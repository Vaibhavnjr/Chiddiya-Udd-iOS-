import Foundation

enum GamePhase: Equatable {
    case splash
    case waitingForPlayers
    case countdown
    case locked
    case callout
    case evaluating
    case results
    case betweenRounds
    case allOut
    case winner
}
