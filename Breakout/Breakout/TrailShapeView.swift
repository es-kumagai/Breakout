import SwiftUI
import Foundation

// 残像形状ビュー
struct TrailShapeView: View {
	let ball: Ball
	let trailColor: Color
	let trailRotation: Angle
	let position: CGPoint
	let opacity: Double
	let index: Int
	let historyCount: Int

	var body: some View {
		Group {
			switch ball.shape {
			case .circle:
				// 丸型ボールの残像（effectiveRadiusを使用して最大サイズを制限）
				Circle()
					.fill(trailColor)
					.frame(
						width: ball.effectiveRadius * 2,
						height: ball.effectiveRadius * 2
					)
					.rotationEffect(trailRotation)
					.position(position)
					.opacity(opacity)
					.blur(radius: 2.5 + CGFloat(historyCount - index - 1) * 1.5)  // よりシャープに調整
					.blendMode(.screen)  // 加算合成で明るく輝かせる

			case .star:
				// 星型ボールの残像 - 発光効果を追加
				Star(corners: 5, smoothness: 0.45)
					.fill(trailColor)
					.frame(width: ball.radius * 3.3, height: ball.radius * 3.3)  // ボールと同じサイズ
					.rotationEffect(trailRotation)
					.position(position)
					.opacity(opacity)
					.blur(radius: 3.5 + CGFloat(historyCount - index - 1) * 1.5)  // よりシャープに調整
					.shadow(color: trailColor.opacity(0.8), radius: 5, x: 0, y: 0)  // シャドウの設定を強化
					.blendMode(.screen)

			case .oval:
				// 楕円形ボールの残像
				Ellipse()
					.fill(trailColor)
					.frame(width: ball.radius * 3.25, height: ball.radius * 1.95)  // ボールと同じサイズ
					.rotationEffect(trailRotation)
					.position(position)
					.opacity(opacity)
					.blur(radius: 3.0 + CGFloat(historyCount - index - 1) * 1.5)  // よりシャープに調整
					.blendMode(.screen)
			}
		}
	}
}