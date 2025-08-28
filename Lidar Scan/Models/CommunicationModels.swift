//
//  CommunicationModels.swift
//  Rescue Robot Control System
//

import Foundation
import simd
import MultipeerConnectivity

// MARK: - Communication Messages

struct RobotStatusUpdate: Codable, Equatable {
    let timestamp: Date
    let position: SIMD3<Float>
    let orientation: SIMD4<Float> // Quaternion
    let batteryLevel: Float?
    let isScanning: Bool
    let detections: [DetectionUpdate]
    let devicePath: [SIMD3<Float>]
    let meshBounds: MeshBounds?
    let connectionStrength: Float
    
    struct DetectionUpdate: Codable, Equatable {
        let id: String
        let position: SIMD3<Float>
        let confidence: Float
        let stability: String
        let age: TimeInterval
        let isStale: Bool
    }
    
    struct MeshBounds: Codable, Equatable {
        let min: SIMD3<Float>
        let max: SIMD3<Float>
    }
}

struct RobotCommand: Codable {
    let timestamp: Date
    let commandId: UUID
    let type: CommandType
    let priority: CommandPriority
    
    enum CommandType: Codable {
        case move(direction: SIMD2<Float>, speed: Float)
        case rotate(angle: Float, speed: Float)
        case goToWaypoint(position: SIMD3<Float>)
        case stop
        case emergencyStop
        case startScanning
        case stopScanning
        case toggleTorch
        case takePicture
    }
    
    enum CommandPriority: String, Codable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        case emergency = "emergency"
    }
}

struct RobotCommandResponse: Codable {
    let commandId: UUID
    let status: ResponseStatus
    let message: String?
    let timestamp: Date
    
    enum ResponseStatus: String, Codable {
        case received = "received"
        case executing = "executing"
        case completed = "completed"
        case failed = "failed"
        case cancelled = "cancelled"
    }
}

// MARK: - Mission Planning

struct Mission: Codable, Identifiable {
    let id: UUID
    let name: String
    var waypoints: [Waypoint]
    let createdAt: Date
    var status: MissionStatus
    
    enum MissionStatus: String, Codable, CaseIterable {
        case planned = "planned"
        case active = "active"
        case paused = "paused"
        case completed = "completed"
        case cancelled = "cancelled"
    }
}

struct Waypoint: Codable, Identifiable {
    let id: UUID
    let position: SIMD3<Float>
    let name: String?
    let action: WaypointAction?
    var isCompleted: Bool
    
    enum WaypointAction: String, Codable {
        case scan = "scan"
        case wait = "wait"
        case takePicture = "takePicture"
        case searchArea = "searchArea"
    }
}

// MARK: - Connection Management

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
    
    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

// MARK: - Message Types

enum MessageType: String, Codable {
    case robotStatus = "robotStatus"
    case robotCommand = "robotCommand"
    case commandResponse = "commandResponse"
    case heartbeat = "heartbeat"
    case discovery = "discovery"
}

struct Message: Codable {
    let type: MessageType
    let data: Data
    let timestamp: Date
    let sender: String
    
    init(type: MessageType, data: Data, sender: String) {
        self.type = type
        self.data = data
        self.timestamp = Date()
        self.sender = sender
    }
}