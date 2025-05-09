import SwiftUI

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
                    
                    // ゲーム開始または復活ボールを発射
                    if !gameState.isGameStarted {
                        // ゲームが開始されていない場合、開始する
                        gameState.startGame()
                    } else {
                        // 既にゲームが開始されている場合は、停止中ボールをチェックして発射する
                        for i in 0..<gameState.balls.count {
                            if !gameState.balls[i].isMoving && gameState.balls[i].reviveCountdown == nil {
                                gameState.launchBall(at: i)
                            }
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
                for i in 0..<gameState.balls.count {
                    if !gameState.balls[i].isMoving && gameState.balls[i].reviveCountdown == nil {
                        gameState.launchBall(at: i)
                    }
                }
            }
        }
        .focusable()
        .onKeyPress(.space) { 
            // ゲームフリーズ中は入力を無視
            if gameState.isGameFrozen { return .ignored }
            
            // スペースキーでの一時停止機能を削除
            if gameState.isGameOver {
                // スペースキーでのリスタート機能は残す
                gameState.restartGame()
                return .handled
            }
            return .ignored
        }
    }
}

// ゲーム要素をまとめたビュー
struct GameContentView: View {
    @EnvironmentObject private var gameState: GameState
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.01)  // ZStackが空だとエラーになるのを防ぐダミー要素
            
            // ブロック
            ForEach(gameState.blocks) { block in
                BlockView(block: block)
            }
            
            // パドル
            PaddleView(paddle: gameState.paddle)
            
            // パドル衝突エフェクト
            if gameState.showPaddleHitEffect {
                PaddleHitEffectView()
            }
            
            // レーザー
            ForEach(0..<gameState.lasers.count, id: \.self) { index in
                LaserView(laser: gameState.lasers[index])
            }
            
            // ボール（複数）
            ForEach(0..<gameState.balls.count, id: \.self) { index in
                BallView(ball: gameState.balls[index])
            }
            
            // ゲーム情報表示
            GameInfoView()
            
            // ゲーム開始メッセージ
            StartMessageView()
            
            // ゲームオーバー表示
            GameOverView()
            
            // レベルアップメッセージ
            LevelUpMessageView()
            
            // 画面フラッシュエフェクト
            if gameState.showScreenFlash {
                ScreenFlashView()
            }
            
            // スターコンボエフェクト
            if gameState.showStarComboEffect {
                StarComboEffectView()
            }
        }
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
                        .padding(.bottom, 30)
                    
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

// ボールのビュー（星/円/楕円の3種類に対応）
struct BallView: View {
    let ball: Ball
    
    var body: some View {
        ZStack {
            // 先に残像を描画（背面）
            ForEach(0..<ball.positionHistory.count, id: \.self) { i in
                trailShape(index: i)
            }
            
            // 後からボール本体を描画（前面）
            mainBallShape()
        }
    }
    
