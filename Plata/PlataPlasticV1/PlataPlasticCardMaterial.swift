import RealityKit
import UIKit
import ImageIO
import OSLog

@MainActor enum PlataPlasticCardMaterial {
    typealias Geometry = PlataMetalV1Geometry

    static func url(_ file: String, folder: String = "plata_plastic_v1", bundle: Bundle) throws -> URL {
        guard let url = bundle.url(forResource: file, withExtension: nil, subdirectory: folder) else {
            throw PlataPlasticError.resource("\(folder)/\(file)")
        }
        return url
    }
    static func load(_ file: String, semantic: TextureResource.Semantic, folder: String = "plata_plastic_v1",
                     bundle: Bundle) async throws -> TextureResource {
        let location = try url(file, folder: folder, bundle: bundle)
        do {
            try Task.checkCancellation()
            let texture = try await PlataPlasticTextureCache.shared.file(location, name: "\(folder)/\(file)", semantic: semantic)
            try Task.checkCancellation()
            return texture
        } catch is CancellationError { throw CancellationError()
        } catch { throw PlataPlasticError.resource("\(folder)/\(file): \(error.localizedDescription)") }
    }
    static func environment(bundle: Bundle) async throws -> EnvironmentResource {
        // All three collections use exactly the same raw studio HDR.
        try await PlataDigitalCardMaterial.environment(bundle: bundle)
    }
    static func surface(_ finish: PlataPlasticFinish, side: String, bundle: Bundle) async throws -> PhysicallyBasedMaterial {
        let family = try await PlataPlasticAppearanceCache.shared.family(finish.surface, bundle: bundle)
        guard let maps = family.maps[side] else { throw PlataPlasticError.rendering("Plastic surface: \(side)") }
        return surface(finish, maps: maps)
    }
    private static func surface(_ finish: PlataPlasticFinish, maps: PlataPlasticSurfaceFamily.Maps) -> PhysicallyBasedMaterial {
        let normal = maps.normal, roughness = maps.roughness
        var material = PhysicallyBasedMaterial()
        material.baseColor.tint = finish.color
        material.metallic = 0.0
        material.roughness = .init(scale: 1, texture: .init(roughness))
        material.normal = .init(texture: .init(normal))
        material.specular = 0.5
        material.clearcoat = .init(floatLiteral: finish == .cobalto ? 0.65 : 0)
        material.clearcoatRoughness = 0.12
        return material
    }
    static func solid(_ color: UIColor, roughness: Float, metallic: Float = 0) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor.tint = color
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)
        return material
    }
    static func ink(_ image: @autoclosure @escaping @MainActor () throws -> CGImage,
                    color: UIColor, name: String, finish: PlataPlasticFinish) async throws -> PhysicallyBasedMaterial {
        try Task.checkCancellation()
        let maps = try await PlataPlasticTextureCache.shared.ink(name: name, draw: image)
        try Task.checkCancellation()
        return inkMaterial(maps, color: color, finish: finish)
    }
    private static func inkMaterial(_ maps: PlataPlasticTextureCache.InkMaps,
                                    color: UIColor, finish: PlataPlasticFinish) -> PhysicallyBasedMaterial {
        var material = solid(color, roughness: finish == .cobalto ? 0.2 : (finish == .rose ? 0.46 : 0.66))
        material.baseColor = .init(tint: color, texture: .init(maps.color))
        material.blending = .transparent(opacity: .init(scale: 1, texture: .init(maps.mask)))
        material.opacityThreshold = 0.1
        material.clearcoat = .init(floatLiteral: finish == .cobalto ? 0.65 : 0)
        material.clearcoatRoughness = 0.12
        return material
    }
    static func graphic(_ name: String, rect: CGRect, material: PhysicallyBasedMaterial) throws -> ModelEntity {
        let key = "\(rect.width):\(rect.height)"
        let mesh: MeshResource
        if let cached = graphicMeshes[key] { mesh = cached }
        else {
            mesh = try Geometry.surface(width: Geometry.width * Float(rect.width), height: Geometry.height * Float(rect.height), radius: 0)
            graphicMeshes[key] = mesh
            PlataPlasticDiagnostics.record(.meshBuild)
        }
        let node = ModelEntity(mesh: mesh, materials: [material])
        node.name = name
        node.position = [Geometry.width * Float(rect.midX - 0.5), Geometry.height * Float(0.5 - rect.midY), 0.000006]
        return node
    }
    static func required(_ name: String, card: Entity) throws -> ModelEntity {
        guard let node = card.findEntity(named: name) as? ModelEntity else { throw PlataPlasticError.rendering(name) }
        return node
    }
    static func set(_ material: PhysicallyBasedMaterial, on node: ModelEntity) { node.model?.materials = [material] }

    // Seven fixed print/stripe rectangles share immutable meshes; no per-colour geometry rebuild.
    private static var graphicMeshes: [String: MeshResource] = [:]

    struct Appearance {
        let finish: PlataPlasticFinish
        let details: PlataPlasticDetails
        let front, back, edge: PhysicallyBasedMaterial
        let logo, payment, contactless, holder, credentials: PhysicallyBasedMaterial
        // Keep shared map groups alive even if the lower-level NSCache evicts a key.
        fileprivate let family: PlataPlasticSurfaceFamily
        fileprivate let inkMaps: [PlataPlasticTextureCache.InkMaps]
    }

    static var diagnosticSummary: String { PlataPlasticDiagnostics.summary }

    static func cachedAppearance(_ finish: PlataPlasticFinish, details: PlataPlasticDetails = .init(),
                                 bundle: Bundle = .main) -> Appearance? {
        PlataPlasticAppearanceCache.shared.cached(finish, details: details, bundle: bundle)
    }
    static func prepare(_ finish: PlataPlasticFinish, details: PlataPlasticDetails = .init(),
                        bundle: Bundle = .main) async throws -> Appearance {
        try await PlataPlasticAppearanceCache.shared.prepare(finish, details: details, bundle: bundle)
    }
    /// Call once on a new gallery entry, never on every selection or pressure retry.
    /// A pressure warning suppresses speculative work until this explicit lifecycle boundary.
    static func beginPrewarmingSession() {
        PlataPlasticAppearanceCache.shared.beginPrewarmingSession()
    }

    /// Order by current selection, then nearest neighbours. No scene or hidden ARView is created.
    static func prewarm(finishes: [PlataPlasticFinish] = PlataPlasticFinish.allCases,
                        details: PlataPlasticDetails = .init(), bundle: Bundle = .main) async throws {
        try await PlataPlasticAppearanceCache.shared.prewarm(finishes, details: details, bundle: bundle)
    }

    fileprivate static func buildAppearance(_ finish: PlataPlasticFinish, details: PlataPlasticDetails,
                                            bundle: Bundle) async throws -> Appearance {
        let family = try await PlataPlasticAppearanceCache.shared.family(finish.surface, bundle: bundle)
        try Task.checkCancellation()
        let cache = PlataPlasticTextureCache.shared
        let logo = try await cache.ink(name: "logo", draw: { try PlataDigitalArtwork.logo() })
        try Task.checkCancellation()
        let payment = try await cache.ink(name: "payment", draw: { try PlataDigitalArtwork.payment() })
        try Task.checkCancellation()
        let contactless = try await cache.ink(name: "contactless", draw: { try PlataPlasticArtwork.contactless() })
        try Task.checkCancellation()
        let holder = try await cache.ink(name: "name-\(details.name)", draw: { try PlataPlasticArtwork.name(details.name) })
        try Task.checkCancellation()
        let fields = [details.number, details.expiry, details.cvc, String(details.showsNumber)]
        let key = fields.map { "\($0.utf8.count):\($0)" }.joined()
        let credentials = try await cache.ink(name: "credentials-\(key)", draw: { try PlataPlasticArtwork.credentials(details) })
        try Task.checkCancellation()
        return Appearance(finish: finish, details: details,
            front: surface(finish, maps: family.maps["front"]!),
            back: surface(finish, maps: family.maps["back"]!),
            edge: surface(finish, maps: family.maps["edge"]!),
            logo: inkMaterial(logo, color: finish.inkColor, finish: finish),
            payment: inkMaterial(payment, color: .white, finish: finish),
            contactless: inkMaterial(contactless, color: finish.inkColor, finish: finish),
            holder: inkMaterial(holder, color: finish.inkColor, finish: finish),
            credentials: inkMaterial(credentials, color: finish.inkColor, finish: finish),
            family: family, inkMaps: [logo, payment, contactless, holder, credentials])
    }

    /// All validation/allocation precedes mutation. No await can split a visible finish update.
    static func apply(_ appearance: Appearance, to card: Entity) throws {
        let front = try required("Front surface", card: card)
        let back = try required("Back surface", card: card)
        let edge = try required("Plastic body and edge", card: card)
        let specs: [(Entity, String, CGRect, PhysicallyBasedMaterial, Bool)] = [
            (front, "PLATA wordmark", PlataDigitalArtwork.logoRect, appearance.logo, true),
            (front, "Mastercard mark", CGRect(x: 0.787, y: 0.777, width: 0.161, height: 0.1595), appearance.payment, true),
            (back, "Contactless mark", PlataPlasticArtwork.contactlessRect, appearance.contactless, true),
            (front, "Cardholder name", PlataPlasticArtwork.nameRect, appearance.holder, appearance.details.showsName),
            (back, "Card credentials", PlataPlasticArtwork.credentialsRect, appearance.credentials, true)
        ]
        let nodes = try specs.map { parent, name, rect, material, enabled -> (Entity, ModelEntity, PhysicallyBasedMaterial, Bool) in
            let node: ModelEntity
            if let existing = parent.findEntity(named: name) {
                guard let model = existing as? ModelEntity else { throw PlataPlasticError.rendering(name) }
                node = model
            } else { node = try graphic(name, rect: rect, material: material) }
            return (parent, node, material, enabled)
        }
        set(appearance.front, on: front); set(appearance.back, on: back); set(appearance.edge, on: edge)
        for (parent, node, material, enabled) in nodes {
            set(material, on: node); node.isEnabled = enabled
            if node.parent == nil { parent.addChild(node) }
        }
        card.name = "PLATA Plastic — \(appearance.finish.title)"
        PlataPlasticDiagnostics.record(.atomicApply, finish: appearance.finish.rawValue)
    }

    static func makeCard(bundle: Bundle) async throws -> Entity {
        let root = Entity(); root.name = "PLATA Plastic"
        let neutral = solid(.gray, roughness: 0.68)
        let edge = ModelEntity(mesh: try PlataPlasticGeometry.edge(), materials: [neutral])
        edge.name = "Plastic body and edge"; root.addChild(edge)
        let cap = try Geometry.surface()
        for isBack in [false, true] {
            let face = ModelEntity(mesh: cap, materials: [neutral])
            face.name = isBack ? "Back surface" : "Front surface"
            face.position.z = (isBack ? -1 : 1) * Geometry.thickness / 2
            if isBack { face.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) }
            root.addChild(face)
        }
        let front = try required("Front surface", card: root)
        let back = try required("Back surface", card: root)
        back.addChild(try graphic("Magnetic stripe", rect: PlataPlasticArtwork.stripeRect,
                                  material: solid(.digitalHex(0x17181B), roughness: 0.56)))
        back.addChild(try graphic("Signature panel", rect: PlataPlasticArtwork.signatureRect,
                                  material: solid(.digitalHex(0xF2EFDF), roughness: 0.84)))
        // Original Metal chip PBR maps are reused unchanged; only the chip is metallic.
        var chipMaterial = PhysicallyBasedMaterial()
        chipMaterial.baseColor = .init(texture: .init(try await load("chip_basecolor_rgba.png", semantic: .color, folder: "plata_metal_v1", bundle: bundle)))
        chipMaterial.roughness = .init(scale: 1, texture: .init(try await load("chip_roughness_rgb.png", semantic: .raw, folder: "plata_metal_v1", bundle: bundle)))
        chipMaterial.metallic = .init(scale: 1, texture: .init(try await load("chip_metalness_rgb.png", semantic: .raw, folder: "plata_metal_v1", bundle: bundle)))
        chipMaterial.normal = .init(texture: .init(try await load("chip_normal_opengl.png", semantic: .normal, folder: "plata_metal_v1", bundle: bundle)))
        let width = Geometry.width * 338 / 2048, height = Geometry.height * 240 / 1292
        let chip = ModelEntity(mesh: try Geometry.surface(width: width, height: height, radius: 0.00155), materials: [chipMaterial])
        chip.name = "Inserted chip"
        chip.position = [Geometry.width * (299 / 2048 - 0.5), Geometry.height * (0.5 - 510 / 1292), 0.000004]
        let chipEdge = ModelEntity(mesh: try Geometry.edge(width: width, height: height, radius: 0.00155, thickness: 0.00004),
                                   materials: [solid(.digitalHex(0x8B8E92), roughness: 0.3, metallic: 1)])
        chipEdge.name = "Chip edge"; chipEdge.position.z = -0.00002
        chip.addChild(chipEdge); front.addChild(chip)
        return root
    }
    static func updateSkin(_ finish: PlataPlasticFinish, card: Entity, bundle: Bundle) async throws {
        let frontMaterial = try await surface(finish, side: "front", bundle: bundle)
        let backMaterial = try await surface(finish, side: "back", bundle: bundle)
        let edgeMaterial = try await surface(finish, side: "edge", bundle: bundle)
        let logo = try await ink(PlataDigitalArtwork.logo(), color: finish.inkColor, name: "logo", finish: finish)
        let payment = try await ink(PlataDigitalArtwork.payment(), color: .white, name: "payment", finish: finish)
        let contactless = try await ink(PlataPlasticArtwork.contactless(), color: finish.inkColor, name: "contactless", finish: finish)
        try Task.checkCancellation()
        let front = try required("Front surface", card: card), back = try required("Back surface", card: card)
        set(frontMaterial, on: front); set(backMaterial, on: back)
        set(edgeMaterial, on: try required("Plastic body and edge", card: card))
        for name in ["PLATA wordmark", "Mastercard mark"] { front.findEntity(named: name)?.removeFromParent() }
        front.addChild(try graphic("PLATA wordmark", rect: PlataDigitalArtwork.logoRect, material: logo))
        front.addChild(try graphic("Mastercard mark", rect: CGRect(x: 0.787, y: 0.777, width: 0.161, height: 0.1595), material: payment))
        back.findEntity(named: "Contactless mark")?.removeFromParent()
        back.addChild(try graphic("Contactless mark", rect: PlataPlasticArtwork.contactlessRect, material: contactless))
    }
    static func updateDetails(_ details: PlataPlasticDetails, skin: PlataPlasticFinish, card: Entity) async throws {
        // Length-prefixed fields avoid collisions without including the skin:
        // ink colour/roughness are material values, not raster content.
        let fields = [details.number, details.expiry, details.cvc, String(details.showsNumber)]
        let credentialsKey = fields.map { "\($0.utf8.count):\($0)" }.joined()
        let name = try await ink(PlataPlasticArtwork.name(details.name), color: skin.inkColor, name: "name-\(details.name)", finish: skin)
        let credentials = try await ink(PlataPlasticArtwork.credentials(details), color: skin.inkColor, name: "credentials-\(credentialsKey)", finish: skin)
        try Task.checkCancellation()
        let front = try required("Front surface", card: card), back = try required("Back surface", card: card)
        front.findEntity(named: "Cardholder name")?.removeFromParent()
        let holder = try graphic("Cardholder name", rect: PlataPlasticArtwork.nameRect, material: name)
        holder.isEnabled = details.showsName; front.addChild(holder)
        back.findEntity(named: "Card credentials")?.removeFromParent()
        back.addChild(try graphic("Card credentials", rect: PlataPlasticArtwork.credentialsRect, material: credentials))
    }
}

