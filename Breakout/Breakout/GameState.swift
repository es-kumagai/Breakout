import SwiftUI
import Combine

@MainActor
class GameState: ObservableObject {
    // ゲーム設定
    static let frameWidth: CGFloat = 800
    static let frameHeight: CGFloat = 600
    static let fps: Double = 60
    
    // ブロック補充の間隔（秒）
    static let blockReplenishInterval: TimeInterval = 10.0
    
    // ボールの基本速度
    private let baseVelocity: CGFloat = 300  // 1秒あたりのピクセル数
    
    // レーザーの速度
    private let laserVelocity: CGFloat = 250  // 1秒あたりのピクセル数
    
    // ゲーム要素
    @Published var paddle: Paddle
    @Published var balls: [Ball] // 複数のボールを管理する配列
    @Published var blocks: [Block]
    @Published var lasers: [Laser] = [] // レーザーを管理する配列
    
    // ゲーム状態
    @Published var lives: Int = 3
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var isGameOver: Bool = false
    @Published var isPaused: Bool = false
    @Published var isGameStarted: Bool = false
    @Published var isGameFrozen: Bool = false // ゲームフリーズ状態フラグ（レーザー衝突時など）
    
    // スターコンボ関連（星型ボール専用）
    @Published var showStarComboEffect: Bool = false // スターコンボエフェクト表示フラグ
    @Published var starComboEffectTimer: Double? = nil // スターコンボエフェクトタイマー
    @Published var starComboEffectColor: Color = .yellow // スターコンボエフェクトの色
    @Published var starComboTargetBlocks: [UUID] = [] // コンボで消滅予定のブロックID
    static let requiredComboCount: Int = 7 // 必要なコンボカウント
    
    // レーザー衝突エフェクト
    @Published var showPaddleHitEffect: Bool = false
    @Published var paddleHitEffectTimer: Double? = nil
    @Published var paddleHitEffectColor: Color = .red
    @Published var paddleWasHit: Bool = false // パドルがヒットされたフラグ
    
    // 画面フラッシュエフェクト
    @Published var showScreenFlash: Bool = false
    @Published var screenFlashColor: Color = .red
    @Published var screenFlashTimer: Double? = nil
    @Published var screenFlashOpacity: Double = 0.7 // フラッシュの不透明度
    
    // レベルアップメッセージ表示用
    @Published var showLevelUpMessage: Bool = false
    @Published var nextLevel: Int = 0
    @Published var levelUpMessageTimer: Double? = nil
    
    // ブロック生成カウントダウン
    @Published var timeUntilNextBlocks: Double = GameState.blockReplenishInterval
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?
    private var lastUpdateTime: TimeInterval = 0
    private var hitBlockIds = Set<UUID>()
    
    // ブロック補充の時間管理
    private var lastBlockReplenishTime: TimeInterval = 0
    
    init() {
        paddle = Paddle()
        balls = [] // 空の配列で初期化
        blocks = []
        
        setupGame()
    }
    
    func setupGame() {
        // パドルを初期位置に戻す
        paddle = Paddle()
        resetBalls()
        resetBlocks()
        startGameLoop()
    }
    
    func resetBalls() {
        // ボールの配列をクリア
        balls.removeAll()
        
        // 3つのボールを追加（異なる形状）
        let shapes: [BallShape] = [.star, .circle, .oval]
        
        for i in 0..<3 {
            var ball = Ball()
            // パドル上の異なる位置に配置
            let offset = CGFloat(i - 1) * 30 // -30, 0, 30のオフセット
            ball.position = CGPoint(
                x: paddle.position.x + offset,
                y: paddle.position.y - paddle.size.height / 2 - ball.effectiveRadius
            )
            ball.velocity = CGVector(dx: 0, dy: 0)
            ball.isMoving = false
            ball.shape = shapes[i] // 形状を設定
            
            // 形状に応じたパステルカラーを設定
            switch ball.shape {
            case .circle:
                // 水色のパステル
                ball.color = Color(red: 0.6, green: 0.9, blue: 1.0)
            case .star:
                // 黄色のパステル
                ball.color = Color(red: 1.0, green: 0.95, blue: 0.6)
                // スターコンボカウンターをリセット
                ball.comboCount = 0
                ball.lastHitBlockColor = nil
            case .oval:
                // オレンジ色のパステル
                ball.color = Color(red: 1.0, green: 0.8, blue: 0.6)
            }
            
            ball.rotation = .zero  // 回転角度を初期化
            ball.growthFactor = 0  // 成長係数をリセット
            
            // 形状ごとに初期回転角度をランダムに設定
            if i == 0 || i == 2 { // 星型と楕円形
                ball.rotation = Angle(degrees: Double.random(in: 0...360))
            }
            
            // 残像の最大数を設定（より多くの残像で滑らかさ向上）
            ball.maxHistoryLength = 8 // 5から8に増加
            
            // 位置履歴を初期化
            ball.positionHistory = []
            
            balls.append(ball)
        }
    }
    
    func startBalls() {
        // すべてのボールを発射
        for i in 0..<balls.count {
            launchBall(at: i)
        }
    }
    
    func resetBlocks() {
        blocks.removeAll()
        hitBlockIds.removeAll()
        
        let blockWidth: CGFloat = 70
        let blockHeight: CGFloat = 25
        let padding: CGFloat = 10
        let totalRows = 5
        let totalColumns = 10
        
        // ブロック全体の幅を計算
        let totalBlocksWidth = CGFloat(totalColumns) * blockWidth + CGFloat(totalColumns - 1) * padding
        // 左端の開始位置（中央揃え）
        let startX = (GameState.frameWidth - totalBlocksWidth) / 2
        
        // 和風の色に変更 - より明るい色に調整
        // 桜色（さくらいろ）、山吹色（やまぶきいろ）、浅葱色（あさぎいろ）、萌黄色（もえぎいろ）、空色（そらいろ）
        let colors: [Color] = [
            Color(red: 0.98, green: 0.77, blue: 0.85), // 桜色（さくらいろ）- #FAC4D9
            Color(red: 0.99, green: 0.79, blue: 0.13), // 山吹色（やまぶきいろ）- #FBCA21
            Color(red: 0.56, green: 0.81, blue: 0.82), // 浅葱色（あさぎいろ）- #8FCFD0
            Color(red: 0.74, green: 0.91, blue: 0.6),  // 萌黄色（もえぎいろ）- #BDE899
            Color(red: 0.54, green: 0.79, blue: 0.93)  // 空色（そらいろ）- #8ACDEE
        ]
        
        for row in 0..<totalRows {
            for column in 0..<totalColumns {
                let xPos = startX + CGFloat(column) * (blockWidth + padding) + blockWidth / 2
                let yPos = padding + CGFloat(row) * (blockHeight + padding) + 50 + blockHeight / 2
                
                let block = Block(
                    id: UUID(),
                    position: CGPoint(x: xPos, y: yPos),
                    size: CGSize(width: blockWidth, height: blockHeight),
                    color: colors[row],
                    isAnimating: false,
                    removeAfter: nil
                )
                blocks.append(block)
            }
        }
        
        // 最初のブロック補充時間を現在に設定
        lastBlockReplenishTime = CACurrentMediaTime()
    }
    
