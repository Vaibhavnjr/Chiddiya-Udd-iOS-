import CoreGraphics
import Foundation

struct GameItem: Equatable {
    let name: String
    let canFly: Bool
}

enum GameRules {
    static let initialReactionWindow: TimeInterval = 1.0
    static let minimumReactionWindow: TimeInterval = 0.4
    static let reactionWindowStep: TimeInterval = 0.1

    static func nextReactionWindow(after currentWindow: TimeInterval) -> TimeInterval {
        let currentMilliseconds = Int((currentWindow * 1_000).rounded())
        let minimumMilliseconds = Int((minimumReactionWindow * 1_000).rounded())
        let stepMilliseconds = Int((reactionWindowStep * 1_000).rounded())

        return TimeInterval(max(currentMilliseconds - stepMilliseconds, minimumMilliseconds)) / 1_000
    }

    static func isLiftCorrect(canFly: Bool, at timestamp: TimeInterval, deadline: TimeInterval) -> Bool {
        timestamp <= deadline ? canFly : !canFly
    }
}

enum PlayerStatus: Equatable {
    case registering
    case ready
    case locked
    case needsFingerBack
    case correct
    case wrong
    case eliminated
    case winner
}

struct GamePlayer: Identifiable, Equatable {
    let id: UUID
    var touchIdentity: ObjectIdentifier?
    var position: CGPoint
    var status: PlayerStatus
    var isFingerDown: Bool
    var isAlive: Bool
}
