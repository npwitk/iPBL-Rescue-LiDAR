//
//  NetworkService.swift
//  Rescue Robot Sensor Head
//

import Foundation
import Network
import simd
import Combine
import UIKit

// MARK: - Network Message Protocol
enum NetworkMessage: Codable {
    case robotPosition(RobotPositionMessage)
    case meshUpdate(MeshUpdateMessage)
    case personDetection(PersonDetectionMessage)
    case sessionStart(SessionStartMessage)
    case sessionEnd(SessionEndMessage)
    case heartbeat(HeartbeatMessage)
    
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    enum MessageType: String, Codable {
        case robotPosition, meshUpdate, personDetection, sessionStart, sessionEnd, heartbeat
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        
        switch type {
        case .robotPosition:
            let data = try container.decode(RobotPositionMessage.self, forKey: .data)
            self = .robotPosition(data)
        case .meshUpdate:
            let data = try container.decode(MeshUpdateMessage.self, forKey: .data)
            self = .meshUpdate(data)
        case .personDetection:
            let data = try container.decode(PersonDetectionMessage.self, forKey: .data)
            self = .personDetection(data)
        case .sessionStart:
            let data = try container.decode(SessionStartMessage.self, forKey: .data)
            self = .sessionStart(data)
        case .sessionEnd:
            let data = try container.decode(SessionEndMessage.self, forKey: .data)
            self = .sessionEnd(data)
        case .heartbeat:
            let data = try container.decode(HeartbeatMessage.self, forKey: .data)
            self = .heartbeat(data)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .robotPosition(let data):
            try container.encode(MessageType.robotPosition, forKey: .type)
            try container.encode(data, forKey: .data)
        case .meshUpdate(let data):
            try container.encode(MessageType.meshUpdate, forKey: .type)
            try container.encode(data, forKey: .data)
        case .personDetection(let data):
            try container.encode(MessageType.personDetection, forKey: .type)
            try container.encode(data, forKey: .data)
        case .sessionStart(let data):
            try container.encode(MessageType.sessionStart, forKey: .type)
            try container.encode(data, forKey: .data)
        case .sessionEnd(let data):
            try container.encode(MessageType.sessionEnd, forKey: .type)
            try container.encode(data, forKey: .data)
        case .heartbeat(let data):
            try container.encode(MessageType.heartbeat, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - Message Types
struct RobotPositionMessage: Codable {
    let position: [Float] // [x, y, z]
    let rotation: [Float] // quaternion [x, y, z, w]
    let timestamp: Date
}

struct MeshUpdateMessage: Codable {
    let anchorId: String
    let vertices: [Float] // Flattened array of vertex positions [x,y,z,x,y,z,...]
    let normals: [Float]? // Flattened array of vertex normals [x,y,z,x,y,z,...]  
    let faces: [UInt32] // Triangle indices (3 per triangle)
    let transform: [Float] // 4x4 matrix as 16-element array
    let timestamp: Date
    let vertexCount: Int // Number of vertices (vertices.count / 3)
}

struct PersonDetectionMessage: Codable {
    let id: String
    let position: [Float] // [x, y, z]
    let confidence: Float
    let stability: String
    let timestamp: Date
}

struct SessionStartMessage: Codable {
    let sessionId: String
    let timestamp: Date
    let deviceInfo: DeviceInfo
}

struct SessionEndMessage: Codable {
    let sessionId: String
    let timestamp: Date
    let totalDetections: Int
}

struct HeartbeatMessage: Codable {
    let timestamp: Date
    let robotStatus: String
}

struct DeviceInfo: Codable {
    let model: String
    let systemVersion: String
    let appVersion: String
}

// MARK: - Network Service
class NetworkService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var lastDataSent: Date?
    
    private var connection: NWConnection?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "NetworkService")
    private var cancellables = Set<AnyCancellable>()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Configuration
    static let defaultPort: NWEndpoint.Port = 12345
    private let heartbeatInterval: TimeInterval = 5.0
    private var heartbeatTimer: Timer?
    
    override init() {
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    func connectToMac(host: String, port: UInt16 = 12345) {
        disconnect()
        
        guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
            updateStatus("Invalid port")
            return
        }
        
        let host = NWEndpoint.Host(host)
        connection = NWConnection(host: host, port: portEndpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionStateChange(state)
            }
        }
        
        connection?.start(queue: queue)
        updateStatus("Connecting...")
    }
    
    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        connection?.cancel()
        connection = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.updateStatus("Disconnected")
        }
    }
    
    private func handleConnectionStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isConnected = true
            updateStatus("Connected")
            startHeartbeat()
            print("📱 Connected to Mac")
            
        case .waiting(let error):
            isConnected = false
            updateStatus("Waiting: \(error.localizedDescription)")
            
        case .failed(let error):
            isConnected = false
            updateStatus("Failed: \(error.localizedDescription)")
            print("❌ Connection failed: \(error)")
            
        case .cancelled:
            isConnected = false
            updateStatus("Cancelled")
            
        default:
            updateStatus("Connecting...")
        }
    }
    
    private func updateStatus(_ status: String) {
        connectionStatus = status
    }
    
    // MARK: - Heartbeat
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func sendHeartbeat() {
        let heartbeat = HeartbeatMessage(
            timestamp: Date(),
            robotStatus: "active"
        )
        
        sendMessage(.heartbeat(heartbeat))
    }
    
    // MARK: - Message Sending
    func sendMessage(_ message: NetworkMessage) {
        guard isConnected, connection != nil else {
            print("⚠️ Cannot send message - not connected")
            return
        }
        
        // Perform encoding on background queue to avoid blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try self.encoder.encode(message)
                
                // Validate data size (prevent sending huge messages)
                guard data.count < 10_000_000 else { // 10MB limit
                    print("❌ Message too large: \(data.count) bytes")
                    return
                }
                
                let lengthData = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }
                
                // Check connection is still valid before sending
                guard self.isConnected, let connection = self.connection else {
                    print("⚠️ Connection lost while preparing message")
                    return
                }
                
                connection.send(content: lengthData + data, completion: .contentProcessed { [weak self] error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Send error: \(error)")
                            // If send fails, mark as disconnected
                            self?.isConnected = false
                            self?.updateStatus("Send failed")
                        } else {
                            self?.lastDataSent = Date()
                        }
                    }
                })
                
            } catch {
                print("❌ Encoding error: \(error)")
            }
        }
    }
    
    // MARK: - Specific Message Senders
    func sendRobotPosition(_ position: simd_float3, rotation: simd_quatf) {
        let message = RobotPositionMessage(
            position: [position.x, position.y, position.z],
            rotation: [rotation.vector.x, rotation.vector.y, rotation.vector.z, rotation.vector.w],
            timestamp: Date()
        )
        
        sendMessage(.robotPosition(message))
    }
    
    func sendPersonDetection(_ pin: PersonPin) {
        let message = PersonDetectionMessage(
            id: pin.id.uuidString,
            position: [pin.worldPosition.x, pin.worldPosition.y, pin.worldPosition.z],
            confidence: pin.confidence,
            stability: pin.stability.rawValue,
            timestamp: Date()
        )
        
        sendMessage(.personDetection(message))
    }
    
    func sendSessionStart(sessionId: String) {
        let deviceInfo = DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        
        let message = SessionStartMessage(
            sessionId: sessionId,
            timestamp: Date(),
            deviceInfo: deviceInfo
        )
        
        sendMessage(.sessionStart(message))
    }
    
    func sendSessionEnd(sessionId: String, totalDetections: Int) {
        let message = SessionEndMessage(
            sessionId: sessionId,
            timestamp: Date(),
            totalDetections: totalDetections
        )
        
        sendMessage(.sessionEnd(message))
    }
    
    // MARK: - Bonjour Discovery (for future enhancement)
    func startBonjourDiscovery() {
        // Future: Implement Bonjour service discovery to automatically find Mac apps
    }
}

// MARK: - Network Extensions
extension NetworkService {
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" { // WiFi interface
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                      &hostname, socklen_t(hostname.count),
                                      nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
}

// Add necessary import for network interfaces
#if canImport(Darwin)
import Darwin
#endif
