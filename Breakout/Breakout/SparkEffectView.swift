import SwiftUI

// 衝撃波の光線エフェクト
struct SparkEffectView: View {
	let angle: Double
	let progress: Double
	let color: Color
	let sparkLength: CGFloat = 50

	var body: some View {
		let distance = CGFloat(progress) * sparkLength
		let startPoint = CGPoint(x: 0, y: 0)
		let endPoint = CGPoint(
			x: startPoint.x + sin(angle) * distance,
			y: startPoint.y - cos(angle) * distance
		)

		Path { path in
			path.move(to: startPoint)
			path.addLine(to: endPoint)
		}
		.stroke(
			LinearGradient(
				gradient: Gradient(colors: [color, color.opacity(0)]),
				startPoint: .leading,
				endPoint: .trailing
			),
			style: StrokeStyle(
				lineWidth: 3 - CGFloat(progress) * 2, lineCap: .round, lineJoin: .round)
		)
		.blur(radius: 2)
		.opacity(1 - progress * 0.5)
		.position(x: CGFloat(GameState.frameWidth) / 2, y: CGFloat(GameState.frameHeight) - 30)
	}
}
