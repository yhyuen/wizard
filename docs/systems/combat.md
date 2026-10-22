# Combat: the fight, spells, enemies (as built)

*Detail: the root [README.md](../../README.md) ('Controls', 'Spellbook, Aether and Cadence', 'The four
spheres', 'What to look for'). Design: GDD 02 (magic) and 03 (combat) in
`/mnt/project-files/design/gdd/`. Tracker: C-1 to C-5; the weight pass is N-2 (N-2.1 to N-2.3).*

*Target for the long-loop direction: [spell and combat spec](/mnt/project-files/design/combat/spell-and-combat-spec.md)
(tracker M0-4): cast wind-ups and interrupts, scarce Aether, a 4-spell book, eight schools, a
force × material table, and spell mastery with visible growth, breakthroughs and prerequisites. Its
first step, the **weight pass** (§17.1: wind-ups, Focus, scarce Aether, Overdraw and Strain, the
4-spell book, cantrips, staff strike, held Ward), is built and described below; the rest is not yet.
Its §15 lists today vs target, and [drift.md](drift.md) has the summary. Fighting enemies (tiers, Poise/Break/Focus/Guard, armour
grades, AI and the fight director, eleven factions, bosses, scaling, rewards, worked fights) is in the
[enemy combat spec](/mnt/project-files/design/combat/enemy-combat-spec.md) (tracker M0-7; visual
page [Enemy Field Guide](https://claude.ai/artifact/NfkV4YFAufXzUP1pBuGcAK)). Until code lands, this page is right about the game.*

## The fight

- **One sim, flat and 2D.** `scripts/arena.gd` simulates every unit (`scripts/unit.gd`),
  projectile, telegraph, zone, field object and effect in sim pixels (the old yard is 480×270).
  The 3D view only reads it ([art.md](art.md)), so **a telegraph is the hitbox** and a shot's
  ground shadow is its exact hitbox. The sim steps 60 times a second; each unit (and each
  person in town) keeps `prev_pos`, and the view draws it at `shown_pos()`, between the last two
  steps, so movement stays smooth on faster screens or a late frame (a jump of over 20 px, such
  as a blink, is drawn where it lands).
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

All numbers are in `data/spells.json` (`casting`, `staff`, `ward`, `cantrips`, `aether`,
`overdraw`, `cadence`, and each spell's `cast`, `windup`, `cooldown`, `aether`).

- **Spellbook:** four slots (Q E R F; League Q W E R), any known spells from any sphere, changed at
  your desk (the story's `book` effect; the old fight's Orrery shrine). In the ruins game the Ring
  opens 2/3/3/4/4 of them ([growth.md](growth.md)). Always there: the **staff strike** (LMB; League
  right-click an enemy or A), the **Ward** (hold RMB; League C), two **cantrips** (1 2; League D F)
  and **Blink** (Space). There is no Magick key: Magicks are retired (their code stays in
  `fire_earth.gd`/`storm_water.gd` until combined spells replace it, but nothing casts them).
- **Cast phases** (N-2.1): every spell winds up, releases, recovers. Speed bands `casting`:
  **Swift** (the old Bolts, wind-up 0.4–0.5 s, walk at 70%, recovery 0.25 s), **Weave** (Pillar,
  Fling, Arc Lance, Undertow, Rewind: 0.8–0.9 s, 40%, 0.4 s), **Incant** (Pyroclasm, Avalanche,
  Storm Call, Maelstrom: 1.5–1.8 s, rooted, 0.6 s). Recovery walks at 80%. Cooldowns: Swift 3–3.5 s,
  Weave 6–7 s, Incant 12–14 s. Hold to wind up (the telegraph shows; a ring at the reticle fills),
  release to cast. Let go early: cancelled, nothing spent, except a **Swift** spell (or any spell
  under League smart cast), which is committed and fires when its wind-up ends. Blink cancels a
  wind-up or recovery. Arc Lance still charges with how long it is held.
- **Injured** ([loop.md](loop.md)): the first spell of each fight winds up +0.2 s longer
  (`arena.set_injured`, `kit.slow_start`), and Vitality stays at or below 75%.
- **Omens** ([loop.md](loop.md)): the Hard Sky multiplies every enemy's Vitality as it spawns
  (`Run.omen_mult("enemy_hp")`, ×1.3) and the Thin Well halves Aether regained in and out of
  fights (`aether_regen`, ×0.5).
- **Focus** (N-2.1, `casting.focus` 1): while winding up, a hit with Impact at or below Focus
  causes no reaction; above it, the cast breaks (a cracked puff, "Cast broken") and half its Aether
  is lost. **Enemies** have Focus too (`enemies.<kind>.focus`, default Poise + 1, the old "stagger
  breaks a wind-up" rule): above it their wind-up breaks, its telegraph goes, and the attack comes
  back at half its cooldown (`ai.gd` `interrupt`).
- **Aether** (N-2.2, `aether`): 100 (wells add to it). In a fight (`arena.fighting()`) it comes back
  at 3/s; out of one at 15/s, but only up to 60% of the pool. **Rest** fills it and clears Strain:
  waking at dawn and the story's `meditate` effect (`kit.rest()`); every test fight starts rested.
  Costs per spell: Swift 12–16, Weave 22–28, Incant 45–50, cantrips 4.
- **Overdraw** (`overdraw`): short on Aether, a spell still casts; each missing point costs 1 HP and
  adds 1 **Strain**, which lowers max Aether one for one until rest. An Overdraw at 50+ Strain
  backlashes: a 2 s stun.
- **Staff strike** (N-2.3, `staff`): free, instant, every 0.6 s, a 24 px arc in front, 3 damage,
  Impact 1; it shoves the prop in front of it. Not a way to win a fight.
- **Ward** (N-2.3, `ward`): hold to raise a shield arc (about 140°) toward the cursor; drains 6
  Aether/s and 8 per hit stopped; stops any hit from the front (shots, slashes, the Warden's ring);
  Impact 3+ breaks it and staggers you; it drops when Aether runs out and can't be raised for 1 s.
  You walk at 70% behind it. Replaces the 2-charge Ward on C.
- **Cantrips** (N-2.3, `cantrips`, `start_cantrips`): instant, 4 Aether, 2 charges back every 6 s,
  at the cursor within 70 px. **Kindle**: lights lamps and braziers, sets props burning, singes
  enemies there (2 damage) and adds a flame pip. **Douse**: puts out fires and lamps, soaks enemies
  (Wet 4 s). The world reads their short `kindle`/`douse` zones ([world.md](world.md)).
- **Cadence** (`cadence`): a spell different from the last adds a note and refunds 4 Aether; 4
  notes make the next spell Resonant (×1.3 size, +1 bounce/strike/chain). Notes fade after 4 s.
  Repeating a spell no longer dulls it (cooldowns stop repeats).
- **Vitality** out of a fight comes back at 2% of max a second (`wizard.regen_out`).
- **Fair telegraphs** (`dodge.reaction` 0.25): a circle never lands faster than
  0.25 s + (radius + body) ÷ wizard speed (`Progression.fair_delay`).
- **Spheres and spells:** Mars (`fire_earth.gd`: Ember Bolt pips → Ignite, Pillar, Pyroclasm,
  embers), Jupiter (Pebble lodestones, Fling, Avalanche), Mercury (`storm_water.gd`: Spark, Arc
  Lance, Storm Call, rods), Luna (Splash Wet, Undertow puddles, Maelstrom), Hours (`hours.gd`:
  Rewind, `from_loop` 2, `ring` 0). Field caps and lives are `spells.json` `field`.
- **The ground in a fight** ([world.md](world.md) "Fire, water and charge on the ground"): your
  fire shots light the cell where they end (out of range, on a foe or at a wall), Pillar and Kindle
  their area; burning and charged cells hurt anyone on them, you at half. A burning cell's flame is
  an `ember` zone marked `cell`: the world deals its damage, not the arena's ember rule.
  Rubble from a fallen structure slows everyone on it by 30% (`move_speed` asks
  `world.ground_speed`); a collapse is Impact 3 to everyone under it.
- **Schools** ([growth.md](growth.md) "Schools"): spells outside this life's school cost more
  Aether and wind up longer (×1.25 or ×1.5). Astral Rite's **Alignment**: stood still 1 s, your
  next spell of the school reaches ×1.3 further (`kit.gd` `still_t`, `aligned()`).
- **Devices** (N-5.2, Spark Artifice, `artifice.gd`; charges and the bench are in
  [growth.md](growth.md) "Devices"): a device (`spells.json` `device`) has no wind-up and costs no
  Aether; each throw spends a charge, and an empty device won't throw ("…is empty. Refill it at a
  bench."). Cooldown 1–1.5 s. Holding the key shows a line and a ring where it lands (its range)
  and the size of what it leaves; it flies 0.3–0.35 s, then:
  **Spark Flask** (range 110) bursts in a 16 px fire (16 damage, Impact 2, 2 flame pips) and leaves
  a `flask` mark the world burns with (ground, props, lamps); **Arc Rod** (90) plants a rod that
  arcs into the nearest foe within 50 px every 0.9 s (8 damage) for 8 s and strikes the ground it
  stands on; **Smoke Jar** (100) leaves a 28 px cloud for 5 s, and a foe inside it can't start an
  attack (its attack cooldown is held at 0.3 s); **Tar Pot** (100) leaves a 26 px pool for 12 s that
  slows anyone in it (as gravel does) and turns the ground under it to oil; any fire touching the
  pool (an ember, a flask, Kindle, Pillar, a burning cell) sets it all alight at once. The HUD shows
  a device's charges where a spell shows its Aether.
- **Star Lantern** (N-5.3, the first combined spell, [growth.md](growth.md) "Combined spells"): a
  device of both schools (range 100, 1 charge spent, cooldown 2 s). It hangs where it lands for
  12 s, a gold light with a 40 px ring of turning stars: any spell you **begin** standing inside the
  ring is Aligned (×1.3 reach) at once, whatever its school and without standing still
  (`artifice.gd` `in_lantern`), and its light keeps light-shy enemies out like a lamp's pool.
- **Mastery in a fight** ([growth.md](growth.md)): a spell's stage sets its Force grade
  (`Progression.grade`, I–IV, capped by Ring) and grows its `minor` axis ×1.2 per stage. Pillar's
  and the meteor's zones draw a ring of sigils per stage (`arena.gd` `_sigils`). Signatures need
  their prerequisite spells at stage this life (`growth.gd` `needs_met`).
- **Magicks** (`magicks`): Meteor and Conductor are retired: no key casts them. Discovery and hint
  tomes still run in the old Mill fight.

## Hits and enemies

- **Impact vs Poise:** reactions none, flinch, stagger, knockdown, launch (`impact_reactions`,
  `reaction_time`). Hit-stop and shake scale with the share of HP removed.
- **Enemy records** (N-6.1, `data/enemies.json`; loaded into `Progression.data` as `enemies`
  (the kinds) and `foes` (the rules)): each kind names its faction, role, tier, attack (melee or
  ranged), body material and the lesson it teaches, then its numbers. Tiers today: Dust Hollow and
  embers are Minions, the Slingers Soldiers, Silas a Champion, the Kiln Warden a Boss.
- **Break** (N-6.1, enemy spec §4, `foes.break`): Soldiers and up have a Break meter (Soldier 35,
  Elite 80, Champion 120, Boss 200), a thin gold bar under the HP chunks. Each hit adds Impact × 10,
  +50% from behind (the hit travels the way it faces) and +50% into a wind-up. Full, it is
  **Broken**: knocked down for 2 s (Soldier), 2.5 s (Elite, Champion) or 3 s (Boss), its telegraphs
  cancelled, taking ×1.5 damage; the bar flashes. The meter drains 10/s after 3 s without a hit.
  Minions have none (any hit staggers them). `arena.gd` `_add_break`, `_break_tick`.
- **The fight director** (N-6.1, enemy spec §6.4, `foes.director`): at most 2 melee and 1 ranged
  enemies may be winding up an attack on you at once, and none further than 320 px from you; the
  rest keep moving until a turn frees up (`ai.gd` `may_attack`). The duellist and bosses aren't
  counted.
- **Bodies and burning** (N-6.2, enemy spec §5, `foes.states`): each kind has a body material
  (`materials.json`): the Hollows and Slingers are husks (cloth), Silas flesh, the Warden iron,
  embers fire (no states). Fire that hits a body that catches (the table's fire × body; flesh only
  while oiled) sets it **burning** for 4 s (half for Elites and up): 2 damage every 0.5 s (×2 if
  oiled), it lights the ground cell it stands on, and husks within 16 px catch. A burning Hollow
  **panics** and runs from you. Water puts it out; fire on a wet body only dries it. Standing in a
  Tar Pot's pool oils a unit for 6 s (`arena.gd` `catch_fire`, `_burn_tick`; a flame shows on it).
- **Enemies** (minds in `scripts/ai.gd`): Dust Hollow, Hollow Slinger,
  Backward Slinger (`inverted`: rises from the dead, its stones fly home), embers from cracks,
  the Kiln Warden (anchored guardian, two phases), Silas Vane (Storm rival). Hollows won't step
  into a lit lamp's pool unless the encounter sets `light_shy: false` ([world.md](world.md)).
- **More Hollows** (N-6.3, enemy spec §8.1, `scripts/hollows.gd`, husk bodies): the
  **Lantern-eater** (Soldier) walks to a lit lamp within 240 px and smothers it over 1.6 s (a hit
  above its Focus 1 stops it), then fights like a Hollow; the **Hollow Choir** (Elite, no attack)
  keeps 120 px off and **hums**: Hollows within 90 px get +1 Poise and ×1.3 speed (`poise_of`); a
  hit above its Focus hushes it for 2.5 s; the **Overdrawn Husk** (Elite) throws a wild Ember Bolt
  (up to 0.35 rad off its aim; the telegraph line shows where it really goes), and when Broken
  **leaks** a violet pool of 20 Aether, 12/s to you while you stand in it, for 5 s. Encounter
  `lamp_night` is the Lantern-eater and Choir with Hollows, then the Husk; like the toll, only the
  fight tests play it until its places are built (N-7.1).
- **Brigands** (N-6.3, enemy spec §8.2; minds, guard, keg and net in `scripts/brigands.gd`, flesh
  bodies): the **Cutthroat** (Minion) stabs with a lunge and backs off; the **Crossbowman**
  (Soldier) keeps 170 px off, shoots a bolt (Impact 2, the Ward stops it) and stands reloading 3 s
  after; the **Shieldman** (Soldier) has a **Guard**: a hit from within 60° of his front up to
  Impact 2 is blocked, a heavier one goes through, and fire on the shield burns it away (he
  staggers); the **Powder Monkey** (Soldier) lobs a powder pot (a circle that lands 0.9 s after his
  throw, Impact 3, lights the ground) and carries a **keg**: fire on him, or him burning, blows it
  (30 damage, Impact 3, 34 px, to everyone near, and it sets off other kegs); the **Brigand
  Captain** (Champion, a Leader) swings with Impact 2, throws a **net** (it roots you 1.2 s; Blink
  gets you out) and every 8 s calls a **volley** (his ready Crossbowmen shoot together, past the
  director). Encounter `toll` (the bridge toll, places spec F13) is the group; until the east road
  is built (N-7.1.5) only the fight tests play it, in the camp yard.
- **The Field Guide** (N-6.5, enemy spec §12.1, `foes.guide`, `scripts/field_guide.gd`): what
  you know of each kind, kept in the soul (`Run.soul["guide"]`), so it carries to every life. A
  kind is **Seen** when it spawns, **Beaten** when killed or it yields, its weakness **Found** the
  first time you do one of its `answers` to it (set it alight, Break it, break its wind-up or hum,
  catch the Crossbowman reloading, burn or go round the shield, fire on the keg, flood the kiln
  first; a gold toast gives its lesson), and **Mastered** once beaten 10 times with its weakness
  found. The Ledger's Guide tab shows it ([frame.md](frame.md)); achievements count it
  ([loop.md](loop.md)).
- **Morale** (N-6.4, enemy spec §6.5, `foes.morale`, `scripts/morale.gd`): people yield, Hollows,
  constructs, embers and Silas don't (only `brigands` so far). Once a side's leader is dead or half
  of it is out of the fight, any of it at 25% HP or less gives up: a Minion runs for 2.5 s and is
  gone (not a kill); the rest **kneel**, out of the fight (team 2: spells, AI and the win check pass
  them by) and give their XP and wells as if beaten. The leader going down toasts that the rest lose
  heart. Win, and everyone kneeling is **spared**: `Run.life["spared"]` counts them by faction for
  the reputation to read later. Losing to people isn't lethal (the toll sets `lethal: false`).
- `scripts/bot.gd` plays the wizard for tests and F2 autoplay: one committed spell at a time, waiting
  for Aether rather than Overdrawing, the Ward against shots, the staff when something is close.

## Tests

`tools/tests/encounters.gd` (every encounter, fresh and strong, frame time p95 under 8 ms),
`tools/tests/unit.gd` (rules, with `_kit`: wind-up, cancel and commit, Focus, Aether in and out of a
fight, Overdraw and Strain, rest, the Ward, the staff, a cantrip), `tools/tests/world_magic.gd`
(spells against the world).
