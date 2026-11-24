import PDFKit
import SwiftUI

struct PDFKitRepresentable: UIViewRepresentable {
    var data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.dataRepresentation() != data {
            uiView.document = PDFDocument(data: data)
        }
    }
}

struct PDFPreviewScreen: View {
    var jobUUID: UUID

    @Query(sort: \MeasureJob.updatedAt, order: .reverse) private var jobs: [MeasureJob]
    @State private var data: Data?
    @State private var fileURL: URL?
    @State private var failed = false
    @State private var working = true

    private var job: MeasureJob? { jobs.first { $0.uuid == jobUUID } }

    var body: some View {
        Group {
            if working {
                ProgressView(Copy.generating)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed || data == nil {
                ContentUnavailableView {
                    Label(Copy.pdfFailed, systemImage: "exclamationmark.triangle")
                } description: {
                    Text("請再試一次。資料仍在這部裝置上。")
                } actions: {
                    Button(Copy.retry) { generate() }
                        .buttonStyle(.borderedProminent)
                }
            } else if let data {
                VStack(spacing: 0) {
                    PDFKitRepresentable(data: data)
                    shareBar
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Copy.previewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: job?.updatedAt) {
            generate()
        }
    }

    @ViewBuilder
    private var shareBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fileURL, let job {
                let report = ReportBuilder.make(job: job)
                ShareLink(
                    item: fileURL,
                    subject: Text(ReportBuilder.shareSubject(report)),
                    message: Text(ReportBuilder.plainText(report))
                ) {
                    Label(Copy.sharePDF, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                ShareLink(item: ReportBuilder.plainText(report)) {
                    Label(Copy.shareText, systemImage: "text.alignleft")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Text(Copy.pdfSavedHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background)
    }

    private func generate() {
        guard let job else {
            failed = true
            working = false
            return
        }
        working = true
        failed = false
        let report = ReportBuilder.make(job: job)
        let pdf = ReportPDFRenderer.render(report)
        guard !pdf.isEmpty else {
            failed = true
            working = false
            return
        }
        do {
            let url = try ReportFiles.write(pdf, name: FileNames.report(customer: job.displayName, date: Date()))
            data = pdf
            fileURL = url
            working = false
        } catch {
            failed = true
            working = false
        }
    }
}
