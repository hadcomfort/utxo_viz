import SwiftUI

struct SummaryBarView: View {
    var totalBalance: String // Formatted BTC string
    var utxoCount: String    // Total count of displayed UTXOs
    var confirmedCount: Int
    var unconfirmedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Total Balance:")
                    .font(.headline)
                Text(totalBalance)
                    .font(.headline.monospaced()) // Monospaced for numbers
                Spacer()
            }
            HStack {
                 Text("Displaying UTXOs:")
                    .font(.caption)
                Text(utxoCount) // Total displayed
                    .font(.caption.weight(.semibold))
                
                if confirmedCount > 0 || unconfirmedCount > 0 { // Only show breakdown if relevant
                    Text("(\(confirmedCount) Confirmed, \(unconfirmedCount) Unconfirmed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12) // Add some horizontal padding too
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
}

struct SummaryBarView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryBarView(
            totalBalance: "1.23456789 BTC",
            utxoCount: "15",
            confirmedCount: 10,
            unconfirmedCount: 5
        )
        .padding()
        .previewLayout(.sizeThatFits)
        
        SummaryBarView(
            totalBalance: "0.00000000 BTC",
            utxoCount: "0",
            confirmedCount: 0,
            unconfirmedCount: 0
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
