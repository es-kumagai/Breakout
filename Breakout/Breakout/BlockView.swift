import SwiftUI

// BlockViewの最適化
struct BlockView: View {
	let block: Block
	@State private var rainbowPhase: Double = 0
	@State private var scaleEffect: CGFloat = 1.0
	@State private var opacity: Double = 1.0
	@State private var pulseOpacity: Double = 0.0

	// 衝突後すぐに元のブロックを非表示にするためのフラグ
	@State private var showOriginalBlock: Bool = true

	var body: some View {
		Group {
			// アニメーションするブロック
			if block.isAnimating {
				ZStack {
					// 最も外側の眩しい発光レイヤー（白）- 最適化のためレンダリング条件を追加
					if pulseOpacity > 0.1 {
						RoundedRectangle(cornerRadius: 6)
							.fill(Color.white)
							.frame(width: block.size.width * 1.5, height: block.size.height * 1.5)
							.position(block.position)
							.blur(radius: 15)
							.opacity(pulseOpacity * 0.7)
							.scaleEffect(scaleEffect + 0.2)
							.zIndex(12)
					}

					// 中間の発光レイヤー - 内部のdrawingGroup()を削除
					RoundedRectangle(cornerRadius: 5)
						.fill(brightRainbowGradient)
						.frame(width: block.size.width * 1.4, height: block.size.height * 1.4)
						.position(block.position)
						.blur(radius: 10)
						.opacity(opacity * 0.9)
						.scaleEffect(scaleEffect + 0.1)
						.zIndex(11)

					// 虹色の輝くエフェクト（メイン）
					RoundedRectangle(cornerRadius: 4)
						.fill(rainbowGradient)
						.frame(width: block.size.width * 1.3, height: block.size.height * 1.3)
						.position(block.position)
						.blur(radius: 8)
						.opacity(opacity)
						.scaleEffect(scaleEffect)
						.shadow(color: .white.opacity(0.8), radius: 15, x: 0, y: 0)
						.animation(.easeInOut(duration: 0.7), value: scaleEffect)
						.animation(.easeInOut(duration: 0.7), value: opacity)
						.zIndex(10)  // 虹色エフェクトを最前面に
				}
				.onAppear {
					// 元のブロックをすぐに非表示 - 高速化のため遅延を減少
					withAnimation(.easeOut(duration: 0.05)) {
						showOriginalBlock = false
					}

					// 虹色の回転アニメーション - パフォーマンス重視で最適化
					withAnimation(.linear(duration: 0.4).repeatForever(autoreverses: false)) {
						rainbowPhase = 360
					}

					// パルス効果のアニメーション - 回数減少でパフォーマンス向上
					withAnimation(.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)) {
						pulseOpacity = 0.9
					}

					// ブロックが消えるアニメーション - 高速化
					withAnimation(.easeInOut(duration: 0.6)) {
						scaleEffect = 1.7
						opacity = 0
					}
				}
			}
			// 通常のブロック表示（アニメーション開始時にすぐ非表示）
			else {
				RoundedRectangle(cornerRadius: 4)
					.fill(block.color)
					.frame(width: block.size.width, height: block.size.height)
					.position(block.position)
					.scaleEffect(block.isAppearing ? 0.01 : 1.0)  // 出現アニメーション
					.opacity(block.isAppearing ? 0.0 : 1.0)  // 出現時フェードイン
					.animation(
						.spring(response: 0.3, dampingFraction: 0.6), value: block.isAppearing
					)
					.zIndex(1)  // 元のブロックは背面に
			}
		}
	}

	// 虹色のグラデーション - 最適化して処理を軽量化
	var rainbowGradient: AngularGradient {
		AngularGradient(
			gradient: Gradient(colors: [
				.red, .orange, .yellow, .green, .blue, .purple, .pink, .red,
			]),
			center: .center,
			startAngle: .degrees(rainbowPhase),
			endAngle: .degrees(rainbowPhase + 360)
		)
	}

	// より明るい虹色のグラデーション - 色数を削減して最適化
	var brightRainbowGradient: AngularGradient {
		AngularGradient(
			gradient: Gradient(colors: [
				Color.red.opacity(1.5), Color.yellow.opacity(1.8),
				Color.green.opacity(1.6), Color.blue.opacity(1.6),
				Color.purple.opacity(1.6), Color.red.opacity(1.5),
			]),
			center: .center,
			startAngle: .degrees(rainbowPhase + 30),  // オフセットを付けて動きを出す
			endAngle: .degrees(rainbowPhase + 390)
		)
	}
}