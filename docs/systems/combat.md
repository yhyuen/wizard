# Combat: the fight, spells, enemies, Magicks (as built)

*Detail: the root [README.md](../../README.md) ('Spellbook, Aether and Cadence', 'The four
spheres', 'What to look for'). Design: GDD 02 (magic) and 03 (combat) in
`/mnt/project-files/design/gdd/`, [Readable Arsenal](/mnt/project-files/design/readable-arsenal.md)
where the GDD is silent. Tracker: C-1 to C-5.*

*Target for the long-loop direction: [spell and combat spec](/mnt/project-files/design/combat/spell-and-combat-spec.md)
(tracker M0-4): cast wind-ups and interrupts, scarce Aether, a 4-spell book, eight schools, a
force × material table. Nothing of it is built yet; its §14 lists today vs target, and
[drift.md](drift.md) has the summary. Until code lands, this page is right about the game.*

## The fight

- **One sim, flat and 2D.** `scripts/arena.gd` simulates every unit (`scripts/unit.gd`),
  projectile, telegraph, zone, field object and effect in sim pixels (the old yard is 480×270).
  The 3D view only reads it ([art.md](art.md)), so **a telegraph is the hitbox** and a shot's
  ground shadow is its exact hitbox.
- **Fights in place.** A story `fight <id>` effect starts an encounter from
  `data/world/encounters.json` where you stand. `waves` run one after another (the next starts
  when the field is clear); `survive > 0` runs them on a timer instead. `leash` (sim px, default
  220) is the ring of mist that holds you near where it began. `lethal` means losing ends the
  loop. Groups can come out of a named map crack (`crack`, glowing `glow` s, default 1) after `at`
  seconds; `guardian` + `flooded_by` lets a once-a-day action (the sluice) start the guardian
  quenched; `waived` waves replace the first ones once you know that trial.
- **The old Mill fight** (two Hollow waves, then the duel with Silas Vane) and the test scenes
  (T on the title card) still run in the arena when no encounter is set.

## The wizard's kit (`scripts/kit.gd`, `scripts/spells/`)

- **Spellbook:** six slots (LMB, RMB, Q, E, R, F; League: Q W E R D F), any known spells from any
  sphere, changed only at an Orrery shrine (in the ruins game, at dawn and from the story's `book`
  effect). C is the Magick (the old fight) or the Ward (the ruins game: `ward` 2 charges, each
  stops one shot). Space blinks.
- **Bolts** fire while held; every other spell shows its telegraph while held and casts on release.
- **Aether** (`spells.json` `aether`): 100, regen 12/s; costs bolt 0, control 20, signature 45,
  magick 50. **Overdraw**: short on Aether, the missing part costs 0.5 HP each and locks the spell
  10 s.
- **Cadence** (`cadence`): the same spell again in a row loses 15% a time, down to 55%; switching
  (unless both are Bolts) adds a note and refunds 10 Aether; 4 notes make the next non-Bolt
  spell Resonant (×1.3 size, +1 bounce/strike/chain). Notes fade after 3 s.
- **Fair telegraphs** (`dodge.reaction` 0.25): a circle never lands faster than
  0.25 s + (radius + body) ÷ wizard speed (`Progression.fair_delay`).
- **Spheres and spells:** Mars (`fire_earth.gd`: Ember Bolt pips → Ignite, Pillar, Pyroclasm,
  embers), Jupiter (Pebble lodestones, Fling, Avalanche), Mercury (`storm_water.gd`: Spark, Arc
  Lance, Storm Call, rods), Luna (Splash Wet, Undertow puddles, Maelstrom), Hours (`hours.gd`:
  Rewind, `from_loop` 2, `ring` 0). Field caps and lives are `spells.json` `field`.
- **Magicks** (`magicks`): Meteor (Mars + Jupiter, found by fire touching a lodestone), Conductor
  (Mercury + Luna, found by lightning on a wet enemy). Hint tomes in the old fight; the ruins
  game turns Magicks off (`Progression.rules`).

## Hits and enemies

- **Impact vs Poise:** reactions none, flinch, stagger, knockdown, launch (`impact_reactions`,
  `reaction_time`). Hit-stop and shake scale with the share of HP removed.
- **Enemies** (`spells.json` `enemies`, minds in `scripts/ai.gd`): Dust Hollow, Hollow Slinger,
  Backward Slinger (`inverted`: rises from the dead, its stones fly home), embers from cracks,
  the Kiln Warden (anchored guardian, two phases), Silas Vane (Storm rival). Hollows won't step
  into a lit lamp's pool unless the encounter sets `light_shy: false` ([world.md](world.md)).
- `scripts/bot.gd` plays the wizard for tests and F2 autoplay.

## Tests

`tools/tests/encounters.gd` (every encounter, fresh and strong, frame time p95 under 8 ms),
`tools/tests/unit.gd` (rules), `tools/tests/world_magic.gd` (spells against the world).