    // メインのボール形状
    @ViewBuilder
    private func mainBallShape() -> some View {
        Group {
            switch ball.shape {
            case .star:
                // 星型
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: ball.radius * 3, height: ball.radius * 3) // 星はやや大きめに表示
                    .foregroundColor(ball.color)
                    .rotationEffect(ball.rotation)
                    
            case .circle:
                // 円型
                Circle()
                    .frame(width: ball.effectiveRadius * 2, height: ball.effectiveRadius * 2) // 成長を反映
                    .foregroundColor(ball.color)
                
            case .oval:
                // 楕円型
                Ellipse()
                    .frame(width: ball.radius * 3, height: ball.radius * 1.5) // 横長の楕円
                    .foregroundColor(ball.color)
                    .rotationEffect(ball.rotation)
            }
        }
        .overlay(ballCounterView())
        .position(ball.position)
    }
    
    // ボールのカウンター表示（必要な場合のみ）
    @ViewBuilder
    private func ballCounterView() -> some View {
        Group {
            if ball.shape == .star && ball.comboCount > 0 && !ball.isMoving {
                Text("\(ball.comboCount)/\(7)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: -ball.radius * 2.5) // ボールの上に表示
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
    
    // 残像の形状
    @ViewBuilder
    private func trailShape(index: Int) -> some View {
        Group {
            switch ball.shape {
            case .star:
                // 星型の残像
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: ball.radius * 3 * trailScale(for: index), height: ball.radius * 3 * trailScale(for: index))
                    .foregroundColor(getTrailColor(for: index))
                    .rotationEffect(ball.rotation - Angle(degrees: Double(index) * 5)) // 残像ごとに少しずつ回転を変える
                
            case .circle:
                // 円型の残像
                Circle()
                    .frame(width: ball.effectiveRadius * 2 * trailScale(for: index), height: ball.effectiveRadius * 2 * trailScale(for: index))
                    .foregroundColor(getTrailColor(for: index))
                
            case .oval:
                // 楕円型の残像
                Ellipse()
                    .frame(width: ball.radius * 3 * trailScale(for: index), height: ball.radius * 1.5 * trailScale(for: index))
                    .foregroundColor(getTrailColor(for: index))
                    .rotationEffect(ball.rotation - Angle(degrees: Double(index) * 5)) // 残像ごとに少しずつ回転を変える
            }
        }
        .position(ball.positionHistory[index])
    }
    
    // インデックスに基づいてスケールを計算
    private func trailScale(for index: Int) -> CGFloat {
        // 円形ボールの場合はボールの成長に合わせて残像のサイズも大きく
        if ball.shape == .circle {
            // 成長係数を考慮しつつ、少し小さめの0.9倍サイズに
            return 0.9
        } else {
            // その他の形状は従来通り0.7倍サイズに
            return 0.7
        }
    }
    
    // インデックスに基づいて色を取得
    private func getTrailColor(for index: Int) -> Color {
        let count = ball.positionHistory.count
        // 残像のインデックスを0.0〜1.0の範囲に正規化
        let normalizedIndex = CGFloat(index) / CGFloat(max(1, count - 1))
        
        // 基本透明度を下げて、より薄くする（0.1〜0.3の範囲）
        let opacity = 0.1 + normalizedIndex * 0.2
        
        // 各ボールの形状に応じたカラースキーム
        switch ball.shape {
        case .star:
            // 黄色の星型用の残像
            if normalizedIndex < 0.3 {
                // 古い残像
                return Color(red: 0.9, green: 0.8, blue: 0.2, opacity: opacity)
            } else if normalizedIndex < 0.6 {
                // 中間の残像
                return Color(red: 1.0, green: 0.9, blue: 0.3, opacity: opacity)
            } else {
                // 新しい残像
                return Color(red: 1.0, green: 0.95, blue: 0.4, opacity: opacity)
            }
            
        case .circle:
            // 水色の丸型用の残像
            if normalizedIndex < 0.3 {
                // 古い残像
                return Color(red: 0.2, green: 0.7, blue: 1.0, opacity: opacity)
            } else if normalizedIndex < 0.6 {
                // 中間の残像
                return Color(red: 0.4, green: 0.8, blue: 1.0, opacity: opacity)
            } else {
                // 新しい残像
                return Color(red: 0.5, green: 0.9, blue: 1.0, opacity: opacity)
            }
            
        case .oval:
            // オレンジ色の楕円型用の残像
            if normalizedIndex < 0.3 {
                // 古い残像
                return Color(red: 0.9, green: 0.5, blue: 0.1, opacity: opacity)
            } else if normalizedIndex < 0.6 {
                // 中間の残像
                return Color(red: 1.0, green: 0.6, blue: 0.2, opacity: opacity)
            } else {
                // 新しい残像
                return Color(red: 1.0, green: 0.7, blue: 0.3, opacity: opacity)
            }
        }
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

struct BlockView: View {
    let block: Block
    @State private var rainbowPhase: Double = 0
    @State private var scaleEffect: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var pulseOpacity: Double = 0.0
    
    // 衝突後すぐに元のブロックを非表示にするためのフラグ
    @State private var showOriginalBlock: Bool = true
    
    var body: some View {
        ZStack {
            // アニメーションするブロック
            if block.isAnimating {
                // 最も外側の眩しい発光レイヤー（白）
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .frame(width: block.size.width * 1.5, height: block.size.height * 1.5)
                    .position(block.position)
                    .blur(radius: 15)
                    .opacity(pulseOpacity * 0.7)
                    .scaleEffect(scaleEffect + 0.2)
                    .zIndex(12)
                
                // 中間の発光レイヤー
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
                    .onAppear {
                        // 元のブロックをすぐに非表示
                        withAnimation(.easeOut(duration: 0.1)) {
                            showOriginalBlock = false
                        }
                        
                        // 虹色の回転アニメーション
                        withAnimation(.linear(duration: 0.4).repeatForever(autoreverses: false)) {
                            rainbowPhase = 360
                        }
                        
                        // パルス効果のアニメーション
                        withAnimation(.easeInOut(duration: 0.2).repeatCount(3, autoreverses: true)) {
                            pulseOpacity = 0.9
                        }
                        
                        // ブロックが消えるアニメーション
                        withAnimation(.easeInOut(duration: 0.7)) {
                            scaleEffect = 1.7
                            opacity = 0
                        }
                    }
            }
            
            // 通常のブロック表示（アニメーション開始時にすぐ非表示）
            if !block.isAnimating || (block.isAnimating && showOriginalBlock) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(block.color)
                    .frame(width: block.size.width, height: block.size.height)
                    .position(block.position)
                    .opacity(block.isAnimating ? 0 : 1.0) // アニメーション中は透明に
                    .scaleEffect(block.isAppearing ? 0.01 : 1.0) // 出現アニメーション
                    .opacity(block.isAppearing ? 0.0 : 1.0) // 出現時フェードイン
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: block.isAppearing)
                    .animation(.easeOut(duration: 0.15), value: block.isAnimating)
                    .zIndex(1) // 元のブロックは背面に
            }
        }
    }
    
    // 虹色のグラデーション（より明るく彩度の高い色を使用）
    var rainbowGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                .red, Color.orange.opacity(1.3), Color.yellow.opacity(1.5), 
                Color.green.opacity(1.3), Color.blue.opacity(1.3), 
                Color.purple.opacity(1.3), Color.pink.opacity(1.5), .red
            ]),
            center: .center,
            startAngle: .degrees(rainbowPhase),
            endAngle: .degrees(rainbowPhase + 360)
        )
    }
    
    // より明るい虹色のグラデーション（外側の発光用）
    var brightRainbowGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color.red.opacity(1.5), Color.orange.opacity(1.6), Color.yellow.opacity(1.8), 
                Color.green.opacity(1.6), Color.blue.opacity(1.6), 
                Color.purple.opacity(1.6), Color.pink.opacity(1.8), Color.red.opacity(1.5)
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

#Preview {
    GameView()
        .environmentObject(GameState())
} 
