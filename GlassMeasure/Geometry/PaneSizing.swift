import Foundation

enum PaneSource: String, Equatable {
    case ar
    case photo
    case manual
}

enum DimensionRole: Equatable {
    case measured
    case tape
    case scaled
    case known
    case estimated
    case manual

    var caption: String {
        switch self {
        case .measured: return "實測"
        case .tape: return "拉尺"
        case .scaled: return "按拉尺縮放"
        case .known: return "實尺"
        case .estimated: return "估算"
        case .manual: return "手動"
        }
    }
}

enum AreaBucket: Equatable {
    case measured
    case manual
    case estimate
}

struct SizedPane: Equatable {
    var widthMM: Double
    var heightMM: Double
    var diagonalMM: Double
    var areaM2: Double
    var widthRole: DimensionRole
    var heightRole: DimensionRole
    var diagonalRole: DimensionRole
    var areaRole: DimensionRole
    var badge: String
    var notes: [String]
    var bucket: AreaBucket
}

enum PaneSizing: Equatable {
    /// Photo mark with no real-world length. Ratio only — never millimetres or area.
    case pending(ratio: String, precise: String)
    case sized(SizedPane)
    case unavailable(String)
}

struct PaneInput: Equatable {
    var source: PaneSource
    var rawWidthMM: Double?
    var rawHeightMM: Double?
    var rawDiagonalMM: Double?
    var rawAreaM2: Double?
    var proportionWidth: Double?
    var proportionHeight: Double?
    var proportionDiagonal: Double?
    var proportionArea: Double?
    var knownEdge: KnownEdge?
    var knownEdgeMM: Double?
    var tapedWidthMM: Double?
    var tapedHeightMM: Double?
}

enum PaneSizingEngine {
    /// Photo input ignores any stored millimetres until one known edge exists.
    static func derive(_ input: PaneInput) -> PaneSizing {
        switch input.source {
        case .photo:
            return derivePhoto(input)
        case .ar:
            return deriveAR(input)
        case .manual:
            return deriveManual(input)
        }
    }

    private static func derivePhoto(_ input: PaneInput) -> PaneSizing {
        guard let width = input.proportionWidth,
              let height = input.proportionHeight,
              let diagonal = input.proportionDiagonal,
              let area = input.proportionArea,
              width > 0, height > 0, diagonal > 0, area > 0 else {
            return .unavailable("未能讀取照片比例。")
        }
        let aspect = PhotoProportionMath.aspect(width: width, height: height)
        guard let edge = input.knownEdge, let known = input.knownEdgeMM, known > 0 else {
            return .pending(ratio: aspect.label, precise: aspect.precise)
        }
        let proportion = PhotoProportion(widthPx: width, heightPx: height, diagonalPx: diagonal, areaPx: area)
        guard let scaled = PhotoProportionMath.scale(proportion: proportion, edge: edge, millimeters: known) else {
            return .unavailable("未能按照片比例換算。")
        }
        guard scaled.widthMM < 80_000, scaled.heightMM < 80_000, scaled.areaM2 < 2_000 else {
            return .unavailable("換算結果超出合理範圍，請檢查已知邊長。")
        }
        let knownText = MeasureFormat.mm(known)
        let note = "以實尺\(edge.title) \(knownText) 按照片比例估算其餘尺寸。透視或斜拍會令結果偏差，不能當作絕對尺寸。"
        return .sized(SizedPane(
            widthMM: scaled.widthMM,
            heightMM: scaled.heightMM,
            diagonalMM: scaled.diagonalMM,
            areaM2: scaled.areaM2,
            widthRole: edge == .width ? .known : .estimated,
            heightRole: edge == .height ? .known : .estimated,
            diagonalRole: .estimated,
            areaRole: .estimated,
            badge: "照片估算",
            notes: [note],
            bucket: .estimate
        ))
    }

