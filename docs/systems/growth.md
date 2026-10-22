# Growth: wells, Rings, Practice, the Echo (as built)

*Detail: [design/slice/systems.md](/mnt/project-files/design/slice/systems.md) §2 (the rules
these numbers came from). Design: GDD 04 (progression and the loop). Tracker: S-1 (slice M3),
C-1 (spell levels and milestones), N-3 (mastery).*

*Target for the long-loop direction: what carries between lives (spells known, best levels and
the Echo, remembered trials, Sphere Comprehension, school rank, insight) is the carry table in the
[lives, carry-over and achievements spec](/mnt/project-files/design/lives/lives-and-carryover-spec.md) §4 (tracker M0-10); spell growth itself is the
[spell and combat spec](/mnt/project-files/design/combat/spell-and-combat-spec.md) §6. Gear (slots, tiers, traits and their caps) is the
[economy spec](/mnt/project-files/design/economy/economy-and-repair-spec.md) §4 (tracker M0-15).
Not built yet.*

There are two layers, and the ruins game uses the first on top of the second.

## The loop's growth (`scripts/game/growth.gd`, `data/slice/progression.json`)

- **Reset on waking:** wells, the Ring, each Model's (spell's) Practice, the spellbook.
- **Kept across loops:** the Models you know, the best Practice each reached, the most wells you
  held (the **Echo**), each spell's mutation picks (`soul.revisions`), and insight. The Turning
  writes them with `scripts/game/lives.gd` `carry` ([loop.md](loop.md)).
- **Wells** come from kills (`wells.kill` 1), patrols and meditating, capped at `well_cap` 80.
  Below the most you held in an earlier loop they grow `echo_mult` ×3 faster.
- **Rings:** Apprentice, 1st (the yard trial sets the flag `ring1`), 2nd, 3rd, 4th at
  `ring_wells` 0/0/20/40/70. Open slots of the four-spell book by Ring `slots` 2/3/3/4/4 (spell and
  combat spec §5.1; six slots before the combat weight pass, N-2.3); a spell's tier needs a Ring
  (`tier_ring`: bolt 0, control 1, signature 4). HP 100 + 2 per well, Aether 100 + 1 per well;
  blink charges at Rings `blink_ring` 2 and 4.
- **Practice** (spell XP): grows ×3 below the best that Model reached before, plus **insight**
  (lives spec §4.3): +1 at each Turning, up to +3, each point +10%, and each Omen taken this life adds 5% of that (`lives.json` `insight`,
  `omen_insight`; it
  replaced Fluency, which counted loops that reached day 7). Meditating and training at the watch's
  targets work once a day each (`once_a_day`); training gives `train_share` 0.4 of a level.
- **Start:** `start_models` Ember Bolt, Pebble, Pillar, Fling.
- **Fights borrow it:** `begin_fight()` lends this loop's Practice and spellbook to the
  Progression autoload with the rules dictionary (`Progression.rules`: hp, aether, blinks, open
  slots, echo, `fluency` (the insight bonus), no Magicks); `end_fight()` takes them back. A book saved with six slots
  keeps its first four.

## Schools (`data/schools.json`; N-5.1)

*Spell spec §5.1, §7, §8. Built: the frame, Astral Rite's rule and Spark Artifice's devices.
Not yet: the other six schools, school quest lines, Grand spells needing the school's Adept rank.
A power's rank ladder is under Powers below.*

