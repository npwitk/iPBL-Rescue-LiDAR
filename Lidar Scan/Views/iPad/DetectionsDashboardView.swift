//
//  DetectionsDashboardView.swift
//  Robot Controller (iPad)
//

import SwiftUI
import simd

struct DetectionsDashboardView: View {
    @EnvironmentObject var networkCoordinator: LocalNetworkCoordinator
    @State private var sortOrder: DetectionSortOrder = .confidence
    @State private var filterStale = false
    
    enum DetectionSortOrder: String, CaseIterable {
        case confidence = "Confidence"
        case distance = "Distance"  
        case age = "Age"
        case stability = "Stability"
    }
    
    private var sortedDetections: [RobotStatusUpdate.DetectionUpdate] {
        guard let detections = networkCoordinator.lastStatusUpdate?.detections else { return [] }
        
        let filtered = filterStale ? detections.filter { !$0.isStale } : detections
        
        return filtered.sorted { detection1, detection2 in
            switch sortOrder {
            case .confidence:
                return detection1.confidence > detection2.confidence
            case .distance:
                let robotPos = networkCoordinator.lastStatusUpdate?.position ?? SIMD3<Float>(0, 0, 0)
                let dist1 = simd_distance(detection1.position, robotPos)
                let dist2 = simd_distance(detection2.position, robotPos)
                return dist1 < dist2
            case .age:
                return detection1.age < detection2.age
            case .stability:
                return detection1.stability > detection2.stability
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("Detection Dashboard")
                        .font(.title.bold())
                    
                    Spacer()
                    
                    // Statistics
                    DetectionStatsCard(detections: sortedDetections)
                }
                
                // Controls
                HStack {
                    // Sort controls
                    HStack(spacing: 12) {
                        Text("Sort by:")
                            .font(.subheadline.bold())
                        
                        Picker("Sort Order", selection: $sortOrder) {
                            ForEach(DetectionSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 300)
                    }
                    
                    Spacer()
                    
                    // Filter controls
                    Toggle("Hide Stale", isOn: $filterStale)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Detection List
            if sortedDetections.isEmpty {
                EmptyDetectionsPlaceholder()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedDetections, id: \.id) { detection in
                            DetectionCard(
                                detection: detection,
                                robotPosition: networkCoordinator.lastStatusUpdate?.position,
                                isSelected: false,
                                onSelect: { },
                                onNavigate: { }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func navigateToDetection(_ detection: RobotStatusUpdate.DetectionUpdate) {
        // Navigation removed - iPad is display-only
    }
}

struct DetectionStatsCard: View {
    let detections: [RobotStatusUpdate.DetectionUpdate]
    
    private var stats: (total: Int, active: Int, stale: Int, avgConfidence: Float) {
        let active = detections.filter { !$0.isStale }
        let stale = detections.filter { $0.isStale }
        let avgConfidence = detections.isEmpty ? 0 : detections.map { $0.confidence }.reduce(0, +) / Float(detections.count)
        
        return (detections.count, active.count, stale.count, avgConfidence)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            StatBubble(title: "Total", value: "\(stats.total)", color: .blue)
            StatBubble(title: "Active", value: "\(stats.active)", color: .green)
            StatBubble(title: "Stale", value: "\(stats.stale)", color: .red)
            StatBubble(title: "Avg Conf", value: "\(Int(stats.avgConfidence * 100))%", color: .orange)
        }
    }
}

struct StatBubble: View {
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
        .frame(width: 80, height: 50)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct DetectionCard: View {
    let detection: RobotStatusUpdate.DetectionUpdate
    let robotPosition: SIMD3<Float>?
    let isSelected: Bool
    let onSelect: () -> Void
    let onNavigate: () -> Void
    
    private var distance: Float {
        guard let robotPos = robotPosition else { return 0 }
        return simd_distance(detection.position, robotPos)
    }
    
    private var stabilityColor: Color {
        switch detection.stability {
        case "single-frame": return .yellow
        case "multi-frame": return .orange
        case "corroborated": return .red
        default: return .gray
        }
    }
    
    private var confidenceColor: Color {
        if detection.confidence >= 0.8 { return .green }
        if detection.confidence >= 0.5 { return .orange }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            VStack(spacing: 8) {
                Circle()
                    .fill(stabilityColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text(detection.stability.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 60)
            
            // Detection info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("ID: \(detection.id.prefix(8))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(detection.confidence * 100))%")
                        .font(.title3.bold())
                        .foregroundColor(confidenceColor)
                }
                
                Text("Position: (\(String(format: "%.1f", detection.position.x)), \(String(format: "%.1f", detection.position.z)))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Distance: \(String(format: "%.1f", distance))m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Age: \(formatAge(detection.age))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(detection.isStale ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: onNavigate) {
                    VStack(spacing: 2) {
                        Image(systemName: "location")
                            .font(.system(size: 16, weight: .medium))
                        Text("Go")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: onSelect) {
                    VStack(spacing: 2) {
                        Image(systemName: isSelected ? "eye.fill" : "eye")
                            .font(.system(size: 16, weight: .medium))
                        Text("View")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
}

struct EmptyDetectionsPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Detections")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Robot hasn't detected any people yet.\nMake sure the robot is scanning and positioned correctly.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DetectionsDashboardView()
        .environmentObject(LocalNetworkCoordinator())
}