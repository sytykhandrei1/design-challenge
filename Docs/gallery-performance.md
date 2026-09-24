# Gallery performance / Xcode handoff

## Scope and quality

Only the main Physical/Digital galleries. The separate Metal preview entry is removed; Metal remains a material type inside Physical. No texture downsampling, geometry simplification, reduced lighting or frame-rate caps were introduced. Plastic/Metal resource trees and Plastic/Digital artwork sources were byte-compared to the pre-optimization copy and are unchanged.

Plastic caches five complete appearances, sharing three surface families and common ink meshes/maps. Warm changes synchronously commit the entire finish. A cold miss keeps the previous complete card until the requested appearance is ready; stale async results cannot replace a newer choice. Initial failures remain visible rather than being concealed. Memory warnings cancel speculative work and evict ready cache entries without releasing the displayed card; a new gallery entry permits prewarming again.

The five finishes' surface textures are estimated at 232–371 MiB including mipmaps depending on RealityKit's texture format, **before** print maps, HDR, chip, scenes and driver overhead. This is a dimensional estimate, not a measured GPU footprint. Device profiling remains essential; a simulator CPU memory metric does not describe GPU allocations.

## Reproducible diagnostics

### Preview transition follow-up (24 September, local)

Keep the full preview drawable size through the closing animation and shrink it once after completion, rather than resizing the render target with each animated layout. The hidden hit-test mesh now keeps the actual ID-1 ratio, with camera fit handling different layout slots. Pure pose/viewport changes skip material-coordinator updates. Copy visibility is independent of the card animation: it is hidden immediately and returns only after closing completes. No texture, lighting, render-resolution or animation-duration reduction.

Release simulator, identical two-iteration warm preview-entry/exit test before/after: CPU instructions4,351,556→4,080,463kI (6.2% fewer); CPU time1.336→1.361s (not an improvement); reported peak process memory91,687→90,983kB. This is a small-sample workload measurement, not iPhone GPU/FPS evidence. Hitch metrics produced no samples. Full-size initial drawable allocation still occurs on first entry; do not claim that all device hitches are eliminated from these measurements. Physical review is required.

Optional launch argument `--plata-plastic-diagnostics` logs `PlasticPerformance` counters. Without it, diagnostics are disabled. `testWarmPlasticColorsDoNotLoadOrRebuildResources` waits for all five finishes, switches through ten selections, and asserts that `coldPrepare`, `textureLoad`, `inkRasterization`, `meshBuild` and `loaderShown` do not increase. `atomicApply` must increase.

Release simulator, Xcode 27.0 (27A266a), iPhone 17 Pro / iOS 26.5. Baseline and optimized sources built separately; identical eight-drag Plastic workload, two measured iterations after warmup:

| Metric | Before | First optimized run |
|---|---:|---:|
| CPU time per eight-drag cycle | 3.612 s | 2.878 s |
| XCTest reported peak physical process memory | 147,925 kB | 99,642 kB |

These small-sample simulator measurements show about 20% lower CPU work and 33% lower reported process-memory peak in this workload. They are not device FPS, GPU memory, latency, or a zero-hitch guarantee. XCTHitchMetric returned no samples; absence of samples must not be reported as zero hitches.

Preview measurement before the final camera change: CPU 1.335 s baseline versus 1.376 s optimized, effectively no demonstrated improvement. One earlier repeat test missed a tap; a repeat with unchanged test passed. Final preview/device verification is tracked in STATUS.md. The first full-resolution render target allocation is not represented by a repeated warm metric. The iteration was stopped at the user's quota request; do not claim fully verified smoothness or publish without review.

## Building after cloning

1. Clone the complete repository and open `Plata.xcodeproj`. No third-party packages, credentials, local asset generators or network downloads are needed to run it. All renderer resources must be included in the commit; do not copy only the Swift files.
2. Use Xcode 26 or newer (final verification uses Xcode 27), shared scheme **Plata**, and iOS 18+ Simulator or iPhone. Newer system bar effects require iOS 26+; older OS uses native fallback.
3. For your own iPhone, select your own Team in Signing & Capabilities and, if required, a unique bundle identifier. Do not reuse the original developer's provisioning identity.
4. For performance review, Edit Scheme → Run → Build Configuration **Release**, disable **Debug executable**, then run on the phone. Debugger/diagnostic instrumentation and simulator timings are not representative of shipping performance.
5. Exercise all five Plastic colors in both directions, Plastic/Metal type reversals, all four Digital colors, repeated preview entry, pinch/rotate and downward dismissal. Test both cold launch and a warm gallery. Memory-pressure recovery may legitimately require a new resource preparation, but must never show an incomplete card or apply an obsolete selection.

The PBR copy build phase resolves paths relative to `SRCROOT`. Large raw `CardMaterials/v1` authoring assets are retained; only the needed runtime subset is copied into the app bundle.

Apple guidance used: [Reducing RealityKit CPU utilization](https://developer.apple.com/documentation/realitykit/reducing-cpu-utilization-in-your-realitykit-app), [RealityKit performance](https://developer.apple.com/documentation/realitykit/improving-the-performance-of-a-realitykit-app), [App responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness).
