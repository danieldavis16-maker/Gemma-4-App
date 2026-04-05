import SwiftUI

struct ServerSetupView: View {
    @Binding var serverHost: String
    @Binding var serverPort: String
    var onConnect: () -> Void

    @State private var hostInput: String = ""
    @State private var portInput: String = "8000"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "server.rack")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)

                Text("Connect to Server")
                    .font(.title2.bold())

                Text("Enter your Mac's IP address.\nFind it with: ipconfig getifaddr en0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    TextField("IP Address (e.g. 192.168.1.42)", text: $hostInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Port", text: $portInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                .padding(.horizontal, 32)

                Button(action: {
                    let host = hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !host.isEmpty else { return }
                    serverHost = host
                    serverPort = portInput.isEmpty ? "8000" : portInput
                    onConnect()
                }) {
                    Text("Connect")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hostInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(hostInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .navigationTitle("Gemma 4 Chat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                hostInput = serverHost
                portInput = serverPort
            }
        }
    }
}