    func movePaddle(to position: CGFloat) {
        // ゲームがフリーズ状態の場合は何もしない
        if isGameFrozen {
            return
        }
        
        // パドルの位置を更新（左右の境界をチェック）
        let halfPaddleWidth = paddle.size.width / 2
        let minX = halfPaddleWidth
        let maxX = GameState.frameWidth - halfPaddleWidth
        
        // 現在のパドル位置を保存（ボールの移動量計算用）
        let previousX = paddle.position.x
        
        // 新しいパドル位置を設定
        paddle.position.x = max(minX, min(position, maxX))
        
        // パドルの移動量を計算
        let deltaX = paddle.position.x - previousX
        
        // 全てのボールを確認し、待機中のボールを一緒に移動
        for i in 0..<balls.count {
            // ゲーム開始前の場合はすべてのボールを移動
            if !isGameStarted {
                let offset = CGFloat(i - 1) * 30 // -30, 0, 30のオフセット
                balls[i].position.x = paddle.position.x + offset
            } 
            // ゲーム開始後は、発射されていないボール（復活カウントダウン中でないもの）だけをパドルと一緒に移動
            else if !balls[i].isMoving && balls[i].reviveCountdown == nil {
                balls[i].position.x += deltaX
                
                // パドルの上に位置を合わせる（Y座標も念のため再設定）
                balls[i].position.y = paddle.position.y - paddle.size.height / 2 - balls[i].effectiveRadius
            }
        }
    }
    
    func startGameLoop() {
        print("startGameLoop() called - Starting game timer")
        timer?.cancel()
        lastUpdateTime = CACurrentMediaTime()
        
        timer = Timer.publish(every: 1.0 / GameState.fps, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let currentTime = CACurrentMediaTime()
                let deltaTime = currentTime - self.lastUpdateTime
                self.lastUpdateTime = currentTime
                self.update(deltaTime: deltaTime)
            }
        
        // タイマーがキャンセルされないように保持
        if let timer = timer {
            cancellables.insert(timer)
        }
    }
    
