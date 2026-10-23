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
| Figures | `scripts/view/figure.gd` (skinned models, from the Wuxia game), `scripts/view/shape_figure.gd` (unskinned shapes: the Sphere-born, and since N-7.6.3 the `beast` shape, a low four-legged body for the dogs, rats and thorny bramble-crawlers) |
| Spells as low-poly shapes | `scripts/view/spells3d.gd` |
| Over-head marks (pips, HP chunks, Wet) | `scripts/view/marks.gd` |
| Shaders | `scripts/view/*.gdshader`, `lowpoly.gdshaderinc` |
| Tuning for the look: figures, moods, mist, vignette, surfaces, ground, camera | `data/visual.json` |
| The flat fallback's palette and sprites | `scripts/pixel_art.gd` |
| Models, fonts, sounds | `assets/` |

## Budgets (web)

**At most 150 draw calls and 4 real lights in any frame** (GDD 06 §6.5), checked in CI on every
review screenshot (`tools/world_shot.gd --check`, [frame.md](frame.md) 'Checks before merging').
After the N-8.2 pass the busiest are the Calendar (142), the market at noon (123) and the
brigands' toll fight (111); the rest of Ring 1 is 20 to 110.

- Static geometry merged into one mesh per 18 m chunk (`town_mesh.gd` `CHUNK_PX`), lit windows
  included (vertex alpha 0 marks a window, which glows by the time of day, `vcol_glow`); a
  building's front walls and roof, which lift while you're inside, are one more mesh. Lamps are
  baked vertex colour plus additive pools, not lights; at most four real lights (spells); one
  shadow pass; distance-field fonts. A figure's small parts (hats, hoods, bags) cast no shadow.
- Only buildings on the line of sight get the cutaway shader (`lowpoly_cut.gdshader`, which
  `discard`s); everything else uses `lowpoly_solid.gdshader`.
- Anything drawn many times goes out as one batch, never a node or draw call each: every flame
  (ground fires, a burning foe, the Warden's ring, the Cinder Lattice) is one MultiMesh, every halo
  another (its colour in the instance's custom data, `halo.gdshader` `batched`); every flat mark
  on the ground (telegraphs, rings, shot shadows) is one triangle array on the decal
  (`arena.gd` `mark_*`, `scripts/ui/tris.gd`), as are the ground's ash, water and charge, and the
  snow's flakes.
- A menu over the standing town (the map, the book, the Ledger, the Codex, a game) is drawn over a
  still picture of the town taken as it opens ([frame.md](frame.md)), so the 3D is not drawn
  behind it.
- `tools/world_shot.gd` (needs a display) takes review screenshots and prints draw calls and
  lights; CI keeps them as the `review-shots` artifact.
