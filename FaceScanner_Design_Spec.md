# FaceScanner iOS App - Design Specification

## Project Overview
**Name:** FaceScanner  
**Platform:** iOS 16.0+  
**Primary Goal:** Capture high-quality 3D face scans using ARKit/TrueDepth camera and export for 3D printing  
**Tech Stack:** Swift, ARKit, SceneKit, Model I/O

---

## 1. Core Features

### 1.1 Face Scanning
- **Real-time face tracking** using ARKit's `ARFaceTrackingConfiguration`
- **Live preview** showing the captured mesh overlay
- **Scan quality indicator** (distance, lighting, movement detection)
- **Guided capture process** with user instructions
- **Multiple scan aggregation** for improved mesh quality

### 1.2 3D Model Export
- **Primary format:** STL (widely compatible with 3D printing slicers)
- **Secondary format:** OBJ (for editing in Blender, MeshLab, etc.)
- **Mesh optimization** before export (hole filling, smoothing)
- **Configurable resolution** (vertex density)

### 1.3 Basic Editing
- **Mesh preview** in 3D with rotation/zoom
- **Scale adjustment** (physical dimensions in mm)
- **Smoothing filter** application
- **Mesh decimation** (reduce polygon count)
- **Mirror correction** (ensure symmetry)

### 1.4 File Management
- **Local storage** of scans
- **Share sheet integration** (export to Files, AirDrop, email)
- **Scan history** with thumbnails
- **Delete/rename** scans

---

## 2. Technical Architecture

### 2.1 App Structure
```
FaceScannerApp/
├── App/
│   ├── FaceScannerApp.swift          # App entry point
│   └── ContentView.swift             # Main navigation
├── Views/
│   ├── ScanView.swift                # AR scanning interface
│   ├── PreviewView.swift             # 3D model viewer
│   ├── EditView.swift                # Basic editing tools
│   └── HistoryView.swift             # Saved scans list
├── Models/
│   ├── FaceScan.swift                # Data model for scans
│   └── ScanSettings.swift            # Configuration
├── Services/
│   ├── ARFaceScanner.swift           # ARKit integration
│   ├── MeshProcessor.swift           # Mesh optimization
│   ├── FileExporter.swift            # STL/OBJ export
│   └── StorageManager.swift          # Local persistence
├── Utilities/
│   ├── Extensions.swift              # Helper extensions
│   └── Constants.swift               # App constants
└── Resources/
    ├── Info.plist
    └── Assets.xcassets
```

### 2.2 Key Components

#### ARFaceScanner
```swift
class ARFaceScanner: NSObject, ObservableObject {
    // Properties
    @Published var isScanning: Bool = false
    @Published var scanQuality: ScanQuality = .poor
    @Published var capturedVertices: [[SIMD3<Float>]] = []
    
    // Methods
    func startScanning()
    func stopScanning()
    func captureMesh() -> ARFaceGeometry?
    func aggregateScans() -> MDLMesh
}
```

#### MeshProcessor
```swift
class MeshProcessor {
    // Mesh operations
    func smoothMesh(_ mesh: MDLMesh, iterations: Int) -> MDLMesh
    func decimateMesh(_ mesh: MDLMesh, targetVertexCount: Int) -> MDLMesh
    func fillHoles(_ mesh: MDLMesh) -> MDLMesh
    func mirrorSymmetry(_ mesh: MDLMesh) -> MDLMesh
    func scaleMesh(_ mesh: MDLMesh, scale: Float) -> MDLMesh
}
```

#### FileExporter
```swift
class FileExporter {
    // Export methods
    func exportAsSTL(_ mesh: MDLMesh, filename: String) -> URL?
    func exportAsOBJ(_ mesh: MDLMesh, filename: String) -> URL?
    func createPreviewImage(_ mesh: MDLMesh) -> UIImage?
}
```

