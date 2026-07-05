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
            GameTheme.background.ignoresSafeArea()

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
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)

                Spacer(minLength: 28)

                statusFooter
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                    .allowsHitTesting(false)
            }

            timingIndicator
                .allowsHitTesting(false)

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
            BirdMark(size: 22)

            Text("Chiddiya Udd")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(GameTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private var timingIndicator: some View {
        VStack {
            Text("Reaction: \(formattedReactionWindow)  ·  Voice: \(formattedSpeechRate)x")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(GameTheme.textSecondary)
                .padding(.top, 58)

            Spacer()
        }
    }

    private var formattedReactionWindow: String {
        let tenths = Int((viewModel.reactionWindow * 10).rounded())
        return "\(tenths / 10).\(tenths % 10)s"
    }

    private var formattedSpeechRate: String {
        let formatted = String(format: "%.2f", viewModel.speechRate)
        return formatted
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    @ViewBuilder
    private var centerContent: some View {
        ZStack {
            switch viewModel.phase {
            case .waitingForPlayers:
                GameText(text: "Put fingers to start game", size: 30, maxLines: 2)
                    .frame(maxWidth: 240)

            case .countdown:
                VStack(spacing: 10) {
                    GameText(text: "\(viewModel.countdownValue)", size: 118, color: GameTheme.primary)
                        .contentTransition(.numericText())

                    GameText(text: "Hold steady", size: 22, weight: .bold, color: GameTheme.textSecondary)
                }

            case .locked:
                GameText(text: viewModel.allAlivePlayersDown ? "Get ready..." : "Put fingers back", size: 34, maxLines: 2)

            case .callout, .evaluating, .results:
                EmptyView()

            case .betweenRounds:
                GameText(text: viewModel.statusText, size: 30, maxLines: 2)

            case .allOut, .winner, .splash:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
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
        GameTheme.textPrimary
            .opacity(0.92)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(GameTheme.primary)
                            .frame(width: 70, height: 70)
                        XMarkShape()
                            .stroke(GameTheme.textPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 34, height: 34)
                    }

                    Text("Everyone got out!")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(GameTheme.textOnPrimary)
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
                    .stroke(GameTheme.surface.opacity(0.42), lineWidth: 8)
                    .frame(width: diameter * 1.35, height: diameter * 1.35)
                    .scaleEffect(ripple ? 1.22 : 0.72)
                    .opacity(ripple ? 0 : 0.72)
                    .animation(.easeOut(duration: 1.05).repeatForever(autoreverses: false), value: ripple)
            }

            Circle()
                .fill(fillColor)
                .frame(width: diameter, height: diameter)
                .overlay(circleStroke)
                .shadow(color: shadowColor, radius: 7, x: 0, y: 8)
                .scaleEffect(scale)

            if let symbol {
                if symbol == "check" {
                    CheckMarkShape()
                        .stroke(symbolColor, style: StrokeStyle(lineWidth: diameter * 0.058, lineCap: .round, lineJoin: .round))
                        .frame(width: diameter * 0.36, height: diameter * 0.36)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    XMarkShape()
                        .stroke(symbolColor, style: StrokeStyle(lineWidth: diameter * 0.058, lineCap: .round, lineJoin: .round))
                        .frame(width: diameter * 0.36, height: diameter * 0.36)
                        .transition(.scale.combined(with: .opacity))
                }
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
            return GameTheme.surface
        case .wrong:
            return GameTheme.error
        case .needsFingerBack:
            return GameTheme.surface.opacity(0.62)
        case .locked:
            return GameTheme.textPrimary
        case .ready:
            return GameTheme.surface.opacity(0.86)
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
        } else if player.status == .correct || player.status == .winner {
            Circle()
                .stroke(GameTheme.success, lineWidth: 4)
        } else if player.status == .eliminated {
            EmptyView()
        } else {
            Circle()
                .stroke(GameTheme.border, lineWidth: 3)
        }
    }

    private var symbol: String? {
        switch player.status {
        case .correct, .winner:
            return "check"
        case .wrong:
            return "x"
        default:
            return nil
        }
    }

    private var symbolColor: Color {
        switch player.status {
        case .correct, .winner:
            return GameTheme.success
        case .wrong:
            return GameTheme.textOnPrimary
        default:
            return GameTheme.textOnPrimary
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
        case .needsFingerBack, .eliminated:
            return .clear
        case .correct, .winner:
            return GameTheme.success.opacity(0.34)
        case .registering, .wrong:
            return .clear
        default:
            return GameTheme.shadow
        }
    }

}

struct BirdMark: View {
    let size: CGFloat

    var body: some View {
        BirdMarkShape()
            .fill(GameTheme.primary)
            .frame(width: size, height: size)
    }
}

private struct BirdMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.62))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY + rect.height * 0.55),
            control: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.12)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.36),
            control: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.25)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.72),
            control: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.56)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.62),
            control: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.94)
        )
        path.closeSubpath()
        return path
    }
}

private struct GameText: View {
    let text: String
    let size: CGFloat
    var weight: Font.Weight = .black
    var color: Color = GameTheme.textPrimary
    var maxLines: Int = 1

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(maxLines)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct CheckMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.84))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.98, y: rect.minY + rect.height * 0.14))
        return path
    }
}

private struct XMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

private struct WinnerView: View {
    let playAgain: () -> Void

    var body: some View {
        ZStack {
            GameTheme.background
                .ignoresSafeArea()

            BirdFlockView()
                .opacity(0.18)
                .allowsHitTesting(false)

            VStack(spacing: 26) {
                BirdMark(size: 86)

                Text("You Win")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(GameTheme.textOnSurface)

                Button(action: playAgain) {
                    Text("Play Again")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(GameTheme.textOnPrimary)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 15)
                        .background(GameTheme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(30)
            .padding(.vertical, 14)
            .background(
                GameTheme.surface.opacity(0.94),
                in: RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .shadow(color: GameTheme.shadow, radius: 24, x: 0, y: 12)
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
                Circle()
                    .fill(GameTheme.surface)
                    .frame(width: item.size, height: item.size)
                    .position(
                        x: proxy.size.width * item.x,
                        y: proxy.size.height * item.y
                    )
            }
        }
    }
}
