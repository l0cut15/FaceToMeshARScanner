//
//  Constants.swift
//  FaceScanner
//
//  App-wide constants
//

import Foundation
import SwiftUI

enum Constants {
    // MARK: - Scan Quality Thresholds
    enum ScanQuality {
        static let minDistance: Float = 0.3  // meters (30cm)
        static let maxDistance: Float = 0.5  // meters (50cm)
        static let minLightIntensity: CGFloat = 500.0  // lux
        static let targetFrameCount = 90  // ~3 seconds at 30fps
        static let maxFrameCount = 120
    }

    // MARK: - File Management
    enum Files {
        static let scansDirectoryName = "scans"
        static let stlExtension = "stl"
        static let objExtension = "obj"
        static let thumbnailSize = CGSize(width: 512, height: 512)
        static let maxStoredScans = 50
    }

    // MARK: - UI Constants
    enum UI {
        static let qualityIndicatorSize: CGFloat = 20
        static let captureButtonSize: CGFloat = 70
        static let captureButtonInnerSize: CGFloat = 60
        static let captureButtonStrokeWidth: CGFloat = 4
    }

    // MARK: - Mesh Processing
    enum Mesh {
        static let defaultScale: Float = 1.0
        static let minScale: Float = 0.5
        static let maxScale: Float = 2.0
        static let defaultSmoothingIterations = 2
        static let maxSmoothingIterations = 10
    }
}
