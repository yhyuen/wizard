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
  F2 autoplay drive the same code. Schemes: Classic (WASD; LMB staff, hold RMB Ward, Q E R F
  spells, 1 2 cantrips), League (right-click move, right-click an enemy or A to strike it with the
  staff, Q W E R spells, D F cantrips, hold C Ward) and League smart cast (a spell commits on the
  key going down); Tab cycles any time; kept in `user://settings.cfg`.
  `scripts/autoload/input_setup.gd` registers the actions in code ([combat.md](combat.md) has the kit).
- **Graphics:** the 3D renders at most 1280 px wide; below 40 fps for 4 s graphics drop to low
  (F4 toggles, low draws the 3D at 3/4 size); kept in `user://settings.json`. F8 mutes.

## HUD and UI

*Target: the [UI and HUD spec](/mnt/project-files/design/ui/ui-hud-spec.md) (tracker M0-12): four-star spellbook bar with stage rings, Focus
diamonds and Overdraw, a 13-moon calendar with pins, fight and explore modes, and every screen
(spellbook, character, Ledger, Codex, region map and calendar, end of a life, title slots); visual page [Lives, Saves and HUD Atlas](https://claude.ai/artifact/7H3xpu7YpYVzGmtDRUq8fK).
Not built yet; the spellbook bar below is its §10 stand-in.*


- `scripts/hud.gd`: the Star Atlas HUD (spellbook constellation of four stars, two cantrip rings
  with their charges, the Ward diamond; Vitality and Aether lines with Strain as a red end, Focus;
  a wind-up ring at the reticle; field-object caps, Cadence stars, the 28-moon row, the duelist's
  plate, toasts, milestone picker, Orrery menu). The spellbook bar is the UI spec's stand-in
  (`/mnt/project-files/design/ui/ui-hud-spec.md` §10) until its §3.1 bar is built. Shapes are drawn as one triangle batch
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
