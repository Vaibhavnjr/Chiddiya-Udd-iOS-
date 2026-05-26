import SwiftUI
import QuartzCore

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -50)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)
        
        // Vibrant colors from GameTheme
        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.18, blue: 0.39, alpha: 1.0), // Primary (Pink/Red)
            UIColor(red: 0.03, green: 0.85, blue: 0.84, alpha: 1.0), // Secondary (Cyan)
            UIColor(red: 0.0, green: 0.68, blue: 0.71, alpha: 1.0),  // Success (Teal)
            UIColor(red: 1.0, green: 0.76, blue: 0.03, alpha: 1.0),  // Warning (Amber)
            UIColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)     // Purple Accent
        ]
        
        let cells: [CAEmitterCell] = colors.flatMap { color in
            // Create two shapes per color: Rectangle and Square
            return [
                createConfettiCell(color: color, image: createConfettiImage(color: color, size: CGSize(width: 12, height: 6))),
                createConfettiCell(color: color, image: createConfettiImage(color: color, size: CGSize(width: 8, height: 8)))
            ]
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        
        // Stop emitting after a short burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emitter.birthRate = 0
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    private func createConfettiCell(color: UIColor, image: CGImage?) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 20
        cell.lifetime = 10.0
        cell.velocity = 200
        cell.velocityRange = 100
        cell.yAcceleration = 150 // Gravity
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 4
        cell.spin = 3.5
        cell.spinRange = 1.0
        cell.scale = 0.5
        cell.scaleRange = 0.2
        cell.contents = image
        return cell
    }
    
    private func createConfettiImage(color: UIColor, size: CGSize) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.cgImage
    }
}


