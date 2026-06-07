# Tower Defense

A Roblox tower-defense game. **Christian codes, Xander does models + animations.**
Built data-driven so adding a tower or enemy = *drop a model in Studio + add one
config entry* — never new code.

Stack: Luau + [Rojo](https://rojo.space) (filesystem ⇄ Studio sync). Code lives here;
the map and art live in Studio.

---

## Run it (first time)

1. Install Rojo (VS Code extension + the Studio plugin) on the machine with Studio.
2. `git clone` this repo, open it in VS Code.
3. Terminal: `rojo serve` → in Studio, open the **Rojo** plugin → **Connect**.
   The `src/` tree syncs into the place.
4. Build the **map** in Studio (see the contract below), then press **Play**.
   Enemies spawn and walk the path; leaks drop Base HP; the HUD shows Cash / Wave / Base.

> Graybox-first: if you haven't made enemy/tower models yet, the code spawns colored
> placeholder parts so the loop works *before* any art exists.

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
