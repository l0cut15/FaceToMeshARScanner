//
//  ScanSettings.swift
//  FaceScanner
//
//  Configuration settings for face scanning
//

import Foundation

struct ScanSettings: Codable {
    var exportFormat: ExportFormat = .stl
    var quality: Quality = .medium
    var scale: Float = 1.0
    var smoothingIterations: Int = 8

    /// When true, the open scan surface is extruded into a watertight, 3D-printable solid on export.
    var makeSolid: Bool = false
    /// Wall thickness of the solid shell, in millimeters at life-size.
    var solidThicknessMM: Float = 3.0

    enum ExportFormat: String, Codable {
        case stl = "STL"
        case obj = "OBJ"
    }

    enum Quality: String, Codable {
        case low = "Low (5K vertices)"
        case medium = "Medium (10K vertices)"
        case high = "High (20K vertices)"

        var targetVertexCount: Int {
            switch self {
            case .low: return 5000
            case .medium: return 10000
            case .high: return 20000
            }
        }
    }
}

// MARK: - Backward-compatible decoding
// Defined in an extension so the synthesized memberwise initializer is preserved.
// Older saved scans predate `makeSolid`/`solidThicknessMM`, so decode those leniently.
extension ScanSettings {
    enum CodingKeys: String, CodingKey {
        case exportFormat, quality, scale, smoothingIterations, makeSolid, solidThicknessMM
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exportFormat = try c.decodeIfPresent(ExportFormat.self, forKey: .exportFormat) ?? .stl
        quality = try c.decodeIfPresent(Quality.self, forKey: .quality) ?? .medium
        scale = try c.decodeIfPresent(Float.self, forKey: .scale) ?? 1.0
        smoothingIterations = try c.decodeIfPresent(Int.self, forKey: .smoothingIterations) ?? 8
        makeSolid = try c.decodeIfPresent(Bool.self, forKey: .makeSolid) ?? false
        solidThicknessMM = try c.decodeIfPresent(Float.self, forKey: .solidThicknessMM) ?? 3.0
    }
}
