import SwiftUI

struct KnownEdgeSheet: View {
    var proportion: PhotoProportion
    var existingEdge: KnownEdge?
    var existingMM: Double?
    var onApply: (KnownEdge, Double) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var edge: KnownEdge
    @State private var text: String
    @State private var message: String?

    init(
        proportion: PhotoProportion,
        existingEdge: KnownEdge?,
        existingMM: Double?,
        onApply: @escaping (KnownEdge, Double) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.proportion = proportion
        self.existingEdge = existingEdge
        self.existingMM = existingMM
        self.onApply = onApply
        self.onClear = onClear
        _edge = State(initialValue: existingEdge ?? .width)
        _text = State(initialValue: existingMM.map { String(format: "%.0f", $0.rounded()) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("輸入窗框一邊的拉尺讀數。其餘尺寸只按照片比例估算，並標示為估算。")
                        .font(.body)
                    WarningNote(text: Copy.photoWarning)
                }
                Section("已知的是") {
                    Picker("已知邊", selection: $edge) {
                        ForEach(KnownEdge.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("例如 1240", text: $text)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                    Text("單位：毫米")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("換算預覽") {
                    previewContent
                }
                if existingMM != nil {
                    Section {
                        Button(Copy.clearKnownEdge, role: .destructive) {
                            onClear()
                            dismiss()
                        }
                    } footer: {
                        Text("清除後只保留寬高比，毫米及面積會移除。")
                    }
                }
            }
            .navigationTitle(Copy.knownEdge)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.apply) { apply() }
                        .disabled(parsed == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(Copy.done) { hideKeyboard() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var previewContent: some View {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("輸入已知邊長後，先會顯示寬度、高度、對角線及面積。")
                .foregroundStyle(.secondary)
        } else if let sizing {
            switch sizing {
            case .sized(let pane):
                LabeledContent(Copy.width, value: "\(MeasureFormat.mm(pane.widthMM))（\(pane.widthRole.caption)）")
                LabeledContent(Copy.height, value: "\(MeasureFormat.mm(pane.heightMM))（\(pane.heightRole.caption)）")
                LabeledContent(Copy.diagonal, value: "\(MeasureFormat.mm(pane.diagonalMM))（\(pane.diagonalRole.caption)）")
                LabeledContent(Copy.area, value: "\(MeasureFormat.area(pane.areaM2))（\(pane.areaRole.caption)）")
            case .unavailable(let reason):
                Text(reason).foregroundStyle(.red)
            case .pending:
                Text(Copy.pendingExplanation).foregroundStyle(.secondary)
            }
        } else {
            Text("請輸入大於 0 的毫米數字。")
                .foregroundStyle(.secondary)
        }
        if let message {
            Text(message).foregroundStyle(.red)
        }
    }

    private var parsed: Double? { LengthParsing.millimetres(text) }

    private var sizing: PaneSizing? {
        guard let mm = parsed else { return nil }
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
            knownEdge: edge,
            knownEdgeMM: mm,
            tapedWidthMM: nil,
            tapedHeightMM: nil
        ))
    }

    private func apply() {
        guard let mm = parsed else { return }
        guard case .sized = sizing else {
            message = "這個長度未能換算出合理尺寸。"
            return
        }
        onApply(edge, mm)
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct TapeCorrectionSheet: View {
    var raw: RawMeasure
    var existingWidth: Double?
    var existingHeight: Double?
    var onApply: (Double?, Double?) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var widthText: String
    @State private var heightText: String
    @State private var message: String?

    init(
        raw: RawMeasure,
        existingWidth: Double?,
        existingHeight: Double?,
        onApply: @escaping (Double?, Double?) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.raw = raw
        self.existingWidth = existingWidth
        self.existingHeight = existingHeight
        self.onApply = onApply
        self.onClear = onClear
        _widthText = State(initialValue: existingWidth.map { String(format: "%.0f", $0.rounded()) } ?? "")
        _heightText = State(initialValue: existingHeight.map { String(format: "%.0f", $0.rounded()) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("目前實測") {
                    LabeledContent(Copy.width, value: MeasureFormat.mm(raw.widthMM))
                    LabeledContent(Copy.height, value: MeasureFormat.mm(raw.heightMM))
                    LabeledContent(Copy.area, value: MeasureFormat.area(raw.areaM2))
                }
                Section {
                    Text("只填一邊會等比縮放整塊玻璃。兩邊都填則分別採用拉尺讀數。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("拉尺寬度（毫米）", text: $widthText)
                        .keyboardType(.decimalPad)
                    TextField("拉尺高度（毫米）", text: $heightText)
                        .keyboardType(.decimalPad)
                }
                Section("校正預覽") {
                    if widthText.isEmpty && heightText.isEmpty {
                        Text("輸入拉尺讀數後先顯示校正結果。")
                            .foregroundStyle(.secondary)
                    } else if let sizing {
                        switch sizing {
                        case .sized(let pane):
                            LabeledContent(Copy.width, value: "\(MeasureFormat.mm(pane.widthMM))（\(pane.widthRole.caption)）")
                            LabeledContent(Copy.height, value: "\(MeasureFormat.mm(pane.heightMM))（\(pane.heightRole.caption)）")
                            LabeledContent(Copy.diagonal, value: "\(MeasureFormat.mm(pane.diagonalMM))（\(pane.diagonalRole.caption)）")
                            LabeledContent(Copy.area, value: "\(MeasureFormat.area(pane.areaM2))（\(pane.areaRole.caption)）")
                            ForEach(pane.notes, id: \.self) { note in
                                Text(note).font(.footnote)
                            }
                        case .unavailable(let reason):
                            Text(reason)
                        case .pending:
                            EmptyView()
                        }
                    }
                    if let message {
                        Text(message).foregroundStyle(.red)
                    }
                }
                if existingWidth != nil || existingHeight != nil {
                    Section {
                        Button("清除拉尺校正", role: .destructive) {
                            onClear()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(Copy.tapeCorrect)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(Copy.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.apply) { apply() }
                        .disabled(widthText.isEmpty && heightText.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(Copy.done) { hideKeyboard() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var sizing: PaneSizing? {
        let width = widthText.isEmpty ? nil : LengthParsing.millimetres(widthText)
        let height = heightText.isEmpty ? nil : LengthParsing.millimetres(heightText)
        if !widthText.isEmpty && width == nil { return nil }
        if !heightText.isEmpty && height == nil { return nil }
        if width == nil && height == nil { return nil }
        return PaneSizingEngine.derive(PaneInput(
            source: .ar,
            rawWidthMM: raw.widthMM,
            rawHeightMM: raw.heightMM,
            rawDiagonalMM: raw.diagonalMM,
            rawAreaM2: raw.areaM2,
            proportionWidth: nil,
            proportionHeight: nil,
            proportionDiagonal: nil,
            proportionArea: nil,
            knownEdge: nil,
            knownEdgeMM: nil,
            tapedWidthMM: width,
            tapedHeightMM: height
        ))
    }

    private func apply() {
        let width = widthText.isEmpty ? nil : LengthParsing.millimetres(widthText)
        let height = heightText.isEmpty ? nil : LengthParsing.millimetres(heightText)
        guard width != nil || height != nil, case .sized = sizing else {
            message = "請輸入有效的毫米數字。"
            return
        }
        onApply(width, height)
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ManualPaneSheet: View {
    var existingWidth: Double?
    var existingHeight: Double?
    var onSave: (Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var widthText: String
    @State private var heightText: String

    init(existingWidth: Double? = nil, existingHeight: Double? = nil, onSave: @escaping (Double, Double) -> Void) {
        self.onSave = onSave
        _widthText = State(initialValue: existingWidth.map { String(format: "%.0f", $0.rounded()) } ?? "")
        _heightText = State(initialValue: existingHeight.map { String(format: "%.0f", $0.rounded()) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("兩個邊都要人手輸入。程式只按這兩個數計算對角線及面積，不會自行估計未填的一邊。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("寬度（毫米）", text: $widthText)
                        .keyboardType(.decimalPad)
                        .font(.title3.monospacedDigit())
                    TextField("高度（毫米）", text: $heightText)
                        .keyboardType(.decimalPad)
                        .font(.title3.monospacedDigit())
                }
                Section("計算") {
                    if let width = LengthParsing.millimetres(widthText), let height = LengthParsing.millimetres(heightText) {
                        LabeledContent(Copy.width, value: MeasureFormat.mm(width))
                        LabeledContent(Copy.height, value: MeasureFormat.mm(height))
                        LabeledContent(Copy.diagonal, value: MeasureFormat.mm(hypot(width, height)))
                        LabeledContent(Copy.area, value: MeasureFormat.area((width / 1000) * (height / 1000)))
                        Text("以上由輸入的寬度及高度計算。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("寬度及高度都填妥後，才會顯示對角線及面積。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(Copy.measureManual)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(Copy.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.save) { save() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(Copy.done) { hideKeyboard() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSave: Bool {
        LengthParsing.millimetres(widthText) != nil && LengthParsing.millimetres(heightText) != nil
    }

    private func save() {
        guard let width = LengthParsing.millimetres(widthText), let height = LengthParsing.millimetres(heightText) else { return }
        onSave(width, height)
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
