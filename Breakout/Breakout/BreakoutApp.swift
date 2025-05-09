import SwiftUI

@main
struct BreakoutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .frame(maxWidth: 800, maxHeight: 600)
        }
        .windowResizability(.contentSize)
    }
} 