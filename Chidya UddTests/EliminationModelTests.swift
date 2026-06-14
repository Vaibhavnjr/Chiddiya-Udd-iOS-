import Foundation
import Testing
@testable import Chidya_Udd

struct EliminationModelTests {
    @Test @MainActor
    func startsInSplash() {
        let viewModel = GameViewModel()
        #expect(viewModel.visiblePlayers.isEmpty)
        #expect(viewModel.statusText.isEmpty)
        #expect(viewModel.reactionWindow == 1.0)
    }

    @Test @MainActor
    func resetRestoresInitialReactionWindow() {
        let viewModel = GameViewModel()

        viewModel.resetGame()

        #expect(viewModel.reactionWindow == GameRules.initialReactionWindow)
    }

    @Test
    func reactionWindowDecreasesToMinimumAndStops() {
        var window = GameRules.initialReactionWindow
        let expectedWindows: [TimeInterval] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4, 0.4]

        for expectedWindow in expectedWindows {
            window = GameRules.nextReactionWindow(after: window)
            #expect(window == expectedWindow)
        }
    }

    @Test
    func flyingLiftMustOccurByDeadline() {
        let deadline: TimeInterval = 100

        #expect(GameRules.isLiftCorrect(canFly: true, at: 99.999, deadline: deadline))
        #expect(GameRules.isLiftCorrect(canFly: true, at: deadline, deadline: deadline))
        #expect(!GameRules.isLiftCorrect(canFly: true, at: 100.001, deadline: deadline))
    }

    @Test
    func nonFlyingItemRequiresFingerDownThroughDeadline() {
        let deadline: TimeInterval = 100

        #expect(!GameRules.isLiftCorrect(canFly: false, at: 99.999, deadline: deadline))
        #expect(!GameRules.isLiftCorrect(canFly: false, at: deadline, deadline: deadline))
        #expect(GameRules.isLiftCorrect(canFly: false, at: 100.001, deadline: deadline))
    }
}
