import Foundation

final class Exporter {
    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    @discardableResult
    func write(_ snapshot: HealthDaySnapshot) throws -> URL {
        let url = documentsURL.appendingPathComponent("\(snapshot.date).json")
        let data = try JSONEncoder.healthExportEncoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        return url
    }
}
