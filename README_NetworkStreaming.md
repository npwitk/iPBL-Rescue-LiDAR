# iPhone-to-Mac 3D Map Streaming Setup

## Overview
This system allows your iPhone app to act as a robot head, streaming live 3D mapping data and person detections to a Mac companion app for real-time monitoring and visualization.

## Features
- **Real-time robot position streaming** (30 FPS)
- **3D mesh data transmission** with compression (2 FPS) 
- **Person detection updates** with confidence and stability (10 FPS)
- **Interactive 3D visualization** on Mac
- **Session management** and statistics tracking
- **Connection status monitoring**

## Setup Instructions

### iPhone App (Robot Head)
1. Build and run the updated iPhone app
2. The app now includes network controls in the top-left area of the AR view
3. Tap the connection button to open the Mac connection setup

### Mac Companion App  
1. Create a new macOS app project in Xcode
2. Add the files from `Mac Companion App/RobotMapViewer/` to your project:
   - `RobotMapViewerApp.swift`
   - `ContentView.swift` 
   - `NetworkReceiver.swift`
   - `VisualizationEngine.swift`
   - `SceneKitView.swift`
   - `NetworkProtocol.swift`
3. Add SceneKit framework to your project
4. Build and run the Mac app

### Network Connection
1. **Start Mac app first** - Click "Start Listening" or use Cmd+S
2. **Get Mac IP address** - Note the Mac's local IP address (shown in app or from System Settings > Network)
3. **Connect from iPhone**:
   - Tap "Connect" in the iPhone app's network controls
   - Enter your Mac's IP address (e.g., 192.168.1.100)
   - Default port is 12345
   - Tap "Connect"

## Usage
1. **Start scanning session** on iPhone
2. **Monitor real-time data** on Mac:
   - Robot position and path visualization
   - Person detections with stability indicators
   - 3D mesh reconstruction from LiDAR
3. **Interactive controls** on Mac:
   - Click on person detections to focus camera
   - Toggle visibility of different data layers
   - View connection statistics and data throughput

## Network Requirements
- Both iPhone and Mac must be on the **same WiFi network**
- Default port: **12345** (TCP)
- Automatic compression reduces bandwidth usage
- Heartbeat system maintains connection health

## Troubleshooting

### Connection Issues
- Verify both devices are on same WiFi network
- Check Mac's firewall settings (allow incoming connections on port 12345)
- Ensure Mac app is listening before connecting iPhone

### Performance
- Mesh data is automatically compressed and throttled to 2 FPS
- Robot position updates at 30 FPS for smooth tracking
- Person detections stream at 10 FPS when detected

### Data Flow
1. **iPhone captures**: AR camera frames, LiDAR mesh data, person detections
2. **iPhone processes**: Compresses mesh data, tracks person positions
3. **iPhone streams**: Sends data over TCP to Mac
4. **Mac receives**: Decodes and visualizes data in real-time

## File Structure
```
iPhone App/
├── Services/
│   ├── NetworkService.swift          # TCP client, message protocols
│   ├── MeshStreamingProtocol.swift   # 3D data compression
│   └── ARMapper.swift                # Enhanced with streaming
├── Views/Components/
│   └── NetworkControlsView.swift     # Connection UI

Mac Companion App/
├── RobotMapViewerApp.swift          # Main Mac app
├── ContentView.swift                # UI layout
├── NetworkReceiver.swift            # TCP server
├── VisualizationEngine.swift        # 3D rendering with SceneKit
├── SceneKitView.swift               # SwiftUI wrapper
└── NetworkProtocol.swift            # Shared message types
```

## Technical Details
- **Mesh Compression**: Quantizes vertices to 16-bit for ~4x size reduction
- **Delta Updates**: Only sends mesh changes when needed
- **Heartbeat System**: 5-second intervals ensure connection health
- **Multi-threaded**: Network operations on background queues
- **Statistics Tracking**: Real-time bandwidth and throughput monitoring

The system is now ready for robot head operation with real-time Mac visualization!