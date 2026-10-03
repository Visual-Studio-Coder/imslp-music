import Foundation

actor IMSLPClient {
    static let shared = IMSLPClient()
    nonisolated static let testMode: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        return false
        #endif
    }()
    nonisolated static let offline = testMode && ProcessInfo.processInfo.arguments.contains("--offline")
    nonisolated static let sourceAccessFixture = testMode && ProcessInfo.processInfo.arguments.contains("--source-access")
    nonisolated static let sampleTitle = "Cello Suite No.1 in G major, BWV 1007 (Bach, Johann Sebastian)"
    private var cache: [String: (Date, WorkDetail)] = [:]
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.httpMaximumConnectionsPerHost = 4
        config.urlCache = URLCache(memoryCapacity: 20_000_000, diskCapacity: 80_000_000)
        session = URLSession(configuration: config)
    }
    nonisolated static func pageURL(_ title: String) -> URL {
        var url = URLComponents(string: "https://imslp.org/index.php")!
        url.queryItems = [URLQueryItem(name: "title", value: title)]
        return url.url!
    }
    private func request(_ params: [String:String]) async throws -> [String:Any] {
        if Self.offline { throw SourceError.offline }
        var parts = URLComponents(string: "https://imslp.org/api.php")!
        parts.queryItems = (params.merging(["format":"json"]) { a,_ in a }).sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: parts.url!)
        request.setValue("IMSLPMusic/1.0 (native public catalog client)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw SourceError.status((response as? HTTPURLResponse)?.statusCode ?? 0) }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String:Any], json["error"] == nil else { throw SourceError.malformed }
            return json
        } catch let error as URLError where error.code == .notConnectedToInternet { throw SourceError.offline }
    }
    func search(_ text: String, offset: Int = 0) async throws -> SearchResults {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return SearchResults() }
        if Self.offline { throw SourceError.offline }
        if Self.testMode {
            try await Task.sleep(for: .milliseconds(150))
            if Self.sourceAccessFixture { return SearchResults(works:[.from("Abendempfindung, K.523 (Mozart, Wolfgang Amadeus)")]) }
            return q.localizedCaseInsensitiveContains("Bach") ? SearchResults(works: [.from(Self.sampleTitle)], composers: [Composer(id: "Category:Bach, Johann Sebastian", name: "Bach, Johann Sebastian")]) : SearchResults()
        }
        let json = try await request(["action":"query", "list":"search", "srsearch":q, "srnamespace":"0", "srlimit":"40", "sroffset":String(offset), "srwhat":"title"])
        let query = json["query"] as? [String:Any]
        let rows = query?["search"] as? [[String:Any]] ?? []
        let works = rows.compactMap { $0["title"] as? String }.filter { $0.hasSuffix(")") }.map(Work.from)
        var composers: [Composer] = []
        if offset == 0 {
            let people = try? await request(["action":"query", "list":"search", "srsearch":q, "srnamespace":"14", "srlimit":"8", "srwhat":"title"])
            let p = (people?["query"] as? [String:Any])?["search"] as? [[String:Any]] ?? []
            composers = p.compactMap { $0["title"] as? String }.filter { $0.contains(",") }.map { Composer(id:$0, name:$0.replacingOccurrences(of:"Category:",with:"")) }
        }
        let next = (json["query-continue"] as? [String:Any])?["search"] as? [String:Any]
        return SearchResults(works: works, composers: composers, nextOffset: next?["sroffset"] as? Int)
    }
    func works(for composer: Composer) async throws -> [Work] {
        if Self.testMode { return [.from(Self.sampleTitle)] }
        let json = try await request(["action":"query", "list":"categorymembers", "cmtitle":composer.id, "cmnamespace":"0", "cmlimit":"100", "cmtype":"page"])
        return (((json["query"] as? [String:Any])?["categorymembers"] as? [[String:Any]]) ?? []).compactMap { $0["title"] as? String }.filter { $0.hasSuffix(")") }.map(Work.from)
    }
    func people(start: Int = 0) async throws -> [Composer] {
        if Self.testMode { return Self.featuredComposers }
        let url = URL(string:"https://imslp.org/imslpscripts/API.ISCR.php?account=worklist/disclaimer=accepted/sort=id/type=1/start=\(start)/retformat=json")!
        let (data, _) = try await session.data(from: url)
        guard let entries = try JSONSerialization.jsonObject(with: data) as? [String:Any] else { throw SourceError.malformed }
        return entries.keys.compactMap(Int.init).sorted().compactMap { index in
            guard let item = entries[String(index)] as? [String:Any], let id = item["id"] as? String else { return nil }
            return Composer(id:id, name:id.replacingOccurrences(of:"Category:",with:""))
        }
    }
    func work(_ work: Work, refresh: Bool = false) async throws -> WorkDetail {
        if !refresh, let saved = cache[work.id], Date().timeIntervalSince(saved.0) < 3600 { return saved.1 }
        if Self.offline { throw SourceError.offline }
        let raw: [String:Any]
        let rendered: [String:Any]
        if Self.testMode {
            raw = try fixture(Self.sourceAccessFixture ? "mozart-work" : "bach-work")
            rendered = try fixture(Self.sourceAccessFixture ? "mozart-rendered" : "bach-rendered")
        } else {
            raw = try await request(["action":"query", "prop":"revisions", "rvprop":"content", "titles":work.id, "redirects":"1"])
            rendered = try await request(["action":"parse", "page":work.id, "prop":"text", "redirects":"1"])
        }
        guard let pages = (raw["query"] as? [String:Any])?["pages"] as? [String:Any], let page = pages.values.first as? [String:Any], let revisions = page["revisions"] as? [[String:Any]], let wiki = revisions.first?["*"] as? String else { throw SourceError.malformed }
        let html = ((rendered["parse"] as? [String:Any])?["text"] as? [String:Any])?["*"] as? String ?? ""
        var detail = WorkDetail(work:work, recordings:WikiParser.recordings(wiki:wiki, rendered:html, work:work))
        if !Self.testMode {
            let names = Array(Set(detail.recordings.compactMap(\.artworkFileName))).prefix(20)
            if !names.isEmpty, let images = try? await request(["action":"query", "prop":"imageinfo", "iiprop":"url", "iiurlwidth":"400", "titles":names.map { "File:" + $0 }.joined(separator:"|")]),
               let pages = (images["query"] as? [String:Any])?["pages"] as? [String:Any] {
                var artwork: [String:URL] = [:]
                for item in pages.values {
                    guard let page = item as? [String:Any], let title = page["title"] as? String,
                          let info = (page["imageinfo"] as? [[String:Any]])?.first,
                          var address = (info["thumburl"] ?? info["url"]) as? String else { continue }
                    if address.hasPrefix("//") { address = "https:" + address }
                    if address.hasPrefix("http:") { address = "https:" + address.dropFirst(5) }
                    if let url = URL(string:address), url.scheme == "https" { artwork[WikiParser.normalized(String(title.dropFirst(5)))] = url }
                }
                for i in detail.recordings.indices {
                    if let name = detail.recordings[i].artworkFileName, let url = artwork[WikiParser.normalized(name)] {
                        detail.recordings[i].artworkURL = url
                        for j in detail.recordings[i].tracks.indices { detail.recordings[i].tracks[j].artworkURL = url }
                    }
                }
            }
        }
        cache[work.id] = (Date(),detail)
        return detail
    }
    func resolve(_ track: Track) async throws -> URL {
        if Self.offline { throw SourceError.offline }
        if Self.testMode { return Bundle.main.url(forResource:"test-audio",withExtension:"wav")! }
        guard !["mid","midi"].contains((track.fileName as NSString).pathExtension.lowercased()) else { throw SourceError.unsupported }
        let fresh = try await work(track.work, refresh:true)
        guard let resolved = fresh.recordings.flatMap(\.tracks).first(where: { $0.id == track.id }) else { throw SourceError.unavailable }
        guard let url = resolved.audioURL else { throw SourceError.sourceAccess(resolved.accessRegion) }
        return url
    }
    private func fixture(_ name:String) throws -> [String:Any] {
        guard let url = Bundle.main.url(forResource:name,withExtension:"json"), let result = try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any] else { throw SourceError.malformed }
        return result
    }
    nonisolated static let featuredComposers: [Composer] = ["Bach, Johann Sebastian", "Beethoven, Ludwig van", "Mozart, Wolfgang Amadeus", "Chopin, Frédéric", "Debussy, Claude", "Schubert, Franz", "Ravel, Maurice", "Clara Schumann"].map { name in
        let source = name == "Clara Schumann" ? "Schumann, Clara" : name
        return Composer(id:"Category:" + source,name:source)
    }
}
