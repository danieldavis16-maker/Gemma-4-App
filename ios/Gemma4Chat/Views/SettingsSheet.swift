import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("System Prompt") {
                    TextField("e.g. You are a helpful coding assistant...", text: $viewModel.settings.systemPrompt, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Temperature") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(viewModel.settings.temperature) },
                            set: { viewModel.settings.temperature = Float($0) }
                        ), in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", viewModel.settings.temperature))
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                    Text("Lower = more focused, Higher = more creative")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Top-K") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(viewModel.settings.topK) },
                            set: { viewModel.settings.topK = Int32($0) }
                        ), in: 1...100, step: 1)
                        Text("\(viewModel.settings.topK)")
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                }

                Section("Top-P") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(viewModel.settings.topP) },
                            set: { viewModel.settings.topP = Float($0) }
                        ), in: 0...1, step: 0.05)
                        Text(String(format: "%.2f", viewModel.settings.topP))
                            .monospacedDigit()
                            .frame(width: 42)
                    }
                }

                Section("Max Tokens") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(viewModel.settings.maxTokens) },
                            set: { viewModel.settings.maxTokens = Int($0) }
                        ), in: 256...4096, step: 256)
                        Text("\(viewModel.settings.maxTokens)")
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        viewModel.settings = .default
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}
