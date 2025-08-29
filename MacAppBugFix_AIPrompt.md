# AI Prompt: Fix Mac Companion App Bugs and Complete Implementation

## Context
You are helping to debug and complete a macOS companion app that receives real-time 3D mapping data from an iPhone robot head. The iPhone app streams robot position, LiDAR mesh data, and person detections over TCP to visualize on Mac.

## Current Mac App Structure
```
Mac Companion App/RobotMapViewer/
├── RobotMapViewerApp.swift          # Main app entry point with window setup
├── ContentView.swift                # Split-view UI with 3D scene and sidebar
├── NetworkReceiver.swift            # TCP server that receives iPhone data
├── VisualizationEngine.swift        # SceneKit-based 3D renderer
├── SceneKitView.swift               # SwiftUI wrapper for SceneKit view
└── NetworkProtocol.swift            # Shared message protocols with iPhone
```

## What Each File Does

### 1. **RobotMapViewerApp.swift**
- **Purpose**: Main SwiftUI App entry point
- **Responsibilities**: 
  - Creates main window with minimum size (1200x800)
  - Sets up app-wide state objects (@StateObject)
  - Provides menu commands for Start/Stop listening
- **State Objects**: MacAppState, NetworkReceiver, VisualizationEngine

### 2. **ContentView.swift** 
- **Purpose**: Main UI layout and user interface
- **Responsibilities**:
  - Split-view layout: 3D scene (left) + control sidebar (right)
  - Connection status display with start/stop buttons
  - View toggle controls (robot path, detections, mesh)
  - Robot status panel with position/session info
  - Person detections list with tap-to-focus
- **Integration**: Connects NetworkReceiver to VisualizationEngine

### 3. **NetworkReceiver.swift**
- **Purpose**: TCP server that receives data from iPhone
- **Responsibilities**:
  - Creates NWListener on port 12345
  - Handles incoming iPhone connections
  - Decodes JSON messages from iPhone
  - Updates MacAppState with received data
  - Passes data to VisualizationEngine for rendering
- **Message Types**: Robot position, mesh updates, person detections, session events, heartbeats

### 4. **VisualizationEngine.swift**
- **Purpose**: 3D scene management and rendering with SceneKit
- **Responsibilities**:
  - Creates and manages SCNScene with lighting/camera
  - Renders robot position as iPhone-like device with path trail
  - Displays person detections as colored spheres with confidence labels
  - Shows 3D mesh data from LiDAR as wireframe geometry
  - Provides camera controls and focus-on-detection features
  - Manages coordinate system visualization

### 5. **SceneKitView.swift**
- **Purpose**: SwiftUI bridge to SceneKit
- **Responsibilities**:
  - Wraps SCNView in NSViewRepresentable for SwiftUI
  - Enables camera controls and anti-aliasing
  - Displays statistics overlay
  - Updates scene when VisualizationEngine changes

### 6. **NetworkProtocol.swift**
- **Purpose**: Shared data structures between iPhone and Mac
- **Responsibilities**:
  - Defines NetworkMessage enum with all message types
  - Message structures: RobotPositionMessage, MeshUpdateMessage, PersonDetectionMessage, etc.
  - Codable implementations for JSON serialization
  - Must match exactly with iPhone app protocol

## Common Bugs to Fix

### 1. **Build/Compilation Issues**
- Missing imports (SwiftUI, SceneKit, Network, Foundation)
- macOS deployment target compatibility
- Framework linking issues
- Swift concurrency warnings

### 2. **Network Connection Problems**
- NWListener not starting properly on port 12345
- Connection state handling edge cases
- Message decoding failures
- Memory leaks from unclosed connections

### 3. **3D Visualization Bugs**
- SceneKit geometry creation errors
- Mesh vertex/face data corruption
- Camera positioning and controls not working
- Scene lighting or material issues
- Performance problems with large datasets

### 4. **UI State Management**
- @Published properties not updating UI
- State synchronization between NetworkReceiver and VisualizationEngine
- Memory retention cycles between objects
- Thread safety issues with UI updates

### 5. **Data Processing Errors**
- Mesh vertex array parsing (flat array to 3D positions)
- Transform matrix conversion (simd_float4x4 construction)
- Person detection coordinate transformations
- Timestamp and session ID handling

## Expected App Behavior

### On Launch:
1. Mac app shows "Not listening" status
2. 3D scene displays empty with coordinate axes
3. Sidebar shows zero detections/status

### When "Start Listening":
1. TCP server starts on port 12345
2. Status changes to "Listening on port 12345"
3. Waits for iPhone connection

### When iPhone Connects:
1. Status shows "Connected to iPhone" 
2. Receives session start message
3. Real-time data streaming begins

### During Operation:
1. **Robot visualization**: iPhone device moves in 3D space with trail
2. **Person detections**: Colored spheres appear with confidence labels
3. **Mesh data**: Wireframe 3D geometry from LiDAR appears
4. **UI updates**: Sidebar shows live statistics and detection list
5. **Interactions**: Click detection → camera focuses on it

## Debug Approach

1. **Start with compilation**: Fix all build errors and warnings
2. **Test networking**: Ensure TCP server starts and accepts connections
3. **Verify data flow**: Add logging to confirm message receipt and parsing
4. **Check 3D rendering**: Ensure SceneKit geometry appears correctly
5. **Test UI responsiveness**: Confirm real-time updates work smoothly
6. **Performance optimization**: Address any lag or memory issues

## Success Criteria

✅ **Mac app builds without errors**  
✅ **TCP server starts and listens on port 12345**  
✅ **Successfully connects to iPhone app**  
✅ **Receives and decodes all message types**  
✅ **Displays robot position and path in 3D**  
✅ **Shows person detections as interactive elements**  
✅ **Renders LiDAR mesh data as wireframes**  
✅ **UI updates in real-time with live data**  
✅ **Camera controls and focus features work**

## Additional Context

The iPhone app is working correctly and successfully builds. It streams:
- Robot position at 30 FPS (smooth movement)
- Mesh updates at 2 FPS (compressed LiDAR data)  
- Person detections at 10 FPS (when people detected)
- Session management and heartbeat messages

Focus on making the Mac app a robust receiver and visualizer for this data stream. The goal is real-time monitoring of a robot head (iPhone) exploring and mapping an environment while detecting people.