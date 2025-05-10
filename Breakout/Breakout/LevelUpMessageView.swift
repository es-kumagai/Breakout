// レベルアップメッセージ表示ビュー
import SwiftUI

// レベルアップメッセージ表示ビュー
struct LevelUpMessageView: View {
	@EnvironmentObject private var gameState: GameState

	var body: some View {
		Group {
			if gameState.showLevelUpMessage {
				ZStack {
					// 背景の暗いオーバーレイ
					Color.black.opacity(0.7)
						.edgesIgnoringSafeArea(.all)

					// メッセージボックス
					VStack(spacing: 25) {
						// タイトル
						Text("レベルクリア！")
							.font(.system(size: 36, weight: .bold))
							.foregroundColor(.yellow)
							.shadow(color: .orange, radius: 2, x: 0, y: 0)

						// レベル情報
						VStack(spacing: 15) {
							Text("ボーナス: +100点")
								.font(.system(size: 24))
								.foregroundColor(.white)

							Text("レベル \(gameState.level) → \(gameState.nextLevel)")
								.font(.system(size: 28, weight: .bold))
								.foregroundColor(.white)
						}

						// カウントダウン表示
						if let timer = gameState.levelUpMessageTimer {
							Text("\(Int(timer) + 1)秒後に次のレベルへ")
								.font(.system(size: 20))
								.foregroundColor(.gray)
						}
					}
					.padding(40)
					.background(
						RoundedRectangle(cornerRadius: 20)
							.fill(Color.black.opacity(0.8))
							.overlay(
								RoundedRectangle(cornerRadius: 20)
									.stroke(Color.yellow, lineWidth: 3)
							)
					)
					.shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
				}
				.zIndex(100)  // 最前面に表示
			}
		}
	}
}
