// ゲーム情報表示ビュー
import SwiftUI

struct GameInfoView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        VStack {
            // スコア・レベル・ライフ表示
            HStack {
                Text("スコア: \(gameState.score)")
                    .foregroundColor(.white)
                Spacer()
                Text("レベル: \(gameState.level)")
                    .foregroundColor(.white)
                Spacer()
                Text("ライフ: \(gameState.lives)")
                    .foregroundColor(.white)
            }
            .padding()
            
            // ブロック生成カウントダウン表示（ゲーム開始時のみ）
            if gameState.isGameStarted && !gameState.isGameOver {
                BlockReplenishCountdownView()
            }
            
            // ボール復活カウントダウン表示（ゲーム状態に関わらず表示）
            if !gameState.isGameOver {
                BallReviveCountdownsView()
            }
            
            Spacer()
        }
    }
} 