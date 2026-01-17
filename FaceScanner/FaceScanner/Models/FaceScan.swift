//
//  FaceScan.swift
//  FaceScanner
//
//  Data model for storing face scan information
//

import Foundation

struct FaceScan: Identifiable, Codable {
    let id: UUID
    var name: String
    let date: Date
    let meshFileURL: URL
    var thumbnailData: Data?
    let vertexCount: Int
    let settings: ScanSettings

    init(name: String = "Face Scan",
         meshFileURL: URL,
         vertexCount: Int,
         settings: ScanSettings = ScanSettings()) {
        self.id = UUID()
        self.name = name
        self.date = Date()
        self.meshFileURL = meshFileURL
        self.vertexCount = vertexCount
        self.settings = settings
    }
}
