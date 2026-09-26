# Repository size and card fidelity

## Scope

The September 26, 2026 cleanup only separates offline authoring artifacts from
the files needed to build the application. The repository URL is unchanged.
The pre-cleanup remote main was `7b8e9705b936f414b873973885cc4bfdd6facd2b`;
its complete file tree matched the previously reviewed `3e2b5e3` snapshot.

Tracked files before cleanup: 999,206,554 bytes. Excluded authoring files:
333 files / 869,483,331 bytes. Retained original files: 129,723,223 bytes,
plus small documentation and verification additions. These are uncompressed
file sizes, not GitHub storage, clone-transfer size or installed app size.

## Quality guarantee and verification

No renderer, Swift source, project setting, shader, mesh, resolution, texture,
lighting parameter, color profile or compression format was changed. All 37
legacy PBR build inputs remain, including both standard and zoom tiers. All
current Plastic/Metal/Digital resources remain unchanged.

`runtime-baseline-sha256.json` records the SHA-256 and byte length of the
application source/assets, project files, PBR build scripts and retained raw
resources before cleanup. Run:

```sh
python3 Scripts/verify-runtime-resources.py
```

This checks byte identity with that baseline; it is not a claim that previously
known rendering/performance issues were fixed. Future intentional edits to
application files must be reviewed before updating their baseline entries.

Validation on September 26:

- Fresh device Release build: PASS (unsigned verification build, no phone install).
- All 179 baseline source/build/resource files: SHA-256 match.
- All 74 raw resource files in the built app match the previous device Release
  bundle, with identical inventories. `Assets.car` also matches byte-for-byte.
- Plastic five-finish gallery and preview UI test: PASS.
- Digital and Metal UI tests fail identically before and after cleanup under
  the same Release simulator setup: Digital peak zoom reads 1.0 instead of >2;
  Metal selection produces the same stationary screenshot until movement;
  Metal peak zoom reads 1.0 instead of >1.5. The original unmodified project
  reproduced all three assertions. No test or interaction code was changed.
  Do not describe this run as all UI tests passing or these issues as fixed.
- After history filtering, every retained file's Git object and path were
  compared for all 13 mapped commits: PASS. Only the explicit archived paths
  were removed; retained historical application code/assets are unchanged.

## Preserved authoring material

Before cleanup, a complete Git bundle and `CardMaterials-original.tar` were
saved outside the repository. Every file extracted from the material archive
was SHA-256 checked against the original, including the 333 excluded files.
The owner retains the archive and original history; do not upload the large
archive into this repository again.

Normal Xcode builds need neither the archive nor downloads, generators, Git LFS
or extra packages. To edit/regenerate materials, obtain the archive from the
owner and extract it OUTSIDE the checkout. For the optional Plastic generator,
point `--source-root` to the extracted `CardMaterials/v1/shared/micro` directory.
Its NumPy/Pillow dependencies are authoring-only. The archived original README,
scripts, manifests, sources and verification reports document the full workflow.

## Git history

The user explicitly authorized removing only these archived authoring paths
from published main history. The old history is retained in the local backup.
Commit IDs change; existing users should make a fresh clone (preserve their own
uncommitted work first). Do not merge an old clone's main back into the cleaned
history: that can reintroduce the large objects. The unrelated historical
`claude/blissful-knuth-orvqkn` branch is not modified.

GitHub's reported storage may lag server garbage collection, and old objects
may remain accessible through cached commit/PR references. A fresh clone's
transferred objects and checked-out files are the practical verification.
