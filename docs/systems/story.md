# Story: the scene engine, effects, cutscenes (as built)

*Detail: the format is in the header of `scripts/game/story.gd` and
[design/slice/tech-plan.md](/mnt/project-files/design/slice/tech-plan.md) §2. Story content
(the `.story` files) is indexed in [content.md](content.md). Design: GDD 01, the story doc.
Tracker: S-1, W-1, R-2.*

*Target for the powers (勢力) and schools (流派): the [powers and reputation spec](/mnt/project-files/design/powers/powers-and-reputation-spec.md)
(tracker M0-14: standing per power, joining a road power and its rank ladder with dated exams,
lessons from a master, fame and infamy with witnesses and nicknames, fines and bounties, rivals,
blame for damage, what carries across lives); visual page
[Powers and Reputation Atlas](https://claude.ai/artifact/4kaEe5EARHzsXc2AN4bZq1). It adds story
conditions (`standing`, `rank`, `fame`, `nickname`, `wanted`) and effects (`+ standing`, `+ merit`,
`+ fame`, `+ join`) that are not built yet; see [drift.md](drift.md).*

*Target for the side activities (commissions, the dueling ladder, minigames, rumours and overheard
talk, confrontations, inheritances) and the people's bonds: the
[people and side activities spec](/mnt/project-files/design/people/people-and-side-activities-spec.md)
(tracker M0-17; visual [Folk and Pastimes Atlas](https://claude.ai/artifact/H9gh2FHhiCZ6Sm8iu7zkvS)).
It adds story conditions (`bond`, `taste_known`, `companion`, `rumour_heard`, `commission_done`,
`rung`, `minigame_beaten`) and effects (`+ bond`, `+ rumour`, `+ companion`, `+ commission`,
`+ confront`) that are not built yet; see [drift.md](drift.md). Its §21 is SEALED story content.*

## Scenes (`scripts/game/story.gd`)

- Each map's story folder (`maps.json` `story`) holds plain-text `.story` files of scenes:
  `=== scene_id`, header keys, then lines (`Name: text`, or narration), effects (`+ op arg`),
  choices (`* text [cond] -> next`) and outcomes (`? won -> scene`).
- **Header keys:** `place`, `days` (`4`, `1-7`, `2,3`), `times`, `when`, `force`, `priority`,
  `repeat`, `known`, `title`, `slot` (`free`: doesn't use up the time of day), `backdrop`, and what
  starts it: `talk: <person>`, `use: <item or exit>`, `arrive: <place>`, `cast: <element>` (with
  `use:`; `cast: hours` is Rewind's shard on the item).
- **Conditions** are Godot expressions over `k(id)` (remembered), `f(id)` (flag this loop),
  `seen(id)`, `died(cause)`, `can_turn()` (a calamity has passed, so the Hours can be turned back),
  `count(prefix)`, `done(op)`, and `loop`, `day`, `time`, `ring`. A
  line, effect or outcome can start with `[condition]`.
- **Effects:** `learn`, `set`, `clear`, `fight`, `wells`, `train`, `meditate`, `goto`, `end_loop`,
  `model`, `trial`, `sound`, `cutscene`, `move`, `take`, `sleep`, `book`, `today` (a once-a-day
  action, for `done(op)`), `go <map> <spot>` or `go <exit>`, `open <door>` (that door stands open for the life, even a gate whose prop still stands), `play_path <id>`, `road <id>` (take a road
  for this life, [loop.md](loop.md)), `deed <id>` (a soul flag the Turning keeps; SEALED deeds
  open roads), `omen <id>` (take an Omen for this life), `forecast <who>` (that person says
  tomorrow's weather, [world.md](world.md)), `bench` (work at a bench: fill your devices from
  your reagents and take the time of day; `bench stock` gives the Lamplighters' spare reagents,
  [growth.md](growth.md) "Devices"). Conditions also have `mastered(school)` (that school at Master in this life or an earlier
  one, N-5.3), `guide_found()` and `guide_mastered()` (Field Guide counts, N-6.5,
  [combat.md](combat.md)), `on_road(id)`,
  `offered(id)`, `omen(id)`, `omens()`, `omens_offered()`, `ended(cause)`, `attended(id)` and `missed(id)` (fixed events, [loop.md](loop.md)) (only while a life's
  ending checks achievements). Achievements' conditions (`data/world/achievements.json`) are
  linted with the scenes'.
  A new effect or header key is a change to this spec.

## Playing them (`scripts/game/slice.gd`)

- The game flow answers the world's requests by picking the best eligible scene, shows it in the
  dialogue panel (number keys pick, Space carries on), runs its effects, and handles what comes
  after it closes (sleep, the spellbook, a map change). Everything a player can do is also a
  method (`talk`, `use`, `choose`, `advance`), so the route bot plays the same code.

## Cutscenes (`scripts/game/cutscene.gd`)

- Short scenes in the fight view where time runs the wrong way: the Fire and the Mourner, and
  recorded paths (`path:<id>` from the map's `paths` file) played forward or in reverse. Poses go
  through unit flags (`pose`, `face`); nothing here changes the rules.

## Tests

`tools/tests/story_lint.gd` (every scene against its own map's people, items, spots and exits;
parse errors), `tools/tests/route.gd`.
