import SwiftUI

struct ListItem: View {
    @Binding var sfSymbol: String
    @Binding var title: String
    @Binding var subtitle: String
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            
            VStack {
                Spacer(minLength: 0)
                Image(systemName: sfSymbol)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

