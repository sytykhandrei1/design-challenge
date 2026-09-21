import RealityKit
import simd

/// Metres throughout. The perimeter, front and back close a single ID-1 solid.
enum PlataMetalV1Geometry {
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

    @MainActor
    static func surface(width: Float = width, height: Float = height,
                        radius: Float = radius) throws -> MeshResource {
        let boundary = perimeter(width: width, height: height, radius: radius)
        let vertices = [SIMD3<Float>.zero] + boundary
        var mesh = MeshDescriptor(name: "plata_metal_v1_surface")
        mesh.positions = .init(vertices)
        mesh.normals = .init(Array(repeating: SIMD3<Float>(0, 0, 1), count: vertices.count))
        mesh.tangents = .init(Array(repeating: SIMD3<Float>(1, 0, 0), count: vertices.count))
        mesh.bitangents = .init(Array(repeating: SIMD3<Float>(0, 1, 0), count: vertices.count))
        // RealityKit texture UV origin is bottom-left; ImageIO handles source image rows.
        mesh.textureCoordinates = .init(vertices.map { .init($0.x / width + 0.5, $0.y / height + 0.5) })
        var indices: [UInt32] = []
        for index in boundary.indices {
            let current = UInt32(index + 1)
            let next = UInt32((index + 1) % boundary.count + 1)
            indices.append(contentsOf: [0, current, next])
        }
        mesh.primitives = .triangles(indices)
        return try MeshResource.generate(from: [mesh])
    }

    /// Extruded rounded contour; radius is independent of the very small thickness.
    /// The two separate surface entities cap it at exactly +/- thickness / 2.
    @MainActor
    static func edge(width: Float = width, height: Float = height,
                     radius: Float = radius, thickness: Float = thickness) throws -> MeshResource {
        let boundary = perimeter(width: width, height: height, radius: radius)
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for index in boundary.indices {
            let a = boundary[index]
            let b = boundary[(index + 1) % boundary.count]
            let normal = simd_normalize(SIMD3<Float>(b.y - a.y, a.x - b.x, 0))
            let base = UInt32(vertices.count)
            vertices += [a + .init(0, 0, -thickness / 2), b + .init(0, 0, -thickness / 2),
                         b + .init(0, 0, thickness / 2), a + .init(0, 0, thickness / 2)]
            normals += Array(repeating: normal, count: 4)
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        var mesh = MeshDescriptor(name: "plata_metal_v1_edge")
        mesh.positions = .init(vertices)
        mesh.normals = .init(normals)
        mesh.primitives = .triangles(indices)
        return try MeshResource.generate(from: [mesh])
    }
}
