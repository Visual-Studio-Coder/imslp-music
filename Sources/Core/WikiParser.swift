import Foundation

/// Reads balanced templates so nested performer/publisher templates do not cut off a recording.
enum WikiParser {
    static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { result in
            (0..<result.numberOfRanges).map { result.range(at: $0).location == NSNotFound ? "" : ns.substring(with: result.range(at: $0)) }
        }
    }
    static func clean(_ source: String) -> String {
        var s = source
        s = s.replacingOccurrences(of: #"\[\[(?:[^\]|]+\|)?([^\]]+)\]\]"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\{\{(?:GardnerPerf|plain)\|(?:https?[^|]+\|)?([^{}]+)\}\}"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\{\{[^{}]*\}\}"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<br\s*/?>"#, with: " / ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        for (a,b) in [("&amp;","&"),("&quot;","\""),("&#39;","'"),("&nbsp;"," "),("''","")] { s = s.replacingOccurrences(of: a, with: b) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func recordings(wiki: String, rendered: String, work: Work) -> [Recording] {
        let audio = wiki.components(separatedBy: "*****FILES*****").first ?? wiki
        let ns = audio as NSString
        let starts = matches(#"\{\{#fte:imslpaudio"#, in: audio)
        guard !starts.isEmpty else { return [] }
        let regex = try! NSRegularExpression(pattern: #"\{\{#fte:imslpaudio"#)
        let positions = regex.matches(in: audio, range: NSRange(location: 0, length: ns.length))
        let urls = playerURLs(rendered)
        let access = fileAccess(rendered)
        var result: [Recording] = []
        for position in positions {
            let start = position.range.location
            var i = start + 2, depth = 1
            while i + 1 < ns.length && depth > 0 {
                let pair = ns.substring(with: NSRange(location: i, length: 2))
                if pair == "{{" { depth += 1; i += 2 }
                else if pair == "}}" { depth -= 1; i += 2 }
                else { i += 1 }
            }
            guard depth == 0 else { continue }
            let body = ns.substring(with: NSRange(location: start, length: i-start-2))
            let fields = matches(#"(?m)^\|([^=\n]+)=(.*(?:\n(?!\|)[^\n]*)*)"#, in: body)
            var values: [String:String] = [:]
            fields.forEach { values[$0[1].trimmingCharacters(in: .whitespaces)] = $0[2].trimmingCharacters(in: .whitespacesAndNewlines) }
            let prefix = ns.substring(to: start)
            let headings = matches(#"(?m)^(={3,5})([^=\n]+)\1\s*$"#, in: prefix)
            let lastSection = headings.last(where: { $0[1].count == 3 })?[2] ?? "Recordings"
            if lastSection.localizedCaseInsensitiveContains("Video") || lastSection.localizedCaseInsensitiveContains("Naxos") { continue }
            let synthesized = lastSection.localizedCaseInsensitiveContains("Synthesized") || (values["Performers"] ?? "").localizedCaseInsensitiveContains("MIDI")
            let heading = clean(headings.last?[2] ?? "Complete Performance")
            let performerValue = clean(values["Performers"] ?? "")
            let categories = clean(values["Performer Categories"] ?? "").replacingOccurrences(of: "=", with: " · ")
            let performer = performerValue.isEmpty ? (categories.isEmpty ? "Performer not listed" : categories) : performerValue
            let license = clean(values["Copyright"] ?? "License not listed")
            let files = values.keys.compactMap { key -> (Int, String)? in
                guard key.hasPrefix("File Name "), let number = Int(key.dropFirst(10)), let file = values[key], !file.isEmpty else { return nil }
                return (number, file)
            }.sorted { $0.0 < $1.0 }
            guard let first = files.first else { continue }
            let recordingID = first.1
            let tracks = files.filter { !["pdf", "zip", "mp4"].contains(($0.1 as NSString).pathExtension.lowercased()) }.map { number, file in
                let url = urls.first { normalized($0.lastPathComponent).hasSuffix(normalized(file)) }
                let source = access[normalized(file)]
                return Track(fileName: file, title: clean(values["File Description \(number)"] ?? "Track \(number)"), work: work, performer: performer, license: license, recordingID: recordingID, isSynthesized: synthesized, audioURL: url, filePageURL:source?.0,accessRegion:source?.1)
            }
            guard !tracks.isEmpty else { continue }
            result.append(Recording(id: recordingID, title: heading, performer: performer, license: license, isSynthesized: synthesized, tracks: tracks, artworkFileName: values["Thumb Filename"]))
        }
        return result
    }
    static func normalized(_ s: String) -> String { (s.removingPercentEncoding ?? s).replacingOccurrences(of: " ", with: "_") }
    static func fileAccess(_ html:String) -> [String:(URL,String?)] {
        var result:[String:(URL,String?)] = [:]
        for block in matches(#"(?s)<div id="IMSLP([0-9]+)"[^>]*>(.*?)<div class="we_file_info mhs">"#,in:html) {
            guard let path = matches(#"href="(/images/[^"]+)""#,in:block[2]).first?[1],
                  let file = URL(string:"https://imslp.org" + path) else { continue }
            let region = matches(#"<b>\s*\((EU|US|CA)\)</b>"#,in:block[2]).first?[1]
            let page = URL(string:"https://imslp.org/wiki/Special:ImagefromIndex/" + block[1])!
            result[normalized(file.lastPathComponent)] = (page,region)
        }
        return result
    }
    static func playerURLs(_ html: String) -> [URL] {
        matches(#""file"\s*:\s*("(?:\\.|[^"\\])*")"#, in: html).compactMap {
            guard let value = try? JSONDecoder().decode(String.self, from: Data($0[1].utf8)), let url = URL(string: value), url.scheme == "https" else { return nil }
            return url
        }
    }
}
