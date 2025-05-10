import SwiftUI

// 星形状を描画するためのView - 改良版
struct Star: Shape {
	let corners: Int
	let smoothness: CGFloat

	func path(in rect: CGRect) -> Path {
		guard corners >= 2 else { return Path() }

		let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
		let outerRadius = min(rect.width, rect.height) / 2
		let innerRadius = outerRadius * 0.5  // 内側と外側の比率を調整（0.4→0.5）

		// 星形の各頂点の角度を計算
		let angleIncrement = .pi * 2 / CGFloat(corners * 2)
		var angle = CGFloat(-CGFloat.pi / 2)  // 最初の角度は上部から開始
		var path = Path()

		// 最初の外側頂点に移動
		let firstPoint = CGPoint(
			x: center.x + outerRadius * cos(angle),
			y: center.y + outerRadius * sin(angle)
		)
		path.move(to: firstPoint)

		// 星形を描画（外側と内側の頂点を交互に配置）
		for corner in 0..<(corners * 2) {
			angle += angleIncrement

			let radius = corner.isMultiple(of: 2) ? innerRadius : outerRadius
			let point = CGPoint(
				x: center.x + radius * cos(angle),
				y: center.y + radius * sin(angle)
			)

			path.addLine(to: point)
		}

		path.closeSubpath()
		return path
	}
}
