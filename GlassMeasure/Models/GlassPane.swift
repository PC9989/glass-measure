import Foundation
import SwiftData

@Model
final class GlassPane {
    var uuid: UUID
    var createdAt: Date
    var title: String
    var notes: String
    var sourceRaw: String

    var rawWidthMM: Double?
    var rawHeightMM: Double?
    var rawDiagonalMM: Double?
    var rawAreaM2: Double?

    var proportionWidth: Double?
    var proportionHeight: Double?
    var proportionDiagonal: Double?
    var proportionArea: Double?

    var knownEdgeRaw: String?
    var knownEdgeMM: Double?

    var tapedWidthMM: Double?
    var tapedHeightMM: Double?

    var shapeModeRaw: String?
    var cornersJSON: String?

    @Attribute(.externalStorage) var originalJPEG: Data?
    @Attribute(.externalStorage) var annotatedJPEG: Data?
    @Attribute(.externalStorage) var thumbJPEG: Data?

    var job: MeasureJob?

    init(title: String, source: PaneSource) {
        self.uuid = UUID()
        self.createdAt = .now
        self.title = title
        self.notes = ""
        self.sourceRaw = source.rawValue
        self.rawWidthMM = nil
        self.rawHeightMM = nil
        self.rawDiagonalMM = nil
        self.rawAreaM2 = nil
        self.proportionWidth = nil
        self.proportionHeight = nil
        self.proportionDiagonal = nil
        self.proportionArea = nil
        self.knownEdgeRaw = nil
        self.knownEdgeMM = nil
        self.tapedWidthMM = nil
        self.tapedHeightMM = nil
        self.shapeModeRaw = nil
        self.cornersJSON = nil
        self.originalJPEG = nil
        self.annotatedJPEG = nil
        self.thumbJPEG = nil
        self.job = nil
    }

    var source: PaneSource {
        PaneSource(rawValue: sourceRaw) ?? .manual
    }

    var knownEdge: KnownEdge? {
        guard let knownEdgeRaw else { return nil }
        return KnownEdge(rawValue: knownEdgeRaw)
    }

    var shapeMode: PhotoShapeMode {
        PhotoShapeMode(rawValue: shapeModeRaw ?? "") ?? .quad
    }

    var input: PaneInput {
        PaneInput(
            source: source,
            rawWidthMM: rawWidthMM,
            rawHeightMM: rawHeightMM,
            rawDiagonalMM: rawDiagonalMM,
            rawAreaM2: rawAreaM2,
            proportionWidth: proportionWidth,
            proportionHeight: proportionHeight,
            proportionDiagonal: proportionDiagonal,
            proportionArea: proportionArea,
            knownEdge: knownEdge,
            knownEdgeMM: knownEdgeMM,
            tapedWidthMM: tapedWidthMM,
            tapedHeightMM: tapedHeightMM
        )
    }

    var sizing: PaneSizing {
        PaneSizingEngine.derive(input)
    }

    var proportion: PhotoProportion? {
        guard let proportionWidth, let proportionHeight, let proportionDiagonal, let proportionArea else { return nil }
        return PhotoProportion(
            widthPx: proportionWidth,
            heightPx: proportionHeight,
            diagonalPx: proportionDiagonal,
            areaPx: proportionArea
        )
    }
}
