import CoreGraphics
import Foundation

struct GameItem: Equatable {
    let name: String
    let canFly: Bool
    let audioName: String?

    init(name: String, canFly: Bool, audioName: String? = nil) {
        self.name = name
        self.canFly = canFly
        self.audioName = audioName
    }
}

enum GameRules {
    static let initialReactionWindow: TimeInterval = 1.0
    static let initialSpeechRate: Float = 1.0
    static let speechRateMultiplier: Float = 1.1
    static let maxSpeechRate: Float = 2.0

    static let items: [GameItem] = [
        GameItem(name: "Sparrow", canFly: true, audioName: "chidiya_udd"),
        GameItem(name: "Pigeon", canFly: true, audioName: "kabootar_udd"),
        GameItem(name: "Crow", canFly: true, audioName: "kauwa_udd"),
        GameItem(name: "Eagle", canFly: true, audioName: "garud_udd"),
        GameItem(name: "Sparrow", canFly: true, audioName: "gauraiya_udd"),
        GameItem(name: "Parrot", canFly: true, audioName: "tota_udd"),
        GameItem(name: "Duck", canFly: true, audioName: "battakh_udd"),
        GameItem(name: "Hawk", canFly: true, audioName: "baaz_udd"),
        GameItem(name: "Peacock", canFly: true, audioName: "mor_udd"),
        GameItem(name: "Swan", canFly: true, audioName: "hans_udd")
    ]

    static func nextSpeechRate(after currentRate: Float) -> Float {
        min(currentRate * speechRateMultiplier, maxSpeechRate)
    }

    static func isLiftCorrect(canFly: Bool, at timestamp: TimeInterval, deadline: TimeInterval) -> Bool {
        timestamp <= deadline ? canFly : !canFly
    }

    static func chooseItem(after previousItem: GameItem?) -> GameItem {
        let pool = items.filter { $0 != previousItem }
        return pool.randomElement() ?? items.randomElement() ?? GameItem(name: "Sparrow", canFly: true)
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
