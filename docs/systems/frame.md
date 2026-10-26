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
  loading (the card between maps), death. The title and death screens have **Copy run summary**
  and **Feedback form** (the playtest notes artifact). Onboarding is under 'Tips and help' below.
- **Input** becomes an intent dictionary each physics frame (`scripts/controls.gd`), so tests and
  F2 autoplay drive the same code (F1 practice and F2 autoplay work in debug builds only, not in the
  web or desktop exports). Schemes: Classic (WASD; LMB staff, hold RMB Ward, Q E R F
  spells, 1 2 cantrips), League (right-click move, right-click an enemy or A to strike it with the
  staff, Q W E R spells, D F cantrips, hold C Ward) and League smart cast (a spell commits on the
  key going down); Tab cycles any time; kept in `user://settings.cfg`.
  `scripts/autoload/input_setup.gd` registers the actions in code ([combat.md](combat.md) has the kit).
- **Text:** wrapped lines are cached (`scripts/ui/atlas.gd` `wrap_text`, up to 256), since the
  same barks, hints and toasts are measured word by word every frame otherwise.
- **Graphics:** the 3D renders at most 1280 px wide; below 40 fps for 4 s graphics drop to low
  (F4 toggles, low draws the 3D at 3/4 size); kept in `user://settings.json`. F8 mutes.

## HUD and UI

