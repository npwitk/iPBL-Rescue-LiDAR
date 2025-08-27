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
    
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    
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
                
                // Overlays
                VStack {
                    // Top Status Bar
                    HStack {
                        TrackingStatusView(trackingState: arMapper.trackingState)
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
                    geometrySize: geometry.size
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
        .onAppear {
            checkPermissions()
            appState.setARMapper(arMapper)
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