/// Reuse immutable GPU resources, not live scenes. The artwork closures are
/// evaluated only on misses; typography, raster sizes and PBR values stay intact.
@MainActor
fileprivate final class PlataPlasticTextureCache {
    static let shared = PlataPlasticTextureCache()
    final class TextureBox {
        let value: TextureResource
        init(_ value: TextureResource) { self.value = value }
    }
    final class InkMaps {
        let color: TextureResource
        let mask: TextureResource
        init(color: TextureResource, mask: TextureResource) { self.color = color; self.mask = mask }
    }
    private final class WeakInk {
        weak var value: InkMaps?
        init(_ value: InkMaps) { self.value = value }
    }
    private var liveInks: [String: WeakInk] = [:]
    private let files = NSCache<NSURL, TextureBox>()
    private let inks = NSCache<NSString, InkMaps>()
    private var fileJobs: [URL: Task<TextureResource, Error>] = [:]
    private var inkJobs: [String: Task<InkMaps, Error>] = [:]
    private var generation = 0
    private var memoryObserver: NSObjectProtocol?

    private init() {
        // Conservative uncompressed RGBA+mipmap cost estimates. Live materials
        // retain their own resources; eviction never blanks the displayed card.
        files.countLimit = 16
        // One complete 3072px surface family plus chip/edge maps. Do not
        // retain all three large families merely to warm offscreen colours.
        files.totalCostLimit = 160 * 1024 * 1024
        inks.countLimit = 16
        inks.totalCostLimit = 64 * 1024 * 1024
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.purge() } }
    }

    func file(_ url: URL, name: String, semantic: TextureResource.Semantic) async throws -> TextureResource {
        if let cached = files.object(forKey: url as NSURL) { return cached.value }
        if let task = fileJobs[url] { return try await task.value }
        let revision = generation
        let task = Task { @MainActor in
            try Task.checkCancellation()
            PlataPlasticDiagnostics.record(.textureLoad)
            return try await TextureResource(contentsOf: url, withName: name,
                                             options: .init(semantic: semantic, compression: .none))
        }
        fileJobs[url] = task
        do {
            let value = try await task.value
            if generation == revision {
                fileJobs[url] = nil
                files.setObject(TextureBox(value), forKey: url as NSURL, cost: cost(value))
            }
            return value
        } catch {
            if generation == revision { fileJobs[url] = nil }
            throw error
        }
    }

    func ink(name: String, draw: @escaping @MainActor () throws -> CGImage) async throws -> InkMaps {
        if let live = liveInks[name]?.value { return live }
        if let cached = inks.object(forKey: name as NSString) { return cached }
        if let task = inkJobs[name] { return try await task.value }
        let revision = generation
        let task = Task { @MainActor in
            try Task.checkCancellation()
            PlataPlasticDiagnostics.record(.inkRasterization)
            let image = try draw()
            let alpha = try await Task.detached(priority: .userInitiated) {
                try autoreleasepool { try PlataDigitalArtwork.opacityMask(image) }
            }.value
            try Task.checkCancellation()
            let color = try await TextureResource(image: image, withName: "plata_plastic_v1/\(name)",
                                                  options: .init(semantic: .color, compression: .none))
            try Task.checkCancellation()
            let mask = try await TextureResource(image: alpha, withName: "plata_plastic_v1/\(name)-mask",
                                                 options: .init(semantic: .raw, compression: .none))
            return InkMaps(color: color, mask: mask)
        }
        inkJobs[name] = task
        do {
            let value = try await task.value
            if generation == revision {
                inkJobs[name] = nil
                liveInks = liveInks.filter { $0.value.value != nil }
                liveInks[name] = WeakInk(value)
                inks.setObject(value, forKey: name as NSString, cost: cost(value.color) + cost(value.mask))
            }
            return value
        } catch {
            if generation == revision { inkJobs[name] = nil }
            throw error
        }
    }

    private func cost(_ texture: TextureResource) -> Int { texture.width * texture.height * 4 * 4 / 3 }
    private func purge() {
        generation += 1
        fileJobs.values.forEach { $0.cancel() }; inkJobs.values.forEach { $0.cancel() }
        fileJobs.removeAll(); inkJobs.removeAll()
        files.removeAllObjects(); inks.removeAllObjects()
        liveInks = liveInks.filter { $0.value.value != nil }
    }
}


