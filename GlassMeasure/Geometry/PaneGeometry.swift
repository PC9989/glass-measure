import Foundation
import simd

struct RawMeasure: Equatable {
    var widthMM: Double
    var heightMM: Double
    var diagonalMM: Double
    var areaM2: Double
}

enum PaneGeometry {
    static func facingNormal(_ normal: SIMD3<Float>, camera: SIMD3<Float>, point: SIMD3<Float>) -> SIMD3<Float> {
        let n = simd_normalize(normal)
        return simd_dot(n, camera - point) >= 0 ? n : -n
    }

    /// Horizontal and vertical axes lying on a plane. Up follows gravity when the plane is a wall.
    static func planeAxes(normal: SIMD3<Float>) -> (right: SIMD3<Float>, up: SIMD3<Float>) {
        let n = simd_normalize(normal)
        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(worldUp, n)
        if simd_length(right) < 0.15 {
            right = simd_cross(SIMD3<Float>(1, 0, 0), n)
            if simd_length(right) < 0.15 {
                right = simd_cross(SIMD3<Float>(0, 0, 1), n)
            }
        }
        right = simd_normalize(right)
        var up = simd_normalize(simd_cross(n, right))
        if simd_dot(up, worldUp) < 0 {
            up = -up
            right = -right
        }
        return (right, up)
    }

    static func intersectPlane(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        planePoint: SIMD3<Float>,
        normal: SIMD3<Float>
    ) -> SIMD3<Float>? {
        let n = simd_normalize(normal)
        let dirLength = simd_length(direction)
        guard dirLength > 1e-6 else { return nil }
        let dir = direction / dirLength
        let denom = simd_dot(n, dir)
        if abs(denom) < 1e-5 { return nil }
        let t = simd_dot(planePoint - origin, n) / denom
        if t <= 0 { return nil }
        return origin + dir * t
    }

    /// Gravity-aligned rectangle from two opposite corners on a plane.
    static func rectangle(a: SIMD3<Float>, b: SIMD3<Float>, normal: SIMD3<Float>) -> [SIMD3<Float>] {
        let (right, up) = planeAxes(normal: normal)
        let delta = b - a
        let width = simd_dot(delta, right)
        let height = simd_dot(delta, up)
        let minR = min(Float(0), width)
        let maxR = max(Float(0), width)
        let minU = min(Float(0), height)
        let maxU = max(Float(0), height)
        let tl = a + right * minR + up * maxU
        let tr = a + right * maxR + up * maxU
        let br = a + right * maxR + up * minU
        let bl = a + right * minR + up * minU
        return [tl, tr, br, bl]
    }

    static func orderOnPlane(_ points: [SIMD3<Float>], normal: SIMD3<Float>) -> [SIMD3<Float>] {
        guard points.count == 4 else { return points }
        let (right, up) = planeAxes(normal: normal)
        let centre = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(points.count)
        return points.sorted { lhs, rhs in
            let a = lhs - centre
            let b = rhs - centre
            return atan2(simd_dot(a, up), simd_dot(a, right)) < atan2(simd_dot(b, up), simd_dot(b, right))
        }
    }

    static func measure(corners: [SIMD3<Float>], normal: SIMD3<Float>, rectangular: Bool) -> RawMeasure? {
        guard corners.count == 4 else { return nil }
        let (right, up) = planeAxes(normal: normal)
        let origin = corners[0]
        let coords: [(r: Float, u: Float)] = corners.map { point in
            let delta = point - origin
            return (simd_dot(delta, right), simd_dot(delta, up))
        }
        guard let minR = coords.map(\.r).min(),
              let maxR = coords.map(\.r).max(),
              let minU = coords.map(\.u).min(),
              let maxU = coords.map(\.u).max() else { return nil }
        let widthM = Double(maxR - minR)
        let heightM = Double(maxU - minU)
        guard widthM > 0.01, heightM > 0.01 else { return nil }

        let areaM2: Double
        let diagonalM: Double
        if rectangular {
            areaM2 = widthM * heightM
            diagonalM = hypot(widthM, heightM)
        } else {
            var sum: Float = 0
            for index in 0..<coords.count {
                let next = coords[(index + 1) % coords.count]
                let current = coords[index]
                sum += current.r * next.u - next.r * current.u
            }
            areaM2 = Double(abs(sum) * 0.5)
            let d1 = Double(simd_distance(corners[0], corners[2]))
            let d2 = Double(simd_distance(corners[1], corners[3]))
            diagonalM = max(d1, d2)
        }
        guard areaM2 > 0, diagonalM > 0 else { return nil }
        return RawMeasure(
            widthMM: widthM * 1000,
            heightMM: heightM * 1000,
            diagonalMM: diagonalM * 1000,
            areaM2: areaM2
        )
    }

    static func projectOntoPlane(point: SIMD3<Float>, planePoint: SIMD3<Float>, normal: SIMD3<Float>) -> SIMD3<Float> {
        let n = simd_normalize(normal)
        let distance = simd_dot(planePoint - point, n)
        return point + n * distance
    }
}
