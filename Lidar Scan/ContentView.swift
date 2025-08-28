//
//  ContentView.swift
//  Rescue Robot Sensor Head
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var appState = AppState()
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        if isIPad {
            // iPad gets the robot controller interface with native TabView
            RobotControllerTabView()
        } else {
            // iPhone gets the original sensor head interface
            TabView(selection: $selectedTab) {
                ExploreView()
                    .tabItem {
                        Image(systemName: "eye.fill")
                        Text("Explore")
                    }
                    .tag(0)
                
                MapView()
                    .tabItem {
                        Image(systemName: "map.fill")
                        Text("Map")
                    }
                    .tag(1)
                
                DetectionsList()
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Detections")
                    }
                    .tag(2)
            }
            .environmentObject(appState)
            .onAppear {
                // Initialize MultipeerService for iPhone
                if appState.multipeerService == nil {
                    appState.multipeerService = MultipeerService()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}