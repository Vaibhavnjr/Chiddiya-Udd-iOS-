import SwiftUI
import UIKit

struct TouchCaptureView: UIViewRepresentable {
    @ObservedObject var viewModel: GameViewModel

    func makeUIView(context: Context) -> TouchView {
        let v = TouchView()
        v.viewModel = viewModel
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: TouchView, context: Context) {
        uiView.viewModel = viewModel
    }

    final class TouchView: UIView {
        weak var viewModelRef: GameViewModel?
        var viewModel: GameViewModel {
            get { viewModelRef! }
            set { viewModelRef = newValue }
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let vm = viewModelRef else { return }
            vm.beginTouches(touches, in: self)
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let vm = viewModelRef else { return }
            vm.moveTouches(touches, in: self)
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let vm = viewModelRef else { return }
            vm.endTouches(touches)
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let vm = viewModelRef else { return }
            vm.endTouches(touches)
        }
    }
}
