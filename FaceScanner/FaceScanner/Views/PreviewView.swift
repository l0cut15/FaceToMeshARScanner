//
//  PreviewView.swift
//  FaceScanner
//
//  3D mesh viewer with rotation, zoom, and export options
//

import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ModelIO

struct PreviewView: View {
    let mesh: MDLMesh
    let onDismiss: () -> Void

    @State private var scanName = "Face Scan"
    @State private var showingSaveDialog = false
    @State private var showingShareSheet = false
    @State private var showingEditView = false
    @State private var exportedURL: URL?
    @State private var isSaving = false
    @State private var saveError: String?

    @State private var settings = ScanSettings()

    private let meshProcessor = MeshProcessor()
    private let fileExporter = FileExporter()

    var body: some View {
        NavigationStack {
            ZStack {
                // 3D Scene View
                SceneViewContainer(mesh: mesh)
                    .ignoresSafeArea()

                // Bottom controls
                VStack {
                    Spacer()

                    // Action buttons
                    HStack(spacing: 20) {
                        // Edit button
                        ActionButton(
                            icon: "slider.horizontal.3",
                            label: "Edit"
                        ) {
                            showingEditView = true
                        }

                        // Save button
                        ActionButton(
                            icon: "square.and.arrow.down",
                            label: "Save"
                        ) {
                            showingSaveDialog = true
                        }

                        // Share button
                        ActionButton(
                            icon: "square.and.arrow.up",
                            label: "Share"
                        ) {
                            exportAndShare()
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .alert("Save Scan", isPresented: $showingSaveDialog) {
                TextField("Scan name", text: $scanName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    saveScan()
                }
            } message: {
                Text("Enter a name for this scan")
            }
            .alert("Error", isPresented: .init(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError ?? "An error occurred")
            }
            .sheet(isPresented: $showingEditView) {
                EditView(mesh: mesh, settings: $settings)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }

    private func saveScan() {
        isSaving = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Process mesh with current settings
            var processedMesh = mesh
            if settings.smoothingIterations > 0 {
                processedMesh = meshProcessor.smoothMesh(processedMesh, iterations: settings.smoothingIterations)
            }
            if settings.scale != 1.0 {
                processedMesh = meshProcessor.scaleMesh(processedMesh, scale: settings.scale)
            }

            // Export to file
            let scanID = UUID()
            let filename = scanID.uuidString

            var exportURL: URL?
            switch settings.exportFormat {
            case .stl:
                exportURL = fileExporter.exportAsSTL(processedMesh, filename: filename)
            case .obj:
                exportURL = fileExporter.exportAsOBJ(processedMesh, filename: filename)
            }

            guard let meshURL = exportURL else {
                DispatchQueue.main.async {
                    isSaving = false
                    saveError = "Failed to export mesh"
                }
                return
            }

            // Create scan record
            let scan = FaceScan(
                name: scanName.isEmpty ? "Face Scan" : scanName,
                meshFileURL: meshURL,
                vertexCount: processedMesh.vertexCount,
                settings: settings
            )

            // Save to storage
            StorageManager.shared.addScan(scan)

            DispatchQueue.main.async {
                isSaving = false
                onDismiss()
            }
        }
    }

    private func exportAndShare() {
        isSaving = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Process and export mesh
            var processedMesh = mesh
            if settings.smoothingIterations > 0 {
                processedMesh = meshProcessor.smoothMesh(processedMesh, iterations: settings.smoothingIterations)
            }

            let filename = "FaceScan_\(Date().ISO8601Format())"
            let url = fileExporter.exportAsSTL(processedMesh, filename: filename)

            DispatchQueue.main.async {
                isSaving = false
                if let url = url {
                    exportedURL = url
                    showingShareSheet = true
                } else {
                    saveError = "Failed to export mesh for sharing"
                }
            }
        }
    }
}

// MARK: - Scene View Container
struct SceneViewContainer: UIViewRepresentable {
    let mesh: MDLMesh

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = createScene()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = UIColor.darkGray

        // Set default camera position
        scnView.pointOfView?.position = SCNVector3(0, 0, 0.5)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Scene updates if needed
    }

    private func createScene() -> SCNScene {
        let scene = SCNScene()

        // Convert MDLMesh to SCNNode via MDLAsset
        let asset = MDLAsset()
        asset.add(mesh)

        let scnScene = SCNScene(mdlAsset: asset)

        // Get the mesh node from converted scene and apply material
        if let meshNode = scnScene.rootNode.childNodes.first {
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.lightGray
            material.specular.contents = UIColor.white
            material.shininess = 0.2
            material.lightingModel = .physicallyBased
            meshNode.geometry?.materials = [material]

            scene.rootNode.addChildNode(meshNode.clone())
        }

        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 0.5)
        scene.rootNode.addChildNode(cameraNode)

        // Add key light
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.position = SCNVector3(0, 5, 10)
        keyLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLight)

        // Add fill light
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 400
        fillLight.position = SCNVector3(-5, 0, 5)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)

        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 300
        scene.rootNode.addChildNode(ambientLight)

        return scene
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(.primary)
            .frame(width: 70, height: 60)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

#Preview {
    // Preview with placeholder
    Text("Preview requires mesh data")
}
