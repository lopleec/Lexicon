import Foundation

struct ModelPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var model: String
    var apiType: APIType
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        model: String,
        apiType: APIType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.apiType = apiType
        self.createdAt = createdAt
    }
}
