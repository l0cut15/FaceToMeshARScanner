# FaceScanner - Claude Code Implementation Plan

## Overview
This document provides a step-by-step plan for building the FaceScanner iOS app using Claude Code and Xcode integration.

---

## Phase 1: Project Setup (Day 1)

### Step 1: Create Xcode Project (Manual)
**You must do this step manually in Xcode:**

1. Open Xcode
2. Create new project: File → New → Project
3. Choose "iOS" → "App"
4. Configuration:
   - **Product Name:** FaceScanner
   - **Team:** Your Apple Developer account
   - **Organization Identifier:** com.yourname.facescanner
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None (we'll handle manually)
   - **Include Tests:** Yes
5. Save to desired location
6. **IMPORTANT:** Note the full project path (you'll need it for Claude Code)

### Step 2: Configure Project Settings (Manual)
In Xcode:

1. **Select project** in navigator → Target "FaceScanner"
2. **General tab:**
   - Deployment Target: iOS 16.0
   - Supported Destinations: iPhone only (uncheck iPad)
   - Requires Full Screen: Yes

3. **Signing & Capabilities tab:**
   - Enable "Automatically manage signing"
   - Add capability: "Face ID" (this enables ARKit face tracking)

4. **Info tab:**
   - Add required permissions (see below)

5. **Build Settings:**
   - Swift Language Version: Swift 5
   - Enable bitcode: No (required for ARKit)

### Step 3: Add Info.plist Entries (Manual)
In Xcode, open `Info.plist` and add:

```xml
<key>NSCameraUsageDescription</key>
<string>FaceScanner needs camera access to capture 3D scans of your face.</string>

<key>NSFaceIDUsageDescription</key>
<string>Face tracking technology is used to create accurate 3D models.</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>armv7</string>
    <string>front-facing-camera</string>
</array>

<key>UIRequiresPersistentWiFi</key>
<false/>

<key>UILaunchScreen</key>
<dict>
    <key>UIImageName</key>
    <string></string>
    <key>UIColorName</key>
    <string></string>
</dict>
```

### Step 4: Share Project Path with Claude Code
Once the Xcode project is created:

```bash
# Get your project path
cd /path/to/your/FaceScanner
pwd
# Example: /Users/brett/Developer/FaceScanner

# This is what you'll tell Claude Code
```

---

## Phase 2: Core Implementation with Claude Code (Days 2-5)

### Session 1: Project Structure and Models

**Prompt for Claude Code:**
```
I have an Xcode project at /Users/brett/Developer/FaceScanner

Please create the following Swift files in the project directory:

1. Models/FaceScan.swift - Data model for storing scan information
2. Models/ScanSettings.swift - Configuration settings
3. Utilities/Constants.swift - App-wide constants
4. Utilities/Extensions.swift - Helper extensions for SIMD, SCNVector3, etc.

Follow the design spec at /path/to/FaceScanner_Design_Spec.md

Start with the data models and utilities. Make sure they compile without errors.
```

**Expected outputs:**
- `FaceScan.swift` - Codable struct with id, date, filename, mesh data reference
- `ScanSettings.swift` - User preferences (quality level, export format, etc.)
- `Constants.swift` - Color schemes, dimensions, file paths
- `Extensions.swift` - SIMD to SCNVector3, MDLMesh helpers

### Session 2: ARKit Face Scanner Service

**Prompt for Claude Code:**
```
Create the ARFaceScanner service:

File: Services/ARFaceScanner.swift

Requirements:
- ObservableObject for SwiftUI integration
- Manages ARSession with ARFaceTrackingConfiguration
- Captures ARFaceGeometry frames
- Aggregates multiple frames for better quality
- Provides quality metrics (distance, lighting, stability)
- Publishes scan state updates

Include comprehensive error handling and comments.
```

**Key implementation details Claude Code should include:**
```swift
import ARKit
import Combine

class ARFaceScanner: NSObject, ObservableObject {
    // Session management
    private let session = ARSession()
    private var capturedFrames: [ARFaceGeometry] = []
    
    // Published properties for UI
    @Published var isScanning = false
    @Published var scanQuality: ScanQuality = .poor
    @Published var faceDetected = false
    @Published var instructionText = "Position face in frame"
    
    // Quality thresholds
    private let minDistance: Float = 0.3  // 30cm
    private let maxDistance: Float = 0.5  // 50cm
    private let minFramesToCapture = 60
    private let maxFramesToCapture = 120
}
```

### Session 3: Mesh Processing Service

**Prompt for Claude Code:**
```
Create the MeshProcessor service:

File: Services/MeshProcessor.swift

Requirements:
- Convert ARFaceGeometry to MDLMesh
- Aggregate multiple face geometries into one mesh
- Smoothing algorithms (Laplacian smoothing)
- Mesh decimation (reduce polygon count)
- Hole filling
- Normal generation
- Scaling operations

Use ModelIO framework. Add detailed comments explaining algorithms.
```

### Session 4: File Export Service

**Prompt for Claude Code:**
```
Create the FileExporter service:

File: Services/FileExporter.swift

Requirements:
- Export MDLMesh to STL (binary format)
- Export MDLMesh to OBJ (ASCII format)
- Generate preview thumbnail images
- Handle file naming and storage
- Return URLs for sharing

Include proper error handling and file I/O safety.
```

**STL export format Claude Code should implement:**
```swift
func exportAsSTL(_ mesh: MDLMesh, filename: String) -> URL? {
    // Binary STL format:
    // - 80 byte header
    // - 4 byte triangle count (uint32)
    // - For each triangle: 50 bytes
    //   - 12 bytes: normal (3 x float32)
    //   - 36 bytes: vertices (9 x float32)
    //   - 2 bytes: attribute (uint16)
}
```

### Session 5: Storage Manager

**Prompt for Claude Code:**
```
Create the StorageManager service:

File: Services/StorageManager.swift

Requirements:
- Save/load FaceScan objects
- Manage mesh file storage (Documents directory)
- Generate thumbnails
- List all saved scans
- Delete scans
- Export scan data

Use FileManager and UserDefaults for metadata.
```

---

## Phase 3: User Interface (Days 6-8)

### Session 6: Main App Structure

**Prompt for Claude Code:**
```
Update the main app files:

1. FaceScannerApp.swift - App entry point with proper initialization
2. ContentView.swift - Tab navigation between Home, Scan, History

Use SwiftUI best practices. Include proper state management.
```

### Session 7: Scan View (Most Complex)

**Prompt for Claude Code:**
```
Create the scanning interface:

File: Views/ScanView.swift

Requirements:
- ARSCNView wrapped in UIViewRepresentable
- Real-time face mesh overlay
- Quality indicator (colored circle: red/yellow/green)
- Instruction text based on scan state
- Capture button (enabled only when quality is good)
- Progress indicator during capture
- Transition to preview on completion

Integrate with ARFaceScanner service.
```

**This is the most complex view - Claude Code should scaffold:**
```swift
struct ScanView: View {
    @StateObject private var scanner = ARFaceScanner()
    @State private var showingPreview = false
    @State private var capturedMesh: MDLMesh?
    
    var body: some View {
        ZStack {
            // AR camera view
            ARViewContainer(scanner: scanner)
                .ignoresSafeArea()
            
            // Overlays
            VStack {
                // Quality indicator
                QualityIndicator(quality: scanner.scanQuality)
                
                // Instructions
                Text(scanner.instructionText)
                    .padding()
                    .background(.ultraThinMaterial)
                
                Spacer()
                
                // Capture button
                CaptureButton(enabled: scanner.canCapture) {
                    scanner.capture { mesh in
                        capturedMesh = mesh
                        showingPreview = true
                    }
                }
            }
        }
    }
}
```

### Session 8: Preview and Edit Views

**Prompt for Claude Code:**
```
Create the preview and editing interfaces:

Files:
1. Views/PreviewView.swift - 3D mesh viewer with rotation/zoom
2. Views/EditView.swift - Editing controls (smoothing, scale, etc.)

Use SCNView for 3D rendering. Include gesture recognizers for interaction.
```

### Session 9: History View

**Prompt for Claude Code:**
```
Create the scan history interface:

File: Views/HistoryView.swift

Requirements:
- Grid layout of saved scans
- Thumbnail images
- Date stamps
- Tap to open in PreviewView
- Swipe to delete
- Share button

Integrate with StorageManager service.
```

---

## Phase 4: Integration and Testing (Days 9-10)

### Session 10: Testing Infrastructure

**Prompt for Claude Code:**
```
Create unit tests:

Files in Tests/:
1. MeshProcessorTests.swift - Test mesh operations
2. FileExporterTests.swift - Test export formats
3. StorageManagerTests.swift - Test file I/O

Use XCTest framework. Include sample mesh data for testing.
```

### Session 11: Bug Fixes and Polish

**Manual Xcode work + Claude Code assistance:**

1. **Build the project in Xcode** - note any errors
2. **Ask Claude Code to fix compilation errors:**
   ```
   I'm getting these build errors:
   [paste error messages]
   
   Please fix these issues in the relevant files.
   ```

3. **Test on device:**
   - Connect iPhone with TrueDepth camera
   - Build and run (Cmd+R)
   - Test scanning workflow
   - Verify export files open in Cura/Blender

---

## Workflow: Claude Code + Xcode Integration

### Recommended Approach

**Terminal 1: Claude Code**
```bash
# Navigate to project
cd /Users/brett/Developer/FaceScanner

# Start Claude Code session
claude-code

# In Claude Code chat:
# "Create Services/ARFaceScanner.swift following the spec..."
```

**Xcode: Keep open in parallel**
- Auto-refresh when Claude Code creates files
- Build frequently to catch errors (Cmd+B)
- Use Xcode for:
  - Project settings
  - Info.plist editing
  - Asset catalog management
  - Storyboard/XIB files (if any)
  - Debugging
  - Device deployment

### File Creation Strategy

**Claude Code creates:**
- All `.swift` source files
- Test files
- Documentation
- Helper scripts

**You manage in Xcode:**
- Project settings
- Info.plist
- Build configurations
- Assets (images, colors)
- Entitlements

### Iteration Loop

```
1. Claude Code creates/updates Swift file
   ↓
2. Xcode auto-detects change
   ↓
3. Build in Xcode (Cmd+B)
   ↓
4. If errors → Copy to Claude Code → Fix
   ↓
5. If success → Test on device
   ↓
6. Repeat for next feature
```

---

## Quick Reference Commands

### Build and Run
```bash
# In Xcode: Cmd+B (build), Cmd+R (run)

# Or via xcodebuild (terminal):
cd /path/to/FaceScanner
xcodebuild -scheme FaceScanner -destination 'platform=iOS,name=Brett's iPhone' build
```

### Add Files to Xcode Project
When Claude Code creates a new file:

1. **Right-click** on the folder in Xcode navigator
2. **"Add Files to FaceScanner..."**
3. **Select the new file** (or drag-drop)
4. **Ensure** "Copy items if needed" is UNCHECKED (file already in project)
5. **Ensure** target "FaceScanner" is checked

### Export Archive for Testing
```bash
# Create .ipa for TestFlight/distribution
xcodebuild -scheme FaceScanner -archivePath ./build/FaceScanner.xcarchive archive
xcodebuild -exportArchive -archivePath ./build/FaceScanner.xcarchive -exportPath ./build -exportOptionsPlist ExportOptions.plist
```

---

## Troubleshooting Guide

### Issue: "No such module 'ARKit'"
**Solution:** 
- Ensure deployment target is iOS 16.0+
- Clean build folder: Cmd+Shift+K
- Restart Xcode

### Issue: "Face tracking not supported"
**Solution:**
- Must test on physical device with TrueDepth camera
- Simulator cannot run ARKit face tracking
- Check device compatibility in code

### Issue: STL file won't open in slicer
**Solution:**
```
Claude Code: "Debug the STL export function. The file should be:
- Binary format
- Little-endian
- Valid triangle normals
- No degenerate triangles"
```

### Issue: App crashes on launch
**Solution:**
- Check Info.plist permissions are set
- Verify Face ID capability is enabled
- Check console logs in Xcode

### Issue: Poor scan quality
**Solution:**
- Improve lighting (even, bright)
- Increase frame capture count
- Add mesh smoothing iterations
- Implement outlier rejection

---

## Code Quality Checklist

Before considering a phase complete:

- [ ] All files compile without errors
- [ ] No force-unwrapping (use `if let` or `guard let`)
- [ ] Proper error handling (no silent failures)
- [ ] Comments explain complex algorithms
- [ ] SwiftLint passes (if you use it)
- [ ] Memory leaks checked with Instruments
- [ ] UI is responsive (60fps during scanning)
- [ ] Exported files validated in external tools

---

## Expected Timeline

| Phase | Duration | Key Deliverable |
|-------|----------|-----------------|
| Setup | 1 day | Xcode project configured |
| Core Services | 4 days | ARKit, mesh processing, export working |
| UI Implementation | 3 days | All views functional |
| Testing & Polish | 2 days | Bug-free, device-tested app |
| **Total** | **10 days** | Shippable app |

With Claude Code, expect to spend:
- **30% time:** Writing prompts and reviewing generated code
- **40% time:** Testing in Xcode and on device
- **20% time:** Debugging and fixing issues
- **10% time:** Documentation and polish

---

## Success Metrics

**Phase 2 Complete when:**
- Can instantiate ARFaceScanner without crashes
- Can export a simple cube mesh to valid STL
- StorageManager can save/load JSON data

**Phase 3 Complete when:**
- App builds and runs on device
- Can navigate between all views
- ScanView shows camera feed

**Phase 4 Complete when:**
- Can complete full scan-to-export workflow
- STL opens in Cura without errors
- OBJ opens in Blender and looks correct
- App doesn't crash during normal usage

---

## Next Steps After MVP

1. **App Store submission** (requires Developer Program membership)
2. **Advanced features:**
   - Texture capture
   - Multiple scan angles
   - Cloud sync
3. **Optimization:**
   - Faster export
   - Better mesh quality
   - Background processing
4. **User feedback iteration**

---

**Document Version:** 1.0  
**Compatible with:** Claude Code, Xcode 15+, iOS 16+
