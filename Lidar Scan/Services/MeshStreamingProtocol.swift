//
//  MeshStreamingProtocol.swift
//  Rescue Robot Sensor Head
//

import Foundation
import ARKit
import simd

// MARK: - Mesh Data Structures
struct CompressedMeshData: Codable {
    let anchorId: String
    let transform: [Float] // 4x4 matrix as 16-element array
    let vertices: CompressedVertexData
    let faces: [UInt16] // Triangle indices (compressed to 16-bit)
    let normals: CompressedVertexData?
    let classification: [UInt8]? // Surface classification data
    let timestamp: Date
    let isDelta: Bool // Whether this is a delta update or full mesh
}

struct CompressedVertexData: Codable {
    let count: Int
    let bounds: MeshBounds
    let quantizedVertices: [UInt16] // Quantized to 16-bit for compression
    
    struct MeshBounds: Codable {
        let min: [Float] // [x, y, z]
        let max: [Float] // [x, y, z]
    }
}

// MARK: - Mesh Compression Utilities
class MeshCompressionService {
    
    // Quantization resolution - higher values = better precision, larger data
    private let quantizationLevels: UInt16 = 65535
    
    func compressMeshAnchor(_ meshAnchor: ARMeshAnchor) -> CompressedMeshData? {
        let geometry = meshAnchor.geometry
        
        // Safety check for vertex count
        guard geometry.vertices.count > 0 else {
            print("⚠️ Mesh has no vertices, skipping")
            return nil
        }
        
        // Extract vertex data safely
        let vertexBufferPointer = geometry.vertices.buffer.contents().assumingMemoryBound(to: simd_float3.self)
        let vertices = Array(UnsafeBufferPointer(start: vertexBufferPointer, count: geometry.vertices.count))
        
        // Safety check for face count
        guard geometry.faces.count > 0 else {
            print("⚠️ Mesh has no faces, skipping")
            return nil
        }
        
        // Extract face data safely
        let faceBufferPointer = geometry.faces.buffer.contents().assumingMemoryBound(to: UInt32.self)
        let faces = Array(UnsafeBufferPointer(start: faceBufferPointer, count: geometry.faces.count * 3))
        
        // Compress vertices
        guard let compressedVertices = compressVertices(vertices) else {
            return nil
        }
        
        // Compress faces to 16-bit indices (assuming < 65k vertices per mesh)
        let compressedFaces = faces.compactMap { UInt16(exactly: $0) }
        guard compressedFaces.count == faces.count else {
            print("⚠️ Mesh too large for 16-bit indices, skipping")
            return nil
        }
        
        // Extract normals if available with additional safety checks
        var compressedNormals: CompressedVertexData?
        if geometry.normals.count > 0 && 
           geometry.normals.count < 100000 &&
           geometry.normals.buffer.length >= geometry.normals.count * MemoryLayout<simd_float3>.size {
            
            // Safely access the normals buffer with validation
            let normalBufferPointer = geometry.normals.buffer.contents().assumingMemoryBound(to: simd_float3.self)
            let normals = Array(UnsafeBufferPointer(start: normalBufferPointer, count: geometry.normals.count))
            compressedNormals = compressVertices(normals)
        }
        
        // Extract classification if available (skip if problematic to avoid crashes)
        var classification: [UInt8]?
        if let classificationSource = geometry.classification, 
           classificationSource.count > 0 && 
           classificationSource.count < 100000,
           classificationSource.buffer.length >= classificationSource.count * MemoryLayout<ARMeshClassification>.size {
            
            // Safely access the buffer with additional validation
            let classificationBufferPointer = classificationSource.buffer.contents().assumingMemoryBound(to: ARMeshClassification.self)
            let classificationArray = Array(UnsafeBufferPointer(start: classificationBufferPointer, count: classificationSource.count))
            
            // Safely convert each classification value
            classification = classificationArray.compactMap { (classification: ARMeshClassification) -> UInt8? in 
                let rawValue = classification.rawValue
                
                // Clamp to UInt8 range (0-255) and handle invalid values
                if rawValue < 0 {
                    return 0
                } else if rawValue > 255 {
                    // Log large values for debugging
                    print("⚠️ Large classification value: \(rawValue), clamping to 255")
                    return 255
                } else {
                    return UInt8(rawValue)
                }
            }
            
            // If we lost too many values during conversion, skip classification entirely
            if classification?.count != classificationArray.count {
                print("⚠️ Some classification values were invalid, skipping classification data")
                classification = nil
            }
        }
        
        // Convert transform matrix to array
        let transform = meshAnchor.transform
        let transformArray: [Float] = [
            transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w,
            transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w,
            transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
            transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w
        ]
        
        return CompressedMeshData(
            anchorId: meshAnchor.identifier.uuidString,
            transform: transformArray,
            vertices: compressedVertices,
            faces: compressedFaces,
            normals: compressedNormals,
            classification: classification,
            timestamp: Date(),
            isDelta: false
        )
    }
    
