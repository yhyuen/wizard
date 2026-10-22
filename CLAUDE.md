# Working in this repo

## Specs first

The per-system specs in [docs/systems/](docs/systems/README.md) are the source of truth for how
the game works now: rules, key numbers, data files, entry points.

1. Before changing a system, read its spec in `docs/systems/`, then the detail page it links.
   Open only the code you are changing; don't read code to learn a system.
2. A PR that changes behaviour (code or tuning data) updates the owning spec in the same PR.
   `python3 tools/ci/spec_check.py` enforces it (owners in `docs/systems/map.json`); CI runs it
   first. A pure refactor says so with a commit line `Spec-Skip: <why>`.
3. When building shows the design was wrong, change the spec to what you built and put the
   question in the tracker row's `needs` field for Harold.
4. A new system or folder gets a spec (or a section) and a line in `docs/systems/map.json`.

## Design and status

- Design intent is the GDD in the project files (`/mnt/project-files/design/gdd/`). The specs say
  what is built; where they differ, the spec is right about the game and the difference goes in
  [docs/systems/drift.md](docs/systems/drift.md) or the tracker's `needs`.
- Status lives in the [Wizard Game Tracker](https://claude.ai/artifact/Joz7oeRcgYLuq71qqAZEY8) (how to update it: `/mnt/project-files/pm/TRACKER.md`).
  Every PR names its tracker row(s); when it merges, move the row and add a ship-log line.

## Merging

- CI on GitHub runs every check ([docs/systems/frame.md](docs/systems/frame.md) 'Checks before
  merging'). Once it is green and nothing is left open on the PR, merge it; `main` redeploys the
  web build to GitHub Pages.
- Display text is English, in the game's Western tone.
