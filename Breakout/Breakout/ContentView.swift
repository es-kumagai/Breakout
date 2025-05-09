import SwiftUI

struct ContentView: View {
    @StateObject private var gameState = GameState()
    
    var body: some View {
        VStack {
            GameView()
                .environmentObject(gameState)
        }
        .frame(width: 800, height: 600)
        .background(Color.black)
        // SwiftUIのレンダリングをゲームに最適化
        .drawingGroup()
    }
}

#Preview {
    ContentView()
} 