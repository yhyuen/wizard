# Art and presentation: the 3D view, meshes, shaders, figures, sound files (index)

*A content spec, like [content.md](content.md): `spec_check.py` exempts these paths, because
changing how something looks doesn't change how the game works. If a visual change needs a new
rule (a telegraph's size, a light that changes what enemies do), that rule belongs in the owning
system's spec. Detail: the root [README.md](../../README.md) 'The look'. Design: GDD 06 §6.3
(moody night), §6.6 (Star Atlas UI). Tracker: V-1, V-2.*

*Target sound (not built yet): the [audio spec](/mnt/project-files/design/audio/audio-spec.md)
(tracker M0-18), playable as the [Sound Atlas](https://claude.ai/artifact/EEGxEw6Mertv8gHG5kn2NY).
Sound files stay content under `assets/`; synthesised first (`tools/sfx/make_sfx.py`), recorded CC0
only for organic beds and foley, listed in `assets/sfx/LICENSES.md`.*

*Target look for spells (not built yet): [spell visuals and VFX](/mnt/project-files/design/vfx/spell-visuals-spec.md)
(tracker M0-5), drawn as the [Spell Light Atlas](https://claude.ai/artifact/DUFcUrXiWNc6dTnDdBCUwS): the six beats of a
cast, sigil rings per mastery stage, Force-grade hits, a look per Sphere and per school's casting
act, material states, and the web VFX budget (4 real lights, faked pools, ≤ 300 particles). The
rules it draws come from the [spell and combat spec](/mnt/project-files/design/combat/spell-and-combat-spec.md).
[drift.md](drift.md) lists the gaps.*

## Where it lives

| What | Files |
| --- | --- |
| The 3D view over the sim: camera, moon, mist, moods, the marks decal, figures, spells | `scripts/view/view3d.gd`, `scripts/world/world_view.gd` (maps, close steep camera) |
| Static map meshes, merged per chunk with lamp light baked in | `scripts/world/town_mesh.gd` (camp), `scripts/world/ruin_mesh.gd` (the ruin kit), `scripts/view/town.gd` (the old Mill plaza) |
| Figures | `scripts/view/figure.gd` (skinned models, from the Wuxia game), `scripts/view/shape_figure.gd` (Sphere-born, unskinned shapes) |
| Spells as low-poly shapes | `scripts/view/spells3d.gd` |
| Over-head marks (pips, HP chunks, Wet) | `scripts/view/marks.gd` |
| Shaders | `scripts/view/*.gdshader`, `lowpoly.gdshaderinc` |
| Tuning for the look: figures, moods, mist, vignette, surfaces, ground, camera | `data/visual.json` |
| The flat fallback's palette and sprites | `scripts/pixel_art.gd` |
| Models, fonts, sounds | `assets/` |

## Budgets (web)

- Static geometry merged into a few meshes; lamps are baked vertex colour plus additive pools, not
  lights; at most four real lights (spells); one shadow pass; distance-field fonts.
- Only buildings on the line of sight get the cutaway shader (`lowpoly_cut.gdshader`, which
  `discard`s); everything else uses `lowpoly_solid.gdshader`.
- Anything drawn once per ground cell (fires, blots) goes out as one batch (a MultiMesh, or one
  triangle array on the decal), never a node or draw call per cell: a grass fire is dozens of cells.
- `tools/world_shot.gd` (needs a display) takes review screenshots and prints draw calls and lights.
