import SwiftUI

struct SelectedUTXOGraphView: View {
    let utxo: UTXO

    private func truncateTxid(_ txid: String?) -> String {
        guard let txid = txid, !txid.isEmpty else { return "N/A" }
        return txid.count > 10 ? "\(txid.prefix(6))...\(txid.suffix(4))" : txid
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) { // Reduced spacing
            Text("Simplified Transaction Flow")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)

            HStack(spacing: 0) { // Nodes and arrows in HStack
                // Creation Transaction Node
                NodeView(label: "Creation TX", id: truncateTxid(utxo.txid), color: .blue)
                
                ArrowView()

                // Selected UTXO Node
                NodeView(label: "Selected UTXO", id: "\(utxo.amountInBTC, specifier: "%.8f") BTC", color: .green)

                // Spending Transaction (if applicable)
                if utxo.spent == true, let spendingTxid = utxo.txid_spent {
                    ArrowView()
                    NodeView(label: "Spending TX", id: truncateTxid(spendingTxid), color: .red)
                } else {
                    // If not spent, add a spacer to keep UTXO node centered if there's no spending tx
                    // Or, add a placeholder indicating "Unspent"
                    ArrowView(isPlaceholder: true) // Dotted or lighter arrow
                    NodeView(label: "Status", id: "Unspent", color: .gray.opacity(0.5), isFaded: true)
                }
            }
            .frame(maxWidth: .infinity) // Allow HStack to take available width
            .padding(.horizontal) // Add some horizontal padding

            Text("Note: This is a simplified view and does not show other inputs/outputs.")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.top, 10)
        }
        .padding(.vertical)
        .background(Color.gray.opacity(0.05)) // Light background for the graph area
        .cornerRadius(5)
    }
}

struct NodeView: View {
    let label: String
    let id: String
    let color: Color
    var isFaded: Bool = false

    var body: some View {
        VStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(isFaded ? .gray : .primary)
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(isFaded ? 0.3 : 1.0))
                .frame(minWidth: 80, idealWidth: 100, maxWidth: 120, minHeight: 40, idealHeight: 50, maxHeight: 60) // Flexible sizing
                .overlay(
                    Text(id)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(4)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                )
        }
        .padding(.horizontal, 5) // Padding between node and arrow
    }
}

struct ArrowView: View {
    var isPlaceholder: Bool = false
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 10))
            path.addLine(to: CGPoint(x: 30, y: 10)) // Arrow line
            
            // Arrowhead
            if !isPlaceholder {
                path.move(to: CGPoint(x: 30, y: 10))
                path.addLine(to: CGPoint(x: 25, y: 5))
                path.move(to: CGPoint(x: 30, y: 10))
                path.addLine(to: CGPoint(x: 25, y: 15))
            }
        }
        .stroke(isPlaceholder ? Color.gray.opacity(0.5) : Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: isPlaceholder ? [3,3] : []))
        .frame(width: 30, height: 20) // Fixed size for the arrow
        .padding(.horizontal, 2) // Small padding around arrow
    }
}

// Preview
struct SelectedUTXOGraphView_Previews: PreviewProvider {
    static var sampleUnspentUTXO: UTXO {
        // Manually create a UTXO instance. Ensure all required fields are present.
        // This requires knowing the structure of ConfirmationStatusDetails.
        let statusDetails = UTXO.ConfirmationStatusDetails(confirmed: true, block_height: 123456, block_hash: "dummyhash", block_time: 1600000000)
        // For this preview, we'll use a simplified UTXO that might not be fully valid for other parts of the app
        // but is sufficient for previewing the graph view.
        // In a real app, you might have a mock UTXO generator.
        // The UTXO initializer expects all non-optional fields.
        // We will assume a simple JSON structure for preview if the full init is complex.
        // For simplicity, let's assume we can directly construct it if all fields are known.
        // This is a placeholder for a real UTXO instance.
        // Actual preview would require constructing a valid UTXO.
        // The UTXO model has a complex init(from: Decoder). For preview, it's easier to use JSON.
        let json = """
        {
            "txid": "preview_txid_unspent_12345",
            "vout": 0,
            "status": { "confirmed": true, "block_height": 700000, "block_hash": "somehash", "block_time": 1600000000 },
            "value": 100000,
            "spent": false,
            "originAddress": "preview_address_unspent"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        return try! decoder.decode(UTXO.self, from: json)
    }

    static var sampleSpentUTXO: UTXO {
        let json = """
        {
            "txid": "preview_txid_spent_67890",
            "vout": 1,
            "status": { "confirmed": true, "block_height": 650000, "block_hash": "anotherhash", "block_time": 1500000000 },
            "value": 50000,
            "spent": true,
            "txid_spent": "preview_txid_spending_abcde",
            "vin_spent": 2,
            "status_spent": { "confirmed": true, "block_height": 650010, "block_hash": "spendhash", "block_time": 1500010000 },
            "originAddress": "preview_address_spent"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        return try! decoder.decode(UTXO.self, from: json)
    }
    
    static var previews: some View {
        VStack(spacing: 30) {
            SelectedUTXOGraphView(utxo: sampleUnspentUTXO)
            SelectedUTXOGraphView(utxo: sampleSpentUTXO)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
