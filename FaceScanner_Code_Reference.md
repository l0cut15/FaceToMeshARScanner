# FaceScanner - Critical Code Reference

## Essential Code Patterns for Claude Code Implementation

This document contains the most important code patterns and implementation details.

---

## 1. ARKit Face Scanning Core

### ARFaceScanner.swift - Session Setup

```swift
import ARKit
import Combine

class ARFaceScanner: NSObject, ObservableObject {
    
    // MARK: - Properties
    private let session = ARSession()
    private var sceneView: ARSCNView?
    
    @Published var isScanning = false
    @Published var scanQuality: ScanQuality = .poor
    @Published var faceDetected = false
    @Published var capturedFrames: [ARFaceGeometry] = []
    @Published var instructionText = "Position your face in the frame"
    
    // Quality thresholds
    private let minDistance: Float = 0.3  // meters
    private let maxDistance: Float = 0.5  // meters
    private let targetFrameCount = 90     // ~3 seconds at 30fps
    
    // MARK: - Initialization
    override init() {
        super.init()
        session.delegate = self
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("❌ Face tracking not supported on this device")
            return
        }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isLightEstimationEnabled = true
        
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isScanning = true
        capturedFrames.removeAll()
    }
    
    func stopScanning() {
        session.pause()
        isScanning = false
    }
    
    func captureMesh() -> MDLMesh? {
        guard !capturedFrames.isEmpty else { return nil }
        return aggregateFrames(capturedFrames)
    }
    
    // MARK: - Private Methods
    private func assessScanQuality(_ faceAnchor: ARFaceAnchor, 
                                   frame: ARFrame) -> ScanQuality {
        // Distance check
        let transform = faceAnchor.transform
        let position = transform.columns.3
        let distance = simd_length(SIMD3<Float>(position.x, position.y, position.z))
        
        guard distance >= minDistance && distance <= maxDistance else {
            if distance < minDistance {
                instructionText = "Move back - too close"
            } else {
                instructionText = "Move closer"
            }
            return .poor
        }
        
        // Tracking quality check
        guard frame.camera.trackingState == .normal else {
            instructionText = "Keep face steady"
            return .poor
        }
        
        // Light estimation (if available)
        if let lightEstimate = frame.lightEstimate {
            let intensity = lightEstimate.ambientIntensity
            guard intensity > 500 else {
                instructionText = "Need better lighting"
                return .fair
            }
        }
        
        instructionText = "Perfect - hold steady"
        return .good
    }
    
    private func aggregateFrames(_ frames: [ARFaceGeometry]) -> MDLMesh? {
        guard !frames.isEmpty else { return nil }
        
        // Simple averaging of vertex positions
        let vertexCount = frames[0].vertices.count
        var averagedVertices = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), 
                                               count: vertexCount)
        
        for frame in frames {
            for i in 0..<vertexCount {
                averagedVertices[i] += frame.vertices[i]
            }
        }
        
        for i in 0..<vertexCount {
            averagedVertices[i] /= Float(frames.count)
        }
        
        // Convert to MDLMesh
        return createMDLMesh(vertices: averagedVertices, 
                            indices: Array(frames[0].triangleIndices))
    }
    
    private func createMDLMesh(vertices: [SIMD3<Float>], 
                              indices: [Int32]) -> MDLMesh {
        
        let allocator = MTKMeshBufferAllocator(device: MTLCreateSystemDefaultDevice()!)
        
        // Create vertex buffer
        let vertexData = vertices.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)
        
        // Create index buffer
        let indexData = indices.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        
        // Create submesh
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: indices.count,
                                 indexType: .uint32,
                                 geometryType: .triangles,
                                 material: nil)
        
        // Create mesh
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)
        
        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                          vertexCount: vertices.count,
                          descriptor: vertexDescriptor,
                          submeshes: [submesh])
        
        return mesh
    }
}

// MARK: - ARSessionDelegate
extension ARFaceScanner: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first,
              let frame = session.currentFrame else {
            faceDetected = false
            return
        }
        
        faceDetected = true
        scanQuality = assessScanQuality(faceAnchor, frame: frame)
        
        // Auto-capture frames when quality is good
        if scanQuality == .good && capturedFrames.count < targetFrameCount {
            capturedFrames.append(faceAnchor.geometry)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ AR Session failed: \(error.localizedDescription)")
        stopScanning()
    }
}

// MARK: - Supporting Types
enum ScanQuality {
    case poor, fair, good
    
    var color: Color {
        switch self {
        case .poor: return .red
        case .fair: return .yellow
        case .good: return .green
        }
    }
}
```

