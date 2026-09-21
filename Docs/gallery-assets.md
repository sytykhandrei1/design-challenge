# Gallery refresh — Figma originals, 19 September 2026

File: HKe5nEzpNzw770zsXP9F3B. Layout and motion retrieved through Figma MCP.

| Screen | Figma frame / card | Asset | Original size | SHA-1 |
|---|---|---|---|---|
| Digital | 5228:10193 / 5228:10202 | gallery-digital.png | 1578×996 | bc77c9c8b595da96e78ccb9c134f2b155b792591 |
| Plastic | 5228:10203 / 5228:10208 | gallery-plastic.png | 1648×954 | 1ef90dd71f2b34ff1ac683d39858ef90d0126ed2 |
| Metal | 5228:10216 / 5228:10227 | gallery-metal.png | 1649×954 | 7e0b53cc4e39a2829bf2c4fce16e72a47b22a812 |

The originals are stored in gallery-*.imageset. They are immutable Figma fill images, not generated variants. Gallery layout applies the frame's 346×200 proportions and 20 pt corners. One illustration is intentionally reused across each product's finishes for this mechanics review.

gallery-plata-plus.svg is the unmodified vector from Logo / Plus (5211:19038), 24×24. The asset catalog preserves vector representation and original rendering. Do not replace it with emoji/SF Symbols.

The button glow uses the native KeyframeAnimator translation from node 5228:10237: static rect (-87,-17,80,87), radius 32, blur 45, #FF5000; linear 2-second loop. Translation keyframes: 0% (-55,1), 50.048% (444.093,3.987), 50.118% (443.079,4.788), 100% (443.079,4.788). Reduced Motion disables the glow.

Status bar, navbar, sheet and home indicator are system-owned; no mock OS chrome is embedded.
# Metal integration — 20 September 2026

The gallery now uses the unchanged `PlataMetalV1` RealityKit scene and original maps for Plata / Obsidiana. The gallery adapter is in `MetalCard.swift`; the neighboring renderer sources are not patched. Its studio lighting is retained, with a transparent viewport and front-on camera fitted to the existing artwork slot. Physical ID-1 proportions are preserved.

Metal swatches are sampled from the real gallery front renders, not the material tint multiplier: Plata `#656668`, Obsidiana `#3E3F41`. Method: median sRGB of the unengraved body rectangle x=150…280, y=350…400 on a 402×874 screen. Source captures: gallery-refinement-tests-01, gallery-metal-figma / gallery-metal-obsidiana-final. The actual reflective card varies across its surface and viewing angle; each swatch represents its middle body tone.

Plastic / Digital remain the original one-artwork-per-category Figma assets. The Metal raw maps have baked demo details; live personalization of those PBR details is not implemented by the Metal renderer.
