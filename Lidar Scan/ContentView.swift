//
//  ContentView.swift
//  Rescue Robot Sensor Head
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var appState = AppState()
    
    var body: some View {
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
    }
}

#Preview {
    ContentView()
}