    func update(deltaTime: TimeInterval) {        
        guard !isGameOver else { return }
        
        // スターコンボエフェクトタイマーを更新
        if let timer = starComboEffectTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // タイマー終了、エフェクトを消す
                starComboEffectTimer = nil
                showStarComboEffect = false
                starComboTargetBlocks.removeAll()
            } else {
                starComboEffectTimer = newTimer
            }
        }
        
        // レベルアップメッセージタイマーを更新
        if let timer = levelUpMessageTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // タイマー終了、次のレベルに進む
                levelUpMessageTimer = nil
                showLevelUpMessage = false
                proceedToNextLevel()
            } else {
                levelUpMessageTimer = newTimer
            }
        }
        
        // 画面フラッシュエフェクトタイマーの更新
        if let timer = screenFlashTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // フラッシュエフェクト表示終了
                screenFlashTimer = nil
                showScreenFlash = false
            } else {
                screenFlashTimer = newTimer
                // フラッシュの不透明度を時間経過とともに減少させる
                let progress = newTimer / 0.3 // 0.3秒で徐々に消えるように
                screenFlashOpacity = min(0.7, progress * 0.7) // 最大不透明度0.7
            }
        }
        
        // パドル衝突エフェクトタイマーの更新
        if let timer = paddleHitEffectTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // エフェクト表示終了
                paddleHitEffectTimer = nil
                showPaddleHitEffect = false
                isGameFrozen = false // ゲームフリーズ状態を解除
                
                // エフェクト表示終了後、パドルヒット処理を実行
                if paddleWasHit {
                    paddleWasHit = false // フラグをリセット
                    
                    // ライフを減らす
                    lives -= 1
                    
                    // ゲームオーバーまたは再開
                    if lives > 0 {
                        // ライフが残っている場合は再開
                        resetBalls()
                        lasers.removeAll() // 全てのレーザーを削除
                        isGameStarted = false
                        print("レーザーがパドルに衝突しました。残りライフ: \(lives)")
                    } else {
                        // ライフが0になったらゲームオーバー
                        isGameOver = true
                        lasers.removeAll() // ゲームオーバー時にすべてのレーザーを削除
                        print("レーザーがパドルに衝突し、ゲームオーバーになりました。")
                    }
                }
            } else {
                paddleHitEffectTimer = newTimer
            }
        }
        
        // 通常のゲーム更新処理
        guard !isPaused && !isGameFrozen else { return }
        
        // 落下したボールの復活カウントダウン更新（ゲーム開始状態に関わらず実行）
        updateBallReviveCountdowns(deltaTime: deltaTime)
        
        // ゲームが開始されている場合のみボールを動かす
        if isGameStarted {
            moveBalls(deltaTime: deltaTime)
            checkBallCollisions()
            
            // レーザーを移動し、衝突判定を行う
            moveLasers(deltaTime: deltaTime)
            checkLaserCollisions()
            
            checkCollisions()
            updateAnimatingBlocks()
            checkGameState()
            
            // ブロックアニメーションの更新
            updateBlockAnimations(deltaTime: deltaTime)
            
            // ブロック補充のタイミングをチェックとカウントダウン更新
            timeUntilNextBlocks -= deltaTime
            if timeUntilNextBlocks <= 0 {
                replenishBlocks()
            }
        }
    }
    
    func updateAnimatingBlocks() {
        let currentTime = Date().timeIntervalSince1970
        
        // アニメーション終了したブロックを削除
        for i in (0..<blocks.count).reversed() {
            if let removeAfter = blocks[i].removeAfter, currentTime >= removeAfter {
                blocks.remove(at: i)
            }
        }
    }
    
    func moveBalls(deltaTime: TimeInterval) {
        // すべてのボールを移動
        for i in 0..<balls.count {
            guard balls[i].isMoving else {
                // ボールが止まっているときは履歴をクリア
                if !balls[i].positionHistory.isEmpty {
                    balls[i].positionHistory.removeAll()
                }
                continue
            }
            
            // 前の位置を保存
            let oldPosition = balls[i].position
            
            // フレームレートに依存しない一定の動き
            balls[i].position.x += balls[i].velocity.dx * CGFloat(deltaTime)
            balls[i].position.y += balls[i].velocity.dy * CGFloat(deltaTime)
            
            // 位置履歴を更新 - 残像の間隔を短くして密度を高くする
            let minRecordDistance = balls[i].radius * 0.5  // 以前より短い距離（1.2 → 0.5）
            
            // 移動した距離を計算
            let dx = balls[i].position.x - oldPosition.x
            let dy = balls[i].position.y - oldPosition.y
            let movedDistance = sqrt(dx * dx + dy * dy)
            
            // 十分な距離を移動したか、または履歴が空の場合に記録
            if movedDistance >= minRecordDistance || balls[i].positionHistory.isEmpty {
                // 最大履歴数を超える場合、最も古い位置を削除
                if balls[i].positionHistory.count >= balls[i].maxHistoryLength {
                    balls[i].positionHistory.removeFirst()
                }
                
                // 新しい位置を履歴に追加（前の位置ではなくボールに近い位置を記録）
                // 現在位置から残像までの距離を調整
                let trailPosition = CGPoint(
                    x: balls[i].position.x - (dx * 0.3), // 現在位置から少し後ろの位置
                    y: balls[i].position.y - (dy * 0.3)  // 現在位置から少し後ろの位置
                )
                balls[i].positionHistory.append(trailPosition)
            }
            
            // ボールを回転させる
            let speed = sqrt(balls[i].velocity.dx * balls[i].velocity.dx + balls[i].velocity.dy * balls[i].velocity.dy)
            let rotationMultiplier: Double
            switch balls[i].shape {
            case .star:
                rotationMultiplier = 0.8 // 星型はやや遅めに回転
            case .circle:
                rotationMultiplier = 1.0 // 円形は標準速度
            case .oval:
                rotationMultiplier = 1.2 // 楕円形は少し速めに回転
            }
            
            // 速度に比例した回転速度を設定
            balls[i].rotationSpeed = Double(speed) * 0.002 * rotationMultiplier
            
            // 回転角度を更新
            balls[i].rotation = Angle(degrees: balls[i].rotation.degrees + balls[i].rotationSpeed * deltaTime * 360)
        }
    }
    
    // ボール同士の衝突を検出して処理
    func checkBallCollisions() {
        for i in 0..<balls.count {
            for j in (i+1)..<balls.count {
                let ball1 = balls[i]
                let ball2 = balls[j]
                
                // 少なくとも1つのボールが動いていれば衝突判定
                guard ball1.isMoving || ball2.isMoving else { continue }
                
                // カウントダウン中のボールはスキップ
                if ball1.reviveCountdown != nil || ball2.reviveCountdown != nil {
                    continue
                }
                
                // 2つのボール間の距離
                let dx = ball2.position.x - ball1.position.x
                let dy = ball2.position.y - ball1.position.y
                let distance = sqrt(dx * dx + dy * dy)
                
                // 衝突判定（2つのボールの有効半径の合計より距離が小さい場合）
                if distance < ball1.effectiveRadius + ball2.effectiveRadius {
                    // 衝突の方向ベクトル（正規化）
                    let nx = dx / distance
                    let ny = dy / distance
                    
                    var newBall1 = ball1
                    var newBall2 = ball2
                    
                    // 待機中のボールは位置を変えず、衝突してきたボールの反射だけ処理する
                    // ケース1: ボール1が待機中、ボール2が動いている
                    if !ball1.isMoving && ball2.isMoving {
                        // 反射係数 - 静止ボールに対する反射は強めに
                        let reflectionCoef: CGFloat = 1.2
                        
                        // ボール2を反射
                        let speed = sqrt(ball2.velocity.dx * ball2.velocity.dx + ball2.velocity.dy * ball2.velocity.dy)
                        let dirX = ball2.velocity.dx / speed
                        let dirY = ball2.velocity.dy / speed
                        
                        // 入射ベクトルと法線ベクトルから反射ベクトルを計算
                        let dot = dirX * nx + dirY * ny
                        let reflectX = dirX - 2 * dot * nx
                        let reflectY = dirY - 2 * dot * ny
                        
                        // 反射後の速度を設定（少し速くする）
                        newBall2.velocity.dx = speed * reflectX * reflectionCoef
                        newBall2.velocity.dy = speed * reflectY * reflectionCoef
                        
                        // ランダム性を追加
                        let randomAngle = CGFloat.random(in: -0.2...0.2)
                        applyRandomAngleChange(to: &newBall2, angle: randomAngle)
                        
                        // ボール2が静止ボール1に重ならないように位置調整
                        let overlap = (ball1.effectiveRadius + ball2.effectiveRadius - distance) / 2
                        newBall2.position.x += overlap * nx * 2
                        newBall2.position.y += overlap * ny * 2
                        
                        // ボール1の位置は変更しない（パドル上に留まる）
                        
                        print("動いているボールが待機中のボールで反射しました")
                    }
                    // ケース2: ボール2が待機中、ボール1が動いている
                    else if ball1.isMoving && !ball2.isMoving {
                        // 反射係数 - 静止ボールに対する反射は強めに
                        let reflectionCoef: CGFloat = 1.2
                        
                        // ボール1を反射
                        let speed = sqrt(ball1.velocity.dx * ball1.velocity.dx + ball1.velocity.dy * ball1.velocity.dy)
                        let dirX = ball1.velocity.dx / speed
                        let dirY = ball1.velocity.dy / speed
                        
                        // 入射ベクトルと法線ベクトルから反射ベクトルを計算
                        let dot = dirX * (-nx) + dirY * (-ny)
                        let reflectX = dirX - 2 * dot * (-nx)
                        let reflectY = dirY - 2 * dot * (-ny)
                        
                        // 反射後の速度を設定（少し速くする）
                        newBall1.velocity.dx = speed * reflectX * reflectionCoef
                        newBall1.velocity.dy = speed * reflectY * reflectionCoef
                        
                        // ランダム性を追加
                        let randomAngle = CGFloat.random(in: -0.2...0.2)
                        applyRandomAngleChange(to: &newBall1, angle: randomAngle)
                        
                        // ボール1が静止ボール2に重ならないように位置調整
                        let overlap = (ball1.effectiveRadius + ball2.effectiveRadius - distance) / 2
                        newBall1.position.x -= overlap * nx * 2
                        newBall1.position.y -= overlap * ny * 2
                        
                        // ボール2の位置は変更しない（パドル上に留まる）
                        
                        print("動いているボールが待機中のボールで反射しました")
                    }
                    // ケース3: 両方のボールが動いている
                    else if ball1.isMoving && ball2.isMoving {
                        // 相対速度を計算
                        let dvx = ball2.velocity.dx - ball1.velocity.dx
                        let dvy = ball2.velocity.dy - ball1.velocity.dy
                        
                        // 衝突の強さ（２つのボールの相対速度のドット積）
                        let impulse = nx * dvx + ny * dvy
                        
                        // 両方のボールの速度を更新
                        if impulse > 0 {
                            // ボールの形状と回転に基づいて衝突係数を調整
                            let (coef1, randomAngle1) = getBallCollisionFactors(ball: ball1)
                            let (coef2, randomAngle2) = getBallCollisionFactors(ball: ball2)
                            
                            // 形状係数を適用して反発力を調整
                            let effectiveImpulse1 = impulse * coef1
                            let effectiveImpulse2 = impulse * coef2
                            
                            // 基本速度更新
                            newBall1.velocity.dx += effectiveImpulse1 * nx
                            newBall1.velocity.dy += effectiveImpulse1 * ny
                            newBall2.velocity.dx -= effectiveImpulse2 * nx
                            newBall2.velocity.dy -= effectiveImpulse2 * ny
                            
                            // 回転に基づくランダム要素を追加
                            if randomAngle1 != 0 {
                                applyRandomAngleChange(to: &newBall1, angle: randomAngle1)
                            }
                            
                            if randomAngle2 != 0 {
                                applyRandomAngleChange(to: &newBall2, angle: randomAngle2)
                            }
                            
                            // ボールが重なるのを防ぐために位置を調整
                            let overlap = (ball1.effectiveRadius + ball2.effectiveRadius - distance) / 2
                            newBall1.position.x -= overlap * nx
                            newBall1.position.y -= overlap * ny
                            newBall2.position.x += overlap * nx
                            newBall2.position.y += overlap * ny
                            
                            // 衝突によって回転速度も変化
                            adjustRotationAfterCollision(ball: &newBall1, otherBall: ball2, nx: nx, ny: ny)
                            adjustRotationAfterCollision(ball: &newBall2, otherBall: ball1, nx: -nx, ny: -ny)
                        }
                    }
                    
                    balls[i] = newBall1
                    balls[j] = newBall2
                }
            }
        }
    }
    
    // ボールの形状と回転に基づいて衝突係数とランダム角度を取得
    private func getBallCollisionFactors(ball: Ball) -> (CGFloat, CGFloat) {
        let rotationDegrees = ball.rotation.degrees
        let rotationRadians = rotationDegrees * .pi / 180
        let normalizedRotation = rotationRadians.truncatingRemainder(dividingBy: .pi * 2)
        
        switch ball.shape {
        case .star:
            // 星型：回転角度に応じて、星の尖った部分が衝突すると反発が強くなる
            // 回転角度を5つの部分（星の尖った部分）に分割
            let section = Int((normalizedRotation / (.pi * 2) * 5).rounded()) % 5
            let isTipCollision = section.isMultiple(of: 2) // 星の尖った部分が衝突
            
            if isTipCollision {
                // 星の尖った部分での衝突：より強い反発と大きいランダム要素
                return (1.5, CGFloat.random(in: -0.5...0.5)) // 1.3→1.5, ±0.3→±0.5
            } else {
                // 星の凹んだ部分での衝突：より弱い反発と小さいランダム要素
                return (0.7, CGFloat.random(in: -0.2...0.2)) // 0.85→0.7, ±0.1→±0.2
            }
            
        case .circle:
            // 円形：均一な反発、わずかなランダム性を追加
            return (1.0, CGFloat.random(in: -0.05...0.05)) // 0.0→±0.05
            
        case .oval:
            // 楕円形：回転角度によって反発係数が大きく変化
            // 楕円の長軸方向の反発は非常に弱く、短軸方向の反発は非常に強い
            let longAxisAligned = normalizedRotation.truncatingRemainder(dividingBy: .pi) < .pi / 2
            
            if longAxisAligned {
                // 長軸方向での衝突：かなり弱い反発
                return (0.7, CGFloat.random(in: -0.1...0.1)) // 0.9→0.7, ±0.05→±0.1
            } else {
                // 短軸方向での衝突：かなり強い反発
                return (1.4, CGFloat.random(in: -0.3...0.3)) // 1.15→1.4, ±0.1→±0.3
            }
        }
    }
    
    // 速度ベクトルにランダムな角度変化を適用
    private func applyRandomAngleChange(to ball: inout Ball, angle: CGFloat) {
        let vx = ball.velocity.dx
        let vy = ball.velocity.dy
        let speed = sqrt(vx * vx + vy * vy)
        let currentAngle = atan2(vy, vx)
        let newAngle = currentAngle + angle
        
        ball.velocity.dx = speed * cos(newAngle)
        ball.velocity.dy = speed * sin(newAngle)
    }
    
    // 衝突後の回転速度を調整
    private func adjustRotationAfterCollision(ball: inout Ball, otherBall: Ball, nx: CGFloat, ny: CGFloat) {
        let vx = ball.velocity.dx
        let vy = ball.velocity.dy
        
        // ボールの速度と衝突方向の内積
        let dotProduct = vx * nx + vy * ny
        
        // 衝突の角度によって回転速度が変化
        // 垂直衝突なら回転方向が反転、斜め衝突なら回転が加速/減速
        if abs(dotProduct) > 0.7 {
            // ほぼ正面衝突：回転方向が反転
            ball.rotationSpeed *= -0.9 // -0.8→-0.9
        } else {
            // 斜め衝突：形状に応じた回転変化（より極端に）
            switch ball.shape {
            case .star:
                // 星型は衝突で大きく回転方向が変わる
                ball.rotationSpeed = Double.random(in: -1.5...1.5) * abs(ball.rotationSpeed) * 1.5 // ±1.0→±1.5, 1.2→1.5
            case .circle:
                // 円形は少し加速
                ball.rotationSpeed *= 1.2 // 1.1→1.2
            case .oval:
                // 楕円は方向が変わりやすい
                if Bool.random() {
                    ball.rotationSpeed *= -1.2 // -0.9→-1.2
                } else {
                    ball.rotationSpeed *= 1.4 // 1.1→1.4
                }
            }
        }
        
        // 最大回転速度を制限（少し高く）
        let maxRotationSpeed = Double(baseVelocity) * 0.015 // 0.01→0.015
        ball.rotationSpeed = min(max(ball.rotationSpeed, -maxRotationSpeed), maxRotationSpeed)
    }
    
    func checkCollisions() {
        // 各ボールに対してすべての衝突判定を行う
        for i in 0..<balls.count {
            // 壁との衝突
            if balls[i].position.x - balls[i].effectiveRadius <= 0 || balls[i].position.x + balls[i].effectiveRadius >= GameState.frameWidth {
                // ボールの形状に基づいて反射角度を計算
                applyShapeBasedReflection(ballIndex: i, isWallCollision: true, isHorizontal: true)
                
                // 壁にめり込まないように位置を調整
                if balls[i].position.x - balls[i].effectiveRadius <= 0 {
                    balls[i].position.x = balls[i].effectiveRadius
                } else {
                    balls[i].position.x = GameState.frameWidth - balls[i].effectiveRadius
                }
            }
            
            if balls[i].position.y - balls[i].effectiveRadius <= 0 {
                // ボールの形状に基づいて反射角度を計算
                applyShapeBasedReflection(ballIndex: i, isWallCollision: true, isHorizontal: false)
                
                // 上部にめり込まないように調整
                balls[i].position.y = balls[i].effectiveRadius
            }
            
            // パドルとの衝突
            if balls[i].position.y + balls[i].effectiveRadius >= paddle.position.y - paddle.size.height / 2 &&
               balls[i].position.y - balls[i].effectiveRadius <= paddle.position.y + paddle.size.height / 2 &&
               balls[i].position.x + balls[i].effectiveRadius >= paddle.position.x - paddle.size.width / 2 &&
               balls[i].position.x - balls[i].effectiveRadius <= paddle.position.x + paddle.size.width / 2 {
                
                // パドルの中心からの距離に基づいて反射角度を計算
                let hitPosition = (balls[i].position.x - paddle.position.x) / (paddle.size.width / 2)
                
                // ボールの形状に基づいて角度の補正係数を決定
                let angleModifier: CGFloat
                switch balls[i].shape {
                case .star:
                    // 星型は鋭く反射（よりランダム性と鋭さを持つ）
                    angleModifier = 1.2
                    
                    // スターコンボカウントをリセット
                    if balls[i].comboCount > 0 {
                        balls[i].comboCount = 0
                        print("パドルに当たったため、スターコンボカウントをリセットしました")
                    }
                case .circle:
                    // 円形は通常の反射
                    angleModifier = 1.0
                case .oval:
                    // 楕円形は角度が少し滑らかに変化
                    angleModifier = 0.85
                }
                
                let angle = hitPosition * .pi / 3 * angleModifier // 形状に応じて角度を調整
                
                // 速度の大きさを保持
                let speed = baseVelocity
                balls[i].velocity.dx = speed * sin(angle)
                balls[i].velocity.dy = -speed * cos(angle)
                
                // パドルにめり込まないように位置を調整
                balls[i].position.y = paddle.position.y - paddle.size.height / 2 - balls[i].effectiveRadius
            }
            
            // ブロックとの衝突
            checkBallBlockCollisions(ballIndex: i)
            
            // 下部境界外に出たらボールを削除または失敗状態にする
            if balls[i].position.y - balls[i].effectiveRadius > GameState.frameHeight {
                // 既にカウントダウン中のボールはスキップ
                if balls[i].reviveCountdown != nil {
                    continue
                }
                
                // 星型ボールの場合、comboCountをリセット
                if balls[i].shape == .star && balls[i].comboCount > 0 {
                    print("ボールが画面外に出たため、スターコンボカウントをリセットしました")
                    balls[i].comboCount = 0
                    balls[i].lastHitBlockColor = nil
                }
                
                // ボールが落下した場合
                
                // 他のボールがまだ動いているかをチェック（修正）
                let otherActiveBalls = balls.indices.filter { idx in
                    idx != i && balls[idx].isMoving
                }.count > 0
                
                if otherActiveBalls {
                    // 他のボールがまだ動いている場合、このボールには復活タイマーをセット
                    print("ボール \(i) が落下しました。30秒後に復活します。")
                    
                    // 新しいBallインスタンスを作成して置き換える（SwiftUIの更新を確実にするため）
                    var updatedBall = balls[i]
                    updatedBall.isMoving = false
                    updatedBall.position.y = 2000 // 画面外に移動
                    updatedBall.reviveCountdown = 30.0 // 30秒後に復活
                    balls[i] = updatedBall
                } else {
                    // 最後のボールが落ちた場合
                    balls[i].isMoving = false
                    balls[i].position.y = 2000 // 画面外に移動
                    
                    // すべてのボールが無効になった場合
                    lives -= 1
                    if lives > 0 {
                        resetBalls()
                        lasers.removeAll() // すべてのレーザーを削除
                        isGameStarted = false
                    } else {
                        isGameOver = true
                        lasers.removeAll() // ゲームオーバー時にすべてのレーザーを削除
                    }
                }
            }
        }
    }
    
    // ボールの形状に基づいて反射を適用する新しい関数
    func applyShapeBasedReflection(ballIndex: Int, isWallCollision: Bool, isHorizontal: Bool) {
        let ball = balls[ballIndex]
        var newVelocity = ball.velocity
        
        switch ball.shape {
        case .star:
            // 星型：より鋭い反射と予測不可能性
            if isHorizontal {
                newVelocity.dx *= -1.25 // 反発係数を大きくして勢いを増す (1.15→1.25)
                
                // ランダム要素を追加して予測不可能に（より大きく）
                let randomAngle = CGFloat.random(in: -0.35...0.35) // -0.2...0.2→-0.35...0.35
                let currentSpeed = sqrt(newVelocity.dx * newVelocity.dx + newVelocity.dy * newVelocity.dy)
                let angle = atan2(newVelocity.dy, newVelocity.dx) + randomAngle
                newVelocity.dx = currentSpeed * cos(angle)
                newVelocity.dy = currentSpeed * sin(angle)
            } else {
                newVelocity.dy *= -1.25 // 1.15→1.25
                
                // ランダム要素を追加（より大きく）
                let randomAngle = CGFloat.random(in: -0.35...0.35) // -0.2...0.2→-0.35...0.35
                let currentSpeed = sqrt(newVelocity.dx * newVelocity.dx + newVelocity.dy * newVelocity.dy)
                let angle = atan2(newVelocity.dy, newVelocity.dx) + randomAngle
                newVelocity.dx = currentSpeed * cos(angle)
                newVelocity.dy = currentSpeed * sin(angle)
            }
            
        case .circle:
            // 円形：標準的な反射（わずかなランダム性を追加）
            if isHorizontal {
                newVelocity.dx *= -1.0
                // わずかなランダム要素を追加
                newVelocity.dy *= CGFloat.random(in: 0.95...1.05) // 新規追加
            } else {
                newVelocity.dy *= -1.0
                // わずかなランダム要素を追加
                newVelocity.dx *= CGFloat.random(in: 0.95...1.05) // 新規追加
            }
            
        case .oval:
            // 楕円形：横方向と縦方向で反射特性の差を拡大
            let vx = ball.velocity.dx
            let vy = ball.velocity.dy
            let speed = sqrt(vx * vx + vy * vy)
            let rotationRadians = ball.rotation.degrees * .pi / 180
            
            // 楕円の現在の向き（長軸の方向）を考慮して反射特性を決定
            let isLongAxisHorizontal = rotationRadians.truncatingRemainder(dividingBy: .pi) < .pi / 2
            
            if isHorizontal {
                // 水平方向の衝突
                if isLongAxisHorizontal {
                    // 長軸が水平方向：非常に弱い反発
                    newVelocity.dx *= -0.7 // -0.9→-0.7
                    // 大きな角度変化を追加
                    let angleFactor = CGFloat.random(in: 0.7...1.3) // 0.9...1.1→0.7...1.3
                    newVelocity.dy *= angleFactor
                } else {
                    // 短軸が水平方向：非常に強い反発
                    newVelocity.dx *= -1.3 // -0.9→-1.3
                    // 小さな角度変化
                    let angleFactor = CGFloat.random(in: 0.9...1.1)
                    newVelocity.dy *= angleFactor
                }
            } else {
                // 垂直方向の衝突
                if !isLongAxisHorizontal {
                    // 長軸が垂直方向：非常に弱い反発
                    newVelocity.dy *= -0.7 // -0.9→-0.7
                    // 大きな角度変化を追加
                    let angleFactor = CGFloat.random(in: 0.7...1.3) // 0.9...1.1→0.7...1.3
                    newVelocity.dx *= angleFactor
                } else {
                    // 短軸が垂直方向：非常に強い反発
                    newVelocity.dy *= -1.3 // -0.9→-1.3
                    // 小さな角度変化
                    let angleFactor = CGFloat.random(in: 0.9...1.1)
                    newVelocity.dx *= angleFactor
                }
            }
            
            // 速度を正規化して一定に保つ
            let newSpeed = sqrt(newVelocity.dx * newVelocity.dx + newVelocity.dy * newVelocity.dy)
            newVelocity.dx = newVelocity.dx * speed / newSpeed
            newVelocity.dy = newVelocity.dy * speed / newSpeed
        }
        
        balls[ballIndex].velocity = newVelocity
    }
    
    func checkBallBlockCollisions(ballIndex: Int) {
        for i in 0..<blocks.count {
            let block = blocks[i]
            
            // すでにアニメーション中または削除予定のブロックはスキップ
            if block.isAnimating || block.removeAfter != nil {
                continue
            }
            
            if balls[ballIndex].position.y + balls[ballIndex].effectiveRadius >= block.position.y - block.size.height / 2 &&
               balls[ballIndex].position.y - balls[ballIndex].effectiveRadius <= block.position.y + block.size.height / 2 &&
               balls[ballIndex].position.x + balls[ballIndex].effectiveRadius >= block.position.x - block.size.width / 2 &&
               balls[ballIndex].position.x - balls[ballIndex].effectiveRadius <= block.position.x + block.size.width / 2 {
                
                // ブロックとの衝突方向を判定して反射角度を調整
                let ballCenterX = balls[ballIndex].position.x
                let ballCenterY = balls[ballIndex].position.y
                let blockLeft = block.position.x - block.size.width / 2
                let blockRight = block.position.x + block.size.width / 2
                let blockTop = block.position.y - block.size.height / 2
                let blockBottom = block.position.y + block.size.height / 2
                
                let leftDist = abs(ballCenterX - blockLeft)
                let rightDist = abs(ballCenterX - blockRight)
                let topDist = abs(ballCenterY - blockTop)
                let bottomDist = abs(ballCenterY - blockBottom)
                
                let minDist = min(leftDist, rightDist, topDist, bottomDist)
                
                let isHorizontal = (minDist == leftDist || minDist == rightDist)
                
                // ボールの形状に基づく反射を適用
                applyShapeBasedReflection(ballIndex: ballIndex, isWallCollision: false, isHorizontal: isHorizontal)
                
                // 位置調整（ブロックにめり込まないように）
                if isHorizontal {
                    if minDist == leftDist {
                        balls[ballIndex].position.x = blockLeft - balls[ballIndex].effectiveRadius
                    } else {
                        balls[ballIndex].position.x = blockRight + balls[ballIndex].effectiveRadius
                    }
                } else {
                    if minDist == topDist {
                        balls[ballIndex].position.y = blockTop - balls[ballIndex].effectiveRadius
                    } else {
                        balls[ballIndex].position.y = blockBottom + balls[ballIndex].effectiveRadius
                    }
                }
                
                // 円形ボールの場合、直径を1px大きくする
                if balls[ballIndex].shape == .circle {
                    balls[ballIndex].growthFactor += 0.5 // 半径を0.5px増やす（直径で1px増加）
                }
                
                // スターコンボ処理（星型ボールの場合）
                if balls[ballIndex].shape == .star {
                    // カウントを増やす（パドルに当たった後という条件を削除）
                    balls[ballIndex].comboCount += 1
                    
                    // 衝突したブロックの色を記録
                    balls[ballIndex].lastHitBlockColor = block.color
                    
                    // 必要なコンボ回数に達したらコンボ発動
                    if balls[ballIndex].comboCount >= GameState.requiredComboCount {
                        // スターコンボを発動
                        activateStarCombo(withColor: block.color)
                        // コンボカウントをリセット
                        balls[ballIndex].comboCount = 0
                        balls[ballIndex].lastHitBlockColor = nil
                    }
                }
                
                // ブロックをアニメーション状態に設定
                var animatingBlock = block
                animatingBlock.isAnimating = true
                // スターコンボ中のブロックは特別なフラグを立てる
                if showStarComboEffect && block.color == starComboEffectColor {
                    animatingBlock.isStarComboTarget = true
                    starComboTargetBlocks.append(block.id)
                }
                // 1秒後にブロックを削除する時間を設定
                animatingBlock.removeAfter = Date().timeIntervalSince1970 + 0.7
                blocks[i] = animatingBlock
                hitBlockIds.insert(block.id)
                
                // スコア加算
                score += 10
                
                // レーザーを発射（ブロックの色を渡す）
                createLaser(at: block.position, color: block.color)
                
                // 一つのブロックとの衝突だけを処理（複数ブロックの同時衝突を避けるため）
                break
            }
        }
    }
    
    func checkGameState() {
        // アニメーション中ではないブロックが残っているかチェック
        let activeBlocks = blocks.filter { !$0.isAnimating && $0.removeAfter == nil }
        
        if activeBlocks.isEmpty && blocks.isEmpty {
            // 全てのブロックが消えた場合
            nextLevel = level + 1
            score += 100 // レベルクリアボーナス
            
            // レベルアップメッセージを表示
            showLevelUpMessage = true
            levelUpMessageTimer = 3.0 // 3秒間表示
            
            // ゲームは一時停止状態に
            isPaused = true
        }
    }
    
    func restartGame() {
        // ゲーム状態をリセット
        lives = 3
        score = 0
        level = 1
        isGameOver = false
        isPaused = false
        isGameStarted = false
        isGameFrozen = false // フリーズ状態もリセット
        
        // レーザーを削除
        lasers.removeAll()
        
        // ゲーム要素を再設定
        setupGame()
    }
    
    func startGame() {
        // ゲームがフリーズ状態の場合は何もしない
        if isGameFrozen {
            return
        }
        
        isGameStarted = true
        startBalls()
    }
    
    // 既存のブロックを1段下に移動する関数
    func moveBlocksDown() {
        let blockHeight: CGFloat = 25
        let padding: CGFloat = 10
        let rowHeight = blockHeight + padding
        
        // アニメーション中ではないブロックだけを移動
        for i in 0..<blocks.count {
            if !blocks[i].isAnimating && blocks[i].removeAfter == nil {
                // 現在位置を保存
                let currentPosition = blocks[i].position
                
                // 目標位置を計算（1段下）
                let targetY = currentPosition.y + rowHeight
                
                // 目標位置を設定（アニメーション用）
                blocks[i].targetPosition = CGPoint(x: currentPosition.x, y: targetY)
                
                // 画面下端を超えたらゲームオーバー
                if targetY + blocks[i].size.height / 2 >= GameState.frameHeight - 30 {
                    isGameOver = true
                    break
                }
            }
        }
    }
    
    // 新しいブロック列を上側に追加する関数
    func addNewBlockRow() {
        let blockWidth: CGFloat = 70
        let blockHeight: CGFloat = 25
        let padding: CGFloat = 10
        let totalColumns = 10
        
        // ブロック全体の幅を計算
        let totalBlocksWidth = CGFloat(totalColumns) * blockWidth + CGFloat(totalColumns - 1) * padding
        // 左端の開始位置（中央揃え）
        let startX = (GameState.frameWidth - totalBlocksWidth) / 2
        
        // 新しい行の色はランダムに選択
        // 桜色（さくらいろ）、山吹色（やまぶきいろ）、浅葱色（あさぎいろ）、萌黄色（もえぎいろ）、空色（そらいろ）
        let colors: [Color] = [
            Color(red: 0.98, green: 0.77, blue: 0.85), // 桜色（さくらいろ）- #FAC4D9
            Color(red: 0.99, green: 0.79, blue: 0.13), // 山吹色（やまぶきいろ）- #FBCA21
            Color(red: 0.56, green: 0.81, blue: 0.82), // 浅葱色（あさぎいろ）- #8FCFD0
            Color(red: 0.74, green: 0.91, blue: 0.6),  // 萌黄色（もえぎいろ）- #BDE899
            Color(red: 0.54, green: 0.79, blue: 0.93)  // 空色（そらいろ）- #8ACDEE
        ]
        let rowColor = colors[Int.random(in: 0..<colors.count)]
        
        // 最上段の位置
        let yPos = padding + 50 + blockHeight / 2
        
        for column in 0..<totalColumns {
            let xPos = startX + CGFloat(column) * (blockWidth + padding) + blockWidth / 2
            
            let block = Block(
                id: UUID(),
                position: CGPoint(x: xPos, y: yPos),
                size: CGSize(width: blockWidth, height: blockHeight),
                color: rowColor,
                isAnimating: false,
                removeAfter: nil,
                isAppearing: true, // 出現アニメーション用フラグを設定
                targetPosition: nil, // 目標位置はなし（生成時）
                isStarComboTarget: false // スターコンボで消滅予定のフラグを初期化
            )
            blocks.append(block)
        }
    }
    
    // ブロックを補充する関数（既存ブロックを下に移動し、新しい行を追加）
    func replenishBlocks() {
        moveBlocksDown()
        addNewBlockRow()
        
        // カウントダウンをリセット
        timeUntilNextBlocks = GameState.blockReplenishInterval
    }
    
    // ブロックのアニメーションを更新する関数
    func updateBlockAnimations(deltaTime: TimeInterval) {
        let animationSpeed: CGFloat = 5.0 // アニメーション速度係数
        
        for i in 0..<blocks.count {
            // 出現アニメーション処理
            if blocks[i].isAppearing {
                // 0.3秒後に通常状態に戻す
                if CACurrentMediaTime() - lastBlockReplenishTime > 0.3 {
                    blocks[i].isAppearing = false
                }
            }
            
            // 移動アニメーション処理
            if let targetPosition = blocks[i].targetPosition {
                // 現在位置から目標位置へスムーズに移動
                let dx = targetPosition.x - blocks[i].position.x
                let dy = targetPosition.y - blocks[i].position.y
                
                // 距離が十分小さければ移動完了
                if abs(dx) < 0.5 && abs(dy) < 0.5 {
                    blocks[i].position = targetPosition
                    blocks[i].targetPosition = nil // 移動完了でターゲットをクリア
                } else {
                    // スムーズに移動（イージング効果）
                    blocks[i].position.x += dx * CGFloat(deltaTime) * animationSpeed
                    blocks[i].position.y += dy * CGFloat(deltaTime) * animationSpeed
                }
            }
        }
    }
    
    // 落下したボールの復活カウントダウンを更新
    func updateBallReviveCountdowns(deltaTime: TimeInterval) {
        
        // 全てのボールに対して処理
        for i in 0..<balls.count {
            // 落下していて復活待ちのボールのみ処理
            if let countdown = balls[i].reviveCountdown {                
                // カウントダウンを減らす
                let newCountdown = countdown - deltaTime
                
                // 新しいBallインスタンスを作成して置き換える（常に更新して確実にSwiftUIの再描画を促す）
                var updatedBall = balls[i]
                updatedBall.reviveCountdown = newCountdown
                balls[i] = updatedBall
                                
                // カウントダウンが0以下になったらボールを復活
                if newCountdown <= 0 {
                    print("ボール \(i) が復活します")
                    reviveBall(at: i)
                }
            }
        }
    }
    
    // 落下したボールを復活させる
    func reviveBall(at index: Int) {
        // 復活するボールの形状を保持
        let shape = balls[index].shape
        
        // 円形ボールの場合は成長係数をリセット
        if shape == .circle {
            balls[index].growthFactor = 0
        }
        
        // パドル上で待機中のボールをカウント（移動していなくてカウントダウンもないボール）
        let waitingBalls = balls.filter { !$0.isMoving && $0.reviveCountdown == nil }
        let waitingCount = waitingBalls.count
        
        // 復活位置のX座標を計算
        var reviveX: CGFloat
        
        switch waitingCount {
        case 0:
            // 待機中のボールがない場合は中央に配置
            reviveX = paddle.position.x
        case 1:
            // 既に1つ待機中の場合は左側に配置（パドル幅の1/4左）
            reviveX = paddle.position.x - paddle.size.width / 4
        case 2, 3:
            // 既に2つ以上待機中の場合は右側に配置（パドル幅の1/4右）
            reviveX = paddle.position.x + paddle.size.width / 4
        default:
            // その他の場合は中央に配置
            reviveX = paddle.position.x
        }
        
        // ボールを復活位置に配置
        balls[index].position = CGPoint(
            x: reviveX,
            y: paddle.position.y - paddle.size.height / 2 - balls[index].effectiveRadius
        )
        balls[index].velocity = CGVector(dx: 0, dy: 0)
        balls[index].isMoving = false // クリックするまで動かないように変更
        balls[index].reviveCountdown = nil // カウントダウンをリセット
        
        // 位置履歴をクリア
        balls[index].positionHistory.removeAll()
        
        print("ボール \(index) が復活し、クリック待機中です。待機中ボール数: \(waitingCount + 1)")
    }
    
    // 特定のボールを発射するメソッドを追加
    func launchBall(at index: Int) {
        // ゲームがフリーズ状態の場合は何もしない
        if isGameFrozen {
            return
        }
        
        if index < 0 || index >= balls.count {
            return // 範囲外のインデックスを防ぐ
        }
        
        if !balls[index].isMoving && balls[index].reviveCountdown == nil {
            // ボールが停止中で、カウントダウン中でない場合のみ発射
            var angle: CGFloat
            
            // ボールの形状に基づいて角度を設定
            switch balls[index].shape {
            case .star:
                angle = -CGFloat.pi * 60 / 180
            case .circle:
                angle = -CGFloat.pi / 4
            case .oval:
                angle = -CGFloat.pi * 30 / 180
            }
            
            // わずかなランダム性を追加
            let randomAngle = CGFloat.random(in: -0.1...0.1)
            angle += randomAngle
            
            // 速度設定
            balls[index].velocity = CGVector(
                dx: baseVelocity * cos(angle),
                dy: baseVelocity * sin(angle)
            )
            
            balls[index].isMoving = true
            print("ボール \(index) を発射しました")
        }
    }
    
    // 次のレベルに進むメソッド
    func proceedToNextLevel() {
        level = nextLevel
        resetBalls()
        resetBlocks()
        isGameStarted = false
        isPaused = false
    }
    
    // レベルアップメッセージをスキップして次のレベルに進む
    func skipLevelUpMessage() {
        if showLevelUpMessage {
            levelUpMessageTimer = nil
            showLevelUpMessage = false
            proceedToNextLevel()
        }
    }
    
    // レーザーを発射
    func createLaser(at position: CGPoint, color: Color) {
        let laser = Laser(
            position: position,
            size: CGSize(width: 3, height: 15),
            velocity: CGVector(dx: 0, dy: laserVelocity),
            color: color
        )
        lasers.append(laser)
    }
    
    // レーザーを移動
    func moveLasers(deltaTime: TimeInterval) {
        for i in 0..<lasers.count {
            // 前回の位置を履歴に追加
            let currentPosition = lasers[i].position
            
            // 新しい位置を計算
            let oldY = currentPosition.y
            let newY = currentPosition.y + lasers[i].velocity.dy * CGFloat(deltaTime)
            
            // 位置を更新
            lasers[i].position.y = newY
            
            // 移動距離が十分あれば履歴に追加
            let moveDistance = lasers[i].size.height * 0.8 // レーザーの高さより短い距離で記録（1.2 → 0.8）
            let movedDistance = abs(newY - oldY)
            
            if lasers[i].positionHistory.isEmpty || movedDistance >= moveDistance {
                // 履歴の最大数を超える場合は古いものを削除
                if lasers[i].positionHistory.count >= lasers[i].maxHistoryLength {
                    lasers[i].positionHistory.removeFirst()
                }
                
                // 現在の位置からわずかに後ろの位置を履歴に追加
                let trailPosition = CGPoint(
                    x: currentPosition.x,
                    y: newY - (movedDistance * 0.3) // 現在位置から少し後ろ
                )
                lasers[i].positionHistory.append(trailPosition)
            }
            
            // 画面外に出たら削除
            if lasers[i].position.y > GameState.frameHeight + 30 {
                lasers.remove(at: i)
                break
            }
        }
    }
    
    // レーザーの衝突判定
    func checkLaserCollisions() {
        // パドルがすでにヒットされ処理中の場合はスキップ
        if paddleWasHit || showPaddleHitEffect {
            return
        }
        
        // 各レーザーに対して処理
        for i in (0..<lasers.count).reversed() {
            if i >= lasers.count { continue } // 配列の範囲チェック
            
            let laser = lasers[i]
            
            // パドルとの衝突判定
            if laser.position.y + laser.size.height / 2 >= paddle.position.y - paddle.size.height / 2 &&
               laser.position.y - laser.size.height / 2 <= paddle.position.y + paddle.size.height / 2 &&
               laser.position.x + laser.size.width / 2 >= paddle.position.x - paddle.size.width / 2 &&
               laser.position.x - laser.size.width / 2 <= paddle.position.x + paddle.size.width / 2 {
                
                // パドル衝突エフェクト表示
                showPaddleHitEffect = true
                paddleHitEffectTimer = 0.6 // 0.6秒間表示
                paddleHitEffectColor = laser.color // レーザーの色をエフェクトに使用
                paddleWasHit = true // パドルがヒットされたフラグをセット
                isGameFrozen = true // ゲームをフリーズ状態に設定
                
                // 画面フラッシュエフェクト表示
                showScreenFlash = true
                screenFlashTimer = 0.3 // 0.3秒間表示
                screenFlashColor = laser.color // レーザーの色をフラッシュに使用
                screenFlashOpacity = 0.7 // 初期不透明度
                
                // 全てのレーザーを削除
                lasers.removeAll()
                return // これ以上の処理は不要なので終了
            }
            
            // ボールとの衝突判定
            for j in 0..<balls.count {
                let ball = balls[j]
                
                // 動いていないボールはスキップ
                if !ball.isMoving { continue }
                
                // ボールとレーザーの距離を計算
                let dx = laser.position.x - ball.position.x
                let dy = laser.position.y - ball.position.y
                let distance = sqrt(dx * dx + dy * dy)
                
                // 衝突判定
                if distance < ball.effectiveRadius + laser.size.width / 2 {
                    // レーザーを削除
                    if i < lasers.count {
                        lasers.remove(at: i)
                    }
                    break
                }
            }
        }
    }
    
    // スターコンボを発動するメソッド
    func activateStarCombo(withColor color: Color) {
        // 同じ色のブロックを消滅予定にする
        starComboEffectColor = color
        showStarComboEffect = true
        starComboEffectTimer = 1.5
        
        // 同じ色のブロックを検索して削除予定にする
        for i in 0..<blocks.count {
            if blocks[i].color == color && !blocks[i].isAnimating && blocks[i].removeAfter == nil {
                var block = blocks[i]
                block.isAnimating = true
                block.isStarComboTarget = true
                block.removeAfter = Date().timeIntervalSince1970 + 0.7
                blocks[i] = block
                
                // 削除予定のブロックIDを記録
                starComboTargetBlocks.append(block.id)
                
                // スコア加算
                score += 20 // コンボボーナス
            }
        }
    }
}

