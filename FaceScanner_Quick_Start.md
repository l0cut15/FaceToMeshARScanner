# FaceScanner - Quick Start Guide

## 🚀 Get Started in 15 Minutes

This guide gets you from zero to scanning faces in the shortest time possible.

---

## Prerequisites

### Required
- ✅ **macOS** with Xcode 15+ installed
- ✅ **iPhone XR or newer** with TrueDepth camera
- ✅ **Apple Developer Account** (free tier is fine for testing)
- ✅ **Claude Code** installed and configured
- ✅ **USB cable** to connect iPhone to Mac

### Recommended
- 📱 iPhone 12 or newer (better performance)
- 💡 Good lighting environment
- 🎯 Familiarity with Swift/Xcode (helpful but not required)

---

## Step-by-Step Setup

### STEP 1: Create Xcode Project (5 minutes)

1. **Open Xcode**

2. **Create New Project**
   - File → New → Project
   - Choose: iOS → App
   - Click "Next"

3. **Configure Project**
   ```
   Product Name: FaceScanner
   Team: [Your Apple ID]
   Organization Identifier: com.yourname.facescanner
   Interface: SwiftUI
   Language: Swift
   Storage: None
   Include Tests: ✓
   ```
   - Click "Next"
   - Choose save location (e.g., `~/Developer/FaceScanner`)
   - Click "Create"

4. **Configure Project Settings**
   
   Select project in navigator → Target "FaceScanner":
   
   **General Tab:**
   - Deployment Target: **iOS 16.0**
   - iPhone only (uncheck iPad)
   - Requires Full Screen: ✓
   
   **Signing & Capabilities Tab:**
   - Enable "Automatically manage signing"
   - Click **"+ Capability"** → Add **"Face ID"**
   
   **Info Tab:**
   - Click **"+"** to add new entries:
   
   ```xml
   Key: Privacy - Camera Usage Description
   Value: FaceScanner needs camera access to capture 3D scans of your face.
   
   Key: Privacy - Face ID Usage Description  
   Value: Face tracking technology is used to create accurate 3D models.
   ```

