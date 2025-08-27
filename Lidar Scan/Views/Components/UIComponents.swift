//
//  UIComponents.swift
//  Rescue Robot Sensor Head
//

import SwiftUI
import ARKit

// MARK: - Tracking Status View
struct TrackingStatusView: View {
    let trackingState: ARCamera.TrackingState
    
    private var statusInfo: (text: String, color: Color) {
        switch trackingState {
        case .normal:
            return ("Tracking", .green)
        case .notAvailable:
            return ("Not Available", .red)
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return ("Move Slower", .yellow)
            case .insufficientFeatures:
                return ("Poor Lighting", .yellow)
            case .initializing:
                return ("Initializing", .blue)
            case .relocalizing:
                return ("Relocalizing", .orange)
            @unknown default:
                return ("Limited", .yellow)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusInfo.color)
                .frame(width: 8, height: 8)
            
            Text(statusInfo.text)
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }
}

// MARK: - Session Control Button
struct SessionControlButton: View {
    let isRunning: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    .font(.caption)
                
                Text(isRunning ? "Stop" : "Start")
                    .font(.caption.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isRunning ? Color.red : Color.green)
            .cornerRadius(20)
        }
    }
}

// MARK: - Detection Stats Overlay
struct DetectionStatsOverlay: View {
    let pins: [PersonPin]
    
    private var stats: (total: Int, active: Int, yellow: Int, orange: Int, red: Int) {
        let active = pins.filter { !$0.isStale }
        let yellow = pins.filter { $0.stability == .singleFrame }
        let orange = pins.filter { $0.stability == .multiFrame }
        let red = pins.filter { $0.stability == .corroborated }
        
        return (pins.count, active.count, yellow.count, orange.count, red.count)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            StatBadge(
                icon: "person.3.fill",
                value: stats.active,
                color: .white
            )
            
            StatBadge(
                icon: "circle.fill",
                value: stats.yellow,
                color: .yellow
            )
            
            StatBadge(
                icon: "circle.fill",
                value: stats.orange,
                color: .orange
            )
            
            StatBadge(
                icon: "circle.fill",
                value: stats.red,
                color: .red
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

struct StatBadge: View {
    let icon: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text("\(value)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white)
        }
    }
}

// MARK: - Pose Skeleton Overlay
struct PoseSkeletonOverlay: View {
    @ObservedObject var poseService: PoseService
    let geometrySize: CGSize
    
    var body: some View {
        ZStack {
            // Processing indicator
            if poseService.isProcessing {
                VStack {
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Detecting")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(16)
                        .padding(.trailing)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                }
            }
            
            // Frame rate indicator
            VStack {
                Spacer()
                
                HStack {
                    Text("Pose: \(Int(poseService.frameProcessingRate)) fps")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding(.leading)
                .padding(.bottom, 200)
            }
        }
    }
}

#Preview {
    let samplePins = {
        let pins = [
            PersonPin(initialDetection: PersonDetection(confidence: 0.8, screenPoint: .zero)),
            PersonPin(initialDetection: PersonDetection(confidence: 0.6, screenPoint: .zero)),
            PersonPin(initialDetection: PersonDetection(confidence: 0.9, screenPoint: .zero))
        ]
        pins[1].stability = .multiFrame
        pins[2].stability = .corroborated
        return pins
    }()
    
    return VStack(spacing: 20) {
        TrackingStatusView(trackingState: .normal)
        TrackingStatusView(trackingState: .limited(.excessiveMotion))
        TrackingStatusView(trackingState: .notAvailable)
        
        SessionControlButton(isRunning: false, action: {})
        SessionControlButton(isRunning: true, action: {})
        
        DetectionStatsOverlay(pins: samplePins)
    }
    .padding()
    .background(Color.blue.opacity(0.3))
}