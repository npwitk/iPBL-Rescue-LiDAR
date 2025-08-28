//
//  MissionPlannerView.swift
//  Robot Controller (iPad)
//

import SwiftUI

struct MissionPlannerView: View {
    @EnvironmentObject var robotState: RobotControllerState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Mission Planner")
                .font(.title.bold())
            
            VStack(spacing: 16) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Mission Planning")
                    .font(.title2.bold())
                
                Text("Create and manage automated search missions for the robot.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Coming Soon") {
                    // Future implementation
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.gray)
                .cornerRadius(8)
                .disabled(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title.bold())
            
            VStack(spacing: 16) {
                Image(systemName: "gearshape")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Robot Controller Settings")
                    .font(.title2.bold())
                
                Text("Configure connection settings, control preferences, and robot parameters.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Coming Soon") {
                    // Future implementation
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.gray)
                .cornerRadius(8)
                .disabled(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MissionPlannerView()
        .environmentObject(RobotControllerState())
        .previewInterfaceOrientation(.landscapeLeft)
}