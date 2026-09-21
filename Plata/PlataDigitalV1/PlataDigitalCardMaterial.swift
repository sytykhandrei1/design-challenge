import RealityKit
import UIKit
import ImageIO

/// Standard PBR only. The smooth, non-metallic light field has no bump or baked reflection.
@MainActor
enum PlataDigitalCardMaterial {
    typealias Geometry = PlataMetalV1Geometry

    static func texture(_ image: CGImage, name: String) async throws -> TextureResource {
        try await TextureResource(image: image, withName: "plata_digital_v1/\(name)",
                                  options: .init(semantic: .color, compression: .none))
    }

    static func surface(_ skin: PlataDigitalSkin, isBack: Bool = false) async throws -> PhysicallyBasedMaterial {
        try Task.checkCancellation()
        let image = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool { try PlataDigitalArtwork.background(skin, isBack: isBack) }
        }.value
        try Task.checkCancellation()
        let map = try await texture(image, name: "\(skin.rawValue)-\(isBack ? "back" : "front")")
        var result = PhysicallyBasedMaterial()
        result.baseColor = .init(tint: .white, texture: .init(map))
        result.metallic = 0.0
        result.roughness = .init(floatLiteral: isBack ? 0.55 : 0.23)
        result.specular = .init(floatLiteral: isBack ? 0.16 : 0.32)
        result.clearcoat = .init(floatLiteral: isBack ? 0.12 : 0.40)
        result.clearcoatRoughness = .init(floatLiteral: isBack ? 0.40 : 0.22)
        // Keep the constant emission black: only the artwork contributes emitted colour.
        result.emissiveColor = .init(color: .black, texture: .init(map))
        result.emissiveIntensity = isBack ? 0.30 : 0.42
        return result
    }

    static func ink(_ image: CGImage, name: String, specular: Float = 0.2) async throws -> PhysicallyBasedMaterial {
        try Task.checkCancellation()
        let map = try await texture(image, name: name)
        let mask = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool { try PlataDigitalArtwork.opacityMask(image) }
        }.value
        try Task.checkCancellation()
        let opacity = try await TextureResource(image: mask,
            withName: "plata_digital_v1/\(name)-opacity", options: .init(semantic: .raw, compression: .none))
        var result = PhysicallyBasedMaterial()
        result.baseColor = .init(tint: .white, texture: .init(map))
        result.metallic = 0.0
        result.roughness = 0.4
        result.specular = .init(floatLiteral: specular)
        result.blending = .transparent(opacity: .init(scale: 1, texture: .init(opacity)))
        result.opacityThreshold = 0.1
        // Texture alpha also masks the emissive print; no full-card luminous rectangle.
        result.emissiveColor = .init(color: .black, texture: .init(map))
        result.emissiveIntensity = 0.20
        return result
    }

    static func edge(_ skin: PlataDigitalSkin) -> PhysicallyBasedMaterial {
        var result = PhysicallyBasedMaterial()
        result.baseColor.tint = skin.edgeColor
        result.metallic = 0.0
        result.roughness = 0.32
        result.clearcoat = 0.65
        result.clearcoatRoughness = 0.18
        return result
    }

    static func url(_ file: String, bundle: Bundle) throws -> URL {
        guard let url = bundle.url(forResource: file, withExtension: nil, subdirectory: "plata_metal_v1") else {
            throw PlataDigitalError.resource("plata_metal_v1/\(file)")
        }
        return url
    }

    static func environment(bundle: Bundle) async throws -> EnvironmentResource {
        try await PlataDigitalMaterialCache.shared.environment(bundle: bundle)
    }

    static func loadEnvironment(bundle: Bundle) async throws -> EnvironmentResource {
        let file = "plata_studio.hdr"
        let sourceURL = try url(file, bundle: bundle)
        let image = try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldAllowFloat: true] as CFDictionary) else {
                throw PlataDigitalError.resource("plata_metal_v1/\(file)")
            }
            return image
        }.value
        try Task.checkCancellation()
        return try await EnvironmentResource(equirectangular: image, withName: "plata_digital_v1/studio")
    }

    /// Rect is in top-left normalized card coordinates. Children share their parent's UV basis.
    static func graphic(_ name: String, rect: CGRect, material: PhysicallyBasedMaterial) throws -> ModelEntity {
        let w = Geometry.width * Float(rect.width), h = Geometry.height * Float(rect.height)
        let node = ModelEntity(mesh: try Geometry.surface(width: w, height: h, radius: 0), materials: [material])
        node.name = name
        node.position = [Geometry.width * Float(rect.midX - 0.5), Geometry.height * Float(0.5 - rect.midY), 0.000008]
        return node
    }

    static func makeCard() async throws -> Entity {
        let root = Entity()
        root.name = "PLATA Digital"
        let body = ModelEntity(mesh: try Geometry.edge(), materials: [edge(.amanecer)])
        body.name = "Digital body and edge"
        root.addChild(body)
        let cap = try Geometry.surface()
        let (logoInk, paymentInk) = try await PlataDigitalMaterialCache.shared.prints()
        for isBack in [false, true] {
            var neutral = PhysicallyBasedMaterial()
            neutral.baseColor.tint = .black
            let face = ModelEntity(mesh: cap, materials: [neutral])
            face.name = isBack ? "Back surface" : "Front surface"
            face.position.z = (isBack ? -1 : 1) * Geometry.thickness / 2
            if isBack { face.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) }
            root.addChild(face)
        }
        guard let front = root.findEntity(named: "Front surface") else {
            throw PlataDigitalError.rendering("Missing Front surface")
        }
        // The marks belong only to the front. Keep the official SVG aspect ratio in physical space.
        front.addChild(try graphic("PLATA wordmark", rect: PlataDigitalArtwork.logoRect, material: logoInk))
        front.addChild(try graphic("Mastercard mark", rect: CGRect(x: 0.787, y: 0.777, width: 0.161, height: 0.1595), material: paymentInk))
        return root
    }

    static func updateSkin(_ skin: PlataDigitalSkin, card: Entity) async throws {
        let appearance = try await PlataDigitalMaterialCache.shared.appearance(skin)
        try Task.checkCancellation()
        try apply(appearance, skin: skin, card: card)
    }

    static func apply(_ appearance: PlataDigitalMaterialCache.Appearance, skin: PlataDigitalSkin, card: Entity) throws {
        guard let front = card.findEntity(named: "Front surface"), let back = card.findEntity(named: "Back surface") else {
            throw PlataDigitalError.rendering("Missing Front surface or Back surface")
        }
        set(appearance.front, on: front); set(appearance.back, on: back)
        set(edge(skin), on: card.findEntity(named: "Digital body and edge"))
        if let cloud = front.findEntity(named: "Virtual card cloud") {
            set(appearance.cloud, on: cloud)
        } else {
            front.addChild(try graphic("Virtual card cloud", rect: PlataDigitalArtwork.cloudRect, material: appearance.cloud))
        }
    }

    static func set(_ material: PhysicallyBasedMaterial, on entity: Entity?) {
        guard let entity = entity as? ModelEntity, var model = entity.model else { return }
        model.materials = [material]
        entity.model = model
    }

}