---

## 2. STL Export Implementation

### FileExporter.swift - Binary STL

```swift
import ModelIO
import UIKit

class FileExporter {
    
    private let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    
    // MARK: - STL Export (Binary)
    func exportAsSTL(_ mesh: MDLMesh, filename: String) -> URL? {
        let fileURL = documentsURL.appendingPathComponent("\(filename).stl")
        
        guard let vertexBuffer = mesh.vertexBuffers.first,
              let submesh = mesh.submeshes.first as? MDLSubmesh else {
            print("❌ Invalid mesh structure")
            return nil
        }
        
        // Extract vertices
        let vertexCount = mesh.vertexCount
        let vertexStride = mesh.vertexDescriptor.layouts[0] as! MDLVertexBufferLayout
        let vertexPointer = vertexBuffer.map().bytes.assumingMemoryBound(to: SIMD3<Float>.self)
        var vertices = [SIMD3<Float>]()
        for i in 0..<vertexCount {
            vertices.append(vertexPointer[i])
        }
        
        // Extract indices
        let indexBuffer = submesh.indexBuffer
        let indexCount = submesh.indexCount
        let indexPointer = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)
        var indices = [UInt32]()
        for i in 0..<indexCount {
            indices.append(indexPointer[i])
        }
        
        // Create STL data
        var data = Data()
        
        // Header (80 bytes)
        let header = "FaceScanner v1.0".padding(toLength: 80, withPad: " ", startingAt: 0)
        data.append(header.data(using: .ascii)!)
        
        // Triangle count (4 bytes, little-endian uint32)
        let triangleCount = UInt32(indexCount / 3)
        var triangleCountBytes = triangleCount.littleEndian
        data.append(Data(bytes: &triangleCountBytes, count: 4))
        
        // Write triangles
        for i in stride(from: 0, to: indexCount, by: 3) {
            let v1 = vertices[Int(indices[i])]
            let v2 = vertices[Int(indices[i+1])]
            let v3 = vertices[Int(indices[i+2])]
            
            // Calculate normal
            let edge1 = v2 - v1
            let edge2 = v3 - v1
            let normal = normalize(cross(edge1, edge2))
            
            // Write normal (12 bytes)
            data.append(withUnsafeBytes(of: normal.x.littleEndian) { Data($0) })
            data.append(withUnsafeBytes(of: normal.y.littleEndian) { Data($0) })
            data.append(withUnsafeBytes(of: normal.z.littleEndian) { Data($0) })
            
            // Write vertices (36 bytes total)
            for vertex in [v1, v2, v3] {
                data.append(withUnsafeBytes(of: vertex.x.littleEndian) { Data($0) })
                data.append(withUnsafeBytes(of: vertex.y.littleEndian) { Data($0) })
                data.append(withUnsafeBytes(of: vertex.z.littleEndian) { Data($0) })
            }
            
            // Attribute byte count (2 bytes, always 0)
            var attributeBytes: UInt16 = 0
            data.append(withUnsafeBytes(of: attributeBytes.littleEndian) { Data($0) })
        }
        
        // Write to file
        do {
            try data.write(to: fileURL)
            print("✅ STL exported: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to write STL: \(error)")
            return nil
        }
    }
    
    // MARK: - OBJ Export (ASCII)
    func exportAsOBJ(_ mesh: MDLMesh, filename: String) -> URL? {
        let fileURL = documentsURL.appendingPathComponent("\(filename).obj")
        
        guard let asset = MDLAsset(url: fileURL) else {
            return nil
        }
        
        asset.add(mesh)
        
        do {
            try asset.export(to: fileURL)
            print("✅ OBJ exported: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to write OBJ: \(error)")
            return nil
        }
    }
    
    // MARK: - Preview Generation
    func createPreviewImage(_ mesh: MDLMesh, size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        // Create scene
        let scene = SCNScene()
        
        // Convert MDLMesh to SCNGeometry
        let geometryNode = SCNNode(geometry: SCNGeometry(mdlMesh: mesh))
        scene.rootNode.addChildNode(geometryNode)
        
        // Position camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 0.5)
        scene.rootNode.addChildNode(cameraNode)
        
        // Add lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        // Render to image
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice()!, options: nil)
        renderer.scene = scene
        
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        
        return image
    }
}
```

