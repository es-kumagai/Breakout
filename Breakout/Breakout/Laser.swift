import SwiftUI

struct Laser {
    var position: CGPoint
    let size: CGSize
    let velocity: CGVector
    let color: Color // 赤固定ではなく、ブロックの色を引き継ぐ
    var positionHistory: [CGPoint] = [] // 過去の位置履歴
    let maxHistoryLength: Int = 8 // 履歴の最大保存数（6から8に増加）
} 