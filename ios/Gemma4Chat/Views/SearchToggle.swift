import SwiftUI

struct SearchToggle: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: isEnabled ? "globe" : "globe")
                    .font(.system(size: 16))
                Text("Search")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isEnabled ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isEnabled ? .blue : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isEnabled ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
    }
}
