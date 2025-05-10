// 攻略のヒント表示ビュー
import SwiftUI

struct GameHintView: View {
    let hint: GameHint
    
    var body: some View {
        VStack(spacing: 10) {
            Text("攻略のヒント")
                .font(.title3)
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
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)
            Text(hint.content)
                .font(.body)
                .foregroundColor(Color(white: 0.8))
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
