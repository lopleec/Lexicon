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

    static func fromPasteboard(_ pasteboard: NSPasteboard) -> [ImageAttachment] {
        var results: [ImageAttachment] = []

        if let items = pasteboard.pasteboardItems {
            for item in items {
                if let attachment = attachmentFromPasteboardItem(item) {
                    results.append(attachment)
                }
            }
        }

        if !results.isEmpty {
            return results
        }

        if let data = imageDataFromPasteboard(pasteboard),
           let image = NSImage(data: data),
           let pngData = image.pngData() {
            results.append(ImageAttachment(data: pngData, mimeType: "image/png", filename: "clipboard.png"))
            return results
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           !images.isEmpty {
            results.append(contentsOf: images.compactMap { image in
                guard let data = image.pngData() else { return nil }
                return ImageAttachment(data: data, mimeType: "image/png", filename: "clipboard.png")
            })
        }

        if results.isEmpty,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            results.append(contentsOf: urls.compactMap { url -> ImageAttachment? in
                guard url.isFileURL else { return nil }
                return ImageAttachment.fromURL(url)
            })
        }

        if results.isEmpty, let image = NSImage(pasteboard: pasteboard),
           let data = image.pngData() {
            results.append(ImageAttachment(data: data, mimeType: "image/png", filename: "clipboard.png"))
        }

        return results
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

private func attachmentFromPasteboardItem(_ item: NSPasteboardItem) -> ImageAttachment? {
    if let fileURL = pasteboardItemFileURL(item) {
        return ImageAttachment.fromURL(fileURL)
    }

    if let imageData = pasteboardItemImageData(item),
       let image = NSImage(data: imageData),
       let pngData = image.pngData() {
        return ImageAttachment(data: pngData, mimeType: "image/png", filename: "clipboard.png")
    }

    return nil
}

private func pasteboardItemFileURL(_ item: NSPasteboardItem) -> URL? {
    if let urlString = item.string(forType: .fileURL),
       let url = URL(string: urlString),
       url.isFileURL {
        return url
    }

    if let urlString = item.string(forType: .URL),
       let url = URL(string: urlString),
       url.isFileURL {
        return url
    }

    return nil
}

private func pasteboardItemImageData(_ item: NSPasteboardItem) -> Data? {
    for type in item.types {
        if let utType = UTType(type.rawValue), utType.conforms(to: .image),
           let data = item.data(forType: type) {
            return data
        }
    }
    return nil
}

private func imageDataFromPasteboard(_ pasteboard: NSPasteboard) -> Data? {
    guard let types = pasteboard.types else { return nil }
    for type in types {
        if let utType = UTType(type.rawValue), utType.conforms(to: .image),
           let data = pasteboard.data(forType: type) {
            return data
        }
    }
    return nil
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
