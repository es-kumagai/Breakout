import SwiftUI
import Foundation  // GameStateのimportに必要

struct GameView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var mouseLocation: CGPoint = .zero
    @State private var isPadleMoving = false
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            // ゲーム要素
            GameContentView()
            // GameContentView全体にdrawingGroupを適用して最適化
                .drawingGroup() // パフォーマンス向上のためのGPUレンダリング
        }
        .frame(width: CGFloat(GameState.frameWidth), height: CGFloat(GameState.frameHeight))
        .background(Color.black)
        // マウス位置の検出
        .onContinuousHover { phase in
            // ゲームフリーズ中は入力を無視
            if gameState.isGameFrozen { return }
            
            switch phase {
            case .active(let location):
                mouseLocation = location
                
                // マウス位置に基づいてパドルを移動（クリックなしでも常に追従）
                let x = max(min(location.x, CGFloat(GameState.frameWidth) - gameState.paddle.size.width / 2), gameState.paddle.size.width / 2)
                gameState.movePaddle(to: x)
                
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
                    
                    // マウス/タッチ位置の更新
                    let location = value.location
                    gameState.movePaddle(to: location.x)
                    
                    // ゲーム開始またはボール発射
                    if !gameState.isGameStarted {
                        // ゲームが開始されていない場合、開始する
                        gameState.startGame()
                    } else {
                        // 既にゲームが開始されている場合は、停止中ボールをチェックして発射する
                        gameState.startWaitingBalls()
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
                gameState.startWaitingBalls()
            }
        }
        .focusable()
        // キーボードショートカットの強化
        .onKeyPress(.space) {
            if gameState.isGameFrozen && !gameState.isGameOver { return .ignored }
            
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
                gameState.startWaitingBalls()
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
        // アクセシビリティ改善
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ブレイクアウトゲーム")
        .accessibilityHint("スペースキーでゲーム開始、左右の矢印キーでパドルを移動")
    }
}

#Preview {
    GameView()
        .environmentObject(GameState())
}
