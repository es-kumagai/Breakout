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

// ゲーム要素をまとめたビュー - パフォーマンス最適化版
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

// ゲーム情報表示ビュー
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

// ブロック生成カウントダウン表示ビュー
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

// ボール復活カウントダウン表示ビュー
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

// 個別のボール復活カウントダウン表示
struct BallReviveCountdownView: View {
    @EnvironmentObject private var gameState: GameState
    let ballIndex: Int
    let countdown: Double // Double型に戻す
    
    // 現在の秒数（整数部分）
    private var countdownSeconds: Int {
        return Int(countdown)
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
                
                // ボールの形状アイコン
                BallShapeIconView(shape: gameState.balls[ballIndex].shape)
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

// ボール形状アイコンビュー
struct BallShapeIconView: View {
    let shape: BallShape
    
    var body: some View {
        Group {
            switch shape {
            case .circle:
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
            case .star:
                Star(corners: 5, smoothness: 0.45)
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
            case .oval:
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 16, height: 10)
                    .rotationEffect(.degrees(45))
            }
        }
    }
}

// ゲーム開始メッセージビュー
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

// 攻略のヒント表示ビュー
struct GameHintView: View {
    let hint: GameHint
    
    var body: some View {
        VStack(spacing: 10) {
            Text("攻略のヒント")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule()
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                )
                .padding(.bottom, 8)
            
            Text(hint.caption)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)
                .bold()
            Text(hint.content)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)
        }
        .allowsHitTesting(false) // マウスイベントを無視
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
        )
        .padding(.bottom, 30)
    }
}

// ゲームオーバー表示ビュー
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

struct PaddleView: View {
    let paddle: Paddle
    
    var body: some View {
        Rectangle()
            .foregroundColor(paddle.color)
            .frame(width: paddle.size.width, height: paddle.size.height)
            .position(paddle.position)
    }
}

// ボールのビュー（パフォーマンス最適化版）
struct BallView: View {
    let ball: Ball
    
    var body: some View {
        // 最適化：レイヤー数をまとめてZStackを減らす
        ZStack {
            // 残像（パフォーマンス向上のため最大5つに制限）
            ForEach(max(0, ball.positionHistory.count - 5)..<ball.positionHistory.count, id: \.self) { i in
                trailShape(index: i)
                // ブレンドモードはdrawingGroupで効率化するため個別設定せず、親で一括して適用
            }
            
            // ボール本体
            mainBallShape()
        }
        // 全体にブレンドモードを適用して視覚効果を高める
        .blendMode(.screen)
    }
    
    // メインのボール形状 - より最適化
    @ViewBuilder
    private func mainBallShape() -> some View {
        Group {
            switch ball.shape {
            case .star:
                // 星型 - 形状を簡略化
                Star(corners: 5, smoothness: 0.45)
                    .fill(ball.color)
                    .frame(width: ball.radius * 3, height: ball.radius * 3)
                    .rotationEffect(ball.rotation)
                
            case .circle:
                // 円型 - シンプルな形状
                Circle()
                    .fill(ball.color)
                    .frame(width: ball.effectiveRadius * 2, height: ball.effectiveRadius * 2)
                
            case .oval:
                // 楕円型 - シンプルな形状
                Ellipse()
                    .fill(ball.color)
                    .frame(width: ball.radius * 3, height: ball.radius * 1.5)
                    .rotationEffect(ball.rotation)
            }
        }
        .overlay(ballCounterView())
        .position(ball.position)
        // シャドウを簡略化
        .shadow(color: ball.color.opacity(0.8), radius: 3)
    }
    
