# Milo's Guide — drive the game by talking to Claude

You don't have to type code. You **tell Claude what you want**, it makes the change and explains
*why*, you Play it, and you keep what you like. That's the whole job — you're the director.

## Start a session
1. Open a terminal, go to the game folder:
   ```
   cd tower-defense
   ```
2. Start the game syncing into Studio (leave this running in its own terminal):
   ```
   ./serve.sh
   ```
   Then in Studio: **Rojo plugin → Connect → press Play.**
3. In another terminal, start Claude:
   ```
   claude
   ```
4. Now just talk to it. Try: *"What can I change in this game?"*

## How to ask for stuff
Talk like a person. Claude figures out the code.
- *"Make the boss easier — it's way too hard."*
- *"Give the Sniper tower more range."*
- *"Make the runners faster but weaker."*
- *"Write a funny new line for the Merchant."*
- *"Add a new enemy that's super fast and cheap to kill."*
- *"Why does the Sword tower cost 70? Could it cost less?"*

Claude will make the change **and tell you why it works** — that's how you learn. Ask follow-ups:
*"why 25%?"*, *"what's a variable?"*, *"could it be even more?"* No question is dumb.

## Drop in screenshots
Played something weird? Take a screenshot, then **drag it into the terminal** (or paste the file
path) and say what's up: *"this tower is floating, fix it"* or *"the boss is too easy, see?"*
Claude can look at the picture and fix it — just like Dad's been doing.

## Your playground
Most of what you'll change lives in **`src/shared/Configs/`** — these are just lists of numbers
and words, super safe to mess with:
- **`Towers.luau`** — how much each tower costs, how hard it hits, how far it reaches
- **`Enemies.luau`** — how tough/fast the enemies and bosses are
- **`Cards.luau`** — how powerful the cards are
- **`Waves.luau`** — how many enemies show up and how fast it gets harder
- **`Dialogue.luau`** — every line the characters say (write your own!)

Change a number → press Play → see what happens. That's the loop.

## Saving your work (so it counts)
When you've made something cool, tell Claude: **"save this and make a PR for Dad."** It will:
1. Put your changes on a **branch** (a safe copy, so `main` — the real game — stays fine).
2. **Commit** them with a message.
3. Open a **Pull Request** — Dad gets a notification, looks it over, and merges it in.

You literally cannot break the real game doing this. Branches + the robot checker (CI) catch
mistakes before they ever go live.

## If you mess something up
No big deal — it's all saved. Tell Claude **"undo my changes"** and it'll roll back. Experiment
freely; that's how you find the fun stuff.

## The one rule
**Don't edit scripts inside Roblox Studio.** Studio is for *playing* and (later) *building maps*.
All the code changes happen by talking to Claude. (Maps are their own thing — ask Dad when you
want to start building a level.)

Have fun. Make it weird. The best ideas usually are.
