//
//  RobotControllerApp.swift
//  Robot Controller (iPad)
//

import SwiftUI
import simd

struct RobotControllerRootView: View {
    @StateObject private var multipeerService = MultipeerService()
    
    var body: some View {
        RobotControllerMainView()
            .environmentObject(multipeerService)
    }
}

class RobotControllerState: ObservableObject {
    @Published var robotStatus: RobotStatusUpdate?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var activeMission: Mission?
    @Published var missions: [Mission] = []
    @Published var selectedDetectionId: String?
    
    private var communicationService: RobotCommunicationService?
    
    func configure(with service: RobotCommunicationService) {
        self.communicationService = service
        service.delegate = self
        
        // Bind published properties
        service.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        service.$lastRobotStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.robotStatus, on: self)
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Robot Control Methods
    
    func sendMoveCommand(direction: SIMD2<Float>, speed: Float = 0.5) {
        let command = RobotCommand(
            timestamp: Date(),
            commandId: UUID(),
            type: .move(direction: direction, speed: speed),
            priority: .normal
        )
        communicationService?.sendCommand(command)
    }
    
    func sendRotateCommand(angle: Float, speed: Float = 0.5) {
        let command = RobotCommand(
            timestamp: Date(),
            commandId: UUID(),
            type: .rotate(angle: angle, speed: speed),
            priority: .normal
        )
        communicationService?.sendCommand(command)
    }
    
    func sendGoToWaypoint(_ position: SIMD3<Float>) {
        let command = RobotCommand(
            timestamp: Date(),
            commandId: UUID(),
            type: .goToWaypoint(position: position),
            priority: .high
        )
        communicationService?.sendCommand(command)
    }
    
    func sendStopCommand() {
        let command = RobotCommand(
            timestamp: Date(),
            commandId: UUID(),
            type: .stop,
            priority: .high
        )
        communicationService?.sendCommand(command)
    }
    
    func sendEmergencyStop() {
        let command = RobotCommand(
            timestamp: Date(),
            commandId: UUID(),
            type: .emergencyStop,
            priority: .emergency
        )
        communicationService?.sendCommand(command)
    }
    
    func toggleScanning() {
        let isCurrentlyScanning = robotStatus?.isScanning ?? false
        let command = RobotCommand(
            timestamp: Date(),
            commandId: UUID(),
            type: isCurrentlyScanning ? .stopScanning : .startScanning,
            priority: .normal
        )
        communicationService?.sendCommand(command)
    }
    
    func toggleTorch() {
        let command = RobotCommand(
            timestamp: Date(),
            commandId: UUID(),
            type: .toggleTorch,
            priority: .normal
        )
        communicationService?.sendCommand(command)
    }
    
    // MARK: - Mission Management
    
    func createMission(name: String, waypoints: [Waypoint]) {
        let mission = Mission(
            id: UUID(),
            name: name,
            waypoints: waypoints,
            createdAt: Date(),
            status: .planned
        )
        missions.append(mission)
    }
    
    func startMission(_ mission: Mission) {
        if var updatedMission = missions.first(where: { $0.id == mission.id }) {
            updatedMission.status = .active
            updateMission(updatedMission)
            activeMission = updatedMission
            
            // Send first waypoint
            if let firstWaypoint = updatedMission.waypoints.first {
                sendGoToWaypoint(firstWaypoint.position)
            }
        }
    }
    
    func pauseMission() {
        if var mission = activeMission {
            mission.status = .paused
            updateMission(mission)
            activeMission = mission
            sendStopCommand()
        }
    }
    
    func cancelMission() {
        if var mission = activeMission {
            mission.status = .cancelled
            updateMission(mission)
            activeMission = nil
            sendStopCommand()
        }
    }
    
    private func updateMission(_ mission: Mission) {
        if let index = missions.firstIndex(where: { $0.id == mission.id }) {
            missions[index] = mission
        }
    }
}

import Combine

extension RobotControllerState: RobotCommunicationDelegate {
    func didReceiveRobotStatus(_ status: RobotStatusUpdate) {
        // Status is already updated via the published property binding
        checkMissionProgress()
    }
    
    func didReceiveCommandResponse(_ response: RobotCommandResponse) {
        print("📨 Received command response: \(response.status) for command \(response.commandId)")
    }
    
    func connectionStateChanged(_ state: ConnectionState) {
        // State is already updated via the published property binding
        if case .connected = state {
            print("✅ Robot controller connected")
        }
    }
    
    private func checkMissionProgress() {
        guard var mission = activeMission,
              mission.status == .active,
              let robotPos = robotStatus?.position else { return }
        
        // Check if robot reached current waypoint
        let currentWaypoint = mission.waypoints.first { !$0.isCompleted }
        
        if let waypoint = currentWaypoint {
            let distance = simd_distance(robotPos, waypoint.position)
            if distance < 0.5 { // Within 50cm of waypoint
                // Mark waypoint as completed
                if let index = mission.waypoints.firstIndex(where: { $0.id == waypoint.id }) {
                    mission.waypoints[index].isCompleted = true
                }
                
                // Send next waypoint or complete mission
                if let nextWaypoint = mission.waypoints.first(where: { !$0.isCompleted }) {
                    sendGoToWaypoint(nextWaypoint.position)
                } else {
                    // Mission completed
                    mission.status = .completed
                    activeMission = nil
                }
                
                updateMission(mission)
            }
        }
    }
}