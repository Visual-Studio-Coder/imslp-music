import Foundation
@main struct LiveCatalogCheck {
    static func main() async throws {
        let client = IMSLPClient.shared
        let results = try await client.search("BWV 1007")
        guard !results.works.isEmpty else { fatalError("Search returned no works") }
        let detail = try await client.work(.from(IMSLPClient.sampleTitle))
        guard detail.recordings.count >= 6 else { fatalError("Recording groups missing") }
        guard detail.recordings[2].tracks.count == 6 else { fatalError("Movement order/group changed") }
        let source = try await client.resolve(detail.recordings[0].tracks[0])
        for query in ["Symphony No.5, Op.67", "Suite bergamasque"] {
            let found = try await client.search(query)
            guard let work = found.works.first(where: { $0.title.hasPrefix(query) }) else { fatalError("No work for \(query)") }
            let other = try await client.work(work)
            guard !other.recordings.isEmpty else { fatalError("No recording groups for \(work.id)") }
            print("PASS work=\(work.id) recordingGroups=\(other.recordings.count) publicAudioLinks=\(other.recordings.flatMap(\.tracks).filter { $0.audioURL != nil }.count)")
        }
        print("PASS query=BWV1007 results=\(results.works.count) recordings=\(detail.recordings.count) movements=\(detail.recordings[2].tracks.map(\.title)) source=\(source)")
    }
}
