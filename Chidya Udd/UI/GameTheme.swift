import SwiftUI

enum GameTheme {
    static let cornerRadius: CGFloat = 20

    static let background = Color(hex: "62CEB5")
    static let primary = Color(hex: "ED2126")
    static let surface = Color(hex: "FFFFFF")

    static let textPrimary = Color(hex: "1F2328")
    static let textSecondary = Color(hex: "1F2328").opacity(0.68)
    static let textOnPrimary = Color(hex: "FFFFFF")
    static let textOnSurface = Color(hex: "1F2328")

    static let success = Color(hex: "16A34A")
    static let warning = Color(hex: "FFD54A")
    static let error = Color(hex: "ED2126")

    static let border = Color(hex: "FFFFFF").opacity(0.64)
    static let shadow = Color(hex: "1F2328").opacity(0.16)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
