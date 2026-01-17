# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FaceScanner** is an iOS app for capturing high-quality 3D face scans using ARKit/TrueDepth camera and exporting them for 3D printing.

- **Platform:** iOS 16.0+
- **Language:** Swift
- **Frameworks:** ARKit, SceneKit, ModelIO, SwiftUI
- **Deployment:** iPhone XR or newer with TrueDepth camera required

## Project State

This repository currently contains comprehensive design documentation but **no source code yet**. The project is ready for implementation following the provided specifications.

## Essential Documentation Files

Before implementing any features, review these files in order:

1. **FaceScanner_Design_Spec.md** - Complete technical specification, architecture, and requirements
2. **FaceScanner_Claude_Code_Plan.md** - Phased implementation plan with session-by-session guidance
3. **FaceScanner_Code_Reference.md** - Critical code patterns, complete implementations of core components
4. **FaceScanner_Quick_Start.md** - Setup instructions and workflow guidance
5. **FaceScanner_Troubleshooting.md** - Common issues and debugging strategies

## Xcode Project Setup

The Xcode project must be created manually before code generation:

1. Create iOS App project named "FaceScanner" with SwiftUI interface
2. Set deployment target to **iOS 16.0+**
3. Add **Face ID capability** in Signing & Capabilities
4. Add required Info.plist entries:
   - `NSCameraUsageDescription`: "FaceScanner needs camera access to capture 3D scans of your face."
   - `NSFaceIDUsageDescription`: "Face tracking technology is used to create accurate 3D models."

## Target Directory Structure

```
FaceScanner/
├── FaceScanner/                    # Main app directory
│   ├── FaceScannerApp.swift       # App entry point
│   ├── ContentView.swift          # Main navigation
│   ├── Models/
│   │   ├── FaceScan.swift         # Scan data model
│   │   └── ScanSettings.swift     # Configuration settings
│   ├── Services/
│   │   ├── ARFaceScanner.swift    # ARKit integration (CRITICAL)
│   │   ├── MeshProcessor.swift    # Mesh optimization
│   │   ├── FileExporter.swift     # STL/OBJ export (CRITICAL)
│   │   └── StorageManager.swift   # Local persistence
│   ├── Views/
│   │   ├── ScanView.swift         # AR scanning interface (CRITICAL)
│   │   ├── PreviewView.swift      # 3D model viewer
│   │   ├── EditView.swift         # Editing tools
│   │   └── HistoryView.swift      # Saved scans list
│   ├── Utilities/
│   │   ├── Constants.swift        # App constants
│   │   └── Extensions.swift       # Helper extensions
│   └── Resources/
│       ├── Info.plist
│       └── Assets.xcassets
└── FaceScanner.xcodeproj
```

## Critical Implementation Files

The three most critical files that must work together:

1. **Services/ARFaceScanner.swift** - Captures face geometry from ARKit
2. **Views/ScanView.swift** - UI that displays AR camera and controls scanning
3. **Services/FileExporter.swift** - Exports mesh to STL binary format

These must be implemented first for a functional MVP.

## Development Workflow

### File Creation Pattern

1. **Claude Code creates** `.swift` files in correct directory structure
2. **User manually adds** files to Xcode project via "Add Files to FaceScanner..."
3. **User builds** in Xcode (Cmd+B) to verify compilation
4. **User reports** any errors back to Claude Code for fixes
5. **User tests** on physical device (Simulator cannot run ARKit face tracking)

### Build Commands

```bash
# Build from command line (optional)
cd /path/to/FaceScanner
xcodebuild -scheme FaceScanner -destination 'platform=iOS,name=Your iPhone' build

# Clean build
xcodebuild -scheme FaceScanner clean build
```

**Primary development:** Use Xcode IDE for building, debugging, and device deployment.

## Key Implementation Requirements

### ARKit Face Scanning

