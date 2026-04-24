import Foundation

final class Exporter {

    var fallbackFolderURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    @discardableResult
    func write(_ snapshot: HealthDaySnapshot, to folderURL: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let url = folderURL.appendingPathComponent("\(snapshot.date).json")
        let data = try JSONEncoder.healthExportEncoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        return url
    }
}
