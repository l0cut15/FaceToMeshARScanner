//
//  HistoryView.swift
//  FaceScanner
//
//  Grid layout of saved face scans
//

import SwiftUI
import ModelIO
import MetalKit

struct HistoryView: View {
    @State private var scans: [FaceScan] = []
    @State private var selectedScan: FaceScan?
    @State private var showingDeleteAlert = false
    @State private var scanToDelete: FaceScan?
    @State private var showingShareSheet = false
    @State private var shareURL: URL?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(scans) { scan in
                                ScanCard(scan: scan)
                                    .onTapGesture {
                                        selectedScan = scan
                                    }
                                    .contextMenu {
                                        Button {
                                            shareScan(scan)
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }

                                        Button(role: .destructive) {
                                            scanToDelete = scan
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !scans.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                scanToDelete = nil
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                loadScans()
            }
            .refreshable {
                loadScans()
            }
            .alert("Delete Scan", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let scan = scanToDelete {
                        deleteScan(scan)
                    } else {
                        deleteAllScans()
                    }
                }
            } message: {
                if scanToDelete != nil {
                    Text("Are you sure you want to delete this scan?")
                } else {
                    Text("Are you sure you want to delete all scans? This cannot be undone.")
                }
            }
            .sheet(item: $selectedScan) { scan in
                ScanDetailView(scan: scan) {
                    loadScans()
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func loadScans() {
        scans = StorageManager.shared.loadScans().sorted(by: { $0.date > $1.date })
    }

    private func deleteScan(_ scan: FaceScan) {
        StorageManager.shared.deleteScan(scan)
        loadScans()
    }

    private func deleteAllScans() {
        StorageManager.shared.deleteAllScans()
        loadScans()
    }

    private func shareScan(_ scan: FaceScan) {
        if StorageManager.shared.fileExists(at: scan.meshFileURL) {
            shareURL = scan.meshFileURL
            showingShareSheet = true
        }
    }
}

// MARK: - Scan Card
struct ScanCard: View {
    let scan: FaceScan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))

                if let thumbnailData = scan.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(scan.date.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "cube")
                        .font(.caption2)
                    Text("\(scan.vertexCount) vertices")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text("No Scans Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your face scans will appear here.\nTap the Scan tab to create your first scan.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - Scan Detail View
struct ScanDetailView: View {
    let scan: FaceScan
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedName: String
    @State private var showingShareSheet = false
    @State private var mesh: MDLMesh?

    init(scan: FaceScan, onDismiss: @escaping () -> Void) {
        self.scan = scan
        self.onDismiss = onDismiss
        _editedName = State(initialValue: scan.name)
    }

    var body: some View {
        NavigationStack {
            VStack {
                // 3D Preview
                if let mesh = mesh {
                    SceneViewContainer(mesh: mesh)
                        .frame(height: 300)
                        .cornerRadius(12)
                        .padding()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                        ProgressView()
                    }
                    .frame(height: 300)
                    .padding()
                }

                // Scan Info
                Form {
                    Section("Details") {
                        TextField("Name", text: $editedName)
                            .onSubmit {
                                updateScanName()
                            }

                        LabeledContent("Date", value: scan.date.formatted())
                        LabeledContent("Vertices", value: "\(scan.vertexCount)")
                        LabeledContent("Format", value: scan.settings.exportFormat.rawValue)
                        LabeledContent("Scale", value: String(format: "%.1fx", scan.settings.scale))
                    }

                    Section {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Export & Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        updateScanName()
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadMesh()
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [scan.meshFileURL])
            }
        }
    }

    private func loadMesh() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let device = MTLCreateSystemDefaultDevice() else { return }

            let allocator = MTKMeshBufferAllocator(device: device)
            let asset = MDLAsset(url: scan.meshFileURL,
                               vertexDescriptor: nil,
                               bufferAllocator: allocator)

            if let loadedMesh = asset.childObjects(of: MDLMesh.self).first as? MDLMesh {
                DispatchQueue.main.async {
                    mesh = loadedMesh
                }
            }
        }
    }

    private func updateScanName() {
        guard editedName != scan.name else { return }
        var updatedScan = scan
        updatedScan.name = editedName
        StorageManager.shared.updateScan(updatedScan)
    }
}

#Preview {
    HistoryView()
}
