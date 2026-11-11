import Foundation

class ChatWebSocketManager: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let eventID: Int32
    private var isClosed = false
    
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }()
    
    var onMessageReceived: ((EventMessageResponse) -> Void)?
    var onReconnected: (() -> Void)?
    
    private var reconnectDelay: TimeInterval = 3.0
    private var isFirstConnection = true
    private var isReconnecting = false
    
    init(eventID: Int32) {
        self.eventID = eventID
        super.init()
    }
    
    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }
    
    func connect() {
        guard !isClosed else { return }
        
        guard let token = TokenStorage.shared.getAccessToken() else {
            print("ChatWebSocketManager: Access token missing, cannot connect.")
            handleDisconnect()
            return
        }
        
        var components = URLComponents(
            url: AppConfig.webSocketBaseURL.appendingPathComponent("events/\(eventID)/ws"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components?.url else { return }
        
        webSocketTask?.cancel()
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        startReceiveLoop()
        print("ChatWebSocketManager: Connected to event \(eventID)")
    }
    
    func disconnect() {
        isClosed = true
        isReconnecting = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session.invalidateAndCancel()
        print("ChatWebSocketManager: Disconnected from event \(eventID)")
    }
    
    private func startReceiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, !self.isClosed else { return }
            
            switch result {
            case .failure(let error):
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    return
                }
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
        guard !isClosed, !isReconnecting else { return }
        isReconnecting = true
        
        let delay = reconnectDelay
        // 3 -> 6 -> 12 -> 24 -> 48 -> 60 с
        reconnectDelay = min(reconnectDelay * 2, 60.0)
        print("ChatWebSocketManager: Reconnecting in \(delay)s...")
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isClosed else { return }
            self.isReconnecting = false
            print("ChatWebSocketManager: Reconnecting with fresh token...")
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
            DispatchQueue.main.async { [weak self] in
                self?.onMessageReceived?(messageRes)
            }
        } catch {
            print("ChatWebSocketManager: Failed to decode message: \(error)")
        }
    }
}

extension ChatWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("ChatWebSocketManager: Socket opened")
        reconnectDelay = 3.0
        isReconnecting = false
        
        if isFirstConnection {
            isFirstConnection = false
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onReconnected?()
            }
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("ChatWebSocketManager: Socket closed with code: \(closeCode)")
        handleDisconnect()
    }
}
