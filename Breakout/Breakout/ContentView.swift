import SwiftUI

// GameViewとGameStateの参照エラーを解決するためのインポート
import Foundation

struct ContentView: View {
    @StateObject private var gameState = GameState()
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // ゲームビュー
            VStack {
                GameView()
                    .environmentObject(gameState)
            }
            .frame(width: 800, height: 600)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
            )
            .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 0)
        }
        // SwiftUIのレンダリングをゲームに最適化
        .drawingGroup()
    }
}

#Preview {
    ContentView()
} 