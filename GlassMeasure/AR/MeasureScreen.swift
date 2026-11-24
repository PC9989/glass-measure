import SwiftUI

struct MeasureScreen: View {
    var jobUUID: UUID
    var onSwitch: (ComposerRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \MeasureJob.updatedAt, order: .reverse) private var jobs: [MeasureJob]
    @StateObject private var controller = MeasureController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showTape = false
    @State private var showCloseConfirm = false
    @State private var saveError: String?

    private var job: MeasureJob? { jobs.first { $0.uuid == jobUUID } }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if controller.arUnsupported {
                    blocked(
                        title: Copy.arUnsupportedTitle,
                        message: Copy.arUnsupportedMessage,
                        showSettings: false
                    )
                } else if controller.cameraDenied {
                    blocked(
                        title: Copy.cameraDeniedTitle,
                        message: Copy.cameraDeniedMessage,
                        showSettings: true
                    )
                } else if let sessionError = controller.sessionError {
                    blocked(title: "追蹤未能開始", message: sessionError, showSettings: false, retry: true)
                } else {
                    MeasureARRepresentable(controller: controller)
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture(coordinateSpace: .named("measure")).onEnded { event in
                                controller.place(at: event.location)
                            }
                        )
                    shapeLayer
                    handles
                    chrome(insets: geo.safeAreaInsets)
                }
            }
            .coordinateSpace(name: "measure")
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                controller.resume()
            } else {
                controller.pause()
            }
        }
        .sheet(isPresented: $showTape) {
            if let raw = controller.currentRaw() {
                TapeCorrectionSheet(
                    raw: raw,
                    existingWidth: controller.tapedWidthMM,
                    existingHeight: controller.tapedHeightMM
                ) { width, height in
                    controller.applyTape(width: width, height: height)
                } onClear: {
                    controller.clearTape()
                }
            }
        }
        .alert("離開量度？", isPresented: $showCloseConfirm) {
            Button("離開", role: .destructive) { dismiss() }
            Button(Copy.cancel, role: .cancel) {}
        } message: {
            Text("未儲存的落點會捨棄。")
        }
        .alert("未能儲存", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(Copy.done, role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var shapeLayer: some View {
        Canvas { context, _ in
            let rubber = controller.hud.rubber
            if rubber.count >= 2 {
                stroke(rubber, closed: rubber.count == 4, context: &context, primary: Color.white.opacity(0.9), dashed: true)
            }
            let solid = controller.hud.projected.map(\.point)
            if controller.hud.locked, solid.count >= 2 {
                stroke(solid, closed: solid.count >= 3, context: &context, primary: Color.white, dashed: false)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var handles: some View {
        ZStack {
            if !controller.hud.locked {
                reticle
                ForEach(controller.hud.projected, id: \.index) { corner in
                    cornerDot.position(corner.point).allowsHitTesting(false)
                }
            } else {
                ForEach(controller.hud.projected, id: \.index) { corner in
                    cornerDot
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                        .position(corner.point)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("measure"))
                                .onChanged { value in
                                    controller.moveCorner(index: corner.index, to: value.location)
                                }
                        )
                }
            }
        }
        .ignoresSafeArea()
    }

    private var cornerDot: some View {
        Circle()
            .fill(Color(red: 1, green: 0.82, blue: 0.22))
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(.black, lineWidth: 2))
    }

    private var reticle: some View {
        Circle()
            .stroke(controller.hud.reticleHit ? Color.white : Color.orange, lineWidth: 2)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.black.opacity(0.25)))
            .position(controller.hud.reticle)
            .allowsHitTesting(false)
    }

    private func chrome(insets: EdgeInsets) -> some View {
        VStack(spacing: 10) {
            topBar
            if let tracking = controller.trackingMessage {
                banner(tracking, tint: .orange)
            }
            if let banner = controller.banner {
                banner(banner, tint: .yellow)
            }
            Spacer()
            if !controller.hud.lidarGood {
                banner(Copy.noLiDARWarning, tint: .orange)
            }
            readout
                .padding(.bottom, insets.bottom)
        }
        .padding(.top, insets.top + 8)
        .padding(.horizontal, 16)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                if controller.canSave || controller.canUndo {
                    showCloseConfirm = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.close)

            Picker("量度方式", selection: Binding(
                get: { controller.mode },
                set: { controller.setMode($0) }
            )) {
                ForEach(ARMeasureMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

            Spacer(minLength: 8)

            Text(controller.hud.lidarLabel)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(controller.hud.lidarGood ? Color.green.opacity(0.85) : Color.orange.opacity(0.9), in: Capsule())
                .foregroundStyle(.black)

            Menu {
                Button(Copy.restartTracking) { controller.restartTracking() }
                if controller.meshSupported {
                    Button(controller.showMesh ? Copy.hideMesh : Copy.showMesh) { controller.toggleMesh() }
                }
                Button(Copy.measurePhoto) { onSwitch(.photo) }
                Button(Copy.measureManual) { onSwitch(.manual) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(controller.hud.instruction)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(Copy.placed(controller.hud.placed, of: controller.hud.needed))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            ViewThatFits {
                HStack(alignment: .top) { metrics }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    metrics
                }
            }
            Text(Copy.glassWarning)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.82))
            if let tape = controller.hud.tapeLabel {
                Text(tape)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.22))
            }
            if let data = controller.annotatedJPEG, let image = UIImage(data: data) {
                HStack(spacing: 10) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("標註照片已備妥")
                        .font(.subheadline)
                    Spacer()
                    Button(Copy.retake) { controller.capture() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            controlButtons
        }
        .padding(16)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var metrics: some View {
        metric(Copy.width, controller.hud.widthMM, unit: .length)
        metric(Copy.height, controller.hud.heightMM, unit: .length)
        metric(Copy.diagonal, controller.hud.diagonalMM, unit: .plain)
        metric(Copy.area, controller.hud.areaM2, unit: .area)
    }

    private enum MetricUnit { case length, plain, area }

    private func metric(_ title: String, _ value: Double?, unit: MetricUnit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(primary(value, unit: unit))
                .font(.title.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if unit == .length, let value {
                Text(MeasureFormat.cm(fromMM: value))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primary(_ value: Double?, unit: MetricUnit) -> String {
        guard let value else { return "—" }
        switch unit {
        case .length, .plain: return MeasureFormat.mm(value)
        case .area: return MeasureFormat.area(value)
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 8) {
            if !controller.hud.locked {
                Button(Copy.placePoint) { controller.placeAtCenter() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            HStack(spacing: 8) {
                Button(Copy.resetPoints) { controller.undo() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!controller.canUndo)
                Button(Copy.tapeCorrect) { showTape = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!controller.canSave)
            }
            HStack(spacing: 8) {
                Button(Copy.capture) { controller.capture() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!controller.canSave)
                Button(Copy.savePane) { savePane() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!controller.canSave || job == nil)
            }
        }
    }

    private func banner(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func blocked(title: String, message: String, showSettings: Bool, retry: Bool = false) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.white)
            Text(title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
            if retry {
                Button(Copy.retry) { controller.clearSessionError() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if showSettings {
                Button(Copy.openSettings) { openSettings() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            Button(Copy.measurePhoto) { onSwitch(.photo) }
                .buttonStyle(PrimaryButtonStyle())
            Button(Copy.measureManual) { onSwitch(.manual) }
                .buttonStyle(SecondaryButtonStyle())
            Button(Copy.close) { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
            Spacer()
        }
        .padding(24)
        .foregroundStyle(.white)
    }

    private func savePane() {
        guard let job, let input = controller.makeInput() else { return }
        let pane = GlassPane(title: Copy.glassTitle(job.orderedPanes.count + 1), source: .ar)
        pane.rawWidthMM = input.rawWidthMM
        pane.rawHeightMM = input.rawHeightMM
        pane.rawDiagonalMM = input.rawDiagonalMM
        pane.rawAreaM2 = input.rawAreaM2
        pane.tapedWidthMM = input.tapedWidthMM
        pane.tapedHeightMM = input.tapedHeightMM
        pane.annotatedJPEG = controller.annotatedJPEG
        pane.thumbJPEG = controller.thumbJPEG
        pane.originalJPEG = controller.annotatedJPEG
        job.panes.append(pane)
        job.updatedAt = .now
        do {
            try context.save()
            controller.resetPoints()
            controller.banner = "已儲存。可繼續量度下一塊玻璃。"
        } catch {
            saveError = "未能儲存這塊玻璃。"
        }
    }

    private func stroke(
        _ points: [CGPoint],
        closed: Bool,
        context: inout GraphicsContext,
        primary: Color,
        dashed: Bool
    ) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        if closed { path.closeSubpath() }
        context.stroke(path, with: .color(.black.opacity(0.65)), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
        context.stroke(
            path,
            with: .color(primary),
            style: StrokeStyle(lineWidth: 3, lineJoin: .round, dash: dashed ? [8, 6] : [])
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
