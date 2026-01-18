//
//  FileExporter.swift
//  FaceScanner
//
//  File export service for STL and OBJ formats
//

import Foundation
import ModelIO
import SceneKit
import SceneKit.ModelIO
import UIKit
import MetalKit

class FileExporter {

    private let documentsURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    // MARK: - STL Export (Binary)
    func exportAsSTL(_ mesh: MDLMesh, filename: String) -> URL? {
        let fileURL = documentsURL.appendingPathComponent("\(filename).\(Constants.Files.stlExtension)")

        guard let vertexBuffer = mesh.vertexBuffers.first,
              let submeshes = mesh.submeshes,
              submeshes.count > 0,
              let submesh = submeshes[0] as? MDLSubmesh else {
            print("❌ Invalid mesh structure")
            return nil
        }

        // Extract vertices
        let vertexCount = mesh.vertexCount
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
        let header = "FaceScanner v1.0 - 3D Face Scan".padding(toLength: 80, withPad: " ", startingAt: 0)
        data.append(header.data(using: .ascii)!)

        // Triangle count (4 bytes, little-endian uint32)
        let triangleCount = UInt32(indexCount / 3)
        var triangleCountBytes = triangleCount.littleEndian
        data.append(Data(bytes: &triangleCountBytes, count: 4))

        // Write triangles
        for i in stride(from: 0, to: indexCount, by: 3) {
            // Bounds check to prevent crashes
            guard i + 2 < indexCount else {
                print("⚠️ Skipping invalid triangle at index \(i)")
                continue
            }
            
            let idx0 = Int(indices[i])
            let idx1 = Int(indices[i + 1])
            let idx2 = Int(indices[i + 2])
            
            // Validate indices are within vertex array bounds
            guard idx0 < vertices.count && idx1 < vertices.count && idx2 < vertices.count else {
                print("⚠️ Skipping triangle with out-of-bounds indices: [\(idx0), \(idx1), \(idx2)]")
                continue
            }

            let v1 = vertices[idx0]
            let v2 = vertices[idx1]
            let v3 = vertices[idx2]

            // Calculate normal
            let edge1 = v2 - v1
            let edge2 = v3 - v1
            let normal = normalize(cross(edge1, edge2))

            // Write normal (12 bytes) - use bitPattern for Float to bytes conversion
            data.append(withUnsafeBytes(of: normal.x.bitPattern.littleEndian) { Data($0) })
            data.append(withUnsafeBytes(of: normal.y.bitPattern.littleEndian) { Data($0) })
            data.append(withUnsafeBytes(of: normal.z.bitPattern.littleEndian) { Data($0) })

            // Write vertices (36 bytes total)
            for vertex in [v1, v2, v3] {
                data.append(withUnsafeBytes(of: vertex.x.bitPattern.littleEndian) { Data($0) })
                data.append(withUnsafeBytes(of: vertex.y.bitPattern.littleEndian) { Data($0) })
                data.append(withUnsafeBytes(of: vertex.z.bitPattern.littleEndian) { Data($0) })
            }

            // Attribute byte count (2 bytes, always 0)
            let attributeBytes: UInt16 = 0
            data.append(withUnsafeBytes(of: attributeBytes.littleEndian) { Data($0) })
        }

        // Write to file
        do {
            try data.write(to: fileURL)
            print("✅ STL exported: \(fileURL.path)")
            print("   Triangles: \(triangleCount)")
            print("   File size: \(data.count) bytes")
            return fileURL
        } catch {
            print("❌ Failed to write STL: \(error)")
            return nil
        }
    }

    // MARK: - OBJ Export (ASCII)
    func exportAsOBJ(_ mesh: MDLMesh, filename: String) -> URL? {
        let fileURL = documentsURL.appendingPathComponent("\(filename).\(Constants.Files.objExtension)")

        guard let vertexBuffer = mesh.vertexBuffers.first,
              let submeshes = mesh.submeshes,
              submeshes.count > 0,
              let submesh = submeshes[0] as? MDLSubmesh else {
            print("❌ Invalid mesh structure")
            return nil
        }

        // Extract vertices
        let vertexCount = mesh.vertexCount
        let vertexPointer = vertexBuffer.map().bytes.assumingMemoryBound(to: SIMD3<Float>.self)

        // Extract indices
        let indexBuffer = submesh.indexBuffer
        let indexCount = submesh.indexCount
        let indexPointer = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)

        // Build OBJ file content
        var objContent = "# Generated by FaceScanner App\n"
        objContent += "# Vertices: \(vertexCount)\n"
        objContent += "# Faces: \(indexCount / 3)\n\n"

        objContent += "o FaceScan\n\n"

        // Write vertices
        for i in 0..<vertexCount {
            let v = vertexPointer[i]
            objContent += "v \(v.x) \(v.y) \(v.z)\n"
        }

        objContent += "\n"

        // Write faces (OBJ uses 1-based indexing)
        for i in stride(from: 0, to: indexCount, by: 3) {
            let i0 = indexPointer[i] + 1
            let i1 = indexPointer[i + 1] + 1
            let i2 = indexPointer[i + 2] + 1
            objContent += "f \(i0) \(i1) \(i2)\n"
        }

        // Write to file
        do {
            try objContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ OBJ exported: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to write OBJ: \(error)")
            return nil
        }
    }

    // MARK: - Preview Generation
    func createPreviewImage(_ mesh: MDLMesh, size: CGSize = Constants.Files.thumbnailSize) -> UIImage? {
        // Create scene
        let scene = SCNScene()

        // Convert MDLMesh to SCNGeometry via MDLAsset
        guard MTLCreateSystemDefaultDevice() != nil else {
            print("❌ Metal device not available")
            return nil
        }

        let asset = MDLAsset()
        asset.add(mesh)

        let scnScene = SCNScene(mdlAsset: asset)

        // Get the mesh node from converted scene
        if let meshNode = scnScene.rootNode.childNodes.first {
            scene.rootNode.addChildNode(meshNode.clone())
        }

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

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 300
        scene.rootNode.addChildNode(ambientLight)

        // Render to image
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal device not available")
            return nil
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene

        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)

        return image
    }

    // MARK: - File Management
    func getExportURL(for scanID: UUID, format: ScanSettings.ExportFormat) -> URL {
        let filename = scanID.uuidString
        let ext = format == .stl ? Constants.Files.stlExtension : Constants.Files.objExtension
        return documentsURL.appendingPathComponent("\(filename).\(ext)")
    }

    func deleteFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ Deleted file: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete file: \(error)")
        }
    }
}
