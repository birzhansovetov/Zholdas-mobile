import Foundation

class ChatWebSocketManager: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let eventID: Int32
    private var isClosed = false
    
    var onMessageReceived: ((EventMessageResponse) -> Void)?
    
    init(eventID: Int32) {
        self.eventID = eventID
        super.init()
    }
    
    func connect() {
        guard let token = TokenStorage.shared.getAccessToken() else {
            print("ChatWebSocketManager: Access token missing, cannot connect.")
            return
        }
        
        isClosed = false
        var components = URLComponents(
            url: AppConfig.webSocketBaseURL.appendingPathComponent("events/\(eventID)/ws"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components?.url else { return }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        startReceiveLoop()
        print("ChatWebSocketManager: Connected to event \(eventID)")
    }
    
    func disconnect() {
        isClosed = true
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        print("ChatWebSocketManager: Disconnected from event \(eventID)")
    }
    
    private func startReceiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, !self.isClosed else { return }
            
            switch result {
            case .failure(let error):
                print("ChatWebSocketManager Error receiving: \(error)")
                self.handleDisconnect()
            case .success(let message):
                switch message {
                case .string(let text):
                    self.parseMessage(text)
                case .data(let data):
                    self.parseMessageData(data)
                @unknown default:
                    break
                }
                self.startReceiveLoop()
            }
        }
    }
    
    private func handleDisconnect() {
        guard !isClosed else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, !self.isClosed else { return }
            print("ChatWebSocketManager: Reconnecting...")
            self.connect()
        }
    }
    
    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        parseMessageData(data)
    }
    
    private func parseMessageData(_ data: Data) {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: dateStr) {
                return date
            }
            
            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: dateStr) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateStr)")
        }
        
        do {
            let messageRes = try decoder.decode(EventMessageResponse.self, from: data)
            DispatchQueue.main.async {
                self.onMessageReceived?(messageRes)
            }
        } catch {
            print("ChatWebSocketManager: Failed to decode message: \(error)")
        }
    }
}

extension ChatWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("ChatWebSocketManager: Socket opened")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("ChatWebSocketManager: Socket closed")
    }
}
