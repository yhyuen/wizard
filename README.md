# Wizard: Readable Arsenal prototype

A small browser prototype of the wizard game, built from the "Readable Arsenal" design: one element pair (**Fire + Earth**), one fight (**Ambush at the Mill**), pixel art, and progression you can see. Godot 4.7, GDScript, web export.

## Play it

- **In the browser:** every push to `main` publishes the web build to GitHub Pages (turn Pages on once: *Settings → Pages → Source: GitHub Actions*). Every PR also uploads the build as the `wizard-web` artifact; unzip it and run `python3 -m http.server` in the folder, then open http://localhost:8000.
- **In the editor:** open this folder in Godot 4.7 (standard edition) and press F5.
- **Export yourself:** `godot --headless --export-release "Web" export/web/index.html` (needs the 4.7.2 web export template).

## Controls

| Input | Slot |
| --- | --- |
| WASD | Move |
| Mouse | Aim |
| LMB | **Ember Bolt** (Fire bolt). Adds a flame pip; 3 pips = **Ignite** |
| RMB | **Pebble** (Earth bolt). Heavy knockback; a hit drops a **lodestone** that orbits you |
| Q (hold, release) | **Pillar**: a fire column on a circle telegraph after a delay. Adds 2 pips |
| E (hold, release) | **Fling**: pushes your orbiting lodestones out in a cone |
| R (hold, release) | **Signature**: Pyroclasm (bounces between pip-marked enemies) or Avalanche (every lodestone slams one target). **Tab** swaps them |
| F (hold, release) | **Meteor**, the Fire + Earth Magick. Locked until you discover it |
| Space | Blink (charges grow with wizard level) |
| 1 / 2 | Pick a milestone mutation |
| F1 | Practice: every spell +1 level (to see milestones and mutations quickly) |
| F2 | Autoplay: a bot plays; press again to take over |

Holding Q, E, R or F shows the exact telegraph; the telegraph is the hitbox.

## The fight

Two waves of Dust Hollows (melee, red wedge telegraphs) and Hollow Slingers (red aim lines), then a duel with **Silas Vane, the Storm Rider**: a Spark skill shot, an Arc Lance line, Storm Call circles, and a blink out of your Pillars. At half HP he calls more Hollows. Win or fall, the **Loop Ledger** records the run and you wake again in the next loop.

## What to look for (the "readable" part)

- **Level-ups are visible.** A spell levels from its own hits. You get a toast with the stat change ("Speed 209 › 218"), the card flashes, and for the next few casts a dashed ghost shows the *old* size: an old-speed ghost bolt that the new one outruns, the old Pillar radius, the old Fling cone.
- **Milestones at 5, 10 and 15** pause the fight for a pick between two mutations. The card's name gets a star and lists the mutation. Ember Bolt usually reaches 5 in the first fight.
- **Field objects** are counted by your HP bar: lodestones (cap 3, Avalanche raises it to 7) and embers (cap 6).
- **Impact vs Poise.** Hollows have Poise 0, Silas has Poise 1. Ember Bolt (Impact 1) only makes Silas show a small "x", Pebble (2) makes him flinch, Pillar (3) staggers him and breaks his wind-up; Updraft (4) knocks him down.
- **Enemy HP in chunks of 10.** Hovering an enemy shows hits-to-kill with your current Ember Bolt (×N).
- **Hit-stop and shake** scale with the share of the target's HP removed, not raw damage.
- **The loop as a measuring stick.** Spell levels, mutations and Magicks carry over; the wizard level drops to half. The Ledger lists every loop and draws a sparkline of win times.

## Defaults chosen for the design doc's open questions

1. Elements equipped: two (already decided).
2. **Wizard level halves each loop** (rounded down, minimum 1). Spells keep their levels.
3. **Milestone picks are re-pickable only at an Orrery shrine.** There is no shrine in this prototype, so picks are permanent for now; the picker says so.
4. **Magicks are discovered in combat, with tomes as a later fallback.** Meteor unlocks when fire touches a lodestone (catch one in a Pillar, or let an ember land on one). The F card shows a hint so nobody gets stuck.

## Not in this prototype

The other four elements (Storm, Frost, Water, Time), Orrery shrines, relics and Focus, the town and the 28-day calendar, audio, and Silas as a full Storm kit (he only uses three of its moves). All numbers are starting values in `data/spells.json`.

## Files

| File | What it does |
| --- | --- |
| `data/spells.json` | Every tuning number: spells, stat tracks, milestones, Meteor, enemies, reactions |
| `scripts/autoload/progression.gd` | Spell XP and levels, mutations, mastery, wizard level, loops, the Ledger, saving |
| `scripts/arena.gd` | The Mill fight: units, hits and reactions, pips and Ignite, projectiles, telegraphs, lodestones, drawing |
| `scripts/kit.gd` | The Fire + Earth loadout: casting, hold-to-aim previews and level-up ghosts |
| `scripts/ai.gd` | Hollows, Slingers and Silas Vane |
| `scripts/hud.gd` | Spell cards, HP and caps, duel bar, toasts, milestone picker, title, Ledger |
| `scripts/pixel_art.gd` | Hand-placed pixel sprites and the yard, baked into textures at start |
| `scripts/bot.gd` | The bot used by the fight test and F2 autoplay |
| `tools/tests/` | `unit.gd` (progression rules) and `fight.gd` (bot plays the whole fight) |

Progress saves to `user://progress.json` (in the browser, the site's IndexedDB). Delete twice on the Ledger screen wipes it.

## Tests

```
godot --headless --script res://tools/tests/unit.gd
godot --headless --fixed-fps 60 --script res://tools/tests/fight.gd -- --loops 2
```

CI runs both on every PR (via `tools/ci/godot.sh`, which also fails on script errors) and builds the web export.
