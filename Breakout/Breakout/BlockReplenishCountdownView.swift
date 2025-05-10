// ブロック生成カウントダウン表示ビュー
import SwiftUI

struct BlockReplenishCountdownView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text("次のブロック")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
                
                Text("\(Int(gameState.timeUntilNextBlocks) + 1)秒")
                    .foregroundColor(.yellow)
                    .font(.system(size: 18, weight: .bold))
                // カウントダウンの最後3秒間は点滅
                    .opacity(gameState.timeUntilNextBlocks <= 3.0 ? (Int(gameState.timeUntilNextBlocks * 2) % 2 == 0 ? 1.0 : 0.4) : 1.0)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow, lineWidth: 1)
                    )
            )
            .padding(.trailing, 15)
        }
    }
} 