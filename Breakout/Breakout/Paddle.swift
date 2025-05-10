import SwiftUI

struct Paddle {
    var position: CGPoint = CGPoint(x: GameState.frameWidth / 2, y: GameState.frameHeight - 30)
    var size: CGSize = CGSize(width: 100, height: 15) // 可変にする
    let originalWidth: CGFloat = 100 // 元のサイズを保持する定数
    let color: Color = .white
} 