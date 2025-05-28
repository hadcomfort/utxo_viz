import Foundation

struct InputValidator {
    // Basic regex for Bitcoin addresses (covers P2PKH, P2SH, P2WPKH, P2TR)
    // This is a simplified regex and might not cover all edge cases.
    private let addressRegex = "^(bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39}$"
    private let bech32AddressRegex = "^(bc1q|tb1q)[0-9a-z]{38,58}$" // More specific for P2WPKH/P2TR

    // Basic regex for common xpub, ypub, zpub prefixes
    // [xyz]pub[1-9A-HJ-NP-Za-km-z]{70,110} should be a more robust pattern
    // but for simplicity, we'll check prefixes and general base58 characteristics.
    private let xpubRegex = "^([xyz]pub|[tuv]pub)[a-zA-HJ-NP-Z0-9]{70,110}$"


    func isValidInput(input: String) -> Bool {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a single address or xpub
        if isSingleAddress(trimmedInput) || isXpub(trimmedInput) {
            return true
        }

        // Check if it's a comma-separated list of addresses
        if isCommaSeparatedAddresses(trimmedInput) {
            return true
        }

        return false
    }

    private func isSingleAddress(_ address: String) -> Bool {
        // P2PKH starts with 1
        // P2SH starts with 3
        // P2WPKH/P2TR (Bech32) starts with bc1
        // Testnet addresses often start with m, n, 2, tb1
        if address.starts(with: "1") || address.starts(with: "3") {
            return NSPredicate(format: "SELF MATCHES %@", addressRegex).evaluate(with: address) && address.count >= 26 && address.count <= 35
        } else if address.starts(with: "bc1") || address.starts(with: "tb1") {
             // Bech32/Bech32m can be longer
            return NSPredicate(format: "SELF MATCHES %@", bech32AddressRegex).evaluate(with: address)
        }
        // Add other testnet prefixes if necessary e.g. m, n, 2
        else if address.starts(with: "m") || address.starts(with: "n") || address.starts(with: "2"){
             return NSPredicate(format: "SELF MATCHES %@", addressRegex).evaluate(with: address) && address.count >= 26 && address.count <= 35
        }
        return false
    }

    private func isXpub(_ xpub: String) -> Bool {
        // Common prefixes: xpub, ypub, zpub (mainnet)
        // tpub, upub, vpub (testnet)
        let prefixes = ["xpub", "ypub", "zpub", "tpub", "upub", "vpub"]
        if prefixes.contains(where: xpub.hasPrefix) {
            // Basic check for length and characters (Base58)
            // A full Base58 check is more complex.
            return NSPredicate(format: "SELF MATCHES %@", xpubRegex).evaluate(with: xpub)
        }
        return false
    }

    private func isCommaSeparatedAddresses(_ input: String) -> Bool {
        let addresses = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if addresses.isEmpty {
            return false
        }
        for address in addresses {
            if !isSingleAddress(address) {
                return false // If any address in the list is invalid
            }
        }
        return true // All addresses in the list are valid
    }
}
