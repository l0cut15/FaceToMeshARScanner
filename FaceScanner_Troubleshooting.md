# FaceScanner - Troubleshooting Guide

## Common Issues and Solutions

---

## 🔴 Critical Issues (App Won't Run)

### Issue: "Face tracking configuration is not supported on this device"

**Symptoms:**
- App crashes immediately on launch
- Console shows ARFaceTrackingConfiguration.isSupported = false

**Cause:** Running on device without TrueDepth camera or in Simulator

**Solutions:**
1. **Check device compatibility:**
   - iPhone XR or newer ✅
   - iPhone X ❌ (not supported)
   - Simulator ❌ (never supported)
   
2. **Add runtime check:**
   ```swift
   func startScanning() {
       guard ARFaceTrackingConfiguration.isSupported else {
           // Show alert to user
           showAlert(title: "Not Supported", 
                    message: "This device doesn't support face scanning")
           return
       }
       // ... proceed with scanning
   }
   ```

---

### Issue: Camera permission denied / Camera access error

**Symptoms:**
- Black screen instead of camera feed
- Alert: "FaceScanner would like to access the camera"
- Console: "This app has crashed because it attempted to access privacy-sensitive data"

**Cause:** Missing Info.plist entries

**Solution:**
1. Open `Info.plist` in Xcode
2. Add these keys (exact spelling matters):
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>FaceScanner needs camera access to capture 3D scans of your face.</string>
   
   <key>NSFaceIDUsageDescription</key>
   <string>Face tracking technology is used to create accurate 3D models.</string>
   ```
3. Delete app from device and reinstall
4. Grant permissions when prompted

---

### Issue: "No such module 'ARKit'" or "No such module 'SceneKit'"

**Symptoms:**
- Build fails with module not found errors
- Red underlines in import statements

**Cause:** Deployment target too low or framework not linked

**Solutions:**
1. **Check deployment target:**
   - Select project → Target → General
   - Minimum Deployments: **iOS 16.0** or higher

2. **Add frameworks (if needed):**
   - Select target → Build Phases → Link Binary With Libraries
   - Click "+" → Add:
     - ARKit.framework
     - SceneKit.framework
     - ModelIO.framework
     - MetalKit.framework

3. **Clean build:**
   - Product → Clean Build Folder (Cmd+Shift+K)
   - Restart Xcode

---

## 🟡 Build & Compilation Issues

### Issue: "Type 'ARFaceScanner' has no member 'session'"

**Symptoms:**
- Cannot access scanner.session property
- Build errors in ARViewContainer

**Cause:** Session property is private

**Solution:**
Make session accessible:
```swift
class ARFaceScanner: NSObject, ObservableObject {
    private(set) var session = ARSession()  // Changed from 'private var'
    // ...
}
```

---

### Issue: "Cannot convert value of type 'SIMD3<Float>' to expected argument type 'SCNVector3'"

**Symptoms:**
- Type mismatch errors
- Cannot assign ARKit vectors to SceneKit

**Solution:**
Add extension (should be in Extensions.swift):
```swift
extension SIMD3 where Scalar == Float {
    var scnVector: SCNVector3 {
        SCNVector3(x, y, z)
    }
}
```

Usage:
```swift
let simdVector: SIMD3<Float> = vertex.position
let scnVector = simdVector.scnVector
```

---

### Issue: "Cannot find 'MTKMeshBufferAllocator' in scope"

**Symptoms:**
- Error when creating MDLMesh
- Missing MetalKit reference

**Solution:**
Add import:
```swift
import MetalKit
import ModelIO
```

---

### Issue: Xcode doesn't see new files created by Claude Code

**Symptoms:**
- Files exist on disk but not in Xcode navigator
- Build doesn't include new files

**Solution:**
1. Right-click on folder in Xcode navigator
2. Select "Add Files to FaceScanner..."
3. Navigate to file location
4. **Uncheck** "Copy items if needed"
5. **Check** target "FaceScanner"
6. Click "Add"

---

## 🟢 Runtime Issues

### Issue: Face not detected / mesh not appearing

**Symptoms:**
- Camera works but no face tracking
- faceDetected stays false

**Diagnostics:**
```swift
// Add to ARSessionDelegate
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    print("📹 Frame updated")
    print("   Anchors: \(frame.anchors.count)")
    print("   Tracking state: \(frame.camera.trackingState)")
}

