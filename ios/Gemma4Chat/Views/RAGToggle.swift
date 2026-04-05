import SwiftUI

struct RAGToggle: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                Text("Docs")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isEnabled ? Color.purple.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isEnabled ? .purple : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isEnabled ? Color.purple : Color.clear, lineWidth: 1)
            )
        }
    }
}
