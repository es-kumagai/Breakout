import Foundation

class DummySoundManager {
    var isSoundEnabled: Bool = true
    
    func playSound(name: String) {
        // 実際には何もしない
        print("サウンド再生（ダミー）: \(name)")
    }
    
    func toggleSound() {
        isSoundEnabled.toggle()
    }
    
    func stopAllSounds() {
        // 実際には何もしない
    }
} 