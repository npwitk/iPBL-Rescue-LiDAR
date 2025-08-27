//
//  ARMapper.swift
//  Rescue Robot Sensor Head
//

import Foundation
import ARKit
import RealityKit
import Combine
import simd

class ARMapper: NSObject, ObservableObject {
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var isSessionRunning = false
    @Published var devicePath: [simd_float3] = []
    @Published var meshAnchors: [ARMeshAnchor] = []
    
    private var arView: ARView?
    private var session: ARSession { arView?.session ?? ARSession() }
    private var frameDelegate: ARFrameDelegate?
    private var cancellables = Set<AnyCancellable>()
    private var lastPathUpdate = Date()
    private weak var appState: AppState?
    
    // RoomPlan integration
    private var roomPlanAnchor: ARAnchor?
    
    override init() {
        super.init()
    }
    
    func configure(with arView: ARView, frameDelegate: ARFrameDelegate, appState: AppState) {
        self.arView = arView
        self.frameDelegate = frameDelegate
        self.appState = appState
        
        session.delegate = self
        arView.session.delegate = self
        
        setupARConfiguration()
    }
    
    private func setupARConfiguration() {
        // Just prepare the AR view, don't run the session yet
        guard let arView = arView else { return }
        arView.automaticallyConfigureSession = false
    }
    
    private func createARConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable scene reconstruction with LiDAR if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        // Enable frame semantics for depth if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.isAutoFocusEnabled = true
        
        return configuration
    }
    
    func startSession() {
        guard let arView = arView else { return }
        
        if !isSessionRunning {
            let configuration = createARConfiguration()
            arView.session.run(configuration)
            isSessionRunning = true
            print("🚀 AR Session started with scanning")
        }
    }
    
    func stopSession() {
        session.pause()
        isSessionRunning = false
        devicePath.removeAll()
    }
    
    func raycast(from screenPoint: CGPoint) -> simd_float3? {
        guard let arView = arView else { return nil }
        
        // Try multiple raycast methods for better reliability
        
        // 1. First try: Existing plane geometry (most accurate)
        if let query = arView.raycast(from: screenPoint, allowing: .existingPlaneGeometry, alignment: .any).first {
            return simd_float3(query.worldTransform.columns.3.x,
                              query.worldTransform.columns.3.y,
                              query.worldTransform.columns.3.z)
        }
        
        // 2. Second try: Estimated planes (less accurate but more permissive)
        if let query = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any).first {
            return simd_float3(query.worldTransform.columns.3.x,
                              query.worldTransform.columns.3.y,
                              query.worldTransform.columns.3.z)
        }
        
        // 3. Final fallback: Use camera transform with estimated depth
        let camera = arView.session.currentFrame?.camera
        if let camera = camera {
            // Estimate a position 2 meters in front of camera
            let cameraTransform = camera.transform
            let forward = simd_float3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
            let cameraPosition = simd_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            
            return cameraPosition + (forward * 2.0) // 2 meters forward
        }
        
        return nil
    }
    
    func addAnchor(at worldPosition: simd_float3, for pin: PersonPin) {
        let transform = simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1)
        )
        
        let anchor = ARAnchor(name: "person_\(pin.id.uuidString)", transform: transform)
        session.add(anchor: anchor)
        pin.anchor = anchor
    }
    
    func removeAnchor(for pin: PersonPin) {
        if let anchor = pin.anchor {
            session.remove(anchor: anchor)
            pin.anchor = nil
        }
    }
    
    // RoomPlan import functionality
    func importRoomPlan(from url: URL) async -> Bool {
        // In a real implementation, this would load and process a RoomPlan .usdz file
        // For now, we'll simulate successful import
        return true
    }
    
    func exportWorldMap() async -> ARWorldMap? {
        return await withCheckedContinuation { continuation in
            session.getCurrentWorldMap { worldMap, error in
                if let worldMap = worldMap {
                    continuation.resume(returning: worldMap)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func updateDevicePath(_ transform: simd_float4x4) {
        let position = simd_float3(transform.columns.3.x,
                                  transform.columns.3.y,
                                  transform.columns.3.z)
        
        // Only update path every 0.5 seconds to avoid too much data
        if Date().timeIntervalSince(lastPathUpdate) > 0.5 {
            devicePath.append(position)
            lastPathUpdate = Date()
            
            // Add to current session
            appState?.currentSession?.addDevicePosition(position)
            
            // Keep only last 1000 points
            if devicePath.count > 1000 {
                devicePath.removeFirst(devicePath.count - 1000)
            }
        }
    }
}

// MARK: - ARSessionDelegate
extension ARMapper: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update tracking state
        DispatchQueue.main.async {
            self.trackingState = frame.camera.trackingState
        }
        
        // Update device path
        updateDevicePath(frame.camera.transform)
        
        // Pass frame to pose detection
        frameDelegate?.session(session, didUpdate: frame)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                DispatchQueue.main.async {
                    self.meshAnchors.append(meshAnchor)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                DispatchQueue.main.async {
                    if let index = self.meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
                        self.meshAnchors[index] = meshAnchor
                    }
                }
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                DispatchQueue.main.async {
                    self.meshAnchors.removeAll { $0.identifier == meshAnchor.identifier }
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isSessionRunning = false
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.isSessionRunning = false
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Only restart if the user had previously started the session
        if appState?.isSessionRunning == true {
            startSession()
        }
    }
}

// MARK: - Frame Delegate Protocol
protocol ARFrameDelegate: AnyObject {
    func session(_ session: ARSession, didUpdate frame: ARFrame)
}