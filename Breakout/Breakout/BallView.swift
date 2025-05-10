import SwiftUI

// ボールのビュー（パフォーマンス最適化版）
struct BallView: View {
	let ball: Ball

	var body: some View {
		// 最適化：レイヤー数をまとめてZStackを減らす
		ZStack {
			// 残像（パフォーマンス向上のため最大5つに制限）
			ForEach(max(0, ball.positionHistory.count - 5)..<ball.positionHistory.count, id: \.self) { i in
				trailShape(index: i)
				// ブレンドモードはdrawingGroupで効率化するため個別設定せず、親で一括して適用
			}

			// ボール本体
			mainBallShape()
		}
		// 全体にブレンドモードを適用して視覚効果を高める
		.blendMode(.screen)
	}

	// メインのボール形状 - より最適化
	@ViewBuilder
	private func mainBallShape() -> some View {
		Group {
			switch ball.shape {
			case .star:
				// 星型 - 形状を簡略化
				Star(corners: 5, smoothness: 0.45)
					.fill(ball.color)
					.frame(width: ball.radius * 3, height: ball.radius * 3)
					.rotationEffect(ball.rotation)

			case .circle:
				// 円型 - シンプルな形状
				Circle()
					.fill(ball.color)
					.frame(width: ball.effectiveRadius * 2, height: ball.effectiveRadius * 2)

			case .oval:
				// 楕円型 - シンプルな形状
				Ellipse()
					.fill(ball.color)
					.frame(width: ball.radius * 3, height: ball.radius * 1.5)
					.rotationEffect(ball.rotation)
			}
		}
		.overlay(ballCounterView())
		.position(ball.position)
		// シャドウを簡略化
		.shadow(color: ball.color.opacity(0.8), radius: 3)
	}

	// ボールのカウンター表示（必要な場合のみ）
	@ViewBuilder
	private func ballCounterView() -> some View {
		Group {
			if ball.shape == .star && ball.comboCount > 0 && !ball.isMoving {
				Text("\(ball.comboCount)/\(7)")
					.font(.system(size: 10, weight: .bold))
					.foregroundColor(.white)
					.offset(y: -ball.radius * 2.5)
			} else if ball.shape == .star && ball.comboCount > 0 {
				// 移動中の星型ボールは簡易表示
				HStack(alignment: .bottom, spacing: 4) {
					Text("\(ball.comboCount)")
						.font(.system(size: 13, weight: .bold))
					Text("COMBO!")
						.font(.system(size: 10, weight: .bold))
				}
				.foregroundColor(.white)
				.background(
					Circle().fill(Color.black.opacity(0.5))
						.frame(height: 14)
				)
				.offset(y: -ball.radius * 3.0)
				.fixedSize()
				.lineLimit(1)
			}
		}
	}

	// 残像の形状 - パフォーマンス最適化
	@ViewBuilder
	private func trailShape(index: Int) -> some View {
		let normalizedIndex =
			CGFloat(index - max(0, ball.positionHistory.count - 5))
			/ min(CGFloat(5), CGFloat(ball.positionHistory.count))
		let opacity = 0.1 + normalizedIndex * 0.2  // 0.1〜0.3の範囲

		Group {
			switch ball.shape {
			case .star:
				// 星型の残像 - より軽量化
				Star(corners: 5, smoothness: 0.45)
					.fill(ball.color.opacity(opacity))
					.frame(width: ball.radius * 3 * 0.7, height: ball.radius * 3 * 0.7)
					.rotationEffect(ball.rotation - Angle(degrees: Double(index) * 5))

			case .circle:
				// 円型の残像 - より軽量化
				Circle()
					.fill(ball.color.opacity(opacity))
					.frame(
						width: ball.effectiveRadius * 2 * 0.9,
						height: ball.effectiveRadius * 2 * 0.9)

			case .oval:
				// 楕円型の残像 - より軽量化
				Ellipse()
					.fill(ball.color.opacity(opacity))
					.frame(width: ball.radius * 3 * 0.7, height: ball.radius * 1.5 * 0.7)
					.rotationEffect(ball.rotation - Angle(degrees: Double(index) * 5))
			}
		}
		.position(ball.positionHistory[index])
		// ぼかし効果を単純化してパフォーマンス向上
		.blur(radius: 1.5)
	}
}