import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.92
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            GameTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                BirdMark(size: 72)

                Text("Chiddiya Udd")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.textPrimary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    scale = 1
                    opacity = 1
                }
            }
        }
        .accessibilityLabel("Chiddiya Udd bird logo")
    }
}
