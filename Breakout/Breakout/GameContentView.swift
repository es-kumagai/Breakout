// ゲーム要素をまとめたビュー - パフォーマンス最適化版
import SwiftUI

struct GameContentView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.01).edgesIgnoringSafeArea(.all)
            
            // ブロック - IDを明示的に指定して再利用性向上
            ForEach(gameState.blocks, id: \.id) { block in
                BlockView(block: block)
            }
            
            // パドル - 常に動くのでキャッシュは不要
            PaddleView(paddle: gameState.paddle)
            
            // レーザー - 動きが速いのでキャッシュ不要
            ForEach(0..<gameState.lasers.count, id: \.self) { index in
                LaserView(laser: gameState.lasers[index])
            }
            
            // ボール - 複数ボールをまとめてGPU処理
            ZStack {
                ForEach(0..<gameState.balls.count, id: \.self) { index in
                    BallView(ball: gameState.balls[index])
                }
            }
            
            // ゲーム情報表示
            VStack {
                // ゲーム情報と各種UI
                GameInfoView()
                
                Spacer()
            }
            .zIndex(50)
            
            // エフェクト類は条件付きレンダリング
            Group {
                // 画面フラッシュエフェクト - 最前面に表示
                if gameState.showScreenFlash {
                    ScreenFlashView()
                        .zIndex(100)
                }
                
                // スターコンボエフェクト
                if gameState.showStarComboEffect {
                    StarComboEffectView()
                        .zIndex(90)
                }
                
                // パドル衝突エフェクト
                if gameState.showPaddleHitEffect {
                    PaddleHitEffectView()
                        .zIndex(80)
                }
                
                // 全てのボールが落ちた時のメッセージ
                if gameState.showAllBallsLostMessage {
                    AllBallsLostMessageView()
                        .transition(.opacity)
                        .zIndex(85)
                }
                
                // レーザー衝突メッセージ
                if gameState.showLaserHitMessage {
                    LaserHitMessageView()
                        .transition(.opacity)
                        .zIndex(85)
                }
                
                // ゲーム開始メッセージ
                if !gameState.isGameStarted && !gameState.isGameOver {
                    StartMessageView()
                        .transition(.opacity)
                        .zIndex(70)
                }
                
                // ゲームオーバー表示
                if gameState.isGameOver {
                    GameOverView()
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(60)
                }
                
                // レベルアップメッセージ
                if gameState.showLevelUpMessage {
                    LevelUpMessageView()
                        .transition(.scale)
                        .zIndex(50)
                }
            }
        }
        // GameContentView全体としてのdrawingGroupは削除 - 親要素で既に適用
    }
} 