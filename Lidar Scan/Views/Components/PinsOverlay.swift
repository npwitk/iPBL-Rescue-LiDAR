//
//  PinsOverlay.swift
//  Rescue Robot Sensor Head
//

import SwiftUI
import simd

struct PinsOverlay: View {
    let pins: [PersonPin]
    let selectedPinId: UUID?
    let geometrySize: CGSize
    let arMapper: ARMapper?
    
    var body: some View {
        ZStack {
            ForEach(pins) { pin in
                PinMarker(
                    pin: pin,
                    isSelected: pin.id == selectedPinId,
                    geometrySize: geometrySize,
                    arMapper: arMapper
                )
            }
        }
    }
}

struct PinMarker: View {
    @ObservedObject var pin: PersonPin
    let isSelected: Bool
    let geometrySize: CGSize
    let arMapper: ARMapper?
    
    private var pinColor: Color {
        switch pin.stability {
        case .singleFrame:
            return .yellow
        case .multiFrame:
            return .orange
        case .corroborated:
            return .red
        }
    }
    
    private var screenPosition: CGPoint {
        // Use proper 3D to 2D projection if ARMapper is available
        if let arMapper = arMapper,
           let projectedPosition = arMapper.projectToScreen(worldPosition: pin.worldPosition) {
            return projectedPosition
        }
        
        // Fallback to simplified projection (should rarely be used)
        return CGPoint(
            x: geometrySize.width * 0.5 + CGFloat(pin.worldPosition.x * 50),
            y: geometrySize.height * 0.5 + CGFloat(pin.worldPosition.z * 50)
        )
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Pin marker with glow effect
            ZStack {
                // Glow background
                Circle()
                    .fill(pinColor.opacity(0.3))
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                    .blur(radius: 4)
                
                // Main circle
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                // Person icon
                Image(systemName: "person.fill")
                    .font(.system(size: isSelected ? 12 : 10, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1)
                
                // Pulsing ring for selected
                if isSelected {
                    Circle()
                        .stroke(pinColor, lineWidth: 3)
                        .frame(width: 40, height: 40)
                        .opacity(0.6)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isSelected)
                }
            }
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            
            // Info label
            VStack(alignment: .center, spacing: 2) {
                Text("\(Int(pin.confidence * 100))%")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                
                Text(ageString(pin.age))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.7))
            .cornerRadius(6)
            .opacity(isSelected ? 1.0 : 0.8)
        }
        .position(screenPosition)
        .allowsHitTesting(false)
    }
    
    private func ageString(_ age: TimeInterval) -> String {
        if age < 60 {
            return "\(Int(age))s"
        } else if age < 3600 {
            return "\(Int(age / 60))m"
        } else {
            return "\(Int(age / 3600))h"
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
    
    return PinsOverlay(
        pins: samplePins,
        selectedPinId: samplePins[1].id,
        geometrySize: CGSize(width: 400, height: 800),
        arMapper: nil
    )
    .background(Color.blue.opacity(0.3))
}