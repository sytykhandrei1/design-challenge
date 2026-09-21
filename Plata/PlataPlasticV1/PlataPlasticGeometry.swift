import RealityKit
import simd

/// Metres throughout. The perimeter, front and back close a single ID-1 solid.
enum PlataPlasticGeometry {
    static let width: Float = 0.08560
    static let height: Float = 0.05398
    static let thickness: Float = 0.00076
    static let radius: Float = 0.00318

    private static func perimeter(width: Float, height: Float, radius: Float) -> [SIMD3<Float>] {
        let corners: [(Float, Float, Float)] = [
            (width / 2 - radius, height / 2 - radius, 0),
            (-width / 2 + radius, height / 2 - radius, .pi / 2),
            (-width / 2 + radius, -height / 2 + radius, .pi),
            (width / 2 - radius, -height / 2 + radius, .pi * 1.5)
        ]
        return corners.flatMap { x, y, start in
            (0...24).map { step in
                let angle = start + Float(step) / 24 * .pi / 2
                return SIMD3<Float>(x + cos(angle) * radius, y + sin(angle) * radius, 0)
            }
        }
    }

    /// Extruded rounded contour; radius is independent of the very small thickness.
    /// The two separate surface entities cap it at exactly +/- thickness / 2.
    @MainActor
    static func edge(width: Float = width, height: Float = height,
                     radius: Float = radius, thickness: Float = thickness) throws -> MeshResource {
        let boundary = perimeter(width: width, height: height, radius: radius)
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var tangents: [SIMD3<Float>] = []
        var bitangents: [SIMD3<Float>] = []
        var coordinates: [SIMD2<Float>] = []
        let total = boundary.indices.reduce(Float.zero) { $0 + simd_length(boundary[($1 + 1) % boundary.count] - boundary[$1]) }
        var distance: Float = 0
        var indices: [UInt32] = []
        for index in boundary.indices {
            let a = boundary[index]
            let b = boundary[(index + 1) % boundary.count]
            let normal = simd_normalize(SIMD3<Float>(b.y - a.y, a.x - b.x, 0))
            let base = UInt32(vertices.count)
            let length = simd_length(b - a)
            tangents += Array(repeating: simd_normalize(b - a), count: 4)
            bitangents += Array(repeating: SIMD3<Float>(0, 0, 1), count: 4)
            let u = distance / total, v = (distance + length) / total
            coordinates += [.init(u, 0), .init(v, 0), .init(v, 1), .init(u, 1)]
            distance += length
            vertices += [a + .init(0, 0, -thickness / 2), b + .init(0, 0, -thickness / 2),
                         b + .init(0, 0, thickness / 2), a + .init(0, 0, thickness / 2)]
            normals += Array(repeating: normal, count: 4)
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        var mesh = MeshDescriptor(name: "plata_plastic_v1_edge")
        mesh.positions = .init(vertices)
        mesh.normals = .init(normals)
        mesh.tangents = .init(tangents)
        mesh.bitangents = .init(bitangents)
        mesh.textureCoordinates = .init(coordinates)
        mesh.primitives = .triangles(indices)
        return try MeshResource.generate(from: [mesh])
    }
}
