# Current status — 21 September 2026

Latest work: [Gallery performance](#gallery-performance--21-september-2026). User explicitly authorized publishing the current checkpoint to GitHub for testing. Known issues below are not claimed fixed; older no-push notes describe historical iterations.

## GitHub review checkpoint

- Publishing current source, complete runtime/authoring assets, tests and handoff documentation to main at the user's explicit request. Build products, local simulator recordings, DerivedData and signing credentials are excluded.
- Recipient: open Plata.xcodeproj, select Plata scheme and their own signing Team. For realistic performance use Release with Debug executable off; see Docs/gallery-performance.md.
- Unsigned iPhone Release from a clean separate source/resource copy built successfully. Functional checks passed7/8; Metal stationary color refresh remains unresolved. No new device-performance result is claimed.

## Gallery performance — 21 September 2026

- User requested wrapping up due to 1% account quota remaining. Do not treat this iteration as fully verified or ready to publish. No phone installation, commit or push was performed. Recipient will build from GitHub in Xcode; publication still requires review/approval. Phone Release installation/profiling approval question has no answer yet.
- Completed: ordinary launcher has only Card preview; removed Metal preview navigation. Palette reuses UIKit buttons by slot relative to the fixed ring, animates shared colors, blur-dissolves only surplus/incoming circles (280ms, Reduce Motion fade160). Actual video frames visually checked; artifact in screen-task outputs/palette-blur-dissolve.mp4.
- Plastic owner implemented five ready full-quality appearances with shared maps/ink/geometry, synchronous atomic warm changes, stale-result cancellation and memory-pressure purge. Initial resource errors remain visible; cold miss retains the prior complete finish. Root warms Plastic/Metal concurrently. A new Physical entry re-enables speculative prewarm, never each color. Hit-test proxy geometry is cached and its unused shaders removed; camera projection is no longer recreated on every preview/gesture frame. Texture/artwork files unchanged byte-for-byte.
- Release simulator baseline versus first optimized eight-drag workload: CPU3.612→2.878s (~20% lower), XCTest peak physical process memory147925→99642kB (~33% lower). Two samples each, not device FPS/GPU footprint. Warm reuse test PASS: ten selections add no texture loads, ink rasterization, mesh construction or loaders. See Docs/gallery-performance.md for limits and Xcode handoff instructions.
- Preview metric before final camera optimization: baseline1.335s versus1.376s CPU, no demonstrated gain. One initial repeated-tap test failed; unchanged repeat PASS. Final camera change passed preview/pinch/dismiss functional tests but has not received a new performance measurement. Animation Hitches profiling is unsupported on this simulator; no zero-hitch claims. Physical-device first-entry profiling remains required.
- perf-functional01: 7/8 PASS (launcher, Digital, independent type/color rail, all five actual Plastic images/copy/prices, preview bounce/dismiss/reopen, two-finger transform return, midpoint/subtitle). Metal stationary refresh test FAIL. Plastic test hit a900s XCTest idle-notification timeout before continuing/passing; not a valid performance sample. Pure PhysicsChecks and git diff --check PASS.
- Clean separate source/resource copy /tmp/plata-portable.X4ejkH, new DerivedData /tmp/plata-portable-release-build: unsigned generic-iOS Release BUILD SUCCEEDED, work/perf-portable-release.log. No external downloads/generators needed. This is a build portability check, not a newly signed phone app. /tmp/plata-account-perf-release-build still contains the previous iteration's phone Release; do not install it claiming current changes.
- UNRESOLVED: Metal Plata→Obsidiana model/label changes but stationary pixels remain identical until movement/preview. Fresh material identity candidate FAILED (perf-metal-refresh01); once SceneEvents.Update/reapply candidate FAILED (perf-metal-refresh02). Neighbor was asked to remove both experimental hunks and leave the original Metal renderer. Preserve Plastic optimizations. Next iteration should diagnose actual scene/compositor lifecycle, not add permanent display links, epsilon movement or lower quality.
- Latest artifacts/logs live under /Users/a.sytykh/Documents/Codex/2026-09-19/mcp-pixel-perfect-1-start-flow-2/work. Builds/tests complete; video recording stopped. No scheduled/background work created.

## Preview-only mode — 21 September 2026

- Choose this design retains its existing orange label/bar but has an empty action, disabled semantics and no hit testing. A label-only ButtonStyle prevents PlainButtonStyle's automatic disabled dimming. Removed gallery showsSetup state and its navigation destination entirely. Card tapping/preview and all renderer/gesture logic are untouched. Historical setup/checkout files retained without a gallery entry.
- Replaced obsolete setup UI paths with inert-CTA checks; Plastic/Digital tests now return from preview instead of checkout. preview-only01 PASS: real coordinate taps on Plastic, Metal, Digital and within both previews have no action; card preview/back still work. preview-only02 PASS: final custom style retains #FF5000 (actual pixel assertion), disabled semantics and no navigation. git diff --check PASS. Release build PASS (preview-only-release.log), app /tmp/plata-account-perf-release-build/Build/Products/Release-iphoneos/Plata.app. No phone installation or commits.

## Preview launcher — 21 September 2026

- Replaced the runtime Account/tab-bar root with two native vertically stacked buttons: Card preview, then Metal preview. The first presents the existing type-choice sheet directly (Physical / Digital, no recipient page or in-sheet Back); dismissal then triggers the existing full-screen gallery push. The second uses the exact former Transfer destination. Native Back returns to the launcher. Existing caches/prewarm, galleries, palette crossfade, gestures, prices and renderers unchanged. Legacy Account/recipient sources/assets are retained but unreachable from the launcher.
- Updated UI-test entry helpers and replaced obsolete Account tests with current navigation coverage. preview-entry01 PASS for both gallery types/back and former Transfer demo/back. preview-entry02 PASS for root layout, direct type sheet, swipe dismissal and reopening; corrected the test to use a full 200pt gesture rather than a short swipe within the 44pt navbar. Three affected UI scenarios pass. Actual launcher/type-sheet screenshots visually reviewed; git diff --check PASS. Review artifacts: screen task outputs/preview-launcher.png and preview-type-sheet.png.
- Release device build PASS (preview-entry-release.log), app /tmp/plata-account-perf-release-build/Build/Products/Release-iphoneos/Plata.app. Final diff/plist checks PASS. No phone installation or commits. Previous stationary Metal finish refresh defect remains open and unchanged.

## Palette crossfade — 21 September 2026

- Latest request replaces palette collapse/expand with simultaneous opacity-only crossfade: 240ms easeInOut, 160ms under Reduce Motion. No translation, scaling or delayed incoming circles. The separate selection ring, colors, midpoint/haptic logic and card renderer are unchanged.
- palette-crossfade01 UI test PASS: Plastic → Metal → Plastic, stationary 48pt ring, 40pt settled circles, midpoint selection/release and haptic counters, correct title/subtitle. git diff --check PASS. Release build PASS (palette-crossfade-release.log), app at /tmp/plata-account-perf-release-build/Build/Products/Release-iphoneos/Plata.app; no phone installation or commits.
- Previously documented Metal stale-finish issue is outside this animation change and remains open.

## Carousel pricing and layout — 21 September 2026

- Read Figma 5274:41141 through MCP using design-to-code and SwiftUI skills. Reused existing native navigation/soft-edge bar, SF typography, AccentColor and original 3D renderers. New hand.tap symbol comes directly from design context; no hand-drawn asset substitutions.
- User text overrides the screenshot's sample Plata $40: Plastic Plata is Free, all other Plastic and both Metal are $40; Digital omits price. Price joins the stagger heading. All use the same orange 56pt/20pt-corner “Choose this design” CTA; removed Plus icon/black surface/glow. Finish descriptions remain exact user/spec strings.
- User explicitly chose undistorted ID-1 geometry with Figma side insets. At402pt: physical card width346, height≈218.2 (intentional difference from Figma's211), centre383.5; hint centre249, info top501, rail and bottom CTA anchors unchanged. Gallery-only Plastic order matches the new Figma: Plata/Rosé/Barro/Hueso/Cobalto. Renderer enum order and SANTIAGO artwork remain untouched.
- Shared price metadata also corrects checkout: Free Plata, $40 paid cards, no Metal subscription; express total includes the chosen issuance amount. Digital doesn't acquire a displayed card price. Existing delivery/navigation flow is unchanged.
- Validation: gallery-prices01 PASS for Digital colors/no price, type midpoint/subtitle, and setup/address/Free checkout. Plastic's five real finishes, prices, identical CTA, 28pt insets/ID-1, setup/back PASS in gallery-prices02 (122s); its first run exceeded the 120s test allowance, not a product assertion. Actual screenshots compared with Figma; approved real geometry, SANTIAGO and native OS chrome deliberately differ from the static artwork. PhysicsChecks and git diff --check PASS.
- Open pre-existing regression: Metal finish selection updates the title/material state, but the stationary gallery sometimes keeps the Plata frame until preview/movement. The actual-image assertion fails in prices01/02/03; Metal price, shared orange CTA geometry/pixels and preview assertions pass. Adapter setNeedsDisplay and same-entity anchor reattachment experiments did not resolve it and were removed. No changes to the adjacent task's renderer/materials/textures. Do not report the full suite or this rendering issue as fixed.
- Release device build PASS: gallery-prices-release.log, /tmp/plata-account-perf-release-build/Build/Products/Release-iphoneos/Plata.app. Final git diff --check and project plist validation PASS. Review captures: screen task outputs/gallery-new-plata.png and gallery-new-rose.png. No device installation requested or performed this turn; no commits/pushes.

## Main gallery performance — 20 September 2026

- Scope: Physical/Digital gallery via Plus/Me and Withdraw, not Transfer. Root retains the previously verified offscreen-renderer teardown: resource caches never retain live ARViews.
- Text: removed eager CoreText/LCS work from every MorphingTitle initializer; transition plans are created only on actual text changes and skip pairing for stagger. Canvas replaces per-glyph animated SwiftUI trees for both title/subtitle, preserving wave, blur, scale, timings and Reduce Motion. Extra raster bounds preserve moving glyphs; settled labels are native Text. Generation tokens prevent an old completion from clearing a newer transition.
- Adapter: unchanged configuration returns early; RealityKit paths no longer generate discarded placeholder bitmaps or prepare hidden SceneKit shaders. Both physical pages stay prepared while the gallery is visible, preventing midpoint reversals from destroying/rebuilding Plastic.
- Digital: artwork, opacity masks and HDR decode run off-main. Cache deduplicates in-flight requests and holds at most three complete skins, with immediate neighbors protected from eviction. Shared logo/payment/HDR resources survive navigation; memory pressure purges caches. Ready colors apply synchronously without rebuilding cloud geometry. Order-sheet time prewarms first colors. Original texture sizes, PBR parameters and geometry remain unchanged.
- Metal: with the renderer owner's permission, Coordinator.start has an opt-in resource-cache flag, default false. Main gallery clones a non-scene prototype and shares the same raw HDR resource; Account starts preparation before either gallery entry. Transfer retains its original load path, all file mappings/validation/material parameters remain intact.
- Parallel data integration: physical defaults and the old Rosé bitmap now show ALEX SMITH. DigitalDetails was removed by the adjacent task; adapter/setup/tests now use that API, and Digital setup has no name/number controls. Actual regression screenshots visually confirm both the old Plastic name replacement and clean Digital.
- Measurements: identical three-iteration simulator Debug swipe workload before/after Digital caching (`/tmp/plata-performance-metrics02.xcresult` vs `metrics03`): Digital CPU time 1.608 → 1.237 s per four reversals (~23% lower); physical 0.827 → 0.907 s (no demonstrated improvement in this run). These are not device FPS and not a full before/after baseline for the earlier text changes. XCTHitchMetric produced no hitch samples in these simulator results; do not interpret this as zero hitches. Process memory metrics exclude a trustworthy on-device GPU budget. Cache limits are structural, not a claim of zero memory cost.
- Functional: `performance-functional01` 2/2; `performance-regression01` 4/4 (all Digital colors, Digital setup/back, independent physical rail, real preview pinch/native edges); `performance-regression02` 4/4 after opt-in Metal cache (physical rail, preview pinch, setup/address/checkout, midpoint color/haptics). Final text check and Release device handoff recorded below when complete.
- Remaining validation: user review of Release on iPhone And for subjective motion/haptics and cold-entry behavior. Cold cache/memory-pressure recovery still has a real loading/error fallback; no loader was merely hidden to claim completion. No on-device frame-rate/hitch guarantee has been made.
- Final handoff: `performance-final-text` 1/1 PASS; seven distinct affected functional scenarios pass across the above runs, plus two metric workloads. PhysicsChecks/MorphChecks, git diff --check and project plist validation PASS. `performance-release-device02.log` BUILD SUCCEEDED. At the user's explicit approval, Release was installed on iPhone And / iOS 27 and launched normally with no demo/test arguments: installation UUID BB9A80E2-4B02-45BA-B420-E71E4C31F9E4, database sequence 2812, PID 1531, arm64 Mach-O UUID 218D9CC8-121D-3075-A439-66F0DEB7D9C8. Evidence: screen task work/performance-release-install.json and performance-release-launch.json, both outcome success. This replaces the previous Debug build. No commits/pushes.

## Preview white-edge correction (latest, IMG_1991.PNG)

- User's device screenshot exposed a gap in the previous QA: default preview and Account scrolling passed, but zoomed 3D still stopped at white top/bottom regions. Current fix is in CardOrderingView and our MetalCard adapter only; adjacent renderer/materials/DemoView and project registrations are unchanged.
- Apple explicitly supports bottom button containers over a scroll view via UIScrollEdgeElementContainerInteraction / SwiftUI safeAreaBar. HIG allows custom-bar edge effects and requires legibility checks for soft. Sources: https://developer.apple.com/documentation/uikit/uiscrolledgeelementcontainerinteraction and https://developer.apple.com/design/human-interface-guidelines/scroll-views . The user's conditional hide/show fallback was not needed and is not implemented.
- Gallery ScrollView now fills the native host under its bars. CTA lives in safeAreaBar(bottom), with .soft on top and bottom. Symmetric overscan (three viewport heights, defaultScrollAnchor center) provides actual content beneath both edges; without it the stationary canvas was treated as being at both content ends, producing transparency but no active edge effect. Removed local stage clipping. The central viewport keeps the original card/rail/CTA layout and the same 25%-hidden dismissal boundary.
- The renderer's square target also clipped zoomed pixels before UIKit could blur them. Quarter-turned preview now allocates at least the window diagonal × 1.04 and recalibrates its camera without changing the displayed card size; viewport size participates in layout invalidation. Both SceneKit and RealityKit use the corrected target.
- edge-underlap-tests-01: 3/3 PASS (physical colors/layout, 25% dismissal, real large pinch). Final centered-content edge-underlap-tests-02: 2/2 PASS (layout/selection and real pinch). edge-underlap-tests-03: 4/4 PASS (Digital, yaw/return, no shine/entry, two-finger return). Seven distinct affected scenarios pass; deterministic physics/drag/rail checks, git diff --check and project plist validation pass.
- Frame-by-frame video of the real 3× pinch on iOS 26.5 confirms native texture blur under the top and bottom controls, no white blocks, and exact return to the initial image. Artifact: screen task outputs/preview-soft-edges.mp4 (12 s). No synthetic zoom state or custom painted blur was used.
- Debug app and Release builds PASS. Common app (including the adjacent task's four Digital layouts) installed on iPhone And / iOS 27, installation UUID 0EA29E79-936F-48D5-AC97-837F5CB78B43. Launch currently denied because the phone is locked; unlock requested. On-device UITest build cannot sign its separate runner because no matching profile/account is available; ordinary app signing works. Do not claim visual/gesture verification on iOS 27 until device review is possible. No account/signing configuration was changed. No commit/push.

## Soft navigation edges / preview entrance (previous design-review iteration)

- Fixed selection ring is now #86898F, still 48 pt and stationary. Removed CardShine, its delayed task, state and overlay completely; preserved the independent one-shot Metal CTA glow and physical material reflections.
- Native .scrollEdgeEffectStyle(.soft, for: .top) replaces opaque toolbar overrides throughout Account, gallery/preview, setup, address, checkout, order sheets and demo navigation, including Digital details Form. Older iOS uses automatic native bar backgrounds. Static interactive screens use NavigationCanvas with a stationary native ScrollView; the gallery allows its 3D canvas to extend beneath the top bar without changing the bottom dismissal boundary. No painted navbar gradient.
- Preview entry: 720 ms non-overshooting cubic Bézier for enlargement/quarter turn, plus a single smooth 28° yaw / −12° pitch excursion in the actual SceneKit/RealityKit model. Exact identity and zero endpoint speed; no spring or oscillation. First contact cancels the excursion at its current pose. Reduce Motion skips it and uses a 160 ms transition. Existing short-downward-drag bounce, 25%-hidden release dismissal, pinch and horizontal manipulation are retained.
- Coordinated both DemoView navbar-only changes with the adjacent task. Its renderer, materials, Amanecer cloud and updated Expire/CVV details are unchanged and included in the common build. Project registration/generator untouched. No commit/push; HEAD/origin remain 07f5345.
- Deterministic physics checks cover the complete entrance arc, no rebound, exact endpoint and touch takeover, plus all prior rail/gesture tests. Morph and AccountDates checks pass. soft-edge-tests-01: 11/11 pass; soft-edge-tests-02: 7/7 pass, including 25% dismissal, midpoint events, stable Metal CTA, Digital no-carousel and the neighbor's editable Digital form. These cover 17 distinct UI scenarios. Final soft-edge-tests-03 passes 2/2 for the exact handoff source (entry/no shine and setup/address/checkout). Geometry proposals are now clamped in both gallery and NavigationCanvas. Xcode 27 still emits one non-failing SwiftUI invalid-frame warning when the setup keyboard appears; its origin is not established and should not be reported as fixed. Keyboard input, Done, address and checkout assertions all pass. Xcode's diagnostic collector also reports its pre-existing CommandLineTools simctl lookup issue after TEST SUCCEEDED; do not change global xcode-select.
- Final Debug device and Release simulator builds pass (soft-edge-device-handoff-build.log, soft-edge-release-handoff-build.log). Common Debug app installed successfully on iPhone And / iOS 27, installation UUID B4F5FE23-8428-4073-8F0D-B815F2459D63, and launched with the ordinary Account entry. This includes the adjacent task's current Amanecer. Visual motion was checked on simulator; subjective feel/haptics await user design review. git diff --check and project plist validation pass. No commit/push.
- Visual QA inspected actual intermediate Plastic/Metal frames and native soft edge under scrolled Account content. Artifacts in the screen task outputs: soft-edge-review.png and preview-rotation-review.mp4 (17 seconds, checked start/intermediate/end frames). Both are actual simulator captures, not generated mockups.

## Git

- Repository: `https://github.com/sytykhandrei1/test-task.git`
- Branch: `main`
- Baseline commit before this iteration: `07f5345 Replace pre-order screens with start flow`
- All changes listed below are local and intentionally uncommitted. Do not push until the user reviews the build and explicitly approves it.

## Gallery refinement (current, 20 September)

- User explicitly authorized moving the adjacent task's stable Metal variants into the product gallery. PlataMetalV1 sources/resources remain untouched; MetalCardSurface adapts its RealityKit scene/coordinator to the existing interaction physics, camera and clear gallery background. Plata / Obsidiana now replace the two placeholder Metal colors. Real ID-1 geometry is fitted without stretching inside the artwork slot, including preview and checkout.
- CardSelectionDrag confirms selection at a midpoint crossing in either direction. Release has no predicted or inertial selection. First 320 ms of a contact is limited to one neighboring stop; continued movement after that traverses neighbors in order. Discarded flick travel is never replayed while holding still. Pure checks cover midpoint reversal, quick full-width flicks in both directions, held continuation and type pages.
- Both title and subtitle use the same stagger engine; UIFont weight is measured/rendered consistently. Metal subtitle describes the selected real finish.
- Plastic and Metal CTA both use 56 pt height and 20 pt bottom inset. Metal glow keeps the Figma trajectory but plays once per reveal, not in a loop. Reduce Motion skips it.
- DEBUG gesture probe additionally counts actual haptic calls. CardColorPanGesture preserves the full touch-down path, including recognition slop, so 23 pt returns and 30 pt commits across the 26 pt midpoint. The real physical type stride accounts for fitted Metal width and preserves a 16 pt visible gap/neighbor peek.
- Validation: refinement-tests-01 exposed the short-pan slop bug and a native push/tab-bar assertion race (both fixed); its other 7 scenarios passed. refinement-tests-02 passed all 5 Account tests plus sheet navigation and the fixed color/haptic test, then an external Xcode update invalidated CoreSimulator during Digital. No simulator reset/global setting changes were made; only our CEAA device was booted again.
- Under the now-installed Xcode 27.0 (27A266a), refinement-tests-03 passed all 6 selected gallery tests: color flick/midpoint, Digital, real Metal/CTA, independent finish rail, preview bounce/dismiss, and type midpoint/subtitle. Final refinement-tests-05 passed 2/2 for the exact final spacing and explicit one-shot glow trigger. Frame-by-frame inspection caught and replaced a nonplaying repeating:false initializer; the trigger-based animator visibly plays once and its endpoint stays stable. No invalid-frame warning remains after clamping transient zero-size native navigation geometry.
- Final Debug test build and Release build pass; Release log gallery-refinement-handoff-release.log. Physics/rail/midpoint, Morph and AccountDates checks pass; git diff --check and project plist validation pass. HEAD and origin/main remain 07f5345dda481b1eb5d347c8bdd4fa1d515f9672. Final visual artifacts in the screen-task outputs: gallery-refinement-review.png and gallery-refinement-motion.mp4 (28 s). Physical haptic sensation still requires device review; event timing/counts are verified by tests.
- No commit/push; no phone install. Adjacent Digital corrections remain isolated.

## Digital / Physical gallery refresh (previous, 19 September)

- CardOrderKind now survives the sheet handoff: Digital pushes its own single-card screen (5228:10193); Physical and Withdraw push the two-page Plastic / Metal carousel (5228:10203 / 5228:10216). No account or demo route was removed.
- Independent 6 / 5 / 2 finish selections use native UIScrollView tracking, rubber-banding, deceleration and snapping. The black 48 pt ring is a fixed sibling view; 40 pt colored circles scroll beneath it. Native taps and VoiceOver adjustment are supported, with the existing light haptic on every actual selection change.
- Each physical type remembers its finish. Type swipes use the stationary cardGallery coordinate space and cannot be triggered by the lower rail. Horizontal Digital drags do not create a type carousel or accidentally initiate full-screen pop from the artwork.
- The reference geometry is matched at 402×874: card (28,261,346,200), ring (177,656,48,48), circles y=660, CTA (20,764,362,56), Metal CTA y=776. Title is 24 pt with stagger; descriptions/CTA use native SF subheadline/body metrics (do not double-apply the web export's optical tracking).
- Three immutable Figma fill originals and the exact vector Plata Plus logo were added under gallery-*; original hashes are verified in Docs/gallery-assets.md. As requested, one artwork per type is deliberately shared by all its finishes for this mechanics stage. The old four-card catalog/PBR resources are preserved but not pages in the new type carousel.
- Metal CTA includes the exact 2 s linear Figma glow timeline; Reduce Motion disables glow/shine. The former extra Set up card chip is removed; bottom CTA pushes the existing setup flow. This remains a prototype, not a real issuance or subscription purchase.
- Preserved preview rotation, anchored pinch/pan/twist, bounce and release at 25% hidden with light haptic. The DEBUG-only --card-gesture-probe now records actual completed-pinch peak in addition to vertical drag distance; ordinary launch/Release expose no probe. This avoids timing-dependent screenshot assertions after the 300 ms reset.
- Regression run /tmp/plata-gallery-tests-03.xcresult: 11 of 12 scenarios passed, including all routes, types, finishes, setup, 25% dismissal and rotation. The remaining assertion raced the completed pinch reset; frame-by-frame video confirmed magnification and reset. The assertion was changed to verify the actual gesture peak, not weakened to mere element existence. Final /tmp/plata-gallery-tests-04.xcresult: 4 tests, 0 failures, TEST SUCCEEDED (Digital, Physical/rail, 25% preview dismissal and pinch/reset). Together the runs cover all 12 current product scenarios; earlier failures remain as iteration history, not a single full-suite green claim.
- Deterministic rail centering/bounds/clearance, CardPhysics/25% thresholds, AccountDates and text-morph tests pass. Final Debug and Release builds pass (gallery-release-handoff.log); git diff --check and project plist validation pass. Final visual artifacts: screen task outputs/gallery-review.png and outputs/gallery-mechanics.mp4 (17 seconds), both visually checked. No commit/push; phone retains the adjacent task's reviewed-source Digital demo snapshot pending the user's update preference. Simulator does not verify the physical feel of the haptic.
- Adjacent task's final isolated Metal/Digital views and tests are untouched, including Transfer → Metal/Digital. Its Digital handoff is documented in Docs/plata-digital-v1.md. Only four gallery asset entries were added to the project generator; project.pbxproj was not regenerated.

## Previous design-review changes: root actions, sheet morph, 25% dismissal

- Removed the decorative root back button. Withdraw now pushes the existing card gallery directly; Transfer pushes PlataMetalCardDemoView, with the real native Back and no account tab bar. The DEBUG launch argument remains supported; the view itself also builds in Release.
- BankRootView selects light/dark appearance from the active Metal route, restoring light Account on return. The Metal task owns the Plata/Obsidiana renderer and its new zoom work; no unreviewed Metal variants were added to the main gallery.
- The sheet now uses a native UINavigationController and real system navbar/back. Its custom transition morphs shared SwiftUI row identities, leading-image widths, title/subtitle and chevron/Issue on the same surface in 380 ms. Reduce Motion uses a 160 ms fade without geometric movement. Original assets, colors and endpoint spacing are retained.
- Preview dismissal now measures the actual portion hidden beyond the card viewport: release at >=25% closes with the existing light haptic, while a shorter/cancelled drag bounces back. No requirement to travel half a card remains. Deterministic checks cover just below/exactly/above 25% at three viewport sizes and reject invalid values.
- Final Debug and Release builds pass. Five relevant UI tests have passed across the targeted runs: Transfer, Withdraw, both sheet choices/native back, horizontal rotation/timed return and 25% dismissal. Results: `/tmp/plata-review-v2-tests-01.xcresult` (entry tests), `/tmp/plata-review-v2-tests-04.xcresult` (final sheet/rotation), `/tmp/plata-review-v2-drag-final.xcresult` (final gesture, 1 test / 0 failures). Earlier aggregate runs retain the superseded gesture-test assertion failures, not a wholly-green suite claim.
- The gesture test derives rendered card geometry because XCUI reports the clipped accessibility container, and releases at 30% hidden (226 pt on the 402 pt simulator), below the old 50% threshold. It verifies 160 pt bounce, pinch, actual return to the selected slider, a real Set up tap → setup → Back and reopening the same preview. XCUI's approximate isHittable result was replaced by verifying that actual tap and destination.
- Deterministic threshold/physics checks pass; final `git diff --check` and project plist validation pass. Visual QA confirmed original inactive-row colors, morph intermediate frames without whole-page translation, no root Back, dark Metal chrome and return to light Account. A 13-second sheet morph recording is saved in the screen task's outputs.
- No commits/pushes; shared source ownership and device installation are coordinated with the Metal task. The simulator used here remains CEAA3; physical installation is reserved to the Metal task after the final green signal.

## Previous order-entry sheets and preview dismissal

- Account Transactions follows the device's current month: September on 19 September 2026. Demo payment is due in seven calendar days (26 September today); dates refresh every minute and on scene activation. Cleared the old simulator status-bar time override.
- Added Figma `5219:40138` recipient and `5219:40318` card-type screens in a native short sheet with native NavigationStack push/back. Exported the supplied avatar and add-person artwork at 3×; Another person stays inert.
- Both Physical and Digital complete the sheet and then push the same full-screen gallery from the account. This follows the user's explicit clarification; native gallery back returns to Account, not a hidden modal stack. Dismiss and push are sequenced through sheet onDismiss, with no arbitrary delay.
- Preview now follows one-finger downward travel. Short or cancelled gestures bounce back; release past half-card travel with the majority below the viewport closes to the slider with the same light haptic intensity 1.0. Selection is retained. Window-space direction locking isolates horizontal rotation and two-finger photo manipulation from dismissal.
- Added current-date/month/year-boundary checks, direction-lock/threshold checks and end-to-end sheet/dismissal UI coverage. The initial drag-dismiss UI test passed; the refined navigation test passed both types and inner back.
- Native iOS 26 partial-height sheets have the platform's floating outer inset and system chrome rather than Figma's edge-attached outer silhouette. The app uses original artwork and source content metrics; it does not fake native presentation with a screenshot.
- Coordinated with the adjacent Metal v1 task: separate source ownership, simulator and DerivedData. Its renderer/resources are isolated under `Plata/PlataMetalV1`; its DEBUG-only launch argument is wired without changing the product route. Project/generator edits were handed off serially; no concurrent overwrite or commit.

## Verification for order sheets / preview drag

- App builds with Xcode 26.6 / iOS 26.5 on iPhone 17 Pro (402 × 874 pt), including the isolated demo's target registration.
- Full product regression: **10 UI tests, 0 failures**, `/tmp/plata-sheets-03-tests.xcresult`. Includes account scroll/inert regions/current month, stagger, both sheet choices, native inner back and fullscreen handoff, all carousel designs, PBR zoom, rotation/timed return, pinch reset, setup/keyboard/address/checkout and drag dismissal.
- After final header alignment and shared exit haptic: **2 UI tests, 0 failures**, `/tmp/plata-sheets-final-tests.xcresult`.
- Strengthened short-drag proof: **1 UI test, 0 failures**, `/tmp/plata-drag-proof-02-tests.xcresult`. A DEBUG-only `--card-gesture-probe` exposes the last actual drag distance as an accessibility value, so a no-op drag cannot pass the bounce test. Ordinary launch and Release expose no probe value.
- Final recorded gesture run with an explicit hold before release also passes: `/tmp/plata-drag-final-tests.xcresult`, 1 test, 0 failures.
- Deterministic CardPhysics/direction-lock/threshold, AccountDates month/year-boundary and all four text-morph engine checks pass. Project plist validation and `git diff --check` pass; HEAD and origin/main remain `07f5345`.
- Final reference screenshots and a simulator video are retained in the screen task's outputs. Physical-device haptic strength has not been evaluated in Simulator.
- The separate Metal v1 task reports its build and dedicated UI test passing on iPhone 16 Pro / iOS 18.6, without touching this product flow. Details and resource hashes: `Docs/plata-metal-v1.md`.

## Account screen iteration history

- Replaced start flow with the vertically scrolling Account screen from Figma node `5219:40042` at 402 pt reference width.
- Added the balance, physical/digital card thumbnails, new-card tile, quick actions, Transactions, Credit payment, CLABE, and Acerca de. The credit-payment row also scrolls horizontally to expose the complete third option.
- Added a native TabView with the five original tab icons, including the separate trailing support tab on iOS 26. All tabs and account affordances are intentionally inert except the plus. The plus pushes the existing gallery; native back restores the account and its tab bar.
- Removed the start flow and Settings buttons. The former settings demo source remains unlinked for reference.
- Exported 17 original PNG assets at 3× through Figma MCP, including the sphere with its full shadow. Added named account color assets and documented asset provenance in `Docs/account-assets.md`.
- Switched gallery titles to stagger. Corrected visible-character ordering so whitespace cannot leave final letters partially faded after the animation.
- Replaced obsolete settings UI tests with account scrolling, inert-area and stagger coverage; updated the existing flow tests to enter through the plus.
- Preserved all pre-existing local changes, card materials and flow behavior. No commits or pushes were made.

## Previous account verification

The following section is the earlier account iteration, retained as history.

- Xcode 26.6 / iOS 26.5 / iPhone 17 Pro (402 × 874 pt): app target builds successfully.
- All six existing flow UI tests passed through the new account entry: native push/pop, all four designs, selected-card preview, PBR zoom, one-finger rotation/timed reset, pinch reset, name/keyboard, address and checkout.
- Final targeted run: 4 tests, 0 failures, `TEST SUCCEEDED` in `/tmp/plata-account-final-tests.xcresult`. This covers all 3 new AccountScreenUITests plus account → gallery → account. The initial scrolling assertion was corrected to use the visible native cell's frame and first accessibility match (the combined label and child label share the same text).
- Deterministic physics and all four text-morph engine checks pass. `git diff --check` and project plist validation pass.
- Visually reviewed top and bottom of Account, original artwork, payment clipping/scroll, all carousel designs, preview, keyboard setup, address and checkout. Screenshots for the current review are saved in the task's `outputs` folder.
- Native system chrome follows the installed iOS release; content geometry and original artwork match the supplied 402 pt frame. No physical-device validation was performed this iteration.
- Working-tree changes remain uncommitted at baseline `07f5345`; origin/main matched that commit when checked at the start of this iteration.

## Earlier work retained locally

- Added only `Plata · Brushed metal` to the app as the fourth carousel design for testing. The prepared matte/glossy plastic materials remain in the authoring pack and are not exposed or copied into the app bundle.
- Connected its physically based Base Color, Metalness, Roughness and SceneKit-adapted Normal maps, plus a separately textured rounded edge and studio environment.
- Kept a lightweight 1288 px face in the carousel. The 3K PBR set loads asynchronously only for the selected interactive card; one 6K visible face loads on demand above 1.5× zoom and is released after returning or changing sides.
- Preserved the existing live name and back-details toggles for the new design, using clean and demo PBR surfaces.
- Added a build phase that installs only the brushed-metal runtime maps from `CardMaterials/v1`; the resulting test app bundle contains 37 PBR files and is about 65 MiB before app binary/asset overhead.

- Rebuilt the card gallery for the Figma `5207-*` flow with three supplied archive assets.
- Replaced the modal gallery presentation with a native root `NavigationStack` push and native pop back.
- Added the `Sand dunes`, `Pinklovers · Metal`, and `Colors of life · Metal` states, peeking neighbors, spring paging, color selector and selected-state CTA.
- Added title updates (now stagger), light haptic per selection and a brighter one-time shine delayed until the pushed gallery is visible.
- Preview enlarges the selected design rather than a fixed card.
- Preserved SceneKit thickness, beveled edge, metal materials and orientation-dependent lighting for every design.
- One-finger interaction remains direct Y-axis rotation only.
- Two-finger interaction now behaves like inspecting a photo: anchored pinch, centroid pan and non-inverted roll; small asymmetric motion no longer creates accidental X/Y tilt. Once both fingers are released, scale and translation reset and every rotation axis returns to the visually vertical preview-entry pose in 300 ms. A remaining pinch finger cannot cancel that alignment by becoming a one-finger drag.
- Added selected-card setup with a 400 ms entrance and a 400 ms keyboard layout change.
- Added Card number and Cardholder name toggles, an enabled/disabled name input and real-time name rendering on the front texture.
- Added a generated back placeholder ready for future live card details.
- Added an explicit keyboard Done control so Continue is reachable after editing.
- Added native push navigation to active address fields and then to Order details. The address edit button returns to the address screen.
- Updated UI tests, deterministic physics checks, project generation metadata, README and AGENTS.

## Earlier verification history

- The updated application target builds successfully (`BUILD SUCCEEDED`) with the iOS simulator SDK.
- The dedicated brushed-metal UI test passes: fourth-card selection, preview of that exact card, 2× anchored zoom through the 6K path, reset to an interactive upright card, return to carousel and native push into setup.
- Gallery, preview and post-zoom screenshots were inspected: composition is correct, directional brushing remains visible and the card returns to its vertical preview pose.
- The app bundle was inspected and contains `brushed-metal` front/back/edge maps only; no plastic runtime material folder is present.
- Deterministic gesture/physics checks still pass, including one-finger Y rotation, pinch/pan/twist, zoom reset, 3-second hold and 600 ms return.
- `git diff --check` and `plutil -lint Plata.xcodeproj/project.pbxproj` pass.

- Application target builds successfully with Xcode 26/iOS 26.5 simulator runtime.
- `build-for-testing` succeeds.
- The complete Xcode UI suite passes after the metal integration: 7 tests, 0 failures (`CardFlowUITests` and `MorphSettingsUITests`).
- Deterministic physics check passes: Y-only drag, photo-like twist, anchored pinch/pan, 3-second hold and 600 ms return.
- Card flow UI coverage passes for:
  - all four carousel selections and CTA states;
  - preview of the selected third card;
  - vertical drag ignored and horizontal drag retained;
  - timed return;
  - pinch and reset;
  - setup toggle/input;
  - keyboard state;
  - address → checkout → edit address;
  - close back to start.
- Visual screenshots were inspected from xcresult for carousel, selected-card preview, keyboard state, address and checkout.

## Remaining before handoff

- Let the user review the account dates, two sheets, full-screen handoff and card drag/bounce/dismiss. Keep all work local until explicit approval; the separate RealityKit demo has its own review.
- Before product use, profile the 6K visible-side texture on a physical iPhone and convert the PNG masters to a suitable mobile GPU format. The simulator run validates behavior and visuals, not the final device memory budget.

## Useful commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Plata.xcodeproj -scheme Plata \
  -destination 'platform=iOS Simulator,id=CEAA3DA8-818F-4BF3-BEC4-0E69D2CD24A6' \
  -derivedDataPath /tmp/plata-figma-flow-build test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /tmp/plata-rotation-module-cache \
  Plata/CardPhysics.swift Tests/PhysicsChecks.swift \
  -o /tmp/plata-physics-checks
/tmp/plata-physics-checks
```
## Digital product-gallery integration (20 September 2026)

- Account → plus → Me → Digital now selects the four real Amanecer / Jacarandá / Cenote / Noche cards through the existing lower rail. No material-page carousel was added to Digital. Physical stays Plastic / Metal. The fixed #86898F ring, one-neighbor flick, held sequential selection, midpoint light haptic and stagger are retained.
- Digital subtitles come directly from PlataDigitalSkin; Metal uses PlataMetalFinish and Plastic retains the exact Rosé line in the previous specification. The specification has no final English copy for the other four Plastic finishes, and their real renderers are still in the adjacent task's review. Do not silently rename the shared Rosé placeholder as an unintegrated new material.
- DigitalDetails maps the existing CardFaceOptions so the selected skin and editable/hidden name/details survive into setup/checkout. Original artwork, materials and lighting are unchanged. ID-1 is fitted inside the gallery slot without stretching; Digital uses the actual physical height for the 25%-hidden dismissal threshold, as Metal does.
- Visual QA caught two integration issues missed by navigation-only assertions: async status layout could overwrite the gallery camera, and a retained hidden Digital ARView could leave the next instance blank in setup. With the renderer owner's explicit permission, PlataMetalV1SceneView gained fitsCardAutomatically (default true for unchanged demos). Our adapter disables it and waits for Digital build/appearance/details before calibrating. MetalCard now wraps its representable in an onAppear/onDisappear lifecycle, disposing hidden scenes after the native transition and restoring them on back. Temporary diagnostic logging and the unsuccessful opacity experiment were removed.
- tests01 passed 3 interaction scenarios; tests02 passed 3, but their visual output revealed the above issues. tests03–05 intentionally remain failed history: the new real-pixel scanline assertion detected the blank setup (0 pt vs expected 225 pt). tests06 confirmed releasing the hidden renderer fixes it. Final lifecycle tests and Release validation are recorded below after completion. No commits, pushes or phone installation from this task; the adjacent task coordinates the common install.
- Final /tmp/plata-digital-gallery-tests07.xcresult: 4/4 PASS (four skins/descriptions/rendered widths, preview zoom/dismiss and selection, direct setup + live name, Physical independent finishes, existing setup/address/checkout). /tmp/plata-digital-gallery-tests08.xcresult: 3/3 PASS (expanded setup test including native back to setup and gallery with real-pixel checks, flick/midpoint haptics, Metal strong pinch/native edges). Six unique scenarios on final app source. Xcode 27 / iOS 26.5 simulator; physical haptic feel remains device review.
- Final Release BUILD SUCCEEDED: digital-gallery-final-release.log. Physics checks, git diff --check and project plist validation pass. HEAD and origin/main remain 07f5345. Temporary diagnostic logs are removed; the existing Xcode diagnostic-collector simctl warning remains non-failing. Actual final screenshots were visually checked, including Cenote setup, Amanecer live name and all four gallery finishes. Review artifact: screen task outputs/digital-gallery-review.png. Adjacent agent receives the ready source for a common phone build/install; this task does not claim installation.
