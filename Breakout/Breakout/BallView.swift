import SwiftUI
import Foundation

// ボールのビュー（パフォーマンス最適化版）
struct BallView: View {
	let ball: Ball

	var body: some View {
		// 画面外のボールは非表示（復活カウントダウン中、または明らかに画面外の場合）
		if isOffScreen(ball.position) {
			EmptyView()
		} else {
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
	}

	// ボールが画面外かどうかを判定するヘルパーメソッド
	private func isOffScreen(_ position: CGPoint) -> Bool {
		// 復活カウントダウン中は常に非表示
		if ball.reviveCountdown != nil {
			return true
		}
		
		// 画面の表示領域よりかなり外側にあるボールは非表示
		// 半径の3倍分のマージンを持たせる
		let margin = ball.effectiveRadius * 3
		return position.x < -margin ||
			   position.x > GameState.frameWidth + margin ||
			   position.y < -margin ||
			   position.y > GameState.frameHeight + margin
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
		.overlay(reviveEffectView()) // 復活エフェクトを追加
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

	// 復活エフェクト - 復活アニメーション中のみ表示
	@ViewBuilder
	private func reviveEffectView() -> some View {
		if ball.isReviving {
			// 半径は実際のボールより大きく
			let pulseRadius = ball.effectiveRadius * 2.5
			
			// 復活アニメーション進行に応じて透明度を計算（点滅効果）
			let baseOpacity = 0.2 + 0.8 * sin(Double(ball.reviveProgress) * .pi * 4)
			
			// エフェクト表示：周囲に輝くリング
			Circle()
				.strokeBorder(
					LinearGradient(
						colors: [
							ball.color.opacity(baseOpacity),
							ball.color.opacity(baseOpacity * 0.2)
						],
						startPoint: .top,
						endPoint: .bottom
					),
					lineWidth: 3
				)
				.frame(width: pulseRadius * 2, height: pulseRadius * 2)
				.scaleEffect(1.0 + 0.2 * sin(Double(ball.reviveProgress) * .pi * 6))
				// 回転効果を追加（時計回り）
				.rotationEffect(Angle(degrees: Double(ball.reviveProgress) * 360))
				.blendMode(.screen) // 発光効果
		}
	}

	// 残像の形状 - パフォーマンス最適化
	@ViewBuilder
	private func trailShape(index: Int) -> some View {
		// 画面外の残像は表示しない
		if index < ball.positionHistory.count && !isOffScreen(ball.positionHistory[index]) {
			let normalizedIndex = CGFloat(index - max(0, ball.positionHistory.count - 5))
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
		} else {
			// 画面外の残像は何も表示しない
			EmptyView()
		}
	}
}