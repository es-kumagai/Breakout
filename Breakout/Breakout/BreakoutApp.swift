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
                .frame(minWidth: 800, minHeight: 600)
                .frame(maxWidth: 800, maxHeight: 600)
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