- **Every spell names its school** (`spells.json` `school`): the 13 spells are all **Astral
  Rite** (the College). Each road names its school (`lives.json` `roads`): Apprentice → Astral
  Rite, Lamplighter → Spark Artifice. **This life's school** is your road's; before you take a
  road (a later life's first days) you have none.
- **Outside your school** a spell costs more Aether and winds up longer (`kit.gd` `aether_cost`
  and `windup` × `Progression.school_k`): ×1.25 in a school you hold a rank in (this life, or only
  Initiate in an earlier one), ×1.5 in one you never trained, ×1 again once an earlier life took
  that school to **Adept** (`outside.free_rank`). The book shows the extra cost on a Model ("+25%").
- **School rank:** Initiate, Adept, Master, Grandmaster at 0 / 150 / 600 / 1500 Practice gained on
  your school's spells this life (`life.schools`, from `Progression.practised`); insight adds to it
  as to all Practice, and below the best rank an earlier life reached it comes ×3 (`echo`). A new
  rank toasts. The Turning keeps the best rank per school (`soul.schools`). The spellbook's header
  shows your school and rank.
- **Astral Rite's Alignment:** stand still for 1 s (`alignment.still_s`; a ring of eight gold stars
  turns round your feet when you're Aligned), then begin a spell of your school: it gets ×1.3
  range (`range_k`), its telegraph included (`Progression.align`, `reach()`). Moving or casting
  resets it.

### Devices: Spark Artifice (`schools.json` `devices`, `growth.gd`; N-5.2)

*Economy spec §5. How a device fights is in [combat.md](combat.md) "Devices".*

- **Four devices**, all Spark Artifice and all usable from the Apprentice Ring (`ring` 0): Spark
  Flask, Arc Rod, Smoke Jar, Tar Pot. A device is a Model like any spell (`model_<id>`, kept
  across lives) and goes in any book slot. It levels from its hits like any spell, and that
  Practice counts toward Spark Artifice's rank.
- **Charges** (`life.devices`, reset each life): a device holds 3, +1 per breakthrough this life
  (`device_cap`). The fight spends them through `Progression.rules.devices` (the same dictionary).
- **Reagents** (`life.reagents`, reset each life): lamp oil, glass vial, copper wire, tar, smoke
  powder. Per charge: Spark Flask 1 oil + 1 glass, Arc Rod 1 wire, Smoke Jar 1 powder + 1 glass,
  Tar Pot 1 tar + 1 glass. The spellbook's header lists your stock once you know a device; slots
  and Models show "2 / 3 charges".
- **Outside the school** (`charge_cost`): on the Lamplighter road (or once an earlier life took
  Spark Artifice to Adept) a charge costs its listed reagents; having trained it but walking
  another road, +1 of its first reagent; never trained, double (`never_k`).
- **The bench** (camp, Lantern Market; story effect `bench`): fills every device you know toward
  its cap, one charge at a time round the devices, as far as your reagents go, and takes the time
  of day. Never mid-fight. Its first use teaches anyone the Spark Flask (`teaches`), and once a
  life the Lamplighter there gives you 2 oil and 2 glass (`starter`, story `bench stock`).
- **The Lamplighter road** (`lives.json` `roads.lamplighter.kit`): taking it teaches all four
  devices and starts the life with 3 Spark Flask charges, 4 oil and 4 glass.
- **Salvage** ([world.md](world.md)): breaking a crate, barrel or cart near you adds its reagents.

### Wild spells (`spells.json` `wild`; N-7.6.8)

*Spell spec (wild spells: teachers, tombs and inheritances). Built: one, **Cinder Lattice**, the
Ring 1 inheritance's gift ([world.md](world.md) "Trial rooms"; how it fights is in
[combat.md](combat.md)).*

- A wild spell names **no school**: any road casts it at its listed Aether and wind-up, and its
  Practice counts toward no school's rank. It needs no Ring (`ring` 0). Its Model is learned once
  and kept by the soul, like any Model.

### Combined spells (`schools.json` `combined`; N-5.3)

*Spell spec §6.5, §8. Built: the first, for Astral Rite + Spark Artifice. How it fights is in
[combat.md](combat.md) "Star Lantern".*

- A combined spell names both schools (`spells.json` `schools`, `combined`). It **casts** once both
  schools have reached **Master** (`combined.rank` 2) in this life or an earlier one
  (`growth.mastered`), and its named spells are at their stage this life (`needs`): the **Star
  Lantern** needs Spark Flask and Ember Bolt at Master, and the 1st Ring. The book shows "(not yet)"
  until then.
- It is **never outside your school** on either school's road (`Progression.schools_of`), its
  Practice counts toward whichever of its schools you walk, and as a device its charge costs its
  listed reagents (1 oil, 1 glass, 1 copper wire) and fills at the bench.
- **Learning it:** once both schools are mastered, the Lamplighters' bench offers "Ask about the
  lantern with the star-chart shade" (story condition `mastered(<school>)`), which teaches the Model
  (kept across lives).

## Powers: standing and rank (`data/world/powers.json`, `scripts/game/powers.gd`; N-7.3.3)

*Powers spec §3-4. Built: standing with each power, membership through your road, the rank
ladder's rows, merit, and the College's examination. Not yet: duty boards (merit from duties),
the daily cap, allies and rivals, Associates, leaving and betraying, a voice at fixed events,
rank grants (tier-2 spells, stipend, titles), past-life ranks easing the rows, rivals' exam duels.*

