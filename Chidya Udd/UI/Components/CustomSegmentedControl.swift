import SwiftUI

struct CustomSegmentedControl<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [(T, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(GameTheme.textPrimary)
            
            HStack(spacing: 0) {
                ForEach(options, id: \.0) { option in
                    let isSelected = selection == option.0
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = option.0
                        }
                        Haptics.selection()
                    } label: {
                        Text(option.1)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundStyle(isSelected ? GameTheme.textOnPrimary : GameTheme.textSecondary)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(GameTheme.primary)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                    )
                }
            }
            .padding(4)
            .background(GameTheme.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(GameTheme.border, lineWidth: 1)
            )
        }
    }
    
    @Namespace private var namespace
}
