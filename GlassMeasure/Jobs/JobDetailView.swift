import SwiftUI

private enum FieldCover: String, Identifiable {
    case ar
    case photo
    var id: String { rawValue }
}

struct JobDetailView: View {
    @Bindable var job: MeasureJob
    @Environment(\.modelContext) private var context

    @State private var cover: FieldCover?
    @State private var showManual = false
    @State private var showPDF = false
    @State private var showEditor = false
    @State private var switchTarget: ComposerRoute?
    @State private var saveError: String?

    private var summary: JobAreaSummary { JobAreaSummary(panes: job.orderedPanes) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCard
                if job.orderedPanes.isEmpty {
                    ContentUnavailableView(
                        Copy.emptyPanesTitle,
                        systemImage: "rectangle.dashed",
                        description: Text(Copy.emptyPanesMessage)
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.vertical, 12)
                } else {
                    paneList
                }
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(job.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addMenu
            }
            ToolbarItem(placement: .automatic) {
                Button("編輯") { showEditor = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            pdfBar
        }
        .navigationDestination(for: UUID.self) { uuid in
            if let pane = job.orderedPanes.first(where: { $0.uuid == uuid }) {
                PaneDetailView(pane: pane)
            } else {
                ContentUnavailableView("找不到這塊玻璃", systemImage: "rectangle.dashed")
            }
        }
        .navigationDestination(isPresented: $showPDF) {
            PDFPreviewScreen(jobUUID: job.uuid)
        }
        .fullScreenCover(item: $cover, onDismiss: performSwitch) { item in
            switch item {
            case .ar:
                MeasureScreen(jobUUID: job.uuid, onSwitch: requestSwitch)
            case .photo:
                PhotoMeasureScreen(jobUUID: job.uuid, onSwitch: requestSwitch)
            }
        }
        .sheet(isPresented: $showManual, onDismiss: performSwitch) {
            ManualPaneSheet { width, height in
                addManual(width: width, height: height)
            }
        }
        .sheet(isPresented: $showEditor) {
            JobFormSheet(title: "編輯工作", customer: job.customerName, notes: job.notes) { customer, notes in
                job.customerName = customer
                job.notes = notes
                job.updatedAt = .now
                try? context.save()
            }
        }
        .alert("未能儲存", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button(Copy.done, role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Copy.subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.teal)
            Text(MeasureFormat.dateTime(job.createdAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !job.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(job.notes)
                    .font(.body)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.totalArea)
                .font(.headline)
            if summary.hasAbsoluteArea {
                Text(MeasureFormat.area(summary.grand))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if summary.estimateCount > 0 {
                    Text("包含 \(summary.estimateCount) 塊照片估算")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.estimate)
                }
            } else {
                Text("未有可合計的面積")
                    .font(.title3.weight(.semibold))
            }
            HStack(spacing: 12) {
                Text(Copy.pieceCount(job.panes.count))
                if summary.pending > 0 {
                    Text(Copy.pendingPieces(summary.pending))
                        .foregroundStyle(Theme.pending)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var paneList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.glass)
                .font(.title3.bold())
            ForEach(job.orderedPanes) { pane in
                NavigationLink(value: pane.uuid) {
                    paneRow(pane)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func paneRow(_ pane: GlassPane) -> some View {
        HStack(spacing: 12) {
            thumbnail(pane)
            VStack(alignment: .leading, spacing: 4) {
                Text(pane.title.isEmpty ? Copy.glass : pane.title)
                    .font(.headline)
                Text(subtitle(pane.sizing))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button(Copy.delete, role: .destructive) {
                context.delete(pane)
                job.updatedAt = .now
                try? context.save()
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ pane: GlassPane) -> some View {
        if let data = pane.thumbJPEG ?? pane.annotatedJPEG, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
                .frame(width: 72, height: 54)
                .overlay {
                    Image(systemName: pane.source == .photo ? "photo" : "ruler")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func subtitle(_ sizing: PaneSizing) -> String {
        switch sizing {
        case .pending(let ratio, _):
            return "待實尺 · 寬:高 \(ratio)"
        case .sized(let pane):
            return "\(pane.badge) · \(MeasureFormat.pair(width: pane.widthMM, height: pane.heightMM)) · \(MeasureFormat.area(pane.areaM2))"
        case .unavailable(let message):
            return message
        }
    }

    private var pdfBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(Copy.generatePDF) { showPDF = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(job.panes.isEmpty)
            if job.panes.isEmpty {
                Text(Copy.pdfNeedsPane)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.bar)
    }

    private var addMenu: some View {
        Menu {
            Button(Copy.measureAR, systemImage: "viewfinder") { cover = .ar }
            Button(Copy.measurePhoto, systemImage: "photo") { cover = .photo }
            Button(Copy.measureManual, systemImage: "keyboard") { showManual = true }
        } label: {
            Label(Copy.addGlass, systemImage: "plus")
        }
    }

    private func requestSwitch(_ route: ComposerRoute) {
        switchTarget = route
        cover = nil
        showManual = false
    }

    private func performSwitch() {
        guard let target = switchTarget else { return }
        switchTarget = nil
        switch target {
        case .ar: cover = .ar
        case .photo: cover = .photo
        case .manual: showManual = true
        }
    }

    private func addManual(width: Double, height: Double) {
        let pane = GlassPane(title: Copy.glassTitle(job.orderedPanes.count + 1), source: .manual)
        pane.rawWidthMM = width
        pane.rawHeightMM = height
        pane.rawDiagonalMM = hypot(width, height)
        pane.rawAreaM2 = (width / 1000) * (height / 1000)
        job.panes.append(pane)
        job.updatedAt = .now
        do {
            try context.save()
        } catch {
            saveError = "未能儲存這塊玻璃。"
        }
    }
}
