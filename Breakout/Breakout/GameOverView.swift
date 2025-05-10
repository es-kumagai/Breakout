// ゲームオーバー表示ビュー
import SwiftUI

struct GameOverView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        if gameState.isGameOver {
            ZStack {
                // 半透明の背景
                Color.black.opacity(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        // 背景タップでゲーム再開
                        gameState.restartGame()
                    }
                
                VStack {
                    Spacer()
                    Text("ゲームオーバー")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .padding(.bottom, 10)
                    
                    Text("最終スコア: \(gameState.score)")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.bottom, 20)
                    
                    // 攻略ヒントを表示
                    if let hint = gameState.currentHint {
                        GameHintView(hint: hint)
                            .padding(.top, 12)
                    }
                    
                    Text("画面クリックまたはスペースキーでリスタート")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
} 