@MainActor fileprivate final class PlataPlasticSurfaceFamily {
    struct Maps { let normal, roughness: TextureResource }
    let maps: [String: Maps]
    init(_ maps: [String: Maps]) { self.maps = maps }
}

/// Bounded full-quality appearances. Five colours share only three substrate families
/// and one set of print maps. A cache hit performs no image decode/upload or drawing.
@MainActor private final class PlataPlasticAppearanceCache {
    static let shared = PlataPlasticAppearanceCache()
    private typealias Appearance = PlataPlasticCardMaterial.Appearance
    private final class WeakFamily {
        weak var value: PlataPlasticSurfaceFamily?
        init(_ value: PlataPlasticSurfaceFamily) { self.value = value }
    }
    // Five entries total, including custom detail versions, not five per name.
    // The five default finishes share three full-resolution families: about
    // 232 MiB with R8 roughness / 371 MiB if uploaded as RGBA8, including mipmaps.
    // Print maps, chip, HDR and live scenes are additional; these are estimates,
    // not a measurement of RealityKit's private allocation/driver overhead.
    private let limit = 5
    private var values: [String: Appearance] = [:]
    private var order: [String] = []
    private var jobs: [String: Task<Appearance, Error>] = [:]
    private var families: [String: WeakFamily] = [:]
    private var familyJobs: [String: Task<PlataPlasticSurfaceFamily, Error>] = [:]
    private var demandKey: String?
    private var generation = 0
    private var permitsPrewarm = true
    private var memoryObserver: NSObjectProtocol?