*Target: the [UI and HUD spec](/mnt/project-files/design/ui/ui-hud-spec.md) (tracker M0-12): four-star spellbook bar with stage rings, Focus
diamonds and Overdraw, a 13-moon calendar with pins, fight and explore modes, and every screen
(spellbook, character, Ledger, Codex, region map and calendar, end of a life, title slots); visual page [Lives, Saves and HUD Atlas](https://claude.ai/artifact/7H3xpu7YpYVzGmtDRUq8fK).
Built so far: its §10 stand-in spellbook bar, the calendar row (§3.2, without pins) and the map's
Reach and Calendar tabs (§5.5).*


- `scripts/hud.gd`: the Star Atlas HUD (spellbook constellation of four stars, two cantrip rings
  with their charges, the Ward diamond; Vitality and Aether lines with Strain as a red end, Focus;
  a wind-up ring at the reticle; field-object caps, Cadence stars, the calendar row, the duelist's
  plate, toasts, milestone picker, Orrery menu). The field-object count leaves out ground fires
  (zones marked `cell`). "Injured" by the Vitality line, with the part it
  can't fill drawn red.
- **The calendar row** (top centre): the 13 moons (this one ringed, past ones dim), then this
  moon's 28 days as four weeks of dots in their weekday Sphere's colour, today ringed, known
  calamities as dark discs, the Great Eclipse as a black sun, a dial for the time of day, today's
  weather glyph and, once Aldous has told you, tomorrow's ([world.md](world.md)). Under it: moon
  name, date, weekday, weather and place; in a fight, the date and the fight's numbers.
- **Rain and snow** fall over the world view and outdoor fights (`slice.gd` `_draw_precip`):
  slanted streaks in rain and storm, drifting flakes in snow (one batch); none indoors.
- **Menus over the town** (the map, the book, the Ledger, the Codex, a game, a confrontation): as
  one opens while the town stands still, `main.gd` takes a still picture of the last frame
  (`backdrop`) and the menu is drawn over that, with the 3D view and the HUD switched off until it
  closes (the budgets, [art.md](art.md)). Not in a fight, where the world keeps moving.
- **The map** (M, `scripts/game/slice.gd`) has three tabs (1–3, or click): **Here** (this map,
  as built), **The Reach** (the region map and travel, [world.md](world.md)) and **Calendar**
  (the year's moons, click one to see its weeks by weekday, known dates, the weather glyphs you
  know, today's weather, Rest until…, [loop.md](loop.md)).
- **The Ledger** (L) has eight tabs (1–8): Questions, Clues, People, Insights, **Appointments**
  (missed fixed events, with date, place and who), **Lives** (a page per life lived), **Deeds**
  (achievements and titles, [loop.md](loop.md)) and **Guide** (the Field Guide: every kind of foe,
  "?" until seen, then faction and tier, times beaten, the weakness found with its lesson, a gold
  star once mastered; [combat.md](combat.md)).
- **The Codex** (N; UI spec §5.4, N-7.7) has two tabs: **Pages** (Codex pages your deeds wrote)
  and **Caches** (the caches you remember, to mark for this life; [loop.md](loop.md)). The walk
  hint names it.
- **The main line:** a gold step under the vitals (outside fights) names the next main-story
  action ([loop.md](loop.md)). Under it, the **jobs line** (a hollow diamond, in paper) names the
  commission taken last and its step ([story.md](story.md) Commissions). The calendar row pins
  known fixed events in gold and appointments in silver.
- **Toasts** run down the right; an achievement's is gold, with a chime (UI spec §3.6). A spell
  reaching its wall and a breakthrough toast too (`main.gd` `_on_breakthrough`), and a new school
  rank (`_on_school_ranked`). The spellbook
  screen shows each slot's stage, level and grade, the picked slot's next trials, and "(not yet)"
  on a Model whose prerequisites aren't met, your school and rank in its header and the extra cost
  ("+25%") on a Model outside your school ([growth.md](growth.md)). A device shows "2 / 3
  charges" on its slot and Model, the header lists your reagents, the HUD star shows its charges
  in place of an Aether cost (red at 0), and salvage picked up toasts ("Salvage: 1 glass vial").
- **Waking** (`main.gd` `enter_world`) rebuilds the 3D when the map, or the Mill fields' crop,
  changed since it was built (`world_view.build_key`, N-4.5.3).
- **Screens:** title, loading card (the map's name and its `card` line from `data/world/maps.json`), the end card (a life ends; screen id `death`) and the hurt screen (a fall
  that wakes you Injured, [loop.md](loop.md)). The spellbook bar is the UI spec's stand-in
  (`/mnt/project-files/design/ui/ui-hud-spec.md` §10) until its §3.1 bar is built. Shapes are drawn as one triangle batch
  (`scripts/ui/tris.gd`); panels and buttons come from `scripts/ui/atlas.gd`.
- `scripts/autoload/sfx.gd` plays the synthesised sounds (`tools/sfx/make_sfx.py` → `assets/sfx/`).
- Sound as built: 16 synthesised WAVs, an 8-voice pool with a per-name gap and dB table in
  `sfx.gd`, the night wind loop, everything on the Master bus, no music. *Target: the
  [audio spec](/mnt/project-files/design/audio/audio-spec.md) (tracker M0-18; visual and playable:
  [Sound Atlas](https://claude.ai/artifact/EEGxEw6Mertv8gHG5kn2NY)): wind-up, catch, release and
  impact per Sphere, stage layers and Force grades, material sounds, weather beds, buses, a
  24-voice pool with priority, `data/audio.json`, and music by power, region and season with
  calamity cues. The gaps are in [drift.md](drift.md).*
- When a fight ends, `main.gd` hands the story its outcome and how many were beaten: kills plus
  the ones who yielded ([combat.md](combat.md) 'Morale').
- `scripts/game/build_id.gd` says which build this is; CI writes it before the web export.

## Tips and help (onboarding, N-8.4)

*Plan: [design/onboarding/first-30-minutes.md](/mnt/project-files/design/onboarding/first-30-minutes.md)
(what a new player does in the first 30 minutes, and the five fixes). Built: the help card, the
tips, the merged Ledger toasts, the title line. Not yet: the Day 1 drill and early goals (B, A),
the map's goal marker and compass (D).*

- **Hints** (`slice.gd` `HINTS`): the walk hint (under the wizard until 12 s into the morning) and
  the talk hint (over the first dialogue panel), first life only.
- **Tips** (`data/world/tips.json`, `scripts/game/tips.gd`): one at a time, once per soul
  (`soul.hints`, shared with the hints), first life only, in the hint box: under the wizard while
  walking (`where: world`: no scene, no menu, the dawn card and walk hint gone) or at the top of a
  fight (`where: fight`), for `s` seconds on screen. A tip whose moment passes (a fight ends) shows
  next time. Keys in its text follow the control scheme. Who asks for each: `help` when the walk
  hint is done; `fight` when a fight starts (not the tests' resolver or bot); `ledger` on a Ledger
  toast; `wait` on Z; `day` at a dawn from day 2; `hurt` waking Injured (instead of `day`); `dark`
  at a time of day that is dark (`world.dark()`); `board`, `ladder`, `stair` on walking into the
  places in `places`. The setting `tips` (`user://settings.json`, beside `gfx`) turns them off.
- **How to play** (H, or the title's button; overlay `help`): the keys of the current scheme
  (walking and fighting), and three rules: time, losing, the Ledger and the gold line. T toggles
  tips; H, Esc or Space closes. Over the title, the town, a scene, the end card; not mid-fight
  (a toast says so).
- **Ledger toasts** learnt within a second of each other share one toast: "Ledger +3: A · B · C".
- **Title:** "Ring 1 · the survivors' camp, the fallen city and the Mill fields", and H in the key line.

## Checks before merging

CI (`.github/workflows/ci.yml`) runs on every PR and push to `main`, and publishes `main` to
GitHub Pages. In order:

- `python3 tools/ci/spec_check.py`: the spec rule ([README.md](README.md)).
- `tools/ci/godot.sh` (fails on any script error) with `tools/tests/unit.gd`, `story_lint.gd`,
  `route.gd`, `relearn.gd`, `deaths.gd`, `calamity.gd`, `encounters.gd`, `world_magic.gd` (the fight tests with
  `--fixed-fps 60`), then `tools/map_preview.gd`.
- **Draw budgets** (N-8.2): `tools/world_shot.gd --check` under `xvfb-run` takes all the
  review screenshots (Ring 1's camp, halls, city, undercroft, fields and road, its fights, menus
  and weather) and fails if any is over 150 draw calls or 4 lights ([art.md](art.md)
  'Budgets (web)'); the shots are the `review-shots` artifact.
- The web export (`wizard-web` artifact), which also checks every story file was packed (each
  file's first scene is in the pack). The export presets (`export_presets.cfg`) pack `data/*.json`
  and `data/*.story` at any depth; until N-8.1 they missed the city's, the undercroft's, the
  fields' and the east road's stories, so those maps had no scenes on the web.
- The desktop exports (N-8.1): **Windows** (`Wizard.exe`, x86-64), **macOS** (`Wizard.zip`, a
  universal app, signed ad hoc, not notarized: macOS asks before the first launch) and **Linux**
  (`wizard.x86_64`), each one file with the game packed in (`wizard-windows`, `wizard-macos`,
  `wizard-linux` artifacts, kept 14 days). The Linux build is started headless and must quit
  cleanly. A universal macOS build needs ETC2/ASTC texture import (`project.godot`).

Merge policy: once CI is green and nothing is left open on the PR, merge it.
