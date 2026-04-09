import SwiftUI

struct TemplatesView: View {
    @ObservedObject var viewModel: ChatViewModel

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(builtInTemplates) { template in
                        Button {
                            viewModel.applyTemplate(template)
                            viewModel.showTemplatesSheet = false
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: template.icon)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text(template.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(template.systemPrompt.prefix(60) + "...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.showTemplatesSheet = false
                    }
                }
            }
        }
    }
}
