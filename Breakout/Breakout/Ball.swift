import SwiftUI

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