// ゲーム要素の構造体
@MainActor
struct Paddle {
    var position: CGPoint = CGPoint(x: GameState.frameWidth / 2, y: GameState.frameHeight - 30)
    let size: CGSize = CGSize(width: 100, height: 15)
    let color: Color = .white
}

@MainActor
struct Ball {
    var position: CGPoint = CGPoint(x: GameState.frameWidth / 2, y: GameState.frameHeight / 2)
    var velocity: CGVector = CGVector(dx: 0, dy: 0)
    let radius: CGFloat = 7.5
    var growthFactor: CGFloat = 0 // ブロック衝突による成長係数（円形ボールのみ適用）
    var color: Color = .white // デフォルトは白だが、形状に応じて変更される
    var isMoving: Bool = false
    var shape: BallShape = .circle // ボールの形状
    var rotation: Angle = .zero // 回転角度
    var rotationSpeed: Double = 0 // 回転速度
    var positionHistory: [CGPoint] = [] // 過去の位置履歴
    var maxHistoryLength: Int = 5 // 履歴の最大保存数
    var reviveCountdown: Double? = nil // 復活までのカウントダウン（秒）
    
    // スターコンボ関連のプロパティ（星型ボール専用）
    var comboCount: Int = 0 // 現在のコンボカウント
    var lastHitBlockColor: Color? = nil // 最後に衝突したブロックの色
    
    // 成長を考慮した実際の半径を返す
    var effectiveRadius: CGFloat {
        return radius + (shape == .circle ? growthFactor : 0)
    }
}

enum BallShape {
    case star
    case circle
    case oval
}

struct Block: Identifiable {
    let id: UUID
    var position: CGPoint
    let size: CGSize
    let color: Color
    var isAnimating: Bool = false
    var removeAfter: TimeInterval? = nil
    var isAppearing: Bool = false // 出現アニメーション用フラグ
    var targetPosition: CGPoint? = nil // 移動アニメーション用の目標位置
    var isStarComboTarget: Bool = false // スターコンボで消滅予定のフラグ
}

// レーザー構造体
@MainActor
struct Laser {
    var position: CGPoint
    let size: CGSize
    let velocity: CGVector
    let color: Color // 赤固定ではなく、ブロックの色を引き継ぐ
    var positionHistory: [CGPoint] = [] // 過去の位置履歴
    let maxHistoryLength: Int = 8 // 履歴の最大保存数（6から8に増加）
} 
