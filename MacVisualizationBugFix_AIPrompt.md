# AI Prompt: Fix Mac App 3D Visualization - Data Receiving But Not Displaying

## Problem Statement
The iPhone app is successfully connecting to the Mac companion app and sending real-time 3D mapping data (robot position, mesh data, person detections), but the Mac app is not displaying/visualizing this data in the 3D scene. The data transmission is working but the visualization pipeline has bugs.

## Current Situation
✅ **iPhone app**: Successfully sending data (connection established, no crashes)  
❌ **Mac app**: Receiving data but not showing it in 3D visualization  
❌ **Expected**: Real-time 3D map display with robot path, mesh, and person markers

## Mac App Architecture Overview

The Mac app has these key components that handle data flow:

### 1. **NetworkReceiver.swift** - Data Reception
- **Purpose**: TCP server receiving iPhone data streams
- **Key Methods**:
  - `startListening()` - Starts TCP server on port 12345
  - `processReceivedMessage()` - Decodes JSON messages from iPhone
  - `handleReceivedMessage()` - Routes messages to app state and visualization
- **Expected Behavior**: Receives messages and updates MacAppState + VisualizationEngine

### 2. **MacAppState** - Data Storage  
- **Purpose**: Central state management for received data
- **Key Properties**:
  - `@Published var robotPosition: simd_float3`
  - `@Published var detectedPersons: [RemotePersonDetection]`
  - `@Published var meshData: [RemoteMeshData]`
- **Expected Behavior**: UI automatically updates when @Published properties change

### 3. **VisualizationEngine.swift** - 3D Rendering
- **Purpose**: SceneKit-based 3D scene management
- **Key Methods**:
  - `updateRobotPosition()` - Shows robot as iPhone device with trail
  - `updatePersonDetection()` - Displays person as colored sphere
  - `updateMesh()` - Renders LiDAR mesh as wireframe
- **Expected Behavior**: Creates/updates SceneKit nodes for real-time display

### 4. **SceneKitView.swift** - UI Integration
- **Purpose**: SwiftUI wrapper for SCNView
- **Expected Behavior**: Updates 3D scene when VisualizationEngine changes

## Data Flow Debug Checklist

### Phase 1: Verify Data Reception
```swift
// In NetworkReceiver.handleReceivedMessage()
print("🔍 DEBUG: Received message type: \(message)")
print("🔍 DEBUG: Robot position: \(robotMessage.position)")
print("🔍 DEBUG: AppState robot position updated: \(appState?.robotPosition)")
```

### Phase 2: Check State Updates  
```swift
// In MacAppState
func updateRobotPosition(_ position: simd_float3, rotation: simd_quatf) {
    print("🔍 DEBUG: MacAppState updating robot to: \(position)")
    self.robotPosition = position
    self.robotRotation = rotation
}
```

### Phase 3: Verify Visualization Calls
```swift  
// In VisualizationEngine.updateRobotPosition()
print("🔍 DEBUG: VisualizationEngine updating robot node at: \(position)")
print("🔍 DEBUG: Robot node exists: \(robotNode != nil)")
```

### Phase 4: Check SceneKit Integration
```swift
// In SceneKitView.updateNSView()
print("🔍 DEBUG: SceneKitView updating with scene: \(visualizationEngine.scene)")
```

## Common Mac App Visualization Bugs

### 1. **Data Reception Issues**
- **TCP server not listening properly**
- **Message decoding failures** 
- **Thread safety problems with @Published updates**
- **Memory leaks causing performance issues**

### 2. **State Management Bugs**
- **@Published properties not triggering UI updates**
- **Circular references preventing updates**
- **Race conditions between network and UI threads**
- **AppState not properly connected to VisualizationEngine**

### 3. **SceneKit Rendering Problems**
- **Scene nodes not being added to root node**
- **Camera positioning issues (looking at wrong area)**
- **Geometry creation failures (invalid mesh data)**
- **Material/lighting problems making objects invisible**
- **Coordinate system mismatches**

### 4. **SwiftUI Integration Issues**
- **NSViewRepresentable not updating properly**
- **EnvironmentObject dependencies broken**
- **ObservableObject publishers not connected**

## Message Types from iPhone

The Mac app should handle these message types:

### Robot Position (30 FPS)
```json
{
  "type": "robotPosition",
  "data": {
    "position": [x, y, z],
    "rotation": [qx, qy, qz, qw],
    "timestamp": "2025-08-28T..."
  }
}
```

### Mesh Update (2 FPS)  
```json
{
  "type": "meshUpdate", 
  "data": {
    "anchorId": "uuid",
    "vertices": [x1,y1,z1, x2,y2,z2, ...],
    "faces": [0,1,2, 1,2,3, ...],
    "transform": [4x4 matrix as 16 floats],
    "timestamp": "..."
  }
}
```

### Person Detection (10 FPS)
```json
{
  "type": "personDetection",
  "data": {
    "id": "uuid", 
    "position": [x, y, z],
    "confidence": 0.95,
    "stability": "corroborated",
    "timestamp": "..."
  }
}
```

## Expected Visual Results

### Robot Visualization
- **iPhone device**: Dark gray rounded rectangle representing phone
- **Blue camera indicator**: Small sphere on top of device  
- **Movement trail**: Cyan line showing robot's path
- **Real-time updates**: Smooth 30 FPS position updates

### Person Detection Visualization  
- **Colored spheres**: Yellow (single-frame), Orange (multi-frame), Red (corroborated)
- **Confidence labels**: Text showing "Person 95%" above spheres
- **Interactive**: Click to focus camera on detection
- **Real-time updates**: Appear/update as people are detected

### Mesh Visualization
- **Wireframe geometry**: White line-based 3D mesh from LiDAR
- **Room structure**: Shows walls, floors, furniture as 3D wireframes
- **Semi-transparent**: See-through mesh with alpha blending
- **Progressive building**: Mesh expands as iPhone scans new areas

## Debug Priority Order

1. **Start with NetworkReceiver** - Verify messages are being received and decoded
2. **Check MacAppState** - Ensure @Published properties are updating
3. **Debug VisualizationEngine** - Verify SceneKit nodes are being created
4. **Test SceneKit rendering** - Check camera position, lighting, node hierarchy
5. **Verify SwiftUI integration** - Ensure UI updates trigger scene updates

## Success Criteria

✅ **TCP connection established** (already working)  
✅ **Messages received and decoded** (check logs)  
✅ **MacAppState properties updated** (check @Published vars)  
✅ **VisualizationEngine creates SceneKit nodes**  
✅ **3D scene displays robot, detections, and mesh**  
✅ **Real-time updates work smoothly**  
✅ **Camera controls and interactions work**

## Files to Focus On

1. **NetworkReceiver.swift** - Message handling and state updates
2. **RobotMapViewerApp.swift** - App state object connections  
3. **ContentView.swift** - EnvironmentObject bindings
4. **VisualizationEngine.swift** - SceneKit node creation and updates
5. **SceneKitView.swift** - SwiftUI/SceneKit bridge

The goal is to identify where the data flow breaks between receiving network messages and displaying 3D visualizations. Most likely issues are in state management (@Published not updating UI) or SceneKit node creation failures.