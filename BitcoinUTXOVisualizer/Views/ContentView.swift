import SwiftUI
import UniformTypeIdentifiers 

struct ContentView: View {
    @StateObject private var viewModel = UTXOViewModel()
    @State private var addressInput: String = "" 
    @State private var showingFileImporter = false 
    @State private var selectedUTXO: UTXO? = nil
    @State private var showingAnalytics: Bool = true 
    @State private var showingGraph: Bool = true // To make graph section collapsible in detail pane


    @FocusState private var minAmountFieldIsFocused: Bool
    @FocusState private var maxAmountFieldIsFocused: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 10) {
                inputAndControlsArea()
                
                if let source = viewModel.currentInputSource {
                    Text("Displaying data from: \(source)")
                        .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                }

                summaryBarArea()
                exportButtonsArea().padding(.horizontal) 
                analyticsInsightsArea().padding(.horizontal) 
                utxoListArea()
                detailPaneArea() // This will now include the graph
            }
            .navigationTitle("Bitcoin UTXO Visualizer")
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType.json], allowsMultipleSelection: false) { result in
            handleFileImport(result: result)
        }
        .fileExporter(isPresented: $viewModel.showCSVExporter, document: viewModel.csvFile, contentType: UTType.commaSeparatedText, defaultFilename: "utxos.csv") { result in
            handleExportResult(result, type: "CSV")
        }
        .fileExporter(isPresented: $viewModel.showJSONExporter, document: viewModel.jsonFile, contentType: UTType.json, defaultFilename: "utxos.json") { result in
            handleExportResult(result, type: "JSON")
        }
        .frame(minWidth: 850, minHeight: 850) 
    }

    // MARK: - Subviews / Components
    @ViewBuilder
    private func inputAndControlsArea() -> some View { /* ... (remains unchanged) ... */ 
        VStack(spacing: 10) {
            HStack {
                TextField("Enter Bitcoin Address, Addresses, or xpub", text: $addressInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit { validateAndFetchAPI() }
                Button("Fetch UTXOs") { validateAndFetchAPI() }
            }
            Button("Load UTXOs from File") { showingFileImporter = true }
                .frame(maxWidth: .infinity, alignment: .center)
            Divider()
            Text("Filters").font(.title3)
            HStack(spacing: 15) {
                Picker("Status:", selection: $viewModel.statusFilter) {
                    ForEach(UTXOStatusFilter.allCases) { status in Text(status.rawValue).tag(status) }
                }
                .pickerStyle(SegmentedPickerStyle()).frame(minWidth: 200)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount (BTC):").font(.caption)
                    HStack {
                        TextField("Min", text: $viewModel.minAmountFilterBTC)
                            .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80)
                            .keyboardType(.decimalPad).focused($minAmountFieldIsFocused)
                        Text("-")
                        TextField("Max", text: $viewModel.maxAmountFilterBTC)
                            .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80)
                            .keyboardType(.decimalPad).focused($maxAmountFieldIsFocused)
                    }
                }
                Button("Clear Filters") { viewModel.clearFilters() }.padding(.top, 15)
                Spacer()
            }
            Divider()
            Text("Sort By").font(.title3)
            HStack(spacing: 15) {
                Picker("Field:", selection: $viewModel.sortDescriptor.field) {
                    Text("Amount").tag(UTXOSortField.amount); Text("Age/Block").tag(UTXOSortField.age); Text("Status").tag(UTXOSortField.status)
                }
                .pickerStyle(SegmentedPickerStyle()).frame(minWidth: 200)
                Picker("Direction:", selection: $viewModel.sortDescriptor.direction) {
                    Text("Ascending").tag(SortDirection.ascending); Text("Descending").tag(SortDirection.descending)
                }
                .pickerStyle(SegmentedPickerStyle()).frame(minWidth: 180)
                Spacer()
            }
        }
        .padding([.horizontal, .top])
    }
    @ViewBuilder
    private func summaryBarArea() -> some View { /* ... (remains unchanged) ... */ 
        SummaryBarView(
            totalBalance: "\(viewModel.formattedTotalBalance) BTC",
            utxoCount: "\(viewModel.filteredUTXOs.count)",
            confirmedCount: viewModel.confirmedUTXOCount,
            unconfirmedCount: viewModel.unconfirmedUTXOCount
        )
        .padding(.horizontal)
    }
    @ViewBuilder
    private func exportButtonsArea() -> some View { /* ... (remains unchanged) ... */ 
        HStack {
            Spacer() 
            Button { viewModel.prepareCSVExport() } label: { Label("Export as CSV", systemImage: "square.and.arrow.down") }
            .disabled(viewModel.filteredUTXOs.isEmpty) 
            Button { viewModel.prepareJSONExport() } label: { Label("Export as JSON", systemImage: "square.and.arrow.down") }
            .disabled(viewModel.filteredUTXOs.isEmpty) 
            Spacer()
        }
        .padding(.vertical, 5)
    }
    @ViewBuilder
    private func analyticsInsightsArea() -> some View { /* ... (remains unchanged) ... */ 
        DisclosureGroup("Analytics Insights", isExpanded: $showingAnalytics) {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.analyticsMultiUTXOAddresses.isEmpty && viewModel.analyticsCommonSpendEvents.isEmpty {
                    Text("No specific address reuse or common spending patterns detected in the current set.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    if !viewModel.analyticsMultiUTXOAddresses.isEmpty {
                        Text("Multiple UTXOs per Address:").font(.headline.weight(.medium))
                        ForEach(viewModel.analyticsMultiUTXOAddresses, id: \.self) { insight in
                            Text("• \(insight)").font(.caption)
                        }
                    }
                    if !viewModel.analyticsCommonSpendEvents.isEmpty {
                        Text("Common Spending Events:").font(.headline.weight(.medium)).padding(.top, 5)
                        ForEach(viewModel.analyticsCommonSpendEvents, id: \.self) { insight in
                            Text("• \(insight)").font(.caption)
                        }
                    }
                }
            }
            .padding(.top, 5)
        }
        .padding(.vertical, 5)
    }
    @ViewBuilder
    private func utxoListArea() -> some View { /* ... (remains unchanged) ... */ 
        Group {
            if viewModel.isLoading {
                ProgressView("Loading UTXOs...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                errorDisplayView(errorMessage)
            } else if viewModel.filteredUTXOs.isEmpty {
                emptyStateView()
            } else {
                List(viewModel.filteredUTXOs, selection: $selectedUTXO) { utxo in
                    UTXORowView(utxo: utxo).tag(utxo)
                        .contextMenu {
                            Button(action: { copyToClipboard(utxo.txid) }) { Text("Copy TXID"); Image(systemName: "doc.on.doc") }
                        }
                }
                .border(Color.gray.opacity(0.3))
            }
        }
        .frame(minHeight: 200, maxHeight: .infinity) 
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func errorDisplayView(_ message: String) -> some View { /* ... (remains unchanged) ... */ 
        VStack {
            Image(systemName: "xmark.octagon.fill").resizable().aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40).foregroundColor(.red)
            Text(message).foregroundColor(.red).padding().multilineTextAlignment(.center)
            Button("Dismiss & Clear") {
                viewModel.errorMessage = nil; viewModel.clearData(); viewModel.clearFilters()
            }.padding(.top, 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    @ViewBuilder
    private func emptyStateView() -> some View { /* ... (remains unchanged) ... */ 
        let message = viewModel.hasActiveFilters ? "No UTXOs match the current filters." :
                      (viewModel.currentInputSource != nil ? "No UTXOs found from the source." : "Enter an address/xpub and click 'Fetch UTXOs' or load from a file.")
        Text(message).foregroundColor(.secondary).multilineTextAlignment(.center)
            .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Updated Detail Pane
    @ViewBuilder
    private func detailPaneArea() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Selected UTXO Details").font(.title3)
                Spacer()
                if selectedUTXO != nil {
                    Button(action: { selectedUTXO = nil }) { 
                        Image(systemName: "xmark.circle.fill")
                    }
                    .foregroundColor(.gray)
                    .buttonStyle(BorderlessButtonStyle())
                }
            }.padding(.bottom, 5)

            if let utxo = selectedUTXO {
                // Use a TabView or similar if space becomes an issue. For now, VStack.
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Textual Details
                        DetailRow(label: "TXID", value: utxo.txid, isMonospaced: true, showCopy: true)
                        DetailRow(label: "Vout", value: "\(utxo.vout)")
                        DetailRow(label: "Amount", value: "\(utxo.amountInBTC, specifier: "%.8f") BTC (\(utxo.value) sats)")
                        DetailRow(label: "Origin Addr.", value: utxo.originAddress ?? "N/A", isMonospaced: true, showCopy: (utxo.originAddress != nil))
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Status", value: utxo.status == .confirmed ? "Confirmed" : "Unconfirmed",
                                  color: utxo.status == .confirmed ? .green : .orange)
                        if utxo.status == .confirmed {
                            if let blockHeight = utxo.block_height { DetailRow(label: "Block Height", value: "\(blockHeight)") }
                            if let blockHash = utxo.block_hash { DetailRow(label: "Block Hash", value: blockHash, isMonospaced: true, showCopy: true) }
                            if let blockTime = utxo.block_time { DetailRow(label: "Block Time", value: formatTimestamp(blockTime)) }
                        }
                        Divider().padding(.vertical, 4)
                        let isSpent = utxo.spent ?? false
                        DetailRow(label: "Spend Status", value: isSpent ? "Spent" : "Unspent", color: isSpent ? .red : .blue)
                        if isSpent {
                            if let spendingTxid = utxo.txid_spent { DetailRow(label: "Spent in TXID", value: spendingTxid, isMonospaced: true, showCopy: true, isLink: true, linkURL: "https://mempool.space/tx/\(spendingTxid)") }
                            if let spendingVin = utxo.vin_spent { DetailRow(label: "Spending Vin", value: "\(spendingVin)") }
                            if let spendingStatus = utxo.status_spent {
                                DetailRow(label: "Spend Confirmed", value: spendingStatus.confirmed ? "Yes" : "No", color: spendingStatus.confirmed ? .green : .orange)
                                if spendingStatus.confirmed {
                                    if let spendBlockHeight = spendingStatus.block_height { DetailRow(label: "Spend Block", value: "\(spendBlockHeight)") }
                                   if let spendBlockTime = spendingStatus.block_time { DetailRow(label: "Spend Time", value: formatTimestamp(spendBlockTime)) }
                                }
                            }
                        }
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "ScriptPubKey", value: "Not available via current API endpoint", isItalic: true)
                        Divider().padding(.vertical, 4)
                        Text("Explore:").font(.caption.weight(.medium))
                        if let url = URL(string: "https://mempool.space/tx/\(utxo.txid)") { Link("View Originating Transaction", destination: url).font(.caption) }
                        let validator = InputValidator()
                        if let origin = utxo.originAddress, validator.isSingleAddress(origin) { 
                             if let url = URL(string: "https://mempool.space/address/\(origin.trimmingCharacters(in: .whitespacesAndNewlines))") {
                                Link("View Origin Address (\(origin.trimmingCharacters(in: .whitespacesAndNewlines).prefix(6))...)", destination: url).font(.caption).help("Link to the UTXO's origin address.")
                            }
                        } else if validator.isSingleAddress(addressInput) { 
                             if let url = URL(string: "https://mempool.space/address/\(addressInput.trimmingCharacters(in: .whitespacesAndNewlines))") {
                                Link("View Input Address (\(addressInput.trimmingCharacters(in: .whitespacesAndNewlines).prefix(6))...)", destination: url).font(.caption).help("Link to the address entered in the input field, if it was a single address.")
                            }
                        } else { Text("Address Link: N/A").font(.caption2).foregroundColor(.gray) }
                        
                        Divider().padding(.vertical, 8)

                        // Graphical Visualization Section
                        DisclosureGroup("Transaction Flow Graph", isExpanded: $showingGraph) {
                             SelectedUTXOGraphView(utxo: utxo)
                                .padding(.top, 5)
                        }
                    }
                }
            } else { 
                Text("Select a UTXO from the list to see its details and graph here.")
                    .foregroundColor(.secondary)
                Spacer() 
            }
        }
        .padding()
        .frame(minHeight: 250, maxHeight: .infinity) 
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.08)) 
        .cornerRadius(8)
        .padding([.horizontal, .bottom])
    }
    
    // MARK: - Helper Functions
    private func validateAndFetchAPI() { /* ... (remains unchanged) ... */ 
        viewModel.clearData();
        let validator = InputValidator()
        if validator.isValidInput(input: addressInput) {
            viewModel.fetchUTXOs(forInput: addressInput)
        } else {
            viewModel.errorMessage = "Invalid input format for API fetch."
        }
    }
    private func handleFileImport(result: Result<[URL], Error>) { /* ... (remains unchanged) ... */ 
        viewModel.clearData();
        switch result {
        case .success(let urls):
            guard let url = urls.first else { viewModel.errorMessage = "Could not get file URL."; return }
            viewModel.loadUTXOsFromFile(fileURL: url)
        case .failure(let error):
            viewModel.errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }
    private func copyToClipboard(_ string: String) { /* ... (remains unchanged) ... */ 
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    private func formatTimestamp(_ timestamp: Int) -> String { /* ... (remains unchanged) ... */ 
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    private func handleExportResult(_ result: Result<URL, Error>, type: String) { /* ... (remains unchanged) ... */ 
        switch result {
        case .success(let url): print("\(type) exported successfully to \(url.path)")
        case .failure(let error): print("Error exporting \(type): \(error.localizedDescription)"); viewModel.errorMessage = "Error exporting \(type): \(error.localizedDescription)"
        }
    }
}

// UTXORowView (remains unchanged)
struct UTXORowView: View { /* ... */ 
    let utxo: UTXO
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(utxo.status == .confirmed ? Color.green.opacity(0.7) : Color.orange.opacity(0.7)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(utxo.txid).font(.system(.caption, design: .monospaced)).lineLimit(1).truncationMode(.middle).help(utxo.txid); Text(":\(utxo.vout)").font(.system(.caption, design: .monospaced)) }
                Text("Amount: \(utxo.amountInBTC, specifier: "%.8f") BTC (\(utxo.value) sats)").font(.caption2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(utxo.status == .confirmed ? "Confirmed" : "Unconfirmed").font(.caption.weight(.medium)).foregroundColor(utxo.status == .confirmed ? .green : .orange)
                Text(utxo.age).font(.caption2)
            }
        }
        .padding(.vertical, 5)
    }
}

