//
//  RobotControllerTabView.swift
//  Robot Controller (iPad)
//

import SwiftUI

struct RobotControllerTabView: View {
    @StateObject private var networkCoordinator = LocalNetworkCoordinator()
    @State private var selectedTab = 0
    @State private var showingDeviceDiscovery = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Bot Visualization Tab
            BotVisualizationView()
                .environmentObject(networkCoordinator)
                .tabItem {
                    Image(systemName: "cube.transparent")
                    Text("Bot Visualization")
                }
                .tag(0)
            
            // Detections Tab
            DetectionsDashboardView()
                .environmentObject(networkCoordinator)
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Detections")
                }
                .tag(1)
            
            // Connection Setup Tab
            ConnectionSetupView()
                .environmentObject(networkCoordinator)
                .tabItem {
                    Image(systemName: "wifi")
                    Text("Connection")
                }
                .tag(2)
        }
        .onAppear {
            // Show device discovery on first launch if not connected
            if networkCoordinator.connectedDevices.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingDeviceDiscovery = true
                }
            }
        }
        .sheet(isPresented: $showingDeviceDiscovery) {
            DeviceDiscoverySheet()
                .environmentObject(networkCoordinator)
        }
    }
}

struct ConnectionSetupView: View {
    @EnvironmentObject var networkCoordinator: LocalNetworkCoordinator
    @State private var showingDeviceDiscovery = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "robot")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Robot Controller")
                        .font(.largeTitle.bold())
                    
                    Text("Connect to your robot to view real-time data")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Connection Status
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        
                        Text(networkCoordinator.connectionState.description)
                            .font(.headline)
                    }
                    
                    if !networkCoordinator.connectedDevices.isEmpty {
                        Text("Connected to \(networkCoordinator.connectedDevices.count) device(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Connected Devices
                if !networkCoordinator.connectedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connected Robots")
                            .font(.headline)
                        
                        ForEach(Array(networkCoordinator.connectedDevices), id: \.self) { peer in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(peer.displayName)
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 16) {
                    Button("Find Robots") {
                        showingDeviceDiscovery = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    if !networkCoordinator.connectedDevices.isEmpty {
                        Button("Disconnect All") {
                            networkCoordinator.disconnect()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Connection")
            .sheet(isPresented: $showingDeviceDiscovery) {
                DeviceDiscoverySheet()
                    .environmentObject(networkCoordinator)
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
}

struct DeviceDiscoverySheet: View {
    @EnvironmentObject var networkCoordinator: LocalNetworkCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Instructions
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Discovering Robots")
                        .font(.title2.bold())
                    
                    Text("Make sure your robot (iPhone) is nearby and running the app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Available Devices
                if !networkCoordinator.otherDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Robots")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(Array(networkCoordinator.otherDevices), id: \.self) { peer in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peer.displayName)
                                        .font(.headline)
                                    Text("Robot available")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Connect") {
                                    networkCoordinator.invitePeer(peer)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Searching for robots...")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("Make sure both devices have WiFi and Bluetooth enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Find Robots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            networkCoordinator.startBrowsing()
        }
        .onChange(of: networkCoordinator.connectedDevices) { _, newDevices in
            if !newDevices.isEmpty {
                // Auto-dismiss when connected
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    RobotControllerTabView()
}