### 2.3 Data Flow
```
1. User initiates scan
   ↓
2. ARFaceScanner captures ARFaceGeometry frames
   ↓
3. Multiple frames aggregated into single mesh
   ↓
4. MeshProcessor optimizes geometry
   ↓
5. User previews and edits in SceneKit view
   ↓
6. FileExporter generates STL/OBJ file
   ↓
7. Share sheet presents file to user
```

---

## 3. User Interface

### 3.1 Screen Layout

**Home Screen**
- "New Scan" button (prominent)
- Grid of previous scans (thumbnail + date)
- Settings icon (top-right)

**Scan Screen**
- Full-screen AR camera view
- Face mesh overlay (semi-transparent)
- Quality indicator (top: red/yellow/green)
- Instructions banner (top-center)
- "Capture" button (bottom-center, disabled until quality is good)
- "Cancel" button (top-left)

**Preview Screen**
- 3D model viewer (interactive - pinch/rotate/pan)
- Bottom toolbar:
  - "Edit" button
  - "Export" button
  - "Delete" button
  - "Back" button

**Edit Screen**
- 3D model viewer (same as preview)
- Side panel with sliders:
  - Smoothing (0-10)
  - Scale (50-200%)
  - Detail level (Low/Medium/High)
- "Apply" / "Reset" buttons

### 3.2 User Flow
```
Launch → Home → [New Scan] → Scan Screen (guided) → 
Preview → [Edit] → Edit Screen → [Export] → Share Sheet
```

---

## 4. ARKit Implementation Details

### 4.1 Face Tracking Configuration
```swift
let configuration = ARFaceTrackingConfiguration()
configuration.maximumNumberOfTrackedFaces = 1
configuration.isLightEstimationEnabled = true

// Optional: Request higher quality (if available)
if ARFaceTrackingConfiguration.supportsWorldTracking {
    configuration.worldAlignment = .gravity
}
```

### 4.2 Mesh Capture Strategy
**Multi-frame averaging:**
- Capture 60-120 frames over 3-5 seconds
- Average vertex positions to reduce noise
- Discard frames with high motion or poor lighting
- Weight frames based on quality metrics

**Quality Metrics:**
- Face detection confidence
- Tracking state (normal vs. limited)
- Distance from camera (optimal: 30-50cm)
- Lighting conditions (from light estimation)
- Motion blur detection

### 4.3 Geometry Processing
**From ARFaceAnchor to exportable mesh:**
1. Extract `geometry.vertices` (SIMD3<Float> array)
2. Extract `geometry.triangleIndices` (Int32 array)
3. Convert to ModelIO MDLMesh
4. Apply transformations
5. Generate normals if needed

---

## 5. Export Format Specifications

### 5.1 STL Format (Binary)
- **Header:** 80 bytes (can include app name/version)
- **Triangle count:** 4 bytes (uint32)
- **Triangles:** 50 bytes each
  - Normal vector: 3 × float32
  - Vertex 1: 3 × float32
  - Vertex 2: 3 × float32
  - Vertex 3: 3 × float32
  - Attribute byte count: uint16 (usually 0)

### 5.2 OBJ Format (ASCII)
```
# Generated by FaceScanner App
mtllib face.mtl
o FaceScan

v x1 y1 z1
v x2 y2 z2
...
vn nx1 ny1 nz1
...
vt u1 v1
...
f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3
...
```

### 5.3 Physical Dimensions
- **Default scale:** Real-world face size (~180-220mm height)
- **User adjustable:** 50-200% of actual size
- **Units:** Always export in millimeters for 3D printing compatibility

---

## 6. Device Requirements

### 6.1 Minimum Requirements
- **iOS:** 16.0+
- **Device:** iPhone with TrueDepth camera
  - iPhone XR or newer
  - iPad Pro 11" (2018+)
  - iPad Pro 12.9" (3rd gen+)
- **Storage:** ~50-100MB for app + scans

