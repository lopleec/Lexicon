import Foundation

enum ChatRole: String, Codable {
    case system
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    var content: String
    var images: [ImageAttachment]
    var isStreaming: Bool
    let createdAt: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, images: [ImageAttachment] = [], isStreaming: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.images = images
        self.isStreaming = isStreaming
        self.createdAt = createdAt
    }
}
