import Foundation

struct GameHint: Codable, Identifiable, Hashable {
    let caption: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case caption = "キャプション"
        case content = "内容"
    }

    var id: Int {
        hashValue
    }
    
    var isIllformed: Bool {
        caption.isEmpty || content.isEmpty
    }
} 