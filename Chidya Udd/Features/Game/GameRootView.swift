import SwiftUI

struct GameRootView: View {
    @StateObject private var viewModel: GameViewModel

    init() {
        _viewModel = StateObject(wrappedValue: GameViewModel())
    }

    init(viewModel: GameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.phase == .splash {
                SplashView()
            } else {
                gameContent
            }
        }
        .onAppear {
            viewModel.startSplashIfNeeded()
        }
        .preferredColorScheme(.light)
    }

    private var gameContent: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            TouchCaptureView(viewModel: viewModel)
                .ignoresSafeArea()

            DynamicPlayerCirclesLayer(
                players: viewModel.visiblePlayers,
                phase: viewModel.phase
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.top, 18)

                Spacer(minLength: 40)

                centerContent
                    .padding(.horizontal, 28)
                    .allowsHitTesting(false)

                Spacer(minLength: 28)

                statusFooter
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                    .allowsHitTesting(false)
            }

            if viewModel.phase == .allOut {
                allOutOverlay
                    .allowsHitTesting(false)
            }

            if viewModel.phase == .winner {
                WinnerView(playAgain: viewModel.resetGame)
            }

            if viewModel.showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(GameTheme.primary)

            Text("Chiddya Udd")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var centerContent: some View {
        switch viewModel.phase {
        case .waitingForPlayers:
            Text("Put fingers to start game")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(GameTheme.textPrimary)

        case .countdown:
            VStack(spacing: 10) {
                Text("\(viewModel.countdownValue)")
                    .font(.system(size: 118, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.primary)
                    .contentTransition(.numericText())

                Text("Hold steady")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GameTheme.textSecondary)
            }

        case .locked:
            Text(viewModel.allAlivePlayersDown ? "Get ready..." : "Put fingers back")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(GameTheme.textPrimary)

        case .callout, .evaluating, .results:
            Text(viewModel.activeItem?.name ?? "")
                .font(.system(size: 68, weight: .black, design: .rounded))
                .minimumScaleFactor(0.58)
                .lineLimit(1)
                .foregroundStyle(GameTheme.textPrimary)
                .shadow(color: GameTheme.secondary.opacity(0.16), radius: 18, x: 0, y: 8)

        case .betweenRounds:
            Text(viewModel.statusText)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(GameTheme.textPrimary)

        case .allOut:
            Text("Everyone got out!")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

        case .winner:
            EmptyView()

        case .splash:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        if !viewModel.statusText.isEmpty && viewModel.phase != .allOut {
            Text(viewModel.statusText)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(GameTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            Color.clear
                .frame(height: 44)
        }
    }

    private var allOutOverlay: some View {
        Color(hex: "252A34")
            .opacity(0.92)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 70, weight: .black))
                        .foregroundStyle(GameTheme.primary)

                    Text("Everyone got out!")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
                .padding(28)
            }
    }
}

private struct DynamicPlayerCirclesLayer: View {
    let players: [GamePlayer]
    let phase: GamePhase

    var body: some View {
        GeometryReader { proxy in
            let diameter = circleDiameter(for: players.count, in: proxy.size)

            ZStack {
                ForEach(players) { player in
                    PlayerTouchCircle(
                        player: player,
                        phase: phase,
                        diameter: diameter
                    )
                    .position(player.position)
                    .transition(.scale(scale: 0.58).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: players)
        }
    }

    private func circleDiameter(for count: Int, in size: CGSize) -> CGFloat {
        let shortestSide = min(size.width, size.height)
        let divisor: CGFloat

        switch count {
        case 0...1:
            divisor = 3.25
        case 2:
            divisor = 3.65
        case 3:
            divisor = 4.05
        case 4:
            divisor = 4.45
        default:
            divisor = 4.8
        }

        return min(134, max(84, shortestSide / divisor))
    }
}

private struct PlayerTouchCircle: View {
    let player: GamePlayer
    let phase: GamePhase
    let diameter: CGFloat

    @State private var ripple = false

    var body: some View {
        ZStack {
            if showsRipple {
                Circle()
                    .stroke(GameTheme.secondary.opacity(0.34), lineWidth: 8)
                    .frame(width: diameter * 1.35, height: diameter * 1.35)
                    .scaleEffect(ripple ? 1.22 : 0.72)
                    .opacity(ripple ? 0 : 0.72)
                    .animation(.easeOut(duration: 1.05).repeatForever(autoreverses: false), value: ripple)
            }

            Circle()
                .fill(fillColor)
                .frame(width: diameter, height: diameter)
                .overlay(circleStroke)
                .shadow(color: shadowColor, radius: 14, x: 0, y: 8)
                .scaleEffect(scale)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: diameter * 0.36, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .opacity(opacity)
        .onAppear {
            ripple = true
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.74), value: player.status)
        .animation(.easeInOut(duration: 0.18), value: player.position)
    }

    private var showsRipple: Bool {
        player.isFingerDown && (phase == .waitingForPlayers || phase == .countdown)
    }

    private var fillColor: Color {
        switch player.status {
        case .correct, .winner:
            return Color(hex: "18A058")
        case .wrong:
            return Color(hex: "E5484D")
        case .needsFingerBack:
            return Color.white.opacity(0.64)
        case .locked:
            return GameTheme.accent
        case .ready:
            return GameTheme.secondary
        case .registering:
            return GameTheme.primary
        case .eliminated:
            return Color.clear
        }
    }

    @ViewBuilder
    private var circleStroke: some View {
        if player.status == .needsFingerBack {
            Circle()
                .stroke(
                    GameTheme.warning,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 8])
                )
        } else {
            Circle()
                .stroke(Color.white.opacity(0.78), lineWidth: 3)
        }
    }

    private var symbol: String? {
        switch player.status {
        case .correct, .winner:
            return "checkmark"
        case .wrong:
            return "xmark"
        default:
            return nil
        }
    }

    private var scale: CGFloat {
        switch player.status {
        case .wrong:
            return phase == .results ? 1.08 : 1
        case .correct, .winner:
            return 1.08
        case .needsFingerBack:
            return 0.92
        default:
            return 1
        }
    }

    private var opacity: Double {
        player.status == .needsFingerBack ? 0.68 : 1
    }

    private var shadowColor: Color {
        switch player.status {
        case .needsFingerBack:
            return .clear
        case .wrong:
            return Color(hex: "E5484D").opacity(0.24)
        case .correct, .winner:
            return Color(hex: "18A058").opacity(0.24)
        default:
            return Color.black.opacity(0.14)
        }
    }
}

private struct WinnerView: View {
    let playAgain: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "18A058")
                .ignoresSafeArea()

            BirdFlockView()
                .opacity(0.22)
                .allowsHitTesting(false)

            VStack(spacing: 26) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 86, weight: .black))
                    .foregroundStyle(.white)

                Text("You Win")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Button(action: playAgain) {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "18A058"))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 15)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(30)
        }
    }
}

private struct BirdFlockView: View {
    private let positions: [(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double)] = [
        (0.14, 0.16, 34, -18),
        (0.82, 0.14, 28, 22),
        (0.26, 0.32, 24, 10),
        (0.72, 0.38, 38, -10),
        (0.12, 0.64, 30, 18),
        (0.86, 0.66, 26, -24),
        (0.36, 0.82, 36, 16),
        (0.68, 0.86, 24, -8)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(positions.indices, id: \.self) { index in
                let item = positions[index]
                Image(systemName: "bird.fill")
                    .font(.system(size: item.size, weight: .black))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(item.rotation))
                    .position(
                        x: proxy.size.width * item.x,
                        y: proxy.size.height * item.y
                    )
            }
        }
    }
}
