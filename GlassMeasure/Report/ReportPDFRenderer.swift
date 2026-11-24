import UIKit

enum PDFFont {
    static func text(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black:
            name = "PingFangTC-Semibold"
        case .medium:
            name = "PingFangTC-Medium"
        default:
            name = "PingFangTC-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

enum ReportPDFRenderer {
    static func render(_ report: ReportDocument) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: report.title,
            kCGPDFContextCreator as String: Copy.appName,
            kCGPDFContextAuthor as String: report.site
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        return renderer.pdfData { context in
            let pen = PDFPen(context: context, page: page)
            pen.begin(report: report, continued: false)
            pen.drawMeta(report)
            pen.drawTable(report)
            pen.drawTotals(report.summary)
            pen.drawPhotos(report)
            pen.drawDisclaimer()
        }
    }
}

private final class PDFPen {
    let context: UIGraphicsPDFRendererContext
    let page: CGRect
    let margin: CGFloat = 36
    var y: CGFloat = 36
    var pageNumber = 0
    var reportTitle = ""

    var width: CGFloat { page.width - margin * 2 }
    var bottomLimit: CGFloat { page.height - 46 }

    init(context: UIGraphicsPDFRendererContext, page: CGRect) {
        self.context = context
        self.page = page
    }

    func begin(report: ReportDocument, continued: Bool) {
        context.beginPage()
        pageNumber += 1
        reportTitle = report.title
        if continued || pageNumber > 1 {
            drawCompactHeader()
        } else {
            drawCoverHeader(report)
        }
        drawFooter()
    }

    func ensure(_ height: CGFloat, report: ReportDocument) {
        if y + height > bottomLimit {
            begin(report: report, continued: true)
        }
    }

    func drawMeta(_ report: ReportDocument) {
        let left = [
            "報告編號　\(report.identifier)",
            "量度日期　\(MeasureFormat.dateTime(report.createdAt))"
        ].joined(separator: "\n")
        let right = "客戶／地盤　\(report.site)"
        let block = max(
            textHeight(left, width: width * 0.46, font: PDFFont.text(11)),
            textHeight(right, width: width * 0.5, font: PDFFont.text(11, .medium))
        )
        _ = draw(left, x: margin, y: y, width: width * 0.46, font: PDFFont.text(11), color: Theme.pdfMuted)
        _ = draw(right, x: margin + width * 0.5, y: y, width: width * 0.5, font: PDFFont.text(12, .medium), color: Theme.pdfInk)
        y += block + 8
        if !report.notes.isEmpty {
            y += draw("備註　\(report.notes)", x: margin, y: y, width: width, font: PDFFont.text(11), color: Theme.pdfInk) + 8
        }
        let summary = countLine(report.summary)
        y += draw(summary, x: margin, y: y, width: width, font: PDFFont.text(11), color: Theme.pdfMuted) + 12
    }

    func drawTable(_ report: ReportDocument) {
        ensure(48, report: report)
        y += draw("玻璃明細", x: margin, y: y, width: width, font: PDFFont.text(14, .semibold), color: Theme.pdfInk) + 8
        drawTableHeader()
        if report.panes.isEmpty {
            y += draw("未有玻璃。", x: margin, y: y + 6, width: width, font: PDFFont.text(12), color: Theme.pdfMuted) + 12
            return
        }
        for (index, pane) in report.panes.enumerated() {
            let rowHeight = height(for: pane)
            let needsHeader = y + rowHeight + 4 > bottomLimit
            ensure(rowHeight + 4, report: report)
            if needsHeader {
                drawTableHeader()
            }
            drawRow(pane, height: rowHeight, shaded: index.isMultiple(of: 2))
        }
        y += 12
    }

    func drawTotals(_ summary: JobAreaSummary) {
        let lines = totalLines(summary)
        let height = lines.reduce(18) { partial, line in
            partial + textHeight(line, width: width - 24, font: PDFFont.text(12)) + 4
        } + 16
        // Totals box cannot know the report; page break uses a dummy continuation via ensure by height only.
        if y + height > bottomLimit {
            context.beginPage()
            pageNumber += 1
            drawCompactHeader()
            drawFooter()
        }
        let rect = CGRect(x: margin, y: y, width: width, height: height)
        Theme.pdfRow.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
        var cursor = y + 10
        for (index, line) in lines.enumerated() {
            let font = index == 0 ? PDFFont.text(13, .semibold) : PDFFont.text(11)
            let color = index == 0 ? Theme.pdfInk : Theme.pdfMuted
            cursor += draw(line, x: margin + 12, y: cursor, width: width - 24, font: font, color: color) + 3
        }
        y += height + 16
    }

