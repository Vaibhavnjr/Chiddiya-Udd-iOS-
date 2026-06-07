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
        
        let colors: [UIColor] = [
            UIColor(red: 237 / 255, green: 33 / 255, blue: 38 / 255, alpha: 1),
            UIColor(red: 98 / 255, green: 206 / 255, blue: 181 / 255, alpha: 1),
            UIColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 1),
            UIColor(red: 255 / 255, green: 213 / 255, blue: 74 / 255, alpha: 1),
            UIColor(red: 31 / 255, green: 35 / 255, blue: 40 / 255, alpha: 1)
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

