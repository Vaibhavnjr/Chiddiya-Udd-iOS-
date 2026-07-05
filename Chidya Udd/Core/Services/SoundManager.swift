import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private var audioPlayers: [String: AVAudioPlayer] = [:]

    private init() {}

    @discardableResult
    func play(_ name: String) -> Bool {
        guard let player = player(for: name) else { return false }

        player.currentTime = 0
        player.play()
        return true
    }

    func duration(for name: String) -> TimeInterval? {
        player(for: name)?.duration
    }

    private func player(for name: String) -> AVAudioPlayer? {
        if let player = audioPlayers[name] {
            player.currentTime = 0
            return player
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") ??
                Bundle.main.url(forResource: name, withExtension: "mp3") else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[name] = player
            return player
        } catch {
            // swallow for MVP
            return nil
        }
    }

    // Convenience names
    func beep() { play("beep") }
    func ding() { play("ding") }
    func success() { play("success") }
    func error() { play("error") }
}

