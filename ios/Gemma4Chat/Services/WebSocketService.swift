import Foundation

struct WSMessage: Codable {
    let type: String
    let content: String
    let done: Bool
}

struct ChatRequestMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequestPayload: Codable {
    let messages: [ChatRequestMessage]
    let web_search: Bool
    let rag: Bool
}

protocol WebSocketServiceDelegate: AnyObject {
    func didReceiveToken(_ token: String)
    func didReceiveSearchResults(_ results: String)
    func didReceiveRAGContext(_ context: String)
    func didFinishResponse()
    func didReceiveError(_ error: String)
    func didConnect()
    func didDisconnect()
}

class WebSocketService: NSObject {
    // Update this to your backend's IP address
    private let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    weak var delegate: WebSocketServiceDelegate?

    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    init(host: String = "localhost", port: Int = 8000) {
        self.url = URL(string: "ws://\(host):\(port)/ws/chat")!
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    func connect() {
        guard !isConnected else { return }
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        listenForMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
    }

    func sendChatRequest(messages: [(role: String, content: String)], webSearch: Bool, rag: Bool) {
        let requestMessages = messages.map { ChatRequestMessage(role: $0.role, content: $0.content) }
        let payload = ChatRequestPayload(messages: requestMessages, web_search: webSearch, rag: rag)

        guard let data = try? JSONEncoder().encode(payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            delegate?.didReceiveError("Failed to encode request")
            return
        }

        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                self?.delegate?.didReceiveError("Send failed: \(error.localizedDescription)")
            }
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self?.listenForMessages()

            case .failure(let error):
                self?.delegate?.didReceiveError("WebSocket error: \(error.localizedDescription)")
                self?.isConnected = false
                self?.attemptReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(WSMessage.self, from: data) else {
            return
        }

        switch message.type {
        case "token":
            delegate?.didReceiveToken(message.content)
        case "search_results":
            delegate?.didReceiveSearchResults(message.content)
        case "rag_context":
            delegate?.didReceiveRAGContext(message.content)
        case "done":
            delegate?.didFinishResponse()
        case "error":
            delegate?.didReceiveError(message.content)
        default:
            break
        }
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else { return }
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }
}

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        reconnectAttempts = 0
        delegate?.didConnect()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        delegate?.didDisconnect()
    }
}
