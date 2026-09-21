# PLATA Plastic v1 — first design review

Target: `Plata`, iOS 18.0+, SwiftUI + non-AR RealityKit. Project source of truth is `Scripts/create-project.py`; both its file lists and the current `.xcodeproj` are updated. The generator was validated in a temporary directory, never run over the shared working tree.

Open **Account → Transfer → Plastic**. The existing Metal/Digital demo owns this collection selector. `PlataPlasticCardDemoView` also has a SwiftUI preview; Debug may launch directly with `--plata-metal-v1-demo --plata-plastic-default`. Plastic is not connected to the production gallery before design review. Its gallery integration belongs to the adjacent task.

## Agreed finishes

| Finish | sRGB substrate | Surface | Ink |
| --- | --- | --- | --- |
| Plata | #A9AAAB | Matte, nondirectional fine grain | #303238 |
| Rosé | #DC8BA5 | Satin, fine directional grain | #303238 |
| Barro | #B85339 | Matte, nondirectional fine grain | #F7F2E9 |
| Cobalto | #17369B | Gloss with clearcoat | #F7F2E9 |
| Hueso | #E9E0CE | Matte, nondirectional fine grain | #303238 |

Finish assignments and the five subtitles below were approved by the user. Exact colour values remain proposals for visual review. These are renderable plastic materials, not the previously supplied metallic-looking Rosé illustration.

## Geometry and graphic composition

One closed ID-1 object: 85.60 × 53.98 × 0.76 mm, corner radius 3.18 mm. Front/back use the established rounded surface geometry; a new edge mesh adds continuous perimeter UVs with tangent/bitangent data. The back rotates 180° around Y without negative scaling, so text remains readable. Front, back, edge, chip, print, magnetic stripe and signature panel have separate standard `PhysicallyBasedMaterial` instances.

Front: the exact official PLATA SVG path already implemented by `PlataDigitalArtwork.logo()`, a separate inserted chip, one editable holder name, one Mastercard mark. No virtual-card cloud. The PLATA source remains `Docs/plata-digital-v1-sources/01_Plata_logo_white.svg`, SHA-256 `db25252e6ed3f6cb48d9d47fae38a5bce7dc209c7ba63e5ba3c58171f00a9e89`. It is not reconstructed from text. Physical text uses SF Regular with tabular numerals, sized against Metal as the user-designated reference. It no longer reuses the former Digital holder layout. No claim is made that SF is a supplied brand font.

Back: same element set and placement anchors as the Metal v1 manifest: magnetic stripe, signature panel, adjacent security code, PAN, expiry, contactless mark. No repeated PLATA, holder or Mastercard. The short captions remain **CVV / Expire**. Contactless outline comes from the existing `CardMaterials/v1/shared/vector/nfc.svg`; literal vertices are translated/scaled without changing their outline. Mastercard reuses the existing Digital circle artwork in its own colours; it is not claimed to be a newly supplied official vector master.

Chip dimensions and position follow Metal (338 × 240 / 2048 × 1292 source layout). A 40 µm insert is seated 36 µm into the card, leaving a 4 µm lip. The four original chip maps are reused byte-for-byte from `plata_metal_v1`; contacts and insulating grooves retain their distinct metalness. Matte stripe roughness is 0.56; signature panel roughness is 0.84. Printed marks are nonmetallic, nonemissive and use separate alpha masks, with no engraved height/normal imitation.

`PlataPlasticDetails` keeps name/PAN/expiry/CVV out of the immutable artwork. Demo defaults: `SANTIAGO D FERNANDEZ`, `0000 0000 0000 0000`, `00/00`, `000`. Name and all credentials can independently be edited/hidden via the sliders button. Hidden credentials leave the physical stripe/signature panel intact. Text is rasterized at actual target resolution, not upscaled from a small bitmap.

## Runtime resources and material assembly

`Plata/PlataPlasticV1/Resources/plata_plastic_v1` is a namespaced raw folder in Target Membership / Copy Bundle Resources. It contains 18 PNGs plus an authoring manifest. No Image Sets, runtime height maps, JPEG/HEIC conversion or source-image resizing. Existing Metal PNG/HDR filenames are not changed.

For each `matte`, `satin`, `gloss`, separate `front`, `back`, `edge` maps:

