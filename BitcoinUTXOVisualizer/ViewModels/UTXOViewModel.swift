import Foundation
import Combine
import SwiftUI

// MARK: - Sorting Definitions
enum UTXOSortField { /* ... (existing code) ... */ 
    case amount
    case age 
    case status
}
enum SortDirection { /* ... (existing code) ... */ 
    case ascending
    case descending
}
struct UTXOSortDescriptor: Equatable { /* ... (existing code) ... */ 
    var field: UTXOSortField
    var direction: SortDirection

    static var defaultSort: UTXOSortDescriptor {
        UTXOSortDescriptor(field: .age, direction: .descending)
    }
}

// MARK: - Filtering Definitions
enum UTXOStatusFilter: String, CaseIterable, Identifiable { /* ... (existing code) ... */ 
    case all = "All"
    case confirmed = "Confirmed"
    case unconfirmed = "Unconfirmed"

    var id: String { self.rawValue }
}

class UTXOViewModel: ObservableObject {
    // MARK: - Published Properties for UI
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentInputSource: String? = nil
    @Published private var sourceUTXOs: [UTXO] = []

    @Published var sortDescriptor: UTXOSortDescriptor = .defaultSort
    @Published var statusFilter: UTXOStatusFilter = .all
    @Published var minAmountFilterBTC: String = ""
    @Published var maxAmountFilterBTC: String = ""

    @Published var showCSVExporter: Bool = false
    @Published var csvFile: CSVFile? = nil
    @Published var showJSONExporter: Bool = false
    @Published var jsonFile: JSONFile? = nil

    // MARK: - Analytics Properties
    @Published var analyticsMultiUTXOAddresses: [String] = []
    @Published var analyticsCommonSpendEvents: [String] = []


    var filteredUTXOs: [UTXO] {
        // ... (existing filtering and sorting logic) ...
        var displayableUTXOs = sourceUTXOs
        switch statusFilter {
        case .confirmed: displayableUTXOs = displayableUTXOs.filter { $0.status == .confirmed }
        case .unconfirmed: displayableUTXOs = displayableUTXOs.filter { $0.status == .unconfirmed }
        case .all: break
        }
        let minSatoshis = btcStringToSatoshis(minAmountFilterBTC)
        let maxSatoshis = btcStringToSatoshis(maxAmountFilterBTC)
        if let min = minSatoshis { displayableUTXOs = displayableUTXOs.filter { $0.value >= min } }
        if let max = maxSatoshis, max > 0 { displayableUTXOs = displayableUTXOs.filter { $0.value <= max } }
        
        displayableUTXOs.sort { (lhs, rhs) -> Bool in
            switch sortDescriptor.field {
            case .amount:
                return sortDescriptor.direction == .ascending ? lhs.value < rhs.value : lhs.value > rhs.value
            case .age:
                if lhs.status == .confirmed && rhs.status == .confirmed {
                    let lhsHeight = lhs.block_height ?? 0; let rhsHeight = rhs.block_height ?? 0
                    return sortDescriptor.direction == .descending ? lhsHeight > rhsHeight : lhsHeight < rhsHeight
                } else if lhs.status == .unconfirmed && rhs.status == .confirmed {
                    return sortDescriptor.direction == .descending ? true : false
                } else if lhs.status == .confirmed && rhs.status == .unconfirmed {
                    return sortDescriptor.direction == .descending ? false : true
                } else { return lhs.value > rhs.value }
            case .status:
                if lhs.status == .confirmed && rhs.status == .unconfirmed {
                    return sortDescriptor.direction == .ascending ? false : true
                } else if lhs.status == .unconfirmed && rhs.status == .confirmed {
                    return sortDescriptor.direction == .ascending ? true : false
                }
                return lhs.value > rhs.value
            }
        }
        
        // Update analytics whenever filteredUTXOs changes
        // Using a DispatchQueue.main.async to avoid modifying published properties during a view update cycle directly
        DispatchQueue.main.async {
            self.updateAnalytics(basedOn: displayableUTXOs)
        }
        return displayableUTXOs
    }
    
