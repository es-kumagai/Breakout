import SwiftUI

// レーザー表示ビュー
struct LaserView: View {
	let laser: Laser

	var body: some View {
		ZStack {
			// 先に残像表示（背面）
			ForEach(0..<laser.positionHistory.count, id: \.self) { index in
				laserTrailView(at: laser.positionHistory[index], index: index)
			}

			// 後からメインのレーザービーム（前面）
			mainLaserView()
				.position(laser.position)
		}
	}

	// レーザーの残像
	@ViewBuilder
	private func laserTrailView(at position: CGPoint, index: Int) -> some View {
		// 残像のインデックスを0.0〜1.0の範囲に正規化
		let normalizedIndex = Double(index) / Double(max(1, laser.positionHistory.count - 1))

		// 履歴の番号に基づいて透明度を計算（より薄く）
		let trailOpacity = 0.08 + normalizedIndex * 0.12  // 0.08から0.2の範囲に低下

		// 残像のサイズを固定（0.7倍）
		let sizeMultiplier: CGFloat = 0.7

		VStack(spacing: 0) {
			// レーザー本体の残像
			Rectangle()
				.fill(laser.color.opacity(0.7))  // 基本的な不透明度を下げる
				.frame(
					width: laser.size.width * sizeMultiplier,
					height: laser.size.height * sizeMultiplier
				)

			// 残像の発光効果
			Rectangle()
				.fill(
					LinearGradient(
						gradient: Gradient(colors: [
							laser.color.opacity(0.6),
							Color.orange.opacity(0.4)
						]),
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.frame(
					width: laser.size.width * sizeMultiplier * 0.6,
					height: laser.size.height * sizeMultiplier * 0.3
				)
				.offset(y: -laser.size.height * sizeMultiplier * 0.15)
		}
		.position(position)
		.opacity(trailOpacity)
		.blur(radius: 1.0 + (1.0 - normalizedIndex) * 1.5)  // 古い残像ほどぼかす（より弱く）
	}

	// メインのレーザービーム
	@ViewBuilder
	private func mainLaserView() -> some View {
		VStack(spacing: 0) {
			// レーザービーム本体
			Rectangle()
				.fill(laser.color)
				.frame(width: laser.size.width, height: laser.size.height)

			// レーザーの発光効果
			Rectangle()
				.fill(
					LinearGradient(
						gradient: Gradient(colors: [.red, .orange]),
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.frame(width: laser.size.width * 0.6, height: laser.size.height * 0.3)
				.offset(y: -laser.size.height * 0.15)
		}
		// グロー効果を追加
		.shadow(color: .red.opacity(0.8), radius: 3, x: 0, y: 0)
	}
}