- `*_normal_opengl.png`: RGB8, tangent-space OpenGL (+Y up); loaded with `.normal`, compression `.none`.
- `*_roughness.png`: R8 linear data; loaded with `.raw`, compression `.none`, scale 1.
- Front/back each 3072 × 1937; edge 4096 × 64. Technical PNGs carry no ICC, sRGB or gamma chunks.
- BaseColor is a uniform sRGB material tint, without baked highlights or grain shading. Plastic metallic is a constant **0**, including Rosé. Separate maps are unnecessary for uniform channels.
- Matte roughness 0.68 ± signal × 0.027; satin 0.40 ± signal × 0.018; gloss 0.17 ± signal × 0.008. Normal micro-height amplitudes used offline: 0.65 / 0.32 / 0.055 µm. Cobalto clearcoat 0.65, clearcoat roughness 0.12.
- Studio environment: the unchanged `plata_metal_v1/plata_studio.hdr`, decoded with ImageIO float support. Studio additionally uses a real 55-lumen PointLight at (-0.025, 0.035, 0.12) metres to make finish differences visible during rotation. Studio/Soft/Night alter actual scene lighting; the card emits no light. Reflections move with rotation.

Offline generation: `Scripts/build-plastic-materials.py` samples the existing authoring-only `CardMaterials/v1/shared/micro/{matte-plastic,brushed-metal,glossy-plastic}/height-signal.npy` in physical millimetres. It does not reuse the obsolete hand-reconstructed PLATA graphics or edit provided source textures. The source signals originated from the supplied material references; their hashes, parameters and output hashes are recorded in `manifest.json`. Rosé uses the directional height signal only, with zero metalness. The edge wraps over an integer number of repeat periods.

Authoring uses NumPy/Pillow already available in the workstation runtime; no new iOS dependency or build script is introduced. To regenerate, run this script with a Python environment containing those libraries. Height values are never bundled. All missing/unreadable texture errors include the exact namespaced filename and appear in the scene and OSLog; no silent `try?` fallback.

## Resolution and interaction

The current fitted demo card is approximately 300 pt wide on a 3× iPhone. Its maximum 3× camera zoom spans approximately 2700 physical pixels, covered by the 3072-pixel surface maps. PLATA is authored at 3264 × 544 from the exact vector; the holder at 1536 × 192; the back credential layer at 2560 × 1280. These are native rasterizations, not detail claimed from upscaling.

One finger rotates X/Y. Pinch zoom clamps to 1…3; double tap resets it. Front, Light, Back, Edge buttons provide repeatable poses. The physical bounding sphere is fitted at zoom 1, including the rounded edge. A selected finish preserves pose/zoom, and asynchronous texture updates cancel obsolete requests.

18 PNGs total about 38 MB compressed on disk. Only the selected finish is requested by the scene; RealityKit may retain uploaded resources internally. Two full-size RGBA normals + R8 roughness maps are approximately 76 MiB with mipmaps (excluding graphics, chip, environment and renderer caches). This is an estimate, not an on-device allocation profile. Texture optimisation is deferred until review.

## Validation

Build/test command (separate simulator and DerivedData from the adjacent task):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata -configuration Debug \
  -destination 'platform=iOS Simulator,id=15F004E6-333F-4583-915E-FA4AD5C593CE' \
  -derivedDataPath /tmp/plata-metal-v1-build \
  -resultBundlePath /tmp/plata-personalization-tests01.xcresult \
  -only-testing:PlataUITests/PlataPlasticV1UITests \
  -parallel-testing-enabled NO test
