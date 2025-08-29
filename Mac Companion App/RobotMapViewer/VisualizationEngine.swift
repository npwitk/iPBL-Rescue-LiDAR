//
//  VisualizationEngine.swift
//  Robot Map Viewer
//

import Foundation
import SceneKit
import simd
import Combine

class VisualizationEngine: ObservableObject {
    @Published var scene = SCNScene()
    @Published var cameraNode = SCNNode()
    
    // Scene nodes
    private var robotNode: SCNNode?
    private var robotPathNode: SCNNode?
    private var meshNodes: [String: SCNNode] = [:]
    private var detectionNodes: [String: SCNNode] = [:]
    private var robotPathPoints: [SCNVector3] = []
    
    // Visualization settings
    @Published var showCoordinateSystem = true
    @Published var robotPathOpacity: Float = 0.7
    @Published var meshOpacity: Float = 0.3
    
    init() {
        setupScene()
        setupCamera()
        setupLighting()
        setupCoordinateSystem()
    }
    
    // MARK: - Scene Setup
    private func setupScene() {
        scene.background.contents = NSColor.black
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
    }
    
    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.automaticallyAdjustsZRange = true
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 2, 5)
        cameraNode.eulerAngles = SCNVector3(-0.2, 0, 0)
        
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func setupLighting() {
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor.white
        ambientLight.light?.intensity = 400
        scene.rootNode.addChildNode(ambientLight)
        
        // Directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = NSColor.white
        directionalLight.light?.intensity = 800
        directionalLight.position = SCNVector3(2, 4, 2)
        directionalLight.eulerAngles = SCNVector3(-45.degreesToRadians, 30.degreesToRadians, 0)
        scene.rootNode.addChildNode(directionalLight)
    }
    
    private func setupCoordinateSystem() {
        let coordinateSystem = createCoordinateSystemNode()
        coordinateSystem.name = "coordinateSystem"
        scene.rootNode.addChildNode(coordinateSystem)
    }
    
    private func createCoordinateSystemNode() -> SCNNode {
        let node = SCNNode()
        
        // X axis (red)
        let xAxis = SCNNode(geometry: SCNCylinder(radius: 0.005, height: 1.0))
        xAxis.geometry?.firstMaterial?.diffuse.contents = NSColor.red
        xAxis.position = SCNVector3(0.5, 0, 0)
        xAxis.eulerAngles = SCNVector3(0, 0, -90.degreesToRadians)
        node.addChildNode(xAxis)
        
        // Y axis (green)
        let yAxis = SCNNode(geometry: SCNCylinder(radius: 0.005, height: 1.0))
        yAxis.geometry?.firstMaterial?.diffuse.contents = NSColor.green
        yAxis.position = SCNVector3(0, 0.5, 0)
        node.addChildNode(yAxis)
        
        // Z axis (blue)
        let zAxis = SCNNode(geometry: SCNCylinder(radius: 0.005, height: 1.0))
        zAxis.geometry?.firstMaterial?.diffuse.contents = NSColor.blue
        zAxis.position = SCNVector3(0, 0, 0.5)
        zAxis.eulerAngles = SCNVector3(90.degreesToRadians, 0, 0)
        node.addChildNode(zAxis)
        
        return node
    }
    
    // MARK: - Robot Visualization
    func updateRobotPosition(_ position: simd_float3, rotation: simd_quatf) {
        if robotNode == nil {
            createRobotNode()
        }
        
        let scnPosition = SCNVector3(position.x, position.y, position.z)
        let scnRotation = SCNVector4(rotation.vector.x, rotation.vector.y, rotation.vector.z, rotation.vector.w)
        
        robotNode?.position = scnPosition
        robotNode?.rotation = scnRotation
        
        // Update robot path
        updateRobotPath(scnPosition)
    }
    
    private func createRobotNode() {
        // Create iPhone-like device representation
        let deviceGeometry = SCNBox(width: 0.07, height: 0.14, length: 0.008, chamferRadius: 0.01)
        deviceGeometry.firstMaterial?.diffuse.contents = NSColor.darkGray
        deviceGeometry.firstMaterial?.metalness.contents = 0.7
        deviceGeometry.firstMaterial?.roughness.contents = 0.3
        
        robotNode = SCNNode(geometry: deviceGeometry)
        robotNode?.name = "robot"
        
        // Add camera indicator (small sphere on top)
        let cameraIndicator = SCNNode(geometry: SCNSphere(radius: 0.01))
        cameraIndicator.geometry?.firstMaterial?.diffuse.contents = NSColor.blue
        cameraIndicator.position = SCNVector3(0, 0.08, 0.01)
        robotNode?.addChildNode(cameraIndicator)
        
        // Add coordinate frame for robot
        let robotFrame = createCoordinateSystemNode()
        robotFrame.scale = SCNVector3(0.1, 0.1, 0.1)
        robotNode?.addChildNode(robotFrame)
        
        scene.rootNode.addChildNode(robotNode!)
    }
    
    private func updateRobotPath(_ position: SCNVector3) {
        robotPathPoints.append(position)
        
        // Keep only recent path points
        if robotPathPoints.count > 1000 {
            robotPathPoints.removeFirst(robotPathPoints.count - 1000)
        }
        
        updateRobotPathGeometry()
    }
    
    private func updateRobotPathGeometry() {
        robotPathNode?.removeFromParentNode()
        
        guard robotPathPoints.count > 1 else { return }
        
        // Create path geometry
        let pathGeometry = createPathGeometry(points: robotPathPoints)
        robotPathNode = SCNNode(geometry: pathGeometry)
        robotPathNode?.name = "robotPath"
        
        scene.rootNode.addChildNode(robotPathNode!)
    }
    
    private func createPathGeometry(points: [SCNVector3]) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        for i in 0..<points.count - 1 {
            vertices.append(points[i])
            vertices.append(points[i + 1])
            
            let baseIndex = Int32(i * 2)
            indices.append(baseIndex)
            indices.append(baseIndex + 1)
        }
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexSource = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [indexSource])
        geometry.firstMaterial?.diffuse.contents = NSColor.cyan
        geometry.firstMaterial?.isDoubleSided = true
        
        return geometry
    }
    
    // MARK: - Person Detection Visualization
    func updatePersonDetection(_ detection: RemotePersonDetection) {
        let nodeId = detection.id
        
        if detectionNodes[nodeId] == nil {
            createDetectionNode(detection)
        } else {
            updateDetectionNode(detection)
        }
    }
    
    private func createDetectionNode(_ detection: RemotePersonDetection) {
        let sphere = SCNSphere(radius: 0.05)
        sphere.firstMaterial?.diffuse.contents = detection.stabilityColor
        sphere.firstMaterial?.emission.contents = detection.stabilityColor
        sphere.firstMaterial?.transparency = 0.8
        
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(detection.position.x, detection.position.y, detection.position.z)
        node.name = "detection_\(detection.id)"
        
        // Add text label
        let text = SCNText(string: "Person\n\(Int(detection.confidence * 100))%", extrusionDepth: 0.01)
        text.font = NSFont.systemFont(ofSize: 0.02)
        text.firstMaterial?.diffuse.contents = NSColor.white
        
        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(0, 0.1, 0)
        textNode.scale = SCNVector3(0.3, 0.3, 0.3)
        
        // Billboard constraint to always face camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .Y
        textNode.constraints = [billboardConstraint]
        
        node.addChildNode(textNode)
        
        detectionNodes[detection.id] = node
        scene.rootNode.addChildNode(node)
        
        // Animate appearance
        node.opacity = 0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        node.opacity = 1
        SCNTransaction.commit()
    }
    
    private func updateDetectionNode(_ detection: RemotePersonDetection) {
        guard let node = detectionNodes[detection.id] else { return }
        
        // Update position and color
        node.position = SCNVector3(detection.position.x, detection.position.y, detection.position.z)
        node.geometry?.firstMaterial?.diffuse.contents = detection.stabilityColor
        node.geometry?.firstMaterial?.emission.contents = detection.stabilityColor
        
        // Update label
        if let textNode = node.childNodes.first(where: { $0.geometry is SCNText }),
           let text = textNode.geometry as? SCNText {
            text.string = "Person\n\(Int(detection.confidence * 100))%"
        }
    }
    
    // MARK: - Mesh Visualization
    func updateMesh(_ meshData: RemoteMeshData) {
        let nodeId = meshData.anchorId
        
        // Remove existing mesh node
        meshNodes[nodeId]?.removeFromParentNode()
        
        // Create new mesh geometry
        if let geometry = createMeshGeometry(meshData) {
            let node = SCNNode(geometry: geometry)
            node.name = "mesh_\(nodeId)"
            
            // Apply transform
            node.transform = SCNMatrix4(meshData.transform)
            
            meshNodes[nodeId] = node
            scene.rootNode.addChildNode(node)
        }
    }
    
    private func createMeshGeometry(_ meshData: RemoteMeshData) -> SCNGeometry? {
        guard !meshData.vertices.isEmpty, !meshData.faces.isEmpty else { return nil }
        
        let vertices = meshData.vertices.map { SCNVector3($0.x, $0.y, $0.z) }
        let indices = meshData.faces.map { Int32($0) }
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexSource = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [indexSource])
        
        // Mesh material
        geometry.firstMaterial?.fillMode = .lines
        geometry.firstMaterial?.diffuse.contents = NSColor.white
        geometry.firstMaterial?.transparency = CGFloat(meshOpacity)
        geometry.firstMaterial?.isDoubleSided = true
        
        return geometry
    }
    
    // MARK: - Camera Controls
    func focusOnDetection(_ detection: RemotePersonDetection) {
        let position = SCNVector3(detection.position.x, detection.position.y + 1, detection.position.z + 2)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        cameraNode.position = position
        cameraNode.look(at: SCNVector3(detection.position.x, detection.position.y, detection.position.z))
        SCNTransaction.commit()
    }
    
    func resetCamera() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        cameraNode.position = SCNVector3(0, 2, 5)
        cameraNode.eulerAngles = SCNVector3(-0.2, 0, 0)
        SCNTransaction.commit()
    }
}

// MARK: - Extensions
extension Float {
    var degreesToRadians: Float {
        return self * .pi / 180.0
    }
}

extension SCNMatrix4 {
    init(_ matrix: simd_float4x4) {
        self.init(
            m11: matrix.columns.0.x, m12: matrix.columns.1.x, m13: matrix.columns.2.x, m14: matrix.columns.3.x,
            m21: matrix.columns.0.y, m22: matrix.columns.1.y, m23: matrix.columns.2.y, m24: matrix.columns.3.y,
            m31: matrix.columns.0.z, m32: matrix.columns.1.z, m33: matrix.columns.2.z, m34: matrix.columns.3.z,
            m41: matrix.columns.0.w, m42: matrix.columns.1.w, m43: matrix.columns.2.w, m44: matrix.columns.3.w
        )
    }
}