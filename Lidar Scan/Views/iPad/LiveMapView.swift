//
//  LiveMapView.swift
//  Robot Controller (iPad)
//

import SwiftUI
import simd

struct LiveMapView: View {
    @EnvironmentObject var robotState: RobotControllerState
    @State private var mapScale: Float = 50.0 // pixels per meter
    @State private var mapCenter: SIMD2<Float> = SIMD2<Float>(0, 0)
    @State private var showGrid = true
    @State private var followRobot = true
    @State private var selectedWaypoint: SIMD3<Float>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemBackground)
                
                // Grid
                if showGrid {
                    GridOverlay(scale: mapScale, center: mapCenter)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
                
                // Map Content
                ZStack {
                    // Robot path
                    if let robotStatus = robotState.robotStatus {
                        DevicePathView(
                            path: robotStatus.devicePath,
                            scale: mapScale,
                            center: mapCenter,
                            geometrySize: geometry.size
                        )
                    }
                    
                    // Detection pins
                    if let robotStatus = robotState.robotStatus {
                        ForEach(robotStatus.detections, id: \.id) { detection in
                            DetectionPinView(
                                detection: detection,
                                scale: mapScale,
                                center: mapCenter,
                                geometrySize: geometry.size,
                                isSelected: robotState.selectedDetectionId == detection.id
                            )
                            .onTapGesture {
                                robotState.selectedDetectionId = detection.id
                            }
                        }
                    }
                    
                    // Robot position
                    if let robotStatus = robotState.robotStatus {
                        RobotMarker(
                            position: robotStatus.position,
                            orientation: robotStatus.orientation,
                            scale: mapScale,
                            center: mapCenter,
                            geometrySize: geometry.size,
                            isScanning: robotStatus.isScanning
                        )
                    }
                    
                    // Waypoint marker (if setting waypoint)
                    if let waypoint = selectedWaypoint {
                        WaypointMarker(
                            position: waypoint,
                            scale: mapScale,
                            center: mapCenter,
                            geometrySize: geometry.size
                        )
                    }
                }
                .clipped()
                .onTapGesture { location in
                    handleMapTap(at: location, in: geometry.size)
                }
                
                // Controls Overlay
                VStack {
                    // Top Controls
                    HStack {
                        MapControlsPanel(
                            scale: $mapScale,
                            showGrid: $showGrid,
                            followRobot: $followRobot
                        )
                        
                        Spacer()
                        
                        RobotInfoPanel(robotStatus: robotState.robotStatus)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack {
                        QuickActionsPanel(
                            onRecenter: recenterMap,
                            onClearWaypoint: clearWaypoint,
                            onSendWaypoint: sendWaypoint
                        )
                        
                        Spacer()
                        
                        if selectedWaypoint != nil {
                            WaypointConfirmPanel(
                                onConfirm: sendWaypoint,
                                onCancel: clearWaypoint
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .onReceive(robotState.$robotStatus) { status in
            if followRobot, let position = status?.position {
                updateMapCenter(for: position)
            }
        }
    }
    
    private func handleMapTap(at location: CGPoint, in size: CGSize) {
        let worldPosition = screenToWorld(location, size: size)
        selectedWaypoint = SIMD3<Float>(worldPosition.x, 0, worldPosition.y)
    }
    
    private func screenToWorld(_ point: CGPoint, size: CGSize) -> SIMD2<Float> {
        let screenCenter = SIMD2<Float>(Float(size.width/2), Float(size.height/2))
        let screenOffset = SIMD2<Float>(Float(point.x), Float(point.y)) - screenCenter
        return mapCenter + screenOffset / mapScale
    }
    
    private func updateMapCenter(for robotPosition: SIMD3<Float>) {
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCenter = SIMD2<Float>(robotPosition.x, robotPosition.z)
        }
    }
    
    private func recenterMap() {
        guard let robotPosition = robotState.robotStatus?.position else { return }
        followRobot = true
        updateMapCenter(for: robotPosition)
    }
    
    private func clearWaypoint() {
        selectedWaypoint = nil
    }
    
    private func sendWaypoint() {
        guard let waypoint = selectedWaypoint else { return }
        robotState.sendGoToWaypoint(waypoint)
        selectedWaypoint = nil
    }
}

struct GridOverlay: Shape {
    let scale: Float
    let center: SIMD2<Float>
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let gridSpacing: Float = 1.0 // 1 meter grid
        let pixelSpacing = CGFloat(gridSpacing * scale)
        
        let centerX = rect.width / 2
        let centerY = rect.height / 2
        
        let offsetX = CGFloat(center.x * scale).truncatingRemainder(dividingBy: pixelSpacing)
        let offsetY = CGFloat(center.y * scale).truncatingRemainder(dividingBy: pixelSpacing)
        
        // Vertical lines
        var x = -offsetX
        while x <= rect.width + pixelSpacing {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += pixelSpacing
        }
        
        // Horizontal lines
        var y = -offsetY
        while y <= rect.height + pixelSpacing {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += pixelSpacing
        }
        
        return path
    }
}

struct DevicePathView: View {
    let path: [SIMD3<Float>]
    let scale: Float
    let center: SIMD2<Float>
    let geometrySize: CGSize
    
    var body: some View {
        Path { path_builder in
            guard !path.isEmpty else { return }
            
            let screenPoints = path.map { worldToScreen($0, size: geometrySize) }
            
            if let firstPoint = screenPoints.first {
                path_builder.move(to: firstPoint)
                for point in screenPoints.dropFirst() {
                    path_builder.addLine(to: point)
                }
            }
        }
        .stroke(Color.blue.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
    
    private func worldToScreen(_ worldPos: SIMD3<Float>, size: CGSize) -> CGPoint {
        let worldPos2D = SIMD2<Float>(worldPos.x, worldPos.z)
        let offset = (worldPos2D - center) * scale
        let screenCenter = CGPoint(x: size.width/2, y: size.height/2)
        return CGPoint(
            x: screenCenter.x + CGFloat(offset.x),
            y: screenCenter.y + CGFloat(offset.y)
        )
    }
}

struct RobotMarker: View {
    let position: SIMD3<Float>
    let orientation: SIMD4<Float>
    let scale: Float
    let center: SIMD2<Float>
    let geometrySize: CGSize
    let isScanning: Bool
    
    private var screenPosition: CGPoint {
        let worldPos2D = SIMD2<Float>(position.x, position.z)
        let offset = (worldPos2D - center) * scale
        let screenCenter = CGPoint(x: geometrySize.width/2, y: geometrySize.height/2)
        return CGPoint(
            x: screenCenter.x + CGFloat(offset.x),
            y: screenCenter.y + CGFloat(offset.y)
        )
    }
    
    private var rotationAngle: Double {
        // Convert quaternion to rotation angle (simplified for 2D)
        return Double(atan2(2 * (orientation.w * orientation.z + orientation.x * orientation.y),
                           1 - 2 * (orientation.y * orientation.y + orientation.z * orientation.z)))
    }
    
    var body: some View {
        ZStack {
            // Scanning pulse effect
            if isScanning {
                Circle()
                    .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .scaleEffect(1.5)
                    .opacity(0.6)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isScanning)
            }
            
            // Robot body
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.red)
                .frame(width: 16, height: 24)
            
            // Direction indicator
            Path { path in
                path.move(to: CGPoint(x: 0, y: -12))
                path.addLine(to: CGPoint(x: -4, y: -8))
                path.addLine(to: CGPoint(x: 4, y: -8))
                path.closeSubpath()
            }
            .fill(Color.white)
        }
        .rotationEffect(.radians(rotationAngle))
        .position(screenPosition)
    }
}

struct DetectionPinView: View {
    let detection: RobotStatusUpdate.DetectionUpdate
    let scale: Float
    let center: SIMD2<Float>
    let geometrySize: CGSize
    let isSelected: Bool
    
    private var screenPosition: CGPoint {
        let worldPos2D = SIMD2<Float>(detection.position.x, detection.position.z)
        let offset = (worldPos2D - center) * scale
        let screenCenter = CGPoint(x: geometrySize.width/2, y: geometrySize.height/2)
        return CGPoint(
            x: screenCenter.x + CGFloat(offset.x),
            y: screenCenter.y + CGFloat(offset.y)
        )
    }
    
    private var pinColor: Color {
        switch detection.stability {
        case "single-frame": return .yellow
        case "multi-frame": return .orange
        case "corroborated": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 32, height: 32)
            }
            
            // Pin marker
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 20 : 16, height: isSelected ? 20 : 16)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Person icon
            Image(systemName: "person.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
        .position(screenPosition)
    }
}

struct WaypointMarker: View {
    let position: SIMD3<Float>
    let scale: Float
    let center: SIMD2<Float>
    let geometrySize: CGSize
    
    private var screenPosition: CGPoint {
        let worldPos2D = SIMD2<Float>(position.x, position.z)
        let offset = (worldPos2D - center) * scale
        let screenCenter = CGPoint(x: geometrySize.width/2, y: geometrySize.height/2)
        return CGPoint(
            x: screenCenter.x + CGFloat(offset.x),
            y: screenCenter.y + CGFloat(offset.y)
        )
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 30, height: 30)
            
            Circle()
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 24, height: 24)
            
            Image(systemName: "location")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.green)
        }
        .position(screenPosition)
    }
}

#Preview {
    LiveMapView()
        .environmentObject(RobotControllerState())
        .previewInterfaceOrientation(.landscapeLeft)
}