    // ボールのカウンター表示（必要な場合のみ）
    @ViewBuilder
    private func ballCounterView() -> some View {
        Group {
            if ball.shape == .star && ball.comboCount > 0 && !ball.isMoving {
                Text("\(ball.comboCount)/\(7)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: -ball.radius * 2.5)
            } else if ball.shape == .star && ball.comboCount > 0 {
                // 移動中の星型ボールは簡易表示
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(ball.comboCount)")
                        .font(.system(size: 13, weight: .bold))
                    Text("COMBO!")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.5))
                    .frame(height: 14))
                .offset(y: -ball.radius * 3.0)
                .fixedSize()
                .lineLimit(1)
            }
        }
    }
    
    // 残像の形状 - パフォーマンス最適化
    @ViewBuilder
    private func trailShape(index: Int) -> some View {
        let normalizedIndex = CGFloat(index - max(0, ball.positionHistory.count - 5)) / min(CGFloat(5), CGFloat(ball.positionHistory.count))
        let opacity = 0.1 + normalizedIndex * 0.2 // 0.1〜0.3の範囲
        
        Group {
            switch ball.shape {
            case .star:
                // 星型の残像 - より軽量化
                Star(corners: 5, smoothness: 0.45)
                    .fill(ball.color.opacity(opacity))
                    .frame(width: ball.radius * 3 * 0.7, height: ball.radius * 3 * 0.7)
                    .rotationEffect(ball.rotation - Angle(degrees: Double(index) * 5))
                
            case .circle:
                // 円型の残像 - より軽量化
                Circle()
                    .fill(ball.color.opacity(opacity))
                    .frame(width: ball.effectiveRadius * 2 * 0.9, height: ball.effectiveRadius * 2 * 0.9)
                
            case .oval:
                // 楕円型の残像 - より軽量化
                Ellipse()
                    .fill(ball.color.opacity(opacity))
                    .frame(width: ball.radius * 3 * 0.7, height: ball.radius * 1.5 * 0.7)
                    .rotationEffect(ball.rotation - Angle(degrees: Double(index) * 5))
            }
        }
        .position(ball.positionHistory[index])
        // ぼかし効果を単純化してパフォーマンス向上
        .blur(radius: 1.5)
    }
}

// メインのボール形状ビュー
struct BallShapeView: View {
    let ball: Ball
    
    var body: some View {
        Group {
            switch ball.shape {
            case .circle:
                // 丸型ボール（成長係数を適用）
                Circle()
                    .foregroundColor(ball.color)
                    .frame(width: (ball.radius + ball.growthFactor) * 2, height: (ball.radius + ball.growthFactor) * 2)
                    .rotationEffect(ball.rotation)
                    .position(ball.position)
                
            case .star:
                // 星型ボール - サイズを1.5倍に拡大
                Star(corners: 5, smoothness: 0.45)
                    .foregroundColor(ball.color)
                    .frame(width: ball.radius * 3.3, height: ball.radius * 3.3) // 2.2 * 1.5 = 3.3
                    .rotationEffect(ball.rotation)
                    .position(ball.position)
                
            case .oval:
                // 楕円形ボール - サイズを1.3倍に拡大
                Ellipse()
                    .foregroundColor(ball.color)
                    .frame(width: ball.radius * 3.25, height: ball.radius * 1.95) // 2.5 * 1.3 = 3.25, 1.5 * 1.3 = 1.95
                    .rotationEffect(ball.rotation)
                    .position(ball.position)
            }
        }
    }
}

// 残像形状ビュー
struct TrailShapeView: View {
    let ball: Ball
    let trailColor: Color
    let trailRotation: Angle
    let position: CGPoint
    let opacity: Double
    let index: Int
    let historyCount: Int
    
    var body: some View {
        Group {
            switch ball.shape {
            case .circle:
                // 丸型ボールの残像（成長係数を適用）
                Circle()
                    .fill(trailColor)
                    .frame(width: (ball.radius + ball.growthFactor) * 2, height: (ball.radius + ball.growthFactor) * 2) // 成長したサイズ
                    .rotationEffect(trailRotation)
                    .position(position)
                    .opacity(opacity)
                    .blur(radius: 2.5 + CGFloat(historyCount - index - 1) * 1.5) // よりシャープに調整
                    .blendMode(.screen) // 加算合成で明るく輝かせる
                
            case .star:
                // 星型ボールの残像 - 発光効果を追加
                Star(corners: 5, smoothness: 0.45)
                    .fill(trailColor)
                    .frame(width: ball.radius * 3.3, height: ball.radius * 3.3) // ボールと同じサイズ
                    .rotationEffect(trailRotation)
                    .position(position)
                    .opacity(opacity)
                    .blur(radius: 3.5 + CGFloat(historyCount - index - 1) * 1.5) // よりシャープに調整
                    .shadow(color: trailColor.opacity(0.8), radius: 5, x: 0, y: 0) // シャドウの設定を強化
                    .blendMode(.screen)
                
            case .oval:
                // 楕円形ボールの残像
                Ellipse()
                    .fill(trailColor)
                    .frame(width: ball.radius * 3.25, height: ball.radius * 1.95) // ボールと同じサイズ
                    .rotationEffect(trailRotation)
                    .position(position)
                    .opacity(opacity)
                    .blur(radius: 3.0 + CGFloat(historyCount - index - 1) * 1.5) // よりシャープに調整
                    .blendMode(.screen)
            }
        }
    }
}

