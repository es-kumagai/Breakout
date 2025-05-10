// 個別のボール復活カウントダウン表示
import SwiftUI

struct BallReviveCountdownView: View {
    @EnvironmentObject private var gameState: GameState
    let ballIndex: Int
    let countdown: Double // Double型に戻す
    
    // 現在の秒数（整数部分）
    private var countdownSeconds: Int {
        return Int(countdown)
    }
    
    // 安全にボールの形状を取得するヘルパープロパティ
    private var ballShape: BallShape {
        // インデックスの範囲チェック
        guard ballIndex >= 0 && ballIndex < gameState.balls.count else {
            // デフォルトの形状を返す
            return .circle
        }
        return gameState.balls[ballIndex].shape
    }
    
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text("ボール復活")
                    .foregroundColor(.cyan)
                    .font(.system(size: 14))
                
                Text("\(countdownSeconds)秒")
                    .foregroundColor(.cyan)
                    .font(.system(size: 18, weight: .bold))
                // 残り5秒間は点滅
                    .opacity(countdownSeconds <= 5 ? (countdownSeconds % 2 == 0 ? 1.0 : 0.4) : 1.0)
                
                // ボールの形状アイコン - 安全に取得した形状を使用
                BallShapeIconView(shape: ballShape)
                    .padding(.top, 2)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan, lineWidth: 1)
                    )
            )
            .padding(.trailing, 15)
            .padding(.top, 5)
        }
        // Viewが表示されたときとView更新時のアクション
        .onAppear {
            print("カウントダウン表示: \(countdownSeconds)秒")
        }
    }
} 