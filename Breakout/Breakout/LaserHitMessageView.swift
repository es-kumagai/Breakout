// レーザー衝突メッセージ表示ビュー
import SwiftUI

struct LaserHitMessageView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        if gameState.showLaserHitMessage {
            ZStack {
                // 半透明の背景
                Color.black.opacity(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(spacing: 20) {
                    Text("レーザーに衝突しました！")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.bottom, 10)
                    
                    Text("残りライフ: \(gameState.lives)")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    // 攻略ヒントを表示
                    if let hint = gameState.currentHint {
                        GameHintView(hint: hint)
                            .padding(.top, 12)
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.red, lineWidth: 2)
                        )
                )
                .shadow(color: .red.opacity(0.5), radius: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
} 