# BLOX PROTECTOR — Game Bible

> The north star. Build for **soul over reach** — something 10 people love and remember,
> not slop a million forget. Every system hand-made, every card/NPC line written with intent.
> Quirky mechanics that don't usually mesh — *that's the point.*

## Premise
Classic-Roblox nostalgia meets "the Moderns" / **The Great Smoothing** — hyper-realistic
invaders updating the blocky world into a textured void. You're a **Moderator** sent into the
old servers to push the corruption back, one chapter at a time. Lore-heavy, self-aware,
earnest-under-the-jokes (Block Tales tone).

## The genre-blend (the soul of it)
A chapter is **not one mode** — it flows through three, stitched by story:

### Act 1 — Explore (2.5D / side-scroll)
- Walk a blocky character through a stage (the **Crossroads** for Ch.1).
- **NPCs to talk to** (Builderman + others) — reuse the dialogue box.
- **Secrets to find** (hidden paths, tucked-away cards/cash, easter eggs).
- **Encounter triggers** → drop into a one-off card battle (Act 2).

### Act 2 — One-off card battles (turn-based)
- Discrete duels vs corruption mobs. A **deck + hand + energy**.
- **Vanilla cards early, weird/obscure cards as you progress** — the deck grows with the story.
- Win → back to exploration, maybe a reward card.
- Block Tales DNA: timed action-commands, expressive, comedic-but-tense.

### Act 3 — The Gauntlet (tower defense finale)
- Reaching the stage exit **locks** the world into TD mode.
- Wave after wave; **clear the path to the exit**. Survive it all → **the door unlocks** =
  **end of Chapter 1.**
- This is the existing tower-defense engine (towers, hotbar, placement, combat).

## Visual language
Mixed, by act — and deliberately so. 2.5D side-scroll exploration; a framed battle stage for
duels; the top-down/3D gauntlet for the TD. Retro-Roblox blocky + neon + moody lighting holds
it together. Pure-2D paper-cutout flourishes where they add charm (cards, portraits, cut-ins).

## What already exists (reuse, don't rebuild)
- **TD engine** = Act 3: towers (Brick Slinger/Rocket Trooper/Bomb Bloxer), 5-slot hotbar,
  off-path placement, targeting + hitscan, upgrade/sell, waves, economy, base HP.
- **Dialogue system** = NPC talk everywhere (typewriter white box, portraits, beats).
- **Chapter/card framing** (title + end cards), **retro lighting**, enemy health bars + pops.
- **Data-driven configs** (Towers/Enemies/Waves/Dialogue/Chapters/Balance) — the same pattern
  extends to Cards, NPCs, Stages, Encounters.

## Build order (playable slices — always something to click)
1. **Mode spine + explore→gauntlet:** GameMode manager; a 2.5D exploration stage; side-scroll
   camera + movement; talk to Builderman; reach the gate → it locks into the existing TD
   gauntlet; survive → door opens → Chapter 1 complete. *(in progress)*
2. **Card battles:** deck/hand/energy, turn loop, a starter set of vanilla cards + the first
   couple of weird ones; wire an encounter trigger in the exploration stage.
3. **Depth:** more cards (vanilla→obscure curve), more NPCs + secrets, a second stage,
   rewards, sound, a proper map/stage-select, save (DataStore).
4. **Later:** Chapter 2, co-op, Xander's real models replacing graybox throughout.

## Principles
- Server-authoritative for anything exploitable (battles, economy, TD).
- Data-driven: new content = config + (graybox or real) model, no engine changes.
- Selene-clean every change; reason hard about runtime (built blind until playtested).
- Hand-write the writing. The jokes and lore are the product.
