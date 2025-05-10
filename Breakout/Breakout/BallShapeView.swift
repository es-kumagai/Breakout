import SwiftUI

// メインのボール形状ビュー
struct BallShapeView: View {
	let ball: Ball

	var body: some View {
		Group {
			switch ball.shape {
			case .circle:
				// 丸型ボール（成長係数を適用）
				Circle()
					.foregroundColor(ball.color)
					.frame(
						width: (ball.radius + ball.growthFactor) * 2,
						height: (ball.radius + ball.growthFactor) * 2
					)
					.rotationEffect(ball.rotation)
					.position(ball.position)

			case .star:
				// 星型ボール - サイズを1.5倍に拡大
				Star(corners: 5, smoothness: 0.45)
					.foregroundColor(ball.color)
					.frame(width: ball.radius * 3.3, height: ball.radius * 3.3)  // 2.2 * 1.5 = 3.3
					.rotationEffect(ball.rotation)
					.position(ball.position)

			case .oval:
				// 楕円形ボール - サイズを1.3倍に拡大
				Ellipse()
					.foregroundColor(ball.color)
					.frame(width: ball.radius * 3.25, height: ball.radius * 1.95)  // 2.5 * 1.3 = 3.25, 1.5 * 1.3 = 1.95
					.rotationEffect(ball.rotation)
					.position(ball.position)
			}
		}
	}
}