//
//  Extensions.swift
//  FaceScanner
//
//  Helper extensions for type conversions and utilities
//

import Foundation
import simd
import SceneKit

// MARK: - SIMD3 Extensions
extension SIMD3<Float> {
    static func +(lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func +=(lhs: inout SIMD3<Float>, rhs: SIMD3<Float>) {
        lhs = lhs + rhs
    }

    static func -(lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func /(lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        return SIMD3<Float>(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }

    static func /=(lhs: inout SIMD3<Float>, rhs: Float) {
        lhs = lhs / rhs
    }
}

// MARK: - SIMD3 to SCNVector3 Conversion
extension SIMD3 where Scalar == Float {
    var scnVector: SCNVector3 {
        return SCNVector3(x, y, z)
    }
}

// MARK: - SCNVector3 to SIMD3 Conversion
extension SCNVector3 {
    var simd: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

// MARK: - Date Formatting
extension Date {
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    func formattedShort() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - URL Extensions
extension URL {
    var isSTL: Bool {
        return pathExtension.lowercased() == Constants.Files.stlExtension
    }

    var isOBJ: Bool {
        return pathExtension.lowercased() == Constants.Files.objExtension
    }
}
