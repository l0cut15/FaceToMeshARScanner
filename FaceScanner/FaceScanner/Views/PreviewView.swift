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
                if mesh.vertexCount > 0 {
                    SceneViewContainer(mesh: mesh)
                        .ignoresSafeArea()
                } else {
                    // Show error if mesh is empty
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("No Mesh Data")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("The captured mesh has no vertices. Please try scanning again.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }

                // Bottom controls
                VStack {
                    // Instruction hint at top
                    if mesh.vertexCount > 0 {
                        HStack {
                            Image(systemName: "hand.draw")
                                .font(.caption)
                            Text("Drag to rotate • Pinch to zoom")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.top, 60)
                    }
                    
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
        print("🎨 Creating SCNView for mesh preview...")
        print("   Mesh vertices: \(mesh.vertexCount)")
        
        let scnView = SCNView()
        scnView.scene = createScene()
        scnView.allowsCameraControl = true
        
        // Use auto lighting as fallback + our custom lights
        scnView.autoenablesDefaultLighting = true
        
        // Lighter background for better visibility
        scnView.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        
        // Show statistics for debugging
        scnView.showsStatistics = true
        
        // Anti-aliasing for smoother edges
        scnView.antialiasingMode = .multisampling4X

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Scene updates if needed
    }

    private func createScene() -> SCNScene {
        let scene = SCNScene()
        
        print("🎬 Creating scene from mesh...")

        // Convert MDLMesh to SCNNode via MDLAsset
        let asset = MDLAsset()
        asset.add(mesh)

        let scnScene = SCNScene(mdlAsset: asset)

        // Get the mesh node from converted scene and apply material
        if let meshNode = scnScene.rootNode.childNodes.first {
            print("✅ Mesh node found!")
            
            // Calculate bounding box to position camera properly
            let (min, max) = meshNode.boundingBox
            let center = SCNVector3(
                (min.x + max.x) / 2,
                (min.y + max.y) / 2,
                (min.z + max.z) / 2
            )
            let size = SCNVector3(
                max.x - min.x,
                max.y - min.y,
                max.z - min.z
            )
            
            print("   Bounding box center: (\(center.x), \(center.y), \(center.z))")
            print("   Bounding box size: (\(size.x), \(size.y), \(size.z))")
            
            // Create simple, visible material
            let material = SCNMaterial()
            
            // Bright diffuse color so it's definitely visible
            material.diffuse.contents = UIColor(red: 0.85, green: 0.75, blue: 0.65, alpha: 1.0)
            
            // Simple Phong lighting (most compatible)
            material.lightingModel = .phong
            
            // Moderate specular for some shine
            material.specular.contents = UIColor(white: 0.3, alpha: 1.0)
            material.shininess = 20
            
            // Ensure it renders from both sides
            material.isDoubleSided = true
            
            // Make sure it's not transparent
            material.transparency = 1.0
            material.transparencyMode = .default
            
            meshNode.geometry?.materials = [material]

            scene.rootNode.addChildNode(meshNode)
            print("✅ Mesh added to scene with visible material")
        } else {
            print("❌ No mesh node found in converted scene!")
        }

        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 0, 0.4) // Closer to face
        scene.rootNode.addChildNode(cameraNode)

        scene.rootNode.addChildNode(cameraNode)

        // Simplified, brighter lighting setup
        
        // Main directional light from front-top
        let mainLight = SCNNode()
        mainLight.light = SCNLight()
        mainLight.light?.type = .directional
        mainLight.light?.intensity = 2000 // Much brighter
        mainLight.light?.color = UIColor.white
        mainLight.light?.castsShadow = false // Disable shadows for now
        mainLight.position = SCNVector3(0, 2, 2)
        mainLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(mainLight)

        // Strong ambient light for overall brightness
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 800 // Much brighter
        ambientLight.light?.color = UIColor.white
        scene.rootNode.addChildNode(ambientLight)
        
        // Add omni light near camera for extra illumination
        let cameraLight = SCNNode()
        cameraLight.light = SCNLight()
        cameraLight.light?.type = .omni
        cameraLight.light?.intensity = 1500
        cameraLight.light?.color = UIColor.white
        cameraLight.position = SCNVector3(0, 0, 0.3)
        scene.rootNode.addChildNode(cameraLight)
        
        print("✅ Scene setup complete with bright lighting")

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
