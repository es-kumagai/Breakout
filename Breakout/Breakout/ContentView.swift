import SwiftUI

// GameViewとGameStateの参照エラーを解決するためのインポート
import Foundation

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @State private var mouseLocation: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // ゲームビュー
            VStack {
                GameView()
                    .environmentObject(gameState)
                    .padding(GameState.frameMargin) // GameViewの周囲に余白を追加
            }
            .frame(width: GameState.screenWidth, height: GameState.screenHeight) // サイズを増やして余白分を確保
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
            )
            .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 0)
            // マウス位置の検出 - ContentViewレベルで実装
            .onContinuousHover { phase in
                // ゲームフリーズ中は入力を無視
                if gameState.isGameFrozen { return }
                
                switch phase {
                case .active(let location):
                    mouseLocation = location
                    
                    // ContentView座標からゲーム内座標に変換（余白を考慮）
                    let gameX = convertToGameX(location.x)
                    
                    // 変換した座標でパドルを移動
                    gameState.movePaddle(to: gameX)
                    
                case .ended:
                    break
                }
            }
            .gesture(
                // ドラッグジェスチャーを最適化
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // ゲームフリーズ中またはゲームオーバー時は入力を無視
                        if gameState.isGameFrozen || gameState.isGameOver { return }
                        
                        // マウス/タッチ位置の更新とゲーム内座標への変換
                        let location = value.location
                        let gameX = convertToGameX(location.x)
                        gameState.movePaddle(to: gameX)
                        
                        // ゲーム開始またはボール発射
                        if !gameState.isGameStarted {
                            // ゲームが開始されていない場合、開始する
                            gameState.startGame()
                        } else {
                            // 既にゲームが開始されている場合は、停止中ボールをチェックして発射する
                            for i in 0..<gameState.balls.count where !gameState.balls[i].isMoving && gameState.balls[i].reviveCountdown == nil {
                                gameState.launchBall(at: i)
                            }
                        }
                    }
            )
            .onTapGesture {
                // ゲームフリーズ中は入力を無視
                if gameState.isGameFrozen { return }
                
                // ゲーム開始時のクリック処理
                if !gameState.isGameStarted && !gameState.isGameOver {
                    // 通常のゲーム開始
                    gameState.startGame()
                } else if gameState.isGameStarted && !gameState.isGameOver {
                    // 既にゲームが開始されている場合は、停止中ボールをチェックして発射する
                    for i in 0..<gameState.balls.count where !gameState.balls[i].isMoving && gameState.balls[i].reviveCountdown == nil {
                        gameState.launchBall(at: i)
                    }
                }
            }
            // キーボードサポートも追加
            .focusable()
            .onKeyPress(.space) { 
                if gameState.isGameFrozen { return .ignored }
                
                if gameState.isGameOver {
                    // スペースキーでのリスタート機能
                    gameState.restartGame()
                    return .handled
                } else if !gameState.isGameStarted {
                    // ゲーム開始
                    gameState.startGame()
                    return .handled
                } else {
                    // ボール発射
                    for i in 0..<gameState.balls.count where !gameState.balls[i].isMoving && gameState.balls[i].reviveCountdown == nil {
                        gameState.launchBall(at: i)
                    }
                    return .handled
                }
            }
            // 左右矢印キーでパドル移動
            .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
                if gameState.isGameFrozen { return .ignored }
                
                let moveAmount: CGFloat = 20.0
                if press.key == .leftArrow {
                    let newPosition = max(gameState.paddle.position.x - moveAmount, gameState.paddle.size.width / 2)
                    gameState.movePaddle(to: newPosition)
                } else {
                    let newPosition = min(gameState.paddle.position.x + moveAmount, GameState.frameWidth - gameState.paddle.size.width / 2)
                    gameState.movePaddle(to: newPosition)
                }
                return .handled
            }
        }
        // SwiftUIのレンダリングをゲームに最適化
        .drawingGroup()
    }
    
    // ContentView座標からゲーム内座標に変換する関数
    private func convertToGameX(_ contentViewX: CGFloat) -> CGFloat {
        // 余白を考慮した座標変換
        let adjustedX = contentViewX - GameState.frameMargin
        // ゲーム領域内に収める
        return max(min(adjustedX, GameState.frameWidth), 0)
    }
}

#Preview {
    ContentView()
} 