- Use `ARFaceTrackingConfiguration` with `maximumNumberOfTrackedFaces = 1`
- Capture 60-120 frames over 3-5 seconds for quality averaging
- Quality metrics: distance (30-50cm optimal), lighting (>500 lux), tracking state
- Always check `ARFaceTrackingConfiguration.isSupported` before initializing

### Binary STL Export Format

Must follow exact specification:
- 80 byte header (ASCII, app name/version)
- 4 bytes: triangle count (uint32, little-endian)
- For each triangle (50 bytes):
  - 12 bytes: normal vector (3x float32, little-endian)
  - 36 bytes: 3 vertices (9x float32, little-endian)
  - 2 bytes: attribute count (uint16, always 0)

### Critical Patterns

**Thread safety for UI updates:**
```swift
DispatchQueue.main.async {
    self.isScanning = false
}
```

**Memory management for capture callbacks:**
```swift
scanner.onComplete = { [weak self] in
    self?.processMesh()
}
```

**Type conversions between ARKit and SceneKit:**
```swift
extension SIMD3 where Scalar == Float {
    var scnVector: SCNVector3 {
        SCNVector3(x, y, z)
    }
}
```

## Testing Requirements

- **Must test on physical device** - Simulator does not support face tracking
- Validate exported STL files open correctly in PrusaSlicer, Cura, or MeshLab
- Check memory usage during repeated scanning sessions
- Verify permissions are requested on first launch

## Common Issues to Avoid

1. **Force unwrapping** - Always use guard/if-let for Metal device, mesh buffers
2. **Missing nil checks** - Validate mesh structure before export
3. **Wrong byte order** - STL export must be little-endian
4. **Main thread blocking** - Move mesh aggregation to background queue
5. **Index bounds** - When iterating triangles, validate `i+2 < indexCount`

## Reference Implementation Locations

Complete, production-ready implementations are provided in **FaceScanner_Code_Reference.md** for:

- ARFaceScanner class with session management and quality assessment
- Binary STL export with correct format
- SwiftUI AR camera view integration with UIViewRepresentable
- Data models (FaceScan, ScanSettings)
- Essential extensions (SIMD3, SCNVector3, Date formatting)

**Use these as templates** when implementing features - they follow iOS best practices and handle edge cases.

## Implementation Phases

Follow **FaceScanner_Claude_Code_Plan.md** for session-by-session implementation:

- **Phase 1:** Xcode project setup (manual)
- **Phase 2:** Core services (ARKit, mesh processing, export, storage)
- **Phase 3:** User interface (scan view, preview, editing, history)
- **Phase 4:** Testing and polish

## Validation Criteria

A successful implementation must:

1. Build without errors on iOS 16.0+
2. Launch on physical iPhone with TrueDepth camera
3. Request and handle camera/face tracking permissions
4. Display AR camera feed with face mesh overlay
5. Capture face geometry and export valid STL file
6. Exported STL opens in 3D printing slicers without errors
7. No crashes during scan-to-export workflow

## Performance Targets

- AR frame rate: 60fps during scanning
- STL export time: <3 seconds
- Memory usage: <200MB during active scanning
- Mesh quality: 5,000-15,000 vertices (configurable)
- App size: <25MB

## When Issues Occur

1. **Build errors** - Consult **FaceScanner_Troubleshooting.md** section "Build & Compilation Issues"
2. **Runtime crashes** - Check "Runtime Issues" section with device console output
3. **STL validation failures** - See "Exported STL won't open in slicer" diagnostics
4. **Poor scan quality** - Review "Quality Issues" section for optimization strategies

## Important Constraints

- **No Simulator support** - ARKit face tracking requires physical TrueDepth camera
- **iOS 16.0 minimum** - Required for SwiftUI + ARKit features used
- **iPhone only** - iPad support not in scope (face scanning use case)
- **Local storage only** - No cloud sync in MVP
- **Binary STL only** - ASCII STL format not required for 3D printing compatibility
