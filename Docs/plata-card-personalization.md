# Card data revision — 20 September 2026

Current holder, 21 September: **SANTIAGO D FERNANDEZ** on both Metal and all five Plastic cards, including physical setup defaults. Digital remains without holder/credentials. Only the name changed: SF Regular 70 / 2048, tracking 2, baseline and all material parameters are retained. Metal changed pixels lie within x75…917 / y1103…1160; all other original resources are byte-identical. Existing `front_alex_smith_*` filenames are legacy resource keys retained to avoid unrelated bundle/configuration changes; the manifest records the current holder. The earlier ALEX SMITH report below is historical.

Latest user decision supersedes previous demo-data decisions:

- All physical cards show **ALEX SMITH** instead of CARD HOLDER.
- All four Digital cards have **no holder, PAN, expiry, CVV or placeholder for hidden data**. Their front retains the official PLATA wordmark, cloud and Mastercard; their back retains only its palette artwork.
- Digital data layers, `PlataDigitalDetails`, update tasks and the demo editor are removed. The adjacent gallery task removed Digital personalisation controls and adopted the new API. The physical holder field defaults to ALEX SMITH.

## Metal engraving

The source Metal package contains CARD HOLDER in its four front maps. The originals stay unchanged. Four derived files live beside them in the existing raw `plata_metal_v1` bundle folder:

- `front_alex_smith_basecolor.png`
- `front_alex_smith_roughness_rgb.png`
- `front_alex_smith_metalness_rgb.png`
- `front_alex_smith_normal_opengl.png`

Both Plata and Obsidiana load these instead of the original four front maps. Back, chip, HDR and all other artwork retain their previous pixels. Resolution is still 2048×1292. Changed bounds are x56…679, y1080…1183; generation asserts pixel identity outside this rectangle for every channel. Original text occupied x87…611, y1104…1157. Bare metal microtexture on the same rows supplies the cleared region, feathered outside the letters. No black overlay or extra geometry imitates the name.

`Scripts/render-metal-holder.swift` renders one native SF Regular 70 px mask with 2 px tracking and baseline y1157. `Scripts/build-metal-holder.py` uses this one coverage mask for every channel: a 40 µm recessed normal field (same depth as the original small-engraving specification), roughness 0.43, subtle 2.5% base-colour modulation, and the clean substrate metalness. Normals remain tangent-space OpenGL +Y up. BaseColor has an sRGB profile; technical maps have none. `alex_smith_manifest.json` records source/output hashes and authoring parameters. Runtime needs no height map or new dependency.

Authoring command (NumPy and Pillow only in the workstation's existing Python runtime):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  -module-cache-path /tmp/plata-metal-holder-module-cache \
  Scripts/render-metal-holder.swift /tmp/plata-alex-smith-mask.png
python3 Scripts/build-metal-holder.py \
  --resources Plata/PlataMetalV1/Resources/plata_metal_v1 \
  --mask /tmp/plata-alex-smith-mask.png --output /tmp/plata-alex-smith-maps
```

## Plastic

All five styles use `PlataPlasticDetails.name = "ALEX SMITH"` with their existing native print layer. The name can still be edited or hidden on physical cards. Back credentials stay demo values and do not duplicate the holder. See `plata-plastic-v1.md` for geometry, raw resources and material parameters.

## Validation / device state

The signed common build with Plastic before the name/data revision succeeded in `/tmp/plata-plastic-phone-final03.log` and installed on iPhone And as installation `8A75E1A4-67E4-4B54-8B6E-33E0B41D840F`, database UUID `2DCF8228-9C96-40FC-A63B-4ED79554262E`. Installation had already completed when the adjacent task relayed the user's manual-launch stop instruction. No automatic app launch was performed. **That installed version predates this name/data revision; do not claim the new data changes are on the phone.** Do not reinstall without a new user request.

Simulator checks for this revision run all three collection UI suites, covering resource loading, sides, text absence/presence, light, zoom, rotation and editable physical layers. The Digital tests check actual rendered text with Vision and assert the clean back has no readable text. Code and assets remain uncommitted pending design review.

Final data-change verification: **TEST SUCCEEDED**, all 6 tests, 0 failures, Xcode 27.0 / iPhone 16 Pro iOS 18.6. Both Metal finishes were visually inspected with ALEX SMITH; the original roughness/tint difference remains. All five Plastic fronts passed rendered-name OCR; all four Digital backs passed the empty-text check. 81 unaltered review screenshots: `/Users/a.sytykh/Documents/ChatGPT/TT/Artifacts/plata-personalization-review`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata -configuration Debug \
  -destination 'platform=iOS Simulator,id=15F004E6-333F-4583-915E-FA4AD5C593CE' \
  -derivedDataPath /tmp/plata-metal-v1-build \
  -resultBundlePath /tmp/plata-personalization-tests01.xcresult \
  -only-testing:PlataUITests/PlataMetalV1UITests \
  -only-testing:PlataUITests/PlataDigitalV1UITests \
  -only-testing:PlataUITests/PlataPlasticV1UITests \
  -parallel-testing-enabled NO test
```

Files added for the Plastic implementation: five Swift sources in `Plata/PlataPlasticV1`, 18 PNGs and manifest in its raw resource subfolder, `PlataPlasticV1UITests.swift`, `build-plastic-materials.py`, and this collection's documentation. Modified registration files: `Scripts/create-project.py`, `Plata.xcodeproj/project.pbxproj`; the existing Metal demo receives the Plastic selector. Legacy PBR build input/output lists were added because an external Xcode migration enabled script sandboxing during verification.

Files changed for the data revision: four existing Digital Swift files and its UI test, Plastic Artwork/default and its UI test, Metal CardView resource selection, shared gallery/setup files by the adjacent task. Added the four derived Metal front PNGs, `alex_smith_manifest.json`, `render-metal-holder.swift`, `build-metal-holder.py`, and updated collection documentation. No supplied image is overwritten. Full resource names were not shortened or globally renamed.

## Subsequent authorised Release installation

The user later explicitly authorised the adjacent task to install and launch the current Release. It completed successfully: installation UUID `BB9A80E2-4B02-45BA-B420-E71E4C31F9E4`, sequence 2812, PID 1531, Mach-O UUID `218D9CC8-121D-3075-A439-66F0DEB7D9C8`. This Release includes ALEX SMITH, clean Digital, five Plastic demo finishes and the adjacent task's gallery performance changes. Evidence: `work/performance-release-install.json`, `performance-release-launch.json` and `performance-release-device02.log` under `/Users/a.sytykh/Documents/Codex/2026-09-19/mcp-pixel-perfect-1-start-flow-2`. The prior device-state note above describes the earlier installation only.
