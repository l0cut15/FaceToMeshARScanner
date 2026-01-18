# FaceScanner

A professional iOS app for capturing high-quality 3D face scans using ARKit, designed for 3D printing and modeling.

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![ARKit](https://img.shields.io/badge/ARKit-Face%20Tracking-green.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

## Features

### 🎭 Face Scanning
- **Real-time AR face tracking** with TrueDepth camera
- **Automatic quality assessment** (distance, lighting, tracking state)
- **120-frame capture** for high-quality mesh averaging
- **Live quality indicator** (red/yellow/green)
- **Visual wireframe overlay** during scanning
- **Auto-capture** when quality is optimal

### 📦 Mesh Processing
- **Frame averaging** for noise reduction
- **Mesh smoothing** (Laplacian algorithm, adjustable iterations)
- **Scaling controls** (0.5x - 2.0x for 3D printing)
- **Normal generation** for proper shading
- **~1,220 vertices** and ~2,300 triangles per scan

### 💾 Export & Storage
- **STL export** (binary format for 3D printing)
- **OBJ export** (ASCII format for 3D modeling)
- **Local storage** with scan management
- **Share functionality** for AirDrop, Files, etc.
- **Scan history** with thumbnails and metadata

### 🎨 3D Preview
- **Interactive 3D viewer** (rotate, zoom, pan)
- **Professional lighting setup** (key, fill, rim, ambient)
- **Material customization** (color, smoothing, scale)
- **Real-time rendering** with SceneKit

## Screenshots

| Home | Scanning | Preview | History |
|------|----------|---------|---------|
| ![Home](screenshots/home.png) | ![Scan](screenshots/scan.png) | ![Preview](screenshots/preview.png) | ![History](screenshots/history.png) |

## Requirements

### Device
- **iPhone X or newer** (with Face ID)
- **iPad Pro** (2018 or newer with Face ID)
- **TrueDepth camera** required for face tracking

### Software
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/FaceScanner.git
cd FaceScanner
```

### 2. Open in Xcode
```bash
open FaceScanner.xcodeproj
```

### 3. Configure Signing
- Select your development team in **Signing & Capabilities**
- Update the bundle identifier if needed

### 4. Add Camera Permission
In `Info.plist`, add:
```xml
<key>NSCameraUsageDescription</key>
<string>FaceScanner needs camera access to capture 3D face scans for 3D printing.</string>
```

### 5. Build and Run
- Connect a Face ID-capable device
- Select your device in Xcode
- Press **⌘R** to build and run

## Usage

### Scanning a Face

1. **Open the app** and tap the **Scan** tab
2. **Grant camera permission** when prompted
3. **Position your face** in the camera view
   - Distance: 30-50 cm from camera
   - Good lighting recommended
   - Face the camera directly
4. **Wait for green indicator** (optimal quality)
5. **Hold steady** while 120 frames are captured (~4 seconds)
6. **Tap capture button** to finalize the scan

### Editing Settings

1. Tap **Edit** in the preview screen
2. Adjust settings:
   - **Export Format**: STL (3D printing) or OBJ (modeling)
   - **Quality**: Low/Medium/High vertex count
   - **Smoothing**: 0-10 iterations
   - **Scale**: 0.5x - 2.0x for print sizing

### Exporting Files

1. **Save** the scan with a custom name
2. Go to **History** tab
3. Tap a scan to view details
4. Use **Share** to export via:
   - AirDrop
   - Files app
   - Mail/Messages
   - Cloud storage apps

### 3D Printing

1. Export as **STL format**
2. Open in slicer software (Cura, PrusaSlicer, etc.)
3. Adjust scale if needed (1.0x = life-size)
4. Slice and print!

## Architecture

### Core Components

```
FaceScanner/
├── App/
│   └── FaceScannerApp.swift         # App entry point
├── Views/
│   ├── ContentView.swift            # Main tab navigation
│   ├── ScanView.swift               # AR scanning interface
│   ├── PreviewView.swift            # 3D mesh preview
│   ├── HistoryView.swift            # Scan history grid
│   └── EditView.swift               # Settings editor
├── Services/
│   ├── ARFaceScanner.swift          # ARKit face tracking
│   ├── MeshProcessor.swift          # Mesh operations
│   ├── FileExporter.swift           # STL/OBJ export
│   └── StorageManager.swift         # Local persistence
├── Models/
│   ├── FaceScan.swift               # Scan data model
│   └── ScanSettings.swift           # Export settings
└── Utilities/
    └── Constants.swift               # App constants
```

### Technologies

- **SwiftUI** - Modern declarative UI
- **ARKit** - Face tracking and mesh capture
- **SceneKit** - 3D rendering and preview
- **ModelIO** - Mesh processing and export
- **MetalKit** - GPU-accelerated mesh operations
- **Combine** - Reactive state management

## Technical Details

### Face Mesh Capture

```swift
// 120 frames captured at ~30 fps = 4 seconds
// Each frame: ~1,220 vertices, ~2,300 triangles
// Vertex positions averaged across all frames
// Result: High-quality, noise-reduced mesh
```

### Quality Assessment

Scans are evaluated in real-time based on:
- **Distance**: 0.3m - 0.5m optimal range
- **Tracking state**: Must be `.normal`
- **Lighting**: Minimum 500 lux ambient intensity
- **Frame count**: 90 minimum, 120 maximum

### Mesh Processing

**Smoothing** (Laplacian):
```
For each iteration:
  For each vertex:
    New position = average of neighbor positions
```

**Scaling**:
```
Scale 1.0x = Life-size (~20cm tall)
Scale 0.5x = Half-size for smaller prints
Scale 2.0x = Double-size for larger prints
```

### File Formats

**STL (Binary)**:
- Industry standard for 3D printing
- Compact file size (~2-5 MB per scan)
- Triangle mesh with normals
- Compatible with all slicers

**OBJ (ASCII)**:
- Widely supported in 3D software
- Human-readable format
- Includes vertex positions and faces
- Larger file size but more compatible

## Performance

### Benchmarks
- **Scan capture**: ~4 seconds (120 frames)
- **Mesh processing**: <1 second (1,220 vertices)
- **STL export**: <2 seconds (2,300 triangles)
- **Memory usage**: ~100 MB during scanning
- **Storage per scan**: 2-5 MB

### Optimization
- Frame capture capped at 120 (prevents unbounded growth)
- Mesh operations on background queue
- Lazy loading of scan history
- Pre-allocated arrays for smoothing
- Metal-accelerated rendering

## Troubleshooting

### App crashes on launch
- ✅ Ensure `NSCameraUsageDescription` is in Info.plist
- ✅ Clean build folder (⇧⌘K) and rebuild

### Camera shows black screen
- ✅ Grant camera permission in Settings → Privacy → Camera
- ✅ Test on device with Face ID (not simulator)
- ✅ Restart app after granting permission

### "Face tracking not supported"
- ✅ Device must have TrueDepth camera (iPhone X+)
- ✅ iPad must have Face ID (2018+ Pro models)
- ✅ Simulator does not support face tracking

### Mesh appears pure white/dark
- ✅ Capture a new scan (normals generated during creation)
- ✅ Check console for "Normals generated: ✅"
- ✅ Ensure lighting is not too bright/dark

### Poor scan quality
- ✅ Improve lighting (avoid backlighting)
- ✅ Maintain 30-50 cm distance from camera
- ✅ Keep face steady during capture
- ✅ Face camera directly (not at angle)

### Export fails
- ✅ Check available storage space
- ✅ Verify file permissions
- ✅ Try different export format (STL vs OBJ)

## Known Issues

- [ ] Very large meshes (>20K vertices) may cause memory warnings
- [ ] Extreme lighting conditions can affect scan quality
- [ ] Rapid tab switching during scan may interrupt capture
- [ ] Statistics overlay cannot be disabled in release builds

See [Issues](https://github.com/yourusername/FaceScanner/issues) for full list.

## Roadmap

### v1.1 - Planned Features
- [ ] Mesh decimation (reduce vertex count)
- [ ] Texture capture (color mapping)
- [ ] Multiple face scan merge
- [ ] Cloud sync (iCloud)
- [ ] Export to USDZ format
- [ ] AR Quick Look integration
- [ ] Haptic feedback during capture

### v2.0 - Future Enhancements
- [ ] Full body scanning
- [ ] Animated face capture
- [ ] Facial expression tracking
- [ ] Online 3D print service integration
- [ ] Social sharing features
- [ ] Tutorial/onboarding flow

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftLint for consistency
- Document public APIs
- Write unit tests for core logic

## Testing

### Unit Tests
```bash
⌘U in Xcode
# Or
xcodebuild test -scheme FaceScanner -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Manual Testing Checklist
- [ ] Scan with good lighting
- [ ] Scan with poor lighting
- [ ] Test on different devices (iPhone/iPad)
- [ ] Switch tabs during scanning
- [ ] Background/foreground app
- [ ] Deny/grant camera permission
- [ ] Export STL and verify in slicer
- [ ] Export OBJ and verify in Blender
- [ ] Fill storage and test limits
- [ ] Delete all scans and recreate

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Apple** for ARKit and TrueDepth technology
- **SceneKit** for 3D rendering capabilities
- **ModelIO** for mesh processing tools
- **3D printing community** for feedback and testing

## Support

- 📧 Email: support@facescanner.app
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/FaceScanner/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/FaceScanner/discussions)
- 📖 Wiki: [Documentation](https://github.com/yourusername/FaceScanner/wiki)

## Authors

- **Your Name** - *Initial work* - [@yourusername](https://github.com/yourusername)

## Version History

### v1.0.0 (2026-01-18)
- ✅ Initial release
- ✅ AR face scanning with quality assessment
- ✅ 120-frame capture with averaging
- ✅ STL/OBJ export
- ✅ Mesh smoothing and scaling
- ✅ Local storage with history
- ✅ 3D preview with interactive controls
- ✅ Professional lighting and materials
- ✅ Comprehensive error handling

---

**Made with ❤️ for the 3D printing community**
