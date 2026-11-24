import SwiftUI
import UIKit

struct PhotoViewport {
    var viewSize: CGSize
    var imageSize: CGSize
    var zoom: CGFloat
    var pan: CGSize

    var fit: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else { return 1 }
        return min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    }

    var displaySize: CGSize {
        CGSize(width: imageSize.width * fit * zoom, height: imageSize.height * fit * zoom)
    }

    var origin: CGPoint {
        CGPoint(
            x: (viewSize.width - displaySize.width) / 2 + pan.width,
            y: (viewSize.height - displaySize.height) / 2 + pan.height
        )
    }

    func viewPoint(_ normalized: Vec2) -> CGPoint {
        CGPoint(
            x: origin.x + CGFloat(normalized.x) * displaySize.width,
            y: origin.y + CGFloat(normalized.y) * displaySize.height
        )
    }

    func normalized(from point: CGPoint, clamp: Bool) -> Vec2? {
        guard displaySize.width > 1, displaySize.height > 1 else { return nil }
        let x = Double((point.x - origin.x) / displaySize.width)
        let y = Double((point.y - origin.y) / displaySize.height)
        if clamp {
            return Vec2(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
        }
        guard x >= 0, x <= 1, y >= 0, y <= 1 else { return nil }
        return Vec2(x: x, y: y)
    }
}

enum MarkReadout: Equatable {
    case none
    case ratio(String)
    case metrics([String])
}

struct PhotoMarkingView: View {
    var image: UIImage
    var points: [Vec2]
    var locked: Bool
    var readout: MarkReadout
    var onTap: (Vec2) -> Void
    var onMove: (Int, Vec2) -> Void

    @State private var zoom: CGFloat = 1
    @State private var zoomBase: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var ignoreTap = false
    @State private var loupe: (view: CGPoint, normalized: Vec2)?

    var body: some View {
        GeometryReader { geo in
            let viewport = PhotoViewport(viewSize: geo.size, imageSize: image.size, zoom: zoom, pan: pan)
            ZStack {
                Color.black
                Image(uiImage: image)
                    .resizable()
                    .frame(width: viewport.displaySize.width, height: viewport.displaySize.height)
                    .position(
                        x: viewport.origin.x + viewport.displaySize.width / 2,
                        y: viewport.origin.y + viewport.displaySize.height / 2
                    )
                    .allowsHitTesting(false)
                Canvas { context, _ in
                    let screen = points.map { viewport.viewPoint($0) }
                    guard screen.count >= 2 else { return }
                    var path = Path()
                    path.move(to: screen[0])
                    for point in screen.dropFirst() { path.addLine(to: point) }
                    if locked, screen.count >= 3 { path.closeSubpath() }
                    context.stroke(path, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
                    context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                }
                .allowsHitTesting(false)

                readoutLabel(viewport)
                    .allowsHitTesting(false)

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    let center = viewport.viewPoint(point)
                    Circle()
                        .fill(Color(red: 1, green: 0.82, blue: 0.22))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.black, lineWidth: 2))
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                        .position(center)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("photo"))
                                .onChanged { value in
                                    guard locked, let norm = viewport.normalized(from: value.location, clamp: true) else { return }
                                    loupe = (value.location, norm)
                                    onMove(index, norm)
                                }
                                .onEnded { _ in
                                    loupe = nil
                                }
                        )
                }

                if let loupe {
                    loupeView(loupe, viewport: viewport)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(panGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .named("photo")).onEnded { value in
                    guard !ignoreTap, !locked else { return }
                    guard let norm = viewport.normalized(from: value.location, clamp: false) else { return }
                    onTap(norm)
                }
            )
            .overlay(alignment: .topTrailing) {
                Button(Copy.fitPhoto) { resetZoom() }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .coordinateSpace(name: "photo")
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .named("photo"))
            .onChanged { value in
                ignoreTap = true
                pan = CGSize(width: panBase.width + value.translation.width, height: panBase.height + value.translation.height)
            }
            .onEnded { _ in
                panBase = pan
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    ignoreTap = false
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(zoomBase * value, 1), 6)
            }
            .onEnded { _ in
                zoomBase = zoom
                if zoom <= 1.01 {
                    pan = .zero
                    panBase = .zero
                }
            }
    }

    @ViewBuilder
    private func readoutLabel(_ viewport: PhotoViewport) -> some View {
        if points.count == 4 {
            let centre = points.reduce(Vec2(x: 0, y: 0)) { Vec2(x: $0.x + $1.x, y: $0.y + $1.y) }
            let point = viewport.viewPoint(Vec2(x: centre.x / 4, y: centre.y / 4))
            switch readout {
            case .none:
                EmptyView()
            case .ratio(let ratio):
                labelCard(["待實尺", "寬:高 \(ratio)"], badge: nil).position(point)
            case .metrics(let lines):
                labelCard(lines, badge: Copy.estimate).position(point)
            }
        }
    }

    private func labelCard(_ lines: [String], badge: String?) -> some View {
        VStack(spacing: 4) {
            if let badge {
                Text(badge)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 1, green: 0.82, blue: 0.22), in: Capsule())
                    .foregroundStyle(.black)
            }
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func loupeView(_ loupe: (view: CGPoint, normalized: Vec2), viewport: PhotoViewport) -> some View {
        let size: CGFloat = 120
        let magnification: CGFloat = 2.4
        let magnified = CGSize(
            width: viewport.displaySize.width * magnification,
            height: viewport.displaySize.height * magnification
        )
        let imageCenter = CGPoint(
            x: size / 2 + magnified.width * (0.5 - CGFloat(loupe.normalized.x)),
            y: size / 2 + magnified.height * (0.5 - CGFloat(loupe.normalized.y))
        )
        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: magnified.width, height: magnified.height)
                .position(imageCenter)
            Path { path in
                path.move(to: CGPoint(x: size / 2 - 12, y: size / 2))
                path.addLine(to: CGPoint(x: size / 2 + 12, y: size / 2))
                path.move(to: CGPoint(x: size / 2, y: size / 2 - 12))
                path.addLine(to: CGPoint(x: size / 2, y: size / 2 + 12))
            }
            .stroke(Color(red: 1, green: 0.82, blue: 0.22), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
        .background(.black, in: Circle())
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .position(x: loupe.view.x, y: max(78, loupe.view.y - 96))
    }

    func resetZoom() {
        zoom = 1
        zoomBase = 1
        pan = .zero
        panBase = .zero
    }
}
