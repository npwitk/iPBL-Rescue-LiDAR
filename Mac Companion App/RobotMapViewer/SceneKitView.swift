//
//  SceneKitView.swift
//  Robot Map Viewer
//

import SwiftUI
import SceneKit

struct SceneKitView: NSViewRepresentable {
    @ObservedObject var visualizationEngine: VisualizationEngine
    
    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = visualizationEngine.scene
        scnView.pointOfView = visualizationEngine.cameraNode
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = NSColor.black
        scnView.showsStatistics = true
        
        // Enable anti-aliasing
        scnView.antialiasingMode = .multisampling4X
        
        return scnView
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        // Scene updates are handled by the VisualizationEngine
        nsView.scene = visualizationEngine.scene
        nsView.pointOfView = visualizationEngine.cameraNode
    }
}