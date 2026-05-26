import CoreGraphics
import Foundation

struct GameItem: Equatable {
    let name: String
    let canFly: Bool
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
