# System specs (as built)

One short spec per game system: its rules, its key numbers (or the data file that holds them),
its data files and its code entry points. **These specs are the source of truth for how the game
works now.** Read the spec before the code; open only the code you are changing.

| Spec | System | Tracker rows |
| --- | --- | --- |
| [combat.md](combat.md) | The fight, the spellbook, Aether and Cadence, spells and spheres, Magicks, enemies, encounters | C-1–C-5 |
| [growth.md](growth.md) | Wells, Rings, Practice, the Echo and insight; spell levels and milestones | S-1, C-1 |
| [loop.md](loop.md) | The two layers of state, days and the clock, how a loop ends, the Ledger, the save | S-1, R-1, R-2 |
| [world.md](world.md) | Maps and exits, collision, doors and cracks, people, props, magic meeting the world | W-1, W-2, R-1, R-2 |
| [story.md](story.md) | The scene engine: format, conditions, effects; playing scenes; cutscenes | S-1, R-2 |
| [frame.md](frame.md) | Boot, game flow and screens, input, graphics settings, HUD, sound, CI checks | C-4, V-2, M0-1 |

**Content specs** (index pages for content the check exempts: where it lives and its
conventions; `map.json` `content` says which paths each covers):

| Spec | Content |
| --- | --- |
| [content.md](content.md) | Map layouts, people, scenes, Ledger text |
| [art.md](art.md) | The 3D view, meshes, figures, shaders, the look's tuning, assets |

**[drift.md](drift.md)** lists where the GDD and older docs differ from these specs.

The GDD (design intent) is in the project files, `/mnt/project-files/design/gdd/`. A spec says
what is built; the GDD says what was meant. Where they differ, the spec is right about the game
and the difference is a question for Harold. Status (what's planned, building, built, waiting on
Harold) is in the **[Wizard Game Tracker](https://claude.ai/artifact/Joz7oeRcgYLuq71qqAZEY8)**; how to update it is in
`/mnt/project-files/pm/TRACKER.md`.

## The rule

1. **Read first.** Before changing a system, read its spec here, then the detail page it points
   to. Don't read code to learn a system.
2. **Update in the same PR.** A PR that changes behaviour (code or tuning data) updates the spec
   (or one of the docs the spec lists in `map.json`) in the same PR. `tools/ci/spec_check.py`
   fails CI otherwise.
3. **When building shows the design was wrong**, change the spec to what you built and write the
   question in the tracker row's `needs` field for Harold.
4. **New system or new folder**: add a spec (or a section to the closest one) and a line in
   [map.json](map.json), which says which spec owns which paths.

## The check

`python3 tools/ci/spec_check.py` compares your branch with `origin/main` (its merge base; run
`git fetch origin main` first) and also counts uncommitted and untracked files. For every changed
file under `scripts/`, `data/` or `scenes/` it finds the owning spec(s) in `map.json`; at least
one of those specs' docs must also have changed. It also fails when a file in those folders is
owned by no spec and not listed as exempt, so new systems get a home. CI runs it first.

- **Pure refactors** (no behaviour change): put a line `Spec-Skip: <why>` in a commit message
  on the branch, or run with `SPEC_SKIP="<why>"`. The reason is printed with the result.
- **Exempt paths** (`map.json` `exempt`) are content and presentation: map layouts, people,
  scenes, Ledger text, the 3D view, shaders, `.uid` files. If your content needs a new key or
  rule, that key belongs in the spec.
- Options: `--base <ref>` to compare with another base, `--files a b ...` to check a given list,
  `--coverage` to list unowned files only.
