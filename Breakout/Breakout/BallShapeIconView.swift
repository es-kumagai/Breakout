// ボール形状アイコンビュー
import SwiftUI

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