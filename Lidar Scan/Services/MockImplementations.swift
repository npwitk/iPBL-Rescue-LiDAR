//
//  MockImplementations.swift
//  Rescue Robot Sensor Head
//

import Foundation
import simd
import SwiftUI
import Combine

#if targetEnvironment(simulator)

// MARK: - Mock AR Mapper
class MockARMapper: ARMapper {
    private var mockTimer: Timer?
    private var mockDevicePosition = simd_float3(0, 0, 0)
    
    override init() {
        super.init()
        startMockSession()
    }
    
    private func startMockSession() {
        // Simulate device movement
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Update mock device position
            self.mockDevicePosition.x += Float.random(in: -0.5...0.5)
            self.mockDevicePosition.z += Float.random(in: -0.5...0.5)
            
            DispatchQueue.main.async {
                self.devicePath.append(self.mockDevicePosition)
                
                // Keep path manageable
                if self.devicePath.count > 100 {
                    self.devicePath.removeFirst()
                }
            }
        }
    }
    
    override func raycast(from screenPoint: CGPoint) -> simd_float3? {
        // Return a mock world position based on screen point
        let normalizedX = Float(screenPoint.x / UIScreen.main.bounds.width - 0.5) * 10
        let normalizedZ = Float(screenPoint.y / UIScreen.main.bounds.height - 0.5) * 10
        
        return simd_float3(normalizedX, 0, normalizedZ)
    }
    
    override func startSession() {
        DispatchQueue.main.async {
            self.isSessionRunning = true
            self.trackingState = .normal
        }
    }
    
    override func stopSession() {
        mockTimer?.invalidate()
        mockTimer = nil
        
        DispatchQueue.main.async {
            self.isSessionRunning = false
            self.devicePath.removeAll()
        }
    }
    
    deinit {
        mockTimer?.invalidate()
    }
}

// MARK: - Mock Pose Service
class MockPoseService: PoseService {
    private var mockTimer: Timer?
    private var mockPersonDetections: [CGPoint] = []
    private weak var mockPinTracker: MockPinTracker?
    
    override init() {
        super.init()
        generateMockDetections()
    }
    
    func configure(with pinTracker: MockPinTracker) {
        self.mockPinTracker = pinTracker
    }
    
    private func generateMockDetections() {
        // Create some mock person positions on screen
        mockPersonDetections = [
            CGPoint(x: 0.3, y: 0.4), // Normalized coordinates
            CGPoint(x: 0.7, y: 0.3),
            CGPoint(x: 0.5, y: 0.6),
            CGPoint(x: 0.2, y: 0.8)
        ]
    }
    
    override func startProcessing() {
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        // Start generating mock detections
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / frameProcessingRate, repeats: true) { [weak self] _ in
            self?.generateMockDetection()
        }
    }
    
    override func stopProcessing() {
        mockTimer?.invalidate()
        mockTimer = nil
        
        DispatchQueue.main.async {
            self.isProcessing = false
        }
    }
    
    private func generateMockDetection() {
        guard !mockPersonDetections.isEmpty else { return }
        
        // Randomly select a detection point
        let detectionPoint = mockPersonDetections.randomElement()!
        
        // Add some noise to make it realistic
        let noisyPoint = CGPoint(
            x: detectionPoint.x + Double.random(in: -0.1...0.1),
            y: detectionPoint.y + Double.random(in: -0.1...0.1)
        )
        
        // Convert to screen coordinates
        let screenSize = UIScreen.main.bounds.size
        let screenPoint = CGPoint(
            x: noisyPoint.x * screenSize.width,
            y: noisyPoint.y * screenSize.height
        )
        
        // Create mock pose with basic joints
        let mockJoints: [String: CGPoint] = [
            "neck": noisyPoint,
            "root": CGPoint(x: noisyPoint.x, y: noisyPoint.y + 0.1),
            "left_ankle": CGPoint(x: noisyPoint.x - 0.05, y: noisyPoint.y + 0.2),
            "right_ankle": CGPoint(x: noisyPoint.x + 0.05, y: noisyPoint.y + 0.2)
        ]
        
        let mockPose = HumanBodyPose(
            joints: mockJoints,
            confidence: Float.random(in: 0.5...0.95)
        )
        
        let detection = PersonDetection(
            confidence: mockPose.confidence,
            screenPoint: screenPoint,
            pose: mockPose
        )
        
        // Send to pin tracker if available
        DispatchQueue.main.async { [weak self] in
            if let mockPinTracker = self?.mockPinTracker {
                // Create a mock detection with world position already set
                let mockWorldPos = simd_float3(
                    Float(screenPoint.x / UIScreen.main.bounds.width - 0.5) * 10,
                    0,
                    Float(screenPoint.y / UIScreen.main.bounds.height - 0.5) * 10
                )
                let detectionWithWorld = PersonDetection(
                    id: detection.id,
                    confidence: detection.confidence,
                    screenPoint: screenPoint,
                    worldPosition: mockWorldPos,
                    pose: detection.pose
                )
                mockPinTracker.processMockDetection(detectionWithWorld)
            }
        }
    }
    
    deinit {
        mockTimer?.invalidate()
    }
}

// MARK: - Mock ARFrame and ARView (placeholder classes)
class MockARFrame {
    // Minimal mock implementation
}

class MockARView {
    let bounds = UIScreen.main.bounds
    
    // Mock raycast method
    func raycast(from point: CGPoint) -> simd_float3? {
        let normalizedX = Float(point.x / bounds.width - 0.5) * 10
        let normalizedZ = Float(point.y / bounds.height - 0.5) * 10
        return simd_float3(normalizedX, 0, normalizedZ)
    }
}

// MARK: - Mock Pin Tracker
class MockPinTracker: PinTracker {
    
    override func configure(with arMapper: ARMapper, appState: AppState) {
        self.arMapper = arMapper
        self.appState = appState
        
        // Start cleanup timer for mock implementation
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.cleanupStaleDetections()
        }
    }
    
    func processMockDetection(_ detection: PersonDetection) {
        guard let worldPosition = detection.worldPosition else { return }
        
        // Find nearby existing pin or create new one
        if let existingPin = findNearbyPin(worldPosition: worldPosition) {
            existingPin.addDetection(detection)
        } else {
            createNewMockPin(from: detection)
        }
        
        syncWithAppState()
    }
    
    private func findNearbyPin(worldPosition: simd_float3) -> PersonPin? {
        return pins.first { pin in
            let distance = simd_distance(pin.worldPosition, worldPosition)
            return distance < 1.5 // Increased threshold for simulator
        }
    }
    
    private func createNewMockPin(from detection: PersonDetection) {
        guard let worldPosition = detection.worldPosition else { return }
        
        let newPin = PersonPin(initialDetection: detection)
        newPin.worldPosition = worldPosition
        
        pins.append(newPin)
        
        print("Created mock pin at \(worldPosition)")
    }
    
    private func syncWithAppState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.appState?.pins = self.pins
        }
    }
}

#endif // targetEnvironment(simulator)