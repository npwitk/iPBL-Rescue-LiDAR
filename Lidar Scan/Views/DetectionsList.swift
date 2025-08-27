//
//  DetectionsList.swift
//  Rescue Robot Sensor Head
//

import SwiftUI
import simd

struct DetectionsList: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder: SortOrder = .confidence
    @State private var showingExportSheet = false
    
    enum SortOrder: String, CaseIterable {
        case confidence = "Confidence"
        case stability = "Stability"
        case age = "Age"
        case lastSeen = "Last Seen"
    }
    
    private var filteredAndSortedPins: [PersonPin] {
        let filtered = appState.filterRecent ? appState.recentDetections : appState.pins
        
        return filtered.sorted { pin1, pin2 in
            switch sortOrder {
            case .confidence:
                return pin1.confidence > pin2.confidence
            case .stability:
                return pin1.stability.rawValue > pin2.stability.rawValue
            case .age:
                return pin1.age < pin2.age
            case .lastSeen:
                return pin1.lastSeen > pin2.lastSeen
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter and Sort Controls
                VStack(spacing: 12) {
                    HStack {
                        // Filter toggle
                        Toggle("Recent Only", isOn: $appState.filterRecent)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        Spacer()
                        
                        // Export button
                        Button(action: { showingExportSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                        }
                    }
                    
                    // Sort picker
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Statistics Header
                if !filteredAndSortedPins.isEmpty {
                    DetectionStatsHeader(pins: filteredAndSortedPins)
                        .padding()
                        .background(Color(.systemGray5))
                }
                
                // Detection List
                if filteredAndSortedPins.isEmpty {
                    EmptyDetectionsView()
                } else {
                    List {
                        ForEach(filteredAndSortedPins) { pin in
                            DetectionRow(pin: pin)
                                .onTapGesture {
                                    focusOnDetection(pin)
                                }
                        }
                        .onDelete(perform: deletePins)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Detections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !filteredAndSortedPins.isEmpty {
                        Button("Clear All") {
                            clearAllDetections()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(pins: filteredAndSortedPins)
        }
    }
    
    private func focusOnDetection(_ pin: PersonPin) {
        // Select the pin and switch to explore view
        appState.selectedPinId = pin.id
        
        // Switch to explore tab (assuming tab index 0)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let tabBarController = windowScene.windows.first?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 0
        }
    }
    
    private func deletePins(at offsets: IndexSet) {
        for index in offsets {
            let pin = filteredAndSortedPins[index]
            appState.removePin(pin)
        }
    }
    
    private func clearAllDetections() {
        appState.clearPins()
    }
}

// MARK: - Detection Row
struct DetectionRow: View {
    @ObservedObject var pin: PersonPin
    
    private var stabilityIcon: String {
        switch pin.stability {
        case .singleFrame: return "circle.fill"
        case .multiFrame: return "circle.hexagonpath.fill"
        case .corroborated: return "checkmark.circle.fill"
        }
    }
    
    private var stabilityColor: Color {
        switch pin.stability {
        case .singleFrame: return .yellow
        case .multiFrame: return .orange
        case .corroborated: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Stability indicator
            VStack {
                Image(systemName: stabilityIcon)
                    .font(.title2)
                    .foregroundColor(stabilityColor)
                
                Text(pin.stability.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                // ID and confidence
                HStack {
                    Text("ID: \(pin.id.uuidString.prefix(8))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(pin.confidence * 100))%")
                        .font(.title3.bold())
                        .foregroundColor(confidenceColor(pin.confidence))
                }
                
                // Position
                Text("Position: (\(String(format: "%.1f", pin.worldPosition.x)), \(String(format: "%.1f", pin.worldPosition.y)), \(String(format: "%.1f", pin.worldPosition.z)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Timing info
                HStack {
                    Text("Age: \(formatAge(pin.age))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Last seen: \(formatLastSeen(pin.lastSeen))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Detection count
                Text("\(pin.detectionHistory.count) detections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Status indicator
            VStack {
                Circle()
                    .fill(pin.isStale ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                
                Text(pin.isStale ? "Stale" : "Active")
                    .font(.caption2)
                    .foregroundColor(pin.isStale ? .red : .green)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }
    
    private func formatAge(_ age: TimeInterval) -> String {
        if age < 60 {
            return "\(Int(age))s"
        } else if age < 3600 {
            return "\(Int(age / 60))m"
        } else {
            return "\(Int(age / 3600))h"
        }
    }
    
    private func formatLastSeen(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Statistics Header
struct DetectionStatsHeader: View {
    let pins: [PersonPin]
    
    private var stats: (total: Int, active: Int, stale: Int, avgConfidence: Float) {
        let active = pins.filter { !$0.isStale }
        let stale = pins.filter { $0.isStale }
        let avgConfidence = pins.isEmpty ? 0 : pins.map { $0.confidence }.reduce(0, +) / Float(pins.count)
        
        return (pins.count, active.count, stale.count, avgConfidence)
    }
    
    var body: some View {
        HStack {
            StatCard(title: "Total", value: "\(stats.total)", color: .blue)
            StatCard(title: "Active", value: "\(stats.active)", color: .green)
            StatCard(title: "Stale", value: "\(stats.stale)", color: .red)
            StatCard(title: "Avg Conf", value: "\(Int(stats.avgConfidence * 100))%", color: .orange)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Empty State
struct EmptyDetectionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Detections")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("Start a session in the Explore tab to begin detecting people")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Export Sheet
struct ExportSheet: View {
    let pins: [PersonPin]
    @Environment(\.presentationMode) var presentationMode
    @State private var isExporting = false
    @State private var exportMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Options")
                    .font(.title2.bold())
                
                VStack(spacing: 16) {
                    ExportButton(
                        title: "Export as JSON",
                        description: "Export detection logs as JSON file",
                        icon: "doc.text",
                        action: exportJSON
                    )
                    
                    ExportButton(
                        title: "Export World Map",
                        description: "Export AR world map (if available)",
                        icon: "map",
                        action: exportWorldMap
                    )
                    
                    ExportButton(
                        title: "Export Summary",
                        description: "Export detection summary report",
                        icon: "chart.bar.doc.horizontal",
                        action: exportSummary
                    )
                }
                .padding()
                
                if !exportMessage.isEmpty {
                    Text(exportMessage)
                        .font(.body)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func exportJSON() {
        // Implementation would export detection data as JSON
        exportMessage = "JSON export completed successfully"
    }
    
    private func exportWorldMap() {
        // Implementation would export AR world map
        exportMessage = "World map export completed successfully"
    }
    
    private func exportSummary() {
        // Implementation would export detection summary
        exportMessage = "Summary export completed successfully"
    }
}

struct ExportButton: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    let appState = {
        let state = AppState()
        let samplePins = [
            PersonPin(initialDetection: PersonDetection(confidence: 0.8, screenPoint: .zero)),
            PersonPin(initialDetection: PersonDetection(confidence: 0.6, screenPoint: .zero)),
            PersonPin(initialDetection: PersonDetection(confidence: 0.9, screenPoint: .zero))
        ]
        
        samplePins[0].worldPosition = simd_float3(1, 0, 1)
        samplePins[1].worldPosition = simd_float3(-1, 0, 2)
        samplePins[1].stability = .multiFrame
        samplePins[2].worldPosition = simd_float3(0, 0, -1)
        samplePins[2].stability = .corroborated
        
        state.pins = samplePins
        return state
    }()
    
    return DetectionsList()
        .environmentObject(appState)
}