func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    print("➕ Added anchors: \(anchors.count)")
    for anchor in anchors {
        print("   Type: \(type(of: anchor))")
    }
}
```

**Common Causes:**
1. **Poor lighting** → Move to brighter area
2. **Face too far/close** → Adjust distance (30-50cm)
3. **Face obscured** → Remove glasses, hat, or move hair
4. **Configuration issue** → Verify ARFaceTrackingConfiguration is running

---

### Issue: Scan quality stuck on "poor" (red indicator)

**Symptoms:**
- Indicator always red
- capturedFrames stays empty
- Can never capture

**Debug:**
Add logging to quality assessment:
```swift
private func assessScanQuality(_ faceAnchor: ARFaceAnchor, 
                               frame: ARFrame) -> ScanQuality {
    print("🎯 Quality Check:")
    
    let distance = calculateDistance(faceAnchor)
    print("   Distance: \(distance)m (target: 0.3-0.5)")
    
    print("   Tracking: \(frame.camera.trackingState)")
    
    if let light = frame.lightEstimate {
        print("   Light: \(light.ambientIntensity)")
    }
    
    // ... rest of function
}
```

**Solutions:**
- **Too close:** Back up to 30-40cm
- **Too far:** Move closer
- **Poor tracking:** Keep face steady, improve lighting
- **Bad lighting:** Need 500+ lux intensity

---

### Issue: App crashes when exporting STL

**Symptoms:**
- Export button causes crash
- Console: "EXC_BAD_ACCESS" or "Fatal error: Index out of range"

**Common Causes:**

1. **Nil mesh:**
   ```swift
   // Add guards
   guard let mesh = capturedMesh else {
       print("❌ No mesh to export")
       return
   }
   ```

2. **Invalid mesh structure:**
   ```swift
   guard let vertexBuffer = mesh.vertexBuffers.first,
         let submesh = mesh.submeshes.first as? MDLSubmesh else {
       print("❌ Invalid mesh structure")
       print("   Vertex buffers: \(mesh.vertexBuffers.count)")
       print("   Submeshes: \(mesh.submeshes.count)")
       return
   }
   ```

3. **Index out of bounds:**
   ```swift
   // Validate indices
   for i in stride(from: 0, to: indexCount, by: 3) {
       guard i + 2 < indexCount else {
           print("❌ Invalid triangle at index \(i)")
           continue
       }
       // ... process triangle
   }
   ```

---

### Issue: Exported STL won't open in Cura/slicer

**Symptoms:**
- File exports successfully
- Slicer shows "Invalid file" or doesn't load

**Validation:**

1. **Check file size:**
   ```bash
   ls -lh ~/Documents/exported.stl
   # Should be > 100KB for face scan
   ```

2. **Check STL header:**
   ```bash
   hexdump -C exported.stl | head -20
   # First 80 bytes: ASCII header
   # Bytes 80-83: Triangle count (little-endian)
   ```

3. **Validate triangle count:**
   ```swift
   let expectedSize = 80 + 4 + (triangleCount * 50)
   print("Expected size: \(expectedSize) bytes")
   print("Actual size: \(data.count) bytes")
   ```

4. **Test in MeshLab first:**
   - Open with MeshLab (more forgiving)
   - Check for manifold errors
   - Filters → Cleaning → Fix Non-Manifold Edges

**Common fixes:**
- Ensure little-endian byte order
- Verify triangle count matches actual triangles
- Check for degenerate triangles (zero area)
- Ensure normals are valid (not NaN or infinite)

---

## 🔵 Quality Issues

### Issue: Mesh has holes or gaps

**Symptoms:**
- Visible holes in preview
- Non-manifold warnings in slicer

**Causes:**
- Insufficient frame capture
- Motion during scan
- Poor lighting

**Solutions:**

1. **Increase frame count:**
   ```swift
   private let targetFrameCount = 120  // Increase from 90
   ```

2. **Implement hole filling:**
   ```swift
   func fillHoles(_ mesh: MDLMesh) -> MDLMesh {
       // Use ModelIO's built-in hole filling
       // Or implement custom algorithm
   }
   ```

3. **Better frame filtering:**
   ```swift
   func shouldCaptureFrame(_ anchor: ARFaceAnchor, _ frame: ARFrame) -> Bool {
       // Reject frames with motion blur
       guard frame.camera.trackingState == .normal else { return false }
       
       // Reject frames that differ too much from previous
       if let lastFrame = capturedFrames.last {
           let difference = calculateDifference(anchor.geometry, lastFrame)
           guard difference < threshold else { return false }
       }
       
       return true
   }
   ```

---

### Issue: Mesh is too noisy/bumpy

**Symptoms:**
- Surface has rough texture
- Lots of small imperfections

**Solutions:**

1. **Add Laplacian smoothing:**
   ```swift
   func smoothMesh(_ mesh: MDLMesh, iterations: Int = 5) -> MDLMesh {
       for _ in 0..<iterations {
           // For each vertex, average with neighbors
           // Update all vertices simultaneously
       }
       return mesh
   }
   ```

2. **Increase frame averaging:**
   - More frames = smoother result
   - Trade-off: slower capture

3. **Better lighting:**
   - Even, diffuse lighting works best
   - Avoid harsh shadows or direct sunlight

---

### Issue: Exported mesh is too large/detailed

**Symptoms:**
- STL file > 10MB
- Slicer is slow
- Unnecessary detail

**Solution - Mesh decimation:**
```swift
func decimateMesh(_ mesh: MDLMesh, targetVertexCount: Int) -> MDLMesh {
    // Reduce vertex count while preserving shape
    // ModelIO doesn't have built-in decimation
    // Options:
    // 1. Use OpenSubdiv
    // 2. Implement quadric error metrics
    // 3. Export to external tool (MeshLab) for decimation
}
```

**Workaround:**
- Export high-quality mesh
- Decimate in MeshLab: Filters → Remeshing → Simplification: Quadric Edge Collapse Decimation
- Re-import for printing

---

## 🟣 Performance Issues

### Issue: Low frame rate during scanning

**Symptoms:**
- Laggy camera preview
- Choppy visualization
- iPhone gets hot

**Solutions:**

1. **Reduce visualization complexity:**
   ```swift
   // In Coordinator
   func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
       // Simplify wireframe
       node.geometry?.firstMaterial?.fillMode = .lines
       node.geometry?.firstMaterial?.isLitPerPixel = false
   }
   ```

2. **Optimize frame capture:**
   ```swift
   // Don't capture every frame
   private var frameSkipCounter = 0
   
   func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
       frameSkipCounter += 1
       guard frameSkipCounter % 2 == 0 else { return }  // Capture every 2nd frame
       // ... capture logic
   }
   ```

3. **Move heavy processing off main thread:**
   ```swift
   func captureMesh() {
       DispatchQueue.global(qos: .userInitiated).async {
           let mesh = self.aggregateFrames(self.capturedFrames)
           DispatchQueue.main.async {
               self.capturedMesh = mesh
           }
       }
   }
   ```

---

### Issue: App memory warning / crashes after multiple scans

**Symptoms:**
- Console: "Memory pressure warning"
- App crashes after 3-5 scans
- Instruments shows growing memory

**Solutions:**

1. **Clear captured frames:**
   ```swift
   func stopScanning() {
       session.pause()
       isScanning = false
       capturedFrames.removeAll()  // Free memory
   }
   ```

2. **Limit stored scans:**
   ```swift
   func saveScans(_ scans: [FaceScan]) {
       // Keep only last 50 scans
       let recentScans = Array(scans.suffix(50))
       // Save recentScans...
   }
   ```

3. **Use Instruments to find leaks:**
   - Product → Profile (Cmd+I)
   - Choose "Leaks" template
   - Run through complete scan workflow
   - Look for growing allocations

---

## 🔧 Development Workflow Issues

### Issue: Xcode and Claude Code out of sync

**Symptoms:**
- Xcode shows old code
- Changes don't appear
- Build uses wrong version

**Solution:**
```bash
# In Terminal
cd /path/to/FaceScanner

