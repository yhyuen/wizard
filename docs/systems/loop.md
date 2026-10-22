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
  insight, wells, what was learnt), play time and frame stats for the run summary, hints seen.
- **`life`** is this year and resets at the Turning ("hands reset"): its number `n`, `road`
  (always `apprentice` until roads are built), the day, the time of day, flags, scenes seen, what
  was learnt, Practice, wells, the book, once-a-day actions done (`done_<op>`), items taken,
  `injured`, `losses` (each lost fight: day, time, cause, days slept) and `calamities` passed.
  `Run.loop()` is the life's number.
- **The Turning** (`Run.end_life(cause)`): `scripts/game/lives.gd` `carry(soul, life, cause)` is a
  pure function that returns the new soul (deaths, insight +1 up to `insight.cap`, the Echo and
  revisions from the life's Practice, the most wells held, the life's page). Nothing else carries.
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
- **The life's page** is in the Ledger's **Lives** tab (5): the life, its road, how it ended,
  insight stars, a SEALED line from `lives.json` `ledger_lines` (empty until the story threads
  write them), and three columns: **Kept** (Ledger entries learnt, spells whose best Practice
  rose, insight), **Opened** (roads a deed opened) and **Left behind** (the Ring and wells
  reached, Practice, flags). The first morning's toast points at it.

## Roads (`lives.json` `roads`, lives spec §5)

- Built: the frame and two roads, **Apprentice** (the College, Astral Rite) and **Lamplighter**
  (the Lamplighters, Spark Artifice). A road opens when its `opens_by` soul flag is set by a deed
  (the story's `deed <id>` effect; SEALED: no deed is written yet, so only the Apprentice road
  is open in play).
- Life 1 is always the Apprentice road. A later life offers every open road but the one taken
  last life (unless nothing else is open; from life 4, all of them); the story's `road <id>` effect
  takes one for the year (`on_road`, `offered` conditions). With none taken by moon 1, day
  `road_by_day` (7), the College's intake puts you on the Apprentice road.
- `soul.flags` (deeds), `roads_played`, `last_road`; `life.road`, `life.deeds`. What a road sets
  (school, master, ladder, quests, cantrip) comes with the schools (N-5) and Ring 1 (N-7).
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
until the next moon, and travelling), `tools/tests/unit.gd` (`_year`: the calendar, losses, the
roads), `tools/tests/relearn.gd`.
