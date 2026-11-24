import UIKit

enum AnnotationDrawing {
    static func strokeQuad(_ corners: [CGPoint], in context: CGContext) {
        guard corners.count >= 2 else { return }
        let path = CGMutablePath()
        path.move(to: corners[0])
        for point in corners.dropFirst() {
            path.addLine(to: point)
        }
        if corners.count >= 3 {
            path.closeSubpath()
        }
        context.saveGState()
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.72).cgColor)
        context.setLineWidth(7)
        context.addPath(path)
        context.strokePath()
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()

        for point in corners {
            let rect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
            context.setFillColor(UIColor.black.cgColor)
            context.fillEllipse(in: rect.insetBy(dx: -2, dy: -2))
            context.setFillColor(UIColor(red: 1, green: 0.82, blue: 0.22, alpha: 1).cgColor)
            context.fillEllipse(in: rect)
        }
    }

    static func drawCard(lines: [String], badge: String?, around corners: [CGPoint], canvas: CGSize, in context: CGContext) {
        guard !lines.isEmpty else { return }
        let font = PDFFont.text(15, .semibold)
        let badgeFont = PDFFont.text(12, .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = lines.joined(separator: "\n")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        let maxTextWidth = min(canvas.width - 48, 280)
        let textBounds = (text as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: 400),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let badgeHeight: CGFloat = badge == nil ? 0 : 22
        let cardSize = CGSize(
            width: ceil(textBounds.width) + 28,
            height: ceil(textBounds.height) + 20 + badgeHeight
        )
        let centre = centroid(corners, canvas: canvas)
        var origin = CGPoint(x: centre.x - cardSize.width / 2, y: centre.y - cardSize.height / 2)
        origin.x = min(max(12, origin.x), max(12, canvas.width - cardSize.width - 12))
        origin.y = min(max(12, origin.y), max(12, canvas.height - cardSize.height - 12))
        let card = CGRect(origin: origin, size: cardSize)
        let path = UIBezierPath(roundedRect: card, cornerRadius: 12)
        context.saveGState()
        UIColor.black.withAlphaComponent(0.72).setFill()
        path.fill()
        context.restoreGState()

        var textY = card.minY + 10
        if let badge {
            let badgeText = badge as NSString
            let badgeSize = badgeText.size(withAttributes: [.font: badgeFont])
            let badgeRect = CGRect(
                x: card.midX - badgeSize.width / 2 - 8,
                y: textY,
                width: badgeSize.width + 16,
                height: 18
            )
            UIColor(red: 1, green: 0.82, blue: 0.22, alpha: 1).setFill()
            UIBezierPath(roundedRect: badgeRect, cornerRadius: 9).fill()
            badgeText.draw(
                in: badgeRect.offsetBy(dx: 0, dy: 1),
                withAttributes: [
                    .font: badgeFont,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph
                ]
            )
            textY += badgeHeight
        }
        (text as NSString).draw(
            in: CGRect(x: card.minX + 14, y: textY, width: card.width - 28, height: textBounds.height + 2),
            withAttributes: attributes
        )
    }

    private static func centroid(_ corners: [CGPoint], canvas: CGSize) -> CGPoint {
        guard !corners.isEmpty else {
            return CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        }
        let sum = corners.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(corners.count), y: sum.y / CGFloat(corners.count))
    }
}

enum AROverlayRenderer {
    static func render(
        image: UIImage,
        viewSize: CGSize,
        corners: [CGPoint],
        lines: [String],
        badge: String
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let sx = viewSize.width > 0 ? image.size.width / viewSize.width : 1
            let sy = viewSize.height > 0 ? image.size.height / viewSize.height : 1
            let mapped = corners.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }
            AnnotationDrawing.strokeQuad(mapped, in: context.cgContext)
            AnnotationDrawing.drawCard(lines: lines, badge: badge, around: mapped, canvas: image.size, in: context.cgContext)
        }
    }
}

/// What gets burned onto a photo. The pending case has no measurement strings.
enum PhotoBurn {
    case pending(ratio: String)
    case sized(lines: [String], badge: String)
}

extension PaneSizing {
    var photoBurn: PhotoBurn? {
        switch self {
        case .pending(let ratio, _):
            return .pending(ratio: ratio)
        case .sized(let pane):
            return .sized(
                lines: [
                    "寬 \(MeasureFormat.mm(pane.widthMM))",
                    "高 \(MeasureFormat.mm(pane.heightMM))",
                    "斜 \(MeasureFormat.mm(pane.diagonalMM))",
                    MeasureFormat.area(pane.areaM2)
                ],
                badge: pane.badge
            )
        case .unavailable:
            return nil
        }
    }
}

enum PhotoAnnotationRenderer {
    static func render(image: UIImage, normalized: [Vec2], burn: PhotoBurn) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let corners = normalized.map {
                CGPoint(x: $0.x * image.size.width, y: $0.y * image.size.height)
            }
            AnnotationDrawing.strokeQuad(corners, in: context.cgContext)
            switch burn {
            case .pending(let ratio):
                AnnotationDrawing.drawCard(
                    lines: ["待實尺", "寬:高 \(ratio)"],
                    badge: nil,
                    around: corners,
                    canvas: image.size,
                    in: context.cgContext
                )
            case .sized(let lines, let badge):
                AnnotationDrawing.drawCard(
                    lines: lines,
                    badge: badge,
                    around: corners,
                    canvas: image.size,
                    in: context.cgContext
                )
            }
        }
    }

    static func store(image: UIImage, normalized: [Vec2], burn: PhotoBurn) -> (annotated: Data?, thumb: Data?) {
        let rendered = render(image: image, normalized: normalized, burn: burn)
        return (ImageTools.jpeg(rendered, quality: 0.82), ImageTools.thumbnail(rendered))
    }
}
