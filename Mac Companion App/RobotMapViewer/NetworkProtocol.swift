//
//  NetworkProtocol.swift
//  Robot Map Viewer
//
//  Shared network protocol definitions between iPhone and Mac
//

import Foundation

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
    let vertices: [Float] // Flattened array of vertex positions
    let faces: [Int] // Triangle indices
    let transform: [Float] // 4x4 matrix as 16-element array
    let timestamp: Date
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