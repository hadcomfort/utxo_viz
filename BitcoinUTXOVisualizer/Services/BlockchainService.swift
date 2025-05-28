import Foundation
import Combine 

enum BlockchainServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String) 
    case noUTXOsFound
    case xpubNotSupported 
    case addressDerivationFailed 

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .decodingError(let err): return "Decoding error: \(err.localizedDescription)"
        case .apiError(let msg): return "API error: \(msg)"
        case .noUTXOsFound: return "No UTXOs found."
        case .xpubNotSupported: return "XPUB fetching is not fully supported with this public API."
        case .addressDerivationFailed: return "Failed to derive addresses from XPUB (simulated)."
        }
    }
}

class BlockchainService {
    private let baseURL = "https://mempool.space/api/" 
    private let inputValidator = InputValidator()

    func fetchUTXOs(forInput input: String, completion: @escaping (Result<[UTXO], Error>) -> Void) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        /* Privacy Note: ... */

        if inputValidator.isSingleAddress(trimmedInput) {
            fetchUTXOsForSingleAddress(address: trimmedInput, completion: completion)
        } else if inputValidator.isCommaSeparatedAddresses(trimmedInput) {
            fetchUTXOsForMultipleAddresses(addressesString: trimmedInput, completion: completion)
        } else if inputValidator.isXpub(trimmedInput) {
            fetchUTXOsForXpub(xpub: trimmedInput, completion: completion)
        } else {
            completion(.failure(BlockchainServiceError.apiError("Invalid input format.")))
        }
    }

    private func fetchUTXOsForSingleAddress(address: String, completion: @escaping (Result<[UTXO], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)address/\(address)/utxo") else {
            completion(.failure(BlockchainServiceError.invalidURL)); return
        }
        performRequest(url: url) { result in
            switch result {
            case .success(var utxos):
                // Populate originAddress for each UTXO
                for i in 0..<utxos.count {
                    utxos[i].originAddress = address
                }
                completion(.success(utxos))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func fetchUTXOsForMultipleAddresses(addressesString: String, completion: @escaping (Result<[UTXO], Error>) -> Void) {
        let addresses = addressesString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var combinedUTXOs: [UTXO] = []
        var errors: [Error] = []
        let dispatchGroup = DispatchGroup()

        for address in addresses {
            guard inputValidator.isSingleAddress(address) else {
                errors.append(BlockchainServiceError.apiError("Invalid address in list: \(address)")); continue
            }
            dispatchGroup.enter()
            fetchUTXOsForSingleAddress(address: address) { result in // This will now populate originAddress
                defer { dispatchGroup.leave() }
                switch result {
                case .success(let utxos):
                    combinedUTXOs.append(contentsOf: utxos)
                case .failure(let error):
                    errors.append(error)
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            if !errors.isEmpty && combinedUTXOs.isEmpty {
                completion(.failure(errors.first ?? BlockchainServiceError.apiError("Multiple address fetch failed.")))
            } else if !errors.isEmpty {
                print("Warning: Some addresses failed: \(errors.map { $0.localizedDescription })")
                completion(.success(combinedUTXOs)) // Partial success
            } else if combinedUTXOs.isEmpty {
                completion(.failure(BlockchainServiceError.noUTXOsFound))
            } else {
                completion(.success(combinedUTXOs))
            }
        }
    }

    private func fetchUTXOsForXpub(xpub: String, completion: @escaping (Result<[UTXO], Error>) -> Void) {
        print("Fetching UTXOs for xpub: \(xpub). Note: Using simulated address derivation.")
        // These dummy addresses are unlikely to have real UTXOs.
        // For testing analytics, ensure some of these simulated addresses are repeated if you want
        // to test "multiple UTXOs per address" with xpub input.
        // Or, use an xpub whose first few derived addresses are known and hardcode those.
        let derivedAddress1 = "bc1qxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" // Replace with actual derived if testing
        let derivedAddress2 = "3Jyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy" // Replace with actual derived if testing
        let derivedAddress3 = "bc1qxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" // Same as derivedAddress1 for testing multi-UTXO analytics

        // Simulate deriving a few addresses. In a real scenario, use an HD Wallet library.
        // For this test, we'll use hardcoded, potentially non-existent addresses.
        // To test "multiple UTXOs per address" from xpub, we need some UTXOs to share an originAddress.
        // The current dummy addresses are unique. Let's use a simplified set for now.
        // If these dummy addresses had UTXOs, the `originAddress` would be set by `fetchUTXOsForSingleAddress`.
        
        // For this simulation, we'll use two distinct dummy addresses.
        // If you want to test the "multiple UTXOs from same derived address" analytic,
        // you'd need an xpub and two *actual* derived addresses from it that *both* have UTXOs.
        // Or, modify the simulation to fetch for the *same* dummy address multiple times (which is unrealistic).
        // The current setup will correctly assign the derived address as `originAddress`.
        let simulatedAddressesToQuery = [
            "bc1q0dy0y0dy0y0dy0y0dy0y0dy0y0dy0y0dy0y0dy0y0dysgr9hv", // Dummy 1
            "3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy",                     // Dummy 2
            // To test "multiple UTXOs per originAddress" with xpub, you'd need a real xpub
            // and know some of its derived addresses that have multiple UTXOs, or
            // the test sample_utxos.json should include UTXOs with originAddress set.
            // For now, the logic in fetchUTXOsForMultipleAddresses will handle setting originAddress.
        ]
        
        var combinedUTXOs: [UTXO] = []
        var errors: [Error] = []
        let dispatchGroup = DispatchGroup()

        for address in simulatedAddressesToQuery {
            dispatchGroup.enter()
            // fetchUTXOsForSingleAddress will set the `originAddress` to `address`
            fetchUTXOsForSingleAddress(address: address) { result in
                defer { dispatchGroup.leave() }
                switch result {
                case .success(let utxos):
                    combinedUTXOs.append(contentsOf: utxos)
                case .failure(let error):
                    if !(error is BlockchainServiceError && (error as! BlockchainServiceError) == .noUTXOsFound) {
                        errors.append(error)
                    }
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            if !errors.isEmpty && combinedUTXOs.isEmpty {
                completion(.failure(errors.first ?? BlockchainServiceError.addressDerivationFailed))
            } else if combinedUTXOs.isEmpty {
                completion(.failure(BlockchainServiceError.noUTXOsFound))
            } else {
                if !errors.isEmpty { print("Warning: Some derived addresses failed: \(errors.map { $0.localizedDescription })") }
                completion(.success(combinedUTXOs))
            }
        }
    }

    private func performRequest(url: URL, completion: @escaping (Result<[UTXO], Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { completion(.failure(BlockchainServiceError.networkError(error))); return }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(BlockchainServiceError.apiError("Invalid server response."))); return
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    var apiMsg = "API Error (Status: \(httpResponse.statusCode))."
                    if let data = data, let msg = String(data: data, encoding: .utf8) { apiMsg += " Message: \(msg)"}
                    completion(.failure(BlockchainServiceError.apiError(apiMsg))); return
                }
                guard let data = data else { completion(.failure(BlockchainServiceError.apiError("No data from API."))); return }
                
                do {
                    let decoder = JSONDecoder()
                    var utxos = try decoder.decode([UTXO].self, from: data)
                    // Note: originAddress is populated by the calling methods (fetchUTXOsForSingleAddress, etc.)
                    if utxos.isEmpty { completion(.failure(BlockchainServiceError.noUTXOsFound)) }
                    else { completion(.success(utxos)) }
                } catch {
                    print("Decoding error: \(error) for URL: \(url)")
                    if let jsonStr = String(data: data, encoding: .utf8) { print("Failed JSON: \(jsonStr.prefix(500))") }
                    completion(.failure(BlockchainServiceError.decodingError(error)))
                }
            }
        }.resume()
    }
}