### 6.2 Optimal Conditions
- **Lighting:** Even, bright indoor lighting
- **Distance:** 30-40cm from face
- **Environment:** Stationary user, minimal background motion

---

## 7. Privacy & Permissions

### 7.1 Required Permissions (Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan your face and create a 3D model.</string>

<key>NSFaceIDUsageDescription</key>
<string>Face tracking is used to capture accurate 3D geometry of your face.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save exported 3D models to your photo library (optional).</string>
```

### 7.2 Data Handling
- **No cloud storage:** All data stored locally
- **No analytics:** No face data transmitted
- **User control:** Easy deletion of all scans
- **Transparency:** Clear privacy statement in settings

---

## 8. Testing Strategy

### 8.1 Unit Tests
- Mesh processing algorithms (smoothing, decimation)
- File export format validation
- Coordinate system conversions

### 8.2 Integration Tests
- ARKit session management
- File I/O operations
- Share sheet integration

### 8.3 Device Testing
- Test on multiple iPhone models (XR, 11, 12, 13, 14, 15 series)
- Various lighting conditions
- Different face types (glasses, beards, etc.)

---

## 9. Performance Targets

- **AR frame rate:** Maintain 60 fps during scanning
- **Export time:** < 3 seconds for STL export
- **App launch:** < 2 seconds to ready state
- **Memory usage:** < 200MB during active scanning
- **Mesh quality:** 5,000-15,000 vertices (adjustable)

---

## 10. Future Enhancements (V2)

- **Texture capture:** Color/photo texture mapping
- **Body scanning:** Extend beyond face
- **Cloud backup:** Optional iCloud sync
- **Advanced editing:** Sculpting tools, boolean operations
- **Multi-scan fusion:** Combine scans from different angles
- **AR preview:** View model in AR before export
- **Integration:** Direct export to 3D printing services

---

## 11. Dependencies

### 11.1 Apple Frameworks
- ARKit (face tracking)
- SceneKit (3D rendering)
- ModelIO (mesh manipulation)
- RealityKit (optional, for advanced rendering)
- SwiftUI (UI framework)
- Combine (reactive programming)

### 11.2 Third-party (Optional)
- None required for MVP
- Consider: ZipFoundation (for bundled exports)

---

## 12. File Sizes & Storage

**Typical scan sizes:**
- Raw ARKit data: ~1-2MB per scan
- Optimized mesh (5K vertices): ~150KB STL
- Optimized mesh (15K vertices): ~450KB STL
- Preview thumbnail: ~50KB PNG

**Storage strategy:**
- Store processed mesh (not raw frames)
- Keep last 50 scans by default
- Auto-cleanup option in settings

---

## 13. Error Handling

### 13.1 Critical Errors
- TrueDepth camera not available → Show alert, exit gracefully
- ARKit session failure → Retry with user prompt
- Insufficient storage → Prompt cleanup or export

### 13.2 Recoverable Errors
- Poor scan quality → Show instructions, allow retry
- Export failure → Show error, allow retry with different format
- Face not detected → Guide user to reposition

### 13.3 User Guidance
- On-screen instructions during scan
- Quality indicators with actionable feedback
- Help screen with tips for best results

---

## 14. Accessibility

- VoiceOver support for all buttons
- Dynamic Type support for text
- High contrast mode compatibility
- Haptic feedback for important actions
- Clear error messages (not just visual)

---

## Success Criteria

1. ✅ Successfully capture face mesh on compatible devices
2. ✅ Export valid STL files that load in standard slicers (Cura, PrusaSlicer)
3. ✅ Export valid OBJ files that load in Blender/MeshLab
4. ✅ Mesh quality suitable for 3D printing (no holes, manifold)
5. ✅ Intuitive UI that guides users through process
6. ✅ App size < 25MB
7. ✅ No crashes during typical usage
8. ✅ Privacy-preserving (all local processing)

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Target Completion:** 2-3 weeks with Claude Code
