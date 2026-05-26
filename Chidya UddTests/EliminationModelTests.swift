import Testing
@testable import Chidya_Udd

struct EliminationModelTests {
    @Test @MainActor
    func startsInSplash() {
        let viewModel = GameViewModel()
        #expect(viewModel.visiblePlayers.isEmpty)
        #expect(viewModel.statusText.isEmpty)
    }
}