- **Standing** with a power is its start on the first morning (the College +5, the Watch +5, the
  Knights −15, the rest 0; your road's power +20) plus this life's bumps, −100..100, in seven
  tiers from Hunted to Honoured (Friendly from +10). The bumps are `Run.life.standing`, shared
  with the owners' reaction ladder (world.md); the story moves them with `standing <power> <n>`.
- **Your road joins you to its power** (the Apprentice road the College, the Lamplighter road the
  Guild) as an **Initiate**. **Merit** is earned only as a member, from the story's `merit <n>`:
  Crane's lesson (+10 with every door right, else +5), Marrow's (+5), the Mill cellar (+15 the
  patient way, +5 by fire), the Kiln Warden (+10).
- **Adept** is taken at the power's examination (the story's `exam <power>`) if its rows are met:
  standing 25, the 1st Ring, three spells of its school known, one of them at Adept stage, and 30
  merit. The College examines at the Thaw examination (Thaw 21); passing it with the rows met
  makes you Adept. Master and Grandmaster have rows but nothing examines them yet.
- Story conditions `rank(power)` (−1 not a member, 0 Initiate, 1 Adept) and `standing(power)`.
  The spellbook shows your rank, the power, its tier and your merit. All of it resets each life.

## Spell levels and mastery (`scripts/autoload/progression.gd`, `data/spells.json` `progression`)

- `Progression.data` is `data/spells.json` plus the enemy records from `data/enemies.json`
  (`enemies`, `foes`; [combat.md](combat.md), N-6.1).
- A spell levels from its own hits: XP needed `xp_base` 8 + `xp_step` 4 per level, max 20.
- **Stages** (spell spec §6, N-3): Novice 1–5, Adept 6–10, Master 11–15, Perfected 16–20
  (`stages`, `stage_top`). Under the slice's rules (`rules.walls`) a spell stops at the top of its
  stage (the **wall**); XP keeps filling up to one level's worth (`xp_bank` 1.0) and is spent the
  moment it breaks through.
- **Breakthrough trials** (`breakthrough_trials` 1/2/3 of them for Adept/Master/Perfected), from:
  a **feat** (land it on a foe 15/45/100 times this life, `feats`; training doesn't count), an
  **insight** (any Ledger entry naming the spell in `insight`, none written yet) and a
  **meditation** (meditate on the day of the spell's Sphere: each element has a `sphere`, the
  weekday's Sphere comes from the calendar; `growth.meditate_trials()`). Perfected also needs a
  best-ever level of 11+ (the Echo). A stage reached in an earlier life (`soul.broken`, written by
  `lives.gd` `carry`) counts as remembered: you still climb, but the trial is waived.
- A breakthrough emits `breakthrough(id, stage)`, toasts "Breakthrough: …", and offers the stage's
  Revision pick (the old milestone picks at 5, 10, 15 now come at each breakthrough).
- **What a stage changes:** the Force grade (`grade_by_stage` I–IV, capped by Ring `grade_cap`
  1/2/2/3/3), and each spell's `minor` axis grows ×1.2 per stage (`minor_step`). A stat is still
  `base + per × (level − 1)` (`floor`, `min`, `max`) on its main axis.
- **Prerequisites** (`needs`, spell spec §6.5): Pyroclasm needs Ember Bolt and Pillar at Adept,
  Storm Call Spark and Arc Lance at Adept, Maelstrom Undertow at Master, Avalanche Pebble and Fling
  at Adept, this life. Until then the book lists it "(not yet)" and it can't be slotted.
- **Rings need stages too** (`ring_stages`): the 2nd Ring four spells at Adept, the 3rd one at
  Master, the 4th two at Master, on top of the wells.
- The book shows each slot's stage and grade, and the selected slot's next trials with ticks.
- **Wizard level** and the halving rule (`loop_wizard_level_keep` 0.5), mastery and tome hints
  belong to the old Mill fight; the ruins game's loop doesn't use them (see [drift.md](drift.md)).
  Without `rules.walls` (the old Mill fight) spells level straight to 20 as before.
- Saves to `user://progress.json`, apart from the run ([loop.md](loop.md)).

## Tests

`tools/tests/relearn.gd` (loop 3 is back to loop 1's wells and Practice by day 3),
`tools/tests/unit.gd` (walls, trials, banking, remembered stages, prerequisites, Ring stages;
schools: every spell and road has one, the outside cost, rank from Practice and its Echo, the
carry, Alignment's reach), `tools/tests/world_magic.gd` (an Aligned Pillar lands past its range).
