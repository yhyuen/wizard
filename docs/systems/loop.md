# The loop: days, waking, the Ledger, deaths, save (as built)

*Detail: [design/ruins/README.md](/mnt/project-files/design/ruins/README.md) (the first
playable's rules and success criteria), [design/ruins/content.md](/mnt/project-files/design/ruins/content.md)
§6 (the Ledger). Design: GDD 01 and 04. Tracker: S-1 (the two-layer save, deductions), R-1, R-2.*

*Target for the long-loop direction: the [lives, carry-over and achievements spec](/mnt/project-files/design/lives/lives-and-carryover-spec.md) (tracker M0-10: a year of 13 moons, three
ways a life ends, waking injured, the soul/life carry table, insight, roads, achievements) and the
[save system spec](/mnt/project-files/design/lives/save-spec.md) (tracker M0-11: three slots, soul / life / map-damage files, the crash-proof
Turning, save moments, versions, desktop and browser); visual page [Lives, Saves and HUD Atlas](https://claude.ai/artifact/7H3xpu7YpYVzGmtDRUq8fK). Built so far:
the year (N-1.1) and waking injured (N-1.3); the rest is in [drift.md](drift.md). This page is
right about the game.*

*Seasons and calamities target: the [seasons, weather and calamities spec](/mnt/project-files/design/seasons/seasons-and-calamities-spec.md) (tracker M0-13;
visual: [Year Almanac](https://claude.ai/artifact/J7A45goxfoENHyv2nKRR2o)): four seasons on the calendar, daily weather that repeats every
life, and how a calamity plays (Signs, Eve, Onset, Peak, Dawn, Aftermath; Held, Scarred or Fallen).
Nothing of it is built beyond the four dated events below; the gaps are in [drift.md](drift.md).*

## Two layers of state (`scripts/game/run.gd`, the `Run` autoload)

- **`soul`** is what you understand and remember, and keeps across lives (lives spec §4.1, "heads
  keep"): known Ledger entries, deaths by cause, trials passed, the Echo (`echo`), `revisions`,
  `best_wells`, `insight` (0–3), `lives` (a page per life: number, road, cause, moon, day, time,
  insight, wells, what was learnt, Omens, deeds earned), `achievements` (id: life, moon, day),
  `titles` and the `title` worn, the Field Guide (`guide`: kind -> seen, beaten, found;
  [combat.md](combat.md)), play time and frame stats for the run summary, hints seen.
- **`life`** is this year and resets at the Turning ("hands reset"): its number `n`, `road`
  (always `apprentice` until roads are built), the day, the time of day, flags, scenes seen, what
  was learnt, Practice, wells, the book, once-a-day actions done (`done_<op>`), items taken,
  `injured`, `losses` (each lost fight: day, time, cause, days slept), `calamities` passed,
  `omens`, the achievements `earned` in it and how each fixed event went (`events`). The soul
  also keeps `dates` (fixed events seen come or go) and `appointments`.
  `Run.loop()` is the life's number.
- **The Turning** (`Run.end_life(cause)`): `scripts/game/lives.gd` `carry(soul, life, cause)` is a
  pure function that returns the new soul (deaths, insight +1 up to `insight.cap`, the Echo and
  revisions from the life's Practice, the most wells held, each spell's highest stage as `broken` so
  its breakthrough trials are waived next life ([growth.md](growth.md)), the best rank in each school
  as `schools` ([growth.md](growth.md) "Schools"), the life's page). Nothing else carries. A road names its
  school by id (`lives.json` `roads`); taking a road refreshes the school the fight rules use.
- **Save** (save spec §2, §5; one slot, `user://slot1/`): `soul.json`, `life.json` and
  `meta.json`, each written beside a `.tmp` copy and swapped in. Saved at each dawn, after a loss
  and on waking. The Turning writes in order: `meta.json` with `turning` (the ended life), the new
  soul, the next first morning, `meta.json` cleared. On load, a `turning` mark is finished
  (re-carried if the soul hadn't been written, else just completed), and a life whose `n` isn't
  the soul's pages + 1 is dropped for the first morning (the soul wins). The older
  `user://ruins.json` doesn't carry over. Tests (`--script`) never save, except `unit.gd`'s own
  slot.

## The year (`data/world/calendar.json`, `Run`)

- **A life is a year:** 13 moons of 28 days (`MOON_DAYS`, `MOONS`), so `lp.day` runs 1–364
  (`LAST_DAY`, the Great Eclipse). `moon()`, `moon_day()`, `moon_name()` (Ashmoon … Eclipse moon,
  with seasons), `date_name()` ("Moon 3 · Day 17"), `days_left()`. Story `days:` headers still
  name days of the year.
- **Weather** ([world.md](world.md)): the soul keeps a `seed` (made with the soul, kept by the
  Turning), so each day's weather repeats every life, and the Almanac (`soul.almanac`). At each
  dawn and on arriving in a region the game hands the day's weather to the ground
  (`world.set_sky`: rain puts out fires, wind drives them).
- **Weeks:** each moon is four weeks of seven days, the weekdays ruled by the Spheres from Sol's
  day (`weekday()`: sphere, name, colour). Nothing reads the weekday yet but the calendar.
- **Dated events** (`events`): the four calamities; each is pinned once its `known` condition holds
  (the Great Eclipse always). Fixed events per moon come with N-1.5.
- **Only actions cost time** (`world.json` `walk_clock` false): walking and fighting are free. A
  time of day passes by waiting (Z), training or meditating (each costs one), and sleeping ends
  the day. Five times of day (Morning, Noon, Afternoon, Dusk, Night); maps whose `clock` is false
  (the ruin) never pass time on their own. Climbing out of a descent ends the day.
- **Rest until…** (the map's Calendar tab): from the camp, with nothing hunting you, skip in one
  step to the next moon or a known event (`scripts/game/reach.gd` `rest_targets`); you wake on
  your cot that morning, rested. Days skipped don't play their scenes.
- **Travel** between regions costs days too ([world.md](world.md)).

## How a loop ends, and losing (`data/world/lives.json`)

- **A loop ends** (`Run.end_life(cause)`, the death screen) only for the causes in `endings`
  (`eclipse`, `turned`, `build_end`, `first_playable_end`) or any `calamity:<id>`
  (`Run.ends_life`): the Eclipse on day 364, turning back the Hours at an Orrery shrine, or a
  story ending.
- **Turning back the Hours** needs a calamity passed in this life (`turning_needs_calamity`,
  `life.calamities`, `Run.pass_calamity`; lives spec §3.1): until then the shrine says the rings
  won't stop and offers only the spellbook. No calamity is built yet (N-7.5), so for now a life
  ends at the Eclipse (Rest until… gets you there) or at a story ending; the tests pass a
  stand-in calamity.
- **The end card** (lives spec §3.3): one quiet card with the date and the cause's line
  (`ledger.json` `deaths`), "Continue" after a second; no lists. Then you wake on the cot on the
  first morning of the next life. **Knowledge stays; power resets** ([growth.md](growth.md)).
- **The life's page** is in the Ledger's **Lives** tab (6): the life, its road, how it ended,
  insight stars, a SEALED line from `lives.json` `ledger_lines` (empty until the story threads
  write them), and three columns: **Kept** (Ledger entries learnt, spells whose best Practice
  rose, insight), **Opened** (roads a deed opened) and **Left behind** (the Ring and wells
  reached, Practice, flags). The first morning's toast points at it.

## Fixed events and appointments (`calendar.json` `events` of kind `fixed`, lives spec §6.2, N-1.5)

- Each has a moon, day, time of day, `region`, `who`, a `scene` and `missed` (its default: set,
  clear, learn or deed). Each happens **once a life**. At the start of every time of day
  (`slice._fixed_events`, before forced scenes), an event whose hour has come: if you're in its
  region at that hour, the life is saved and its scene plays (`attended`); otherwise, or if the
  hour went by while you slept, rested or travelled, its default runs (`missed`).
- From then on, in every life, its date is known: pinned in gold on the calendar row, the
  Calendar tab and the Rest until… list. A missed event marked `appointment` (missing it costs
  something) goes into `soul.appointments` (name, date, time, place, who, the life) with a toast;
  it's pinned in **silver** and listed in the Ledger's **Appointments** tab (5).
- Built: **The Knights reach the camp** (Ashmoon 2, dusk, the camp; Dunmore asks for the names
  of wizards who cast fire, and from then on the Knights keep the east road's picket), **The Iron
  Gate shuts** (Thaw 2, morning, the Iron Gate, an appointment; the Iron Gate is a card, so for now
  it is always missed) and **A voice under Cinder Row** (Thaw 10, Night, anywhere in the fallen
  city; an appointment: Brogan, trapped under a beam in the sliced bakery's cellar, freed with a
  lever or by digging, then sits in the camp's market and owes you a road; missed, he's lost)
  and **Two on the watch** (Seedmoon 12, Night, the Mill fields; an appointment, part of the life 1
  main line, N-7.3.2; missed, it sets `tam_taken`).
  The Ring 1 story's other dated beats are people's scenes (N-7.2.3): Sister Nobody's fire from
  Ashmoon 4, Cass's portrait from Ashmoon 20. The main line's are N-7.3.
- Story conditions `attended(id)` and `missed(id)` (this life, or an appointment from before).

## The main line (`data/world/main_line.json`, UI spec §3.4)

- One gold step under the vitals, outside fights: the first step whose `when` holds. The
  Apprentice road's opening (N-7.3.1): Crane's first lesson (Ashmoon 3, or 4) and Marrow's
  (Ashmoon 5, or 6), Aldous's ask and his cellar (Ashmoon 8–28), the Thaw examination (Thaw 21)
  and Wren's ask (Seedmoon 1–10) and meeting (Seedmoon 11) (N-7.3.2), then the first playable's
  two (the way to the Kiln, past the Kiln) until the rest of the road replaces them.
- **The Apprentice road's opening** (`apprentice.story`, SEALED story content): the first morning
  (life 1: Wren at the tent flap, the Ledger under the pillow; sitting up fast faints you; every
  later life: the same morning, the Hours, Wren's answers to what the soul knows, the Omens, and
  the backward hand's line for lives 2–4), the glass note at the camp's edge (the hill), Crane's
  lesson (the Kindle's seven doors, one choice per stroke; how many are right decides how it
  lights; a soul that knows them draws them at once) and Marrow's (stand still on the star stone).
  The lessons are board events at the College tents (`known: true`). **The Mill cellar**
  (N-7.3.2): from Ashmoon 8 Aldous asks you down into his grain cellar (the cellar itself plays
  on arrival, in `fields.story`); the Kindle way burns it (`ignite mill_cellar`: the four seed
  sacks and the ground; the deed `burned_mill`, Aldous remembers it, and the Mill's night fight
  stops); the patient way hangs a lamp an aisle on three different days and saves the seed. Both
  write a word on the Ledger's next page. **The Thaw examination** (Thaw 21, Morning, a board
  event at the College tents): read Marrow's chart right and know Alignment to pass (`deed
  exam_thaw`; with the College's Adept rows met it also makes you Adept, growth.md Powers). **Wren's book** (S7): Wren asks you in Seedmoon; said yes, the Archive stair past
  the Kiln offers the climb on Seedmoon 11 (a scene, not a room yet); the stair ages on the way
  down and the story knocks you down three days (`downed 3 fall`), so the watch on Seedmoon 12
  goes by without you, and you wake to Mira and the news. **Two on the watch** (S8) plays at the
  east fence if you're in the Mill fields that night instead; a later life that kept it hears
  from Aldous what came up out of his cellar. Seven sealed story achievements: fainting on the
  first morning, all seven doors, carrying Brogan home, sitting for Cass, the patient way,
  passing the exam, keeping the watch.

## Calamities (`data/world/calamities.json`, `scripts/game/calamity.gd`, seasons spec §6, §8; N-7.5.1)

- A calamity keys on its calendar event (`event`) and adds its Onset slot, regions, signs,
  preparations, Peak encounter, stakes, tiers, absent default, aftermath, Ledger entry and end card.
  Built: **Lantern Night** (Seedmoon 28, Night, the camp). Its state is the life's
  (`life.calamity`).
- **Signs:** the story's `sign <id> <sign>` marks one seen; two pin an unnamed **"?"** on the
  calendar for its date (`pinned_<event>` life flag, `reach.gd`). **Preparations:** the story's
  `prep <id> <prep>`, each counted once.
- **The Eve:** a rest past a calamity whose date is on your calendar (pinned or named) stops on
  its day's Morning: "Lantern Night is tonight." (Travel doesn't stop.)
- **The Onset:** at its slot, in one of its regions, its `onset_scene` plays (the life is saved
  first): the story's `calamity_onset` puts the market's circuit lamps out for the night, and the
  Peak (`fight c1_peak`, a survive fight) begins where you stand. Falling in it ends the life
  (`calamity:lantern_night`). Anywhere else, or if the hour went by while you rested or
  travelled, it passes **without you** at its absent tier (Fallen; Scarred with four
  preparations).
- **Dawn:** surviving the Peak, the story's `calamity_dawn` reads the stakes (the camp's circuit
  lamps still lit, people lost: `life.calamity_lost`) and picks the tier: **Held** (16+ lamps and
  at most 3 lost), **Scarred** (8+ lamps or at most 10 lost), else **Fallen**. The tier's aftermath
  sets its flags (`market_held` …) and deeds (SEALED: Held opens a road), keeps `shut`, `shortage`
  and `abandons` on the life for the economy, teaches the Ledger entry, keeps the date for every
  later life and lets the Hours be turned back. A **tally card** shows the tier and the stakes.
- **Ring 1's end card** (N-7.5.4): past the tally, Lantern Night's `end_card` ends the life
  (`build_end`): "The end of Ring 1. The rest of the year comes with Ring 2."

## Achievements (`data/world/achievements.json`, `scripts/game/achievements.gd`, lives spec §7)

- The frame (N-1.2; the full list is N-7.7). Each has a kind, name, hint, `when` (a story
  condition) and `grants` (a `title` so far). The game checks every 0.5 s in the world and once as
  a life ends, before the Turning; `ended(cause)` and `omens()` let a condition need the way a life
  ended. Earning one keeps it in the soul (with life, moon and day), adds its title (worn at once
  if you wear none), lists it on the life's page under Opened, writes the soul, and copies it to
  the profile (`user://profile.json`, save spec §3). A gold toast names the deed and its title.
- Six so far, none from the story: **The First Ring** (a Ring's trial), **A Cold Kiln** (the
  Kiln Warden), **To the Last Day** (a year to the Eclipse), **Under a Bad Sky** (hidden: a
  year finished, at the Eclipse or by turning, under an Omen), and from the Field Guide **Field
  Notes** (five kinds' weaknesses found, `guide_found()`) and **Old Hand** (three kinds mastered,
  `guide_mastered()`).
- The Ledger's **Deeds** tab (7): the titles earned (click one to wear it), then every
  achievement: earned ones in gold with when, hidden ones as "?" and the hint, sealed (story) ones
  as "A deed not yet done". A road's `opens_by` may name an achievement as well as a deed.

## Omens (`lives.json` `omens`, lives spec §6.4)

- From life 2, waking on the first morning offers "Read the year's omens" (camp story `omens`,
  the story's `omen <id>` effect, `omen(id)`, `omens()` and `omens_offered()` conditions). Take
  any; each holds for the whole life. **The Hard Sky** (`enemy_hp` ×1.3 on every enemy spawned),
  **The Thin Well** (`aether_regen` ×0.5, in and out of fights) and **The Early Bell**
  (`calamity_early` 1 moon; no effect until calamities are built, N-7.5).
- Each Omen raises insight's effect by `omen_insight` (5%) of itself for that life
  ([growth.md](growth.md)). The life's page names its Omens.

## Roads (`lives.json` `roads`, lives spec §5)

- Built: the frame and two roads, **Apprentice** (the College, Astral Rite) and **Lamplighter**
  (the Lamplighters, Spark Artifice). A road opens when its `opens_by` soul flag is set by a deed (or that achievement is earned)
  (the story's `deed <id>` effect; SEALED: the Lamplighter road's deed comes with Calamity 1,
  N-7.5, so until then only the Apprentice road is open in play).
- Life 1 is always the Apprentice road. A later life offers every open road but the one taken
  last life (unless nothing else is open; from life 4, all of them); the story's `road <id>` effect
  takes one for the year (`on_road`, `offered` conditions). With none taken by moon 1, day
  `road_by_day` (7), the College's intake puts you on the Apprentice road.
- `soul.flags` (deeds), `roads_played`, `last_road`; `life.road`, `life.deeds`. What a road sets
  (school, master, ladder, quests, cantrip) comes with the schools (N-5) and Ring 1 (N-7). Built: its
  school (N-5.1) and its starting `kit` (N-5.2: the Lamplighter road teaches the four devices and
  starts with charges and reagents, `growth.take_road_kit`, run by the `road` effect).
- **The Lamplighter road in Ring 1** (`lamplighter.story`, N-7.4): on the first morning of a life
  it's offered, Fennick stands behind Wren in the tent flap and offers it (a choice off Wren's
  questions); put off, the offer waits at the Guild bench until the College's intake. Taking it
  joins you to the Guild as an Initiate (growth.md Powers). **Rule one** at the bench packs your
  first device (+5 merit). **Mira's round** (from Ashmoon 4, at Dusk in the market): while you
  walk it the town leaves the market's 24 circuit lamps (4 circuits) to you; light all 24 the same
  dusk and the round is done (+10 merit, world.gd `_on_round`). **The rails** (Thaw, by day): Fennick
  flares a circuit with an Arc Rod (+5 merit). **The Market reckoning** (Seedmoon 14, Morning, the
  Guild's exam): undercut Kestrel to end in the black, and keep a flask back for Pell if you know
  why he buys one; passing is the Guild's `exam` (Adept only with its rows met, which life 2
  rarely does). Three sealed achievements: Rule One, Twenty-Four, In the Black. Main-line steps
  point at the bench and the reckoning; the Thaw examination's step isn't shown on this road.
- `life.devices` and `life.reagents` (N-5.2, [growth.md](growth.md) "Devices") reset with the
  life; the device Models you learned stay known.
- **Any other loss** (a lethal fight lost, or a story `end_loop` with another cause) **doesn't end
  the life** (`Run.lose`, lives spec §3.2): the hurt screen shows the cause's line and what you
  learnt since your last fall, then `wake_injured.days` (2) pass, or `wild_days` (3) on a map
  marked `wild`, and you wake on your cot. A second loss the same day costs no more days. Losses
  count in `mem.deaths` like deaths, so story `died()` conditions still work.
- **Injured** until a full night's sleep: Vitality held to `vitality` (75%) of its most and
  `windup` (+0.2 s) on the first spell of each fight ([combat.md](combat.md)); the vitals say
  "Injured". Resting until a date also clears it.
- Every map keeps what you did to it (lamps, props, open doors) until the loop ends
  ([world.md](world.md)).

## The Ledger (`data/world/ledger.json`, drawn by `scripts/game/slice.gd`)

- Entries of kind clue, insight, person, model, trial or question; the story's `learn <id>`
  effect adds one to `mem.known`. Tabs: Questions, Clues, People, Insights (L).
- A **question** opens when anything in its `opens` is known and lists the `clues` that bear on
  it; a deduction picks the answer once its clues are known (`deduction_ready`, `deduce`).
- Knowing a person's entry lets the map (M) find them.

## Tests

`tools/tests/route.gd` (loop 1 through the camp and the halls, loses to the Warden on day 2 and
wakes Injured on day 4, lets the loop go at the shrine, then loop 2), `tools/tests/deaths.gd`
(each first death or fall teaches something; a fall wakes you Injured two days later; resting
until the next moon, and travelling; the Thaw examination; the stair fall that misses the watch), `tools/tests/unit.gd` (`_year`: the calendar, losses, the
roads), `tools/tests/relearn.gd`.
