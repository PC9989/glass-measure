import Foundation

struct JobAreaSummary: Equatable {
    var measured: Double = 0
    var manual: Double = 0
    var estimate: Double = 0
    var pending: Int = 0
    var sized: Int = 0
    var unavailable: Int = 0
    var measuredCount: Int = 0
    var manualCount: Int = 0
    var estimateCount: Int = 0

    var grand: Double { measured + manual + estimate }
    var hasAbsoluteArea: Bool { sized > 0 }

    init(panes: [GlassPane]) {
        for pane in panes {
            switch pane.sizing {
            case .pending:
                pending += 1
            case .unavailable:
                unavailable += 1
            case .sized(let sizedPane):
                sized += 1
                switch sizedPane.bucket {
                case .measured:
                    measured += sizedPane.areaM2
                    measuredCount += 1
                case .manual:
                    manual += sizedPane.areaM2
                    manualCount += 1
                case .estimate:
                    estimate += sizedPane.areaM2
                    estimateCount += 1
                }
            }
        }
    }
}

struct ReportDocument {
    var title: String
    var site: String
    var createdAt: Date
    var notes: String
    var identifier: String
    var panes: [ReportPane]
    var summary: JobAreaSummary
}

struct ReportPane: Identifiable {
    var id: UUID
    var index: Int
    var title: String
    var notes: String
    var kind: ReportPaneKind
    var imageJPEG: Data?
}

enum ReportPaneKind {
    case pending(ratio: String, precise: String)
    case sized(SizedPane)
    case unavailable(String)
}

enum ReportFiles {
    static func write(_ data: Data, name: String) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("報告", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}

enum ReportBuilder {
    static func make(job: MeasureJob) -> ReportDocument {
        let panes = job.orderedPanes.enumerated().map { offset, pane in
            ReportPane(
                id: pane.uuid,
                index: offset + 1,
                title: pane.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Copy.glassTitle(offset + 1)
                    : pane.title,
                notes: pane.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: kind(of: pane.sizing),
                imageJPEG: pane.annotatedJPEG ?? pane.originalJPEG
            )
        }
        let rawID = job.uuid.uuidString.replacingOccurrences(of: "-", with: "")
        return ReportDocument(
            title: "玻璃量度報告",
            site: job.displayName,
            createdAt: job.createdAt,
            notes: job.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            identifier: String(rawID.prefix(8)).uppercased(),
            panes: panes,
            summary: JobAreaSummary(panes: job.orderedPanes)
        )
    }

    static func plainText(_ report: ReportDocument) -> String {
        var lines: [String] = []
        lines.append("\(Copy.appName) 量度摘要")
        lines.append("日期：\(MeasureFormat.dateTime(report.createdAt))")
        lines.append("客戶／地盤：\(report.site)")
        if !report.notes.isEmpty {
            lines.append("備註：\(report.notes)")
        }
        lines.append("")
        if report.panes.isEmpty {
            lines.append("未有玻璃。")
        }
        for pane in report.panes {
            lines.append(contentsOf: lines(for: pane))
            lines.append("")
        }
        lines.append(contentsOf: totalLines(report.summary))
        lines.append("")
        lines.append("玻璃反光、斜拍及透視都會影響準確度。照片估算只供參考；未有實尺的玻璃沒有毫米及面積。")
        lines.append(Copy.localOnly)
        return lines.joined(separator: "\n")
    }

    static func shareSubject(_ report: ReportDocument) -> String {
        "\(Copy.appName) \(report.site)"
    }

    private static func kind(of sizing: PaneSizing) -> ReportPaneKind {
        switch sizing {
        case .pending(let ratio, let precise):
            return .pending(ratio: ratio, precise: precise)
        case .sized(let pane):
            return .sized(pane)
        case .unavailable(let message):
            return .unavailable(message)
        }
    }

    private static func lines(for pane: ReportPane) -> [String] {
        switch pane.kind {
        case .pending(let ratio, let precise):
            var lines = ["\(pane.title)（待實尺）：寬:高 = \(ratio)"]
            lines.append("精確比例 \(precise)。未輸入已知邊長，沒有毫米及面積。")
            if !pane.notes.isEmpty { lines.append("備註：\(pane.notes)") }
            return lines
        case .sized(let sized):
            var lines = ["\(pane.title)（\(sized.badge)）"]
            lines.append("寬度 \(MeasureFormat.mm(sized.widthMM))（\(sized.widthRole.caption)）")
            lines.append("高度 \(MeasureFormat.mm(sized.heightMM))（\(sized.heightRole.caption)）")
            lines.append("對角線 \(MeasureFormat.mm(sized.diagonalMM))（\(sized.diagonalRole.caption)）")
            lines.append("面積 \(MeasureFormat.area(sized.areaM2))（\(sized.areaRole.caption)）")
            lines.append(contentsOf: sized.notes)
            if !pane.notes.isEmpty { lines.append("備註：\(pane.notes)") }
            return lines
        case .unavailable(let message):
            return ["\(pane.title)：\(message)"]
        }
    }

    private static func totalLines(_ summary: JobAreaSummary) -> [String] {
        var lines: [String] = []
        if summary.hasAbsoluteArea {
            if summary.estimate > 0 {
                let concrete = summary.measured + summary.manual
                if concrete > 0 {
                    lines.append("實測及手動合計：\(MeasureFormat.area(concrete))")
                }
                lines.append("照片估算合計：\(MeasureFormat.area(summary.estimate))（只供參考）")
                lines.append("總計（含估算）：\(MeasureFormat.area(summary.grand))")
            } else {
                lines.append("總面積：\(MeasureFormat.area(summary.grand))")
            }
        } else {
            lines.append("未有可合計的面積。")
        }
        if summary.pending > 0 {
            lines.append("另有 \(summary.pending) 塊玻璃待實尺，未計入面積。")
        }
        return lines
    }
}
