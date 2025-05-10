// ゲーム開始メッセージビュー
import SwiftUI

struct StartMessageView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        if !gameState.isGameStarted && !gameState.isGameOver {
            VStack {
                Spacer()
                Text("クリックしてゲームを開始")
                    .font(.title)
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }
} 