import SwiftUI

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