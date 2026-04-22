import Foundation

final class Exporter {

    enum Destination {
        case iCloud(URL)
        case localFallback(URL)

        var url: URL {
            switch self {
            case .iCloud(let url), .localFallback(let url): return url
            }
        }

        var isICloud: Bool {
            if case .iCloud = self { return true }
            return false
        }
    }

    private var localDocumentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Resolve export destination. Prefer iCloud Ubiquity Container; fall back to local Documents.
    func destination() -> Destination {
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let documents = container.appendingPathComponent("Documents", isDirectory: true)
            try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            return .iCloud(documents)
        }
        return .localFallback(localDocumentsURL)
    }

    @discardableResult
    func write(_ snapshot: HealthDaySnapshot) throws -> (url: URL, isICloud: Bool) {
        let dest = destination()
        let url = dest.url.appendingPathComponent("\(snapshot.date).json")
        let data = try JSONEncoder.healthExportEncoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        return (url, dest.isICloud)
    }
}