// 星形状を描画するためのView - 改良版
struct Star: Shape {
    let corners: Int
    let smoothness: CGFloat
    
    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }
        
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.5 // 内側と外側の比率を調整（0.4→0.5）
        
        // 星形の各頂点の角度を計算
        let angleIncrement = .pi * 2 / CGFloat(corners * 2)
        var angle = CGFloat(-CGFloat.pi / 2) // 最初の角度は上部から開始
        var path = Path()
        
        // 最初の外側頂点に移動
        let firstPoint = CGPoint(
            x: center.x + outerRadius * cos(angle),
            y: center.y + outerRadius * sin(angle)
        )
        path.move(to: firstPoint)
        
        // 星形を描画（外側と内側の頂点を交互に配置）
        for corner in 0..<(corners * 2) {
            angle += angleIncrement
            
            let radius = corner.isMultiple(of: 2) ? innerRadius : outerRadius
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            
            path.addLine(to: point)
        }
        
        path.closeSubpath()
        return path
    }
}

// BlockViewの最適化
struct BlockView: View {
    let block: Block
    @State private var rainbowPhase: Double = 0
    @State private var scaleEffect: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var pulseOpacity: Double = 0.0
    
    // 衝突後すぐに元のブロックを非表示にするためのフラグ
    @State private var showOriginalBlock: Bool = true
    
    var body: some View {
        Group {
            // アニメーションするブロック
            if block.isAnimating {
                ZStack {
                    // 最も外側の眩しい発光レイヤー（白）- 最適化のためレンダリング条件を追加
                    if pulseOpacity > 0.1 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: block.size.width * 1.5, height: block.size.height * 1.5)
                            .position(block.position)
                            .blur(radius: 15)
                            .opacity(pulseOpacity * 0.7)
                            .scaleEffect(scaleEffect + 0.2)
                            .zIndex(12)
                    }
                    
                    // 中間の発光レイヤー - 内部のdrawingGroup()を削除
                    RoundedRectangle(cornerRadius: 5)
                        .fill(brightRainbowGradient)
                        .frame(width: block.size.width * 1.4, height: block.size.height * 1.4)
                        .position(block.position)
                        .blur(radius: 10)
                        .opacity(opacity * 0.9)
                        .scaleEffect(scaleEffect + 0.1)
                        .zIndex(11)
                    
                    // 虹色の輝くエフェクト（メイン）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(rainbowGradient)
                        .frame(width: block.size.width * 1.3, height: block.size.height * 1.3)
                        .position(block.position)
                        .blur(radius: 8)
                        .opacity(opacity)
                        .scaleEffect(scaleEffect)
                        .shadow(color: .white.opacity(0.8), radius: 15, x: 0, y: 0)
                        .animation(.easeInOut(duration: 0.7), value: scaleEffect)
                        .animation(.easeInOut(duration: 0.7), value: opacity)
                        .zIndex(10) // 虹色エフェクトを最前面に
                }
                .onAppear {
                    // 元のブロックをすぐに非表示 - 高速化のため遅延を減少
                    withAnimation(.easeOut(duration: 0.05)) {
                        showOriginalBlock = false
                    }
                    
                    // 虹色の回転アニメーション - パフォーマンス重視で最適化
                    withAnimation(.linear(duration: 0.4).repeatForever(autoreverses: false)) {
                        rainbowPhase = 360
                    }
                    
                    // パルス効果のアニメーション - 回数減少でパフォーマンス向上
                    withAnimation(.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)) {
                        pulseOpacity = 0.9
                    }
                    
                    // ブロックが消えるアニメーション - 高速化
                    withAnimation(.easeInOut(duration: 0.6)) {
                        scaleEffect = 1.7
                        opacity = 0
                    }
                }
            }
            // 通常のブロック表示（アニメーション開始時にすぐ非表示）
            else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(block.color)
                    .frame(width: block.size.width, height: block.size.height)
                    .position(block.position)
                    .scaleEffect(block.isAppearing ? 0.01 : 1.0) // 出現アニメーション
                    .opacity(block.isAppearing ? 0.0 : 1.0) // 出現時フェードイン
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: block.isAppearing)
                    .zIndex(1) // 元のブロックは背面に
            }
        }
    }
    
    // 虹色のグラデーション - 最適化して処理を軽量化
    var rainbowGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                .red, .orange, .yellow, .green, .blue, .purple, .pink, .red
            ]),
            center: .center,
            startAngle: .degrees(rainbowPhase),
            endAngle: .degrees(rainbowPhase + 360)
        )
    }
    
    // より明るい虹色のグラデーション - 色数を削減して最適化
    var brightRainbowGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color.red.opacity(1.5), Color.yellow.opacity(1.8),
                Color.green.opacity(1.6), Color.blue.opacity(1.6),
                Color.purple.opacity(1.6), Color.red.opacity(1.5)
            ]),
            center: .center,
            startAngle: .degrees(rainbowPhase + 30), // オフセットを付けて動きを出す
            endAngle: .degrees(rainbowPhase + 390)
        )
    }
}

