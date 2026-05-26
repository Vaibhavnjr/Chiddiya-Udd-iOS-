import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.92
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(GameTheme.primary)

                Text("Chiddya Udd")
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
        .accessibilityLabel("Chiddya Udd")
    }
}