```

UI checks exercise all five finishes, both sides and edge, three lighting levels, 3× zoom, rotation, long holder name and hiding credentials. Vision checks actual rendered back text, not an accessibility mirror of the model. Full-frame OCR supplies orientation context; observations outside the scene (including numeric status-bar indicators) are excluded.

Source membership and resources match the generator's isolated output: 24 app Swift sources, 5 UI-test sources, 3 resource entries. All 18 technical PNG hashes match the built simulator bundle exactly. Original 13 Metal PNG/HDR files and the official PLATA SVG remain unchanged. The later ALEX SMITH change adds separate derived Metal front maps; see `plata-card-personalization.md`.

Initial two Plastic UI tests passed in tests03. A later Xcode project migration enabled script sandboxing; exact inputs/outputs for the existing legacy PBR copy phase now live in `Scripts/pbr-inputs.xcfilelist` and `pbr-outputs.xcfilelist`. Sandbox remains enabled. Both the current project and generator use the lists. A test restart was needed after the isolated simulator lost its connection UUID; other simulators were not reset. No commits or pushes before user design review.


## Typography alignment — 20 September 2026

The user explicitly designated **Metal as the size reference**. Neither Metal renderer nor any Metal textures were changed in this iteration. All five Plastic finishes share one name and one credentials renderer, so tint/finish changes cannot change the type size.

The previous Plastic holder was 39.46% larger than Metal at equal physical card width: `44 / 600 × 0.65` versus `70 / 2048`. Plastic now uses SF Regular `70 / 2048` and tracking `2 / 2048`, correctly converted into the cropped 600-unit name canvas. `ALEX SMITH` does not trigger auto-fit; fitting remains available for long custom names. The glyph layer remains 1536 × 192; no texture was resized.

Metal's back is supplied as baked PBR maps, with no source font metadata. Therefore its numeric point sizes cannot honestly be recovered. Visible glyph heights were measured directly from `back_roughness_rgb.png` (2048 × 1292); glyph coverage threshold 90–100 consistently separates the 109 engraving from the substrate. Plastic uses CoreText glyph-path metrics to match those heights in the same card coordinate system:

| Role | Metal reference glyph height | Plastic target |
| --- | ---: | ---: |
| PAN digit 0 | 57 px | 57 px |
| Security caption CVC / CVV | 28 px | 28 px |
| Security value digit 0 | 42 px | 42 px |
| Expiry caption capitals | 23 px | 23 px |
| Expiry value digit 0 | 46 px | 46 px |

These are glyph heights, not font point sizes. Plastic keeps the accepted short captions `CVV` and `Expire`; lowercase shapes/descenders naturally differ from Metal's `CVC` and `VALID THRU`. Position anchors, material properties, resolution and credentials remain unchanged. Engraved highlights on Metal and flat print on Plastic naturally produce different contrast.

The former gallery Rosé bitmap has a third, smaller holder size. It is being replaced by the adjacent task with this real Plastic renderer following READY, rather than modifying the soon-to-be-replaced bitmap. Do not claim the installed phone or main gallery has been updated by this typography-only step.

Final user-provided subtitles, also used by the demo and gallery through `PlataPlasticFinish.subtitle`:

- Plata—matte grey, quiet and clean
- Rosé—brushed finish, catches the light
- Barro—burnt terracotta, warm and matte
- Cobalto—deep talavera blue
- Hueso—bone white, soft matte

Validation: Debug build passed on simulator `15F004E6-333F-4583-915E-FA4AD5C593CE` with DerivedData `/tmp/plata-metal-v1-build`. Both Metal UI tests and Plastic zoom/personalization passed in `/tmp/plata-typography-tests01.xcresult`. The initial fit-scale Vision pass missed the deliberately small CVV caption on Plata and Rosé; actual screenshots showed it present. The existing test now checks the caption at real 2× camera zoom, while checking PAN and expiry at fit scale. All five finishes then passed in `/tmp/plata-typography-tests02.xcresult`, including front/back, three lighting conditions and CVV close-ups. This is not bitmap upscaling or removal of the assertion.

Command for the successful rerun:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata -configuration Debug \
  -destination 'platform=iOS Simulator,id=15F004E6-333F-4583-915E-FA4AD5C593CE' \
  -derivedDataPath /tmp/plata-metal-v1-build \
  -resultBundlePath /tmp/plata-typography-tests02.xcresult \
  -only-testing:PlataUITests/PlataPlasticV1UITests/testFiveFinishesBackAndLighting \
  -parallel-testing-enabled NO test
```

Screenshots: `/Users/a.sytykh/Documents/ChatGPT/TT/Artifacts/plata-typography-review` and `plata-typography-review-final`. `git diff --check` passed. READY handed to the adjacent gallery task with API, finish order and approved subtitles. Its subsequent bounded material cache and main-gallery integration require its own final build/flow checks. No commit or phone installation in this iteration.
