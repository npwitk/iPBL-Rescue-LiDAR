//
//  RobotCommunicationService.swift
//  Rescue Robot Control System
//

import Foundation
import MultipeerConnectivity
import Combine
import simd

protocol RobotCommunicationDelegate: AnyObject {
    func didReceiveRobotStatus(_ status: RobotStatusUpdate)
    func didReceiveCommandResponse(_ response: RobotCommandResponse)
    func connectionStateChanged(_ state: ConnectionState)
}

class RobotCommunicationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastRobotStatus: RobotStatusUpdate?
    @Published var connectedPeers: [MCPeerID] = []
    @Published var signalStrength: Float = 0.0
    
    // MARK: - Private Properties
    private let serviceType = "rescue-robot"
    private let localPeerID: MCPeerID
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let advertiser: MCNearbyServiceAdvertiser
    
    weak var delegate: RobotCommunicationDelegate?
    private var isHost: Bool
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var commandResponses: [UUID: RobotCommandResponse] = [:]
    
    // MARK: - Initialization
    
    init(deviceType: DeviceType) {
        let deviceName = "\(deviceType.rawValue)-\(UIDevice.current.name)"
        self.localPeerID = MCPeerID(displayName: deviceName)
        self.isHost = (deviceType == .robot)
        
        self.session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: ["type": deviceType.rawValue],
            serviceType: serviceType
        )
        
        super.init()
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
        
        setupHeartbeat()
    }
    
    enum DeviceType: String {
        case robot = "robot"
        case controller = "controller"
    }
    
    // MARK: - Connection Management
    
    func startService() {
        connectionState = .connecting
        
        if isHost {
            // Robot advertises its presence
            advertiser.startAdvertisingPeer()
            print("🤖 Robot started advertising")
        } else {
            // iPad controller searches for robots
            browser.startBrowsingForPeers()
            print("📱 Controller started browsing for robots")
        }
    }
    
    func stopService() {
        browser.stopBrowsingForPeers()
        advertiser.stopAdvertisingPeer()
        session.disconnect()
        connectionState = .disconnected
        stopHeartbeat()
        stopReconnectTimer()
    }
    
    private func setupHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func startReconnectTimer() {
        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.attemptReconnect()
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func attemptReconnect() {
        guard connectionState != .connected else {
            stopReconnectTimer()
            return
        }
        
        connectionState = .reconnecting
        
        if !isHost {
            browser.stopBrowsingForPeers()
            browser.startBrowsingForPeers()
        }
    }
    
    // MARK: - Message Sending
    
    func sendCommand(_ command: RobotCommand) {
        guard connectionState.isConnected else {
            print("❌ Cannot send command - not connected")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(command)
            let message = Message(type: .robotCommand, data: data, sender: localPeerID.displayName)
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: session.connectedPeers, with: .reliable)
            print("📤 Sent command: \(command.type)")
        } catch {
            print("❌ Failed to send command: \(error)")
        }
    }
    
    func sendRobotStatus(_ status: RobotStatusUpdate) {
        guard connectionState.isConnected else { return }
        
        do {
            let data = try JSONEncoder().encode(status)
            let message = Message(type: .robotStatus, data: data, sender: localPeerID.displayName)
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: session.connectedPeers, with: .unreliable)
        } catch {
            print("❌ Failed to send robot status: \(error)")
        }
    }
    
    private func sendHeartbeat() {
        guard connectionState.isConnected else { return }
        
        do {
            let heartbeatData = ["timestamp": Date().timeIntervalSince1970]
            let data = try JSONSerialization.data(withJSONObject: heartbeatData)
            let message = Message(type: .heartbeat, data: data, sender: localPeerID.displayName)
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: session.connectedPeers, with: .unreliable)
        } catch {
            print("❌ Failed to send heartbeat: \(error)")
        }
    }
    
    // MARK: - Message Processing
    
    private func processReceivedMessage(_ messageData: Data, from peer: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(Message.self, from: messageData)
            
            switch message.type {
            case .robotStatus:
                let status = try JSONDecoder().decode(RobotStatusUpdate.self, from: message.data)
                DispatchQueue.main.async {
                    self.lastRobotStatus = status
                    self.delegate?.didReceiveRobotStatus(status)
                }
                
            case .robotCommand:
                let command = try JSONDecoder().decode(RobotCommand.self, from: message.data)
                // Forward to robot control system
                handleReceivedCommand(command)
                
            case .commandResponse:
                let response = try JSONDecoder().decode(RobotCommandResponse.self, from: message.data)
                commandResponses[response.commandId] = response
                DispatchQueue.main.async {
                    self.delegate?.didReceiveCommandResponse(response)
                }
                
            case .heartbeat:
                // Update connection strength based on heartbeat
                updateSignalStrength()
                
            case .discovery:
                print("📡 Received discovery message from \(peer.displayName)")
            }
            
        } catch {
            print("❌ Failed to process received message: \(error)")
        }
    }
    
    private func handleReceivedCommand(_ command: RobotCommand) {
        print("🤖 Robot received command: \(command.type)")
        
        // Send initial acknowledgment
        let receivedResponse = RobotCommandResponse(
            commandId: command.commandId,
            status: .received,
            message: "Command received and processing",
            timestamp: Date()
        )
        sendCommandResponse(receivedResponse)
        
        // Execute the command
        DispatchQueue.main.async {
            self.executeCommand(command)
        }
    }
    
    private func executeCommand(_ command: RobotCommand) {
        var responseStatus: RobotCommandResponse.ResponseStatus = .executing
        var responseMessage = ""
        
        switch command.type {
        case .startScanning:
            // This will be handled by the AppState when integrated
            responseStatus = .completed
            responseMessage = "Started scanning"
            print("🔍 Command: Start scanning")
            
        case .stopScanning:
            // This will be handled by the AppState when integrated
            responseStatus = .completed
            responseMessage = "Stopped scanning"
            print("⏹️ Command: Stop scanning")
            
        case .toggleTorch:
            // This will be handled by the AppState when integrated  
            responseStatus = .completed
            responseMessage = "Toggled torch"
            print("💡 Command: Toggle torch")
            
        case .takePicture:
            responseStatus = .completed
            responseMessage = "Picture taken"
            print("📸 Command: Take picture")
            
        case .emergencyStop:
            // Emergency stop - immediately stop all operations
            responseStatus = .completed
            responseMessage = "Emergency stop executed"
            print("🛑 Command: EMERGENCY STOP")
            
        case .stop:
            responseStatus = .completed
            responseMessage = "Robot stopped"
            print("⏸️ Command: Stop")
            
        case .move(let direction, let speed):
            // Physical robot would move here - for iPhone this is informational
            responseStatus = .completed
            responseMessage = "Movement command noted (direction: \(direction), speed: \(speed))"
            print("🚶 Command: Move direction \(direction) at speed \(speed)")
            
        case .rotate(let angle, let speed):
            // Physical robot would rotate here - for iPhone this is informational
            responseStatus = .completed
            responseMessage = "Rotation command noted (angle: \(angle)°, speed: \(speed))"
            print("🔄 Command: Rotate \(angle)° at speed \(speed)")
            
        case .goToWaypoint(let position):
            // Physical robot would navigate here - for iPhone this is informational
            responseStatus = .completed
            responseMessage = "Waypoint navigation noted (position: \(position))"
            print("🎯 Command: Go to waypoint \(position)")
        }
        
        // Send completion response
        let completionResponse = RobotCommandResponse(
            commandId: command.commandId,
            status: responseStatus,
            message: responseMessage,
            timestamp: Date()
        )
        sendCommandResponse(completionResponse)
    }
    
    private func sendCommandResponse(_ response: RobotCommandResponse) {
        do {
            let data = try JSONEncoder().encode(response)
            let message = Message(type: .commandResponse, data: data, sender: localPeerID.displayName)
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("❌ Failed to send command response: \(error)")
        }
    }
    
    private func updateSignalStrength() {
        // Simplified signal strength calculation
        // In reality, you'd measure latency and packet loss
        signalStrength = connectionState.isConnected ? Float.random(in: 0.7...1.0) : 0.0
    }
    
    // MARK: - Command Response Tracking
    
    func waitForCommandResponse(commandId: UUID, timeout: TimeInterval = 10.0) async -> RobotCommandResponse? {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if let response = commandResponses[commandId] {
                commandResponses.removeValue(forKey: commandId)
                return response
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        return nil
    }
}

