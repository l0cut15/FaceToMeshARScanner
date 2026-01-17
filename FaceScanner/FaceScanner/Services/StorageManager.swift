//
//  StorageManager.swift
//  FaceScanner
//
//  Local storage management for face scans
//

import Foundation

class StorageManager {
    static let shared = StorageManager()

    private let scansKey = "savedScans"
    private let documentsURL = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]

    private let scansDirectoryURL: URL

    private init() {
        // Create scans directory if it doesn't exist
        scansDirectoryURL = documentsURL.appendingPathComponent(Constants.Files.scansDirectoryName)
        createScansDirectoryIfNeeded()
    }

    // MARK: - Directory Management
    private func createScansDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: scansDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: scansDirectoryURL,
                                                       withIntermediateDirectories: true,
                                                       attributes: nil)
                print("✅ Created scans directory")
            } catch {
                print("❌ Failed to create scans directory: \(error)")
            }
        }
    }

    // MARK: - Save/Load Scans
    func saveScans(_ scans: [FaceScan]) {
        // Limit to max stored scans (keep most recent)
        let scansToSave = Array(scans.sorted(by: { $0.date > $1.date })
                                     .prefix(Constants.Files.maxStoredScans))

        guard let data = try? JSONEncoder().encode(scansToSave) else {
            print("❌ Failed to encode scans")
            return
        }
        UserDefaults.standard.set(data, forKey: scansKey)
        print("✅ Saved \(scansToSave.count) scans")
    }

    func loadScans() -> [FaceScan] {
        guard let data = UserDefaults.standard.data(forKey: scansKey),
              let scans = try? JSONDecoder().decode([FaceScan].self, from: data) else {
            print("ℹ️ No saved scans found")
            return []
        }
        print("✅ Loaded \(scans.count) scans")
        return scans
    }

    func addScan(_ scan: FaceScan) {
        var scans = loadScans()
        scans.append(scan)
        saveScans(scans)
    }

    func updateScan(_ scan: FaceScan) {
        var scans = loadScans()
        if let index = scans.firstIndex(where: { $0.id == scan.id }) {
            scans[index] = scan
            saveScans(scans)
            print("✅ Updated scan: \(scan.name)")
        }
    }

    func deleteScan(_ scan: FaceScan) {
        // Delete mesh file
        if FileManager.default.fileExists(atPath: scan.meshFileURL.path) {
            do {
                try FileManager.default.removeItem(at: scan.meshFileURL)
                print("✅ Deleted mesh file")
            } catch {
                print("❌ Failed to delete mesh file: \(error)")
            }
        }

        // Remove from saved scans
        var scans = loadScans()
        scans.removeAll { $0.id == scan.id }
        saveScans(scans)
        print("✅ Deleted scan: \(scan.name)")
    }

    func deleteAllScans() {
        let scans = loadScans()
        for scan in scans {
            if FileManager.default.fileExists(atPath: scan.meshFileURL.path) {
                try? FileManager.default.removeItem(at: scan.meshFileURL)
            }
        }
        UserDefaults.standard.removeObject(forKey: scansKey)
        print("✅ Deleted all scans")
    }

    // MARK: - Mesh File Management
    func getMeshFileURL(for scanID: UUID, format: ScanSettings.ExportFormat = .stl) -> URL {
        let ext = format == .stl ? Constants.Files.stlExtension : Constants.Files.objExtension
        return scansDirectoryURL.appendingPathComponent("\(scanID.uuidString).\(ext)")
    }

    func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Storage Info
    func getTotalStorageUsed() -> Int64 {
        var totalSize: Int64 = 0

        do {
            let files = try FileManager.default.contentsOfDirectory(at: scansDirectoryURL,
                                                                    includingPropertiesForKeys: [.fileSizeKey],
                                                                    options: [])
            for file in files {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
        } catch {
            print("❌ Failed to calculate storage: \(error)")
        }

        return totalSize
    }

    func getStorageUsedString() -> String {
        let bytes = getTotalStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func getScanCount() -> Int {
        return loadScans().count
    }
}
