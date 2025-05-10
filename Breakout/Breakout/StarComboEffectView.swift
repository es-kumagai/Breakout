// スターコンボエフェクトビュー
import SwiftUI

struct StarComboEffectView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            // 対象ブロックを光らせるエフェクト
            ForEach(gameState.blocks.indices, id: \.self) { index in
                if gameState.blocks[index].isStarComboTarget {
                    // 星型のエフェクトをブロック上に表示
                    StarEffectView(position: gameState.blocks[index].position, color: gameState.starComboEffectColor)
                }
            }
            
            // 中央メッセージ
            VStack {
                Spacer()
                Text("★ COMBO!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .black, radius: 2, x: 2, y: 2)
                    .scaleEffect(scale) // スケールアニメーション
                Spacer()
            }
        }
        .onAppear {
            // 素早く表示してフェードアウトするアニメーション
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 1.2 // 少し大きめにして目立たせる
            }
        }
    }
} 