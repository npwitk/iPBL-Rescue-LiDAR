//
//  ExploreView.swift
//  Rescue Robot Sensor Head
//

import SwiftUI
import RealityKit
import ARKit
import AVFoundation

struct ExploreView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var arMapper = ARMapper()
    @StateObject private var poseService = PoseService()
    @StateObject private var pinTracker = PinTracker()
    @StateObject private var networkCoordinator = LocalNetworkCoordinator()
    
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    @State private var showingConnectionSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main AR View
                ARViewContainer(
                    arMapper: arMapper,
                    poseService: poseService,
                    pinTracker: pinTracker,
                    appState: appState
                )
                .ignoresSafeArea(.all)
                
                // Session Status Overlay when not running
                if !appState.isSessionRunning {
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "camera")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Ready to Scan")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            Text("Press Start!!!!!!!!")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                        
                        Spacer()
                    }
                }
                
                // Overlays
                VStack {
                    // Top Status Bar
                    HStack {
                        TrackingStatusView(trackingState: arMapper.trackingState)
                        
                        // Connection Status
                        ConnectionStatusIndicator(state: networkCoordinator.connectionState)
                        
                        Spacer()
                        SessionControlButton(
                            isRunning: appState.isSessionRunning,
                            action: toggleSession
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Bottom Controls
                    VStack(spacing: 16) {
                        // Connection Status Button
                        Button(action: {
                            showingConnectionSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(getConnectionStatusColor())
                                    .frame(width: 8, height: 8)
                                Text("Controllers: \(networkCoordinator.connectedDevices.count)")
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // Torch Control
                        TorchControl(isOn: $appState.torchIsOn)
                        
                        // Detection Stats
                        if !appState.pins.isEmpty {
                            DetectionStatsOverlay(pins: appState.pins)
                        }
                    }
                    .padding(.bottom, 100) // Leave space for tab bar
                }
                
                // Pin Overlays
                PinsOverlay(
                    pins: appState.pins,
                    selectedPinId: appState.selectedPinId,
                    geometrySize: geometry.size,
                    arMapper: arMapper
                )
                
                // Pose Skeleton Overlay
                PoseSkeletonOverlay(
                    poseService: poseService,
                    geometrySize: geometry.size
                )
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionMessage)
        }
        .sheet(isPresented: $showingConnectionSheet) {
            RobotConnectionSheet()
                .environmentObject(networkCoordinator)
        }
        .onAppear {
            checkPermissions()
            appState.setARMapper(arMapper)
            setupRobotCommunication()
        }
    }
    
    private func getConnectionStatusColor() -> Color {
        switch networkCoordinator.connectionState {
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
    
    private func toggleSession() {
        if appState.isSessionRunning {
            stopSession()
        } else {
            startSession()
        }
    }
    
    private func startSession() {
        guard checkPermissions() else { return }
        
        // Start a new scanning session
        appState.startNewSession()
        
        arMapper.startSession()
        poseService.startProcessing()
    }
    
    private func stopSession() {
        arMapper.stopSession()
        poseService.stopProcessing()
        
        // End the current scanning session
        appState.endCurrentSession()
    }
    
    private func setupRobotCommunication() {
        // MultipeerService is already initialized and started automatically
        
        // Start broadcasting robot status periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            broadcastRobotStatus()
        }
    }
    
    private func broadcastRobotStatus() {
        guard appState.isSessionRunning else { return }
        
        let detectionUpdates = appState.pins.map { pin in
            RobotStatusUpdate.DetectionUpdate(
                id: pin.id.uuidString,
                position: pin.worldPosition,
                confidence: pin.confidence,
                stability: pin.stability.rawValue,
                age: pin.age,
                isStale: pin.isStale
            )
        }
        
        let meshBounds = appState.currentSession?.meshBounds.map {
            RobotStatusUpdate.MeshBounds(min: $0.min, max: $0.max)
        }
        
        let robotPosition = arMapper.devicePath.last ?? SIMD3<Float>(0, 0, 0)
        let robotOrientation = SIMD4<Float>(0, 0, 0, 1) // Simplified orientation
        
        let status = RobotStatusUpdate(
            timestamp: Date(),
            position: robotPosition,
            orientation: robotOrientation,
            batteryLevel: UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : nil,
            isScanning: appState.isSessionRunning,
            detections: detectionUpdates,
            devicePath: Array(arMapper.devicePath.suffix(100)), // Last 100 points
            meshBounds: meshBounds,
            connectionStrength: 0.8 // Simplified
        )
        
        networkCoordinator.sendRobotStatus(status)
    }
    
    @discardableResult
    private func checkPermissions() -> Bool {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            permissionMessage = "Camera access is required for AR functionality"
            showingPermissionAlert = true
            return false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        self.permissionMessage = "Camera access is required for AR functionality"
                        self.showingPermissionAlert = true
                    }
                }
            }
            return false
        case .authorized:
            break
        @unknown default:
            break
        }
        
        return true
    }
    
    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - ARView Container
struct ARViewContainer: UIViewRepresentable {
    let arMapper: ARMapper
    let poseService: PoseService
    let pinTracker: PinTracker
    let appState: AppState
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR view
        arView.automaticallyConfigureSession = false
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // Setup services
        let coordinator = context.coordinator
        arMapper.configure(with: arView, frameDelegate: coordinator, appState: appState)
        poseService.configure(with: pinTracker)
        pinTracker.configure(with: arMapper, appState: appState)
        
        coordinator.setup(arView: arView, arMapper: arMapper, poseService: poseService)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update torch state
        context.coordinator.updateTorch(isOn: appState.torchIsOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARFrameDelegate {
        private var arView: ARView?
        private var arMapper: ARMapper?
        private var poseService: PoseService?
        
        func setup(arView: ARView, arMapper: ARMapper, poseService: PoseService) {
            self.arView = arView
            self.arMapper = arMapper
            self.poseService = poseService
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard let arView = arView,
                  let poseService = poseService else { return }
            
            // Process pose detection on frame
            poseService.processFrame(frame, in: arView)
        }
        
        func updateTorch(isOn: Bool) {
            // Access the camera device directly - AR sessions use the default back camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("Could not access back camera for torch control")
                return
            }
            
            configureTorch(device: device, isOn: isOn)
        }
        
        private func configureTorch(device: AVCaptureDevice, isOn: Bool) {
            guard device.hasTorch else { 
                print("Device does not have torch")
                return 
            }
            
            do {
                try device.lockForConfiguration()
                if isOn {
                    if device.isTorchModeSupported(.on) {
                        device.torchMode = .on
                        try device.setTorchModeOn(level: 1.0) // Full brightness
                        print("Torch turned on")
                    }
                } else {
                    if device.isTorchModeSupported(.off) {
                        device.torchMode = .off
                        print("Torch turned off")
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch configuration error: \(error)")
            }
        }
    }
}

#Preview {
    ExploreView()
        .environmentObject(AppState())
}
