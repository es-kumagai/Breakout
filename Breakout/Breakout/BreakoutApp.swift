import SwiftUI
import Foundation
import Combine
import AVFoundation

@main
struct BreakoutApp: App {
    // 最初のキーボードフォーカスを設定
    @State private var isInitialFocusSet = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: GameState.screenWidth, minHeight: GameState.screenHeight)
                .frame(maxWidth: GameState.screenWidth, maxHeight: GameState.screenHeight)
                .navigationTitle("ブレイクアウト")
                .background(Color.black)
                // 起動時のキーボードフォーカス設定
                .onAppear {
                    if !isInitialFocusSet {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // フォーカスの制御
                            NSApp.mainWindow?.makeFirstResponder(nil)
                            isInitialFocusSet = true
                        }
                    }
                }
                // アプリ起動時のアニメーション
                .transition(.opacity)
                .animation(.easeIn(duration: 0.5), value: isInitialFocusSet)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
    }
} 