# See what Claude Code created
ls -la FaceScanner/Services/

# Force Xcode to refresh
killall Xcode
open FaceScanner.xcodeproj
```

---

### Issue: Can't build on device - provisioning profile errors

**Symptoms:**
- "No provisioning profile found"
- "Failed to create provisioning profile"

**Solution:**
1. Xcode → Settings → Accounts
2. Add Apple ID if not present
3. Select target → Signing & Capabilities
4. Team: Select your Apple ID
5. Enable "Automatically manage signing"
6. Wait for Xcode to generate profile (may take 1-2 minutes)

---

## 📊 Debugging Techniques

### Enable verbose AR logging

```swift
// In FaceScannerApp.swift
init() {
    // Enable ARKit debug options
    UserDefaults.standard.set(true, forKey: "ARKitDebugEnabled")
}

// In ARFaceScanner
func startScanning() {
    let configuration = ARFaceTrackingConfiguration()
    
    #if DEBUG
    configuration.debugOptions = [.showFeaturePoints, .showWorldOrigin]
    #endif
    
    session.run(configuration)
}
```

### Log all mesh statistics

```swift
func debugMesh(_ mesh: MDLMesh) {
    print("🔍 Mesh Debug:")
    print("   Vertices: \(mesh.vertexCount)")
    print("   Submeshes: \(mesh.submeshes.count)")
    
    if let submesh = mesh.submeshes.first as? MDLSubmesh {
        print("   Triangles: \(submesh.indexCount / 3)")
        print("   Index type: \(submesh.indexType.rawValue)")
    }
    
    print("   Bounds: \(mesh.boundingBox)")
}
```

### Validate exported STL programmatically

```swift
func validateSTL(at url: URL) -> Bool {
    guard let data = try? Data(contentsOf: url) else {
        print("❌ Cannot read file")
        return false
    }
    
    guard data.count > 84 else {
        print("❌ File too small (< 84 bytes)")
        return false
    }
    
    // Read triangle count
    let triangleCountBytes = data.subdata(in: 80..<84)
    let triangleCount = triangleCountBytes.withUnsafeBytes {
        $0.load(as: UInt32.self)
    }
    
    let expectedSize = 80 + 4 + (Int(triangleCount) * 50)
    
    if data.count == expectedSize {
        print("✅ Valid STL file")
        print("   Triangles: \(triangleCount)")
        return true
    } else {
        print("❌ Invalid STL file")
        print("   Expected: \(expectedSize) bytes")
        print("   Actual: \(data.count) bytes")
        return false
    }
}
```

---

## 🆘 Emergency Fixes

### Nuclear option: Clean everything

```bash
# Terminal
cd /path/to/FaceScanner

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/FaceScanner-*

