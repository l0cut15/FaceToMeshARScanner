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
    var smoothingIterations: Int = 2

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