---

## 3. SwiftUI AR View Integration

### ScanView.swift - AR Camera View

```swift
import SwiftUI
import SceneKit
import ARKit

struct ScanView: View {
    @StateObject private var scanner = ARFaceScanner()
    @State private var showingPreview = false
    @State private var capturedMesh: MDLMesh?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // AR Camera View
            ARViewContainer(scanner: scanner)
                .ignoresSafeArea()
            
            // UI Overlays
            VStack {
                // Top controls
                HStack {
                    Button("Cancel") {
                        scanner.stopScanning()
                        dismiss()
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Quality indicator
                    Circle()
                        .fill(scanner.scanQuality.color)
                        .frame(width: 20, height: 20)
                        .padding()
                }
                
                // Instruction text
                Text(scanner.instructionText)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding()
                
                Spacer()
                
                // Progress
                if scanner.isScanning {
                    ProgressView(value: Double(scanner.capturedFrames.count),
                                total: 90)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                        .padding()
                }
                
                // Capture button
                Button(action: capture) {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .fill(scanner.canCapture ? Color.white : Color.gray)
                                .frame(width: 60, height: 60)
                        )
                }
                .disabled(!scanner.canCapture)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            scanner.startScanning()
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .sheet(isPresented: $showingPreview) {
            if let mesh = capturedMesh {
                PreviewView(mesh: mesh)
            }
        }
    }
    
    private func capture() {
        guard let mesh = scanner.captureMesh() else {
            print("❌ Failed to capture mesh")
            return
        }
        
        capturedMesh = mesh
        scanner.stopScanning()
        showingPreview = true
    }
}

// MARK: - AR View Container (UIKit Bridge)
struct ARViewContainer: UIViewRepresentable {
    let scanner: ARFaceScanner
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session = scanner.session
        arView.automaticallyUpdatesLighting = true
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scanner: scanner)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        let scanner: ARFaceScanner
        
        init(scanner: ARFaceScanner) {
            self.scanner = scanner
        }
        
        func renderer(_ renderer: SCNSceneRenderer, 
                     nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let device = renderer.device else {
                return nil
            }
            
            // Create face geometry visualization
            let faceGeometry = ARSCNFaceGeometry(device: device)
            let node = SCNNode(geometry: faceGeometry)
            node.geometry?.firstMaterial?.fillMode = .lines
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.5)
            
            return node
        }
        
        func renderer(_ renderer: SCNSceneRenderer, 
                     didUpdate node: SCNNode, 
                     for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
                return
            }
            
            faceGeometry.update(from: faceAnchor.geometry)
        }
    }
}
```

---

## 4. Data Models

### FaceScan.swift

```swift
import Foundation

struct FaceScan: Identifiable, Codable {
    let id: UUID
    var name: String
    let date: Date
    let meshFileURL: URL
    var thumbnailData: Data?
    let vertexCount: Int
    let settings: ScanSettings
    
    init(name: String = "Face Scan",
         meshFileURL: URL,
         vertexCount: Int,
         settings: ScanSettings = ScanSettings()) {
        self.id = UUID()
        self.name = name
        self.date = Date()
        self.meshFileURL = meshFileURL
        self.vertexCount = vertexCount
        self.settings = settings
    }
}

struct ScanSettings: Codable {
    var exportFormat: ExportFormat = .stl
    var quality: Quality = .medium
    var scale: Float = 1.0
    var smoothingIterations: Int = 2
    
    enum ExportFormat: String, Codable {
        case stl = "STL"
        case obj = "OBJ"
    }
    
    enum Quality: String, Codable {
        case low = "Low (5K vertices)"
        case medium = "Medium (10K vertices)"
        case high = "High (20K vertices)"
        
        var targetVertexCount: Int {
            switch self {
            case .low: return 5000
            case .medium: return 10000
            case .high: return 20000
            }
        }
    }
}
```

