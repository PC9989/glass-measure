import Foundation

/// A point in image space. Y grows downward, matching UIImage.
struct Vec2: Equatable {
    var x: Double
    var y: Double
}

enum PhotoShapeMode: String, Equatable {
    case rectangle
    case quad
}

/// Pixel proportions of a marked pane. These are not millimetres.
struct PhotoProportion: Equatable {
    var widthPx: Double
    var heightPx: Double
    var diagonalPx: Double
    var areaPx: Double
}

struct ScaledPhoto: Equatable {
    var widthMM: Double
    var heightMM: Double
    var diagonalMM: Double
    var areaM2: Double
}

enum KnownEdge: String, Equatable, CaseIterable, Identifiable {
    case width
    case height

    var id: String { rawValue }

    var title: String {
        switch self {
        case .width: return "寬度"
        case .height: return "高度"
        }
    }
}

enum PhotoProportionMath {
    /// Measures a marked shape. Returns nil when the mark is too small to be a pane.
    static func measure(pixelWidth: Double, pixelHeight: Double, normalized: [Vec2], mode: PhotoShapeMode) -> PhotoProportion? {
        guard pixelWidth > 1, pixelHeight > 1, normalized.count == 4 else { return nil }
        let pixels = normalized.map {
            Vec2(x: $0.x * pixelWidth, y: $0.y * pixelHeight)
        }
        let proportion: PhotoProportion?
        switch mode {
        case .rectangle:
            proportion = measureRectangle(pixels)
        case .quad:
            proportion = measureQuad(pixels)
        }
        guard let proportion else { return nil }
        guard proportion.widthPx >= 2, proportion.heightPx >= 2, proportion.areaPx >= 4 else { return nil }
        guard proportion.widthPx.isFinite, proportion.heightPx.isFinite, proportion.areaPx.isFinite else { return nil }
        return proportion
    }

    /// Width:height label. `label` is a short ratio such as "4:3". `precise` is width ÷ height.
    static func aspect(width: Double, height: Double) -> (label: String, precise: String) {
        guard width > 0, height > 0, width.isFinite, height.isFinite else {
            return ("—", "—")
        }
        let target = width / height
        let precise = String(format: "%.3f : 1", target)
        if let fraction = bestFraction(target: target) {
            return (fraction, precise)
        }
        if width >= height {
            return (String(format: "%.2f:1", target), precise)
        }
        return (String(format: "1:%.2f", height / width), precise)
    }

    /// Scales every linear dimension from one known edge. Area scales by the square.
    /// The known edge is written back exactly so it cannot drift.
    static func scale(proportion: PhotoProportion, edge: KnownEdge, millimeters: Double) -> ScaledPhoto? {
        guard millimeters > 0, millimeters.isFinite else { return nil }
        switch edge {
        case .width:
            guard proportion.widthPx > 0 else { return nil }
            let millimetresPerPixel = millimeters / proportion.widthPx
            return finish(
                widthMM: millimeters,
                heightMM: proportion.heightPx * millimetresPerPixel,
                diagonalMM: proportion.diagonalPx * millimetresPerPixel,
                areaPx: proportion.areaPx,
                millimetresPerPixel: millimetresPerPixel
            )
        case .height:
            guard proportion.heightPx > 0 else { return nil }
            let millimetresPerPixel = millimeters / proportion.heightPx
            return finish(
                widthMM: proportion.widthPx * millimetresPerPixel,
                heightMM: millimeters,
                diagonalMM: proportion.diagonalPx * millimetresPerPixel,
                areaPx: proportion.areaPx,
                millimetresPerPixel: millimetresPerPixel
            )
        }
    }

    static func orderClockwise(_ points: [Vec2]) -> [Vec2] {
        guard points.count == 4 else { return points }
        let cx = points.reduce(0) { $0 + $1.x } / 4
        let cy = points.reduce(0) { $0 + $1.y } / 4
        return points.sorted { a, b in
            atan2(a.y - cy, a.x - cx) < atan2(b.y - cy, b.x - cx)
        }
    }

