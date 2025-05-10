// 星型エフェクトビュー（個別ブロック用）
import SwiftUI

struct StarEffectView: View {
    let position: CGPoint
    let color: Color
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 外側の星
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(color.opacity(0.8))
                .blendMode(.screen)
            
            // 内側の星
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
                .blendMode(.screen)
        }
        .position(position)
        .scaleEffect(scale)
        .onAppear {
            // 拍動するようなスケールアニメーション
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                scale = 1.3
            }
        }
    }
} 