# Plata — iOS card ordering prototype

Open `Plata.xcodeproj`, select the shared **Plata** scheme and an iPhone simulator, then Run. Xcode 26 recommended; deployment target iOS 18. No packages or network dependencies. For a physical iPhone, select your development team under Signing & Capabilities.

The app opens directly into the card selection sheet. Swipe horizontally and tap a card to expand it. One-finger movement rotates it only left or right around the screen's Y axis; vertical movement is ignored. With two fingers, zoom and freely rotate around X, Y and Z at the same time, including turning the vertical card horizontal. The card holds its released orientation for three seconds and returns smoothly to the front in 600 ms; a new touch interrupts that return without a jump. The magnified area remains under the two-finger centroid and returns to 100% after release. `Back to designs` reverses the transition and preserves selection. `Order for 799 ₽` intentionally performs no action.

## Design and implementation

- [Selection reference](https://www.figma.com/design/h8QUKmJIP3vX8oUHKuzaMx/Problem-Service?node-id=2007-38027)
- [Expanded reference](https://www.figma.com/design/h8QUKmJIP3vX8oUHKuzaMx/Problem-Service?node-id=2007-38138)
- SwiftUI `TabView`, native sheet and `NavigationStack`; the preview changes state in place without a navigation push.
- A continuous card view changes size, position and rotation. Title and button label use a content transition.
- The supplied `hola-platacard.png` front artwork is unchanged. Five slots repeat that artwork, as in Figma. The title `Plastic card` follows Figma, although the image and requested interaction depict metal.
- The new `hola-platacard-back` asset supplies the reverse: brushed copper, a magnetic stripe, small PLATA branding and dunes. Its generation prompt is preserved in [`Docs/backside-prompt.md`](Docs/backside-prompt.md).
- SceneKit renders a closed solid with rounded corners, bevels and a visible material edge. Separate front, back and edge materials share the same geometry. Model thickness is 0.9 relative to a width of 100. Surface brushing and orientation-dependent lighting convey metal without adding an outline or ring. This is a visual material approximation, not a full physical simulation.
- `CardPhysics` keeps quaternion orientation. With one finger it applies only screen-horizontal movement to unbounded yaw; vertical movement cannot tilt the card. With two fingers, centroid movement controls pitch/yaw while finger-line twist controls roll, so zoom and free rotation remain simultaneous. Release schedules a testable 3-second hold followed by a 600 ms shortest-path return to the front. Regrabbing cancels the return at its currently visible orientation.
- `CardZoom` scales the 3D card from 1× to 3× around the surface point under the two-finger centroid. The node translates in world space using the live quaternion, so the same off-centre point remains under the fingers while the card rotates and scales. Releasing returns scale and translation to the original state in 300 ms.
- The selected card's renderer is prepared before interaction; carousel neighbours use the static front artwork, and decoded front/back images are shared. Scene rendering is requested when orientation changes, without a continuous idle animation.
- Reduce Motion shortens the existing expansion transition. VoiceOver supports activation and carousel adjustment; accessibility and small-screen behaviour must be checked for each interaction revision.
- In preview, one immediate multi-touch UIKit recognizer owns both rotation and scaling, including one-to-two-to-one finger transitions. Interactive sheet dismissal is disabled there.

## Title morphing

The gear button on the account screen opens **Settings**, a bench for choosing how an animated title should change. A four-name slider (`Sand dunes`, `Classic Plata`, `Metal Plata`, `Beautiful nature`) morphs the name in place on every swipe; the chip row picks the technique.

Four techniques are offered, each modelled on an open-source project and reproduced locally rather than added as a package, so the project stays buildable with no network and no dependencies:

| Technique | Modelled on | What it does |
| --- | --- | --- |
| Diff | textmorph-ios | Shared characters keep their identity and slide to the new position; only the rest fade |
| Stagger | AnimateText | Characters leave upwards and arrive from below, one after another |
| Shapeshift | ZCAnimatedLabel | Characters balloon outwards as they leave and shrink in from oversize as they arrive |
| Blur | SwiftUI-Text-Animation-Library | Pure defocus: the old name blurs out while the new one sharpens up |

A native option using `contentTransition(.interpolate)` was offered and removed: on a `Text` whose whole string changes it produced no visible animation, which also means the navigation title in `CardOrderingView` is not currently animating either.

Every technique is written as a `GlyphAppearance` over a local progress from 0 to 1, so a new one is arithmetic rather than new drawing code. Character positions come from CoreText on the same system font SwiftUI draws with. `MorphStage` conforms to `Animatable`, so the spring runs on the animation system: no timer, no display link. Whitespace never pairs — it draws nothing, and matching it would spend the budget visible glyphs need, which is how `Classic Plata` → `Metal Plata` carries the whole word `Plata` across. Reduce Motion drops every moving part and leaves a cross-fade.

Scale, Evaporate, Fall, Reveal, Spin, Roulette and Shrink were built and then dropped at the user's request; they are in the history of this branch if any of them is wanted back. Never built: the particle effects of LTMorphingLabel (`sparkle`, `burn`, `anvil`, `pixelate`), which need `CAEmitterLayer`, and the Metal shader effects of SwiftMotion (`liquid`, `glitch`, `wave`), which need a `.metal` file in the target and a different pipeline.

## Files

| File | Purpose |
| --- | --- |
| `Plata/PlataApp.swift` | Native shell, sheet entry and settings button |
| `Plata/CardOrderingView.swift` | Carousel and shared transition |
| `Plata/MetalCard.swift` | Immediate touch input, SceneKit solid geometry and materials |
| `Plata/CardPhysics.swift` | Direct quaternion rotation and gesture lifecycle |
| `Plata/Assets.xcassets/hola-platacard-back.imageset/` | Generated copper reverse artwork |
| `Docs/backside-prompt.md` | Reusable prompt and constraints for the reverse artwork |
| `Plata/TextMorph.swift` | Card names, the four engines and the character diff |
| `Plata/MorphingTitle.swift` | Glyph measurement and the animated stage |
| `Plata/MorphSettingsView.swift` | Settings screen: name slider and technique chips |
| `Tests/PhysicsChecks.swift` | Numerical gesture and rotation checks |
| `Tests/MorphChecks.swift` | Character diff and engine rest-state checks |
| `PlataUITests/CardFlowUITests.swift` | End-to-end UI test |
| `PlataUITests/MorphSettingsUITests.swift` | Settings screen UI test |
| `AGENTS.md` | User requirements and push rules |
| `STATUS.md` | Verification and handoff |

## Verification

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Plata.xcodeproj -scheme Plata -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build test
xcrun swiftc -module-cache-path /tmp/plata-rotation-module-cache Plata/CardPhysics.swift Tests/PhysicsChecks.swift -o /tmp/plata-physics-checks
/tmp/plata-physics-checks
xcrun swiftc Plata/TextMorph.swift Tests/MorphChecks.swift -o /tmp/plata-morph-checks
/tmp/plata-morph-checks
```

Numerical checks cover one-finger horizontal-only rotation, two-finger pitch/yaw/roll, horizontal card layout, combined anchored zoom and rotation, the exact 3-second deadline and 600 ms return, interrupted returns, regrabbing, full turns, event-frequency consistency, the 3× zoom limit and return to 100%. UI checks cover the native flow, Y-axis rotation, timed return and the combined two-finger transform. See `STATUS.md` for the latest actual results. Simulator tests do not establish physical-device frame rate or subjective feel.

The project and shared scheme are included. `Scripts/create-project.py` regenerates them without XcodeGen and overwrites the project definition; keep that script updated when adding source files or changing build settings. It lists every source explicitly, so a new file has to be added there and to `project.pbxproj` together.

## Acceptance and GitHub

Keep changes local until the user tests a build and explicitly accepts the completed stage. Then commit and push the accepted work to `main`, authenticated as `sytykhandrei1`. Local author identity uses the account's GitHub ID-based noreply address. Never force-push or overwrite another agent's work. Read `AGENTS.md` first.
