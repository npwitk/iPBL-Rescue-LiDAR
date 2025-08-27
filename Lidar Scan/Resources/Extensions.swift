//
//  Extensions.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 27/04/25.
//

import SwiftUI
import ARKit
import MetalKit
import RealityKit

extension View {
    func alertView(title: String,
                   message: String,
                   hintText: String,
                   primaryAction: @escaping (String) -> Void,
                   secondaryAction: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = hintText
        }
        alert.addAction(.init(title: "Cancel", style: .cancel, handler: { _ in
            secondaryAction()
        }))
        alert.addAction(.init(title: "Save", style: .default, handler: { _ in
            if let text = alert.textFields?[0].text {
                primaryAction(text)
            } else {
                primaryAction("")
            }
        }))
        // presenting alert
        rootController().present(alert, animated: true, completion: nil)
    }
    func rootController() -> UIViewController {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .init()
        }
        guard let root = screen.windows.first?.rootViewController else {
            return .init()
        }
        return root
    }
}

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
    func toMDLMesh(device: MTLDevice, camera: ARCamera, modelMatrix: simd_float4x4) -> MDLMesh {
        func convertVertexLocalToWorld() {
            let verticesPointer = vertices.buffer.contents()
            for vertexIndex in 0..<vertices.count {
                let vertex = self.vertex(at: UInt32(vertexIndex))
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.x, y: vertex.y, z: vertex.z, w: 1)
                let vertexWorldPosition = (modelMatrix * vertexLocalTransform).columns.3
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x,
                                           toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y,
                                           toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z,
                                           toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
            }
        }
        convertVertexLocalToWorld()
        let allocator = MTKMeshBufferAllocator(device: device)
        let data = Data.init(bytes: vertices.buffer.contents(),
                             count: vertices.stride * vertices.count)
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)
        let indexData = Data.init(bytes: faces.buffer.contents(),
                                  count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: faces.count * faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: nil)
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride)
        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                           vertexCount: vertices.count,
                           descriptor: vertexDescriptor,
                           submeshes: [submesh])
        return mesh
    }
}
