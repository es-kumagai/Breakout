import SwiftUI
import Combine
import Foundation
import AVFoundation

// MainActor属性を追加して同期コンテキストの問題を解決
class GameState: ObservableObject {
    // ゲーム設定 - static letでメモリ効率化
    static let frameWidth: CGFloat = 800
    static let frameHeight: CGFloat = 600
    static let frameMargin: CGFloat = 120
    static let fps: Double = 60
    static let blockReplenishInterval: TimeInterval = 10.0
    static let requiredComboCount: Int = 7 // 必要なコンボカウント
    
    static var screenWidth: CGFloat {
        frameWidth + frameMargin * 2
    }

    static var screenHeight: CGFloat {
        frameHeight + frameMargin * 2
    }

    // メモリ効率化のための定数定義
    private let baseVelocity: CGFloat = 300  // 1秒あたりのピクセル数
    private let laserVelocity: CGFloat = 250  // 1秒あたりのピクセル数
    private let maxBallHistory: Int = 8 // ボール履歴の最大値
    private let initialLives: Int = 3
    private let levelClearBonus: Int = 100
    private let blockBreakScore: Int = 10
    private let comboBlockScore: Int = 20
    
    // 高性能レンダリング用のバッチ処理
    private var pendingComboTargets: [[UUID]] = [] // 複数バッチのブロックIDを管理
    private var currentBatchIndex: Int = 0 // 現在処理中のバッチインデックス
    private let maxVisibleBatchSize: Int = 5 // 一度に視覚的に表示するブロック数の上限（8→5に減少）
    private let batchProcessingInterval: Double = 0.3 // バッチ処理の間隔（秒）
    
    // ゲーム要素 - @Publishedを必要なものだけに限定
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
    @Published var isSoundEnabled: Bool = true // サウンド有効フラグ
    
    // スターコンボ関連（星型ボール専用）
    @Published var showStarComboEffect: Bool = false // スターコンボエフェクト表示フラグ
    @Published var starComboEffectTimer: Double? = nil // スターコンボエフェクトタイマー
    @Published var starComboEffectColor: Color = .yellow // スターコンボエフェクトの色
    @Published var starComboTargetBlocks: [UUID] = [] // コンボで消滅予定のブロックID
    @Published var starComboChainCount: Int = 0 // 連続コンボ回数を追跡
    
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
    
    // 全てのボールが落ちた時のメッセージ表示用
    @Published var showAllBallsLostMessage: Bool = false
    @Published var allBallsLostMessageTimer: Double? = nil
    
    // レーザーがパドルに当たった時のメッセージ表示用
    @Published var showLaserHitMessage: Bool = false
    @Published var laserHitMessageTimer: Double? = nil
    
    // ボール順次発射用のプロパティ
    private var pendingBallIndices: [Int] = [] // 発射待ちのボールインデックス
    private var nextBallLaunchTimer: Double? = nil // 次のボール発射までのタイマー
    private let ballLaunchInterval: Double = 0.2 // ボール発射間隔（秒）
    
    // 復活ボール発射管理用プロパティ
    private var revivedBallQueue: [Int] = [] // 復活して発射待ちのボールキュー
    private var revivedBallLaunchTimer: Double? = nil // 復活ボール発射タイマー
    private var shouldAutoLaunchRevivedBalls: Bool = false // 復活ボールの自動発射フラグ
    
    // 待機中ボールの時間差発射用プロパティ
    private var waitingBallLaunchInterval: Double = 0.3 // 待機中ボール発射間隔（秒）
    
    // メモリ効率化のためにSet型を使用
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?
    private var lastUpdateTime: TimeInterval = 0
    private var hitBlockIds = Set<UUID>()
    
    // ブロック補充の時間管理
    private var lastBlockReplenishTime: TimeInterval = 0
    
    // サウンドマネージャーの参照 - 実際のSoundManagerクラスがなければダミーで代用
    private let soundManager = DummySoundManager()
    
    // 共通で使う和風の色配列 - 毎回生成せずメモリ効率化
    private let japaneseColors: [Color] = [
        Color(red: 0.98, green: 0.77, blue: 0.85), // 桜色（さくらいろ）
        Color(red: 0.99, green: 0.79, blue: 0.13), // 山吹色（やまぶきいろ）
        Color(red: 0.56, green: 0.81, blue: 0.82), // 浅葱色（あさぎいろ）
        Color(red: 0.74, green: 0.91, blue: 0.6),  // 萌黄色（もえぎいろ）
        Color(red: 0.54, green: 0.79, blue: 0.93)  // 空色（そらいろ）
    ]
    
    // 安定性重視のバッチ処理用
    private var pendingComboBlocks: [Int] = [] // 処理待ちのブロックインデックス
    private let safeVisibleBatchSize: Int = 4 // 安全のため、一度に処理するブロック数を制限
    private let safeBatchInterval: Double = 0.3 // バッチ間の十分な間隔（GPUバッファのクリア時間確保）
    
    // ゲームの攻略ヒント関連のプロパティ
    @Published var currentHint: GameHint? = nil
    private var gameHints: [GameHint] = []
    
    init() {
        paddle = Paddle()
        balls = [] // 空の配列で初期化
        blocks = []
        
        // ヒントデータを読み込む
        loadGameHints()
        
        setupGame()
    }
    
    // メモリリーク防止のためのdeinit処理
    deinit {
        // タイマーのキャンセル
        timer?.cancel()
        cancellables.removeAll()
        
        // サウンドのクリーンアップ
        soundManager.stopAllSounds()
        
        // 参照サイクルの解消
        balls.removeAll()
        blocks.removeAll()
        lasers.removeAll()
        starComboTargetBlocks.removeAll()
        hitBlockIds.removeAll()
        
        // GPUリソースの明示的解放
        clearRenderingCache()
    }
    
