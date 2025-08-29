//
//  NetworkReceiver.swift
//  Robot Map Viewer
//

import Foundation
import Network
import simd
import Combine

class NetworkReceiver: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var lastMessageReceived: Date?
    @Published var messagesReceived: Int = 0
    @Published var connectionStatus = "Not listening"
    
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "NetworkReceiver", qos: .userInteractive)
    private let decoder = JSONDecoder()
    
    private weak var appState: MacAppState?
    private weak var visualizationEngine: VisualizationEngine?
    
    // Statistics
    @Published var bytesReceived: UInt64 = 0
    @Published var messagesPerSecond: Double = 0
    private var messageCount = 0
    private var lastStatsUpdate = Date()
    
    // Configuration
    private let port: NWEndpoint.Port = 12345
    
    override init() {
        super.init()
        decoder.dateDecodingStrategy = .iso8601
    }
    
    deinit {
        stopListening()
    }
    
    func configure(appState: MacAppState, visualizationEngine: VisualizationEngine) {
        self.appState = appState
        self.visualizationEngine = visualizationEngine
    }
    
    // MARK: - Network Management
    func startListening() {
        stopListening() // Ensure clean start
        
        do {
            listener = try NWListener(using: .tcp, on: port)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleListenerStateChange(state)
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("New connection from iPhone")
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: queue)
            print("Started listening on port \(port)")
            
        } catch {
            print("Failed to create listener: \(error)")
            connectionStatus = "Failed to start: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        connection?.cancel()
        connection = nil
        
        listener?.cancel()
        listener = nil
        
        DispatchQueue.main.async {
            self.isListening = false
            self.connectionStatus = "Not listening"
            self.appState?.isConnected = false
        }
    }
    
    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            connectionStatus = "Listening on port \(port)"
            
        case .failed(let error):
            isListening = false
            connectionStatus = "Failed: \(error.localizedDescription)"
            print("Listener failed: \(error)")
            
        case .cancelled:
            isListening = false
            connectionStatus = "Cancelled"
            
        default:
            break
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        // Cancel existing connection
        self.connection?.cancel()
        self.connection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionStateChange(state)
            }
        }
        
        connection.start(queue: queue)
        startReceivingMessages(connection)
    }
    
    private func handleConnectionStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionStatus = "Connected to iPhone"
            appState?.isConnected = true
            print("iPhone connected")
            
        case .failed(let error):
            connectionStatus = "Connection failed: \(error.localizedDescription)"
            appState?.isConnected = false
            print("Connection failed: \(error)")
            
        case .cancelled:
            connectionStatus = "iPhone disconnected"
            appState?.isConnected = false
            print("iPhone disconnected")
            
        default:
            break
        }
    }
    
    // MARK: - Message Receiving
    private func startReceivingMessages(_ connection: NWConnection) {
        // Receive message length first (4 bytes)
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, data.count == 4 else {
                if let error = error {
                    print("Error receiving length: \(error)")
                }
                return
            }
            
            let messageLength = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // Receive the actual message
            connection.receive(minimumIncompleteLength: Int(messageLength), maximumLength: Int(messageLength)) { messageData, _, _, error in
                guard let messageData = messageData else {
                    if let error = error {
                        print("Error receiving message: \(error)")
                    }
                    return
                }
                
                self.processReceivedMessage(messageData)
                
                // Continue receiving if connection is still active
                if !isComplete && error == nil {
                    self.startReceivingMessages(connection)
                }
            }
        }
    }
    
    private func processReceivedMessage(_ data: Data) {
        do {
            let message = try decoder.decode(NetworkMessage.self, from: data)
            
            DispatchQueue.main.async {
                self.handleReceivedMessage(message)
                self.updateStatistics(dataSize: data.count)
            }
            
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    // MARK: - Message Handling
    private func handleReceivedMessage(_ message: NetworkMessage) {
        lastMessageReceived = Date()
        
        switch message {
        case .robotPosition(let robotMessage):
            let position = simd_float3(robotMessage.position[0], robotMessage.position[1], robotMessage.position[2])
            let rotation = simd_quatf(ix: robotMessage.rotation[0], iy: robotMessage.rotation[1], iz: robotMessage.rotation[2], r: robotMessage.rotation[3])
            
            appState?.updateRobotPosition(position, rotation: rotation)
            visualizationEngine?.updateRobotPosition(position, rotation: rotation)
            
        case .meshUpdate(let meshMessage):
            processMeshUpdate(meshMessage)
            
        case .personDetection(let detectionMessage):
            let detection = RemotePersonDetection(
                id: detectionMessage.id,
                position: simd_float3(detectionMessage.position[0], detectionMessage.position[1], detectionMessage.position[2]),
                confidence: detectionMessage.confidence,
                stability: detectionMessage.stability,
                timestamp: detectionMessage.timestamp
            )
            
            appState?.addOrUpdateDetection(detection)
            visualizationEngine?.updatePersonDetection(detection)
            
        case .sessionStart(let sessionMessage):
            appState?.currentSessionId = sessionMessage.sessionId
            print("Started session: \(sessionMessage.sessionId)")
            
        case .sessionEnd(let sessionMessage):
            print("Ended session: \(sessionMessage.sessionId) with \(sessionMessage.totalDetections) detections")
            
        case .heartbeat(let heartbeatMessage):
            appState?.lastHeartbeat = heartbeatMessage.timestamp
        }
    }
    
    private func processMeshUpdate(_ meshMessage: MeshUpdateMessage) {
        // Convert vertices from flat array to simd_float3 array
        var vertices: [simd_float3] = []
        for i in stride(from: 0, to: meshMessage.vertices.count, by: 3) {
            if i + 2 < meshMessage.vertices.count {
                vertices.append(simd_float3(
                    meshMessage.vertices[i],
                    meshMessage.vertices[i + 1],
                    meshMessage.vertices[i + 2]
                ))
            }
        }
        
        // Convert transform array to matrix
        let t = meshMessage.transform
        let transform = simd_float4x4(
            simd_float4(t[0], t[1], t[2], t[3]),
            simd_float4(t[4], t[5], t[6], t[7]),
            simd_float4(t[8], t[9], t[10], t[11]),
            simd_float4(t[12], t[13], t[14], t[15])
        )
        
        let meshData = RemoteMeshData(
            anchorId: meshMessage.anchorId,
            vertices: vertices,
            faces: meshMessage.faces,
            transform: transform,
            timestamp: meshMessage.timestamp
        )
        
        appState?.addOrUpdateMesh(meshData)
        visualizationEngine?.updateMesh(meshData)
    }
    
    // MARK: - Statistics
    private func updateStatistics(dataSize: Int) {
        messageCount += 1
        bytesReceived += UInt64(dataSize)
        messagesReceived += 1
        
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastStatsUpdate)
        
        if timeDiff >= 1.0 {
            messagesPerSecond = Double(messageCount) / timeDiff
            messageCount = 0
            lastStatsUpdate = now
        }
    }
    
    func resetStatistics() {
        bytesReceived = 0
        messagesPerSecond = 0
        messagesReceived = 0
        messageCount = 0
        lastStatsUpdate = Date()
    }
}