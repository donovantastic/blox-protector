# Night Build — Milestone 2 + the Block-Tales theme

Built overnight by the trinity (Claude orchestrating + server/towers, Codex on the story UI,
Gemini on research/content/review). **Selene-clean across all 24 modules, committed + pushed.**

## TL;DR
Press **Play** and you get a complete, themed Chapter-1 demo: title card → Builderman's
intro → place towers → defend 8 waves (story beats along the way) → **CHAPTER 1 COMPLETE** +
a Chapter-2 teaser. Graybox visuals — Xander's models drop in by name later.

## How to play
1. `./serve.sh` on the MBP, Connect in Studio, press **Play** (the test map auto-builds).
2. Watch the **title card** + **Builderman's intro** (click / Space to advance the dialogue).
3. **Pick a tower** — click a hotbar slot or press **1 / 2 / 3**:
   - **Brick Slinger** (cheap rapid) · **Rocket Trooper** (slow, long-range, hits hard) · **Bomb Bloxer** (area).
4. A **ghost** follows your mouse — **green = placeable**, **red = on the path / can't afford / overlaps**.
   Left-click to place, right-click / **Esc** to cancel. (Slots 4-5 are locked — future unlocks.)
5. Towers auto-target and fire (tracers); **cash** comes from kills. **Click a placed tower** → **Upgrade**
   (range + damage up) or **Sell** (60% refund).
6. Survive **8 waves** → **VICTORY** + the demo end card.

## What's in
- **M2 towers:** 5-slot hotbar (3 starters), off-path ghost placement, targeting (first/strongest/closest),
  hitscan + tracers, upgrade levels, sell, server-authoritative validation (off-path / overlap / afford).
- **Theme — BLOX PROTECTOR:** defend the **Database Core** from **The Moderns** / the **Great Smoothing**
  (hyper-realistic invaders). Builderman dialogue (typewriter box, portraits), chapter **title + end cards**,
  lore names — towers (Brick Slinger / Rocket Trooper / Bomb Bloxer) vs enemies (Shiny Crawler / Lag-Walker /
  Mesh-Tank), retro moody lighting.
- **Juice:** enemy health bars, death pops.

## Honest caveats (I can't run Studio from here)
- Everything is **Selene-validated** and I reasoned hard about runtime — but I couldn't actually playtest.
  If anything errors, the **Output** window shows it; paste me the red lines and I'll fix on the spot.
- A **Gemini review** ran over the whole codebase — see `docs/REVIEW.md` (any real bugs it flagged I fixed
  before you woke up; see the commit log).
- **No sounds yet** — Block Tales' blip/SFX need SoundIds; quick add once you pick them.
- **Graybox** — colored placeholder parts. Drop Xander's models into
  `ReplicatedStorage.Assets.Towers.<Pelter|Sniper|Splash>` and `…Assets.Enemies.<Grunt|Runner|Brute>`
  (Models with a PrimaryPart; an enemy needs nothing special, a tower can include a part named `Turret`).
- **Map** is the auto-built S-path (`DevTestMap`) — swap in a real "Crossroads" anytime; the code finds it
  via the Map contract (Spawn / Base / numbered Path).

## Next
Sounds · more towers + enemies · the **meta layer** (persistent Coins, crate gacha, tower unlocks, DataStore)
· **Chapter 2** · Xander's real models + map · a proper start menu.

_Content/design docs: `docs/BLOCK_TALES_RESEARCH.md`, `docs/CHAPTER_1_CONTENT.md`._