    static func rectangleCorners(a: Vec2, b: Vec2) -> [Vec2] {
        let minX = min(a.x, b.x)
        let maxX = max(a.x, b.x)
        let minY = min(a.y, b.y)
        let maxY = max(a.y, b.y)
        return [
            Vec2(x: minX, y: minY),
            Vec2(x: maxX, y: minY),
            Vec2(x: maxX, y: maxY),
            Vec2(x: minX, y: maxY)
        ]
    }

    private static func finish(
        widthMM: Double,
        heightMM: Double,
        diagonalMM: Double,
        areaPx: Double,
        millimetresPerPixel: Double
    ) -> ScaledPhoto? {
        let areaM2 = areaPx * millimetresPerPixel * millimetresPerPixel / 1_000_000
        let result = ScaledPhoto(widthMM: widthMM, heightMM: heightMM, diagonalMM: diagonalMM, areaM2: areaM2)
        guard result.widthMM.isFinite, result.heightMM.isFinite, result.diagonalMM.isFinite, result.areaM2.isFinite else {
            return nil
        }
        guard result.widthMM > 0, result.heightMM > 0, result.areaM2 > 0 else { return nil }
        return result
    }

    private static func measureRectangle(_ pixels: [Vec2]) -> PhotoProportion? {
        let xs = pixels.map(\.x)
        let ys = pixels.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        let width = maxX - minX
        let height = maxY - minY
        return PhotoProportion(
            widthPx: width,
            heightPx: height,
            diagonalPx: hypot(width, height),
            areaPx: width * height
        )
    }

    private static func measureQuad(_ pixels: [Vec2]) -> PhotoProportion? {
        let ordered = orderClockwise(pixels)
        let edges = (0..<4).map { index -> (length: Double, horizontal: Double) in
            let a = ordered[index]
            let b = ordered[(index + 1) % 4]
            let dx = abs(b.x - a.x)
            let dy = abs(b.y - a.y)
            let length = hypot(dx, dy)
            let horizontal = dx / max(dx + dy, 0.001)
            return (length, horizontal)
        }
        let pairALength = (edges[0].length + edges[2].length) / 2
        let pairBLength = (edges[1].length + edges[3].length) / 2
        let pairAHorizontal = (edges[0].horizontal + edges[2].horizontal) / 2
        let pairBHorizontal = (edges[1].horizontal + edges[3].horizontal) / 2

        let width: Double
        let height: Double
        if abs(pairAHorizontal - pairBHorizontal) < 0.12 {
            let xs = ordered.map(\.x)
            let ys = ordered.map(\.y)
            width = (xs.max() ?? 0) - (xs.min() ?? 0)
            height = (ys.max() ?? 0) - (ys.min() ?? 0)
        } else if pairAHorizontal >= pairBHorizontal {
            width = pairALength
            height = pairBLength
        } else {
            width = pairBLength
            height = pairALength
        }

        let diagonal = max(distance(ordered[0], ordered[2]), distance(ordered[1], ordered[3]))
        return PhotoProportion(
            widthPx: width,
            heightPx: height,
            diagonalPx: diagonal,
            areaPx: shoelace(ordered)
        )
    }

    private static func shoelace(_ points: [Vec2]) -> Double {
        var sum = 0.0
        for index in 0..<points.count {
            let next = points[(index + 1) % points.count]
            let current = points[index]
            sum += current.x * next.y - next.x * current.y
        }
        return abs(sum) * 0.5
    }

    private static func distance(_ a: Vec2, _ b: Vec2) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Small-integer approximation of width ÷ height. Prefers the smallest tidy ratio within 1.2%.
    private static func bestFraction(target: Double) -> String? {
        for den in 1...24 {
            let num = Int((target * Double(den)).rounded())
            guard num >= 1, num <= 48 else { continue }
            let error = abs(Double(num) / Double(den) - target) / target
            if error <= 0.012 {
                let divisor = gcd(num, den)
                return "\(num / divisor):\(den / divisor)"
            }
        }
        return nil
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = abs(a)
        var b = abs(b)
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return max(a, 1)
    }
}
