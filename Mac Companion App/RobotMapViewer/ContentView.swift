//
//  ContentView.swift
//  Robot Map Viewer
//

import SwiftUI
import SceneKit

struct ContentView: View {
    @EnvironmentObject var appState: MacAppState
    @EnvironmentObject var networkReceiver: NetworkReceiver
    @EnvironmentObject var visualizationEngine: VisualizationEngine
    
    var body: some View {
        HStack(spacing: 0) {
            // Main 3D View
            VStack {
                // Top Controls
                HStack {
                    connectionStatusView
                    Spacer()
                    viewToggleControls
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // 3D Scene View
                SceneKitView(visualizationEngine: visualizationEngine)
                    .background(Color.black)
            }
            
            // Right Sidebar
            VStack {
                // Robot Status
                robotStatusPanel
                
                Divider()
                    .padding(.vertical)
                
                // Detections List
                detectionsPanel
                
                Spacer()
            }
            .frame(width: 300)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            setupNetworkReceiver()
        }
    }
    
    private var connectionStatusView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(networkReceiver.isListening ? Color.green : Color.red)
                .frame(width: 12, height: 12)
                .animation(.easeInOut(duration: 0.3), value: networkReceiver.isListening)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(networkReceiver.isListening ? "Listening" : "Disconnected")
                    .font(.headline)
                
                if let lastMessage = networkReceiver.lastMessageReceived {
                    Text("Last: \(timeAgo(lastMessage))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(networkReceiver.isListening ? "Stop" : "Start") {
                if networkReceiver.isListening {
                    networkReceiver.stopListening()
                } else {
                    networkReceiver.startListening()
                }
            }
        }
    }
    
    private var viewToggleControls: some View {
        HStack {
            Toggle("Robot Path", isOn: $appState.showRobotPath)
            Toggle("Detections", isOn: $appState.showDetections)
            Toggle("Mesh", isOn: $appState.showMesh)
        }
    }
    
    private var robotStatusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Robot Status")
                .font(.title2.bold())
            
            HStack {
                Text("Position:")
                Spacer()
                Text(String(format: "(%.2f, %.2f, %.2f)", 
                           appState.robotPosition.x, 
                           appState.robotPosition.y, 
                           appState.robotPosition.z))
                    .font(.system(.caption, design: .monospaced))
            }
            
            if let sessionId = appState.currentSessionId {
                HStack {
                    Text("Session:")
                    Spacer()
                    Text(String(sessionId.prefix(8)))
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            HStack {
                Text("Detections:")
                Spacer()
                Text("\(appState.detectedPersons.count)")
                    .font(.headline)
            }
            
            HStack {
                Text("Mesh Anchors:")
                Spacer()
                Text("\(appState.meshData.count)")
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
    
    private var detectionsPanel: some View {
        VStack(alignment: .leading) {
            Text("Person Detections")
                .font(.title3.bold())
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.detectedPersons) { detection in
                        detectionRow(detection)
                    }
                }
            }
        }
    }
    
    private func detectionRow(_ detection: RemotePersonDetection) -> some View {
        HStack {
            Circle()
                .fill(detection.stabilityColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(detection.id.prefix(8)))
                    .font(.system(.caption, design: .monospaced))
                
                Text(String(format: "(%.1f, %.1f, %.1f)", 
                           detection.position.x, 
                           detection.position.y, 
                           detection.position.z))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text("\(Int(detection.confidence * 100))% • \(detection.stability)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timeAgo(detection.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(appState.selectedDetection?.id == detection.id ? 
                   Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onTapGesture {
            appState.selectedDetection = detection
            visualizationEngine.focusOnDetection(detection)
        }
    }
    
    private func setupNetworkReceiver() {
        networkReceiver.configure(appState: appState, visualizationEngine: visualizationEngine)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 1 {
            return "now"
        } else if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MacAppState())
        .environmentObject(NetworkReceiver())
        .environmentObject(VisualizationEngine())
}