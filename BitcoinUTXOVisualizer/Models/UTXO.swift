import Foundation

enum ConfirmationStatus: Codable, Hashable {
    case confirmed
    case unconfirmed

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ConfirmationStatusCodingKeys.self)
        if let isConfirmed = try? container.decode(Bool.self, forKey: .confirmed) {
            self = isConfirmed ? .confirmed : .unconfirmed
        } else {
            self = .unconfirmed
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConfirmationStatusCodingKeys.self)
        try container.encode(self == .confirmed, forKey: .confirmed)
    }

    private enum ConfirmationStatusCodingKeys: String, CodingKey {
        case confirmed
    }
}

struct UTXO: Codable, Identifiable, Hashable {
    let txid: String
    let vout: Int
    let value: Int64 

    let confirmationStatusDetails: ConfirmationStatusDetails 

    let spent: Bool? 
    let txid_spent: String? 
    let vin_spent: Int? 
    let status_spent: ConfirmationStatusDetails? 

    // New field for analytics
    var originAddress: String? = nil // Optional, populated by BlockchainService

    var id: String { "\(txid):\(vout)" }
    var amountInBTC: Double { Double(value) / 100_000_000.0 }
    var status: ConfirmationStatus { confirmationStatusDetails.confirmed ? .confirmed : .unconfirmed }
    var age: String {
        if let height = confirmationStatusDetails.block_height, status == .confirmed {
            return "Block: \(height)"
        } else {
            return "Unconfirmed"
        }
    }
    var block_height: Int? { confirmationStatusDetails.block_height }
    var block_hash: String? { confirmationStatusDetails.block_hash }
    var block_time: Int? { confirmationStatusDetails.block_time }

    struct ConfirmationStatusDetails: Codable, Hashable {
        let confirmed: Bool
        let block_height: Int?
        let block_hash: String?
        let block_time: Int?
    }
    
    enum CodingKeys: String, CodingKey {
        case txid
        case vout
        case status // Mapped to confirmationStatusDetails
        case value
        case spent
        case txid_spent
        case vin_spent
        case status_spent
        case originAddress // New key for encoding/decoding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        txid = try container.decode(String.self, forKey: .txid)
        vout = try container.decode(Int.self, forKey: .vout)
        value = try container.decode(Int64.self, forKey: .value)
        confirmationStatusDetails = try container.decode(ConfirmationStatusDetails.self, forKey: .status)
        spent = try container.decodeIfPresent(Bool.self, forKey: .spent)
        txid_spent = try container.decodeIfPresent(String.self, forKey: .txid_spent)
        vin_spent = try container.decodeIfPresent(Int.self, forKey: .vin_spent)
        status_spent = try container.decodeIfPresent(ConfirmationStatusDetails.self, forKey: .status_spent)
        originAddress = try container.decodeIfPresent(String.self, forKey: .originAddress) // Decode new field
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(txid, forKey: .txid)
        try container.encode(vout, forKey: .vout)
        try container.encode(value, forKey: .value)
        try container.encode(confirmationStatusDetails, forKey: .status)
        try container.encodeIfPresent(spent, forKey: .spent)
        try container.encodeIfPresent(txid_spent, forKey: .txid_spent)
        try container.encodeIfPresent(vin_spent, forKey: .vin_spent)
        try container.encodeIfPresent(status_spent, forKey: .status_spent)
        try container.encodeIfPresent(originAddress, forKey: .originAddress) // Encode new field
    }

    // Manually provide a copy method to modify originAddress post-initialization if needed
    // Or, make originAddress a var and set it after decoding if it's not in the JSON source.
    // For BlockchainService, it will create UTXO objects and then set this field.
    // For JSON loading, it's better if it's part of the Codable process.
}