// レベルアップメッセージ表示ビュー
struct LevelUpMessageView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        Group {
            if gameState.showLevelUpMessage {
                ZStack {
                    // 背景の暗いオーバーレイ
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    // メッセージボックス
                    VStack(spacing: 25) {
                        // タイトル
                        Text("レベルクリア！")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange, radius: 2, x: 0, y: 0)
                        
                        // レベル情報
                        VStack(spacing: 15) {
                            Text("ボーナス: +100点")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text("レベル \(gameState.level) → \(gameState.nextLevel)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // カウントダウン表示
                        if let timer = gameState.levelUpMessageTimer {
                            Text("\(Int(timer) + 1)秒後に次のレベルへ")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.yellow, lineWidth: 3)
                            )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
                }
                .zIndex(100) // 最前面に表示
            }
        }
    }
}

// レーザー表示ビュー
struct LaserView: View {
    let laser: Laser
    
    var body: some View {
        ZStack {
            // 先に残像表示（背面）
            ForEach(0..<laser.positionHistory.count, id: \.self) { index in
                laserTrailView(at: laser.positionHistory[index], index: index)
            }
            
            // 後からメインのレーザービーム（前面）
            mainLaserView()
                .position(laser.position)
        }
    }
    
    // レーザーの残像
    @ViewBuilder
    private func laserTrailView(at position: CGPoint, index: Int) -> some View {
        // 残像のインデックスを0.0〜1.0の範囲に正規化
        let normalizedIndex = Double(index) / Double(max(1, laser.positionHistory.count - 1))
        
        // 履歴の番号に基づいて透明度を計算（より薄く）
        let trailOpacity = 0.08 + normalizedIndex * 0.12 // 0.08から0.2の範囲に低下
        
        // 残像のサイズを固定（0.7倍）
        let sizeMultiplier: CGFloat = 0.7
        
        VStack(spacing: 0) {
            // レーザー本体の残像
            Rectangle()
                .fill(laser.color.opacity(0.7)) // 基本的な不透明度を下げる
                .frame(
                    width: laser.size.width * sizeMultiplier,
                    height: laser.size.height * sizeMultiplier
                )
            
            // 残像の発光効果
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            laser.color.opacity(0.6),
                            Color.orange.opacity(0.4)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(
                    width: laser.size.width * sizeMultiplier * 0.6,
                    height: laser.size.height * sizeMultiplier * 0.3
                )
                .offset(y: -laser.size.height * sizeMultiplier * 0.15)
        }
        .position(position)
        .opacity(trailOpacity)
        .blur(radius: 1.0 + (1.0 - normalizedIndex) * 1.5) // 古い残像ほどぼかす（より弱く）
    }
    
    // メインのレーザービーム
    @ViewBuilder
    private func mainLaserView() -> some View {
        VStack(spacing: 0) {
            // レーザービーム本体
            Rectangle()
                .fill(laser.color)
                .frame(width: laser.size.width, height: laser.size.height)
            
            // レーザーの発光効果
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.red, .orange]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: laser.size.width * 0.6, height: laser.size.height * 0.3)
                .offset(y: -laser.size.height * 0.15)
        }
        // グロー効果を追加
        .shadow(color: .red.opacity(0.8), radius: 3, x: 0, y: 0)
    }
}

