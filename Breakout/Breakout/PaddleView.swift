// パドル表示ビュー
import SwiftUI

struct PaddleView: View {
    let paddle: Paddle
    
    var body: some View {
        Rectangle()
            .foregroundColor(paddle.color)
            .frame(width: paddle.size.width, height: paddle.size.height)
            .position(paddle.position)
    }
} 