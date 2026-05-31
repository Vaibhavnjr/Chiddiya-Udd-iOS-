import Foundation
import UIKit

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var phase: GamePhase = .splash
    @Published private(set) var players: [GamePlayer] = []
    @Published private(set) var countdownValue: Int = 3
    @Published private(set) var activeItem: GameItem?
    @Published private(set) var showConfetti = false

    let minPlayers = 2
    let maxPlayers = 5
    let reactionWindow: TimeInterval = 1.0

    private let countdownDuration = 3
    private let lockDuration: TimeInterval = 1.15
    private let resultDuration: TimeInterval = 1.45
    private let betweenRoundDelay: TimeInterval = 1.0
    private let allOutDuration: TimeInterval = 1.8

    private let gameItems: [GameItem] = [
        GameItem(name: "Bird", canFly: true),
        GameItem(name: "Pigeon", canFly: true),
        GameItem(name: "Crow", canFly: true),
        GameItem(name: "Eagle", canFly: true),
        GameItem(name: "Parrot", canFly: true),
        GameItem(name: "Cow", canFly: false),
        GameItem(name: "Dog", canFly: false),
        GameItem(name: "Cat", canFly: false),
        GameItem(name: "Elephant", canFly: false),
        GameItem(name: "Fish", canFly: false)
    ]

    private var touchToPlayerID: [ObjectIdentifier: UUID] = [:]
    private var answeredPlayerIDs = Set<UUID>()
    private var lastItemName: String?

    private var splashTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var lockTask: Task<Void, Never>?
    private var reactionTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var betweenRoundTask: Task<Void, Never>?
    private var allOutTask: Task<Void, Never>?

    var visiblePlayers: [GamePlayer] {
        players.filter { $0.status != .eliminated }
    }

    var alivePlayers: [GamePlayer] {
        players.filter(\.isAlive)
    }

    var allAlivePlayersDown: Bool {
        let alive = alivePlayers
        return !alive.isEmpty && alive.allSatisfy(\.isFingerDown)
    }

    var statusText: String {
        switch phase {
        case .splash:
            return ""
        case .waitingForPlayers:
            return players.count == 1 ? "Need one more finger" : "Put fingers to start game"
        case .countdown:
            return "Game starts in \(countdownValue) secs"
        case .locked:
            return allAlivePlayersDown ? "Get ready..." : "Put fingers back"
        case .callout:
            return ""
        case .evaluating:
            return ""
        case .results:
            return ""
        case .betweenRounds:
            return allAlivePlayersDown ? "Next round starts in 1 second" : "Survivors, put fingers back"
        case .allOut:
            return "Everyone got out!"
        case .winner:
            return ""
        }
    }

    func startSplashIfNeeded() {
        guard phase == .splash, splashTask == nil else { return }
        splashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard let self, !Task.isCancelled, self.phase == .splash else { return }
            self.phase = .waitingForPlayers
        }
    }

    func resetGame() {
        cancelAllTasks()
        touchToPlayerID.removeAll()
        answeredPlayerIDs.removeAll()
        players.removeAll()
        activeItem = nil
        countdownValue = countdownDuration
        showConfetti = false
        phase = .waitingForPlayers
    }

    func beginTouches(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            beginTouch(touch, in: view)
        }
    }

    func moveTouches(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let identity = ObjectIdentifier(touch)
            guard let playerID = touchToPlayerID[identity],
                  let index = playerIndex(for: playerID) else { continue }

            players[index].position = touch.location(in: view)
            players[index].isFingerDown = true
            updateReadinessForFingerDownPlayer(at: index)
        }
    }

    func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            endTouch(touch)
        }
    }

    private func beginTouch(_ touch: UITouch, in view: UIView) {
        let identity = ObjectIdentifier(touch)
        guard touchToPlayerID[identity] == nil else { return }

        let position = touch.location(in: view)

        switch phase {
        case .waitingForPlayers, .countdown:
            guard players.count < maxPlayers else { return }
            let player = GamePlayer(
                id: UUID(),
                touchIdentity: identity,
                position: position,
                status: phase == .countdown ? .ready : .registering,
                isFingerDown: true,
                isAlive: true
            )
            players.append(player)
            touchToPlayerID[identity] = player.id
            Haptics.light()
            handlePregamePlayersChanged()

        case .locked:
            assignTouch(identity, at: position, statusWhenDown: .locked)
            handleLockedReadinessChanged()

        case .betweenRounds:
            assignTouch(identity, at: position, statusWhenDown: .ready)
            handleBetweenRoundReadinessChanged()

        case .results:
            assignCorrectResultTouch(identity, at: position)

        default:
            break
        }
    }

    private func endTouch(_ touch: UITouch) {
        let identity = ObjectIdentifier(touch)
        guard let playerID = touchToPlayerID.removeValue(forKey: identity),
              let index = playerIndex(for: playerID) else { return }

        players[index].touchIdentity = nil
        players[index].isFingerDown = false

        switch phase {
        case .waitingForPlayers, .countdown:
            players.remove(at: index)
            handlePregamePlayersChanged()

        case .locked:
            setNeedsFingerBackIfFingerIsUp(at: index)
            lockTask?.cancel()
            handleLockedReadinessChanged()

        case .callout:
            recordLift(for: playerID)

        case .betweenRounds:
            setNeedsFingerBackIfFingerIsUp(at: index)
            betweenRoundTask?.cancel()
            handleBetweenRoundReadinessChanged()

        case .results:
            break

        default:
            break
        }
    }

    private func handlePregamePlayersChanged() {
        countdownTask?.cancel()
        lockTask?.cancel()
        countdownValue = countdownDuration

        guard players.count >= minPlayers else {
            phase = .waitingForPlayers
            for index in players.indices {
                players[index].status = .registering
            }
            return
        }

        startCountdown()
    }

    private func startCountdown() {
        phase = .countdown
        for index in players.indices {
            players[index].status = .ready
        }

        let expectedPlayerIDs = Set(players.map(\.id))
        countdownTask = Task { [weak self] in
            guard let self else { return }

            for value in stride(from: self.countdownDuration, through: 1, by: -1) {
                self.countdownValue = value
                Haptics.light()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }

            guard self.phase == .countdown,
                  Set(self.players.map(\.id)) == expectedPlayerIDs,
                  self.players.count >= self.minPlayers,
                  self.players.allSatisfy(\.isFingerDown) else {
                self.handlePregamePlayersChanged()
                return
            }

            self.lockPlayers()
        }
    }

    private func lockPlayers() {
        countdownTask?.cancel()
        phase = .locked
        showConfetti = false

        for index in players.indices {
            players[index].status = players[index].isFingerDown ? .locked : .needsFingerBack
            players[index].isAlive = true
        }

        Haptics.medium()
        handleLockedReadinessChanged()
    }

    private func handleLockedReadinessChanged() {
        lockTask?.cancel()
        guard phase == .locked else { return }

        for index in players.indices where players[index].isAlive {
            players[index].status = players[index].isFingerDown ? .locked : .needsFingerBack
        }

        guard allAlivePlayersDown else { return }

        lockTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.lockDuration * 1_000_000_000))
            guard !Task.isCancelled,
                  self.phase == .locked,
                  self.allAlivePlayersDown else { return }
            self.startCallout()
        }
    }

    private func startCallout() {
        guard allAlivePlayersDown, alivePlayers.count > 1 else { return }

        activeItem = pickGameItem()
        answeredPlayerIDs.removeAll()
        phase = .callout

        for index in players.indices where players[index].isAlive {
            players[index].status = .locked
        }

        if let item = activeItem {
            Haptics.selection()
            SpeechService.shared.speak(item.name)
        }

        reactionTask?.cancel()
        reactionTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.reactionWindow * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.evaluatePendingAnswers()
        }
    }

    private func recordLift(for playerID: UUID) {
        guard phase == .callout,
              let item = activeItem,
              !answeredPlayerIDs.contains(playerID),
              let index = playerIndex(for: playerID),
              players[index].isAlive else { return }

        answeredPlayerIDs.insert(playerID)
        let correct = item.canFly
        players[index].status = correct ? .correct : .wrong

        if correct {
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    private func evaluatePendingAnswers() {
        guard phase == .callout, let item = activeItem else { return }

        phase = .evaluating

        for index in players.indices where players[index].isAlive {
            let playerID = players[index].id
            guard !answeredPlayerIDs.contains(playerID) else { continue }

            let correct = item.canFly ? false : players[index].isFingerDown
            players[index].status = correct ? .correct : .wrong
            answeredPlayerIDs.insert(playerID)
        }

        let anyWrong = alivePlayers.contains { $0.status == .wrong }
        if anyWrong {
            Haptics.error()
        } else {
            Haptics.success()
        }

        showResults()
    }

    private func showResults() {
        phase = .results
        resultTask?.cancel()
        resultTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.resultDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.finishResults()
        }
    }

    private func finishResults() {
        guard phase == .results else { return }

        for index in players.indices where players[index].status == .wrong {
            if let identity = players[index].touchIdentity {
                touchToPlayerID.removeValue(forKey: identity)
            }
            players[index].touchIdentity = nil
            players[index].isFingerDown = false
            players[index].isAlive = false
            players[index].status = .eliminated
        }

        let remaining = alivePlayers

        if remaining.count == 1 {
            if let winnerIndex = players.firstIndex(where: { $0.isAlive }) {
                players[winnerIndex].status = .winner
            }
            activeItem = nil
            phase = .winner
            showConfetti = true
            Haptics.success()
            return
        }

        if remaining.isEmpty {
            activeItem = nil
            phase = .allOut
            showConfetti = false
            Haptics.error()
            allOutTask?.cancel()
            allOutTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.allOutDuration * 1_000_000_000))
                guard !Task.isCancelled, self.phase == .allOut else { return }
                self.resetGame()
            }
            return
        }

        activeItem = nil
        phase = .betweenRounds
        showConfetti = false
        updateSurvivorReadinessStatuses()
        handleBetweenRoundReadinessChanged()
    }

    private func handleBetweenRoundReadinessChanged() {
        betweenRoundTask?.cancel()
        guard phase == .betweenRounds else { return }

        updateSurvivorReadinessStatuses()
        guard alivePlayers.count > 1, allAlivePlayersDown else { return }

        betweenRoundTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.betweenRoundDelay * 1_000_000_000))
            guard !Task.isCancelled,
                  self.phase == .betweenRounds,
                  self.allAlivePlayersDown else { return }
            self.startCallout()
        }
    }

    private func updateSurvivorReadinessStatuses() {
        for index in players.indices where players[index].isAlive {
            players[index].status = players[index].isFingerDown ? .ready : .needsFingerBack
        }
    }

    private func updateReadinessForFingerDownPlayer(at index: Array<GamePlayer>.Index) {
        guard players[index].isAlive, players[index].isFingerDown else { return }

        switch phase {
        case .locked:
            players[index].status = .locked
        case .betweenRounds:
            players[index].status = .ready
        default:
            break
        }
    }

    private func setNeedsFingerBackIfFingerIsUp(at index: Array<GamePlayer>.Index) {
        guard !players[index].isFingerDown else { return }
        players[index].status = .needsFingerBack
    }

    private func assignTouch(_ identity: ObjectIdentifier, at position: CGPoint, statusWhenDown: PlayerStatus) {
        guard let index = nearestAlivePlayerMissingFinger(to: position) else { return }

        players[index].touchIdentity = identity
        players[index].position = position
        players[index].isFingerDown = true
        players[index].status = statusWhenDown
        touchToPlayerID[identity] = players[index].id
        Haptics.light()
    }

    private func assignCorrectResultTouch(_ identity: ObjectIdentifier, at position: CGPoint) {
        guard let index = nearestCorrectResultPlayerMissingFinger(to: position) else { return }

        players[index].touchIdentity = identity
        players[index].position = position
        players[index].isFingerDown = true
        touchToPlayerID[identity] = players[index].id
    }

    private func nearestAlivePlayerMissingFinger(to point: CGPoint) -> Array<GamePlayer>.Index? {
        let candidates = players.indices.filter { index in
            players[index].isAlive && !players[index].isFingerDown
        }

        return candidates.min { lhs, rhs in
            distanceSquared(from: players[lhs].position, to: point) < distanceSquared(from: players[rhs].position, to: point)
        }
    }

    private func nearestCorrectResultPlayerMissingFinger(to point: CGPoint) -> Array<GamePlayer>.Index? {
        let candidates = players.indices.filter { index in
            players[index].isAlive && players[index].status == .correct && !players[index].isFingerDown
        }

        return candidates.min { lhs, rhs in
            distanceSquared(from: players[lhs].position, to: point) < distanceSquared(from: players[rhs].position, to: point)
        }
    }

    private func pickGameItem() -> GameItem {
        let pool = gameItems.filter { $0.name != lastItemName }
        let item = pool.randomElement() ?? gameItems.randomElement() ?? GameItem(name: "Bird", canFly: true)
        lastItemName = item.name
        return item
    }

    private func playerIndex(for id: UUID) -> Array<GamePlayer>.Index? {
        players.firstIndex { $0.id == id }
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private func cancelAllTasks() {
        splashTask?.cancel()
        countdownTask?.cancel()
        lockTask?.cancel()
        reactionTask?.cancel()
        resultTask?.cancel()
        betweenRoundTask?.cancel()
        allOutTask?.cancel()

        splashTask = nil
        countdownTask = nil
        lockTask = nil
        reactionTask = nil
        resultTask = nil
        betweenRoundTask = nil
        allOutTask = nil
    }
}
