import Foundation
import Network

// Listens for Tempest Hub UDP broadcasts on port 50222 (local network, no auth required)
final class TempestUDPReceiver {
    static let udpPort: NWEndpoint.Port = 50222

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "tempest.udp")

    var onPacket: ((TempestPacket) -> Void)?

    func start() {
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: Self.udpPort)
        } catch {
            print("TempestUDP: failed to bind port \(Self.udpPort): \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] conn in
            conn.start(queue: self?.queue ?? .main)
            self?.receive(on: conn)
        }
        listener?.start(queue: queue)
        print("TempestUDP: listening on UDP :\(Self.udpPort)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, isComplete, error in
            if let data, !data.isEmpty {
                self?.handleDatagram(data)
            }
            if error == nil {
                self?.receive(on: conn)
            }
        }
    }

    private func handleDatagram(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let packet = TempestPacket.parse(json: json)
        DispatchQueue.main.async { self.onPacket?(packet) }
    }
}