    func drawPhotos(_ report: ReportDocument) {
        let illustrated = report.panes.filter { $0.imageJPEG != nil }
        guard !illustrated.isEmpty else { return }
        if y + 36 > bottomLimit {
            begin(report: report, continued: true)
        }
        y += draw("量度相片", x: margin, y: y, width: width, font: PDFFont.text(14, .semibold), color: Theme.pdfInk) + 8
        for pane in illustrated {
            let caption = photoCaption(pane)
            let captionHeight = textHeight(caption, width: width, font: PDFFont.text(10))
            let block = 24 + 210 + 8 + captionHeight + 14
            ensure(block, report: report)
            y += draw(pane.title, x: margin, y: y, width: width, font: PDFFont.text(12, .semibold), color: Theme.pdfInk) + 6
            if let data = pane.imageJPEG, let image = UIImage(data: data) {
                let frame = aspectFit(image.size, max: CGSize(width: width, height: 210))
                let origin = CGPoint(x: margin + (width - frame.width) / 2, y: y)
                let box = CGRect(origin: origin, size: frame)
                UIColor.white.setFill()
                context.cgContext.fill(box.insetBy(dx: -2, dy: -2))
                Theme.pdfRule.setStroke()
                context.cgContext.stroke(box)
                image.draw(in: box)
                y += frame.height + 6
            }
            y += draw(caption, x: margin, y: y, width: width, font: PDFFont.text(10), color: Theme.pdfMuted) + 14
        }
    }

    func drawDisclaimer() {
        let text = "聲明：玻璃、鏡面及反光表面或令擴增實境量度出現偏差，建議以拉尺覆核最少一邊。照片估算只按一條已知邊及相片比例推算，正面拍攝以外的透視會令結果偏差，不能視為絕對尺寸。未輸入已知邊長的玻璃只記錄寬高比，報告不會為其填寫毫米或面積。本報告由玻璃度尺在裝置本機產生，相片及尺寸不會上載。"
        let height = textHeight(text, width: width, font: PDFFont.text(9)) + 8
        if y + height > bottomLimit {
            context.beginPage()
            pageNumber += 1
            drawCompactHeader()
            drawFooter()
        }
        _ = draw(text, x: margin, y: y, width: width, font: PDFFont.text(9), color: Theme.pdfMuted)
    }

    private func drawCoverHeader(_ report: ReportDocument) {
        Theme.pdfTeal.setFill()
        context.cgContext.fill(CGRect(x: 0, y: 0, width: page.width, height: 86))
        _ = draw(Copy.appName, x: margin, y: 22, width: width * 0.6, font: PDFFont.text(26, .semibold), color: .white)
        _ = draw(Copy.subtitle, x: margin, y: 54, width: width * 0.45, font: PDFFont.text(12), color: UIColor.white.withAlphaComponent(0.85))
        _ = draw(report.title, x: margin + width * 0.45, y: 34, width: width * 0.55, font: PDFFont.text(16, .medium), color: .white, alignment: .right)
        y = 104
    }

    private func drawCompactHeader() {
        Theme.pdfTeal.setFill()
        context.cgContext.fill(CGRect(x: 0, y: 0, width: page.width, height: 36))
        _ = draw("\(Copy.appName)　\(reportTitle)", x: margin, y: 10, width: width, font: PDFFont.text(12, .medium), color: .white)
        y = 52
    }

    private func drawFooter() {
        let footerY = page.height - 28
        _ = draw("\(Copy.appName) · 只供報價參考 · 本機產生", x: margin, y: footerY, width: width * 0.7, font: PDFFont.text(8), color: Theme.pdfMuted)
        _ = draw("第 \(pageNumber) 頁", x: margin, y: footerY, width: width, font: PDFFont.text(8), color: Theme.pdfMuted, alignment: .right)
    }

    private func drawTableHeader() {
        let headers = ["#", "名稱", "寬度", "高度", "面積", "備註"]
        let font = PDFFont.text(9, .medium)
        Theme.pdfInk.setFill()
        context.cgContext.fill(CGRect(x: margin, y: y, width: width, height: 22))
        var x = margin
        for (title, column) in zip(headers, columns) {
            _ = draw(title, x: x + 4, y: y + 5, width: column - 8, font: font, color: .white)
            x += column
        }
        y += 22
    }

    private var columns: [CGFloat] {
        let fixed: CGFloat = 28 + 86 + 86 + 78 + 108
        let name = max(80, width - fixed)
        return [28, name, 86, 86, 78, 108]
    }