    private func compressVertices(_ vertices: [simd_float3]) -> CompressedVertexData? {
        guard !vertices.isEmpty else { return nil }
        
        // Calculate bounding box with NaN/Infinity checks
        var minBounds = vertices[0]
        var maxBounds = vertices[0]
        
        // Check first vertex for NaN/Infinity
        guard !minBounds.x.isNaN && !minBounds.y.isNaN && !minBounds.z.isNaN &&
              !minBounds.x.isInfinite && !minBounds.y.isInfinite && !minBounds.z.isInfinite else {
            print("⚠️ First vertex contains NaN/Infinity, skipping mesh")
            return nil
        }
        
        for vertex in vertices {
            // Skip vertices with NaN/Infinity
            guard !vertex.x.isNaN && !vertex.y.isNaN && !vertex.z.isNaN &&
                  !vertex.x.isInfinite && !vertex.y.isInfinite && !vertex.z.isInfinite else {
                print("⚠️ Vertex contains NaN/Infinity: \(vertex), skipping")
                continue
            }
            
            minBounds = simd_min(minBounds, vertex)
            maxBounds = simd_max(maxBounds, vertex)
        }
        
        let bounds = CompressedVertexData.MeshBounds(
            min: [minBounds.x, minBounds.y, minBounds.z],
            max: [maxBounds.x, maxBounds.y, maxBounds.z]
        )
        
        // Quantize vertices to 16-bit range
        let range = maxBounds - minBounds
        
        // Safety check for zero range (all vertices at same position)
        let safeRange = simd_float3(
            range.x == 0 ? 1.0 : range.x,
            range.y == 0 ? 1.0 : range.y,
            range.z == 0 ? 1.0 : range.z
        )
        
        let quantizedVertices = vertices.flatMap { vertex in
            let normalized = (vertex - minBounds) / safeRange
            let quantized = normalized * Float(quantizationLevels)
            
            // Clamp to valid ranges and check for NaN/Infinity
            let safeQuantizedX = quantized.x.isNaN || quantized.x.isInfinite ? 0.0 : quantized.x.clamped(to: 0...Float(quantizationLevels))
            let safeQuantizedY = quantized.y.isNaN || quantized.y.isInfinite ? 0.0 : quantized.y.clamped(to: 0...Float(quantizationLevels))
            let safeQuantizedZ = quantized.z.isNaN || quantized.z.isInfinite ? 0.0 : quantized.z.clamped(to: 0...Float(quantizationLevels))
            
            return [
                UInt16(Int(safeQuantizedX)),
                UInt16(Int(safeQuantizedY)),
                UInt16(Int(safeQuantizedZ))
            ]
        }
        
        return CompressedVertexData(
            count: vertices.count,
            bounds: bounds,
            quantizedVertices: quantizedVertices
        )
    }
    
    func decompressVertices(_ compressedData: CompressedVertexData) -> [simd_float3] {
        let minBounds = simd_float3(
            compressedData.bounds.min[0],
            compressedData.bounds.min[1],
            compressedData.bounds.min[2]
        )
        
        let maxBounds = simd_float3(
            compressedData.bounds.max[0],
            compressedData.bounds.max[1],
            compressedData.bounds.max[2]
        )
        
        let range = maxBounds - minBounds
        
        var vertices: [simd_float3] = []
        
        for i in stride(from: 0, to: compressedData.quantizedVertices.count, by: 3) {
            let quantizedX = Float(compressedData.quantizedVertices[i]) / Float(quantizationLevels)
            let quantizedY = Float(compressedData.quantizedVertices[i + 1]) / Float(quantizationLevels)
            let quantizedZ = Float(compressedData.quantizedVertices[i + 2]) / Float(quantizationLevels)
            
            let vertex = simd_float3(quantizedX, quantizedY, quantizedZ) * range + minBounds
            vertices.append(vertex)
        }
        
        return vertices
    }
}

// MARK: - Streaming Configuration
struct StreamingConfiguration {
    // Update frequencies
    let robotPositionHz: Double = 30.0 // 30 FPS for robot position
    let meshUpdateHz: Double = 2.0 // 2 FPS for mesh updates (heavy data)
    let detectionUpdateHz: Double = 10.0 // 10 FPS for person detections
    
    // Data transmission limits
    let maxMeshVerticesPerFrame: Int = 10000
    let maxSimultaneousMeshAnchors: Int = 10
    
    // Network optimization
    let compressionEnabled: Bool = true
    let deltaUpdatesEnabled: Bool = true
    
    var robotPositionInterval: TimeInterval { 1.0 / robotPositionHz }
    var meshUpdateInterval: TimeInterval { 1.0 / meshUpdateHz }
    var detectionUpdateInterval: TimeInterval { 1.0 / detectionUpdateHz }
}

// MARK: - Streaming Statistics
class StreamingStats: ObservableObject {
    @Published var totalBytesSent: UInt64 = 0
    @Published var messagesPerSecond: Double = 0
    @Published var averageCompressionRatio: Double = 0
    @Published var networkLatency: TimeInterval = 0
    
    private var messageCount: Int = 0
    private var lastStatsUpdate = Date()
    private var compressionRatios: [Double] = []
    
    func recordMessage(originalSize: Int, compressedSize: Int) {
        messageCount += 1
        totalBytesSent += UInt64(compressedSize)
        
        let compressionRatio = Double(originalSize) / Double(compressedSize)
        compressionRatios.append(compressionRatio)
        
        // Keep only recent compression ratios
        if compressionRatios.count > 100 {
            compressionRatios.removeFirst(compressionRatios.count - 100)
        }
        
        updateStats()
    }
    
    private func updateStats() {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastStatsUpdate)
        
        if timeDiff >= 1.0 { // Update every second
            messagesPerSecond = Double(messageCount) / timeDiff
            
            if !compressionRatios.isEmpty {
                averageCompressionRatio = compressionRatios.reduce(0, +) / Double(compressionRatios.count)
            }
            
            messageCount = 0
            lastStatsUpdate = now
        }
    }
    
    func reset() {
        totalBytesSent = 0
        messagesPerSecond = 0
        averageCompressionRatio = 0
        networkLatency = 0
        messageCount = 0
        compressionRatios.removeAll()
        lastStatsUpdate = Date()
    }
}

// MARK: - Float Extensions
extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