    private init() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.purge() } }
    }
    private func key(_ finish: PlataPlasticFinish, _ details: PlataPlasticDetails, _ bundle: Bundle) -> String {
        [bundle.bundleURL.path, finish.rawValue, details.name, details.number, details.expiry,
         details.cvc, String(details.showsName), String(details.showsNumber)]
            .map { "\($0.utf8.count):\($0)" }.joined()
    }
    private func touch(_ key: String) { order.removeAll { $0 == key }; order.append(key) }
    func cached(_ finish: PlataPlasticFinish, details: PlataPlasticDetails, bundle: Bundle) -> PlataPlasticCardMaterial.Appearance? {
        let key = key(finish, details, bundle); demandKey = key
        guard let value = values[key] else { return nil }
        touch(key)
        PlataPlasticDiagnostics.record(.cacheHit, finish: finish.rawValue)
        return value
    }
    func prepare(_ finish: PlataPlasticFinish, details: PlataPlasticDetails, bundle: Bundle) async throws -> PlataPlasticCardMaterial.Appearance {
        demandKey = key(finish, details, bundle)
        return try await request(finish, details: details, bundle: bundle)
    }
    private func request(_ finish: PlataPlasticFinish, details: PlataPlasticDetails, bundle: Bundle) async throws -> Appearance {
        try Task.checkCancellation()
        let key = key(finish, details, bundle)
        if let value = values[key] { touch(key); return value }
        let revision = generation
        let task: Task<Appearance, Error>
        if let existing = jobs[key] { task = existing }
        else {
            task = Task { @MainActor in
                PlataPlasticDiagnostics.record(.coldPrepare, finish: finish.rawValue)
                let value = try await PlataPlasticCardMaterial.buildAppearance(finish, details: details, bundle: bundle)
                PlataPlasticDiagnostics.record(.prepareComplete, finish: finish.rawValue)
                return value
            }
            jobs[key] = task
        }
        do {
            let value = try await task.value
            guard generation == revision else { throw CancellationError() }
            jobs[key] = nil
            values[key] = value; touch(key)
            while values.count > limit, let victim = order.first(where: { $0 != demandKey }) {
                values[victim] = nil; order.removeAll { $0 == victim }
            }
            try Task.checkCancellation()
            return value
        } catch {
            if generation == revision { jobs[key] = nil }
            throw error
        }
    }
    func family(_ surface: String, bundle: Bundle) async throws -> PlataPlasticSurfaceFamily {
        let key = bundle.bundleURL.path + "/" + surface
        if let live = families[key]?.value { return live }
        let revision = generation
        let task: Task<PlataPlasticSurfaceFamily, Error>
        if let existing = familyJobs[key] { task = existing }
        else {
            task = Task { @MainActor in
                var maps: [String: PlataPlasticSurfaceFamily.Maps] = [:]
                for side in ["front", "back", "edge"] {
                    try Task.checkCancellation()
                    let normal = try await PlataPlasticCardMaterial.load("\(surface)_\(side)_normal_opengl.png", semantic: .normal, bundle: bundle)
                    let roughness = try await PlataPlasticCardMaterial.load("\(surface)_\(side)_roughness.png", semantic: .raw, bundle: bundle)
                    maps[side] = .init(normal: normal, roughness: roughness)
                }
                return PlataPlasticSurfaceFamily(maps)
            }
            familyJobs[key] = task
        }
        do {
            let value = try await task.value
            guard generation == revision else { throw CancellationError() }
            familyJobs[key] = nil
            families = families.filter { $0.value.value != nil }
            families[key] = WeakFamily(value)
            try Task.checkCancellation()
            return value
        } catch {
            if generation == revision { familyJobs[key] = nil }
            throw error
        }
    }
    func beginPrewarmingSession() { permitsPrewarm = true }

    func prewarm(_ finishes: [PlataPlasticFinish], details: PlataPlasticDetails, bundle: Bundle) async throws {
        // Memory pressure stops speculative work for the current gallery session.
        // Demand loads still work at full quality; displayed entities retain their resources.
        guard permitsPrewarm else { return }
        var seen = Set<String>()
        let selected = finishes.filter { seen.insert($0.rawValue).inserted }.prefix(limit)
        for finish in selected {
            try Task.checkCancellation()
            guard permitsPrewarm else { return }
            _ = try await request(finish, details: details, bundle: bundle)
            await Task.yield()
        }
    }
    private func purge() {
        generation += 1; permitsPrewarm = false
        jobs.values.forEach { $0.cancel() }; familyJobs.values.forEach { $0.cancel() }
        jobs.removeAll(); familyJobs.removeAll(); values.removeAll(); order.removeAll()
        // Weak indexes cost no GPU memory and can still reuse the displayed card's maps.
        families = families.filter { $0.value.value != nil }
        PlataPlasticDiagnostics.record(.pressurePurge)
    }
}


/// Opt-in counters work in Debug and Release performance runs without adding UI.
/// Logs contain only finish IDs/counters, never holder names or credentials.
@MainActor enum PlataPlasticDiagnostics {
    enum Event: String, CaseIterable {
        case coldPrepare, prepareComplete, cacheHit, atomicApply
        case textureLoad, inkRasterization, meshBuild, loaderShown, pressurePurge
    }
    static let enabled = ProcessInfo.processInfo.arguments.contains("--plata-plastic-diagnostics")
    private static let logger = Logger(subsystem: "com.sytykhandrei.platacards", category: "PlasticPerformance")
    private static var counts: [Event: Int] = [:]
    static var summary: String {
        Event.allCases.map { "\($0.rawValue)=\(counts[$0, default: 0])" }.joined(separator: ",")
    }
    static func record(_ event: Event, finish: String = "") {
        guard enabled else { return }
        counts[event, default: 0] += 1
        logger.info("Plastic \(event.rawValue, privacy: .public) finish=\(finish, privacy: .public) \(summary, privacy: .public)")
    }
}
