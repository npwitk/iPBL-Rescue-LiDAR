//
//  SceneViewWrapper.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 28/04/25.
//

import SwiftUI
import SceneKit

struct SceneViewWrapper: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let rootVC = windowScene?.keyWindow?.rootViewController
        return Coordinator(scene: scene, viewController: rootVC)
    }
    let scene: SCNScene?
    func makeUIView(context: Context) -> some UIView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = UIColor.darkGray  // Changed to dark gray background
        // Merge all root nodes under a parent for positioning
        let parentNode = SCNNode()
        scene?.rootNode.childNodes.forEach { node in
            parentNode.addChildNode(node)
        }
        scene?.rootNode.addChildNode(parentNode)
        // Apply dark gray material to nodes
        parentNode.enumerateChildNodes { node, _ in
            if let geometry = node.geometry {
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.lightGray  // Changed to light gray material
                material.lightingModel = .physicallyBased
                material.isDoubleSided = true
                geometry.materials = [material]
            }
        }
        // Center the model
        let (minVec, maxVec) = parentNode.boundingBox
        let dxAxis = (minVec.x + maxVec.x) / 2
        let dyAxis = (minVec.y + maxVec.y) / 2
        let dzAxis = (minVec.z + maxVec.z) / 2
        parentNode.position = SCNVector3(-dxAxis, -dyAxis, -dzAxis)
        // Add a camera that fits the model
        let maxDimension = max(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, maxDimension * 2)
        scene?.rootNode.addChildNode(cameraNode)
        // Directional light
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 1000
        lightNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene?.rootNode.addChildNode(lightNode)
        // Ambient light
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light?.type = .ambient
        ambientNode.light?.color = UIColor(white: 0.3, alpha: 1.0)
        scene?.rootNode.addChildNode(ambientNode)
        scnView.scene = scene
        let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        return scnView
    }
    class Coordinator: NSObject {
        let scene: SCNScene?
        weak var viewController: UIViewController?
        init(scene: SCNScene?, viewController: UIViewController?) {
            self.scene = scene
            self.viewController = viewController
        }
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: nil)
            guard let hit = hits.first else { return }
            let position = hit.worldCoordinates
            // Show an alert to enter label
            let alert = UIAlertController(title: "Add Tag", message: "Enter your label", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Tag name"
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
                guard let text = alert.textFields?.first?.text, !text.isEmpty else { return }
                self?.addTag(at: position, with: text)
            }))
            viewController?.present(alert, animated: true)
        }
        func addTag(at position: SCNVector3, with text: String) {
            let textGeometry = SCNText(string: text, extrusionDepth: 0.2)
            textGeometry.font = UIFont.systemFont(ofSize: 5)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.red
            textGeometry.firstMaterial?.isDoubleSided = true
            textGeometry.firstMaterial?.readsFromDepthBuffer = false
            let textNode = SCNNode(geometry: textGeometry)
            textNode.scale = SCNVector3(0.01, 0.01, 0.01)
            textNode.position = position
            textNode.renderingOrder = 1000
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = [.Y]
            textNode.constraints = [constraint]
            scene?.rootNode.addChildNode(textNode)
        }
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {
    }
}
