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

        // Weld first: ModelIO's `addNormals` de-indexes the mesh (each triangle gets its
        // own vertex copies). Smoothing on that broken topology moves every triangle's
        // corners toward only its own two neighbours, tearing the surface apart. Welding
        // restores the true shared adjacency so smoothing behaves correctly.
        guard let (welded, indices) = weldedGeometry(from: mesh) else {
            print("❌ Invalid mesh structure for smoothing")
            return mesh
        }
        var vertices = welded
        let vertexCount = vertices.count

        // Safety check for very large meshes
        if vertexCount > 50000 {
            print("⚠️ Large mesh detected (\(vertexCount) vertices). This may take a while...")
        }

        // Build adjacency list from the welded topology
        var adjacency = [Set<Int>](repeating: Set<Int>(), count: vertexCount)
        for t in stride(from: 0, to: indices.count - 2, by: 3) {
            let a = indices[t], b = indices[t + 1], c = indices[t + 2]
            adjacency[a].insert(b); adjacency[a].insert(c)
            adjacency[b].insert(a); adjacency[b].insert(c)
            adjacency[c].insert(a); adjacency[c].insert(b)
        }

        // Taubin (λ|μ) smoothing: each iteration does a positive relaxation pass followed
        // by a slightly larger negative pass. This smooths the surface without the volume
        // shrinkage that plain Laplacian smoothing causes, so high iteration counts stay
        // stable (features don't melt away or collapse inward).
        let lambda: Float = 0.5
        let mu: Float = -0.53

        func relax(factor: Float) {
            var updated = vertices
            for i in 0..<vertexCount {
                let neighbors = adjacency[i]
                if neighbors.isEmpty { continue }

                var sum = SIMD3<Float>(0, 0, 0)
                for neighborIndex in neighbors {
                    sum += vertices[neighborIndex]
                }
                let average = sum / Float(neighbors.count)
                updated[i] = vertices[i] + factor * (average - vertices[i])
            }
            vertices = updated
        }

        for iteration in 0..<iterations {
            if iteration % 5 == 0 {
                print("🔄 Smoothing iteration \(iteration + 1)/\(iterations)")
            }
            relax(factor: lambda)
            relax(factor: mu)
        }

        let int32Indices = indices.map { Int32($0) }
        return createMDLMesh(vertices: vertices, indices: int32Indices) ?? mesh
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
        guard let submeshes = mesh.submeshes,
              submeshes.count > 0,
              let submesh = submeshes[0] as? MDLSubmesh else {
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

    // MARK: - Solidify (Manifold Shell for 3D Printing)
    /// Extrudes an open surface mesh inward along its vertex normals by `thickness`
    /// (in mesh units — meters for a raw ARKit scan) to produce a watertight, manifold
    /// solid suitable for 3D printing.
    ///
    /// The original surface becomes the outer wall; a duplicated copy offset along the
    /// inverted normals forms the inner wall; the open boundary is stitched with side
    /// walls. Face windings are chosen so every edge is shared by exactly two triangles
    /// with opposite orientation (a consistent, watertight manifold).
    func solidify(_ mesh: MDLMesh, thickness: Float) -> MDLMesh {
        guard thickness > 0 else { return mesh }

        // Weld coincident vertices by position (ModelIO's `addNormals` de-indexes meshes,
        // so without welding every edge looks like a boundary and each triangle becomes
        // its own disconnected closed box instead of part of a single shell).
        guard let (vertices, indices) = weldedGeometry(from: mesh) else {
            print("❌ Invalid mesh structure for solidify")
            return mesh
        }
        let indexCount = indices.count

        guard !vertices.isEmpty, indexCount >= 3 else {
            print("❌ Empty mesh, cannot solidify")
            return mesh
        }

        let vertexCount = vertices.count
        print("🔗 Solidify weld: \(mesh.vertexCount) → \(vertexCount) vertices")

        // 1. Per-vertex normals (area-weighted average of adjacent face normals).
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: vertexCount)
        for t in stride(from: 0, to: indices.count - 2, by: 3) {
            let a = indices[t], b = indices[t + 1], c = indices[t + 2]
            guard a < vertexCount, b < vertexCount, c < vertexCount else { continue }
            // Cross product magnitude is proportional to triangle area → area weighting.
            let faceNormal = cross(vertices[b] - vertices[a], vertices[c] - vertices[a])
            normals[a] += faceNormal
            normals[b] += faceNormal
            normals[c] += faceNormal
        }
        for i in 0..<vertexCount {
            let len = simd_length(normals[i])
            normals[i] = len > 1e-8 ? normals[i] / len : SIMD3<Float>(0, 0, 1)
        }

        // 2. Find boundary edges: an undirected edge used by exactly one triangle.
        //    Keep the directed edge as it appears in that triangle for correct stitching.
        var edgeCount = [UInt64: Int]()
        var edgeDir = [UInt64: (Int, Int)]()
        func edgeKey(_ u: Int, _ v: Int) -> UInt64 {
            let lo = UInt64(min(u, v)), hi = UInt64(max(u, v))
            return (hi << 32) | lo
        }
        func addEdge(_ u: Int, _ v: Int) {
            let k = edgeKey(u, v)
            edgeCount[k, default: 0] += 1
            if edgeDir[k] == nil { edgeDir[k] = (u, v) }
        }
        for t in stride(from: 0, to: indices.count - 2, by: 3) {
            let a = indices[t], b = indices[t + 1], c = indices[t + 2]
            addEdge(a, b); addEdge(b, c); addEdge(c, a)
        }
        var boundaryEdges = [(Int, Int)]()
        for (k, count) in edgeCount where count == 1 {
            if let dir = edgeDir[k] { boundaryEdges.append(dir) }
        }

        guard !boundaryEdges.isEmpty else {
            print("ℹ️ Mesh is already closed; nothing to solidify")
            return mesh
        }

        // 3. Build the doubled geometry.
        let n = vertexCount
        var outVertices = vertices
        outVertices.reserveCapacity(n * 2)
        for i in 0..<n {
            // Inner shell: offset inward (opposite the outward-facing normal).
            outVertices.append(vertices[i] - normals[i] * thickness)
        }

        var outIndices = [Int32]()
        outIndices.reserveCapacity(indexCount * 2 + boundaryEdges.count * 6)

        // Outer faces — original winding (outward normals).
        for t in stride(from: 0, to: indices.count - 2, by: 3) {
            outIndices.append(Int32(indices[t]))
            outIndices.append(Int32(indices[t + 1]))
            outIndices.append(Int32(indices[t + 2]))
        }
        // Inner faces — reversed winding on the offset copy (normals face the cavity).
        for t in stride(from: 0, to: indices.count - 2, by: 3) {
            let a = indices[t] + n, b = indices[t + 1] + n, c = indices[t + 2] + n
            outIndices.append(Int32(a))
            outIndices.append(Int32(c))
            outIndices.append(Int32(b))
        }
        // Side walls — stitch each boundary edge (u→v) to its offset copy (uB, vB).
        // Windings pair up with the reversed inner faces to keep every edge manifold.
        for (u, v) in boundaryEdges {
            let uB = u + n, vB = v + n
            outIndices.append(Int32(v)); outIndices.append(Int32(u)); outIndices.append(Int32(uB))
            outIndices.append(Int32(v)); outIndices.append(Int32(uB)); outIndices.append(Int32(vB))
        }

        print("🧱 Solidify: \(n) → \(outVertices.count) verts, \(indexCount / 3) → \(outIndices.count / 3) tris, \(boundaryEdges.count) boundary edges")

        return createMDLMesh(vertices: outVertices, indices: outIndices) ?? mesh
    }

    // MARK: - Helper Methods

    /// Extracts a welded, indexed triangle list from an `MDLMesh`.
    ///
    /// ModelIO's `addNormals` de-indexes meshes — it gives every triangle its own private
    /// vertex copies, so no two triangles share indices even where they share positions.
    /// This merges coincident positions back into a single shared vertex so downstream
    /// processing (smoothing, solidify) sees the correct connected topology.
    ///
    /// Returns welded vertex positions and triangle indices into that welded set.
    private func weldedGeometry(from mesh: MDLMesh) -> (vertices: [SIMD3<Float>], indices: [Int])? {
        guard let vertexBuffer = mesh.vertexBuffers.first,
              let submeshes = mesh.submeshes,
              submeshes.count > 0,
              let submesh = submeshes[0] as? MDLSubmesh else {
            return nil
        }

        let rawVertexCount = mesh.vertexCount
        let indexCount = submesh.indexCount
        guard rawVertexCount > 0, indexCount >= 3 else { return nil }

        let vertexPointer = vertexBuffer.map().bytes.assumingMemoryBound(to: SIMD3<Float>.self)
        let indexPointer = submesh.indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)

        var vertices = [SIMD3<Float>]()
        var remap = [Int](repeating: 0, count: rawVertexCount)
        var lookup = [SIMD3<Int32>: Int]()
        let quantum: Float = 1e-5  // 0.01 mm — merges exact duplicates, never distinct features
        for i in 0..<rawVertexCount {
            let v = vertexPointer[i]
            let key = SIMD3<Int32>(Int32((v.x / quantum).rounded()),
                                   Int32((v.y / quantum).rounded()),
                                   Int32((v.z / quantum).rounded()))
            if let existing = lookup[key] {
                remap[i] = existing
            } else {
                let newIndex = vertices.count
                lookup[key] = newIndex
                remap[i] = newIndex
                vertices.append(v)
            }
        }

        // Remap triangle indices onto the welded vertex set, dropping any triangle that
        // collapses to a degenerate (two shared corners) after welding.
        var indices = [Int]()
        indices.reserveCapacity(indexCount)
        for t in stride(from: 0, to: indexCount - 2, by: 3) {
            let a = remap[Int(indexPointer[t])]
            let b = remap[Int(indexPointer[t + 1])]
            let c = remap[Int(indexPointer[t + 2])]
            guard a != b, b != c, a != c else { continue }
            indices.append(a); indices.append(b); indices.append(c)
        }

        return (vertices, indices)
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
