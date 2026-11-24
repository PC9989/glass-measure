import AVFoundation
import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImportedPicture: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedPicture(data: data)
        }
    }
}

struct PhotoMeasureScreen: View {
    var jobUUID: UUID
    var onSwitch: (ComposerRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \MeasureJob.updatedAt, order: .reverse) private var jobs: [MeasureJob]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var image: UIImage?
    @State private var originalJPEG: Data?
    @State private var mode: PhotoShapeMode = .quad
    @State private var points: [Vec2] = []
    @State private var locked = false
    @State private var knownEdge: KnownEdge?
    @State private var knownMM: Double?
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var showCamera = false
    @State private var showKnown = false
    @State private var showCloseConfirm = false
    @State private var errorText: String?
    @State private var banner: String?

    private var job: MeasureJob? { jobs.first { $0.uuid == jobUUID } }
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    marker(image)
                } else {
                    chooser
                }
            }
            .navigationTitle(Copy.measurePhoto)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.close) {
                        if locked || !points.isEmpty {
                            showCloseConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                }
                if image != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button(Copy.replacePhoto) { replacePhoto() }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadFile(url)
            case .failure:
                errorText = "未能開啟檔案。"
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { picked in
                showCamera = false
                load(image: picked)
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPicker(item) }
        }
        .sheet(isPresented: $showKnown) {
            if let proportion = currentProportion {
                KnownEdgeSheet(proportion: proportion, existingEdge: knownEdge, existingMM: knownMM) { edge, mm in
                    knownEdge = edge
                    knownMM = mm
                } onClear: {
                    knownEdge = nil
                    knownMM = nil
                }
            }
        }
        .alert("離開照片估算？", isPresented: $showCloseConfirm) {
            Button("離開", role: .destructive) { dismiss() }
            Button(Copy.cancel, role: .cancel) {}
        } message: {
            Text("未儲存的標示會捨棄。")
        }
        .alert("未能處理相片", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button(Copy.done, role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Copy.choosePhoto)
                    .font(.largeTitle.bold())
                Text("在相片上標示窗框。未輸入已知邊長時，只會記錄寬高比，不會估算毫米或面積。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                WarningNote(text: Copy.photoWarning)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(Copy.photoLibrary, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    showFiles = true
                } label: {
                    Label(Copy.photoFiles, systemImage: "folder")
                }
                .buttonStyle(SecondaryButtonStyle())
                if cameraAvailable {
                    Button {
                        openCamera()
                    } label: {
                        Label(Copy.photoCamera, systemImage: "camera")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Text(Copy.localOnly)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(Copy.measureAR) { onSwitch(.ar) }
                    .buttonStyle(SecondaryButtonStyle())
                Button(Copy.measureManual) { onSwitch(.manual) }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func marker(_ image: UIImage) -> some View {
        GeometryReader { geo in
            let sideBySide = horizontalSizeClass == .regular && geo.size.width > geo.size.height && geo.size.width > 900
            if sideBySide {
                HStack(spacing: 0) {
                    PhotoMarkingView(
                        image: image,
                        points: points,
                        locked: locked,
                        readout: readout,
                        onTap: addPoint,
                        onMove: movePoint
                    )
                    panel
                        .frame(width: 360)
                        .background(.background)
                }
            } else {
                VStack(spacing: 0) {
                    PhotoMarkingView(
                        image: image,
                        points: points,
                        locked: locked,
                        readout: readout,
                        onTap: addPoint,
                        onMove: movePoint
                    )
                    panel
                        .frame(maxHeight: geo.size.height * 0.46)
                }
            }
        }
    }

    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("標示方式", selection: $mode) {
                    Text("四角").tag(PhotoShapeMode.quad)
                    Text("矩形").tag(PhotoShapeMode.rectangle)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in
                    points = []
                    locked = false
                }

                if let banner {
                    Text(banner)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.measured)
                }

                if let sizing = currentSizing {
                    sizingPanel(sizing)
                } else {
                    instruction
                    Button(Copy.backOne) { undo() }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(points.isEmpty && !locked)
                }
            }
            .padding(16)
        }
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .quad
                 ? "依序點選窗框四個角。可雙指縮放後再落點。"
                 : (points.isEmpty ? "點選矩形的一個角。" : "點選對角，拉出貼齊相片的矩形。"))
                .font(.headline)
            Text(Copy.placed(locked ? (mode == .quad ? 4 : 2) : points.count, of: mode == .quad ? 4 : 2))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("標示完成前不會顯示毫米或面積。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sizingPanel(_ sizing: PaneSizing) -> some View {
        switch sizing {
        case .pending(let ratio, let precise):
            Text(Copy.ratioCaption)
                .font(.headline)
            Text(ratio)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("寬比高 \(ratio)，未有實尺")
            Text("\(Copy.ratioPreciseCaption) \(precise)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(Copy.pendingExplanation)
                .font(.body)
            WarningNote(text: Copy.photoWarning)
            Button(Copy.enterKnownEdge) { showKnown = true }
                .buttonStyle(PrimaryButtonStyle())
            Button(Copy.savePending) { save() }
                .buttonStyle(SecondaryButtonStyle())
            Button(Copy.backOne) { undo() }
                .buttonStyle(SecondaryButtonStyle())
        case .sized(let pane):
            StatusBadge(text: pane.badge, tint: Theme.estimate)
            ViewThatFits {
                HStack(alignment: .top) { sizedMetrics(pane) }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                    sizedMetrics(pane)
                }
            }
            ForEach(pane.notes, id: \.self) { note in
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
            WarningNote(text: Copy.photoWarning)
            Button(Copy.changeKnownEdge) { showKnown = true }
                .buttonStyle(SecondaryButtonStyle())
            Button(Copy.saveEstimate) { save() }
                .buttonStyle(PrimaryButtonStyle())
            Button(Copy.backOne) { undo() }
                .buttonStyle(SecondaryButtonStyle())
        case .unavailable(let message):
            Text(message).font(.body)
            Button(Copy.backOne) { undo() }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    @ViewBuilder
    private func sizedMetrics(_ pane: SizedPane) -> some View {
        MetricBlock(
            title: Copy.width,
            value: MeasureFormat.mm(pane.widthMM),
            caption: pane.widthRole.caption,
            secondary: MeasureFormat.cm(fromMM: pane.widthMM)
        )
        MetricBlock(
            title: Copy.height,
            value: MeasureFormat.mm(pane.heightMM),
            caption: pane.heightRole.caption,
            secondary: MeasureFormat.cm(fromMM: pane.heightMM)
        )
        MetricBlock(title: Copy.diagonal, value: MeasureFormat.mm(pane.diagonalMM), caption: pane.diagonalRole.caption)
        MetricBlock(title: Copy.area, value: MeasureFormat.area(pane.areaM2), caption: pane.areaRole.caption)
    }

    private var readout: MarkReadout {
        guard let sizing = currentSizing else { return .none }
        switch sizing {
        case .pending(let ratio, _):
            return .ratio(ratio)
        case .sized(let pane):
            return .metrics([
                MeasureFormat.pair(width: pane.widthMM, height: pane.heightMM),
                MeasureFormat.area(pane.areaM2)
            ])
        case .unavailable:
            return .none
        }
    }

    private var currentProportion: PhotoProportion? {
        guard locked, points.count == 4, let image else { return nil }
        let pixels = ImageTools.pixelSize(of: image)
        return PhotoProportionMath.measure(
            pixelWidth: pixels.width,
            pixelHeight: pixels.height,
            normalized: points,
            mode: mode
        )
    }

    private var currentSizing: PaneSizing? {
        guard let proportion = currentProportion else { return nil }
        return PaneSizingEngine.derive(PaneInput(
            source: .photo,
            rawWidthMM: nil,
            rawHeightMM: nil,
            rawDiagonalMM: nil,
            rawAreaM2: nil,
            proportionWidth: proportion.widthPx,
            proportionHeight: proportion.heightPx,
            proportionDiagonal: proportion.diagonalPx,
            proportionArea: proportion.areaPx,
            knownEdge: knownEdge,
            knownEdgeMM: knownMM,
            tapedWidthMM: nil,
            tapedHeightMM: nil
        ))
    }

    private func addPoint(_ point: Vec2) {
        guard !locked else { return }
        banner = nil
        if mode == .rectangle {
            if points.isEmpty {
                points = [point]
            } else {
                points = PhotoProportionMath.rectangleCorners(a: points[0], b: point)
                locked = true
            }
        } else {
            points.append(point)
            if points.count == 4 {
                points = PhotoProportionMath.orderClockwise(points)
                locked = true
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func movePoint(_ index: Int, _ point: Vec2) {
        guard locked, points.indices.contains(index) else { return }
        if mode == .rectangle {
            let opposite = points[(index + 2) % 4]
            points = PhotoProportionMath.rectangleCorners(a: opposite, b: point)
        } else {
            points[index] = point
        }
    }

    private func undo() {
        banner = nil
        if locked {
            points = []
            locked = false
            return
        }
        if !points.isEmpty { points.removeLast() }
    }

    private func replacePhoto() {
        image = nil
        originalJPEG = nil
        points = []
        locked = false
        knownEdge = nil
        knownMM = nil
        photoItem = nil
        banner = nil
    }

    private func save() {
        guard let job, let image, let proportion = currentProportion, let sizing = currentSizing else { return }
        switch sizing {
        case .unavailable(let message):
            errorText = message
            return
        case .pending, .sized:
            break
        }
        let pane = GlassPane(title: Copy.glassTitle(job.orderedPanes.count + 1), source: .photo)
        pane.proportionWidth = proportion.widthPx
        pane.proportionHeight = proportion.heightPx
        pane.proportionDiagonal = proportion.diagonalPx
        pane.proportionArea = proportion.areaPx
        pane.knownEdgeRaw = knownEdge?.rawValue
        pane.knownEdgeMM = knownMM
        pane.shapeModeRaw = mode.rawValue
        pane.cornersJSON = CornerCodec.encode(points)
        pane.originalJPEG = originalJPEG
        pane.rawWidthMM = nil
        pane.rawHeightMM = nil
        pane.rawDiagonalMM = nil
        pane.rawAreaM2 = nil
        if let burn = sizing.photoBurn {
            let stored = PhotoAnnotationRenderer.store(image: image, normalized: points, burn: burn)
            pane.annotatedJPEG = stored.annotated
            pane.thumbJPEG = stored.thumb
        }
        job.panes.append(pane)
        job.updatedAt = .now
        do {
            try context.save()
            points = []
            locked = false
            knownEdge = nil
            knownMM = nil
            banner = "已儲存。可在同一張相片再標下一塊，或換相片。"
        } catch {
            errorText = "未能儲存這塊玻璃。"
        }
    }

    private func loadPicker(_ item: PhotosPickerItem) async {
        do {
            if let picture = try await item.loadTransferable(type: ImportedPicture.self) {
                await MainActor.run { load(data: picture.data) }
            } else {
                await MainActor.run { errorText = "未能讀取這張相片。" }
            }
        } catch {
            await MainActor.run { errorText = "未能讀取這張相片。" }
        }
    }

    private func loadFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorText = "未能讀取這張相片。"
            return
        }
        load(data: data)
    }

    private func load(data: Data) {
        guard let raw = UIImage(data: data) else {
            errorText = "未能讀取這張相片。"
            return
        }
        load(image: raw)
    }

    private func load(image: UIImage) {
        let prepared = ImageTools.prepared(image)
        self.image = prepared
        originalJPEG = ImageTools.jpeg(prepared, quality: 0.86)
        points = []
        locked = false
        knownEdge = nil
        knownMM = nil
        banner = nil
    }

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true }
                    else { errorText = Copy.cameraDeniedMessage }
                }
            }
        default:
            errorText = Copy.cameraDeniedMessage
        }
    }
}
