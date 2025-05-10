// ゲームオーバー表示ビュー
import SwiftUI

struct GameOverView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showContent = false
    
    var body: some View {
        if gameState.isGameOver {
            ZStack {
                // より不透明な背景
                Color.black.opacity(0.9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle()) // タップ領域を明示的に設定
                    .onTapGesture {
                        print("ゲームオーバー画面をタップ: リスタート実行")
                        gameState.restartGame()
                    }
                
                VStack {
                    Spacer()
                    
                    // ゲームオーバーテキストを目立たせる
                    Text("ゲームオーバー")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.7), radius: 10, x: 0, y: 0)
                        .padding(.bottom, 20)
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6), value: showContent)
                    
                    Text("最終スコア: \(gameState.score)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 25)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.easeInOut.delay(0.3), value: showContent)
                    
                    // 攻略ヒントを表示
                    if let hint = gameState.currentHint {
                        GameHintView(hint: hint)
                            .padding(.top, 15)
                            .padding(.horizontal, 25)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.black.opacity(0.7))
                                    .shadow(color: .white.opacity(0.2), radius: 5)
                            )
                            .padding(.vertical, 10)
                            .opacity(showContent ? 1.0 : 0.0)
                            .animation(.easeInOut.delay(0.6), value: showContent)
                    }
                    
                    Text("画面をクリックしてリスタート")
                        .foregroundColor(.yellow)
                        .font(.system(size: 18))
                        .padding(.top, 30)
                        .padding(.bottom, 10)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.easeInOut.delay(0.8), value: showContent)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                // VStackでのタップジェスチャーを追加（より確実なリスタート用）
                .contentShape(Rectangle())
                .onTapGesture {
                    print("ゲームオーバーVStackをタップ: リスタート実行")
                    gameState.restartGame()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // 表示時にアニメーションを開始
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showContent = true
                }
            }
            .onDisappear {
                // 非表示時にアニメーション状態をリセット
                self.showContent = false
            }
        }
    }
} 