import Foundation
import AVFoundation

public class SoundManager {
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private(set) var isSoundEnabled = true
    
    init() {
        // プリロードするサウンド
        preloadSound(filename: "paddle_hit", type: "wav")
        preloadSound(filename: "block_break", type: "wav")
        preloadSound(filename: "game_over", type: "wav")
        preloadSound(filename: "level_up", type: "wav")
        preloadSound(filename: "ball_launch", type: "wav")
        preloadSound(filename: "combo", type: "wav")
        preloadSound(filename: "laser", type: "wav")
    }
    
    func preloadSound(filename: String, type: String) {
        if let path = Bundle.main.path(forResource: filename, ofType: type) {
            do {
                let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                player.prepareToPlay()
                audioPlayers[filename] = player
            } catch {
                print("🔊 サウンド読み込みエラー: \(filename).\(type) - \(error.localizedDescription)")
            }
        } else {
            print("🔊 サウンドファイルが見つかりません: \(filename).\(type)")
        }
    }
    
    func playSound(name: String) {
        guard isSoundEnabled else { return }
        
        if let player = audioPlayers[name] {
            if player.isPlaying {
                player.currentTime = 0
            }
            player.play()
        }
    }
    
    func toggleSound() {
        isSoundEnabled.toggle()
    }
    
    func stopAllSounds() {
        audioPlayers.values.forEach { $0.stop() }
    }
} 
