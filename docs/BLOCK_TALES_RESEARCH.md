### Block Tales Research Report

**1. Visual Aesthetic: "Retro-Roblox"**
*   **The Look:** Uses the **2008–2010 era** aesthetic. Characters are strictly **R6 blocky avatars** with "classic" faces.
*   **Materials:** Relies on `Plastic`, `SmoothPlastic`, `Wood`, and `Neon`. **Zero PBR/textures** are used, creating a clean, toy-like look.
*   **Lighting:** Modern "Future" lighting is applied to blocky geometry, creating high-contrast, moody environments (e.g., glowing neon in a dark cave).
*   **Animations:** Uses **low-FPS, "choppy" animations** (8–12 FPS) to mimic 8-bit sprites. Characters "pop" between poses rather than sliding smoothly.
*   **Color Palette:** Highly saturated, "standard" Roblox colors (Bright Red, Bright Green, Bright Blue).

**2. Chapter Structure: The "Demo" Model**
*   **Framing:** Each chapter is a self-contained "Storybook" or "File" within a larger narrative.
*   **The Demo:** Presents "Chapter 1" as a vertical slice including a town hub, a dungeon, and a cinematic boss.
*   **Gating:** Chapters end with a **hard teaser** (e.g., a silhouette of the next antagonist) and a "Thanks for Playing" card.

**3. Lore & Dialogue**
*   **Premise:** A meta-narrative where the player is from the "modern future" sent back to the "classic past" (2010) to save the timeline from corruption.
*   **Dialogue Style:** Delivered in white boxes with thick black outlines. Characters have "portraits" that change expressions.
*   **Dynamic Text:** Text "shakes" for yelling, "waves" for magic, and scrolls with a signature **high-pitched blip sound**.
*   **Tone:** Self-aware and comedic (referencing "Noobs" and "Shedletsky") but pivots to genuine drama during boss fights.

---

### Design Directives for "The Classic Defense"

#### **A. Narrative & Structure**
1.  **Lore Premise: The Great Smoothing.** The "Classic Realm" is being invaded by **"The Moderns"**—hyper-realistic, high-poly entities who want to "Update" (erase) the blocky world. You are a **"Moderator"** summoning classic legends to defend the **Database Core**.
2.  **Chapter 1: "The First Upload".** Structure the demo as 15 waves: 
    *   **Waves 1-5:** Intro dialogue from **"Builderman"** (an old, grumbling R6 avatar). 
    *   **Waves 6-14:** Introduction of "Shiny" (PBR-textured) enemies. 
    *   **Wave 15:** Boss fight against **"The Mesh-Monster"** (a flickering, high-poly sphere). Ends with a title card: *"Chapter 2: The Swamp of Despair... Coming Soon."*

#### **B. Visual & UI Directives**
3.  **The "8-Bit Snap" Animation:** All towers must have **0% interpolation**. When a tower attacks, it should snap instantly to the "swing" pose.
4.  **Classic Fidelity:** Strictly forbid `Texture` or `SurfaceAppearance` objects. Use only `SmoothPlastic`. Use **Legacy-style Studs** on top surfaces for that authentic 2008 feel.
5.  **Dialogue "Blips":** Any wave-start or boss-intro must use a scrolling text box with a **"bit-crushed" sound effect**.
6.  **The Paper UI:** All UI (Health bars, Tower menus) should be **skewed slightly** (1-3 degrees) and use a bold, rounded font like **"Patrick Hand"** or **"Luckiest Guy"** to feel like a storybook.

#### **C. Units & Enemies**
7.  **3 Starter Towers:**
    *   **The Noob Slinger:** *Cost: $150.* A classic yellow-headed Noob that throws 1x1 Plastic Bricks. Upgrade: "Color-Bomb" (Explosive bricks).
    *   **The Linked Swordman:** *Cost: $300.* Melee R6 avatar. Attacks have the classic "Swoosh" sound. Upgrade: "Illumina" (Hits blind enemies).
    *   **The Stud-Turret:** *Cost: $500.* A gray cannon that fires 2D "Stud" decals. High fire rate, low damage.
8.  **3 Enemy Concepts:**
    *   **The Shiny Crawler:** A standard blob but with **100% Reflectance**. It represents the "Modern" invasion.
    *   **The Glitch-Block:** A flickering, semi-transparent block that "teleports" (moves 5 studs instantly) every 3 seconds.
    *   **The High-Poly Blob:** A terrifyingly smooth, realistic-looking sphere that moves slowly but has massive health. Waves "distort" around it.
t Trooper"**
*   **Concept:** A blocky soldier with a 2006-style Rocket Launcher.
*   **Role:** Splash Damage. Deals high damage but has a very slow reload (the "Classic Reload" animation).

**9. Enemy Concept: "The Glitchy Guest"**
*   **Description:** A Guest 666-inspired shadow that flickers in and out of transparency.
*   **Trait:** Fast movement; occasionally "teleports" (lags) forward 2 studs.

**10. Enemy Concept: "The Overloaded Noob"**
*   **Description:** A character carrying too many "Classic Hats" (stacked high on their head).
*   **Trait:** Tanky. As it takes damage, hats fall off, increasing its move speed.
