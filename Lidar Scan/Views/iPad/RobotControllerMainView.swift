//
//  RobotControllerMainView.swift
//  Robot Controller (iPad)
//

import SwiftUI
import simd

struct RobotControllerMainView: View {
    @EnvironmentObject var multipeerService: MultipeerService
    @State private var selectedTab: ControllerTab = .visualization
    
    enum ControllerTab: String, CaseIterable {
        case visualization = "Bot Visualization"
        case detections = "Detections"
        
        var icon: String {
            switch self {
            case .visualization: return "cube.transparent"
            case .detections: return "person.3"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar Navigation
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "robot")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("Robot Viewer")
                        .font(.headline.bold())
                        .multilineTextAlignment(.center)
                    
                    ConnectionStatusIndicator(state: multipeerService.connectionState)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Tab Navigation
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(ControllerTab.allCases, id: \.self) { tab in
                            SidebarTabButton(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                action: { selectedTab = tab }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Spacer()
            }
            .frame(width: 280)
            .background(Color(.systemGray5))
            
            // Main Content
            Group {
                switch selectedTab {
                case .visualization:
                    BotVisualizationView()
                case .detections:
                    DetectionsDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // Any initialization logic
        }
    }
}

struct SidebarTabButton: View {
    let tab: RobotControllerMainView.ControllerTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24)
                
                Text(tab.rawValue)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 12)
    }
}

struct ConnectionStatusIndicator: View {
    let state: ConnectionState
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(state.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch state {
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
    RobotControllerMainView()
        .environmentObject(MultipeerService())
        .previewInterfaceOrientation(.landscapeLeft)
}