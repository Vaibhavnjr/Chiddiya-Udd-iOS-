import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private var audioPlayers: [String: AVAudioPlayer] = [:]

    private init() {}

    func play(_ name: String) {
        if let player = audioPlayers[name] {
            player.currentTime = 0
            player.play()
            return
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") ??
                Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[name] = player
            player.play()
        } catch {
            // swallow for MVP
        }
    }

    // Convenience names
    func beep() { play("beep") }
    func ding() { play("ding") }
    func success() { play("success") }
    func error() { play("error") }
}