    // サウンド設定の切り替え
    func toggleSound() {
        soundManager.toggleSound()
        isSoundEnabled = soundManager.isSoundEnabled
    }
    
    // ゲームが前面に来たときの処理（リソース再取得）
    func didBecomeActive() {
        if timer == nil || cancellables.isEmpty {
            startGameLoop()
        }
    }
    
    // ゲームがバックグラウンドになったときの処理（リソース解放）
    func didEnterBackground() {
        if !isGameOver && !isPaused {
            isPaused = true
        }
    }
    
    // バッファリングを最適化するためのメソッド
    func prepareForRendering() {
        // メモリの状態に関わらず定期的なクリーンアップを実行
        // 非表示の要素をクリア
        balls.indices.filter { balls[$0].position.y > GameState.frameHeight + 100 }.forEach {
            balls[$0].positionHistory.removeAll(keepingCapacity: true)
        }
        
        // 過剰な残像履歴をクリア - 数を減らす
        for i in 0..<balls.count {
            // 最大履歴を5に制限（元の8から削減）
            let reducedMaxHistory = 5
            if balls[i].positionHistory.count > reducedMaxHistory {
                balls[i].positionHistory.removeFirst(balls[i].positionHistory.count - reducedMaxHistory)
            }
        }
        
        // レーザーの残像履歴も最適化 - 数を減らす
        for i in 0..<lasers.count {
            // 最大履歴を4に制限
            let reducedMaxHistory = 4
            if lasers[i].positionHistory.count > reducedMaxHistory {
                lasers[i].positionHistory.removeFirst(lasers[i].positionHistory.count - reducedMaxHistory)
            }
        }
        
        // GPUメモリの安定性を確保するための追加対策
        if showStarComboEffect && starComboTargetBlocks.count > maxVisibleBatchSize {
            starComboTargetBlocks = Array(starComboTargetBlocks.prefix(maxVisibleBatchSize))
        }
        
        // 同時に表示するブロック数も制限
        let maxVisibleBlocks = 50
        if blocks.count > maxVisibleBlocks {
            // アニメーション中でないブロックのみを対象に制限
            let activeBlocks = blocks.filter { !$0.isAnimating && $0.removeAfter == nil }
            if activeBlocks.count > maxVisibleBlocks {
                // 必要な数だけ非表示にする処理を実装する場合（実際には表示制限だけで十分）
                // この部分は実際のゲームロジックに影響するため、実装は慎重に行う
            }
        }
    }
    
    func setupGame() {
        // パドルを初期位置に戻す
        paddle = Paddle()
        resetBalls()
        resetBlocks()
        
        // レーザーを全て削除
        lasers.removeAll(keepingCapacity: true)
        
        startGameLoop()
    }
    
