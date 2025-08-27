//
//  PoseService.swift
//  Rescue Robot Sensor Head
//

import Foundation
import Vision
import ARKit
import RealityKit
import CoreVideo
import simd

class PoseService: NSObject, ObservableObject {
    @Published var isProcessing = false
    @Published var frameProcessingRate: Double = 15.0 // Target 15 fps
    
    private var lastProcessedTime: CFTimeInterval = 0
    private let processingQueue = DispatchQueue(label: "pose.processing", qos: .userInitiated)
    private var isDeviceOverheated = false
    private weak var pinTracker: PinTracker?
    
    private lazy var poseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        request.revision = VNDetectHumanBodyPoseRequestRevision1
        return request
    }()
    
    override init() {
        super.init()
        setupThermalMonitoring()
    }
    
    func configure(with pinTracker: PinTracker) {
        self.pinTracker = pinTracker
    }
    
    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateThermalState()
        }
        updateThermalState()
    }
    
    private func updateThermalState() {
        let thermalState = ProcessInfo.processInfo.thermalState
        isDeviceOverheated = thermalState == .serious || thermalState == .critical
        
        // Adjust processing rate based on thermal state
        switch thermalState {
        case .nominal:
            frameProcessingRate = 15.0
        case .fair:
            frameProcessingRate = 10.0
        case .serious:
            frameProcessingRate = 5.0
        case .critical:
            frameProcessingRate = 2.0
        @unknown default:
            frameProcessingRate = 15.0
        }
    }
    
    func processFrame(_ frame: ARFrame, in arView: ARView) {
        let currentTime = CACurrentMediaTime()
        let targetInterval = 1.0 / frameProcessingRate
        
        // Skip frame if not enough time has passed or device is overheated
        guard currentTime - lastProcessedTime >= targetInterval,
              !isDeviceOverheated else {
            return
        }
        
        lastProcessedTime = currentTime
        
        // Capture viewport size on main thread
        let viewportSize = arView.bounds.size
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.performPoseDetection(frame: frame, arView: arView, viewportSize: viewportSize)
        }
    }
    
    private func performPoseDetection(frame: ARFrame, arView: ARView, viewportSize: CGSize) {
        let pixelBuffer = frame.capturedImage
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        do {
            try imageRequestHandler.perform([poseRequest])
            
            if let results = poseRequest.results {
                processPoseResults(results, frame: frame, arView: arView, viewportSize: viewportSize)
            }
        } catch {
            print("Failed to perform pose detection: \(error)")
        }
        
        DispatchQueue.main.async {
            self.isProcessing = false
        }
    }
    
    private func processPoseResults(_ results: [VNHumanBodyPoseObservation], frame: ARFrame, arView: ARView, viewportSize: CGSize) {
        for observation in results {
            guard observation.confidence > 0.3 else { continue }
            
            // Extract pose joints
            let pose = extractPose(from: observation)
            let representativePoint = pose.representativeJoint
            
            // Convert to AR view coordinates using pre-captured viewport size
            let screenPoint = CGPoint(
                x: representativePoint.x * viewportSize.width,
                y: (1.0 - representativePoint.y) * viewportSize.height
            )
            
            // Create detection
            let detection = PersonDetection(
                confidence: observation.confidence,
                screenPoint: screenPoint,
                pose: pose
            )
            
            // Pass to pin tracker for processing
            DispatchQueue.main.async { [weak self] in
                self?.pinTracker?.processDetection(detection, frame: frame, arView: arView)
            }
        }
    }
    
    private func extractPose(from observation: VNHumanBodyPoseObservation) -> HumanBodyPose {
        var joints: [String: CGPoint] = [:]
        
        // Define joint names mapping
        let jointNames: [VNHumanBodyPoseObservation.JointName: String] = [
            .nose: "nose",
            .neck: "neck",
            .rightShoulder: "right_shoulder",
            .rightElbow: "right_elbow",
            .rightWrist: "right_wrist",
            .leftShoulder: "left_shoulder",
            .leftElbow: "left_elbow",
            .leftWrist: "left_wrist",
            .root: "root",
            .rightHip: "right_hip",
            .rightKnee: "right_knee",
            .rightAnkle: "right_ankle",
            .leftHip: "left_hip",
            .leftKnee: "left_knee",
            .leftAnkle: "left_ankle"
        ]
        
        // Extract recognized joints
        for (visionJoint, jointName) in jointNames {
            if let recognizedPoint = try? observation.recognizedPoint(visionJoint),
               recognizedPoint.confidence > 0.1 {
                joints[jointName] = recognizedPoint.location
            }
        }
        
        return HumanBodyPose(joints: joints, confidence: observation.confidence)
    }
    
    func startProcessing() {
        isProcessing = true
    }
    
    func stopProcessing() {
        isProcessing = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}