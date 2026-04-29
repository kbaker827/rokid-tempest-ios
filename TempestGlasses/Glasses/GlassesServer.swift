import Foundation
import Network

final class GlassesServer {
    static let port: NWEndpoint.Port = 8088
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "glasses.tempest")

    var onClientConnected: (() -> Void)?
    var onClientDisconnected: (() -> Void)?
    var clientCount: Int { connections.count }

    func start() {
        guard let l = try? NWListener(using: .tcp, on: Self.port) else { return }
        listener = l
        l.newConnectionHandler = { [weak self] c in self?.accept(c) }
        l.start(queue: queue)
    }

    func stop() {
        listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }; connections.removeAll()
    }

    private func accept(_ conn: NWConnection) {
        connections.append(conn)
        conn.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.remove(conn) }
            else if case .cancelled = state { self?.remove(conn) }
        }
        conn.start(queue: queue)
        onClientConnected?()
    }

    private func remove(_ conn: NWConnection) {
        connections.removeAll { $0 === conn }
        onClientDisconnected?()
    }

    // MARK: - Broadcast

    func broadcastWeather(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        let raw = Data(line.utf8)
        for conn in connections { conn.send(content: raw, completion: .idempotent) }
    }

    // Formatted one-liner for glasses display
    func broadcastFormatted(_ text: String) {
        let payload: [String: String] = ["type": "weather", "text": text]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        let raw = Data(line.utf8)
        for conn in connections { conn.send(content: raw, completion: .idempotent) }
    }

    func broadcastAlert(_ text: String) {
        let payload: [String: String] = ["type": "alert", "text": text]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        let raw = Data(line.utf8)
        for conn in connections { conn.send(content: raw, completion: .idempotent) }
    }
}