// パドル衝突エフェクトビュー
struct PaddleHitEffectView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var animationProgress: Double = 0
    
    var body: some View {
        ZStack {
            // パドルの形状に合わせたエフェクト
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [gameState.paddleHitEffectColor, gameState.paddleHitEffectColor.opacity(0.3)]),
                        startPoint: .center,
                        endPoint: .trailing
                    )
                )
                .frame(width: gameState.paddle.size.width * (1 + animationProgress * 0.3),
                       height: gameState.paddle.size.height * (1 + animationProgress * 0.5))
                .position(gameState.paddle.position)
                .opacity(1 - animationProgress * 0.8)
                .blur(radius: 3 + animationProgress * 10)
            
            // 光線が飛び散る効果
            ForEach(0..<8, id: \.self) { i in
                SparkEffectView(angle: Double(i) * .pi / 4, progress: animationProgress, color: gameState.paddleHitEffectColor)
            }
            
            // パドルをハイライト
            Rectangle()
                .fill(gameState.paddleHitEffectColor.opacity(0.8 - animationProgress * 0.8))
                .frame(width: gameState.paddle.size.width, height: gameState.paddle.size.height)
                .position(gameState.paddle.position)
                .blur(radius: 2)
        }
        .onAppear {
            // アニメーション開始
            withAnimation(.easeOut(duration: 0.6)) {
                animationProgress = 1.0
            }
        }
    }
}

// 衝撃波の光線エフェクト
struct SparkEffectView: View {
    let angle: Double
    let progress: Double
    let color: Color
    let sparkLength: CGFloat = 50
    
    var body: some View {
        let distance = CGFloat(progress) * sparkLength
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(
            x: startPoint.x + sin(angle) * distance,
            y: startPoint.y - cos(angle) * distance
        )
        
        Path { path in
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        }
        .stroke(
            LinearGradient(
                gradient: Gradient(colors: [color, color.opacity(0)]),
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 3 - CGFloat(progress) * 2, lineCap: .round, lineJoin: .round)
        )
        .blur(radius: 2)
        .opacity(1 - progress * 0.5)
        .position(x: CGFloat(GameState.frameWidth) / 2, y: CGFloat(GameState.frameHeight) - 30)
    }
}

// 画面フラッシュエフェクト表示ビュー
struct ScreenFlashView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        Group {
            if gameState.showScreenFlash {
                // 画面全体を覆うフラッシュエフェクト
                gameState.screenFlashColor
                    .opacity(gameState.screenFlashOpacity)
                    .blendMode(.screen) // 下の色を明るく混ぜる
                    .edgesIgnoringSafeArea(.all)
                    .zIndex(999) // 最前面に表示
                    .animation(.easeOut(duration: 0.2), value: gameState.screenFlashOpacity)
            }
        }
    }
}

// スターコンボエフェクトビュー
struct StarComboEffectView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            // 対象ブロックを光らせるエフェクト
            ForEach(gameState.blocks.indices, id: \.self) { index in
                if gameState.blocks[index].isStarComboTarget {
                    // 星型のエフェクトをブロック上に表示
                    StarEffectView(position: gameState.blocks[index].position, color: gameState.starComboEffectColor)
                }
            }
            
            // 中央メッセージ
            VStack {
                Spacer()
                Text("★ COMBO!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .black, radius: 2, x: 2, y: 2)
                    .scaleEffect(scale) // スケールアニメーション
                Spacer()
            }
        }
        .onAppear {
            // 素早く表示してフェードアウトするアニメーション
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 1.2 // 少し大きめにして目立たせる
            }
        }
    }
}

// 星型エフェクトビュー（個別ブロック用）
struct StarEffectView: View {
    let position: CGPoint
    let color: Color
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 外側の星
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(color.opacity(0.8))
                .blendMode(.screen)
            
            // 内側の星
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
                .blendMode(.screen)
        }
        .position(position)
        .scaleEffect(scale)
        .onAppear {
            // 拍動するようなスケールアニメーション
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                scale = 1.3
            }
        }
    }
}

// 全てのボールが落ちた時のメッセージ表示ビュー
struct AllBallsLostMessageView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        if gameState.showAllBallsLostMessage {
            ZStack {
                // 半透明の背景
                Color.black.opacity(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(spacing: 20) {
                    Text("全てのボールが落ちました！")
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

// レーザー衝突メッセージ表示ビュー
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

#Preview {
    GameView()
        .environmentObject(GameState())
}
