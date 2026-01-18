//
//  ARFaceScanner.swift
//  FaceScanner
//
//  ARKit face tracking and mesh capture service
//

import ARKit
import Combine
import ModelIO
import MetalKit
import SwiftUI

class ARFaceScanner: NSObject, ObservableObject {

    // MARK: - Properties
    private(set) var session = ARSession()

    @Published var isScanning = false
    @Published var scanQuality: ScanQuality = .poor
    @Published var faceDetected = false
    @Published var instructionText = "Position your face in the frame"
    @Published var capturedFrames: [ARFaceGeometry] = []

    // Quality thresholds
    private let minDistance: Float = Constants.ScanQuality.minDistance
    private let maxDistance: Float = Constants.ScanQuality.maxDistance
    private let targetFrameCount = Constants.ScanQuality.targetFrameCount

    var canCapture: Bool {
        return capturedFrames.count >= targetFrameCount && scanQuality == .good
    }

    // MARK: - Initialization
    override init() {
        super.init()
        session.delegate = self
    }

    // MARK: - Public Methods
    func startScanning() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("❌ Face tracking not supported on this device")
            DispatchQueue.main.async {
                self.instructionText = "Face tracking not supported"
            }
            return
        }

        print("🎥 Starting AR face tracking session...")
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isLightEstimationEnabled = true

        // Update UI state immediately
        isScanning = true
        capturedFrames.removeAll()
        instructionText = "Position your face in the frame"
        
        // Run AR session (this is safe to call from main thread)
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("✅ AR session started successfully")
    }

    func stopScanning() {
        session.pause()
        isScanning = false
        capturedFrames.removeAll()
    }

    func captureMesh() -> MDLMesh? {
        guard !capturedFrames.isEmpty else {
            print("❌ No frames captured")
            return nil
        }
        print("📦 Creating mesh from \(capturedFrames.count) frames...")
        let mesh = aggregateFrames(capturedFrames)
        if let mesh = mesh {
            print("✅ Mesh created with \(mesh.vertexCount) vertices")
        } else {
            print("❌ Failed to create mesh")
        }
        return mesh
    }

    // MARK: - Private Methods
    private func assessScanQuality(_ faceAnchor: ARFaceAnchor, frame: ARFrame) -> ScanQuality {
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
            guard intensity > Constants.ScanQuality.minLightIntensity else {
                instructionText = "Need better lighting"
                return .fair
            }
        }

        instructionText = "Perfect - hold steady"
        return .good
    }

    private func aggregateFrames(_ frames: [ARFaceGeometry]) -> MDLMesh? {
        guard !frames.isEmpty else { return nil }

        print("🔄 Aggregating \(frames.count) frames...")
        
        // Simple averaging of vertex positions
        let vertexCount = frames[0].vertices.count
        print("   Each frame has \(vertexCount) vertices")
        
        var averagedVertices = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0),
                                               count: vertexCount)

        for frame in frames {
            for i in 0..<vertexCount {
                averagedVertices[i] += frame.vertices[i]
            }
        }

        for i in 0..<vertexCount {
            averagedVertices[i] /= Float(frames.count)
        }

        // Convert to MDLMesh (triangleIndices are Int16, convert to Int32)
        let triangleCount = frames[0].triangleCount
        let indexCount = triangleCount * 3
        print("   Triangle count: \(triangleCount), Index count: \(indexCount)")
        
        let int32Indices = frames[0].triangleIndices.map { Int32($0) }
        print("   Creating MDLMesh with \(averagedVertices.count) vertices and \(int32Indices.count) indices")
        
        return createMDLMesh(vertices: averagedVertices,
                            indices: int32Indices)
    }

    private func createMDLMesh(vertices: [SIMD3<Float>], indices: [Int32]) -> MDLMesh? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal device not available")
            return nil
        }

        let allocator = MTKMeshBufferAllocator(device: device)

        // Create vertex buffer
        let vertexData = vertices.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

        // Create index buffer (convert Int32 to UInt32)
        let uint32Indices = indices.map { UInt32($0) }
        let indexData = uint32Indices.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        // Create submesh
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: indices.count,
                                 indexType: .uint32,
                                 geometryType: .triangles,
                                 material: nil)

        // Create vertex descriptor
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)

        // Create mesh
        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                          vertexCount: vertices.count,
                          descriptor: vertexDescriptor,
                          submeshes: [submesh])
        
        // Generate normals for proper shading
        do {
            mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
            print("✅ MDLMesh created successfully")
            print("   Vertex count: \(mesh.vertexCount)")
            print("   Submesh count: \(mesh.submeshes?.count ?? 0)")
            print("   Normals generated: ✅")
        } catch {
            print("⚠️ Could not generate normals: \(error)")
            print("   Mesh will still display but may look flat")
        }

        return mesh
    }
}

// MARK: - ARSessionDelegate
extension ARFaceScanner: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first,
              let frame = session.currentFrame else {
            DispatchQueue.main.async {
                self.faceDetected = false
            }
            return
        }

        DispatchQueue.main.async {
            self.faceDetected = true
            self.scanQuality = self.assessScanQuality(faceAnchor, frame: frame)

            // Auto-capture frames when quality is good (enforce max limit)
            if self.scanQuality == .good && self.capturedFrames.count < Constants.ScanQuality.maxFrameCount {
                self.capturedFrames.append(faceAnchor.geometry)
                // Log every 10th frame to reduce console spam
                if self.capturedFrames.count % 10 == 0 || self.capturedFrames.count == 1 {
                    print("📸 Captured frame \(self.capturedFrames.count)/\(Constants.ScanQuality.maxFrameCount)")
                }
            } else if self.capturedFrames.count >= Constants.ScanQuality.maxFrameCount {
                // Stop capturing to prevent unbounded growth
                self.instructionText = "Ready to capture!"
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ AR Session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.stopScanning()
        }
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
