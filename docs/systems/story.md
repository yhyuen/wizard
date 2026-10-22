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
  `count(prefix)`, `done(op)`, `since(op)` (days since `today op`, 9999 if never), `remembers(who, deed)`, `rank(power)`, `standing(power)`, and `loop`, `day`, `time`, `ring`. A
  line, effect or outcome can start with `[condition]`.
- **Effects:** `learn`, `set`, `clear`, `fight`, `wells`, `train`, `meditate`, `goto`, `end_loop`,
  `model`, `trial`, `sound`, `cutscene`, `move`, `take`, `sleep`, `book`, `today` (a once-a-day
  action, for `done(op)`), `go <map> <spot>` or `go <exit>`, `open <door>` (that door stands open for the life, even a gate whose prop still stands), `ignite <place>` (everything that burns in the current map's place rect catches, and the ground under it; not counted as unseen damage), `downed <days> <cause>` (when the scene closes: the hurt screen with the death text for `cause`, then `days` pass and you wake on your cot, Injured; not counted as a death), `standing <power> <n>`, `merit <n>` and `exam <power>` (the next rank in your road's power if its rows are met; [growth.md](growth.md) Powers), `sign <calamity> <sign>`, `prep <calamity> <prep>` (takes the time of day), `calamity_onset <calamity>` and `calamity_dawn <calamity>` ([loop.md](loop.md) Calamities), `remember <who> <deed>` (a person's memory of you, [world.md](world.md) People), `bond <who>
  <source> [key] [amount]`, `bond_cross <who>`, `betray <who>` and `gift <who> <item>` ([world.md](world.md) Bonds), `rumour <id>` (Rumours below), `commission <id> take|next|clean|lose|slow|work|pay` (Commissions below), `ladder bout|win` (The camp ladder below), `game <who> free|work|coin` (Minigames below), `companion <who> join|part` ([world.md](world.md) Companions), `play_path <id>`, `road <id>` (take a road
  for this life, [loop.md](loop.md)), `deed <id>` (a soul flag the Turning keeps; SEALED deeds
  open roads), `omen <id>` (take an Omen for this life), `forecast <who>` (that person says
  tomorrow's weather, [world.md](world.md)), `bench` (work at a bench: fill your devices from
  your reagents and take the time of day; `bench stock` gives the Lamplighters' spare reagents,
  [growth.md](growth.md) "Devices"). Conditions also have `mastered(school)` (that school at Master in this life or an earlier
  one, N-5.3), `guide_found()` and `guide_mastered()` (Field Guide counts, N-6.5,
  [combat.md](combat.md)), `on_road(id)`,
  `offered(id)`, `omen(id)`, `omens()`, `omens_offered()`, `ended(cause)`, `attended(id)` and `missed(id)` (fixed events, [loop.md](loop.md)), `rumour_heard(id)` (Rumours below), `commission_step(id)`, `commission_posted(id)`, `commission_done(id)`, `commission_known(id)`, `commission_lost(id)`, `commission_clean(id)` and `commission_board_empty()` (Commissions below), `rung()`, `ladder_open()` and `ladder_book(n)` (The camp ladder below), `game_open(who)`, `game_work(who)`, `game_coin(who)` and `minigame_beaten(who)` (Minigames below), `companion()` and `companion_can(who)` ([world.md](world.md) Companions), `bond(who)` (your bond tier with them, 0–5) and `bond_ready(who)` (lamp full, a crossing scene
  can open the next tier; [world.md](world.md) Bonds), `calamity_in(id)` (days until
  that calamity, after the Early Bell) and `calamity_variant(id)` (its later-lives variant, 0 before
  it has been Held; [loop.md](loop.md) Calamities) (only while a life's
  ending checks achievements). Achievements' conditions (`data/world/achievements.json`) are
  linted with the scenes'.
  A new effect or header key is a change to this spec.

## Playing them (`scripts/game/slice.gd`)

- The game flow answers the world's requests by picking the best eligible scene, shows it in the
  dialogue panel (number keys pick, Space carries on), runs its effects, and handles what comes
  after it closes (sleep, the spellbook, a map change). Everything a player can do is also a
  method (`talk`, `use`, `choose`, `advance`), so the route bot plays the same code.

## Rumours (`data/world/rumours.json`, `scripts/game/rumours.gd`, people spec §10; N-7.6.2)

- A rumour has a kind (date, person, lead), its text, what it points at (an event, a person and
  maybe a taste, a place) and a pool (region and moon band). The story's `rumour <id>` hears it:
  kept in the soul for every life, a toast, and a date rumour pins its event on the calendar
  (`soul.dates`). `rumour_heard(id)` reads it.
- **Overheard talk** (`data/world/story/rumours.story`): scenes at a place in a window of days and
  times, `slot: free`, that play once and never again once their rumour is heard in any life. Ring
  1 has seven: the Knights' arrival, the Iron Gate, the voice under Cinder Row, the east fence,
  the Market's lighting, and two about people.
- The Ledger's **Rumours** tab (9) lists them by kind; one heard in an earlier life says so.
- `draw(pool, kind)` (kind optional) takes the unheard rumour pointing at the soonest event still ahead (for minigames
  and companions, later).
- **Data check** (story_lint): every fixed event that is an appointment has a rumour pointing at
  it, from a scene that can play at least 7 days before.

## Commissions (`data/world/commissions.json`, `scripts/game/commissions.gd`, people spec §6; N-7.6.3)

- Small paid jobs, texture and never story: a commission's scenes teach nothing, open no road and
  give no merit (the lint checks). Ring 1 has the eight of people spec §6.3. Each has a giver (a
  role, in words), a board, a window of days it is posted in, steps (each a line, a map and a
  place), pay in crowns and a matter hook.
- **Taking and paying**: the camp's **commissions board** (item `board` in the square) lists the
  posted jobs with their pay and takes the reports; the Night Round is on the watch post's
  **duty slate** (`duty_slate`). Scenes in `data/world/story/commissions.story`. Nothing is
  posted in the week before a calamity ("NOT NOW. LANTERN NIGHT."). A job taken stays open until
  it is done; each happens once a life.
- **The steps**: arrive scenes at each step's place (priority 6, in that map's story), most of
  them a fight (`com_*` encounters, none lethal: [combat.md](combat.md)). Won: `next`. Lost: you
  wake a day later, Injured, the step still open, and the **slow way** offered (half a day, half
  pay). Steps with real work take the time of day (`work`) unless the job was done in an earlier
  life, when the scene also says what you remember (spec §6.1 rule 5; `Run.soul.commissions`).
- **The matter hook** pays +50%: a `spare` hook holds while nothing of its kinds in its place is
  burning, burned or broken as the step there ends (the hay and trees in the orchard, the Mill's
  fence by the bramble, the quarry's stores, the granary's hay and barrels); the others are
  choices in the scene (light the round's lamps, prop the beam, freeze or drain the flood).
- **Crowns** are kept for the life (`Run.life.crowns`); nothing sells for them yet.
- The HUD's **jobs line** (under the main line's gold step) shows the job taken last and its
  step; the Ledger's **Work** tab (0) lists doing, posted and done, with the crowns earned.
- **Data check** (story_lint): every commission is taken and paid by some scene, enough scenes
  move it on, every step's place is on its map, the hook's place is a step's, and no commission
  scene gives what the main line needs.

## The camp ladder (`data/world/ladders/camp.json`, `scripts/game/ladder.gd`, people spec §7.1; N-7.6.4)

- Six rungs in the chalk ring in the College yard, each a named duelist showing a style: a stave
  brawler (no magic), a hedge-witch (oil on the ground), a Lamplighter journeyman (sparks, then a
  long reload), a Knights' squire (shield), a Drowned novice (frost from far off) and, at the top,
  Silas Vane. Their fights are `ladder_1`..`ladder_6` ([combat.md](combat.md)).
- The **ladder slate** (`ladder_post`, in the ring) lists them. At Dusk, once a week (7 days
  since the last bout), you may challenge the rung above yours; a bout costs no time. Win: you hold
  the rung, its purse (10/15/20/30/40/60 crowns) and, for every later life, the duelist's
  **book** (what they open with, their range, their tell), which their scene then says. Lose: you
  pick yourself up, bruised, no days lost, your rung kept.
- The rung (`Run.life.rung`) resets each life; books carry (`Run.soul.ladder_books`). The Work tab
  shows the rung and the books; holding the top rung is the **Top of the Slate** achievement.
- **Data check** (story_lint): every rung has a duel of its kind and a scene that fights it.

## Minigames (`data/world/minigames/*.json`, `scripts/game/minigames/`, people spec §9; N-7.6.5)

- Two games in the camp, offered in each opponent's talk scene (`data/world/story/minigames.story`
  holds the matches). `game <who> free|work` stops the scene like a fight (button "Play") and
  opens the game panel; `? won` / `? lost` carry on after it. F1 in the panel is easy mode (tells
  always shown, one wrong answer struck out); 0 concedes.
- **Star-charts** (Wren, Brogan, Lector Marrow; Dusk and Night only): best of three sky riddles
  (a constellation, a moon phase or a Sphere). Clues come one at a time; answer or wait. Wait past
  the opponent's buzz (seeded per riddle) and they answer first, right with their `sure` chance; a
  wrong answer gives the riddle away. A riddle answered right is remembered for every life (its
  answer is marked, `Run.soul.charts`); the Lantern's answer also gives a date rumour.
- **Sparks** (Mira, Pell, Kestrel): liar's dice, four brass dice each, ones (lamps) wild. Raise
  (more dice, or as many on a higher face) or call dark; whoever was wrong loses a die. Opponents
  call by `nerve` and bluff by `bluff`.
- **Rules** (`games.gd`): free play once a week per opponent, costing no time; a win pays the
  stake and a loss costs it (if you have it); either is the `minigame_win`/`minigame_loss` bond.
  **Work** (Kestrel's market table): half a day (two times of day), a wage, and a rumour every time.
  The **first win** against someone each season picks a rumour (When, Who or Where: the most useful
  unheard one of that kind). The first win also learns their **tell** for every life
  (`Run.soul.tells`): the panel then shows its sign when it means something (Star-charts: they'll
  answer if you wait; Sparks: their bid is a bluff). Beaten in a past life (`Run.soul.games_beaten`),
  a Star-charts opponent will **pay for coin** without a game (the stake, no rumour, no bond; it
  takes the week's game); never at dice. No games in a calamity's week. The Work tab lists who
  you've beaten.
- **Data check** (story_lint): `game` args (work only where there is work, never coin at dice, both
  outcomes), every opponent is a person with a scene that plays them, every riddle has three clues
  and its answer among the options, and each opponent has riddles enough. `people.gd` plays both
  cores alone with bots, and the frame through the slice.

## Cutscenes (`scripts/game/cutscene.gd`)

- Short scenes in the fight view where time runs the wrong way: the Fire and the Mourner, and
  recorded paths (`path:<id>` from the map's `paths` file) played forward or in reverse. Poses go
  through unit flags (`pose`, `face`); nothing here changes the rules.

## Tests

`tools/tests/story_lint.gd` (every scene against its own map's people, items, spots and exits;
parse errors; the 7-day rumour check; the commissions' and the ladder's checks), `tools/tests/route.gd`, `tools/tests/people.gd`.
