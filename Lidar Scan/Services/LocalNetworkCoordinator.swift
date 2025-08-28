//
//  LocalNetworkCoordinator.swift
//  Rescue Robot Control System
//

import Foundation
import MultipeerConnectivity
import SwiftUI

class LocalNetworkCoordinator: NSObject, ObservableObject {
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private let session: MCSession
    
    // All devices that are advertising
    @Published var allDevices: Set<MCPeerID> = []
    
    // All devices that are connected with current device
    @Published var connectedDevices: Set<MCPeerID> = []
    
    // Connection state for UI
    @Published var connectionState: ConnectionState = .disconnected
    
    // Devices that are available but not connected
    var otherDevices: Set<MCPeerID> {
        allDevices.subtracting(connectedDevices)
    }
    
    // Last received robot status (for iPad)
    @Published var lastStatusUpdate: RobotStatusUpdate?
    
    // Device type
    let deviceType: DeviceType
    
    enum DeviceType {
        case robot      // iPhone - advertises service
        case controller // iPad - browses for service
    }
    
    init(deviceType: DeviceType = UIDevice.current.userInterfaceIdiom == .pad ? .controller : .robot) {
        self.deviceType = deviceType
        
        // Create peer ID with device type info
        let deviceName = UIDevice.current.name
        let peerName = "\(deviceName) - \(deviceType == .robot ? "Robot" : "Controller")"
        let peerID = MCPeerID(displayName: peerName)
        
        // Initialize MultipeerConnectivity components
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["deviceType": deviceType == .robot ? "robot" : "controller"],
            serviceType: .rescueRobotService
        )
        
        browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: .rescueRobotService
        )
        
        session = MCSession(peer: peerID)
        
        super.init()
        
        // Set delegates
        advertiser.delegate = self
        browser.delegate = self
        session.delegate = self
        
        // Start appropriate service based on device type
        startServices()
    }
    
    // MARK: - Service Management
    
    private func startServices() {
        if deviceType == .robot {
            startAdvertising()
        } else {
            startBrowsing()
        }
    }
    
    public func startAdvertising() {
        print("🤖 Starting advertising as robot")
        advertiser.startAdvertisingPeer()
        connectionState = .connecting
    }
    
    public func stopAdvertising() {
        print("🛑 Stopping advertising")
        advertiser.stopAdvertisingPeer()
    }
    
    public func startBrowsing() {
        print("📱 Starting browsing as controller")
        browser.startBrowsingForPeers()
        connectionState = .connecting
    }
    
    public func stopBrowsing() {
        print("🛑 Stopping browsing")
        browser.stopBrowsingForPeers()
    }
    
    // Invite a specific peer to connect
    public func invitePeer(_ peerID: MCPeerID) {
        print("📤 Inviting \(peerID.displayName) to connect")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    // Disconnect from all peers
    public func disconnect() {
        print("🔌 Disconnecting session")
        session.disconnect()
        connectionState = .disconnected
    }
    
    // MARK: - Data Transmission
    
    public func sendRobotStatus(_ status: RobotStatusUpdate) {
        guard deviceType == .robot, !connectedDevices.isEmpty else { return }
        
        do {
            let message = Message(
                type: .robotStatus,
                data: try JSONEncoder().encode(status),
                sender: session.myPeerID.displayName
            )
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: Array(connectedDevices), with: .reliable)
            print("📤 Sent robot status to \(connectedDevices.count) devices")
        } catch {
            print("❌ Failed to send robot status: \(error)")
        }
    }
    
    public func sendCommand(_ command: RobotCommand) {
        guard deviceType == .controller, !connectedDevices.isEmpty else { return }
        
        do {
            let message = Message(
                type: .robotCommand,
                data: try JSONEncoder().encode(command),
                sender: session.myPeerID.displayName
            )
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: Array(connectedDevices), with: .reliable)
            print("📤 Sent command to \(connectedDevices.count) devices")
        } catch {
            print("❌ Failed to send command: \(error)")
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension LocalNetworkCoordinator: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        print("📞 Received invitation from \(peerID.displayName)")
        
        DispatchQueue.main.async {
            // Auto-accept invitations from controllers for robots
            if self.deviceType == .robot {
                print("✅ Auto-accepting invitation from controller")
                invitationHandler(true, self.session)
            } else {
                // Controllers should not receive invitations
                print("❌ Rejecting unexpected invitation")
                invitationHandler(false, nil)
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension LocalNetworkCoordinator: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        print("🔍 Found peer: \(peerID.displayName) with info: \(String(describing: info))")
        
        DispatchQueue.main.async {
            self.allDevices.insert(peerID)
        }
    }
    
    func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        print("👻 Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.allDevices.remove(peerID)
            self.connectedDevices.remove(peerID)
        }
    }
}

// MARK: - MCSessionDelegate

extension LocalNetworkCoordinator: MCSessionDelegate {
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        print("🔗 Session state changed for \(peerID.displayName): \(state.rawValue)")
        
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("✅ Connected to \(peerID.displayName)")
                self.connectedDevices.insert(peerID)
                self.connectionState = .connected
                
            case .connecting:
                print("🔄 Connecting to \(peerID.displayName)")
                self.connectionState = .connecting
                
            case .notConnected:
                print("❌ Disconnected from \(peerID.displayName)")
                self.connectedDevices.remove(peerID)
                self.connectionState = self.connectedDevices.isEmpty ? .disconnected : .connected
                
            @unknown default:
                break
            }
        }
    }
    
    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        do {
            let message = try JSONDecoder().decode(Message.self, from: data)
            
            DispatchQueue.main.async {
                self.handleReceivedMessage(message)
            }
        } catch {
            print("❌ Failed to decode message: \(error)")
        }
    }
    
    private func handleReceivedMessage(_ message: Message) {
        switch message.type {
        case .robotStatus:
            if deviceType == .controller {
                do {
                    let status = try JSONDecoder().decode(RobotStatusUpdate.self, from: message.data)
                    lastStatusUpdate = status
                    print("📥 Received robot status update")
                } catch {
                    print("❌ Failed to decode robot status: \(error)")
                }
            }
            
        case .robotCommand:
            if deviceType == .robot {
                // Handle commands on robot
                NotificationCenter.default.post(
                    name: NSNotification.Name("RobotCommandReceived"),
                    object: message.data
                )
                print("📥 Received robot command")
            }
            
        default:
            break
        }
    }
    
    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {
        // Handle streams if needed
    }
    
    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
        // Handle resource transfers if needed
    }
    
    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        // Handle resource transfers if needed
    }
}

// MARK: - Service Type Extension

private extension String {
    // Service type must be 1-15 characters, contain only ASCII lowercase letters, numbers, and hyphens
    static let rescueRobotService = "rescue-robot"
}