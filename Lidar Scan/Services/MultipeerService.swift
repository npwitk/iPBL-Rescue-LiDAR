//
//  MultipeerService.swift
//  Rescue Robot Control System
//

import Foundation
import MultipeerConnectivity
import Combine

@MainActor
class MultipeerService: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedPeers: [MCPeerID] = []
    @Published var lastStatusUpdate: RobotStatusUpdate?
    
    private let serviceType = "rescue-robot" // Must be 1-15 characters, contain only ASCII lowercase letters, numbers, and hyphens
    private let peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    let deviceType: DeviceType
    
    enum DeviceType {
        case robot      // iPhone - advertises itself
        case controller // iPad - browses for robot
    }
    
    override init() {
        // Use device model to determine type
        let deviceName = UIDevice.current.name
        self.deviceType = UIDevice.current.userInterfaceIdiom == .pad ? .controller : .robot
        
        // Create unique peer ID
        let peerName = "\(deviceName) - \(deviceType == .robot ? "Robot" : "Controller")"
        self.peerID = MCPeerID(displayName: peerName)
        
        // Initialize session
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        
        super.init()
        
        session.delegate = self
        
        // Start appropriate service based on device type
        if deviceType == .robot {
            startAdvertising()
        } else {
            startBrowsing()
        }
    }
    
    deinit {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }
    
    // MARK: - Service Management
    
    private func startAdvertising() {
        guard deviceType == .robot else { return }
        
        print("🤖 Starting advertising as robot: \(peerID.displayName)")
        
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["deviceType": "robot"],
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        connectionState = .connecting
        print("📡 Advertising started for service type: \(serviceType)")
    }
    
    private func startBrowsing() {
        guard deviceType == .controller else { return }
        
        print("📱 Starting browsing as controller: \(peerID.displayName)")
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        connectionState = .connecting
        print("🔍 Browsing started for service type: \(serviceType)")
    }
    
    private func stopServices() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        
        advertiser = nil
        browser = nil
        connectionState = .disconnected
    }
    
    // MARK: - Data Transmission
    
    func sendStatusUpdate(_ status: RobotStatusUpdate) {
        guard deviceType == .robot, !connectedPeers.isEmpty else { return }
        
        do {
            let message = Message(type: .robotStatus, data: try JSONEncoder().encode(status), sender: peerID.displayName)
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: connectedPeers, with: .reliable)
        } catch {
            print("Failed to send status update: \(error)")
        }
    }
    
    func sendCommand(_ command: RobotCommand) {
        guard deviceType == .controller, !connectedPeers.isEmpty else { return }
        
        do {
            let message = Message(type: .robotCommand, data: try JSONEncoder().encode(command), sender: peerID.displayName)
            let messageData = try JSONEncoder().encode(message)
            
            try session.send(messageData, toPeers: connectedPeers, with: .reliable)
        } catch {
            print("Failed to send command: \(error)")
        }
    }
    
    // MARK: - Connection Management
    
    func disconnect() {
        stopServices()
    }
    
    func reconnect() {
        stopServices()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.deviceType == .robot {
                self.startAdvertising()
            } else {
                self.startBrowsing()
            }
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("🔗 Session state changed for \(peerID.displayName): \(state)")
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("✅ Connected to \(peerID.displayName)")
                self.connectedPeers.append(peerID)
                self.connectionState = .connected
                
            case .connecting:
                print("🔄 Connecting to \(peerID.displayName)")
                self.connectionState = .connecting
                
            case .notConnected:
                print("❌ Disconnected from \(peerID.displayName)")
                self.connectedPeers.removeAll { $0 == peerID }
                self.connectionState = self.connectedPeers.isEmpty ? .disconnected : .connected
                
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(Message.self, from: data)
            
            DispatchQueue.main.async {
                self.handleReceivedMessage(message)
            }
        } catch {
            print("Failed to decode received message: \(error)")
        }
    }
    
    private func handleReceivedMessage(_ message: Message) {
        switch message.type {
        case .robotStatus:
            if deviceType == .controller {
                do {
                    let status = try JSONDecoder().decode(RobotStatusUpdate.self, from: message.data)
                    lastStatusUpdate = status
                } catch {
                    print("Failed to decode robot status: \(error)")
                }
            }
            
        case .robotCommand:
            if deviceType == .robot {
                // Robot receives commands - handle in main app
                NotificationCenter.default.post(
                    name: NSNotification.Name("RobotCommandReceived"),
                    object: message.data
                )
            }
            
        default:
            break
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle streams if needed
    }
    
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Handle resource transfers if needed
    }
    
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Handle resource transfers if needed
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📞 Received invitation from \(peerID.displayName)")
        // Auto-accept invitations from controllers
        Task { @MainActor in
            print("✅ Accepting invitation from \(peerID.displayName)")
            invitationHandler(true, self.session)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("🔍 Found peer: \(peerID.displayName) with info: \(String(describing: info))")
        // Auto-connect to robots
        if info?["deviceType"] == "robot" {
            print("🤖 Found robot, sending invitation to \(peerID.displayName)")
            Task { @MainActor in
                browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Handle peer loss
    }
}
