import SwiftUI

// パドル衝突エフェクトビュー
struct PaddleHitEffectView: View {
	@EnvironmentObject private var gameState: GameState
	@State private var animationProgress: Double = 0

	var body: some View {
		ZStack {
			// パドルの形状に合わせたエフェクト
			Rectangle()
				.fill(
					LinearGradient(
						gradient: Gradient(colors: [
							gameState.paddleHitEffectColor,
							gameState.paddleHitEffectColor.opacity(0.3),
						]),
						startPoint: .center,
						endPoint: .trailing
					)
				)
				.frame(
					width: gameState.paddle.size.width * (1 + animationProgress * 0.3),
					height: gameState.paddle.size.height * (1 + animationProgress * 0.5)
				)
				.position(gameState.paddle.position)
				.opacity(1 - animationProgress * 0.8)
				.blur(radius: 3 + animationProgress * 10)

			// 光線が飛び散る効果
			ForEach(0..<8, id: \.self) { i in
				SparkEffectView(
					angle: Double(i) * .pi / 4, progress: animationProgress,
					color: gameState.paddleHitEffectColor)
			}

			// パドルをハイライト
			Rectangle()
				.fill(gameState.paddleHitEffectColor.opacity(0.8 - animationProgress * 0.8))
				.frame(width: gameState.paddle.size.width, height: gameState.paddle.size.height)
				.position(gameState.paddle.position)
				.blur(radius: 2)
		}
		.onAppear {
			// アニメーション開始
			withAnimation(.easeOut(duration: 0.6)) {
				animationProgress = 1.0
			}
		}
	}
}
