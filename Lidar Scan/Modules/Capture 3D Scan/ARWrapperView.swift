//
//  ARWrapperView.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 27/04/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ARWrapperView: UIViewRepresentable {
    @Binding var submittedExportRequest: Bool
    @Binding var submittedName: String
    @Binding var pauseSession: Bool
    let arView = ARView(frame: .zero)
    func makeUIView(context: Context) -> ARView {
        return arView
    }
    func updateUIView(_ uiView: ARView, context: Context) {
        let viewModel = ExportViewModel()
        setARViewOptions(arView)
        let configuration = buildConfigure()
        if submittedExportRequest {
            guard let camera = arView.session.currentFrame?.camera else { return }
            if let meshAnchors = arView.session.currentFrame?.anchors.compactMap( { $0 as? ARMeshAnchor }),
               let asset = viewModel.convertToAsset(meshAnchor: meshAnchors, camera: camera) {
                do {
                    try ExportViewModel().export(asset: asset, fileName: submittedName)
                } catch {
                    print("Export Failed")
                }
            }
        }
        if pauseSession {
            arView.session.pause()
        } else {
            arView.session.run(configuration)
        }
    }
    private func buildConfigure() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        arView.automaticallyConfigureSession = false
        configuration.sceneReconstruction = .meshWithClassification
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        return configuration
    }
    private func setARViewOptions(_ arView: ARView) {
        arView.debugOptions.insert(.showSceneUnderstanding)
    }
}

class ExportViewModel: NSObject, ObservableObject, ARSessionDelegate {
    func convertToAsset(meshAnchor: [ARMeshAnchor], camera: ARCamera) -> MDLAsset? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil}
        let asset = MDLAsset()
        for anchor in meshAnchor {
            let mdlMesh = anchor.geometry.toMDLMesh(device: device, camera: camera, modelMatrix: anchor.transform)
            asset.add(mdlMesh)
        }
        return asset
    }
    func export(asset: MDLAsset, fileName: String) throws {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "com.original.creatingLidarModel", code: 153)
        }
        let folderName = "OBJ_FILES"
        let folderURL = directory.appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        let url = folderURL.appendingPathComponent("\(fileName.isEmpty ? UUID().uuidString : fileName).obj")
        do {
            try asset.export(to: url)
            print("Object saved successfully at \(url)")
        } catch {
            print(error)
        }
    }
}
