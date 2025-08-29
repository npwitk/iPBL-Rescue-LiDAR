//
//  NetworkControlsView.swift
//  Rescue Robot Sensor Head
//

import SwiftUI

struct NetworkControlsView: View {
    @ObservedObject var networkService: NetworkService
    @ObservedObject var streamingStats: StreamingStats
    @State private var showingConnectionSheet = false
    @State private var macIPAddress = ""
    @State private var macPort = "12345"
    
    var body: some View {
        HStack(spacing: 12) {
            // Connection Status Indicator
            connectionStatusButton
            
            if networkService.isConnected {
                // Data Stats when connected
                dataStatsView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .sheet(isPresented: $showingConnectionSheet) {
            ConnectionSetupSheet(
                networkService: networkService,
                macIPAddress: $macIPAddress,
                macPort: $macPort
            )
        }
    }
    
    private var connectionStatusButton: some View {
        Button(action: {
            if networkService.isConnected {
                networkService.disconnect()
            } else {
                showingConnectionSheet = true
            }
        }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(networkService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: networkService.isConnected)
                
                Text(networkService.isConnected ? "Connected" : "Connect")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(12)
        }
    }
    
    private var dataStatsView: some View {
        HStack(spacing: 8) {
            // Data sent indicator
            VStack(spacing: 2) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text(formatDataSize(streamingStats.totalBytesSent))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Messages per second
            VStack(spacing: 2) {
                Image(systemName: "speedometer")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("\(Int(streamingStats.messagesPerSecond))/s")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Last data sent indicator
            if let lastSent = networkService.lastDataSent {
                VStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(timeAgo(lastSent))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    private func formatDataSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 1 {
            return "now"
        } else if interval < 60 {
            return "\(Int(interval))s"
        } else {
            return "\(Int(interval / 60))m"
        }
    }
}

struct ConnectionSetupSheet: View {
    @ObservedObject var networkService: NetworkService
    @Binding var macIPAddress: String
    @Binding var macPort: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingIPScanner = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Mac Connection") {
                    HStack {
                        Text("IP Address")
                        Spacer()
                        TextField("192.168.1.100", text: $macIPAddress)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("12345", text: $macPort)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                    }
                }
                
                Section("Quick Setup") {
                    Button("Scan for Mac Apps") {
                        showingIPScanner = true
                    }
                    .disabled(true) // Future feature
                    
                    Button("Use Default Settings") {
                        macIPAddress = getDefaultIPAddress()
                        macPort = "12345"
                    }
                }
                
                Section("Connection Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(networkService.connectionStatus)
                            .foregroundColor(networkService.isConnected ? .green : .red)
                    }
                    
                    if let localIP = NetworkService.getLocalIPAddress() {
                        HStack {
                            Text("iPhone IP")
                            Spacer()
                            Text(localIP)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Ensure your Mac companion app is running")
                        Text("2. Both devices must be on the same WiFi network")
                        Text("3. Enter your Mac's IP address above")
                        Text("4. Default port is 12345")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Connect to Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Connect") {
                        connectToMac()
                    }
                    .disabled(macIPAddress.isEmpty)
                }
            }
        }
    }
    
    private func connectToMac() {
        guard !macIPAddress.isEmpty,
              let port = UInt16(macPort) else { return }
        
        networkService.connectToMac(host: macIPAddress, port: port)
        dismiss()
    }
    
    private func getDefaultIPAddress() -> String {
        // Get local network base and suggest common Mac IP
        if let localIP = NetworkService.getLocalIPAddress() {
            let components = localIP.components(separatedBy: ".")
            if components.count >= 3 {
                return "\(components[0]).\(components[1]).\(components[2]).100"
            }
        }
        return "192.168.1.100"
    }
}

#Preview {
    VStack {
        NetworkControlsView(
            networkService: NetworkService(),
            streamingStats: StreamingStats()
        )
        Spacer()
    }
    .background(Color.black)
}