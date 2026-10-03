import Foundation
import AVFoundation

@main struct LiveAudioCheck {
    static func main() async throws {
        let url = URL(string: "https://ks15.imslp.org/files/imglnks/usimg/e/ea/IMSLP310845-PMLP164349-bach_cellosuiteno1_carr.mp3")!
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration > 1000 else { fatalError("Invalid duration") }
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player.volume = 0
        player.play()
        try await Task.sleep(for: .seconds(5))
        let before = player.currentTime().seconds
        guard before > 0 else { fatalError("Playback did not advance: \(String(describing: player.currentItem?.error))") }
        await player.seek(to: CMTime(seconds: 30, preferredTimescale: 600))
        try await Task.sleep(for: .seconds(2))
        let after = player.currentTime().seconds
        guard after >= 30 else { fatalError("Seek failed") }
        player.pause()
        let (local, response) = try await URLSession.shared.download(from: url)
        let saved = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Artifacts/live-complete.mp3")
        try? FileManager.default.removeItem(at: saved)
        try FileManager.default.moveItem(at: local, to: saved)
        print("download response", response)
        let downloaded = AVURLAsset(url: saved)
        let localDuration = try await downloaded.load(.duration).seconds
        guard abs(localDuration - duration) < 1 else { fatalError("Download incomplete") }
        print("PASS source=IMSLP310845 status=\((response as? HTTPURLResponse)?.statusCode ?? 0) duration=\(duration) played=\(before) seek=\(after) downloadedDuration=\(localDuration)")
    }
}
