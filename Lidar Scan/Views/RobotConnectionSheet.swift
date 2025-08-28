//
//  RobotConnectionSheet.swift
//  Rescue Robot Control System
//

import SwiftUI

struct RobotConnectionSheet: View {
    @EnvironmentObject var networkCoordinator: LocalNetworkCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "robot")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Robot Broadcasting")
                        .font(.title2.bold())
                    
                    Text("Controllers (iPads) can discover and connect to this robot.")
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
                    
                    Text("Broadcasting as: \(UIDevice.current.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Connected Controllers
                if !networkCoordinator.connectedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connected Controllers")
                            .font(.headline)
                        
                        ForEach(Array(networkCoordinator.connectedDevices), id: \.self) { peer in
                            HStack {
                                Image(systemName: "ipad")
                                    .foregroundColor(.blue)
                                Text(peer.displayName)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("No controllers connected")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("Other devices can find this robot by searching for nearby devices.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Instructions
                VStack(spacing: 8) {
                    Text("To connect a controller:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Open the app on an iPad")
                        Text("2. Go to the Connection tab")
                        Text("3. Tap 'Find Robots'")
                        Text("4. Select this device from the list")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Note about network requirements
                VStack(spacing: 8) {
                    Text("Network Requirements:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Both devices need WiFi and Bluetooth enabled")
                        Text("• Devices should be nearby (same room)")
                        Text("• No internet connection required")
                        Text("• Uses local network for communication")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Robot Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
}

#Preview {
    RobotConnectionSheet()
        .environmentObject(LocalNetworkCoordinator())
}