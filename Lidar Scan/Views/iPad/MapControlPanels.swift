//
//  MapControlPanels.swift
//  Robot Controller (iPad)
//

import SwiftUI

struct MapControlsPanel: View {
    @Binding var scale: Float
    @Binding var showGrid: Bool
    @Binding var followRobot: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Zoom controls
            HStack(spacing: 12) {
                Text("Zoom")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Button(action: { scale = max(10, scale - 10) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(scale <= 10)
                
                Text("\(Int(scale))px/m")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
                
                Button(action: { scale = min(200, scale + 10) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(scale >= 200)
            }
            
            // View options
            HStack(spacing: 16) {
                Toggle("Grid", isOn: $showGrid)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Toggle("Follow Robot", isOn: $followRobot)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct RobotInfoPanel: View {
    let robotStatus: RobotStatusUpdate?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let status = robotStatus {
                // Position
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("(\(String(format: "%.1f", status.position.x)), \(String(format: "%.1f", status.position.z)))")
                        .font(.caption.monospacedDigit())
                }
                
                // Battery
                if let battery = status.batteryLevel {
                    HStack(spacing: 4) {
                        Image(systemName: battery > 0.2 ? "battery.100" : "battery.25")
                            .font(.caption)
                            .foregroundColor(battery > 0.2 ? .green : .red)
                        
                        Text("\(Int(battery * 100))%")
                            .font(.caption.monospacedDigit())
                    }
                }
                
                // Connection strength
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.caption)
                        .foregroundColor(signalColor(status.connectionStrength))
                    
                    Text("\(Int(status.connectionStrength * 100))%")
                        .font(.caption.monospacedDigit())
                }
                
                // Scanning status
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.isScanning ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    
                    Text(status.isScanning ? "Scanning" : "Idle")
                        .font(.caption)
                }
                
                // Detection count
                HStack(spacing: 4) {
                    Image(systemName: "person.3")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(status.detections.count)")
                        .font(.caption.monospacedDigit())
                }
                
            } else {
                Text("No robot data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func signalColor(_ strength: Float) -> Color {
        if strength > 0.7 { return .green }
        if strength > 0.3 { return .orange }
        return .red
    }
}

struct QuickActionsPanel: View {
    let onRecenter: () -> Void
    let onClearWaypoint: () -> Void
    let onSendWaypoint: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Recenter map
            Button(action: onRecenter) {
                VStack(spacing: 4) {
                    Image(systemName: "location.viewfinder")
                        .font(.system(size: 16, weight: .medium))
                    Text("Center")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .frame(width: 60, height: 50)
            }
            
            // Zoom to fit
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 16, weight: .medium))
                    Text("Fit All")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .frame(width: 60, height: 50)
            }
            
            // Clear all waypoints
            Button(action: onClearWaypoint) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                    Text("Clear")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .frame(width: 60, height: 50)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct WaypointConfirmPanel: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: onConfirm) {
                HStack(spacing: 8) {
                    Image(systemName: "location")
                        .font(.system(size: 14, weight: .medium))
                    Text("Send Robot Here")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}