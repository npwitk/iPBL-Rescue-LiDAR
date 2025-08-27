//
//  View3DScansView.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 27/04/25.
//

import SwiftUI
import SceneKit

class CurrentlyDisplaying: ObservableObject {
    @Published var fileName = ""
}

struct View3DScansView: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>
    @StateObject private var viewModel = InspectViewModel()
    @StateObject private var currentlyDispalying = CurrentlyDisplaying()
    @State private var fileNames: [String] = []
    @State private var fileName = ""
    @State private var fullScreen = false
    var body: some View {
        NavigationView {
            VStack {
                ZStack {
                    HStack {
                        Button {
                            self.mode.wrappedValue.dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
                            Text("Back").foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .padding()
                    Text("List of Scans")
                }
                if fileNames.isEmpty {
                    Spacer()
                    let title = "Nothing to see here. There are no scans to display yet."
                    let subtitle = "Please go to 'Capture 3D Scan' section to scan something."
                    Text("\(title) \(subtitle)")
                        .padding()
                        .multilineTextAlignment(.center)
                    Spacer()
                } else {
                    List(fileNames, id: \.self) { fileName in
                        Button {
                            self.currentlyDispalying.fileName = fileName
                            self.fullScreen.toggle()
                        } label: {
                            Text(fileName)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeFile(fileName: fileName)
                                withAnimation {
                                    fetchFiles()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }.refreshable {
                        fetchFiles()
                    }
                    .navigationDestination(isPresented: $fullScreen) {
                        if !self.currentlyDispalying.fileName.isEmpty {
                            SceneViewWrapper(scene: displayFile(fileName: self.currentlyDispalying.fileName))
                        }
                    }
                }
            }.onAppear {
                fetchFiles()
            }
        }
    }
    func fetchFiles() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first else {
            return
        }
        let folderName = "OBJ_FILES"
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            let filteredURLs = fileURLs.filter { (url) -> Bool in
                return url.pathExtension == "obj"
            }
            self.fileNames = filteredURLs.map { $0.lastPathComponent }
        } catch {
            print("Error fetching files: \(error)")
        }
    }
    func displayFile(fileName: String) -> SCNScene {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Failed to access Document Directory")
        }
        let folderName = "OBJ_FILES"
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        let fileURL = folderURL.appendingPathComponent(fileName)
        print(fileURL)
        let sceneView = try? SCNScene(url: fileURL)
        return sceneView ?? SCNScene()
    }
    func removeFile(fileName: String) {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Failed to access Document Directory")
        }
        let folderName = "OBJ_FILES"
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        let fileURL = folderURL.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("File Removed successfully: \(fileURL)")
        } catch {
            print("Error removing file: \(error)")
        }
    }
}

#Preview {
    View3DScansView()
}