# Clean build in Xcode
# Product → Clean Build Folder (Cmd+Shift+K)

# Delete app from device
# Long-press app icon → Delete App

# Restart Xcode
killall Xcode

# Rebuild
xcodebuild -scheme FaceScanner clean build
```

---

## 📞 When to Ask for Help

**Ask Claude Code for help when:**
- Build errors you don't understand
- Need to implement complex algorithms
- Refactoring existing code
- Adding new features

**Search Apple forums when:**
- ARKit-specific issues
- Xcode configuration problems
- Device compatibility questions

**Check external tools when:**
- STL validation issues → Use MeshLab
- Printing problems → Ask on 3D printing forums
- Mesh quality → Use Blender for visual inspection

---

## 🎯 Quick Diagnostic Checklist

When something goes wrong, check these in order:

- [ ] Is deployment target iOS 16.0+?
- [ ] Are Info.plist permissions set?
- [ ] Is Face ID capability added?
- [ ] Testing on physical device (not Simulator)?
- [ ] Device has TrueDepth camera?
- [ ] Camera permissions granted?
- [ ] Clean build completed (Cmd+Shift+K)?
- [ ] Latest code from Claude Code added to Xcode?
- [ ] Build succeeds with no warnings?
- [ ] Console shows meaningful errors?

**90% of issues are one of these!**

---

**Keep this guide handy during development. Most issues have simple fixes!**
