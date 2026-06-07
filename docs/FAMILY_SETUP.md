# Family Setup — BLOX PROTECTOR

How the three of us build this game together. Read this once; after that you live in
**[MILO.md](MILO.md)** or **[XANDER.md](XANDER.md)**.

## The big picture
- **One shared GitHub account** owns the repo. Everyone works under it (no separate logins yet —
  GitHub's minimum age is 13, so for now we share). Each machine stamps commits with *your* name.
- **The code lives in git.** Roblox Studio is where you *play* the game and build maps/models.
- **Three lanes:**
  | Person | Works in | Owns |
  |---|---|---|
  | Christian | VS Code + Claude (terminal) | the code + reviews everyone's PRs |
  | Milo | Claude in the terminal (+ screenshots) | balance, ideas, dialogue, maps |
  | Xander | Blender → Studio | 3D models |

Nobody can break the live game: you work on a **branch**, and Christian merges to `main` after a
quick look. A robot (CI) also checks every change for mistakes.

---

## One-time machine setup

Do this once on each computer. (Windows for the kids, Mac for Christian — both noted.)

### 1. Install the tools
- **VS Code** — https://code.visualstudio.com
- **Git** — https://git-scm.com (Mac: comes with Xcode tools / Homebrew)
- **Rokit** (installs Rojo + the lint tools) — https://github.com/rojo-rbx/rokit
  (Windows: run the PowerShell installer from the Rokit page. Mac: `curl … | sh` from the page.)
- **Claude Code** — https://claude.com/code  
  *Windows note:* Claude Code may run through **WSL** (Windows Subsystem for Linux) — follow the
  current install steps on that page. Christian: confirm the kids' install method before handing off.
- **Roblox Studio** — https://create.roblox.com  → and inside Studio, install the **Rojo** plugin
  (Toolbox → search "Rojo", or run `rojo plugin install` in a terminal).

### 2. Get the code + run setup
```
git clone https://github.com/donovantastic/blox-protector
cd blox-protector
./scripts/setup.sh        # installs the game tools + VS Code extensions
```
*(Windows: run that line inside WSL or Git Bash — both come with `bash`.)*

The script installs Rojo / Selene / StyLua / luau-lsp (via Rokit) and the VS Code extensions,
then prints the last manual steps. Safe to re-run any time.

### 3. Stamp your name on your commits (so we know who did what)
```
git config --global user.name  "Milo"        # or "Xander" / "Christian"
git config --global user.email "donovangames@example.com"   # any shared email
```

---

## The play loop (everyone)
The code on disk gets into Studio through **Rojo**:
1. In a terminal in the repo: `./serve.sh` (Mac) — or `rojo serve` — and leave it running.
2. In Studio: open the place → **Rojo** plugin → **Connect** (`localhost:34872`).
3. Press **Play**. Now whenever the code changes, it live-syncs into Studio — just re-Play.

> If a change doesn't show up, check that Rojo says **Connected** in Studio, and that `serve` is
> still running.

---

## The safe workflow (everyone)
1. **Branch** before you change anything: `git checkout -b your-name/what-youre-doing`
2. Make your change. **Validate:** `stylua src && selene src` (must be clean).
3. **Commit + push:** `git commit -m "..."` → `git push -u origin your-branch`
4. **Open a PR:** `gh pr create --fill` (or on GitHub). Christian reviews + merges to `main`.
5. Pull the latest before starting next time: `git checkout main && git pull`

**Christian's one-time GitHub setup:** turn on **branch protection** for `main` (require a PR,
require the CI to pass). Settings → Branches → add a rule for `main`.

---

## Where to go next
- **Milo** → [MILO.md](MILO.md) — tweak the game by talking to Claude.
- **Xander** → [XANDER.md](XANDER.md) — get your Blender models into the game.
- The full game design is in [GAME_BIBLE.md](GAME_BIBLE.md).
