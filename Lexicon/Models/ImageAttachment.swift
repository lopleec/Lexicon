import AppKit
import Foundation
import UniformTypeIdentifiers

struct ImageAttachment: Identifiable, Codable {
    let id: UUID
    let data: Data
    let mimeType: String
    let filename: String

    init(id: UUID = UUID(), data: Data, mimeType: String, filename: String) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.filename = filename
    }

    var preview: NSImage {
        NSImage(data: data) ?? NSImage(size: NSSize(width: 1, height: 1))
    }

    var dataURL: String {
        let base64 = data.base64EncodedString()
        return "data:\(mimeType);base64,\(base64)"
    }

    static func fromURL(_ url: URL) -> ImageAttachment? {
        guard let data = try? Data(contentsOf: url),
              NSImage(data: data) != nil else {
            return nil
        }

        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
        let name = url.lastPathComponent
        return ImageAttachment(data: data, mimeType: mimeType, filename: name)
    }
}
