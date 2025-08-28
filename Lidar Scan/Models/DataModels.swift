//
//  DataModels.swift
//  Rescue Robot Sensor Head
//

import Foundation
import simd
import Vision
import ARKit

// MARK: - Pin Stability Levels
enum PinStability: String, CaseIterable {
    case singleFrame = "single-frame"
    case multiFrame = "multi-frame"
    case corroborated = "corroborated"
    
    var color: String {
        switch self {
        case .singleFrame: return "yellow"
        case .multiFrame: return "orange" 
        case .corroborated: return "red"
        }
    }
    
    var confidenceThreshold: Float {
        switch self {
        case .singleFrame: return 0.4
        case .multiFrame: return 0.8
        case .corroborated: return 0.9
        }
    }
}

// MARK: - Detection Data
struct PersonDetection: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let confidence: Float
    let screenPoint: CGPoint
    let worldPosition: simd_float3?
    let pose: HumanBodyPose?
    
    init(id: UUID = UUID(), confidence: Float, screenPoint: CGPoint, worldPosition: simd_float3? = nil, pose: HumanBodyPose? = nil) {
        self.id = id
        self.timestamp = Date()
        self.confidence = confidence
        self.screenPoint = screenPoint
        self.worldPosition = worldPosition
        self.pose = pose
    }
}

struct HumanBodyPose: Codable {
    let joints: [String: CGPoint]
    let confidence: Float
    
    var representativeJoint: CGPoint {
        // Priority: neck -> root -> average of ankles
        if let neck = joints["neck"] { return neck }
        if let root = joints["root"] { return root }
        if let leftAnkle = joints["left_ankle"], let rightAnkle = joints["right_ankle"] {
            return CGPoint(x: (leftAnkle.x + rightAnkle.x) / 2, y: (leftAnkle.y + rightAnkle.y) / 2)
        }
        // Fallback to first available joint
        return joints.values.first ?? CGPoint.zero
    }
}

// MARK: - Person Pin
class PersonPin: ObservableObject, Identifiable {
    let id: UUID
    @Published var stability: PinStability
    @Published var confidence: Float
    @Published var worldPosition: simd_float3
    @Published var lastSeen: Date
    @Published var detectionHistory: [PersonDetection]
    
    let firstSeen: Date
    var anchor: ARAnchor?
    
    init(id: UUID = UUID(), initialDetection: PersonDetection) {
        self.id = id
        self.firstSeen = Date()
        self.lastSeen = initialDetection.timestamp
        self.confidence = initialDetection.confidence
        self.worldPosition = initialDetection.worldPosition ?? simd_float3(0, 0, 0)
        self.stability = .singleFrame
        self.detectionHistory = [initialDetection]
    }
    
    func addDetection(_ detection: PersonDetection) {
        detectionHistory.append(detection)
        lastSeen = detection.timestamp
        confidence = max(confidence, detection.confidence)
        
        if let worldPos = detection.worldPosition {
            worldPosition = worldPos
        }
        
        updateStability()
    }
    
    private func updateStability() {
        let recentDetections = detectionHistory.filter { 
            Date().timeIntervalSince($0.timestamp) < 5.0 
        }
        
        if recentDetections.count >= 10 && confidence >= PinStability.corroborated.confidenceThreshold {
            stability = .corroborated
        } else if recentDetections.count >= 3 && confidence >= PinStability.multiFrame.confidenceThreshold {
            stability = .multiFrame
        } else {
            stability = .singleFrame
        }
    }
    
    var age: TimeInterval {
        Date().timeIntervalSince(firstSeen)
    }
    
    var isStale: Bool {
        Date().timeIntervalSince(lastSeen) > 10.0
    }
}

// MARK: - Detection Export
struct DetectionExport: Codable {
    let id: UUID
    let worldPosition: [Float]
    let confidenceTimeline: [Float]
    let timestamps: [Date]
    let stability: String
    let firstSeen: Date
    let lastSeen: Date
    
    init(from pin: PersonPin) {
        self.id = pin.id
        self.worldPosition = [pin.worldPosition.x, pin.worldPosition.y, pin.worldPosition.z]
        self.confidenceTimeline = pin.detectionHistory.map { $0.confidence }
        self.timestamps = pin.detectionHistory.map { $0.timestamp }
        self.stability = pin.stability.rawValue
        self.firstSeen = pin.firstSeen
        self.lastSeen = pin.lastSeen
    }
}

// MARK: - Scanning Session
class ScanningSession: ObservableObject {
    @Published var devicePath: [simd_float3] = []
    @Published var detectedPins: [PersonPin] = []
    @Published var meshBounds: (min: simd_float3, max: simd_float3)? = nil
    
    let sessionId = UUID()
    let startTime = Date()
    var endTime: Date?
    
    func addDevicePosition(_ position: simd_float3) {
        devicePath.append(position)
        updateMeshBounds(with: position)
    }
    
    func addPin(_ pin: PersonPin) {
        detectedPins.append(pin)
        updateMeshBounds(with: pin.worldPosition)
    }
    
    private func updateMeshBounds(with position: simd_float3) {
        if meshBounds == nil {
            meshBounds = (min: position, max: position)
        } else {
            let currentBounds = meshBounds!
            meshBounds = (
                min: simd_float3(
                    min(currentBounds.min.x, position.x),
                    min(currentBounds.min.y, position.y),
                    min(currentBounds.min.z, position.z)
                ),
                max: simd_float3(
                    max(currentBounds.max.x, position.x),
                    max(currentBounds.max.y, position.y),
                    max(currentBounds.max.z, position.z)
                )
            )
        }
    }
    
    func endSession() {
        endTime = Date()
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isSessionRunning = false
    @Published var torchIsOn: Bool = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var pins: [PersonPin] = []
    @Published var selectedPinId: UUID?
    @Published var showMesh = true
    @Published var showAnchors = true
    @Published var showDevicePath = true
    @Published var filterRecent = true
    
    // Current scanning session
    @Published var currentSession: ScanningSession?
    @Published var completedSessions: [ScanningSession] = []
    
    // Service references  
    var arMapper: AnyObject?  // Using AnyObject to avoid circular imports
    
    func setARMapper(_ mapper: AnyObject) {
        self.arMapper = mapper
    }
    
    func startNewSession() {
        currentSession = ScanningSession()
        pins.removeAll()
        isSessionRunning = true
    }
    
    func endCurrentSession() {
        currentSession?.endSession()
        if let session = currentSession {
            completedSessions.append(session)
        }
        isSessionRunning = false
    }
    
    var recentDetections: [PersonPin] {
        pins.filter { !$0.isStale }
    }
    
    func addPin(_ pin: PersonPin) {
        DispatchQueue.main.async {
            self.pins.append(pin)
        }
    }
    
    func removePin(_ pin: PersonPin) {
        DispatchQueue.main.async {
            self.pins.removeAll { $0.id == pin.id }
        }
    }
    
    func clearPins() {
        DispatchQueue.main.async {
            self.pins.removeAll()
        }
    }
}
