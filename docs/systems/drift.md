# Design vs build: where they differ (2026-10-22)

*The first pass, written when these specs were added. The GDD (`/mnt/project-files/design/gdd/`)
says what was meant; these specs say what is built. Where they differ the spec is right about the
game, and the difference is either logged here as a known change or a question for Harold in the
tracker's `needs`.*

## The direction moved on; the build is the ruins first playable

- **What's built** is the ruins first playable (GDD v2, 2026-10-19; milestones R1 and R2, PRs
  #23–#26): the survivors' camp, the College halls, a 28-day loop to the Eclipse.
- **What's meant now** is the long-loop open-world RPG (Harold, 2026-10-20 and 2026-10-22: a
  year-long loop of 13 moons, many factions and schools, magic taken seriously and touching the
  world, the same person every life taking a different road). GDD v3 and its roadmap are being
  written in the "Full game build plan" thread. Until code for it lands, the specs describe the
  ruins build, and the R rows on the tracker are parked.

## Known differences inside the build

| Doc says | As built | Where |
| --- | --- | --- |
| Root README 'The design decisions, as built': spell levels carry over, the wizard level halves each loop | True only for the old Mill fight (`Progression`). The ruins game's loop resets Practice, wells and Ring, with the Echo making relearning faster (Harold 2026-10-15) | [growth.md](growth.md) |
| Root README 'Not in this prototype': days 8 to 28 | The loop runs all 28 days; the content is in the camp and halls only | [loop.md](loop.md) |
| GDD 02: seven Spheres | Four Spheres plus the Hours (Rewind) | [combat.md](combat.md) |
| GDD 03: Magicks in the loadout | Turned off in the ruins game (C is the Ward); Meteor and Conductor only in the old Mill fight | [combat.md](combat.md) |

## Questions for Harold

None open from this pass; the open question is the direction itself (tracker M0-3).