---

## 5. Essential Extensions

### Extensions.swift

```swift
import simd
import SceneKit

// MARK: - SIMD Extensions
extension SIMD3<Float> {
    static func +(lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    static func -(lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }
    
    static func /(lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        return SIMD3<Float>(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }
}

// MARK: - SCNVector3 Conversion
extension SIMD3 where Scalar == Float {
    var scnVector: SCNVector3 {
        return SCNVector3(x, y, z)
    }
}

extension SCNVector3 {
    var simd: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

// MARK: - Date Formatting
extension Date {
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
```

---

## 6. Storage Manager

### StorageManager.swift

```swift
import Foundation

class StorageManager {
    static let shared = StorageManager()
    
    private let scansKey = "savedScans"
    private let documentsURL = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]
    
    private init() {}
    
    // MARK: - Save/Load Scans
    func saveScans(_ scans: [FaceScan]) {
        guard let data = try? JSONEncoder().encode(scans) else {
            print("❌ Failed to encode scans")
            return
        }
        UserDefaults.standard.set(data, forKey: scansKey)
    }
    
    func loadScans() -> [FaceScan] {
        guard let data = UserDefaults.standard.data(forKey: scansKey),
              let scans = try? JSONDecoder().decode([FaceScan].self, from: data) else {
            return []
        }
        return scans
    }
    
    // MARK: - Mesh File Management
    func getMeshFileURL(for scanID: UUID) -> URL {
        return documentsURL
            .appendingPathComponent("scans")
            .appendingPathComponent("\(scanID.uuidString).stl")
    }
    
    func deleteScan(_ scan: FaceScan) {
        // Delete mesh file
        try? FileManager.default.removeItem(at: scan.meshFileURL)
        
        // Remove from saved scans
        var scans = loadScans()
        scans.removeAll { $0.id == scan.id }
        saveScans(scans)
    }
}
```

---

## 7. Testing Utilities

### Quick Test Helper

```swift
// Add to any view for quick testing
#if DEBUG
struct TestData {
    static func createDummyMesh() -> MDLMesh {
        // Create a simple cube for testing
        let allocator = MTKMeshBufferAllocator(
            device: MTLCreateSystemDefaultDevice()!
        )
        return MDLMesh(boxWithExtent: [0.1, 0.1, 0.1],
                      segments: [1, 1, 1],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator)
    }
}
#endif
```

---

## Common Gotchas

### 1. Memory Management
```swift
// ❌ DON'T: Capture strong references
scanner.onComplete = { [self] in
    self.processMesh()
}

// ✅ DO: Use weak self
scanner.onComplete = { [weak self] in
    self?.processMesh()
}
```

### 2. Thread Safety
```swift
// ❌ DON'T: Update UI on background thread
session.delegate = { 
    self.isScanning = false  // Crash!
}

// ✅ DO: Dispatch to main queue
DispatchQueue.main.async {
    self.isScanning = false
}
```

### 3. Force Unwrapping
```swift
// ❌ DON'T: Force unwrap
let device = MTLCreateSystemDefaultDevice()!

// ✅ DO: Guard or if-let
guard let device = MTLCreateSystemDefaultDevice() else {
    print("Metal not supported")
    return
}
```

---

## Build & Run Checklist

Before running on device:

- [ ] All services compile
- [ ] Info.plist has camera permission
- [ ] Face ID capability added
- [ ] Deployment target is iOS 16.0+
- [ ] Connected to iPhone with TrueDepth
- [ ] Build configuration is Debug
- [ ] Provisioning profile is valid

---

**Use this reference while working with Claude Code to ensure critical implementations are correct!**
