//
//  MapView.swift
//  Rescue Robot Sensor Head
//

import SwiftUI
import simd
import ARKit
import SceneKit

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @State private var showControls = true
    
    // Get the most recent completed session (only show 3D map after capture is done)
    private var displaySession: ScanningSession? {
        return appState.completedSessions.last
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let session = displaySession {
                // 3D LiDAR Map View using SceneKit
                LiDAR3DMapView(session: session)
                    .environmentObject(appState)
                
                // Map info overlay
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("3D LiDAR Map")
                                .font(.caption.bold())
                            Text("Session: \(session.startTime.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                            Text("Pins: \(session.detectedPins.count)")
                                .font(.caption)
                            Text("Meshes: \(getMeshCount())")
                                .font(.caption2)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            } else {
                // No session available
                VStack(spacing: 16) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No 3D Map Available")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Complete a session in the Explore tab to view the 3D LiDAR map")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Controls overlay
            if showControls, let session = displaySession {
                VStack {
                    HStack {
                        Map3DControlsView()
                            .environmentObject(appState)
                        Spacer()
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Pin list
                    if !session.detectedPins.isEmpty {
                        PinListView(
                            pins: session.detectedPins,
                            selectedPinId: appState.selectedPinId,
                            onSelectPin: selectPin
                        )
                        .padding(.bottom, 100) // Tab bar space
                    }
                }
            }
            
            // Toggle controls button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showControls.toggle() }) {
                        Image(systemName: showControls ? "eye.slash" : "eye")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
    
    private func selectPin(_ pin: PersonPin) {
        withAnimation(.easeInOut(duration: 0.3)) {
            appState.selectedPinId = pin.id
        }
    }
    
    private func getMeshCount() -> Int {
        if let arMapper = appState.arMapper as? ARMapper {
            return arMapper.meshAnchors.count
        }
        return 0
    }
}

// MARK: - 3D Map Components

struct LiDAR3DMapView: UIViewRepresentable {
    let session: ScanningSession
    @EnvironmentObject var appState: AppState
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = SCNScene()
        scnView.backgroundColor = UIColor.black
        
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true
        
        // Set up camera
        setupCamera(scnView)
        
        // Add content
        setupScene(scnView)
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        // Clear existing content and rebuild
        scnView.scene?.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        setupScene(scnView)
    }
    
    private func setupCamera(_ scnView: SCNView) {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.automaticallyAdjustsZRange = true
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2, 5)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        
        scnView.scene?.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
    }
    
    private func setupScene(_ scnView: SCNView) {
        guard let scene = scnView.scene else { return }
        
        // Add LiDAR mesh geometry
        if appState.showMesh, let arMapper = appState.arMapper as? ARMapper {
            addLiDARMeshes(to: scene, meshAnchors: arMapper.meshAnchors)
        }
        
        // Add device path
        if appState.showDevicePath {
            addDevicePath(to: scene, path: session.devicePath)
        }
        
        // Add person pins
        addPersonPins(to: scene, pins: session.detectedPins, selectedId: appState.selectedPinId)
        
        // Add ground plane for reference
        addGroundPlane(to: scene)
    }
    
    private func addLiDARMeshes(to scene: SCNScene, meshAnchors: [ARMeshAnchor]) {
        for meshAnchor in meshAnchors {
            if let scnGeometry = createSCNGeometry(from: meshAnchor.geometry) {
                let meshNode = SCNNode(geometry: scnGeometry)
                
                // Apply transform
                meshNode.simdTransform = meshAnchor.transform
                
                // Material
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.3)
                material.transparency = 1
                material.cullMode = .back
                material.isDoubleSided = true
                scnGeometry.materials = [material]
                
                scene.rootNode.addChildNode(meshNode)
            }
        }
    }
    
    private func createSCNGeometry(from arMesh: ARMeshGeometry) -> SCNGeometry? {
        let vertices = arMesh.vertices
        let faces = arMesh.faces
        
        let vertexCount = vertices.count
        let faceCount = faces.count
        
        guard vertexCount > 0, faceCount > 0 else { return nil }
        
        // Extract vertex data
        let vertexBuffer = vertices.buffer.contents()
        let vertexStride = vertices.stride
        
        var scnVertices: [SCNVector3] = []
        for i in 0..<vertexCount {
            let offset = i * vertexStride
            let vertex = vertexBuffer.advanced(by: offset).assumingMemoryBound(to: simd_float3.self).pointee
            scnVertices.append(SCNVector3(vertex.x, vertex.y, vertex.z))
        }
        
        // Extract face indices
        let faceBuffer = faces.buffer.contents()
        let bytesPerIndex = faces.bytesPerIndex
        
        var indices: [Int32] = []
        for i in 0..<(faceCount * 3) {
            let offset = i * bytesPerIndex
            let index: Int32
            
            if bytesPerIndex == 2 {
                index = Int32(faceBuffer.advanced(by: offset).assumingMemoryBound(to: UInt16.self).pointee)
            } else {
                index = Int32(faceBuffer.advanced(by: offset).assumingMemoryBound(to: UInt32.self).pointee)
            }
            indices.append(index)
        }
        
        // Create SCNGeometry
        let vertexSource = SCNGeometrySource(vertices: scnVertices)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles, primitiveCount: faceCount, bytesPerIndex: MemoryLayout<Int32>.size)
        
        return SCNGeometry(sources: [vertexSource], elements: [element])
    }
    
    private func addDevicePath(to scene: SCNScene, path: [simd_float3]) {
        guard path.count > 1 else { return }
        
        let pathNode = SCNNode()
        
        for i in 0..<(path.count - 1) {
            let start = path[i]
            let end = path[i + 1]
            
            let lineGeometry = createLineGeometry(from: SCNVector3(start), to: SCNVector3(end))
            let lineNode = SCNNode(geometry: lineGeometry)
            
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemGreen
            material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.3)
            lineGeometry.materials = [material]
            
            pathNode.addChildNode(lineNode)
        }
        
        scene.rootNode.addChildNode(pathNode)
    }
    
    private func addPersonPins(to scene: SCNScene, pins: [PersonPin], selectedId: UUID?) {
        for pin in pins where pin.worldPosition != simd_float3(0, 0, 0) {
            let isSelected = pin.id == selectedId
            let pinNode = createPersonPinNode(for: pin, isSelected: isSelected)
            pinNode.position = SCNVector3(pin.worldPosition)
            scene.rootNode.addChildNode(pinNode)
        }
    }
    
    private func createPersonPinNode(for pin: PersonPin, isSelected: Bool) -> SCNNode {
        let parentNode = SCNNode()
        
        // Main pin cylinder
        let radius: CGFloat = isSelected ? 0.06 : 0.04
        let height: CGFloat = isSelected ? 0.3 : 0.2
        
        let cylinder = SCNCylinder(radius: radius, height: height)
        let pinNode = SCNNode(geometry: cylinder)
        
        let color: UIColor = switch pin.stability {
        case .singleFrame: .systemYellow
        case .multiFrame: .systemOrange
        case .corroborated: .systemRed
        }
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color.withAlphaComponent(0.3)
        material.specular.contents = UIColor.white.withAlphaComponent(0.5)
        cylinder.materials = [material]
        
        pinNode.position.y = Float(height / 2)
        parentNode.addChildNode(pinNode)
        
        // Add a glowing base ring
        let ringRadius: CGFloat = isSelected ? 0.12 : 0.08
        let ring = SCNTorus(ringRadius: ringRadius, pipeRadius: 0.01)
        let ringNode = SCNNode(geometry: ring)
        
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = color.withAlphaComponent(0.6)
        ringMaterial.emission.contents = color.withAlphaComponent(0.8)
        ring.materials = [ringMaterial]
        
        ringNode.position.y = 0.01
        parentNode.addChildNode(ringNode)
        
        // Add floating person icon above pin
        let iconHeight: Float = 0.05
        let iconNode = createPersonIconNode(color: color, size: isSelected ? 0.08 : 0.06)
        iconNode.position.y = Float(height) + iconHeight
        parentNode.addChildNode(iconNode)
        
        if isSelected {
            // Pulsing animation for the entire pin
            let pulseAction = SCNAction.repeatForever(SCNAction.sequence([
                SCNAction.scale(to: 1.1, duration: 0.8),
                SCNAction.scale(to: 1.0, duration: 0.8)
            ]))
            parentNode.runAction(pulseAction)
            
            // Ring rotation animation
            let rotateAction = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 3.0))
            ringNode.runAction(rotateAction)
        }
        
        return parentNode
    }
    
    private func createPersonIconNode(color: UIColor, size: CGFloat) -> SCNNode {
        // Create a simple person icon using basic shapes
        let parentNode = SCNNode()
        
        // Head (sphere)
        let headRadius = size * 0.25
        let head = SCNSphere(radius: headRadius)
        let headNode = SCNNode(geometry: head)
        
        let headMaterial = SCNMaterial()
        headMaterial.diffuse.contents = color
        headMaterial.emission.contents = color.withAlphaComponent(0.2)
        head.materials = [headMaterial]
        
        headNode.position.y = Float(size * 0.6)
        parentNode.addChildNode(headNode)
        
        // Body (cylinder)
        let bodyRadius = size * 0.15
        let bodyHeight = size * 0.5
        let body = SCNCylinder(radius: bodyRadius, height: bodyHeight)
        let bodyNode = SCNNode(geometry: body)
        
        let bodyMaterial = SCNMaterial()
        bodyMaterial.diffuse.contents = color
        bodyMaterial.emission.contents = color.withAlphaComponent(0.2)
        body.materials = [bodyMaterial]
        
        bodyNode.position.y = Float(bodyHeight / 2)
        parentNode.addChildNode(bodyNode)
        
        return parentNode
    }
    
    private func createLineGeometry(from start: SCNVector3, to end: SCNVector3) -> SCNGeometry {
        let vertices = [start, end]
        let indices: [Int32] = [0, 1]
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData, primitiveType: .line, primitiveCount: 1, bytesPerIndex: MemoryLayout<Int32>.size)
        
        return SCNGeometry(sources: [vertexSource], elements: [element])
    }
    
    private func addGroundPlane(to scene: SCNScene) {
        let plane = SCNPlane(width: 10, height: 10)
        let planeNode = SCNNode(geometry: plane)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.1)
        material.transparency = 0.9
        plane.materials = [material]
        
        planeNode.eulerAngles.x = -Float.pi / 2 // Rotate to be horizontal
        planeNode.position.y = -0.01 // Slightly below ground level
        
        scene.rootNode.addChildNode(planeNode)
    }
}

