//
//  RobotMapViewerApp.swift
//  Robot Map Viewer
//
//  Mac companion app for viewing 3D maps from iPhone robot head
//

import SwiftUI

@main
struct RobotMapViewerApp: App {
    @StateObject private var appState = MacAppState()
    @StateObject private var networkReceiver = NetworkReceiver()
    @StateObject private var visualizationEngine = VisualizationEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(networkReceiver)
                .environmentObject(visualizationEngine)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Start Listening") {
                    networkReceiver.startListening()
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Stop Listening") {
                    networkReceiver.stopListening()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Mac App State
class MacAppState: ObservableObject {
    @Published var isConnected = false
    @Published var robotPosition: simd_float3 = simd_float3(0, 0, 0)
    @Published var robotRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    @Published var lastHeartbeat: Date?
    @Published var currentSessionId: String?
    @Published var detectedPersons: [RemotePersonDetection] = []
    @Published var meshData: [RemoteMeshData] = []
    
    // UI State
    @Published var showRobotPath = true
    @Published var showDetections = true
    @Published var showMesh = true
    @Published var selectedDetection: RemotePersonDetection?
    
    func updateRobotPosition(_ position: simd_float3, rotation: simd_quatf) {
        self.robotPosition = position
        self.robotRotation = rotation
    }
    
    func addOrUpdateDetection(_ detection: RemotePersonDetection) {
        if let index = detectedPersons.firstIndex(where: { $0.id == detection.id }) {
            detectedPersons[index] = detection
        } else {
            detectedPersons.append(detection)
        }
    }
    
    func addOrUpdateMesh(_ mesh: RemoteMeshData) {
        if let index = meshData.firstIndex(where: { $0.anchorId == mesh.anchorId }) {
            meshData[index] = mesh
        } else {
            meshData.append(mesh)
        }
    }
}

// MARK: - Data Models for Mac
struct RemotePersonDetection: Identifiable, Hashable {
    let id: String
    let position: simd_float3
    let confidence: Float
    let stability: String
    let timestamp: Date
    
    var stabilityColor: Color {
        switch stability {
        case "single-frame": return .yellow
        case "multi-frame": return .orange
        case "corroborated": return .red
        default: return .gray
        }
    }
}

struct RemoteMeshData: Identifiable {
    let id = UUID()
    let anchorId: String
    let vertices: [simd_float3]
    let faces: [Int]
    let transform: simd_float4x4
    let timestamp: Date
}