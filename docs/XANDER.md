# Xander's Guide — Blender models into the game

Your job is the coolest part: the towers and enemies people see are **your models**. You build
them in Blender, then drop them into the game in Roblox Studio. The game is set up so that **the
moment your model is in the right place with the right name, it shows up** — and if something's
off, it just falls back to a placeholder box instead of breaking. So you'll always *see* whether
it worked.

> **The first import, do with Dad.** Steps 4-5 (export → Studio import) have a few settings that
> are fiddly the first couple of times. After that you'll have the rhythm.

## What the game needs from each model
Every model needs:
1. A **name** that matches the game (we'll tell you the name — e.g. `Pelter`, `Sniper`, `Grunt`,
   `Brute`, `Boss`).
2. A **PrimaryPart** (one part marked as the "anchor" of the model).
3. For **towers**: a part named **`Turret`** (the bit that rotates to aim). Enemies don't need this.

That's the whole contract. Get those right and the code does the rest.

## Step 1 — Build it in Blender
- Keep it **low-poly** and blocky — it fits the game's look *and* runs fast. Think classic Roblox.
- Build it roughly **person-sized** for enemies, or a bit chunkier for towers. (We can rescale in
  Studio, but closer is better.)

## Step 2 — Clean it up (this prevents 90% of problems)
- Select everything: press **A**.
- **Apply transforms:** `Object menu → Apply → All Transforms` (or **Ctrl+A → All Transforms**).
  This "bakes in" your scale/rotation so it imports correctly.
- Make sure the model sits roughly at the **center** (the 3D cursor / origin).

## Step 3 — Color / texture (optional for now)
- Simple colored materials are totally fine to start — the game looks good in flat blocky colors.
- Fancy textures can come later (bake them in Blender, or just use Roblox materials in Studio).

## Step 4 — Export from Blender
- `File → Export → FBX (.fbx)`  *(use `.obj` instead if it never moves/animates)*
- In the export options: **Selected Objects** checked, scale left at default to start.
- Save it somewhere easy to find.

## Step 5 — Import into Roblox Studio
- In Studio: **Avatar tab → Import 3D** (the 3D Importer) → pick your `.fbx`.
- It'll show a preview. Check the **size** — it should look right next to a default character. Use
  the importer's scale slider if it's tiny or huge.
- Click **Import.** You now have a **Model** made of MeshParts.

## Step 6 — Put it in the game
- In the **Explorer**, find your imported model.
- Set its **Name** to the one we gave you (right-click → Rename, or the Properties panel).
- Set a **PrimaryPart**: click the model, in Properties find `PrimaryPart`, pick the main body part.
  (For towers, also name the aiming part `Turret`.)
- Drag the model into: `ReplicatedStorage → Assets → Towers` (or `Assets → Enemies`).
  *(If those folders don't exist yet, make them: right-click ReplicatedStorage → Insert Folder,
  name it `Assets`, then a `Towers` and `Enemies` folder inside.)*

## Step 7 — Check it (this is the fun part)
Press **Play.** Place that tower (or wait for that enemy) — **your model should appear in the game
instead of the gray box.** That's your "did I do it right?" — if you see your model, it worked. If
you still see a gray box, the name or folder is off; fix it and Play again.

## Saving your model so it's in the real game
Tell Claude (or ask Dad) to **save your model into the project** so it ships with the game and
isn't just on your computer. Then it goes through the same branch → PR → Dad-reviews flow as
everything else.

## Quick fixes
- **It's the wrong size in-game** → re-import with a different scale, or scale the model in Studio.
- **It's a gray box** → the Name or the folder is wrong. Double-check against what we told you.
- **It's sideways / sunken** → you probably skipped *Apply Transforms* in Blender (Step 2).

Your models are what make this feel like a real game instead of a bunch of blocks. No rush — get
one tower looking great and the rest follow the same steps.
