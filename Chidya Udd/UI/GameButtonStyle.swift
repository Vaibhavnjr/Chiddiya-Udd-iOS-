import SwiftUI

struct GameButtonStyle: ButtonStyle {
    var color: Color = GameTheme.primary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(GameTheme.textOnPrimary)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: GameTheme.cornerRadius, style: .continuous)
                    .fill(color)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
