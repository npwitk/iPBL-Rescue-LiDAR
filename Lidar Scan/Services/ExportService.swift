//
//  ExportService.swift
//  Rescue Robot Sensor Head
//

import Foundation
import ARKit
import UniformTypeIdentifiers
import UIKit

class ExportService: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Float = 0.0
    
    private weak var arMapper: ARMapper?
    
    func configure(with arMapper: ARMapper) {
        self.arMapper = arMapper
    }
    
    // MARK: - JSON Export
    func exportDetectionsAsJSON(_ pins: [PersonPin]) async throws -> URL {
        isExporting = true
        exportProgress = 0.1
        
        let detections = pins.map { DetectionExport(from: $0) }
        let exportData = DetectionExportData(
            exportDate: Date(),
            totalDetections: detections.count,
            detections: detections,
            metadata: ExportMetadata()
        )
        
        exportProgress = 0.5
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(exportData)
        let url = try saveToDocuments(data: data, filename: "detections_\(dateString()).json")
        
        exportProgress = 1.0
        isExporting = false
        
        return url
    }
    
    // MARK: - World Map Export
    func exportWorldMap() async throws -> URL? {
        guard let arMapper = arMapper else {
            throw ExportError.arMapperNotAvailable
        }
        
        isExporting = true
        exportProgress = 0.1
        
        guard let worldMap = await arMapper.exportWorldMap() else {
            isExporting = false
            throw ExportError.worldMapNotAvailable
        }
        
        exportProgress = 0.5
        
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        let url = try saveToDocuments(data: data, filename: "worldmap_\(dateString()).arworldmap")
        
        exportProgress = 1.0
        isExporting = false
        
        return url
    }
    
    // MARK: - USDZ Export (placeholder)
    func exportAsUSDZ(_ pins: [PersonPin]) async throws -> URL {
        isExporting = true
        exportProgress = 0.1
        
        // In a real implementation, this would create a USDZ file with the 3D scene
        // For now, we'll create a placeholder file
        var usdzContent = """
        #usda 1.0
        (
            defaultPrim = "Scene"
            metersPerUnit = 1
            upAxis = "Y"
        )
        
        def Xform "Scene"
        {
        """
        
        exportProgress = 0.5
        
        for (index, pin) in pins.enumerated() {
            let pinUSD = """
                def Sphere "Pin_\(index)"
                {
                    double3 xformOp:translate = (\(pin.worldPosition.x), \(pin.worldPosition.y), \(pin.worldPosition.z))
                    uniform token[] xformOpOrder = ["xformOp:translate"]
                    double radius = 0.1
                    color3f[] primvars:displayColor = [(\(pin.stability == .corroborated ? "1, 0, 0" : pin.stability == .multiFrame ? "1, 0.5, 0" : "1, 1, 0"))]
                }
            
            """
            usdzContent += pinUSD
        }
        
        usdzContent += "}"
        
        exportProgress = 0.8
        
        let data = usdzContent.data(using: .utf8)!
        let url = try saveToDocuments(data: data, filename: "detections_\(dateString()).usd")
        
        exportProgress = 1.0
        isExporting = false
        
        return url
    }
    
    // MARK: - Summary Export
    func exportSummary(_ pins: [PersonPin]) async throws -> URL {
        isExporting = true
        exportProgress = 0.1
        
        let summary = generateSummaryReport(pins)
        let data = summary.data(using: .utf8)!
        let url = try saveToDocuments(data: data, filename: "summary_\(dateString()).txt")
        
        exportProgress = 1.0
        isExporting = false
        
        return url
    }
    
    // MARK: - Helper Methods
    private func saveToDocuments(data: Data, filename: String) throws -> URL {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExportError.documentsDirectoryNotFound
        }
        
        let exportFolder = documentsPath.appendingPathComponent("Exports")
        
        // Create exports directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: exportFolder.path) {
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        }
        
        let fileURL = exportFolder.appendingPathComponent(filename)
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    private func generateSummaryReport(_ pins: [PersonPin]) -> String {
        let activeCount = pins.filter { !$0.isStale }.count
        let staleCount = pins.filter { $0.isStale }.count
        let stabilityDistribution = pins.reduce(into: [PinStability: Int]()) { dict, pin in
            dict[pin.stability, default: 0] += 1
        }
        let avgConfidence = pins.isEmpty ? 0 : pins.map { $0.confidence }.reduce(0, +) / Float(pins.count)
        let totalDetectionEvents = pins.reduce(0) { $0 + $1.detectionHistory.count }
        
        return """
        RESCUE ROBOT DETECTION SUMMARY
        ==============================
        
        Export Date: \(Date())
        
        OVERVIEW:
        - Total Pins: \(pins.count)
        - Active Pins: \(activeCount)
        - Stale Pins: \(staleCount)
        - Total Detection Events: \(totalDetectionEvents)
        - Average Confidence: \(String(format: "%.1f", avgConfidence * 100))%
        
        STABILITY DISTRIBUTION:
        - Single Frame (Yellow): \(stabilityDistribution[.singleFrame] ?? 0)
        - Multi Frame (Orange): \(stabilityDistribution[.multiFrame] ?? 0)
        - Corroborated (Red): \(stabilityDistribution[.corroborated] ?? 0)
        
        DETAILED DETECTION LOG:
        \(pins.enumerated().map { index, pin in
            """
            
            Pin #\(index + 1):
              ID: \(pin.id.uuidString)
              Position: (\(String(format: "%.2f", pin.worldPosition.x)), \(String(format: "%.2f", pin.worldPosition.y)), \(String(format: "%.2f", pin.worldPosition.z)))
              Confidence: \(String(format: "%.1f", pin.confidence * 100))%
              Stability: \(pin.stability.rawValue)
              Age: \(String(format: "%.1f", pin.age))s
              Detection Count: \(pin.detectionHistory.count)
              First Seen: \(pin.firstSeen)
              Last Seen: \(pin.lastSeen)
              Status: \(pin.isStale ? "Stale" : "Active")
            """
        }.joined(separator: "\n"))
        
        END REPORT
        """
    }
}


struct DetectionExportData: Codable {
    let exportDate: Date
    let totalDetections: Int
    let detections: [DetectionExport]
    let metadata: ExportMetadata
}

struct ExportMetadata: Codable {
    let appVersion: String
    let deviceModel: String
    let systemVersion: String
    
    init() {
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.deviceModel = UIDevice.current.model
        self.systemVersion = UIDevice.current.systemVersion
    }
}

// MARK: - Export Errors
enum ExportError: LocalizedError {
    case documentsDirectoryNotFound
    case arMapperNotAvailable
    case worldMapNotAvailable
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "Could not access documents directory"
        case .arMapperNotAvailable:
            return "AR Mapper not available"
        case .worldMapNotAvailable:
            return "World map not available"
        case .encodingFailed:
            return "Failed to encode data"
        }
    }
}

// MARK: - Share Helper
extension ExportService {
    func shareFile(url: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
}
