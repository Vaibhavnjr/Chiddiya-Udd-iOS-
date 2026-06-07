import SwiftUI

struct CustomStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(GameTheme.textPrimary)
            
            Spacer()
            
            HStack(spacing: 0) {
                Button {
                    if value > range.lowerBound {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            value -= 1
                        }
                        Haptics.light()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(value > range.lowerBound ? GameTheme.textPrimary : GameTheme.textSecondary.opacity(0.3))
                
                Text("\(value)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .frame(width: 40)
                    .foregroundStyle(GameTheme.primary)
                
                Button {
                    if value < range.upperBound {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            value += 1
                        }
                        Haptics.light()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(value < range.upperBound ? GameTheme.textPrimary : GameTheme.textSecondary.opacity(0.3))
            }
            .background(GameTheme.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(GameTheme.border, lineWidth: 1)
            )
        }
    }
}