5. **Verify Setup**
   - Press **Cmd+B** to build
   - Should succeed with no errors
   - Note your project path (you'll need it):
     ```bash
     # In Terminal:
     cd ~/Developer/FaceScanner
     pwd
     # Copy this path!
     ```

---

### STEP 2: Download Design Documents (1 minute)

The design spec and implementation plan are ready to use with Claude Code.

**Save these files:**
- `FaceScanner_Design_Spec.md` (design specification)
- `FaceScanner_Claude_Code_Plan.md` (implementation plan)

**Put them in your project directory:**
```bash
cd ~/Developer/FaceScanner
# Save the .md files here
```

---

### STEP 3: Start Claude Code Session (2 minutes)

1. **Open Terminal**

2. **Navigate to project:**
   ```bash
   cd ~/Developer/FaceScanner
   ```

3. **Start Claude Code:**
   ```bash
   claude-code
   ```

4. **First prompt to Claude Code:**
   ```
   I'm building an iOS face scanning app following the design spec in 
   FaceScanner_Design_Spec.md and implementation plan in 
   FaceScanner_Claude_Code_Plan.md
   
   This is a SwiftUI app using ARKit for face scanning and export to STL/OBJ files.
   
   Let's start with Phase 2, Session 1: Create the data models and utilities.
   
   Project structure:
   - FaceScanner/ (root)
     - FaceScanner/ (contains Swift files)
     - FaceScanner.xcodeproj
   
   Create these files in FaceScanner/ directory:
   1. Models/FaceScan.swift
   2. Models/ScanSettings.swift  
   3. Utilities/Constants.swift
   4. Utilities/Extensions.swift
   
   Start with FaceScan.swift - a Codable struct that stores:
   - id (UUID)
   - date (Date)
   - name (String)
   - meshFileURL (URL) - reference to saved .stl file
   - thumbnailData (Data?) - optional preview image
   - vertexCount (Int)
   - settings (ScanSettings)
   ```

---

### STEP 4: Iterative Development (Main Work)

**Workflow loop:**

```
┌─────────────────────────────────────┐
│ 1. Claude Code creates Swift file   │
│    (in Terminal)                     │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 2. Add file to Xcode project        │
│    (Right-click folder → Add Files) │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 3. Build in Xcode (Cmd+B)           │
│    Check for errors                 │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ 4. If errors → paste to Claude Code │
│    If success → continue to next    │
└────────────┬────────────────────────┘
             │
             ▼
         [Repeat]
```

**Follow the phases in the implementation plan:**
- Phase 2: Core implementation (Services)
- Phase 3: User interface (Views)
- Phase 4: Testing and polish

**Pro tips:**
- Build frequently in Xcode (Cmd+B)
- Test on device early and often
- Keep both Terminal (Claude Code) and Xcode visible
- Save your Claude Code chat history

---

### STEP 5: Test on Device (1 minute)

1. **Connect iPhone** via USB

2. **In Xcode:**
   - Select your iPhone from device menu (top-left)
   - Press **Cmd+R** to build and run
   - First time: Trust computer on iPhone

3. **Grant permissions** when app launches:
   - Camera access: Allow
   - Face tracking: Allow

4. **Test basic flow:**
   - Tap "New Scan"
   - Point camera at face
   - Watch quality indicator
   - Capture when green
   - View 3D model
   - Export STL

---

## Critical Path to First Working Scan

**Minimum files needed for basic functionality:**

```
FaceScanner/
├── FaceScannerApp.swift         ← Entry point
├── ContentView.swift            ← Main navigation
├── Models/
│   └── FaceScan.swift           ← Data model
├── Services/
│   ├── ARFaceScanner.swift      ← ARKit integration (CRITICAL)
│   └── FileExporter.swift       ← STL export (CRITICAL)
└── Views/
    ├── ScanView.swift           ← Scanning UI (CRITICAL)
    └── PreviewView.swift        ← 3D viewer
```

**Focus on these 3 critical files first:**
1. `ARFaceScanner.swift` - Captures face data
2. `ScanView.swift` - UI for scanning
3. `FileExporter.swift` - Exports STL

Everything else is enhancement!

---

## Validation Checklist

### ✅ Project Setup Complete
- [ ] Xcode project created and builds
- [ ] Camera/Face ID permissions in Info.plist
- [ ] Face ID capability added
- [ ] Can run on connected iPhone

### ✅ Phase 2 Complete (Services)
- [ ] ARFaceScanner compiles
- [ ] Can start ARSession without crash
- [ ] FileExporter creates valid STL file
- [ ] StorageManager saves/loads data

### ✅ Phase 3 Complete (UI)
- [ ] App launches on device
- [ ] Can navigate to ScanView
- [ ] Camera feed displays
- [ ] Face mesh overlay shows
- [ ] Can return to home screen

### ✅ MVP Complete
- [ ] Can scan face from start to finish
- [ ] STL file exports to Files app
- [ ] STL opens in Cura/PrusaSlicer
- [ ] Mesh looks recognizable
- [ ] No crashes during workflow

---

## Common First-Run Issues

### ❌ "Face tracking not supported"
**Cause:** Running in Simulator  
**Fix:** Must test on physical iPhone with TrueDepth camera

### ❌ "Camera permission denied"
**Cause:** Info.plist missing camera description  
**Fix:** Add NSCameraUsageDescription key (see Step 1)

### ❌ File won't import to Xcode
**Cause:** File created outside project directory  
**Fix:** Ensure Claude Code creates files in correct path

### ❌ Build errors: "No such module 'ARKit'"
**Cause:** Deployment target too low  
**Fix:** Set to iOS 16.0+ in project settings

### ❌ STL file won't open
**Cause:** Invalid binary format  
**Fix:** Verify STL exporter uses correct byte order and structure

---

## Sample Prompts for Claude Code

### Starting a new service
```
Create Services/ARFaceScanner.swift

Requirements:
- ObservableObject class for SwiftUI
- Manages ARSession with ARFaceTrackingConfiguration  
- Captures face geometry frames
- Published properties for scan state
- Quality detection (distance, lighting)

Follow iOS best practices. Include error handling and comments.
```

### Fixing build errors
```
I'm getting these build errors:

[paste errors from Xcode]

Please fix these in the relevant files.
```

### Creating a view
```
Create Views/ScanView.swift

A SwiftUI view that:
- Shows AR camera feed using ARSCNView
- Displays face mesh overlay
- Shows quality indicator (red/yellow/green circle)
- Has capture button (bottom center)
- Integrates with ARFaceScanner service

Use UIViewRepresentable to wrap SceneKit view.
```

### Implementing export
```
Create the STL export function in Services/FileExporter.swift

Input: MDLMesh from ModelIO
Output: URL to binary STL file

Binary STL format:
- 80 byte header
- 4 byte uint32 triangle count
- For each triangle (50 bytes):
  - 12 bytes: normal vector (3 floats)
  - 36 bytes: 3 vertices (9 floats)  
  - 2 bytes: attribute count

Use little-endian byte order.
```

---

## Resource Links

### Apple Documentation
- [ARKit Face Tracking](https://developer.apple.com/documentation/arkit/arfacetrackingconfiguration)
- [ModelIO Framework](https://developer.apple.com/documentation/modelio)
- [SceneKit](https://developer.apple.com/documentation/scenekit)

### STL Format
- [STL Format Specification](http://www.fabbers.com/tech/STL_Format)
- [Binary STL Reference](https://en.wikipedia.org/wiki/STL_(file_format))

### Testing
- [PrusaSlicer](https://www.prusa3d.com/page/prusaslicer_424/) (free STL viewer/slicer)
- [Blender](https://www.blender.org) (free 3D editor for OBJ)
- [MeshLab](https://www.meshlab.net) (free mesh analysis)

---

## What's Next?

### After MVP Works
1. **Test with different faces** (glasses, beards, etc.)
2. **Validate STL files** in your slicer software
3. **3D print** a test piece!
4. **Iterate on quality:**
   - Increase frame count
   - Add mesh smoothing
   - Improve hole filling

### Future Enhancements
- Color texture capture
- Multi-angle scanning
- Advanced editing tools
- Cloud backup
- AR preview
- Direct printer integration

---

## Need Help?

### During Development
1. **Build errors:** Copy to Claude Code, ask for fix
2. **Runtime crashes:** Check Xcode console, share stack trace
3. **Poor results:** Adjust quality thresholds in ARFaceScanner
4. **Export issues:** Validate STL format with hex editor

### Testing Resources
- **STL validation:** Import to Cura, check for errors
- **Mesh analysis:** Open in MeshLab, check manifold status
- **Visual inspection:** Rotate in preview, look for holes

---

## Time Estimates

**Conservative timeline:**
- Day 1: Project setup + data models (2-3 hours)
- Days 2-3: Core services (ARKit, export) (6-8 hours)
- Days 4-5: UI implementation (6-8 hours)  
- Days 6-7: Testing and debugging (4-6 hours)
- **Total: ~20-25 hours over 1 week**

**Aggressive timeline:** 
- Weekend hackathon: 12-16 hours straight
- Focus on critical path only
- Skip advanced features

---

## Success Story

**You'll know you've succeeded when:**

1. You point your iPhone at your face
2. The app shows a green quality indicator
3. You tap "Capture"
4. A 3D mesh appears on screen
5. You export to STL
6. The file opens in your slicer
7. You see a recognizable 3D model of your face
8. You 3D print it and it looks like you! 🎉

**Let's build this!**

---

**Document Version:** 1.0  
**Difficulty:** Intermediate  
**Time to MVP:** 1 week  
**Fun Factor:** 10/10 🚀
