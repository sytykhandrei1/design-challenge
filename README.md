# Plata — iOS card ordering prototype

Open `Plata.xcodeproj`, select the shared **Plata** scheme and an iPhone simulator, then Run. Xcode 26 recommended; deployment target iOS 18. No packages or network dependencies. For a physical iPhone, select your development team under Signing & Capabilities.

The app opens directly into the card selection sheet. Swipe horizontally, tap a card to expand it, then press or drag across the metal surface. `Back to designs` reverses the transition and preserves selection. `Order for 799 ₽` intentionally performs no action.

## Design and implementation

- [Selection reference](https://www.figma.com/design/h8QUKmJIP3vX8oUHKuzaMx/Problem-Service?node-id=2007-38027)
- [Expanded reference](https://www.figma.com/design/h8QUKmJIP3vX8oUHKuzaMx/Problem-Service?node-id=2007-38138)
- SwiftUI `TabView`, native sheet and `NavigationStack`; the preview changes state in place without a navigation push.
- A continuous card view changes size, position and rotation. Title and button label use a content transition.
- Exact supplied `hola-platacard.png` and settings icon are bundled. Five slots repeat the artwork, as in Figma; no extra designs are invented. The title `Plastic card` follows Figma, although the image and requested interaction depict metal.
- The renderer combines original brushed copper with moving reflections. No added outline, ring, generated texture or idle shimmer; original colour at rest.
- A rigid plate on a central support: touch position controls torque; two damped angular springs provide inertia and release. This is an interactive approximation, not a full material/lighting simulation. A central press produces almost no angular torque.
- Updates are confined to Core Animation layers; the decoded image is shared. The display link stops when settled or offscreen. Substeps keep behaviour stable at 60/120 Hz.
- Reduce Motion shortens transitions and limits tilt. VoiceOver supports activation and carousel adjustment.
- In preview, an immediate contact recognizer takes ownership of the card gesture and interactive sheet dismissal is disabled. This prevents a downward drag from moving the entire sheet.

## Title morphing

The gear button on the account screen opens **Settings**, a bench for choosing how an animated title should change. A four-name slider (`Sand dunes`, `Classic Plata`, `Metal Plata`, `Beautiful nature`) morphs the name in place on every swipe; the segmented control picks the technique, and `Compare all three` runs all of them from the same swipe.

- **Native** — `contentTransition(.interpolate)`, exactly what the navigation title uses today. No measurement, the whole label cross-fades.
- **Diff** — the longest common subsequence of the two names is matched, so shared characters keep their identity and slide to their new position while the rest fade. `Classic Plata` → `Metal Plata` carries the whole word `Plata` across.
- **Stagger** — every character leaves upwards and the new ones arrive from below with a left-to-right delay, the model used by AnimateText. Reproduced locally rather than added as a package, so the project stays buildable with no network and no dependencies.

Character positions come from CoreText on the same system font SwiftUI draws with. `MorphStage` conforms to `Animatable`, so the spring runs on the animation system: no timer, no display link. Whitespace never pairs — it draws nothing, and matching it would spend the budget visible glyphs need. Reduce Motion drops the travel, blur and stagger and leaves a short cross-fade.

## Files

| File | Purpose |
| --- | --- |
| `Plata/PlataApp.swift` | Native shell, sheet entry and settings button |
| `Plata/CardOrderingView.swift` | Carousel and shared transition |
| `Plata/MetalCard.swift` | Touch input and material rendering |
| `Plata/CardPhysics.swift` | Angular spring integration |
| `Plata/TextMorph.swift` | Card names, technique list and the character diff |
| `Plata/MorphingTitle.swift` | Glyph measurement and the two custom engines |
| `Plata/MorphSettingsView.swift` | Settings screen: name slider and technique switch |
| `Tests/PhysicsChecks.swift` | Numerical checks |
| `Tests/MorphChecks.swift` | Character diff checks |
| `PlataUITests/CardFlowUITests.swift` | End-to-end UI test |
| `PlataUITests/MorphSettingsUITests.swift` | Settings screen UI test |
| `AGENTS.md` | User requirements and push rules |
| `STATUS.md` | Verification and handoff |

## Verification

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Plata.xcodeproj -scheme Plata -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build test
xcrun swiftc Plata/CardPhysics.swift Tests/PhysicsChecks.swift -o /tmp/plata-physics-checks
/tmp/plata-physics-checks
xcrun swiftc Plata/TextMorph.swift Tests/MorphChecks.swift -o /tmp/plata-morph-checks
/tmp/plata-morph-checks
```

The project and shared scheme are included. `Scripts/create-project.py` regenerates them without XcodeGen and overwrites the project definition; keep that script updated when adding source files or changing build settings. It lists every source explicitly, so a new file has to be added there and to `project.pbxproj` together.

## Acceptance and GitHub

Keep changes local until the user tests a build and explicitly accepts the completed stage. Then commit and push the accepted work to `main`, authenticated as `sytykhandrei1`. Local author identity uses the account's GitHub ID-based noreply address. Never force-push or overwrite another agent's work. Read `AGENTS.md` first.