/// Resources, never live ARViews/entities, survive navigation. Three complete
/// skins bound retention to the selected color and its immediate neighbors.
/// No resolution changes and no four-scene/renderer pool are involved.
@MainActor
final class PlataDigitalMaterialCache {
    static let shared = PlataDigitalMaterialCache()
    struct Appearance {
        let front: PhysicallyBasedMaterial
        let back: PhysicallyBasedMaterial
        let cloud: PhysicallyBasedMaterial
    }
    private final class Entry {
        var value: Appearance?
        var task: Task<Appearance, Error>?
    }
    private var entries: [PlataDigitalSkin: Entry] = [:]
    private var recent: [PlataDigitalSkin] = []
    private var neighborhood = Set<PlataDigitalSkin>()
    private var printTask: Task<(PhysicallyBasedMaterial, PhysicallyBasedMaterial), Error>?
    private var environmentTask: Task<EnvironmentResource, Error>?
    private var environmentBundle: URL?
    private var memoryObserver: NSObjectProtocol?
    private var printRevision = UUID()
    private var environmentRevision = UUID()

    private init() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.purge() }
        }
    }

    func cached(_ skin: PlataDigitalSkin) -> Appearance? {
        guard let value = entries[skin]?.value else { return nil }
        touch(skin)
        return value
    }

    func appearance(_ skin: PlataDigitalSkin) async throws -> Appearance {
        if let value = cached(skin) { return value }
        if let task = entries[skin]?.task {
            touch(skin)
            return try await task.value
        }
        let entry = Entry()
        entries[skin] = entry
        touch(skin)
        let task = Task { @MainActor in
            let front = try await PlataDigitalCardMaterial.surface(skin)
            try Task.checkCancellation()
            let back = try await PlataDigitalCardMaterial.surface(skin, isBack: true)
            try Task.checkCancellation()
            let cloudImage = try await Task.detached(priority: .userInitiated) {
                try autoreleasepool { try PlataDigitalArtwork.cloud(skin) }
            }.value
            let cloud = try await PlataDigitalCardMaterial.ink(cloudImage, name: "\(skin.rawValue)-cloud", specular: 0)
            try Task.checkCancellation()
            return Appearance(front: front, back: back, cloud: cloud)
        }
        entry.task = task
        do {
            let value = try await task.value
            if entries[skin] === entry { entry.value = value; entry.task = nil }
            return value
        } catch {
            if entries[skin] === entry { entries[skin] = nil; recent.removeAll { $0 == skin } }
            throw error
        }
    }

    func prints() async throws -> (PhysicallyBasedMaterial, PhysicallyBasedMaterial) {
        if let printTask { return try await printTask.value }
        let revision = UUID()
        printRevision = revision
        let task = Task { @MainActor in
            let logo = try await Task.detached(priority: .userInitiated) {
                try autoreleasepool { try PlataDigitalArtwork.logo() }
            }.value
            let logoMaterial = try await PlataDigitalCardMaterial.ink(logo, name: "logo")
            try Task.checkCancellation()
            let payment = try PlataDigitalArtwork.payment()
            let paymentMaterial = try await PlataDigitalCardMaterial.ink(payment, name: "payment")
            return (logoMaterial, paymentMaterial)
        }
        printTask = task
        do { return try await task.value }
        catch { if printRevision == revision { printTask = nil }; throw error }
    }

    func environment(bundle: Bundle) async throws -> EnvironmentResource {
        if let environmentTask, environmentBundle == bundle.bundleURL { return try await environmentTask.value }
        environmentTask?.cancel()
        let revision = UUID()
        environmentRevision = revision
        environmentBundle = bundle.bundleURL
        let task = Task { @MainActor in try await PlataDigitalCardMaterial.loadEnvironment(bundle: bundle) }
        environmentTask = task
        do { return try await task.value }
        catch { if environmentRevision == revision { environmentTask = nil }; throw error }
    }

    func prewarm(around skin: PlataDigitalSkin, includeShared: Bool = false) async throws {
        if includeShared {
            _ = try await environment(bundle: .main)
            _ = try await prints()
        }
        try Task.checkCancellation()
        _ = try await appearance(skin)
        let skins = PlataDigitalSkin.allCases
        guard let index = skins.firstIndex(of: skin) else { return }
        for neighbor in [index - 1, index + 1] where skins.indices.contains(neighbor) {
            try Task.checkCancellation()
            _ = try await appearance(skins[neighbor])
        }
    }

    func focus(on skin: PlataDigitalSkin) {
        let skins = PlataDigitalSkin.allCases
        guard let index = skins.firstIndex(of: skin) else { return }
        neighborhood = Set([index - 1, index, index + 1].filter { skins.indices.contains($0) }.map { skins[$0] })
    }

    private func touch(_ skin: PlataDigitalSkin) {
        recent.removeAll { $0 == skin }
        recent.append(skin)
        while recent.count > 3 {
            // Prefetch must not evict the other immediate neighbor just before
            // a midpoint reversal. Drop a color outside the focused window first.
            let victim = recent.firstIndex { !neighborhood.contains($0) } ?? recent.startIndex
            let oldest = recent.remove(at: victim)
            entries.removeValue(forKey: oldest)?.task?.cancel()
        }
    }

    private func purge() {
        for entry in entries.values { entry.task?.cancel() }
        entries.removeAll(); recent.removeAll()
        printRevision = UUID(); environmentRevision = UUID()
        printTask?.cancel(); printTask = nil
        environmentTask?.cancel(); environmentTask = nil
    }
}
