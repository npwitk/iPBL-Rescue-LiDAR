//
//  RobotControlView.swift
//  Robot Controller (iPad)
//

import SwiftUI
import simd

struct RobotControlView: View {
    @EnvironmentObject var robotState: RobotControllerState
    @State private var movementSpeed: Float = 0.5
    @State private var rotationSpeed: Float = 0.5
    @State private var isMoving = false
    @State private var currentDirection = SIMD2<Float>(0, 0)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 20) {
                // Left Panel - Movement Controls
                VStack(spacing: 20) {
                    Text("Movement Control")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    // Virtual Joystick
                    JoystickView(
                        onDirectionChanged: { direction in
                            currentDirection = direction
                            if simd_length(direction) > 0.1 {
                                if !isMoving {
                                    isMoving = true
                                    startMovement()
                                }
                            } else {
                                if isMoving {
                                    isMoving = false
                                    stopMovement()
                                }
                            }
                        }
                    )
                    .frame(width: 200, height: 200)
                    
                    // Speed Controls
                    VStack(spacing: 12) {
                        Text("Speed: \(Int(movementSpeed * 100))%")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            Button("25%") { movementSpeed = 0.25 }
                            Button("50%") { movementSpeed = 0.5 }
                            Button("75%") { movementSpeed = 0.75 }
                            Button("100%") { movementSpeed = 1.0 }
                        }
                        .buttonStyle(SpeedButtonStyle(selectedSpeed: movementSpeed))
                        
                        Slider(value: $movementSpeed, in: 0.1...1.0)
                            .accentColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        ControlButton(
                            title: "Stop",
                            icon: "stop.fill",
                            color: .red,
                            action: { robotState.sendStopCommand() }
                        )
                        
                        ControlButton(
                            title: robotState.robotStatus?.isScanning == true ? "Stop Scan" : "Start Scan",
                            icon: robotState.robotStatus?.isScanning == true ? "stop.circle" : "play.circle",
                            color: .blue,
                            action: { robotState.toggleScanning() }
                        )
                        
                        ControlButton(
                            title: "Torch",
                            icon: "flashlight.on.fill",
                            color: .orange,
                            action: { robotState.toggleTorch() }
                        )
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: 400)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Right Panel - Status and Precision Controls
                VStack(spacing: 20) {
                    Text("Robot Status")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    // Robot Status Display
                    RobotStatusDisplay(robotStatus: robotState.robotStatus)
                    
                    // Precision Movement Controls
                    VStack(spacing: 16) {
                        Text("Precision Movement")
                            .font(.headline.bold())
                        
                        // Directional arrows
                        VStack(spacing: 8) {
                            Button(action: { sendPrecisionMove(direction: SIMD2<Float>(0, 1)) }) {
                                Image(systemName: "arrow.up")
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            HStack(spacing: 8) {
                                Button(action: { sendPrecisionMove(direction: SIMD2<Float>(-1, 0)) }) {
                                    Image(systemName: "arrow.left")
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: { robotState.sendStopCommand() }) {
                                    Image(systemName: "stop.fill")
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: { sendPrecisionMove(direction: SIMD2<Float>(1, 0)) }) {
                                    Image(systemName: "arrow.right")
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            
                            Button(action: { sendPrecisionMove(direction: SIMD2<Float>(0, -1)) }) {
                                Image(systemName: "arrow.down")
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Rotation controls
                        HStack(spacing: 16) {
                            Button(action: { robotState.sendRotateCommand(angle: -Float.pi/4, speed: rotationSpeed) }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title3)
                                    Text("45° Left")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            Button(action: { robotState.sendRotateCommand(angle: Float.pi/4, speed: rotationSpeed) }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.title3)
                                    Text("45° Right")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .frame(maxWidth: 350)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .padding(20)
        }
    }
    
    private func startMovement() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isMoving && simd_length(currentDirection) > 0.1 {
                robotState.sendMoveCommand(direction: currentDirection, speed: movementSpeed)
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopMovement() {
        robotState.sendStopCommand()
    }
    
    private func sendPrecisionMove(direction: SIMD2<Float>) {
        let scaledDirection = direction * 0.3 // Short movement
        robotState.sendMoveCommand(direction: scaledDirection, speed: 0.3)
    }
}

struct JoystickView: View {
    let onDirectionChanged: (SIMD2<Float>) -> Void
    @State private var knobPosition = CGPoint.zero
    @State private var isDragging = false
    
    private let knobSize: CGFloat = 40
    private let trackSize: CGFloat = 180
    
    var body: some View {
        ZStack {
            // Track (outer circle)
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: trackSize, height: trackSize)
                .overlay(
                    Circle()
                        .stroke(Color(.systemGray3), lineWidth: 2)
                )
            
            // Center dot
            Circle()
                .fill(Color(.systemGray2))
                .frame(width: 4, height: 4)
            
            // Directional indicators
            ForEach(0..<8) { index in
                let angle = Double(index) * .pi / 4
                let radius = trackSize / 2 - 20
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 6, height: 6)
                    .offset(x: x, y: y)
            }
            
            // Knob (draggable)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: knobSize, height: knobSize)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .offset(x: knobPosition.x, y: knobPosition.y)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isDragging)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            updateKnobPosition(value.translation)
                        }
                        .onEnded { _ in
                            isDragging = false
                            returnToCenter()
                        }
                )
        }
        .frame(width: trackSize, height: trackSize)
    }
    
    private func updateKnobPosition(_ translation: CGSize) {
        let maxRadius = (trackSize - knobSize) / 2
        let distance = min(sqrt(translation.width * translation.width + translation.height * translation.height), maxRadius)
        let angle = atan2(translation.height, translation.width)
        
        knobPosition = CGPoint(
            x: cos(angle) * distance,
            y: sin(angle) * distance
        )
        
        // Convert to normalized direction (-1 to 1)
        let normalizedDirection = SIMD2<Float>(
            Float(knobPosition.x / maxRadius),
            Float(-knobPosition.y / maxRadius) // Flip Y for standard coordinate system
        )
        
        onDirectionChanged(normalizedDirection)
    }
    
    private func returnToCenter() {
        withAnimation(.easeOut(duration: 0.3)) {
            knobPosition = .zero
        }
        onDirectionChanged(SIMD2<Float>(0, 0))
    }
}

struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 80)
            .background(color)
            .cornerRadius(12)
        }
    }
}

struct SpeedButtonStyle: ButtonStyle {
    let selectedSpeed: Float
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct RobotStatusDisplay: View {
    let robotStatus: RobotStatusUpdate?
    
    var body: some View {
        VStack(spacing: 12) {
            if let status = robotStatus {
                StatusRow(label: "Position", value: "(\(String(format: "%.2f", status.position.x)), \(String(format: "%.2f", status.position.z)))", icon: "location")
                
                if let battery = status.batteryLevel {
                    StatusRow(label: "Battery", value: "\(Int(battery * 100))%", icon: "battery.100")
                }
                
                StatusRow(label: "Connection", value: "\(Int(status.connectionStrength * 100))%", icon: "wifi")
                StatusRow(label: "Scanning", value: status.isScanning ? "Active" : "Idle", icon: "camera.viewfinder")
                StatusRow(label: "Detections", value: "\(status.detections.count)", icon: "person.3")
            } else {
                Text("No robot connection")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    RobotControlView()
        .environmentObject(RobotControllerState())
        .previewInterfaceOrientation(.landscapeLeft)
}