import ARKit
import AVFoundation
import Combine
import RealityKit
import UIKit

enum ARMeasureMode: String, CaseIterable, Identifiable {
    case rectangle
    case quad

    var id: String { rawValue }
    var needed: Int { self == .rectangle ? 2 : 4 }
    var title: String { self == .rectangle ? Copy.rectangleMode : Copy.quadMode }
}

struct ProjectedCorner: Equatable {
    var index: Int
    var point: CGPoint
}

struct MeasureHUD: Equatable {
    var instruction = "將裝置對準窗框"
    var lidarGood = false
    var lidarLabel = "正在檢查感測"
    var projected: [ProjectedCorner] = []
    var rubber: [CGPoint] = []
    var widthMM: Double?
    var heightMM: Double?
    var diagonalMM: Double?
    var areaM2: Double?
    var tapeLabel: String?
    var placed = 0
    var needed = 2
    var locked = false
    var reticle = CGPoint.zero
    var reticleHit = false
}

final class MeasureController: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var hud = MeasureHUD()
    @Published private(set) var mode: ARMeasureMode = .rectangle
    @Published private(set) var cameraDenied = false
    @Published private(set) var arUnsupported = false
    @Published private(set) var sessionError: String?
    @Published private(set) var meshSupported = false
    @Published private(set) var showMesh = false
    @Published private(set) var trackingMessage: String?
    @Published var banner: String?
    @Published private(set) var annotatedJPEG: Data?
    @Published private(set) var thumbJPEG: Data?

    private weak var arView: ARView?
    private var taps: [SIMD3<Float>] = []
    private var lockedCorners: [SIMD3<Float>]?
    private var planePoint: SIMD3<Float>?
    private var planeNormal: SIMD3<Float>?
    private var rectangular = false
    private var baseRaw: RawMeasure?
    private var tapedWidth: Double?
    private var tapedHeight: Double?
    private var lastTick: TimeInterval = 0
    private var sessionStarted = false

    var canSave: Bool { baseRaw != nil && lockedCorners != nil }
    var canUndo: Bool { lockedCorners != nil || !taps.isEmpty }
    var hasTape: Bool { tapedWidth != nil || tapedHeight != nil }
    var tapedWidthMM: Double? { tapedWidth }
    var tapedHeightMM: Double? { tapedHeight }

    func attach(_ view: ARView) {
        guard arView == nil else { return }
        arView = view
        view.session.delegate = self
        view.session.delegateQueue = .main
        guard ARWorldTrackingConfiguration.isSupported else {
            arUnsupported = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession(reset: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startSession(reset: true)
                    } else {
                        self?.cameraDenied = true
                    }
                }
            }
        default:
            cameraDenied = true
        }
    }

    func setMode(_ mode: ARMeasureMode) {
        guard self.mode != mode else { return }
        self.mode = mode
        resetPoints()
    }

    func place(at point: CGPoint) {
        guard lockedCorners == nil else { return }
        guard let hit = resolve(point, preferLockedPlane: planeNormal != nil) else {
            banner = "未對到平面。請移近窗框或牆身，稍候再落點。"
            return
        }
        adoptPlaneIfNeeded(hit)
        guard let normal = planeNormal, let planePoint else { return }
        let onPlane = PaneGeometry.projectOntoPlane(point: hit.position, planePoint: planePoint, normal: normal)
        taps.append(onPlane)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if mode == .rectangle, taps.count >= 2 {
            lockedCorners = PaneGeometry.rectangle(a: taps[0], b: taps[1], normal: normal)
            rectangular = true
            finishLock()
        } else if mode == .quad, taps.count >= 4 {
            let flattened = taps.map {
                PaneGeometry.projectOntoPlane(point: $0, planePoint: planePoint, normal: normal)
            }
            lockedCorners = PaneGeometry.orderOnPlane(flattened, normal: normal)
            rectangular = false
            finishLock()
        }
        refreshHUD(force: true)
    }

    func placeAtCenter() {
        guard let view = arView else { return }
        place(at: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
    }

    func moveCorner(index: Int, to point: CGPoint) {
        guard var corners = lockedCorners,
              corners.indices.contains(index),
              let normal = planeNormal,
              let planePoint,
              let hit = resolve(point, preferLockedPlane: true) else { return }
        let onPlane = PaneGeometry.projectOntoPlane(point: hit.position, planePoint: planePoint, normal: normal)
        if rectangular {
            let opposite = corners[(index + 2) % 4]
            corners = PaneGeometry.rectangle(a: opposite, b: onPlane, normal: normal)
        } else {
            corners[index] = onPlane
        }
        lockedCorners = corners
        baseRaw = PaneGeometry.measure(corners: corners, normal: normal, rectangular: rectangular)
        clearAdjustments(message: "已更改落點，拉尺校正及標註照片已取消。")
        refreshHUD(force: true)
    }

    func undo() {
        if lockedCorners != nil {
            resetPoints()
            return
        }
        guard !taps.isEmpty else { return }
        taps.removeLast()
        if taps.isEmpty {
            planePoint = nil
            planeNormal = nil
        }
        refreshHUD(force: true)
    }

    func resetPoints() {
        taps = []
        lockedCorners = nil
        planePoint = nil
        planeNormal = nil
        rectangular = false
        baseRaw = nil
        tapedWidth = nil
        tapedHeight = nil
        annotatedJPEG = nil
        thumbJPEG = nil
        refreshHUD(force: true)
    }

    func applyTape(width: Double?, height: Double?) {
        guard baseRaw != nil else { return }
        tapedWidth = width
        tapedHeight = height
        annotatedJPEG = nil
        thumbJPEG = nil
        banner = "已套用拉尺校正。標註照片需重新拍攝。"
        refreshHUD(force: true)
    }

    func clearTape() {
        tapedWidth = nil
        tapedHeight = nil
        annotatedJPEG = nil
        thumbJPEG = nil
        refreshHUD(force: true)
    }

    func capture() {
        guard let view = arView, let corners = lockedCorners, let input = makeInput() else { return }
        guard case .sized(let pane) = PaneSizingEngine.derive(input) else { return }
        let viewSize = view.bounds.size
        let points = project(corners, in: view)
        guard points.count == 4 else {
            banner = "畫面未能對齊四個角，請稍移裝置再拍攝。"
            return
        }
        let ordered = points.sorted { $0.index < $1.index }.map(\.point)
        view.snapshot(saveToHDR: false) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let image else {
                    self.banner = "未能拍攝畫面。"
                    return
                }
                let lines = [
                    "寬 \(MeasureFormat.mm(pane.widthMM))",
                    "高 \(MeasureFormat.mm(pane.heightMM))",
                    "斜 \(MeasureFormat.mm(pane.diagonalMM))",
                    MeasureFormat.area(pane.areaM2)
                ]
                let drawn = AROverlayRenderer.render(
                    image: image,
                    viewSize: viewSize,
                    corners: ordered,
                    lines: lines,
                    badge: pane.badge
                )
                self.annotatedJPEG = ImageTools.jpeg(drawn, quality: 0.82)
                self.thumbJPEG = ImageTools.thumbnail(drawn)
                self.banner = "已拍下標註照片。"
            }
        }
    }

    func makeInput() -> PaneInput? {
        guard let raw = baseRaw else { return nil }
        return PaneInput(
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
            tapedWidthMM: tapedWidth,
            tapedHeightMM: tapedHeight
        )
    }

    func currentRaw() -> RawMeasure? { baseRaw }

    func toggleMesh() {
        showMesh.toggle()
        applyMeshVisibility()
    }

    func clearSessionError() {
        sessionError = nil
        startSession(reset: true)
    }

    func restartTracking() {
        resetPoints()
        startSession(reset: true)
        banner = "已重新開始追蹤。"
    }

    func pause() {
        arView?.session.pause()
    }

    func resume() {
        guard sessionStarted, !cameraDenied, !arUnsupported else { return }
        startSession(reset: false)
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        trackingMessage = Self.describe(camera.trackingState)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionError = "追蹤未能開始。可改用照片估算或手動輸入。"
    }

    func sessionWasInterrupted(_ session: ARSession) {
        banner = "量度已暫停。"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        banner = "追蹤已恢復。請確認窗框仍在畫面中。"
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        refreshHUD(force: false)
    }

    private func startSession(reset: Bool) {
        guard let view = arView else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            arUnsupported = true
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = [.vertical, .horizontal]
        config.environmentTexturing = .none
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            meshSupported = true
        } else {
            meshSupported = false
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        view.session.run(config, options: options)
        sessionStarted = true
        applyMeshVisibility()
        refreshHUD(force: true)
    }

    private func applyMeshVisibility() {
        guard let view = arView, meshSupported else { return }
        if showMesh {
            view.debugOptions.insert(.showSceneUnderstanding)
        } else {
            view.debugOptions.remove(.showSceneUnderstanding)
        }
    }

    private struct Hit {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }

    private func resolve(_ point: CGPoint, preferLockedPlane: Bool) -> Hit? {
        guard let view = arView else { return nil }
        if preferLockedPlane,
           let planePoint,
           let planeNormal,
           let ray = view.ray(through: point),
           let hit = PaneGeometry.intersectPlane(
            origin: ray.origin,
            direction: ray.direction,
            planePoint: planePoint,
            normal: planeNormal
           ) {
            return Hit(position: hit, normal: planeNormal)
        }
        return raycast(point, in: view)
    }

    private func raycast(_ point: CGPoint, in view: ARView) -> Hit? {
        let targets: [ARRaycastQuery.Target] = [.existingPlaneInfinite, .existingPlaneGeometry, .estimatedPlane]
        let alignments: [ARRaycastQuery.TargetAlignment] = [.vertical, .any]
        for target in targets {
            for alignment in alignments {
                guard let query = view.makeRaycastQuery(from: point, allowing: target, alignment: alignment),
                      let result = view.session.raycast(query).first else { continue }
                return makeHit(result)
            }
        }
        return nil
    }

    private func makeHit(_ result: ARRaycastResult) -> Hit {
        let column = result.worldTransform.columns.3
        let position = SIMD3<Float>(column.x, column.y, column.z)
        var normal = SIMD3<Float>(
            result.worldTransform.columns.1.x,
            result.worldTransform.columns.1.y,
            result.worldTransform.columns.1.z
        )
        if let plane = result.anchor as? ARPlaneAnchor {
            normal = SIMD3<Float>(plane.transform.columns.1.x, plane.transform.columns.1.y, plane.transform.columns.1.z)
        }
        if simd_length(normal) < 0.001 {
            normal = SIMD3<Float>(0, 0, 1)
        }
        if let frame = arView?.session.currentFrame {
            let cameraColumn = frame.camera.transform.columns.3
            let camera = SIMD3<Float>(cameraColumn.x, cameraColumn.y, cameraColumn.z)
            normal = PaneGeometry.facingNormal(normal, camera: camera, point: position)
        } else {
            normal = simd_normalize(normal)
        }
        return Hit(position: position, normal: normal)
    }

    private func adoptPlaneIfNeeded(_ hit: Hit) {
        guard planeNormal == nil else { return }
        planeNormal = hit.normal
        planePoint = hit.position
    }

    private func finishLock() {
        guard let corners = lockedCorners, let normal = planeNormal else { return }
        baseRaw = PaneGeometry.measure(corners: corners, normal: normal, rectangular: rectangular)
        taps = []
        banner = nil
    }

    private func clearAdjustments(message: String) {
        let hadAdjustment = tapedWidth != nil || tapedHeight != nil || annotatedJPEG != nil
        tapedWidth = nil
        tapedHeight = nil
        annotatedJPEG = nil
        thumbJPEG = nil
        if hadAdjustment {
            banner = message
        }
    }

    private func project(_ points: [SIMD3<Float>], in view: ARView) -> [ProjectedCorner] {
        points.enumerated().compactMap { index, point in
            guard let projected = view.project(point), projected.x.isFinite, projected.y.isFinite else { return nil }
            return ProjectedCorner(index: index, point: projected)
        }
    }

    private func refreshHUD(force: Bool) {
        let now = CACurrentMediaTime()
        if !force, now - lastTick < 0.08 { return }
        lastTick = now
        guard let view = arView, view.bounds.width > 1, view.bounds.height > 1 else { return }

        var next = MeasureHUD()
        next.needed = mode.needed
        next.lidarGood = meshSupported
        next.lidarLabel = meshSupported ? Copy.hasLiDAR : Copy.noLiDAR
        next.reticle = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        next.locked = lockedCorners != nil

        if let corners = lockedCorners {
            next.projected = project(corners, in: view)
            next.placed = mode.needed
            next.instruction = "拖動角點可微調。儲存前可以拉尺校正及拍攝。"
            if let raw = baseRaw, let input = input(from: raw), case .sized(let pane) = PaneSizingEngine.derive(input) {
                next.widthMM = pane.widthMM
                next.heightMM = pane.heightMM
                next.diagonalMM = pane.diagonalMM
                next.areaM2 = pane.areaM2
                next.tapeLabel = hasTape ? pane.badge : nil
            }
        } else {
            next.projected = project(taps, in: view)
            next.placed = taps.count
            next.instruction = instruction
            if let preview = previewCorners(in: view) {
                next.rubber = preview.points
                next.reticleHit = preview.hit
                if let raw = preview.measure {
                    next.widthMM = raw.widthMM
                    next.heightMM = raw.heightMM
                    next.diagonalMM = raw.diagonalMM
                    next.areaM2 = raw.areaM2
                }
            } else {
                next.reticleHit = resolve(next.reticle, preferLockedPlane: planeNormal != nil) != nil
            }
        }
        if next != hud {
            hud = next
        }
    }

    private struct Preview {
        var points: [CGPoint]
        var measure: RawMeasure?
        var hit: Bool
    }

    private func previewCorners(in view: ARView) -> Preview? {
        guard lockedCorners == nil, let normal = planeNormal, let planePoint, !taps.isEmpty else { return nil }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let hit = resolve(center, preferLockedPlane: true) else {
            return Preview(points: project(taps, in: view).map(\.point), measure: nil, hit: false)
        }
        let onPlane = PaneGeometry.projectOntoPlane(point: hit.position, planePoint: planePoint, normal: normal)
        if mode == .rectangle, taps.count == 1 {
            let rect = PaneGeometry.rectangle(a: taps[0], b: onPlane, normal: normal)
            let measure = PaneGeometry.measure(corners: rect, normal: normal, rectangular: true)
            return Preview(points: project(rect, in: view).map(\.point), measure: measure, hit: true)
        }
        if mode == .quad, taps.count < 4 {
            var preview = taps
            preview.append(onPlane)
            let world = preview.count == 4 ? PaneGeometry.orderOnPlane(preview, normal: normal) : preview
            let measure = preview.count == 4
                ? PaneGeometry.measure(corners: world, normal: normal, rectangular: false)
                : nil
            return Preview(points: project(world, in: view).map(\.point), measure: measure, hit: true)
        }
        return nil
    }

    private var instruction: String {
        switch mode {
        case .rectangle:
            return taps.isEmpty
                ? "點選窗框一個角，或將中心對準後按落點。"
                : "點選對角。矩形會貼在第一點的牆身平面。"
        case .quad:
            return "點選窗框第 \(min(taps.count + 1, 4)) 個角。其後的點會貼上同一平面。"
        }
    }

    private func input(from raw: RawMeasure) -> PaneInput? {
        PaneInput(
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
            tapedWidthMM: tapedWidth,
            tapedHeightMM: tapedHeight
        )
    }

    private static func describe(_ state: ARCamera.TrackingState) -> String? {
        switch state {
        case .normal:
            return nil
        case .notAvailable:
            return "追蹤暫不可用"
        case .limited(let reason):
            switch reason {
            case .initializing:
                return "正在啟動追蹤，請緩慢移動裝置"
            case .relocalizing:
                return "正在重新定位"
            case .excessiveMotion:
                return "移動過快，請放慢"
            case .insufficientFeatures:
                return "特徵不足。請對準窗框邊緣或有紋理的牆身"
            @unknown default:
                return "追蹤受限制"
            }
        }
    }
}
