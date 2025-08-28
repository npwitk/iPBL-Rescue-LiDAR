//
//  BotVisualizationView.swift
//  Robot Controller (iPad)
//

import SwiftUI
import SceneKit
import simd

struct BotVisualizationView: View {
    @EnvironmentObject var networkCoordinator: LocalNetworkCoordinator
    @State private var sceneView = SCNView()
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var botNode = SCNNode()
    @State private var pathNodes: [SCNNode] = []
    @State private var detectionNodes: [SCNNode] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with connection status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Robot Visualization")
                        .font(.title2.bold())
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(networkCoordinator.connectionState.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let status = networkCoordinator.lastStatusUpdate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last Update: \(timeAgo(status.timestamp))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Detections: \(status.detections.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let battery = status.batteryLevel {
                            Text("Battery: \(Int(battery * 100))%")
                                .font(.caption)
                                .foregroundColor(battery > 0.2 ? .secondary : .red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // SceneKit View
            SceneKitView(
                scene: scene,
                cameraNode: cameraNode,
                botNode: botNode,
                onSceneSetup: setupScene
            )
            .onChange(of: networkCoordinator.lastStatusUpdate) { _, newStatus in
                if let status = newStatus {
                    updateVisualization(with: status)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch networkCoordinator.connectionState {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
    
    private func setupScene() {
        // Setup lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 400
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 800
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(10, 10, 10)
        lightNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(lightNode)
        
        // Setup camera
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 5, 8)
        cameraNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(cameraNode)
        
        // Create bot representation
        setupBotNode()
        
        // Add floor plane
        let floor = SCNFloor()
        floor.reflectivity = 0.1
        floor.firstMaterial?.diffuse.contents = UIColor.lightGray.withAlphaComponent(0.3)
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }
    
    private func setupBotNode() {
        // Create robot representation
        let robotGeometry = SCNBox(width: 0.3, height: 0.2, length: 0.4, chamferRadius: 0.05)
        robotGeometry.firstMaterial?.diffuse.contents = UIColor.systemBlue
        robotGeometry.firstMaterial?.specular.contents = UIColor.white
        
        botNode.geometry = robotGeometry
        botNode.position = SCNVector3Zero
        
        // Add direction indicator
        let arrowGeometry = SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.3)
        arrowGeometry.firstMaterial?.diffuse.contents = UIColor.systemRed
        let arrowNode = SCNNode(geometry: arrowGeometry)
        arrowNode.position = SCNVector3(0, 0.2, 0.2)
        arrowNode.rotation = SCNVector4(1, 0, 0, -Float.pi/2)
        botNode.addChildNode(arrowNode)
        
        scene.rootNode.addChildNode(botNode)
    }
    
    private func updateVisualization(with status: RobotStatusUpdate) {
        // Update bot position and orientation
        botNode.position = SCNVector3(status.position.x, status.position.y, status.position.z)
        
        // Convert quaternion to rotation
        let rotation = quaternionToRotation(status.orientation)
        botNode.rotation = SCNVector4(rotation.axis.x, rotation.axis.y, rotation.axis.z, rotation.angle)
        
        // Update device path
        updateDevicePath(status.devicePath)
        
        // Update person detections
        updateDetections(status.detections)
        
        // Update camera to follow bot
        updateCamera(botPosition: status.position)
    }
    
    private func updateDevicePath(_ path: [SIMD3<Float>]) {
        // Remove old path nodes
        pathNodes.forEach { $0.removeFromParentNode() }
        pathNodes.removeAll()
        
        // Create new path visualization
        for i in 1..<path.count {
            let start = path[i-1]
            let end = path[i]
            
            let distance = simd_distance(start, end)
            let direction = simd_normalize(end - start)
            let center = (start + end) / 2
            
            let cylinder = SCNCylinder(radius: 0.01, height: CGFloat(distance))
            cylinder.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.6)
            
            let pathNode = SCNNode(geometry: cylinder)
            pathNode.position = SCNVector3(center.x, center.y, center.z)
            
            // Orient cylinder along path segment
            let up = SIMD3<Float>(0, 1, 0)
            let axis = simd_cross(up, direction)
            let angle = acos(simd_dot(up, direction))
            
            if simd_length(axis) > 0.001 {
                pathNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
            }
            
            scene.rootNode.addChildNode(pathNode)
            pathNodes.append(pathNode)
        }
    }
    
    private func updateDetections(_ detections: [RobotStatusUpdate.DetectionUpdate]) {
        // Remove old detection nodes
        detectionNodes.forEach { $0.removeFromParentNode() }
        detectionNodes.removeAll()
        
        // Create new detection visualizations
        for detection in detections {
            let sphere = SCNSphere(radius: 0.15)
            
            // Color based on stability
            let color: UIColor = switch detection.stability {
            case "red": .systemRed
            case "orange": .systemOrange
            case "yellow": .systemYellow
            default: .gray
            }
            
            sphere.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.8)
            sphere.firstMaterial?.emission.contents = color.withAlphaComponent(0.3)
            
            let detectionNode = SCNNode(geometry: sphere)
            detectionNode.position = SCNVector3(detection.position.x, detection.position.y + 0.2, detection.position.z)
            
            // Add pulsing animation for active detections
            if !detection.isStale {
                let scaleAnimation = CABasicAnimation(keyPath: "scale")
                scaleAnimation.fromValue = NSValue(scnVector3: SCNVector3(0.8, 0.8, 0.8))
                scaleAnimation.toValue = NSValue(scnVector3: SCNVector3(1.2, 1.2, 1.2))
                scaleAnimation.duration = 1.0
                scaleAnimation.autoreverses = true
                scaleAnimation.repeatCount = .infinity
                detectionNode.addAnimation(scaleAnimation, forKey: "pulse")
            }
            
            scene.rootNode.addChildNode(detectionNode)
            detectionNodes.append(detectionNode)
        }
    }
    
    private func updateCamera(botPosition: SIMD3<Float>) {
        // Position camera to follow bot with offset
        let offset = SIMD3<Float>(0, 3, 5)
        let cameraPosition = botPosition + offset
        
        cameraNode.position = SCNVector3(cameraPosition.x, cameraPosition.y, cameraPosition.z)
        cameraNode.look(at: SCNVector3(botPosition.x, botPosition.y, botPosition.z))
    }
    
    private func quaternionToRotation(_ quaternion: SIMD4<Float>) -> (axis: SIMD3<Float>, angle: Float) {
        let w = quaternion.w
        let x = quaternion.x
        let y = quaternion.y
        let z = quaternion.z
        
        let angle = 2.0 * acos(abs(w))
        let s = sqrt(1.0 - w * w)
        
        let axis: SIMD3<Float>
        if s < 0.001 {
            axis = SIMD3<Float>(x, y, z)
        } else {
            axis = SIMD3<Float>(x / s, y / s, z / s)
        }
        
        return (axis, angle)
    }
}

struct SceneKitView: UIViewRepresentable {
    let scene: SCNScene
    let cameraNode: SCNNode
    let botNode: SCNNode
    let onSceneSetup: () -> Void
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = false
        sceneView.backgroundColor = UIColor.systemBackground
        sceneView.antialiasingMode = .multisampling4X
        
        onSceneSetup()
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update if needed
    }
}

#Preview {
    BotVisualizationView()
        .environmentObject(LocalNetworkCoordinator())
}