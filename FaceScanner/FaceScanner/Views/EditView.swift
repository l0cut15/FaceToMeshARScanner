//
//  EditView.swift
//  FaceScanner
//
//  Editing controls for mesh processing settings
//

import SwiftUI
import ModelIO

struct EditView: View {
    let mesh: MDLMesh
    @Binding var settings: ScanSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Export Format Section
                Section("Export Format") {
                    Picker("Format", selection: $settings.exportFormat) {
                        Text("STL (Binary)").tag(ScanSettings.ExportFormat.stl)
                        Text("OBJ (ASCII)").tag(ScanSettings.ExportFormat.obj)
                    }
                    .pickerStyle(.segmented)

                    Text(formatDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Quality Settings Section
                Section("Quality") {
                    Picker("Resolution", selection: $settings.quality) {
                        ForEach([ScanSettings.Quality.low, .medium, .high], id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }

                    HStack {
                        Text("Current vertices")
                        Spacer()
                        Text("\(mesh.vertexCount)")
                            .foregroundColor(.secondary)
                    }
                }

                // Smoothing Section
                Section("Smoothing") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Iterations: \(settings.smoothingIterations)")
                            Spacer()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settings.smoothingIterations) },
                                set: { settings.smoothingIterations = Int($0) }
                            ),
                            in: 0...Double(Constants.Mesh.maxSmoothingIterations),
                            step: 1
                        )
                    }

                    Text("Higher values produce smoother surfaces but may lose detail")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Scale Section
                Section("Scale") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scale: \(String(format: "%.1fx", settings.scale))")
                            Spacer()
                        }

                        Slider(
                            value: $settings.scale,
                            in: Constants.Mesh.minScale...Constants.Mesh.maxScale,
                            step: 0.1
                        )

                        HStack {
                            Text("\(String(format: "%.1fx", Constants.Mesh.minScale))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1fx", Constants.Mesh.maxScale))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Adjust the scale for 3D printing. 1.0x is life-size.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Reset Section
                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Edit Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formatDescription: String {
        switch settings.exportFormat {
        case .stl:
            return "Binary STL is widely compatible with 3D printers and slicer software."
        case .obj:
            return "OBJ format is better for 3D modeling software like Blender."
        }
    }

    private func resetToDefaults() {
        settings.exportFormat = .stl
        settings.quality = .medium
        settings.scale = Constants.Mesh.defaultScale
        settings.smoothingIterations = Constants.Mesh.defaultSmoothingIterations
    }
}

#Preview {
    EditView(
        mesh: MDLMesh(),
        settings: .constant(ScanSettings())
    )
}
