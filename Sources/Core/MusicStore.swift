import Foundation
import SwiftUI
import SwiftData
import AVFoundation
import MediaPlayer
import CryptoKit

final class TransferProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let report: @Sendable (Double) -> Void
    init(report: @escaping @Sendable (Double) -> Void) { self.report = report }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 { report(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) }
    }
}

@MainActor @Observable final class MusicStore {
    var library = LibrarySnapshot()
    var error: String?
    var errorSource: URL?
    var isPlaying = false
    var isLoading = false
    var elapsed: Double = 0
    var duration: Double = 0
    var volume: Double = 0.8 { didSet { player.volume = Float(volume) } }
    var downloadProgress: [String:Double] = [:]
    var downloadErrors: [String:String] = [:]
    var showPlayer = false
    var showQueue = false
    var section: AppSection = .home
    var navigationPath = NavigationPath()
    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObserver: NSKeyValueObservation?
    @ObservationIgnored private var playbackTask: Task<Void,Never>?
    @ObservationIgnored private var transfers: [String:Task<Void,Never>] = [:]
    @ObservationIgnored private var playbackGeneration = UUID()
    @ObservationIgnored private var loadedEntry: UUID?
    @ObservationIgnored private var remoteTargets: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var normalOrder: [UUID] = []
    let storageURL: URL
    var current: Track? { library.queue.indices.contains(library.queueIndex) ? library.queue[library.queueIndex].track : nil }
    var currentEntry: QueueEntry? { library.queue.indices.contains(library.queueIndex) ? library.queue[library.queueIndex] : nil }
    var repeatLabel: String { ["Repeat Off", "Repeat All", "Repeat One"][min(2,max(0,library.repeatMode))] }
    var downloadedBytes: Int64 {
        library.downloads.values.reduce(0) { sum, name in
            sum + ((try? FileManager.default.attributesOfItem(atPath: storageURL.appendingPathComponent(name).path)[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }
    init() {
        let base = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
        storageURL = base.appendingPathComponent(IMSLPClient.testMode ? "IMSLPMusicTests" : "IMSLPMusic", isDirectory:true)
        do {
            try FileManager.default.createDirectory(at:storageURL,withIntermediateDirectories:true)
            if IMSLPClient.testMode && ProcessInfo.processInfo.arguments.contains("--reset-library") {
                for file in try FileManager.default.contentsOfDirectory(at:storageURL,includingPropertiesForKeys:nil) { try FileManager.default.removeItem(at:file) }
            }
            let configuration = ModelConfiguration(url:storageURL.appendingPathComponent("Library.store"))
            let db = try ModelContainer(for:LibraryRecord.self, configurations:configuration)
            container = db
            if let record = try db.mainContext.fetch(FetchDescriptor<LibraryRecord>()).first {
                library = try JSONDecoder().decode(LibrarySnapshot.self,from:record.payload)
            }
            library.queueIndex = min(max(library.queueIndex,0),max(library.queue.count-1,0))
            library.downloads = library.downloads.filter { FileManager.default.fileExists(atPath:storageURL.appendingPathComponent($0.value).path) }
        } catch { self.error = "Could not open the library: \(error.localizedDescription)" }
        normalOrder = library.queueOrder ?? library.queue.map(\.id)
        player.volume = IMSLPClient.testMode ? 0 : Float(volume)
        observer = player.addPeriodicTimeObserver(forInterval:CMTime(seconds:0.4,preferredTimescale:600),queue:.main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? max(0,time.seconds) : 0
                let seconds = self.player.currentItem?.duration.seconds ?? 0
                self.duration = seconds.isFinite ? max(0,seconds) : 0
                self.updateNowPlaying()
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName:.AVPlayerItemDidPlayToEndTime, object:nil, queue:.main) { [weak self] note in
            guard let item = note.object as? AVPlayerItem else { return }
            Task { @MainActor in
                guard let self, item === self.player.currentItem else { return }
                if self.library.repeatMode == 2 { self.seek(0); self.player.play() }
                else { self.next(automatic:true) }
            }
        }
        configureRemoteCommands()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback,mode:.default,policy:.longFormAudio)
        NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if type == AVAudioSession.InterruptionType.began.rawValue { Task { @MainActor in self?.pause() } }
        }
        #endif
    }
    func persist() {
        library.queueOrder = normalOrder
        guard let context = container?.mainContext else { return }
        do {
            let payload = try JSONEncoder().encode(library)
            if let record = try context.fetch(FetchDescriptor<LibraryRecord>()).first { record.payload = payload }
            else { context.insert(LibraryRecord(payload:payload)) }
            try context.save()
        } catch { self.error = "Could not save the library: \(error.localizedDescription)" }
    }
    func isSaved(_ track:Track) -> Bool { library.tracks.contains { $0.id == track.id } }
    func isFavorite(_ track:Track) -> Bool { library.favorites.contains(track.id) }
    func save(_ track:Track) { if !isSaved(track) { library.tracks.insert(track,at:0); persist() } }
    func removeFromLibrary(_ track:Track) {
        library.tracks.removeAll { $0.id == track.id }; library.favorites.remove(track.id)
        for i in library.playlists.indices { library.playlists[i].entries.removeAll { $0.track.id == track.id } }
        persist()
    }
    func favorite(_ track:Track) {
        save(track)
        if isFavorite(track) { library.favorites.remove(track.id) } else { library.favorites.insert(track.id) }
        persist()
    }
    func createPlaylist(_ name:String) {
        let name = name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        library.playlists.append(MusicPlaylist(name:name)); persist()
    }
    func renamePlaylist(_ id:UUID,name:String) {
        guard let index = library.playlists.firstIndex(where:{$0.id == id}), !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        library.playlists[index].name = name.trimmingCharacters(in:.whitespacesAndNewlines); persist()
    }
    func deletePlaylist(_ id:UUID) { library.playlists.removeAll { $0.id == id }; persist() }
    func add(_ track:Track,to id:UUID) {
        guard let index = library.playlists.firstIndex(where:{$0.id == id}) else { return }
        save(track); library.playlists[index].entries.append(QueueEntry(track:track)); persist()
    }
    func movePlaylist(_ id:UUID,from:IndexSet,to:Int) {
        guard let index = library.playlists.firstIndex(where:{$0.id == id}) else { return }
        library.playlists[index].entries.move(fromOffsets:from,toOffset:to); persist()
    }
    func removePlaylistTrack(_ id:UUID,entry:UUID) {
        guard let index = library.playlists.firstIndex(where:{$0.id == id}) else { return }
        library.playlists[index].entries.removeAll { $0.id == entry }; persist()
    }
    func play(_ tracks:[Track],at index:Int = 0) {
        guard !tracks.isEmpty else { return }
        library.queue = tracks.map { QueueEntry(track:$0) }
        library.queueIndex = min(max(index,0),tracks.count-1)
        normalOrder = library.queue.map(\.id)
        if library.shuffle { shuffleUpcoming() }
        persist(); loadCurrent()
    }
    func selectQueue(_ entry:UUID) {
        guard let index = library.queue.firstIndex(where:{$0.id == entry}) else { return }
        library.queueIndex = index; persist(); loadCurrent()
    }
    func enqueue(_ tracks:[Track],next:Bool) {
        let entries = tracks.map { QueueEntry(track:$0) }
        if next { library.queue.insert(contentsOf:entries,at:min(library.queueIndex+1,library.queue.count)) }
        else { library.queue.append(contentsOf:entries) }
        normalOrder.append(contentsOf:entries.map(\.id)); persist()
    }
    func moveQueue(from:IndexSet,to:Int) {
        let id = currentEntry?.id
        library.queue.move(fromOffsets:from,toOffset:to)
        library.queueIndex = library.queue.firstIndex(where:{$0.id == id}) ?? 0
        persist()
    }
    func removeQueue(_ id:UUID) {
        let old = currentEntry?.id
        let index = library.queueIndex
        library.queue.removeAll { $0.id == id }
        library.queueIndex = library.queue.firstIndex(where:{$0.id == old}) ?? min(index,max(0,library.queue.count-1))
        if id == old { pause(); loadedEntry = nil; player.replaceCurrentItem(with:nil); elapsed = 0; duration = 0 }
        persist()
    }
    func clearQueue() {
        pause(); playbackTask?.cancel(); loadedEntry = nil; player.replaceCurrentItem(with:nil)
        library.queue = []; library.queueIndex = 0; elapsed = 0; duration = 0; persist()
    }
    func toggleShuffle() {
        library.shuffle.toggle()
        if library.shuffle { normalOrder = library.queue.map(\.id); shuffleUpcoming() }
        else if library.queueIndex + 1 < library.queue.count {
            let first = library.queueIndex + 1
            let rest = library.queue[first...].sorted { (normalOrder.firstIndex(of:$0.id) ?? Int.max) < (normalOrder.firstIndex(of:$1.id) ?? Int.max) }
            library.queue.replaceSubrange(first...,with:rest)
        }
        persist()
    }
    private func shuffleUpcoming() {
        let first = library.queueIndex + 1
        guard first < library.queue.count else { return }
        library.queue.replaceSubrange(first...,with:library.queue[first...].shuffled())
    }
    func cycleRepeat() { library.repeatMode = (library.repeatMode + 1) % 3; persist() }
    func togglePlayback() {
        if isPlaying || isLoading { pause() }
        else if loadedEntry == currentEntry?.id, player.currentItem != nil { isPlaying = true; player.play() }
        else { loadCurrent() }
    }
    func pause() {
        playbackTask?.cancel(); playbackGeneration = UUID(); isLoading = false; isPlaying = false; player.pause(); updateNowPlaying()
    }
    func next(automatic:Bool = false) {
        if library.queueIndex + 1 < library.queue.count { library.queueIndex += 1; persist(); loadCurrent() }
        else if library.repeatMode == 1, !library.queue.isEmpty { library.queueIndex = 0; persist(); loadCurrent() }
        else { pause(); if automatic { seek(0) } }
    }
    func previous() {
        if elapsed > 3 { seek(0) }
        else if library.queueIndex > 0 { library.queueIndex -= 1; persist(); loadCurrent() }
        else { seek(0) }
    }
    func seek(_ seconds:Double) {
        guard seconds.isFinite else { return }
        let target = max(0,min(seconds,duration > 0 ? duration : seconds))
        player.seek(to:CMTime(seconds:target,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero)
        elapsed = target; updateNowPlaying()
    }
    private func loadCurrent() {
        guard let track = current, let entry = currentEntry else { return }
        playbackTask?.cancel(); player.pause(); player.replaceCurrentItem(with:nil)
        let generation = UUID(); playbackGeneration = generation
        isLoading = true; isPlaying = false; elapsed = 0; duration = 0; loadedEntry = nil
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url:URL
                if let local = self.localURL(track) { url = local }
                else { url = try await IMSLPClient.shared.resolve(track) }
                try Task.checkCancellation()
                guard generation == self.playbackGeneration else { return }
                #if os(iOS)
                try AVAudioSession.sharedInstance().setActive(true)
                #endif
                let item = AVPlayerItem(url:url)
                self.statusObserver = item.observe(\.status,options:[.new]) { [weak self] item,_ in
                    let failed = item.status == .failed
                    let message = item.error?.localizedDescription
                    Task { @MainActor in
                        guard let self, generation == self.playbackGeneration, failed else { return }
                        self.pause(); self.error = message ?? "Could not play this recording."; self.errorSource = track.sourceURL
                    }
                }
                self.player.replaceCurrentItem(with:item)
                self.loadedEntry = entry.id; self.isLoading = false; self.isPlaying = true; self.player.play()
                self.library.recent.removeAll { $0.id == track.id }; self.library.recent.insert(track,at:0)
                self.library.recent = Array(self.library.recent.prefix(30)); self.persist(); self.updateNowPlaying()
            } catch is CancellationError { }
            catch {
                guard generation == self.playbackGeneration else { return }
                self.isLoading = false; self.isPlaying = false; self.error = error.localizedDescription; self.errorSource = track.sourceURL
            }
        }
    }
    func localURL(_ track:Track) -> URL? {
        guard let name = library.downloads[track.id] else { return nil }
        let url = storageURL.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath:url.path) ? url : nil
    }
    func download(_ track:Track) {
        guard transfers[track.id] == nil, localURL(track) == nil else { return }
        downloadProgress[track.id] = 0; downloadErrors[track.id] = nil
        transfers[track.id] = Task { [weak self] in
            guard let self else { return }
            var temporary:URL?
            defer { if let temporary { try? FileManager.default.removeItem(at:temporary) }; self.transfers[track.id] = nil; self.downloadProgress[track.id] = nil }
            do {
                let source = try await IMSLPClient.shared.resolve(track)
                let ext = source.pathExtension.isEmpty ? "mp3" : source.pathExtension
                let filename = SHA256.hash(data:Data(track.id.utf8)).map { String(format:"%02x",$0) }.joined() + "." + ext
                let destination = self.storageURL.appendingPathComponent(filename)
                let staging = self.storageURL.appendingPathComponent(UUID().uuidString + "." + ext)
                temporary = staging
                if source.isFileURL {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--slow-download") { try await Task.sleep(for:.seconds(5)) }
                    if ProcessInfo.processInfo.arguments.contains("--corrupt-download") { try Data("<html>Access required</html>".utf8).write(to:staging) }
                    else { try FileManager.default.copyItem(at:source,to:staging) }
                    #else
                    try FileManager.default.copyItem(at:source,to:staging)
                    #endif
                }
                else {
                    let progress = TransferProgress { [weak self] value in Task { @MainActor in self?.downloadProgress[track.id] = value } }
                    let (file,response) = try await URLSession.shared.download(from:source,delegate:progress)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SourceError.unavailable }
                    guard !(http.mimeType ?? "").contains("html") else { throw SourceError.unavailable }
                    try FileManager.default.moveItem(at:file,to:staging)
                }
                try Task.checkCancellation()
                let asset = AVURLAsset(url:staging)
                let duration = try await asset.load(.duration).seconds
                guard duration.isFinite, duration > 0 else { throw SourceError.unsupported }
                try Task.checkCancellation()
                if FileManager.default.fileExists(atPath:destination.path) { try FileManager.default.removeItem(at:destination) }
                try FileManager.default.moveItem(at:staging,to:destination)
                self.library.downloads[track.id] = filename
                var downloaded = self.library.downloadedTracks ?? []
                downloaded.removeAll { $0.id == track.id }; downloaded.append(track)
                self.library.downloadedTracks = downloaded
                self.save(track); self.persist()
            } catch is CancellationError { }
            catch let err as URLError where err.code == .cancelled { }
            catch { self.downloadErrors[track.id] = error.localizedDescription }
        }
    }
    func cancelDownload(_ track:Track) { transfers[track.id]?.cancel() }
    func removeDownload(_ track:Track) {
        guard let url = localURL(track) else { return }
        do { try FileManager.default.removeItem(at:url); library.downloads.removeValue(forKey:track.id); library.downloadedTracks?.removeAll { $0.id == track.id }; persist() }
        catch { self.error = "Could not remove the download: \(error.localizedDescription)" }
    }
    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        for (command,action) in [(center.playCommand,0),(center.pauseCommand,1),(center.togglePlayPauseCommand,2),(center.nextTrackCommand,3),(center.previousTrackCommand,4)] {
            let target = command.addTarget { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    switch action {
                    case 0: if !self.isPlaying { self.togglePlayback() }
                    case 1: self.pause()
                    case 2: self.togglePlayback()
                    case 3: self.next()
                    default: self.previous()
                    }
                }
                return .success
            }
            remoteTargets.append((command,target))
        }
        let command = center.changePlaybackPositionCommand
        let target = command.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(event.positionTime) }; return .success
        }
        remoteTargets.append((command,target))
    }
    private func updateNowPlaying() {
        guard let track = current else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle:track.title, MPMediaItemPropertyAlbumTitle:track.work.title, MPMediaItemPropertyArtist:track.performer, MPMediaItemPropertyComposer:track.work.composer, MPMediaItemPropertyPlaybackDuration:duration, MPNowPlayingInfoPropertyElapsedPlaybackTime:elapsed, MPNowPlayingInfoPropertyPlaybackRate:isPlaying ? 1.0 : 0.0]
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        #endif
    }
}
