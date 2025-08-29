//
//  PinTracker.swift
//  Rescue Robot Sensor Head
//

import Foundation
import ARKit
import RealityKit
import simd
import UIKit

class PinTracker: ObservableObject {
    @Published var pins: [PersonPin] = []
    
    private weak var arMapper: ARMapper?
    private weak var appState: AppState?
    private let proximityThreshold: Float = 0.8 // meters - reduced for better clustering
    private let confidenceDecayRate: Float = 0.95
    private let maxPinAge: TimeInterval = 30.0
    
    // Haptic feedback
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    func configure(with arMapper: ARMapper, appState: AppState) {
        self.arMapper = arMapper
        self.appState = appState
        
        // Start cleanup timer
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.cleanupStaleDetections()
        }
    }
    
    func processDetection(_ detection: PersonDetection, frame: ARFrame, arView: ARView) {
        // Raycast to get 3D world position
        guard let worldPosition = arMapper?.raycast(from: detection.screenPoint) else {
            print("Failed to raycast detection at screen point: \(detection.screenPoint)")
            return
        }
        
        print("Raycast successful: \(worldPosition)")
        
        // Create detection with world position
        let detectionWithWorld = PersonDetection(
            id: detection.id,
            confidence: detection.confidence,
            screenPoint: detection.screenPoint,
            worldPosition: worldPosition,
            pose: detection.pose
        )
        
        // Find nearby existing pin or create new one
        if let existingPin = findNearbyPin(worldPosition: worldPosition) {
            print("Adding to existing pin: \(existingPin.id)")
            updateExistingPin(existingPin, with: detectionWithWorld)
        } else {
            print("Creating new pin at position: \(worldPosition)")
            createNewPin(from: detectionWithWorld)
        }
        
        // Update app state
        syncWithAppState()
    }
    
    private func findNearbyPin(worldPosition: simd_float3) -> PersonPin? {
        return pins.first { pin in
            let distance = simd_distance(pin.worldPosition, worldPosition)
            return distance < proximityThreshold
        }
    }
    
    private func updateExistingPin(_ pin: PersonPin, with detection: PersonDetection) {
        let previousStability = pin.stability
        
        pin.addDetection(detection)
        
        // Update anchor position if we have better accuracy
        if detection.confidence > pin.confidence * 0.8 {
            arMapper?.removeAnchor(for: pin)
            if let worldPos = detection.worldPosition {
                pin.worldPosition = worldPos
                arMapper?.addAnchor(at: worldPos, for: pin)
            }
        }
        
        // Stream person detection update to Mac
        arMapper?.streamPersonDetection(pin)
        
        // Trigger haptic feedback on stability promotion
        if pin.stability != previousStability && pin.stability.rawValue > previousStability.rawValue {
            DispatchQueue.main.async {
                self.hapticFeedback.impactOccurred()
            }
        }
    }
    
    private func createNewPin(from detection: PersonDetection) {
        guard let worldPosition = detection.worldPosition else { return }
        
        let newPin = PersonPin(initialDetection: detection)
        newPin.worldPosition = worldPosition
        
        pins.append(newPin)
        arMapper?.addAnchor(at: worldPosition, for: newPin)
        
        // Add to current session
        appState?.currentSession?.addPin(newPin)
        
        // Stream new person detection to Mac
        arMapper?.streamPersonDetection(newPin)
        
        print("Created new pin at \(worldPosition)")
    }
    
    private func cleanupStaleDetections() {
        var pinsToRemove: [PersonPin] = []
        
        for pin in pins {
            // Apply confidence decay
            pin.confidence *= confidenceDecayRate
            
            // Mark stale pins for removal
            if pin.isStale || pin.age > maxPinAge || pin.confidence < 0.1 {
                pinsToRemove.append(pin)
            }
        }
        
        // Remove stale pins
        for pin in pinsToRemove {
            removePin(pin)
        }
        
        if !pinsToRemove.isEmpty {
            syncWithAppState()
        }
    }
    
    private func removePin(_ pin: PersonPin) {
        arMapper?.removeAnchor(for: pin)
        pins.removeAll { $0.id == pin.id }
        print("Removed stale pin: \(pin.id)")
    }
    
    func clearAllPins() {
        for pin in pins {
            arMapper?.removeAnchor(for: pin)
        }
        pins.removeAll()
        syncWithAppState()
    }
    
    private func syncWithAppState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.appState?.pins = self.pins
        }
    }
    
    // Manual pin management
    func promotePin(_ pin: PersonPin) {
        switch pin.stability {
        case .singleFrame:
            pin.stability = .multiFrame
        case .multiFrame:
            pin.stability = .corroborated
        case .corroborated:
            break
        }
        
        hapticFeedback.impactOccurred()
        syncWithAppState()
    }
    
    func demotePin(_ pin: PersonPin) {
        switch pin.stability {
        case .corroborated:
            pin.stability = .multiFrame
        case .multiFrame:
            pin.stability = .singleFrame
        case .singleFrame:
            break
        }
        
        syncWithAppState()
    }
    
    // Statistics
    var totalDetections: Int {
        pins.reduce(0) { $0 + $1.detectionHistory.count }
    }
    
    var activeDetections: Int {
        pins.count { !$0.isStale }
    }
    
    var stabilityDistribution: [PinStability: Int] {
        var distribution: [PinStability: Int] = [:]
        for stability in PinStability.allCases {
            distribution[stability] = pins.count { $0.stability == stability }
        }
        return distribution
    }
}