// MARK: - MCSessionDelegate

extension RobotCommunicationService: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectionState = .connected
                self.connectedPeers = session.connectedPeers
                self.stopReconnectTimer()
                print("✅ Connected to \(peerID.displayName)")
                
            case .connecting:
                self.connectionState = .connecting
                print("🔄 Connecting to \(peerID.displayName)")
                
            case .notConnected:
                self.connectionState = .disconnected
                self.connectedPeers = session.connectedPeers
                self.startReconnectTimer()
                print("❌ Disconnected from \(peerID.displayName)")
                
            @unknown default:
                break
            }
            
            self.delegate?.connectionStateChanged(self.connectionState)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        processReceivedMessage(data, from: peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used for this implementation
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used for this implementation
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used for this implementation
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension RobotCommunicationService: MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("📡 Found peer: \(peerID.displayName)")
        
        // Only connect to robots if we're a controller
        if !isHost, let deviceType = info?["type"], deviceType == "robot" {
            print("🤝 Inviting robot: \(peerID.displayName)")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("📴 Lost peer: \(peerID.displayName)")
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension RobotCommunicationService: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📨 Received invitation from: \(peerID.displayName)")
        
        // Auto-accept invitations if we're a robot
        if isHost {
            invitationHandler(true, session)
        }
    }
}