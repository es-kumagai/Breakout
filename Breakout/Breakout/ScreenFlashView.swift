// 画面フラッシュエフェクト表示ビュー
import SwiftUI

struct ScreenFlashView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        Group {
            if gameState.showScreenFlash {
                // 画面全体を覆うフラッシュエフェクト
                gameState.screenFlashColor
                    .opacity(gameState.screenFlashOpacity)
                    .blendMode(.screen) // 下の色を明るく混ぜる
                    .edgesIgnoringSafeArea(.all)
                    .zIndex(999) // 最前面に表示
                    .animation(.easeOut(duration: 0.2), value: gameState.screenFlashOpacity)
            }
        }
    }
} 