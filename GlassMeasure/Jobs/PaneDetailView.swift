import SwiftUI

struct PaneDetailView: View {
    @Bindable var pane: GlassPane
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showKnown = false
    @State private var showTape = false
    @State private var showManual = false
    @State private var showDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("名稱", text: $pane.title)
                    .font(.title.bold())
                if let badge = pane.sizing.badgeText {
                    StatusBadge(text: badge, tint: pane.sizing.badgeTint)
                }
                sizingBody
                if let image = (pane.annotatedJPEG ?? pane.originalJPEG).flatMap(UIImage.init(data:)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08)))
                }
                TextField(Copy.notesPlaceholder, text: $pane.notes, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                Button(Copy.delete, role: .destructive) { showDelete = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(pane.title.isEmpty ? Copy.glass : pane.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pane.title) { _, _ in touch() }
        .onChange(of: pane.notes) { _, _ in touch() }
        .sheet(isPresented: $showKnown) {
            if let proportion = pane.proportion {
                KnownEdgeSheet(
                    proportion: proportion,
                    existingEdge: pane.knownEdge,
                    existingMM: pane.knownEdgeMM
                ) { edge, mm in
                    pane.knownEdgeRaw = edge.rawValue
                    pane.knownEdgeMM = mm
                    rewritePhoto()
                    touch()
                } onClear: {
                    pane.knownEdgeRaw = nil
                    pane.knownEdgeMM = nil
                    rewritePhoto()
                    touch()
                }
            }
        }
        .sheet(isPresented: $showTape) {
            if let width = pane.rawWidthMM, let height = pane.rawHeightMM, let diagonal = pane.rawDiagonalMM, let area = pane.rawAreaM2 {
                TapeCorrectionSheet(
                    raw: RawMeasure(widthMM: width, heightMM: height, diagonalMM: diagonal, areaM2: area),
                    existingWidth: pane.tapedWidthMM,
                    existingHeight: pane.tapedHeightMM
                ) { tapedWidth, tapedHeight in
                    pane.tapedWidthMM = tapedWidth
                    pane.tapedHeightMM = tapedHeight
                    touch()
                } onClear: {
                    pane.tapedWidthMM = nil
                    pane.tapedHeightMM = nil
                    touch()
                }
            }
        }
        .sheet(isPresented: $showManual) {
            ManualPaneSheet(existingWidth: pane.rawWidthMM, existingHeight: pane.rawHeightMM) { width, height in
                pane.rawWidthMM = width
                pane.rawHeightMM = height
                pane.rawDiagonalMM = hypot(width, height)
                pane.rawAreaM2 = (width / 1000) * (height / 1000)
                touch()
            }
        }
        .confirmationDialog("刪除這塊玻璃？", isPresented: $showDelete, titleVisibility: .visible) {
            Button(Copy.delete, role: .destructive) {
                context.delete(pane)
                pane.job?.updatedAt = .now
                try? context.save()
                dismiss()
            }
            Button(Copy.cancel, role: .cancel) {}
        }
    }

    @ViewBuilder
    private var sizingBody: some View {
        switch pane.sizing {
        case .pending(let ratio, let precise):
            VStack(alignment: .leading, spacing: 8) {
                Text(Copy.ratioCaption)
                    .font(.headline)
                Text(ratio)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text("\(Copy.ratioPreciseCaption) \(precise)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(Copy.pendingExplanation)
                    .font(.body)
                WarningNote(text: Copy.photoWarning)
                Button(Copy.enterKnownEdge) { showKnown = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .sized(let sized):
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                    MetricBlock(title: Copy.width, value: MeasureFormat.mm(sized.widthMM), caption: sized.widthRole.caption, secondary: MeasureFormat.cm(fromMM: sized.widthMM))
                    MetricBlock(title: Copy.height, value: MeasureFormat.mm(sized.heightMM), caption: sized.heightRole.caption, secondary: MeasureFormat.cm(fromMM: sized.heightMM))
                    MetricBlock(title: Copy.diagonal, value: MeasureFormat.mm(sized.diagonalMM), caption: sized.diagonalRole.caption)
                    MetricBlock(title: Copy.area, value: MeasureFormat.area(sized.areaM2), caption: sized.areaRole.caption)
                }
                ForEach(sized.notes, id: \.self) { note in
                    Text(note).font(.subheadline).foregroundStyle(.secondary)
                }
                if sized.bucket == .estimate {
                    WarningNote(text: Copy.photoWarning)
                    Button(Copy.changeKnownEdge) { showKnown = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
                if pane.source == .ar {
                    if pane.annotatedJPEG != nil && (pane.tapedWidthMM != nil || pane.tapedHeightMM != nil) {
                        Text("若校正是在拍攝之後才加上，相片上的數字可能仍是校正前的實測。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button(Copy.tapeCorrect) { showTape = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
                if pane.source == .manual {
                    Button("修改尺寸") { showManual = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        case .unavailable(let message):
            Text(message)
            if pane.source == .photo {
                Button(Copy.enterKnownEdge) { showKnown = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(pane.proportion == nil)
            }
        }
    }

    private func rewritePhoto() {
        guard let data = pane.originalJPEG, let image = UIImage(data: data) else {
            pane.annotatedJPEG = nil
            pane.thumbJPEG = nil
            return
        }
        let corners = CornerCodec.decode(pane.cornersJSON)
        guard corners.count == 4, let burn = pane.sizing.photoBurn else {
            pane.annotatedJPEG = nil
            pane.thumbJPEG = nil
            return
        }
        let stored = PhotoAnnotationRenderer.store(image: image, normalized: corners, burn: burn)
        pane.annotatedJPEG = stored.annotated
        pane.thumbJPEG = stored.thumb
    }

    private func touch() {
        pane.job?.updatedAt = .now
        try? context.save()
    }
}
