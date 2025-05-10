// ボール復活カウントダウン表示ビュー
import SwiftUI

struct BallReviveCountdownsView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var forceUpdate = UUID() // 強制的な更新用のステート
    
    var body: some View {
        ForEach(0..<gameState.balls.count, id: \.self) { index in
            if let countdown = gameState.balls[index].reviveCountdown, Int(countdown) >= 0 {
                BallReviveCountdownView(ballIndex: index, countdown: countdown)
                // 常に一意のIDを持たせることで強制的に再描画
                    .id("ball-countdown-\(index)-\(countdown)")
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            // 0.5秒ごとに強制的に更新
            forceUpdate = UUID()
        }
    }
} 