# CLAUDE.md — BLOX PROTECTOR (family game-dev project)

Claude Code reads this file automatically at the start of every session in this repo.
It tells you how to work here. **Read it before doing anything.**

## Who's building this
A Roblox tower-defense / adventure game, built by the Donovan family:
- **Christian** (dad) — lead engineer. Owns the architecture, reviews everyone's changes.
- **Milo** (12) — balance, ideas, dialogue, and maps. He works by *talking to you in the
  terminal* and pasting screenshots — **he directs, you implement.** He's learning to code by
  doing this, not by typing it himself.
- **Xander** — 3D models + animations (Blender → Roblox Studio).

## ⭐ Learning mode (the most important rule)
This is a **learning project.** When you make a change, **explain the WHY** — the reasoning and
the game-dev / computer-science concept behind it — as a short, plain-language teaching moment.
Assume the person may be 12 and new to coding.
- Name the value you changed and what it does: *"Health is how many hits an enemy survives. I
  raised the boss from 720 → 900, about 25% tankier — try it and tell me if it feels right."*
- Teach the concept gently when it naturally comes up (a variable, a percentage, what a function
  is, cause-and-effect). One or two sentences — a nudge, not a lecture.
- Be encouraging. Take ideas seriously. Never make anyone feel dumb for asking.
- If Christian says "skip the lesson" or is clearly moving fast, drop the teaching and just do
  the work.

## The game is built to be tweaked safely
Almost everything you'd change lives in plain, commented config files — **`src/shared/Configs/`**:
| File | What's in it |
|---|---|
| `Towers.luau` | each tower's cost, damage, range, fire rate, upgrade levels |
| `Enemies.luau` | health, speed, reward, leak damage, boss sizes |
| `Cards.luau` | card power + effect (damage / freeze / heal) |
| `Waves.luau` | how many enemies per wave + how they scale |
| `Chapters.luau` | chapter structure (waves, boss, story beats) |
| `Dialogue.luau` | **every line of dialogue** — write new NPC banter here |
| `Balance.luau` / `Sounds.luau` | global knobs + sound ids |

These are **data, not logic** — changing a number is safe and shows up the instant you Play.
Prefer making balance/content changes here.

**Content (maps + models) is added in Roblox Studio, not in code:**
- **Maps** = `Workspace.Map` with a `Spawn` part, a `Base` part, and a `Path` folder of waypoint
  parts named `1, 2, 3…` (enemies walk Spawn → 1 → 2 → … → Base). The dev map
  (`src/server/DevTestMap.luau`) auto-builds one until a real map exists.
- **Models** = `ReplicatedStorage.Assets.Towers.<name>` / `Assets.Enemies.<name>`, named to match
  the config. A missing/misnamed model just falls back to a graybox box — **nothing breaks.**

## How to work (the loop)
1. Make the change (prefer a config file).
2. **Validate** — always run from the repo root before committing:
   ```
   stylua src && selene src
   ```
   Both must pass with 0 errors. The CI runs these on every push, so broken code can't merge.
3. **Reason about runtime** — we can't run Roblox Studio from here, so think through what a change
   does *in the game* before saying it works. Selene catches typos + undefined names; it does NOT
   catch logic mistakes. Be honest about what's tested vs. reasoned.
4. **Stay on a branch — never commit to `main`.** Branch, commit, push, open a PR for Christian:
   ```
   git checkout -b milo/easier-boss
   ...
   git commit -m "Make the Mainframe a bit tankier"
   git push -u origin milo/easier-boss
   gh pr create --fill
   ```
5. **Never edit Roblox scripts inside Studio.** The code lives in these files and Rojo syncs it in.
   Studio is only for building maps + models.

## Commit messages
Short and clear. End with:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## If something breaks
Nothing here is unfixable — it's all in git. `git checkout .` throws away uncommitted changes; a
bad commit can be reverted. **Encourage experimenting.** The safety net (branches + git + the CI)
is real, so it's safe to try things and see what happens.

## Validating Luau (for you, the agent)
You can lint the code before the humans ever press Play:
- `selene src` — catches syntax errors + undefined globals (uses the Roblox standard library).
- `stylua src` — auto-formats (run it so diffs stay clean).
Run both after every change. They're installed via Rokit (`rokit install`).