    // ... (existing summary properties: totalBalanceSatoshis, etc.) ...
    var totalBalanceSatoshis: Int64 { filteredUTXOs.reduce(0) { $0 + $1.value } }
    var totalBalanceBTC: Double { Double(totalBalanceSatoshis) / 100_000_000.0 }
    var utxoCount: Int { filteredUTXOs.count }
    var confirmedUTXOCount: Int { filteredUTXOs.filter { $0.status == .confirmed }.count }
    var unconfirmedUTXOCount: Int { filteredUTXOs.filter { $0.status == .unconfirmed }.count }
    var formattedTotalBalance: String {
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8; formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalBalanceBTC)) ?? "0.00"
    }
    var hasActiveFilters: Bool { statusFilter != .all || !minAmountFilterBTC.isEmpty || !maxAmountFilterBTC.isEmpty }


    private var blockchainService = BlockchainService()

    // ... (existing fetchUTXOs, loadUTXOsFromFile, clearAndPrepareForLoad, handleLoadingError, clearFilters, btcStringToSatoshis, clearData methods) ...
    func fetchUTXOs(forInput input: String) { 
        clearAndPrepareForLoad()
        isLoading = true

        blockchainService.fetchUTXOs(forInput: input) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let fetchedUTXOs):
                    self.sourceUTXOs = fetchedUTXOs
                    self.currentInputSource = "API: \(input)"
                    if fetchedUTXOs.isEmpty {
                        self.errorMessage = "No UTXOs found for the API input: \(input)."
                    }
                    // self.updateAnalytics(basedOn: self.filteredUTXOs) // Now handled by filteredUTXOs computed property
                case .failure(let error):
                    self.handleLoadingError(error)
                    // self.updateAnalytics(basedOn: []) // Now handled by filteredUTXOs computed property
                }
            }
        }
    }
    func loadUTXOsFromFile(fileURL: URL) { 
        clearAndPrepareForLoad()
        isLoading = true

        do {
            guard fileURL.startAccessingSecurityScopedResource() else {
                self.isLoading = false; self.errorMessage = "Permission denied."; self.currentInputSource = nil
                // self.updateAnalytics(basedOn: []) // Now handled by filteredUTXOs
                return
            }
            let data = try Data(contentsOf: fileURL)
            fileURL.stopAccessingSecurityScopedResource()

            let decoder = JSONDecoder()
            let fileUTXOs = try decoder.decode([UTXO].self, from: data)
            
            DispatchQueue.main.async {
                self.isLoading = false; self.sourceUTXOs = fileUTXOs
                self.currentInputSource = "File: \(fileURL.lastPathComponent)"
                if fileUTXOs.isEmpty { self.errorMessage = "No UTXOs found in file." }
                // self.updateAnalytics(basedOn: self.filteredUTXOs) // Now handled by filteredUTXOs
            }
        } catch {
            fileURL.stopAccessingSecurityScopedResource()
            DispatchQueue.main.async {
                self.isLoading = false
                self.handleLoadingError(error, context: "Error loading file.")
                // self.updateAnalytics(basedOn: []) // Now handled by filteredUTXOs
            }
        }
    }
    private func clearAndPrepareForLoad() { 
        isLoading = true; errorMessage = nil; sourceUTXOs = [] 
        currentInputSource = nil
        // Analytics will be cleared by updateAnalytics when sourceUTXOs becomes empty via filteredUTXOs
    }
    private func handleLoadingError(_ error: Error, context: String? = nil) { 
        self.sourceUTXOs = [] // This will trigger analytics update via filteredUTXOs
        if let serviceError = error as? BlockchainServiceError {
            self.errorMessage = context != nil ? "\(context) \(serviceError.localizedDescription)" : serviceError.localizedDescription
        } else {
            self.errorMessage = context != nil ? "\(context) \(error.localizedDescription)" : error.localizedDescription
        }
        self.currentInputSource = nil
    }
    func clearFilters() { 
        statusFilter = .all; minAmountFilterBTC = ""; maxAmountFilterBTC = ""
        // objectWillChange.send() // To recompute filteredUTXOs and thus analytics
    }
    private func btcStringToSatoshis(_ btcString: String) -> Int64? { 
        guard !btcString.isEmpty, let btcValue = Double(btcString.replacingOccurrences(of: ",", with: ".")) else { return nil }
        if btcValue < 0 { return nil } 
        return Int64(btcValue * 100_000_000.0)
    }
    func clearData() { 
        sourceUTXOs = [] // This will trigger analytics update via filteredUTXOs
        errorMessage = nil; currentInputSource = nil 
    }


    // MARK: - Analytics Logic
    private func updateAnalytics(basedOn utxos: [UTXO]) {
        // Multiple UTXOs per Address
        var multiUTXOAddrResults: [String] = []
        let utxosByOriginAddress = Dictionary(grouping: utxos.filter { $0.originAddress != nil }, by: { $0.originAddress! })
        
        for (address, groupedUtxos) in utxosByOriginAddress {
            if groupedUtxos.count > 1 {
                let shortAddress = address.count > 12 ? "\(address.prefix(6))...\(address.suffix(6))" : address
                multiUTXOAddrResults.append("\(shortAddress) has \(groupedUtxos.count) UTXOs.")
            }
        }
        self.analyticsMultiUTXOAddresses = multiUTXOAddrResults.sorted()

        // Common Spending Transaction
        var commonSpendResults: [String] = []
        let spentUtxosWithSpendTxid = utxos.filter { $0.spent == true && $0.txid_spent != nil }
        let utxosBySpendTxid = Dictionary(grouping: spentUtxosWithSpendTxid, by: { $0.txid_spent! })

        for (spendTxid, groupedUtxos) in utxosBySpendTxid {
            if groupedUtxos.count > 1 {
                let utxoShortList = groupedUtxos.map { "\($0.txid.prefix(6))...:\($0.vout)" }.joined(separator: ", ")
                let shortSpendTxid = spendTxid.count > 12 ? "\(spendTxid.prefix(6))...\(spendTxid.suffix(6))" : spendTxid
                commonSpendResults.append("Common Spend: \(groupedUtxos.count) UTXOs spent in TXID \(shortSpendTxid) (UTXOs: \(utxoShortList))")
            }
        }
        self.analyticsCommonSpendEvents = commonSpendResults.sorted()
    }


    // MARK: - Export Logic
    func prepareCSVExport() { /* ... (existing code) ... */ 
        let content = generateCSVString(from: filteredUTXOs)
        self.csvFile = CSVFile(initialText: content)
        self.showCSVExporter = true
    }
    func prepareJSONExport() { /* ... (existing code) ... */ 
        guard let content = generateJSONString(from: filteredUTXOs) else {
            self.errorMessage = "Failed to generate JSON data for export."
            return
        }
        self.jsonFile = JSONFile(initialText: content)
        self.showJSONExporter = true
    }
    private func generateCSVString(from utxos: [UTXO]) -> String { /* ... (existing code, ensure originAddress is included) ... */ 
        var csvString = "TXID,Vout,Amount (BTC),Amount (Sats),Status,Block Height,Block Hash,Block Time,Age,Origin Address,Spent,Spend TXID,Spend Vin,Spend Status Confirmed,Spend Block Height,Spend Block Time\n" // Added Origin Address
        let dateFormatter = DateFormatter(); dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for utxo in utxos {
            let txid = utxo.txid; let vout = "\(utxo.vout)"; let amountBTC = String(format: "%.8f", utxo.amountInBTC)
            let amountSats = "\(utxo.value)"; let status = utxo.status == .confirmed ? "Confirmed" : "Unconfirmed"
            let blockHeight = utxo.block_height != nil ? "\(utxo.block_height!)" : ""; let blockHash = utxo.block_hash ?? ""
            let blockTime = utxo.block_time != nil ? dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(utxo.block_time!))) : ""; let age = utxo.age
            let originAddress = utxo.originAddress ?? "" // Added
            let spent = "\(utxo.spent ?? false)"; let spendTxid = utxo.txid_spent ?? ""; let spendVin = utxo.vin_spent != nil ? "\(utxo.vin_spent!)" : ""
            var spendStatusConfirmed = ""; var spendBlockHeight = ""; var spendBlockTimeStr = ""
            if let spendStatus = utxo.status_spent {
                spendStatusConfirmed = "\(spendStatus.confirmed)"
                if let sbh = spendStatus.block_height { spendBlockHeight = "\(sbh)" }
                if let sbt = spendStatus.block_time { spendBlockTimeStr = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(sbt))) }
            }
            let row = "\(txid),\(vout),\(amountBTC),\(amountSats),\(status),\(blockHeight),\(blockHash),\(blockTime),\"\(age)\",\(originAddress),\(spent),\(spendTxid),\(spendVin),\(spendStatusConfirmed),\(spendBlockHeight),\(spendBlockTimeStr)\n"
            csvString.append(row)
        }
        return csvString
    }
    private func generateJSONString(from utxos: [UTXO]) -> String? { /* ... (existing code) ... */ 
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(utxos)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error encoding UTXOs to JSON: \(error)"); self.errorMessage = "Error encoding data to JSON: \(error.localizedDescription)"
            return nil
        }
    }
}
