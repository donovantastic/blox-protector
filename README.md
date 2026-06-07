# Tower Defense

A Roblox tower-defense game. **Christian codes, Xander does models + animations.**
Built data-driven so adding a tower or enemy = *drop a model in Studio + add one
config entry* — never new code.

Stack: Luau + [Rojo](https://rojo.space) (filesystem ⇄ Studio sync). Code lives here;
the map and art live in Studio.

---

## Setup — three machines

| Machine | Role |
|---|---|
| **MacBook Pro** | code (edit here; Claude works here). Runs the Rojo dev server. |
| **Mac mini** | Roblox Studio — runs the game, imports Xander's art. |
| **Windows** | Xander's Blender (modeling/animation) — stays free. |

Rojo streams code **MBP → Mini over the LAN** — edit a file, it live-syncs into Studio.
No git round-trip per change.

**MBP (code):** Rojo is installed via [Rokit](https://github.com/rojo-rbx/rokit), pinned in
`rokit.toml`. On a fresh clone, run `rokit install` to get the same version. Then:
```
./serve.sh      # serves on 0.0.0.0:34872 and prints the connect address
```
Edit `src/` in VS Code — changes live-sync to the Mini.

**Mac mini (Studio, one-time):** install the **Rojo Studio plugin** (Creator Store → "Rojo").
Open your place → **Rojo** plugin → host **`Christian-MBP.local`** (or `192.168.1.105`),
port `34872` → **Connect**. Build the map (contract below), press **Play**. Import Xander's
models here under `ReplicatedStorage.Assets.{Towers,Enemies}`, named to match the configs.

**Windows (Xander):** Blender → export **FBX** (or `.obj` for static) → hand to the Mini →
import into Studio.

> **Connect address:** `Christian-MBP.local:34872` (survives Wi-Fi reconnects) or
> `192.168.1.105:34872`. Keep `./serve.sh` running on the MBP while you work.
>
> **Graybox-first:** until there's art, the code spawns colored placeholder parts, so the
> loop runs *today*.

---

## 🗺️ Map contract (build this in Studio)

Everything the code needs, by name/tag — graybox parts are fine:

```
Workspace.Map                 (Folder or Model)
  ├─ Spawn   (Part)           enemies appear here
  ├─ Base    (Part)           enemies leak here → you lose Base HP (defend this)
  └─ Path    (Folder)         waypoint Parts named "1","2","3",… in walk order
```
Plus, anywhere in the map, **Parts tagged `BuildZone`** (use the Tag Editor) — towers
may only be placed *inside* a build zone (and off the path). [placement = next milestone]

Enemies walk: **Spawn → 1 → 2 → … → Base.**

**Art drop-in (optional, graybox works without it):**
```
ReplicatedStorage.Assets.Enemies.<name>   Model w/ PrimaryPart  (matches Enemies.luau `model`)
ReplicatedStorage.Assets.Towers.<name>    Model w/ PrimaryPart  (matches Towers.luau `model`)
```

---

## Architecture

```
src/shared/Configs/   Towers.luau · Enemies.luau · Waves.luau   ← all balance/stats here
src/shared/Remotes.luau                                          ← client⇄server events
src/server/           init.server · Map · GameState · EconomyService
                      · EnemyService · WaveManager                ← server-authoritative
src/client/           init.client · UIController                  ← HUD
```

**Two economies, kept separate:**
- **Cash** 💵 — in-round, from kills, spent on towers/upgrades, resets each match. *(built)*
- **Coins** 🪙 — persistent meta, earned per round, spent on crates + tower unlocks. *(Phase 2)*

**Two radii per tower** (in `Towers.luau`):
- `placementRadius` — fixed footprint, never changes.
- `range` (per upgrade level) — attack radius, grows with upgrades.

---

## Roadmap

**Milestone 1 — enemy/wave loop** ✅ *(this commit)*
Path movement · waves that scale · base HP / lose · cash on kill · HUD.

**Milestone 2 — towers** (next)
PlacementController (ghost preview → click, server-validated: in-zone, off-path,
afford, no overlap) · TowerService (targeting first/last/closest/strongest, fire
rate, hitscan damage) · upgrades (range ↑, damage ↑) · sell · 3 starter towers.

**Milestone 3 — meta + polish**
Persistent Coins (DataStore) · crate gacha · tower unlocks · win condition · juice
(projectiles, hit FX, sounds) — then Xander's real models + animations replace graybox.

**Later:** co-op.
