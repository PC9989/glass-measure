import UIKit

enum CornerCodec {
    struct Point: Codable {
        var x: Double
        var y: Double
    }

    static func encode(_ points: [Vec2]) -> String? {
        let payload = points.map { Point(x: $0.x, y: $0.y) }
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [Vec2] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        guard let payload = try? JSONDecoder().decode([Point].self, from: data) else { return [] }
        return payload.map { Vec2(x: $0.x, y: $0.y) }
    }
}

enum ImageTools {
    static func upright(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func limited(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxPixel, longest > 0 else { return image }
        let ratio = maxPixel / longest
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    static func prepared(_ image: UIImage, maxPixel: CGFloat = 2200) -> UIImage {
        limited(upright(image), maxPixel: maxPixel)
    }

    static func jpeg(_ image: UIImage, quality: CGFloat) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    static func thumbnail(_ image: UIImage, maxPixel: CGFloat = 360) -> Data? {
        jpeg(limited(image, maxPixel: maxPixel), quality: 0.72)
    }

    static func pixelSize(of image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }
}

enum FileNames {
    static func report(customer: String, date: Date) -> String {
        let trimmed = customer.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = sanitize(trimmed.isEmpty ? Copy.unnamedSite : trimmed)
        return "玻璃度尺_\(who)_\(MeasureFormat.fileStamp(date)).pdf"
    }

    static func sanitize(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r")
        let cleaned = name.components(separatedBy: forbidden).joined(separator: " ")
        let collapsed = cleaned.replacingOccurrences(of: "  ", with: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "工作" }
        return String(trimmed.prefix(40))
    }
}
