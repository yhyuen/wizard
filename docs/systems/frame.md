# The frame: boot, game flow, HUD, input, sound, checks (as built)

*Detail: the root [README.md](../../README.md) ('Playing', 'Controls', 'Checks', 'Play it').
Design: GDD 03 §controls, 06 (UI, platform). Tracker: C-4 (controls), V-2 (web performance),
M0-1 (these specs and the spec check).*

## Boot and the game flow

- `scenes/main.tscn` runs `scripts/main.gd`: the arena (the sim, [combat.md](combat.md)), the 3D
  view (`scripts/world/world_view.gd`, [art.md](art.md)), the HUD at 960×540 and the game flow
  (`scripts/game/slice.gd`) on top. Modes: title, world (walking a map), fight, cutscene, slice
  (loading card, death).
- Autoloads (`project.godot`): `InputSetup`, `Progression` ([growth.md](growth.md)), `Run`
  ([loop.md](loop.md)), `Sfx`.
- `slice.gd` screens: title, world (with the dialogue panel, map M, spellbook, Ledger L over it),
  loading (the card between maps), death. First-loop hints show until done once. The title and
  death screens have **Copy run summary** and **Feedback form** (the playtest notes artifact).
- **Input** becomes an intent dictionary each physics frame (`scripts/controls.gd`), so tests and
  F2 autoplay drive the same code. Schemes: Classic (WASD), League (right-click move/attack, QWERDF)
  and League smart cast; Tab cycles any time; kept in `user://settings.cfg`. `scripts/autoload/input_setup.gd`
  registers the actions in code.
- **Graphics:** the 3D renders at most 1280 px wide; below 40 fps for 4 s graphics drop to low
  (F4 toggles, low draws the 3D at 3/4 size); kept in `user://settings.json`. F8 mutes.

## HUD and UI

- `scripts/hud.gd`: the Star Atlas HUD (spellbook constellation, Magick diamond or Ward, Vitality
  and Aether lines, field-object caps, Cadence stars, the 28-moon row, the duelist's plate,
  toasts, milestone picker, Orrery menu). Shapes are drawn as one triangle batch
  (`scripts/ui/tris.gd`); panels and buttons come from `scripts/ui/atlas.gd`.
- `scripts/autoload/sfx.gd` plays the synthesised sounds (`tools/sfx/make_sfx.py` → `assets/sfx/`).
- `scripts/game/build_id.gd` says which build this is; CI writes it before the web export.

## Checks before merging

CI (`.github/workflows/ci.yml`) runs on every PR and push to `main`, and publishes `main` to
GitHub Pages. In order:

- `python3 tools/ci/spec_check.py`: the spec rule ([README.md](README.md)).
- `tools/ci/godot.sh` (fails on any script error) with `tools/tests/unit.gd`, `story_lint.gd`,
  `route.gd`, `relearn.gd`, `deaths.gd`, `encounters.gd`, `world_magic.gd` (the fight tests with
  `--fixed-fps 60`), then `tools/map_preview.gd`.
- The web export (`wizard-web` artifact), which also checks the story files were packed.

Merge policy: once CI is green and nothing is left open on the PR, merge it.