    private func height(for pane: ReportPane) -> CGFloat {
        let nameHeight = textHeight(pane.title, width: columns[1] - 8, font: PDFFont.text(10, .medium))
        let noteHeight = textHeight(note(for: pane), width: columns[5] - 8, font: PDFFont.text(8))
        return max(32, max(nameHeight, noteHeight) + 14)
    }

    private func drawRow(_ pane: ReportPane, height: CGFloat, shaded: Bool) {
        let rect = CGRect(x: margin, y: y, width: width, height: height)
        (shaded ? Theme.pdfRow : UIColor.white).setFill()
        context.cgContext.fill(rect)
        let cells = cells(for: pane)
        var x = margin
        for (index, column) in columns.enumerated() {
            let font = index == 0 || index >= 2 ? PDFFont.text(9) : PDFFont.text(10, .medium)
            let color = cellColor(pane: pane, column: index)
            _ = draw(cells[index], x: x + 4, y: y + 7, width: column - 8, font: font, color: color)
            x += column
        }
        y += height
    }

    /// Pending rows never receive formatted millimetres.
    private func cells(for pane: ReportPane) -> [String] {
        switch pane.kind {
        case .pending(let ratio, _):
            return ["\(pane.index)", pane.title, "待實尺", "待實尺", "—", "寬:高 \(ratio)"]
        case .sized(let sized):
            return [
                "\(pane.index)",
                pane.title,
                MeasureFormat.mm(sized.widthMM),
                MeasureFormat.mm(sized.heightMM),
                MeasureFormat.area(sized.areaM2),
                sized.badge
            ]
        case .unavailable:
            return ["\(pane.index)", pane.title, "—", "—", "—", "未能讀取"]
        }
    }

    private func cellColor(pane: ReportPane, column: Int) -> UIColor {
        switch pane.kind {
        case .pending where column >= 2:
            return Theme.pdfAmber
        case .sized(let sized) where sized.bucket == .estimate && column >= 2:
            return Theme.pdfAmber
        default:
            return Theme.pdfInk
        }
    }

    private func note(for pane: ReportPane) -> String {
        switch pane.kind {
        case .pending(let ratio, _):
            return "寬:高 \(ratio)"
        case .sized(let sized):
            return sized.badge
        case .unavailable:
            return "未能讀取"
        }
    }

    private func photoCaption(_ pane: ReportPane) -> String {
        switch pane.kind {
        case .pending(let ratio, let precise):
            return "待實尺 · 寬:高 \(ratio) · 精確 \(precise) · 未計算毫米及面積"
        case .sized(let sized):
            return "寬度 \(MeasureFormat.mm(sized.widthMM))（\(sized.widthRole.caption)） · 高度 \(MeasureFormat.mm(sized.heightMM))（\(sized.heightRole.caption)） · 對角線 \(MeasureFormat.mm(sized.diagonalMM))（\(sized.diagonalRole.caption)） · 面積 \(MeasureFormat.area(sized.areaM2))（\(sized.areaRole.caption)）"
        case .unavailable(let message):
            return message
        }
    }

    private func countLine(_ summary: JobAreaSummary) -> String {
        "共 \(summary.sized + summary.pending + summary.unavailable) 塊 · 實測 \(summary.measuredCount) · 手動 \(summary.manualCount) · 照片估算 \(summary.estimateCount) · 待實尺 \(summary.pending)"
    }

    private func totalLines(_ summary: JobAreaSummary) -> [String] {
        var lines: [String] = []
        if summary.hasAbsoluteArea {
            if summary.estimate > 0 {
                lines.append("總計（含照片估算）　\(MeasureFormat.area(summary.grand))")
                let concrete = summary.measured + summary.manual
                if concrete > 0 {
                    lines.append("實測及手動　\(MeasureFormat.area(concrete))")
                }
                lines.append("照片估算　\(MeasureFormat.area(summary.estimate))　只供參考，已計入總計並於明細標示。")
            } else {
                lines.append("總面積　\(MeasureFormat.area(summary.grand))")
            }
        } else {
            lines.append("未有可合計的面積")
        }
        if summary.pending > 0 {
            lines.append("另有 \(summary.pending) 塊玻璃待實尺，未計入面積，亦沒有毫米數字。")
        }
        return lines
    }

    @discardableResult
    private func draw(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let height = textHeight(text, width: width, font: font, alignment: alignment)
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: height), withAttributes: attributes)
        return height
    }

    private func textHeight(_ text: String, width: CGFloat, font: UIFont, alignment: NSTextAlignment = .left) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: 4000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style],
            context: nil
        )
        return max(ceil(bounds.height), font.lineHeight)
    }

    private func aspectFit(_ size: CGSize, max: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return max }
        let scale = min(max.width / size.width, max.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