    private static func deriveAR(_ input: PaneInput) -> PaneSizing {
        guard let raw = rawMeasure(from: input) else {
            return .unavailable("未能讀取實測尺寸。")
        }
        let corrected = applyTape(raw: raw, tapedWidth: input.tapedWidthMM, tapedHeight: input.tapedHeightMM)
        var notes: [String] = []
        if let note = corrected.note {
            notes.append(note)
            notes.append("校正前 \(MeasureFormat.pair(width: raw.widthMM, height: raw.heightMM))。")
        }
        let taped = corrected.taped
        return .sized(SizedPane(
            widthMM: corrected.measure.widthMM,
            heightMM: corrected.measure.heightMM,
            diagonalMM: corrected.measure.diagonalMM,
            areaM2: corrected.measure.areaM2,
            widthRole: taped.width ? .tape : (taped.any ? .scaled : .measured),
            heightRole: taped.height ? .tape : (taped.any ? .scaled : .measured),
            diagonalRole: taped.any ? .scaled : .measured,
            areaRole: taped.any ? .scaled : .measured,
            badge: taped.any ? "已拉尺校正" : "實測",
            notes: notes,
            bucket: .measured
        ))
    }

    private static func deriveManual(_ input: PaneInput) -> PaneSizing {
        guard let raw = rawMeasure(from: input) else {
            return .unavailable("未能讀取手動尺寸。")
        }
        return .sized(SizedPane(
            widthMM: raw.widthMM,
            heightMM: raw.heightMM,
            diagonalMM: raw.diagonalMM,
            areaM2: raw.areaM2,
            widthRole: .manual,
            heightRole: .manual,
            diagonalRole: .manual,
            areaRole: .manual,
            badge: "手動輸入",
            notes: ["寬度及高度由人手輸入，對角線及面積按這兩個數計算。"],
            bucket: .manual
        ))
    }

    private static func rawMeasure(from input: PaneInput) -> RawMeasure? {
        guard let width = input.rawWidthMM,
              let height = input.rawHeightMM,
              let diagonal = input.rawDiagonalMM,
              let area = input.rawAreaM2,
              width > 0, height > 0, diagonal > 0, area > 0,
              width.isFinite, height.isFinite, diagonal.isFinite, area.isFinite else {
            return nil
        }
        return RawMeasure(widthMM: width, heightMM: height, diagonalMM: diagonal, areaM2: area)
    }

    private struct TapeFlags {
        var width = false
        var height = false
        var any: Bool { width || height }
    }

    private static func applyTape(
        raw: RawMeasure,
        tapedWidth: Double?,
        tapedHeight: Double?
    ) -> (measure: RawMeasure, note: String?, taped: TapeFlags) {
        switch (tapedWidth, tapedHeight) {
        case let (width?, nil) where width > 0 && raw.widthMM > 0:
            let scale = width / raw.widthMM
            return (
                RawMeasure(
                    widthMM: width,
                    heightMM: raw.heightMM * scale,
                    diagonalMM: raw.diagonalMM * scale,
                    areaM2: raw.areaM2 * scale * scale
                ),
                "已拉尺校正：以寬度 \(MeasureFormat.mm(width)) 等比縮放。",
                TapeFlags(width: true)
            )
        case let (nil, height?) where height > 0 && raw.heightMM > 0:
            let scale = height / raw.heightMM
            return (
                RawMeasure(
                    widthMM: raw.widthMM * scale,
                    heightMM: height,
                    diagonalMM: raw.diagonalMM * scale,
                    areaM2: raw.areaM2 * scale * scale
                ),
                "已拉尺校正：以高度 \(MeasureFormat.mm(height)) 等比縮放。",
                TapeFlags(height: true)
            )
        case let (width?, height?) where width > 0 && height > 0 && raw.widthMM > 0 && raw.heightMM > 0:
            let scaleW = width / raw.widthMM
            let scaleH = height / raw.heightMM
            return (
                RawMeasure(
                    widthMM: width,
                    heightMM: height,
                    diagonalMM: hypot(width, height),
                    areaM2: raw.areaM2 * scaleW * scaleH
                ),
                "已拉尺校正：寬度及高度都改為拉尺讀數。",
                TapeFlags(width: true, height: true)
            )
        default:
            return (raw, nil, TapeFlags())
        }
    }
}