// DetailRow (remains unchanged)
struct DetailRow: View { /* ... */ 
    let label: String; let value: String; var color: Color? = nil; var isMonospaced: Bool = false; var showCopy: Bool = false; var isLink: Bool = false; var linkURL: String? = nil; var isItalic: Bool = false
    var body: some View {
        HStack(alignment: .top) {
            Text("\(label):").font(.caption.weight(.medium)).frame(width: 100, alignment: .trailing).padding(.trailing, 5)
            Group {
                if isLink, let urlString = linkURL, let url = URL(string: urlString) { Link(value, destination: url).font(isMonospaced ? .system(.caption, design: .monospaced) : .caption).if(isItalic) { $0.italic() } }
                else { Text(value).font(isMonospaced ? .system(.caption, design: .monospaced) : .caption).if(isItalic) { $0.italic() } }
            }
            .foregroundColor(color).lineLimit(1).truncationMode(.middle).help(value)
            if showCopy { Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string) }) { Image(systemName: "doc.on.doc") }.buttonStyle(BorderlessButtonStyle()) }
            Spacer()
        }
    }
}

// Helper for conditional modifier (remains unchanged)
extension View { /* ... */ 
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View { if condition { transform(self) } else { self } }
}

struct ContentView_Previews: PreviewProvider { /* ... (remains unchanged) ... */ 
    static var previews: some View { let vm = UTXOViewModel(); return ContentView().environmentObject(vm) }
}
