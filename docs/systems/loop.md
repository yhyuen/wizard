# The loop: days, waking, the Ledger, deaths, save (as built)

*Detail: [design/ruins/README.md](/mnt/project-files/design/ruins/README.md) (the first
playable's rules and success criteria), [design/ruins/content.md](/mnt/project-files/design/ruins/content.md)
§6 (the Ledger). Design: GDD 01 and 04. Tracker: S-1 (the two-layer save, deductions), R-1, R-2.*

*Target for the long-loop direction: the [lives, carry-over and achievements spec](/mnt/project-files/design/lives/lives-and-carryover-spec.md) (tracker M0-10: a year of 13 moons, three
ways a life ends, waking injured, the soul/life carry table, insight, roads, achievements) and the
[save system spec](/mnt/project-files/design/lives/save-spec.md) (tracker M0-11: three slots, soul / life / map-damage files, the crash-proof
Turning, save moments, versions, desktop and browser); visual page [Lives, Saves and HUD Atlas](https://claude.ai/artifact/7H3xpu7YpYVzGmtDRUq8fK). Nothing of it is built yet;
[drift.md](drift.md) has the summary. Until code lands, this page is right about the game.*

## Two layers of state (`scripts/game/run.gd`, the `Run` autoload)

- **`mem`** is what you remember and keeps across loops: the loop number, known Ledger entries,
  deaths by cause, trials passed, Fluency, best wells, revisions, a log of each loop (day, time,
  cause, what was learnt), play time and frame stats for the run summary.
- **`lp`** is this loop and resets on waking: the day, the time of day, flags, scenes seen, what
  was learnt this loop, once-a-day actions done (`done_<op>`), items taken.
- **Save:** `user://ruins.json` at each dawn, at the end of a loop and on waking. A save from the
  older town month (`slice.json`) doesn't carry over. Tests (`--script`) never save.

## A loop

- **The clock:** five times of day (Morning, Noon, Afternoon, Dusk, Night), each `period_s` 40 s
  of walking (`data/world/world.json`); the clock stops while you talk, read, look at the map or
  fight, and in maps whose `clock` is false (the ruin). Sleeping on your cot ends the day.
  Climbing out of a descent ends the day too.
- **28 days** (`LAST_DAY`) to the Eclipse.
- **A loop ends** (`Run.end_loop(cause)`) by dying in a lethal fight (`fight:<id>`), letting it go
  at an Orrery shrine (`shrine`), the Eclipse (`eclipse`) or a story `end_loop` effect. The death
  screen lists what you learnt that loop and the cause's line (`ledger.json` `deaths`); then you
  wake on the cot on day 1 of the next loop. **Knowledge stays; power resets** ([growth.md](growth.md)).
- Every map keeps what you did to it (lamps, props, open doors) until the loop ends
  ([world.md](world.md)).

## The Ledger (`data/world/ledger.json`, drawn by `scripts/game/slice.gd`)

- Entries of kind clue, insight, person, model, trial or question; the story's `learn <id>`
  effect adds one to `mem.known`. Tabs: Questions, Clues, People, Insights (L).
- A **question** opens when anything in its `opens` is known and lists the `clues` that bear on
  it; a deduction picks the answer once its clues are known (`deduction_ready`, `deduce`).
- Knowing a person's entry lets the map (M) find them.

## Tests

`tools/tests/route.gd` (loop 1 through the camp and the halls, the shrine on day 2, into loop
2), `tools/tests/deaths.gd` (each first death teaches something), `tools/tests/relearn.gd`.