    func resetBalls() {
        // パドルヒットフラグをリセット
        paddleWasHit = false
        
        // パドルの幅を元のサイズに戻す
        paddle.size.width = paddle.originalWidth
        
        // ボールの配列をクリア - キャパシティ指定でメモリ効率化
        balls.removeAll(keepingCapacity: true)
        
        // ブロック生成カウントダウンをリセット
        timeUntilNextBlocks = GameState.blockReplenishInterval
        
        // 連続コンボカウントをリセット
        starComboChainCount = 0
        
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
            ball.maxHistoryLength = maxBallHistory
            
            // 位置履歴を初期化 - キャパシティ指定でメモリ効率化
            ball.positionHistory = []
            ball.positionHistory.reserveCapacity(maxBallHistory)
            
            balls.append(ball)
        }
    }
    
    func startBalls() {
        // 発射順序の配列を作成 [1, 2, 0]（中央、右、左の順）
        pendingBallIndices = [1, 2, 0]
        
        // 最初のボール（中央）を発射
        if pendingBallIndices.count > 0 {
            let firstBallIndex = pendingBallIndices.removeFirst()
            launchBall(at: firstBallIndex)
            
            // 次のボール発射までのタイマーを設定
            nextBallLaunchTimer = ballLaunchInterval
        }
        
        // 発射音を再生
        soundManager.playSound(name: "ball_launch")
    }
    
    func resetBlocks() {
        // メモリ効率化
        blocks.removeAll(keepingCapacity: true)
        hitBlockIds.removeAll(keepingCapacity: true)
        
        let blockWidth: CGFloat = 70
        let blockHeight: CGFloat = 25
        let padding: CGFloat = 10
        let totalRows = 5
        let totalColumns = 10
        
        // ブロック全体の幅を計算
        let totalBlocksWidth = CGFloat(totalColumns) * blockWidth + CGFloat(totalColumns - 1) * padding
        // 左端の開始位置（中央揃え）
        let startX = (GameState.frameWidth - totalBlocksWidth) / 2
        
        // キャパシティ指定でメモリ効率化
        blocks.reserveCapacity(totalRows * totalColumns)
        
        for row in 0..<totalRows {
            for column in 0..<totalColumns {
                let xPos = startX + CGFloat(column) * (blockWidth + padding) + blockWidth / 2
                let yPos = padding + CGFloat(row) * (blockHeight + padding) + 50 + blockHeight / 2
                
                let block = Block(
                    id: UUID(),
                    position: CGPoint(x: xPos, y: yPos),
                    size: CGSize(width: blockWidth, height: blockHeight),
                    color: japaneseColors[row],
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
        
        // 次のボール発射タイマーを更新
        if let timer = nextBallLaunchTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // タイマー終了、次のボールを発射
                if !pendingBallIndices.isEmpty {
                    let nextBallIndex = pendingBallIndices.removeFirst()
                    launchBall(at: nextBallIndex)
                    
                    // まだ発射するボールが残っていれば、次のタイマーを設定
                    nextBallLaunchTimer = pendingBallIndices.isEmpty ? nil : waitingBallLaunchInterval
                    
                    print("時間差発射: ボール \(nextBallIndex) を発射、残り \(pendingBallIndices.count) 個")
                } else {
                    // 全てのボールを発射完了
                    nextBallLaunchTimer = nil
                    print("全てのボールの発射が完了しました")
                }
            } else {
                nextBallLaunchTimer = newTimer
            }
        }
        
        // 復活ボール発射タイマーを更新
        if let timer = revivedBallLaunchTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // タイマー終了、次の復活ボールを発射
                if !revivedBallQueue.isEmpty {
                    let nextBallIndex = revivedBallQueue.removeFirst()
                    launchBall(at: nextBallIndex)
                    
                    // まだ発射するボールが残っていれば、次のタイマーを設定
                    revivedBallLaunchTimer = revivedBallQueue.isEmpty ? nil : waitingBallLaunchInterval
                } else {
                    // 全ての復活ボールを発射完了
                    revivedBallLaunchTimer = nil
                    shouldAutoLaunchRevivedBalls = false
                }
            } else {
                revivedBallLaunchTimer = newTimer
            }
        }
        
        // スターコンボエフェクトタイマーを更新
        if let timer = starComboEffectTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // タイマー終了
                starComboEffectTimer = nil
                
                if !pendingComboBlocks.isEmpty {
                    // 次のバッチを処理
                    processNextComboBlockBatch()
                } else {
                    // すべての処理完了
                    showStarComboEffect = false
                    starComboTargetBlocks.removeAll(keepingCapacity: false)
                }
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
        
        // 全てのボールが落ちた時のメッセージタイマーを更新
        if let timer = allBallsLostMessageTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // タイマー終了、ゲームを再開
                allBallsLostMessageTimer = nil
                showAllBallsLostMessage = false
                isGameFrozen = false
                
                // 全てのレーザーを削除
                lasers.removeAll(keepingCapacity: true)
                
                // パドルヒットフラグをリセット
                paddleWasHit = false
                
                // ボールをリセットして再開（ただしisGameStarted = falseにするだけで自動発射はしない）
                resetBalls()
                isGameStarted = false
            } else {
                allBallsLostMessageTimer = newTimer
            }
        }
        
        // レーザー衝突メッセージタイマーを更新
        if let timer = laserHitMessageTimer {
            let newTimer = timer - deltaTime
            if newTimer <= 0 {
                // タイマー終了、メッセージを非表示にする
                laserHitMessageTimer = nil
                showLaserHitMessage = false
                
                // ゲームオーバーの場合は処理を変更
                if lives <= 0 || isGameOver {
                    // ゲームオーバー確定
                    isGameOver = true
                    isGameFrozen = false
                    lasers.removeAll() // ゲームオーバー時にすべてのレーザーを削除
                    print("レーザーがパドルに衝突し、ゲームオーバーになりました。")
                    
                    // ゲームオーバー処理を実行（ヒント表示）
                    gameOver()
                } else {
                    // ライフが残っている場合
                    isGameFrozen = false
                    
                    // パドルヒットフラグをリセット
                    paddleWasHit = false
                    
                    // ゲームを再開（ただしisGameStarted = falseにするだけで自動発射はしない）
                    resetBalls()
                    lasers.removeAll() // 全てのレーザーを削除
                    isGameStarted = false
                    print("レーザーがパドルに衝突しました。残りライフ: \(lives)")
                }
            } else {
                laserHitMessageTimer = newTimer
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
                
                // ライフがなくなった場合、確実にゲームオーバーにする
                if lives <= 0 {
                    isGameOver = true
                    isGameFrozen = false
                    print("ライフがなくなりました。ゲームオーバー")
                    
                    // エフェクトフラグをリセット
                    paddleWasHit = false
                    showLaserHitMessage = false
                    laserHitMessageTimer = nil
                    
                    // 全てのレーザーを削除
                    lasers.removeAll(keepingCapacity: true)
                    return
                }
                
                // レーザー衝突メッセージを表示中の場合はゲームフリーズ状態を維持
                if !showLaserHitMessage {
                    isGameFrozen = false // ゲームフリーズ状態を解除
                }
                
                // エフェクト表示終了後、パドルヒット処理を実行
                if paddleWasHit && !showLaserHitMessage {
                    paddleWasHit = false // フラグをリセット
                    
                    // ゲームオーバーまたは再開
                    if lives > 0 {
                        // ライフが残っている場合は再開（ただしisGameStarted = falseにするだけで自動発射はしない）
                        resetBalls()
                        lasers.removeAll() // 全てのレーザーを削除
                        isGameStarted = false
                        print("レーザーがパドルに衝突しました。残りライフ: \(lives)")
                    } else {
                        // ライフが0になったらゲームオーバー
                        isGameOver = true
                        lasers.removeAll() // ゲームオーバー時にすべてのレーザーを削除
                        print("レーザーがパドルに衝突し、ゲームオーバーになりました。")
                        
                        // ゲームオーバー処理を実行（ヒント表示）
                        gameOver()
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
            
            // 位置履歴を更新 - 専用メソッドを使用
            let dx = balls[i].position.x - oldPosition.x
            let dy = balls[i].position.y - oldPosition.y
            let movedDistance = sqrt(dx * dx + dy * dy)
            
            // 十分な距離を移動したか、最後の残像から時間が経過した場合に記録
            if movedDistance >= balls[i].radius * 0.5 || balls[i].positionHistory.isEmpty {
                updateTrailHistory(for: &balls[i], oldPosition: oldPosition)
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
                        
                        // 残像履歴を更新（新しい位置を追加）
                        updateTrailHistory(for: &newBall2, oldPosition: ball2.position)
                        
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
                        
                        // 残像履歴を更新（新しい位置を追加）
                        updateTrailHistory(for: &newBall1, oldPosition: ball1.position)
                        
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
                            
                            // 保存用に現在位置を記録
                            let oldPosition1 = ball1.position
                            let oldPosition2 = ball2.position
                            
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
                            
                            // 残像履歴を更新（衝突前の位置から新しい位置への自然な遷移）
                            updateTrailHistory(for: &newBall1, oldPosition: oldPosition1)
                            updateTrailHistory(for: &newBall2, oldPosition: oldPosition2)
                            
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
    
    // 残像の履歴を適切に更新するヘルパーメソッド
    private func updateTrailHistory(for ball: inout Ball, oldPosition: CGPoint) {
        // 移動距離が十分に大きい場合のみ履歴に追加
        let dx = ball.position.x - oldPosition.x
        let dy = ball.position.y - oldPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > ball.radius * 0.5 || ball.positionHistory.isEmpty {
            // 最大履歴数を超える場合は古いものを削除
            if ball.positionHistory.count >= ball.maxHistoryLength {
                ball.positionHistory.removeFirst()
            }
            
            // 残像は現在位置から少し後ろの位置に表示
            let trailPosition = CGPoint(
                x: oldPosition.x + dx * 0.3, // 現在位置と前の位置の間
                y: oldPosition.y + dy * 0.3
            )
            ball.positionHistory.append(trailPosition)
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
                // 衝突前の位置を保存
                let oldPosition = balls[i].position
                
                // ボールの形状に基づいて反射角度を計算
                applyShapeBasedReflection(ballIndex: i, isWallCollision: true, isHorizontal: true)
                
                // 壁にめり込まないように位置を調整
                if balls[i].position.x - balls[i].effectiveRadius <= 0 {
                    balls[i].position.x = balls[i].effectiveRadius
                } else {
                    balls[i].position.x = GameState.frameWidth - balls[i].effectiveRadius
                }
                
                // 残像を更新
                updateTrailHistory(for: &balls[i], oldPosition: oldPosition)
            }
            
            if balls[i].position.y - balls[i].effectiveRadius <= 0 {
                // 衝突前の位置を保存
                let oldPosition = balls[i].position
                
                // ボールの形状に基づいて反射角度を計算
                applyShapeBasedReflection(ballIndex: i, isWallCollision: true, isHorizontal: false)
                
                // 上部にめり込まないように調整
                balls[i].position.y = balls[i].effectiveRadius
                
                // 残像を更新
                updateTrailHistory(for: &balls[i], oldPosition: oldPosition)
            }
            
            // パドルとの衝突
            if balls[i].position.y + balls[i].effectiveRadius >= paddle.position.y - paddle.size.height / 2 &&
               balls[i].position.y - balls[i].effectiveRadius <= paddle.position.y + paddle.size.height / 2 &&
               balls[i].position.x + balls[i].effectiveRadius >= paddle.position.x - paddle.size.width / 2 &&
               balls[i].position.x - balls[i].effectiveRadius <= paddle.position.x + paddle.size.width / 2 {
                
                // 衝突前の位置を保存
                let oldPosition = balls[i].position
                
                // パドルの中心からの距離に基づいて反射角度を計算
                let hitPosition = (balls[i].position.x - paddle.position.x) / (paddle.size.width / 2)
                
                // ボールの形状に基づいて角度の補正係数を決定
                let angleModifier: CGFloat
                switch balls[i].shape {
                case .star:
                    // 星型は鋭く反射（よりランダム性と鋭さを持つ）
                    angleModifier = 1.2
                    
                    // スターコンボ連続カウントをリセット
                    starComboChainCount = 0
                    
                    // 個別のボールのcomboCountもリセット
                    balls[i].comboCount = 0
                    balls[i].lastHitBlockColor = nil
                    print("星型ボールがパドルに当たったため、コンボカウントとチェインカウントをリセットしました")
                    
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
                
                // 残像を更新
                updateTrailHistory(for: &balls[i], oldPosition: oldPosition)
            }
            
            // ブロックとの衝突
            checkBallBlockCollisions(ballIndex: i)
            
            // 下部境界外に出たらボールを削除または失敗状態にする
            if balls[i].position.y - balls[i].effectiveRadius > GameState.frameHeight {
                // 既にカウントダウン中のボールはスキップ
                if balls[i].reviveCountdown != nil {
                    continue
                }
                
                // 星型ボールの場合、comboCountをリセットし、連続コンボもリセット
                if balls[i].shape == .star {
                    print("星型ボールが画面外に出たため、コンボカウントをリセットしました")
                    balls[i].comboCount = 0
                    balls[i].lastHitBlockColor = nil
                    starComboChainCount = 0 // 連続コンボもリセット
                }
                
                // 楕円形ボールの場合、パドルの長さを元に戻す
                if balls[i].shape == .oval {
                    if paddle.size.width < paddle.originalWidth {
                        paddle.size.width = paddle.originalWidth
                        print("楕円形ボールが画面外に出たため、パドルのサイズを元に戻しました: \(paddle.size.width)")
                    }
                }
                
                // ボールが落下した場合
                
                // 他のボールがまだ動いているかをチェック
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
                    
                    // 残像履歴をクリア
                    updatedBall.positionHistory.removeAll(keepingCapacity: true)
                    
                    balls[i] = updatedBall
                } else {
                    // 全てのボールが落ちた場合、ライフを減らしてメッセージを表示
                    lives -= 1
                    if lives <= 0 {
                        // ライフが0になったらゲームオーバー
                        isGameOver = true
                        print("全てのボールが落下し、ライフがなくなりました。ゲームオーバー")
                        
                        // ゲームオーバー処理を実行（ヒント表示）
                        gameOver()
                    } else {
                        // ライフが残っている場合は一時停止してメッセージを表示
                        isGameFrozen = true
                        showAllBallsLostMessage = true
                        allBallsLostMessageTimer = 3.0 // 3秒間メッセージを表示
                        
                        // ランダムなヒントを設定
                        currentHint = getRandomHint()

                        // 画面フラッシュエフェクト（警告として赤色）
                        showScreenFlash = true
                        screenFlashColor = .red
                        screenFlashTimer = 0.3
                        screenFlashOpacity = 0.5
                        
                        print("全てのボールが落下しました。残りライフ: \(lives)")
                    }
                }
                
                if balls[i].isMoving {
                    // コンボをリセット（パドルに触れるまでコンボはリセット）
                    starComboChainCount = 0
                    if balls[i].shape == .star {
                        balls[i].comboCount = 0
                    }
                    
                    // サウンド再生
                    soundManager.playSound(name: "ball_lost")
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
                
                // 衝突前の位置を保存
                let oldPosition = balls[ballIndex].position
                
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
                
                // 残像を更新
                updateTrailHistory(for: &balls[ballIndex], oldPosition: oldPosition)
                
                // 円形ボールの場合、直径を1px大きくする
                if balls[ballIndex].shape == .circle {
                    balls[ballIndex].growthFactor += 0.5 // 半径を0.5px増やす（直径で1px増加）
                }
                
                // 楕円形ボールの場合、パドルの幅を1px小さくする
                if balls[ballIndex].shape == .oval {
                    // パドルが元のサイズの半分より大きい場合のみ縮小する
                    if paddle.size.width > paddle.originalWidth / 2 {
                        paddle.size.width -= 1
                        print("パドルのサイズを縮小: \(paddle.size.width)")
                    }
                }
                
                // スターコンボ処理（星型ボールの場合）
                if balls[ballIndex].shape == .star {
                    // カウントを増やす
                    balls[ballIndex].comboCount += 1
                    
                    // 衝突したブロックの色を記録
                    balls[ballIndex].lastHitBlockColor = block.color
                    
                    // 必要なコンボ回数に達したらコンボ発動
                    if balls[ballIndex].comboCount >= GameState.requiredComboCount {
                        // スターコンボを発動
                        activateStarCombo(withColor: block.color)
                        // コンボカウントをリセット（連続コンボのため）
                        balls[ballIndex].comboCount = 0
                    }
                    
                    // 現在のコンボ状況を表示
                    print("星型ボールのコンボカウント: \(balls[ballIndex].comboCount)/\(GameState.requiredComboCount), 連続コンボ: \(starComboChainCount)")
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
                score += blockBreakScore // 通常のブロック破壊スコア
                
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
            
            // 画面上のレーザーをすべて消去
            lasers.removeAll(keepingCapacity: true)
            
            // ゲームは一時停止状態に
            isPaused = true
        }
    }
    
    func restartGame() {
        isGameOver = false
        lives = initialLives
        score = 0
        level = 1
        
        // パドルのサイズを元に戻す
        paddle.size.width = paddle.originalWidth
        
        // すべてのエフェクトフラグをリセット
        isGameFrozen = false
        showScreenFlash = false
        screenFlashTimer = nil
        showPaddleHitEffect = false
        paddleHitEffectTimer = nil
        showLaserHitMessage = false
        laserHitMessageTimer = nil
        showAllBallsLostMessage = false
        allBallsLostMessageTimer = nil
        showLevelUpMessage = false
        levelUpMessageTimer = nil
        paddleWasHit = false
        
        // ヒントをクリア
        currentHint = nil
        
        setupGame()
        soundManager.playSound(name: "level_up")
    }
    
    func startGame() {
        // レーザーを全て削除
        lasers.removeAll(keepingCapacity: true)
        
        // パドルヒットフラグをリセット
        paddleWasHit = false
        
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
                    
                    // ゲームオーバー処理を実行（ヒント表示）
                    gameOver()
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
        let currentTime = Date().timeIntervalSince1970
        
        // GPUメモリを最適化するため、一度に処理するアニメーションブロック数を制限
        var animatingCount = 0
        let maxAnimatingBlocks = 30 // 最大同時アニメーションブロック数
        
        // アニメーション終了したブロックを削除（逆順に処理して安全に削除）
        for i in (0..<blocks.count).reversed() {
            if let removeAfter = blocks[i].removeAfter, currentTime >= removeAfter {
                blocks.remove(at: i)
                continue // 削除したブロックは以降の処理をスキップ
            }
            
            // アニメーション中のブロック数をカウント
            if blocks[i].isAnimating || blocks[i].isAppearing || blocks[i].targetPosition != nil {
                animatingCount += 1
                
                // 最大数を超えたらアニメーションを制限（ただし処理自体は継続）
                if animatingCount > maxAnimatingBlocks {
                    continue
                }
            }
            
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
        // GPUバッファを節約するため、カウントダウン表示を最適化
        var visibleCountdowns = 0
        let maxVisibleCountdowns = 2 // 同時に表示するカウントダウンの最大数
        
        // 同時復活の検出用変数（使用しないが念のため保持）
        var justRevivedBallsCount = 0
        var justRevivedBallIndices: [Int] = []
        
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
                
                // 表示数をカウント
                visibleCountdowns += 1
                                
                // カウントダウンが0以下になったらボールを復活
                if newCountdown <= 0 {
                    print("ボール \(i) が復活します")
                    reviveBall(at: i)
                    
                    // 同時復活カウント（統計用に記録するが使用しない）
                    justRevivedBallsCount += 1
                    justRevivedBallIndices.append(i)
                }
                
                // 最大表示数を超えた場合は処理のみ行い表示は制限
                if visibleCountdowns > maxVisibleCountdowns {
                    // この処理はUI表示に関する制限のため、実際のゲームロジックには影響しない
                }
            }
        }
        
        // 自動発射ロジックは使用しない - 復活したボールはクリックまで待機するように修正
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
        
        // 自動発射フラグは常にOFFに設定 - 復活ボールはクリックまで待機
        shouldAutoLaunchRevivedBalls = false
        
        print("ボール \(index) が復活し、クリック待機中です。待機中ボール数: \(waitingCount + 1)")
    }
    
    // 特定のボールを発射するメソッドを追加
    func launchBall(at index: Int) {
        guard index < balls.count else { return }
        
        let ball = balls[index]
        if ball.isMoving || ball.reviveCountdown != nil {
            return
        }
        
        // パドルの位置に基づいて発射角度を計算
        // パドルの中央からの相対位置を -1.0 から 1.0 の範囲で計算
        let paddleRelativePos = (ball.position.x - paddle.position.x) / (paddle.size.width / 2)
        
        // 相対位置に基づいて角度を計算（-45度から45度の範囲）
        // 真ん中(0)なら0度、右端(1.0)なら45度、左端(-1.0)なら-45度
        let angle = paddleRelativePos * (.pi / 4) // π/4 = 45度
        
        let speed = baseVelocity * (1.0 + CGFloat(level) * 0.05) // レベルごとに5%ずつ速度増加
        let dx = speed * CGFloat(sin(angle))
        let dy = -speed * CGFloat(cos(angle)) // 上方向に発射
        
        balls[index].velocity = CGVector(dx: dx, dy: dy)
        balls[index].isMoving = true
        
        // 発射音を再生
        soundManager.playSound(name: "ball_launch")
        
        print("ボールを発射: 角度 \(angle * 180 / .pi)度, 速度 \(speed)")
    }
    
    // 次のレベルに進むメソッド
    func proceedToNextLevel() {
        // 丸いボールの現在の大きさを保存
        let circleGrowthFactors = balls.map { ball in
            ball.shape == .circle ? ball.growthFactor : 0
        }
        
        level = nextLevel
        
        // レベルアップボーナスとしてライフを1追加
        lives += 1
        print("レベルアップボーナス: ライフが1追加されました。現在のライフ: \(lives)")
        
        // パドルの幅を元のサイズに戻す
        paddle.size.width = paddle.originalWidth
        
        // 全てのレーザーを削除
        lasers.removeAll(keepingCapacity: true)
        
        resetBalls()
        
        // 丸いボールの大きさを元に戻す
        for i in 0..<min(balls.count, circleGrowthFactors.count) {
            if balls[i].shape == .circle {
                balls[i].growthFactor = circleGrowthFactors[i]
                print("丸いボールの大きさを引き継ぎました: \(balls[i].growthFactor)")
            }
        }
        
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
                
                // ライフを減らす
                lives -= 1
                
                // ライフがなくなった場合はゲームオーバー処理
                if lives <= 0 {
                    // ゲームオーバーフラグを設定
                    isGameOver = true
                    isGameFrozen = false // ゲームオーバー時はフリーズ解除
                    
                    // ランダムなヒントを設定
                    currentHint = getRandomHint()

                    // エフェクト表示を短くして、確実に終了するように
                    showScreenFlash = false
                    screenFlashTimer = 0.3
                    screenFlashColor = .red
                    screenFlashOpacity = 0.7
                    
                    // 衝突エフェクトフラグはリセット（画面フラッシュのみ表示）
                    showPaddleHitEffect = false
                    paddleHitEffectTimer = nil
                    showLaserHitMessage = false
                    laserHitMessageTimer = nil
                    
                    // 全てのレーザーを削除
                    lasers.removeAll()
                    
                    // ゲームオーバー処理を実行
                    gameOver()
                    
                    print("レーザーの衝突でライフが0になり、ゲームオーバーになりました")
                    return // ゲームオーバー時はここで終了
                }
                
                // ライフが残っている場合は通常の衝突処理
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
                
                // レーザー衝突メッセージを表示
                showLaserHitMessage = true
                laserHitMessageTimer = 3.0 // 3秒間メッセージを表示
                
                // ランダムなヒントを設定
                currentHint = getRandomHint()

                // 全てのレーザーを削除
                lasers.removeAll()
                return // これ以上の処理は不要なので終了
            }
            
            // ボールとの衝突判定 - 発射前のボールも含めて全てのボールをチェック
            for j in 0..<balls.count {
                let ball = balls[j]
                
                // ボールの動き状態に関わらず、すべてのボールに対して衝突判定を行う
                // カウントダウン中のボールのみスキップ
                if ball.reviveCountdown != nil { continue }
                
                // ボールとレーザーの距離を計算
                let dx = laser.position.x - ball.position.x
                let dy = laser.position.y - ball.position.y
                let distance = sqrt(dx * dx + dy * dy)
                
                // 衝突判定
                if distance < ball.effectiveRadius + laser.size.width / 2 {
                    // レーザー衝突エフェクト（オプション）
                    if isSoundEnabled {
                        soundManager.playSound(name: "laser_hit")
                    }
                    
                    // レーザーを削除
                    if i < lasers.count {
                        lasers.remove(at: i)
                    }
                    
                    // 発射前のボールに当たった場合のログ（デバッグ用）
                    if !ball.isMoving {
                        print("発射前のボールにレーザーが衝突しました")
                    }
                    
                    break
                }
            }
        }
    }
    
    // スターコンボを発動するメソッド
    func activateStarCombo(withColor color: Color) {
        // すでにコンボ処理中の場合はスキップ（安定性重視）
        if showStarComboEffect {
            print("⚠️ 前のコンボが処理中のため、新しいコンボはスキップされました")
            return
        }
        
        // 同じ色のブロックを消滅予定にする
        starComboEffectColor = color
        showStarComboEffect = true
        starComboEffectTimer = safeBatchInterval // 安全な間隔
        
        // 連続コンボカウントを増加
        starComboChainCount += 1
        
        // 連続コンボが2回以上の場合、ライフを1追加
        if starComboChainCount >= 2 {
            lives += 1
            print("連続スターコンボ達成！ライフが1追加されました。現在のライフ: \(lives)")
            
            // 2回目のコンボでライフが増えた後は、さらに3回ごとにライフを増やす
            if starComboChainCount >= 5 && (starComboChainCount - 2) % 3 == 0 {
                lives += 1
                print("高度な連続コンボ達成！さらにライフが1追加されました。現在のライフ: \(lives)")
            }
        }
        
        // 同じ色のブロックを検索して保存
        pendingComboBlocks.removeAll(keepingCapacity: true)
        for i in 0..<blocks.count {
            if blocks[i].color == color && !blocks[i].isAnimating && blocks[i].removeAfter == nil {
                pendingComboBlocks.append(i)
            }
        }
        
        // 全てのブロックに対してスコアを加算（最終的に全て消えるので）
        score += pendingComboBlocks.count * comboBlockScore
        
        print("スターコンボ発動！連続コンボ数: \(starComboChainCount)、対象ブロック数: \(pendingComboBlocks.count)")
        
        // バッチサイズを制限（GPU処理量を削減）
        if pendingComboBlocks.count > maxVisibleBatchSize * 5 {
            // 最大処理数を制限
            let maxTotalBlocks = maxVisibleBatchSize * 5
            if pendingComboBlocks.count > maxTotalBlocks {
                pendingComboBlocks = Array(pendingComboBlocks.prefix(maxTotalBlocks))
                print("パフォーマンス最適化: コンボ対象を\(maxTotalBlocks)個に制限しました")
            }
        }
        
        // 最初のバッチを処理
        processNextComboBlockBatch()
    }
    
    // 次のブロックバッチを処理する安全なメソッド
    private func processNextComboBlockBatch() {
        starComboTargetBlocks.removeAll(keepingCapacity: true) // GPUメモリを確実にクリア
        
        // 処理するブロックがなければ終了
        if pendingComboBlocks.isEmpty {
            showStarComboEffect = false
            starComboEffectTimer = nil
            return
        }
        
        // 安全に処理できるブロック数を決定
        let batchSize = min(pendingComboBlocks.count, safeVisibleBatchSize)
        
        // スターコンボの効果音を再生
        if isSoundEnabled && batchSize > 0 {
            soundManager.playSound(name: "star_combo")
        }
        
        // バッチを処理
        for _ in 0..<batchSize {
            guard !pendingComboBlocks.isEmpty else { break }
            
            let blockIndex = pendingComboBlocks.removeFirst()
            
            // インデックスが有効範囲内かチェック
            guard blockIndex < blocks.count else { continue }
            
            var block = blocks[blockIndex]
            // すでにアニメーション中または削除予定のブロックはスキップ
            if block.isAnimating || block.removeAfter != nil {
                continue
            }
            
            // 通常のブロック破壊と同じエフェクトを適用
            
            // 1. ブロックをアニメーション状態に設定
            block.isAnimating = true
            block.isStarComboTarget = true
            block.removeAfter = Date().timeIntervalSince1970 + 0.7
            
            // 2. レーザーを発射（通常のブロック破壊と同様）
            createLaser(at: block.position, color: block.color)
            
            // 3. スターコンボの特別エフェクト（ヒットエフェクト）
            // 通常のヒットエフェクトよりも少し華やかに
            let randomOffset = CGFloat.random(in: -5...5)
            createLaser(at: CGPoint(x: block.position.x + randomOffset, 
                                    y: block.position.y + randomOffset), 
                       color: starComboEffectColor)
            
            // ブロック更新を適用
            blocks[blockIndex] = block
            
            // 視覚効果用の配列に追加（厳格に制限）
            starComboTargetBlocks.append(block.id)
        }
        
        // 次のバッチのタイマーを設定
        if !pendingComboBlocks.isEmpty {
            starComboEffectTimer = 0.25 // バッチ間隔を少し短くしてスムーズに
            print("コンボ処理中: 残り \(pendingComboBlocks.count) ブロック")
        } else {
            // 処理完了
            starComboEffectTimer = 0.5 // 最後のバッチは少し長めに表示
            print("コンボ処理完了")
        }
    }
    
    // レーザーとパドルの衝突処理
    func handleLaserPaddleCollision(laserIndex: Int) async {
        // レーザーを削除
        if laserIndex < lasers.count {
            lasers.remove(at: laserIndex)
        }
        
        // ゲームフリーズ効果
        isGameFrozen = true
        
        // パドル衝突エフェクト表示
        showPaddleHitEffect = true
        paddleHitEffectTimer = 1.0
        paddleWasHit = true
        
        // レーザー衝突サウンドを再生
        soundManager.playSound(name: "laser")
        
        // 画面フラッシュ効果
        triggerScreenFlash(color: Color.red)
        
        // 0.75秒後にゲームフリーズを解除
        try? await Task.sleep(for: .seconds(0.75))
        isGameFrozen = false
    }
    
    // レベルアップ処理
    func levelUp() {
        level += 1
        nextLevel = level
        showLevelUpMessage = true
        levelUpMessageTimer = 2.0
        
        // スコアボーナス（一定数のポイントを加算）
        score += 100
        
        // ブロックをリセットして次レベル開始
        resetBlocks()
        
        // レベルアップサウンドを再生
        soundManager.playSound(name: "level_up")
    }
    
    // ゲームオーバー処理
    func gameOver() {
        isGameOver = true
        timer?.cancel()
        isGameStarted = false

        // ゲームオーバーサウンドを再生
        soundManager.playSound(name: "game_over")
    }
    
    // 画面フラッシュ効果を開始するメソッド
    func triggerScreenFlash(color: Color) {
        showScreenFlash = true
        screenFlashTimer = 0.3 // 0.3秒間表示
        screenFlashColor = color
        screenFlashOpacity = 0.7 // 初期不透明度
    }
    
    // GPUレンダリングの最適化（スターコンボエフェクト用）
    func optimizeStarComboEffectForGPU() {
        // 新しいバッチ処理方式では不要
        // ここは互換性のためだけに残す
    }
    
    // MovingBlock構造体を追加（GPUメモリ最適化のためのキャッシュ）
    struct MovingBlockCache {
        let blockId: UUID
        let originalPosition: CGPoint
        let targetPosition: CGPoint
        let progress: CGFloat
        
        // 現在の位置を計算（レンダリング時のリアルタイム計算を減らす）
        var currentPosition: CGPoint {
            let x = originalPosition.x + (targetPosition.x - originalPosition.x) * progress
            let y = originalPosition.y + (targetPosition.y - originalPosition.y) * progress
            return CGPoint(x: x, y: y)
        }
    }
    
    // レンダリングのためにプリコンピューティングされたデータをクリア
    func clearRenderingCache() {
        // ゲームが一時停止された時や、メモリ警告時に呼び出す
        hitBlockIds.removeAll(keepingCapacity: true)
        
        // スターコンボがアクティブでなければ関連データをクリア
        if !showStarComboEffect {
            starComboTargetBlocks.removeAll(keepingCapacity: true)
        }
    }
    
    // 待機中のボールをまとめて発射するメソッド（クリックハンドラから呼び出される）
    func startWaitingBalls() {
        // 既にボール発射タイマーが動作中の場合は何もしない（二重発射防止）
        if nextBallLaunchTimer != nil {
            print("ボール発射タイマーが既に動作中です")
            return
        }
        
        // 待機中のボールをリストアップ（移動していなくてカウントダウンもないボール）
        let waitingBallIndices = balls.indices.filter { idx in
            !balls[idx].isMoving && balls[idx].reviveCountdown == nil
        }
        
        // 待機中のボールが無ければ何もしない
        if waitingBallIndices.isEmpty {
            return
        }
        
        // 待機中のボールが1つだけなら即発射
        if waitingBallIndices.count == 1 {
            launchBall(at: waitingBallIndices[0])
            return
        }
        
        // 待機中のボールが2つ以上あるなら時間差発射
        if waitingBallIndices.count >= 2 {
            // 待機中のボールをキューに設定
            pendingBallIndices = Array(waitingBallIndices)
            
            // 最初のボールを即座に発射
            let firstBallIndex = pendingBallIndices.removeFirst()
            launchBall(at: firstBallIndex)
            
            // 2つ目以降のボールのタイマーを設定
            if !pendingBallIndices.isEmpty {
                nextBallLaunchTimer = waitingBallLaunchInterval
            }
            
            print("複数のボールを時間差発射します: 残り\(pendingBallIndices.count)個")
        }
    }
    
    // ヒントデータをplistから読み込む
    private func loadGameHints() {
        guard let url = Bundle.main.url(forResource: "GameHints", withExtension: "plist") else {
            fatalError("攻略ヒントのplistファイルが見つかりません")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = PropertyListDecoder()
            let hints = try decoder.decode([GameHint].self, from: data)
            gameHints = hints
            print("攻略ヒントを\(hints.count)件読み込みました")
            
            guard hints.count > 0 else {
                fatalError("攻略ヒントは１つ以上必要です。")
            }
            
            guard !hints.contains(where: \.isIllformed) else {
                fatalError("不正な攻略ヒントデータがあります。")
            }
        } catch {
            fatalError("攻略ヒントの読み込みに失敗しました: \(error)")
        }
    }
    
    // ランダムなヒントを取得する
    private func getRandomHint() -> GameHint {
        gameHints.randomElement()!
    }
}

// ボールの形状を表す列挙型
enum BallShape {
    case star
    case circle
    case oval
}

// ゲーム要素の構造体
struct Paddle {
    var position: CGPoint = CGPoint(x: GameState.frameWidth / 2, y: GameState.frameHeight - 30)
    var size: CGSize = CGSize(width: 100, height: 15) // 可変にする
    let originalWidth: CGFloat = 100 // 元のサイズを保持する定数
    let color: Color = .white
}

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
struct Laser {
    var position: CGPoint
    let size: CGSize
    let velocity: CGVector
    let color: Color // 赤固定ではなく、ブロックの色を引き継ぐ
    var positionHistory: [CGPoint] = [] // 過去の位置履歴
    let maxHistoryLength: Int = 8 // 履歴の最大保存数（6から8に増加）
}

// ダミーのSoundManagerクラス（実際のクラスがある場合は不要）
class DummySoundManager {
    var isSoundEnabled: Bool = true
    
    func playSound(name: String) {
        // 実際には何もしない
        print("サウンド再生（ダミー）: \(name)")
    }
    
    func toggleSound() {
        isSoundEnabled.toggle()
    }
    
    func stopAllSounds() {
        // 実際には何もしない
    }
}

// 攻略ヒントの構造体
struct GameHint: Codable, Identifiable, Hashable {
    let caption: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case caption = "キャプション"
        case content = "内容"
    }

    var id: Int {
        hashValue
    }
    
    var isIllformed: Bool {
        caption.isEmpty || content.isEmpty
    }
}
