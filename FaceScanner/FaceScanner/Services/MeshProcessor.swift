//
//  MeshProcessor.swift
//  FaceScanner
//
//  Mesh optimization and processing operations
//

import Foundation
import ModelIO
import MetalKit

class MeshProcessor {

    // MARK: - Mesh Smoothing
    func smoothMesh(_ mesh: MDLMesh, iterations: Int = 5) -> MDLMesh {
        guard iterations > 0 else { return mesh }

        // Extract current vertices
        guard let vertexBuffer = mesh.vertexBuffers.first,
              let vertexDescriptor = mesh.vertexDescriptor.attributes[0] as? MDLVertexAttribute else {
            print("❌ Invalid mesh structure for smoothing")
            return mesh
        }

        let vertexCount = mesh.vertexCount
        let stride = (mesh.vertexDescriptor.layouts[0] as! MDLVertexBufferLayout).stride
        let vertexPointer = vertexBuffer.map().bytes.assumingMemoryBound(to: SIMD3<Float>.self)

        var vertices = [SIMD3<Float>]()
        for i in 0..<vertexCount {
            vertices.append(vertexPointer[i])
        }

        // Build adjacency list
        let adjacency = buildAdjacencyList(mesh)

        // Laplacian smoothing iterations
        for _ in 0..<iterations {
            var smoothedVertices = vertices

            for i in 0..<vertexCount {
                guard let neighbors = adjacency[i], !neighbors.isEmpty else {
                    continue
                }

                // Average neighbor positions
                var sum = SIMD3<Float>(0, 0, 0)
                for neighborIndex in neighbors {
                    sum += vertices[neighborIndex]
                }
                smoothedVertices[i] = sum / Float(neighbors.count)
            }

            vertices = smoothedVertices
        }

        // Create new mesh with smoothed vertices
        guard let submesh = mesh.submeshes.first as? MDLSubmesh else {
            return mesh
        }

        let indexBuffer = submesh.indexBuffer
        let indexCount = submesh.indexCount
        let indexPointer = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)
        var indices = [Int32]()
        for i in 0..<indexCount {
            indices.append(Int32(indexPointer[i]))
        }

        return createMDLMesh(vertices: vertices, indices: indices) ?? mesh
    }

    // MARK: - Mesh Scaling
    func scaleMesh(_ mesh: MDLMesh, scale: Float) -> MDLMesh {
        guard scale > 0 else {
            print("❌ Invalid scale value")
            return mesh
        }

        // Extract vertices
        guard let vertexBuffer = mesh.vertexBuffers.first else {
            print("❌ No vertex buffer")
            return mesh
        }

        let vertexCount = mesh.vertexCount
        let vertexPointer = vertexBuffer.map().bytes.assumingMemoryBound(to: SIMD3<Float>.self)

        var scaledVertices = [SIMD3<Float>]()
        for i in 0..<vertexCount {
            scaledVertices.append(vertexPointer[i] * scale)
        }

        // Get indices
        guard let submesh = mesh.submeshes.first as? MDLSubmesh else {
            return mesh
        }

        let indexBuffer = submesh.indexBuffer
        let indexCount = submesh.indexCount
        let indexPointer = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)
        var indices = [Int32]()
        for i in 0..<indexCount {
            indices.append(Int32(indexPointer[i]))
        }

        return createMDLMesh(vertices: scaledVertices, indices: indices) ?? mesh
    }

    // MARK: - Helper Methods
    private func buildAdjacencyList(_ mesh: MDLMesh) -> [Int: Set<Int>] {
        var adjacency = [Int: Set<Int>]()

        guard let submesh = mesh.submeshes.first as? MDLSubmesh else {
            return adjacency
        }

        let indexBuffer = submesh.indexBuffer
        let indexCount = submesh.indexCount
        let indexPointer = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)

        // Process triangles
        for i in stride(from: 0, to: indexCount, by: 3) {
            let i0 = Int(indexPointer[i])
            let i1 = Int(indexPointer[i + 1])
            let i2 = Int(indexPointer[i + 2])

            // Add edges
            adjacency[i0, default: Set<Int>()].insert(i1)
            adjacency[i0, default: Set<Int>()].insert(i2)

            adjacency[i1, default: Set<Int>()].insert(i0)
            adjacency[i1, default: Set<Int>()].insert(i2)

            adjacency[i2, default: Set<Int>()].insert(i0)
            adjacency[i2, default: Set<Int>()].insert(i1)
        }

        return adjacency
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

        // Generate normals
        mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.0)

        return mesh
    }
}