struct Map3DControlsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3D Map Controls")
                .font(.caption.bold())
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("LiDAR Mesh", isOn: $appState.showMesh)
                Toggle("Device Path", isOn: $appState.showDevicePath)
            }
            .font(.caption)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            Text("Drag: Orbit camera\nPinch: Zoom\nTwo fingers: Pan")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
}

struct PinListView: View {
    let pins: [PersonPin]
    let selectedPinId: UUID?
    let onSelectPin: (PersonPin) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(pins) { pin in
                    PinListItem(
                        pin: pin,
                        isSelected: pin.id == selectedPinId,
                        onTap: { onSelectPin(pin) }
                    )
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
    }
}

struct PinListItem: View {
    @ObservedObject var pin: PersonPin
    let isSelected: Bool
    let onTap: () -> Void
    
    private var pinColor: Color {
        switch pin.stability {
        case .singleFrame: return .yellow
        case .multiFrame: return .orange
        case .corroborated: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Circle()
                    .fill(pinColor)
                    .frame(width: 16, height: 16)
                
                Text("\(Int(pin.confidence * 100))%")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                
                Text(pin.id.uuidString.prefix(6))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.2) : Color.black.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1)
            )
        }
    }
}


#Preview {
    let appState = {
        let state = AppState()
        let samplePins = [
            PersonPin(initialDetection: PersonDetection(confidence: 0.8, screenPoint: .zero)),
            PersonPin(initialDetection: PersonDetection(confidence: 0.6, screenPoint: .zero)),
            PersonPin(initialDetection: PersonDetection(confidence: 0.9, screenPoint: .zero))
        ]
        samplePins[0].worldPosition = simd_float3(1, 0, 1)
        samplePins[1].worldPosition = simd_float3(-1, 0, 2)
        samplePins[1].stability = .multiFrame
        samplePins[2].worldPosition = simd_float3(0, 0, -1)
        samplePins[2].stability = .corroborated
        
        state.pins = samplePins
        return state
    }()
    
    return MapView()
        .environmentObject(appState)
}
