### BLOCKER

*   **`src/server/WaveManager.luau:76`**
    *   **Description:** Mid-wave dialogue (`chapter.beats`) fires to clients and instantly starts the wave without yielding; the client's screen-filling `InputBlocker` traps all clicks, preventing players from placing or upgrading towers while enemies attack.
    *   **Severity:** BLOCKER
    *   **Fix:** Wait for the client(s) to report `DialogueDone` before calling `runWave(waveNumber)`, just like `waitForIntro()` does for wave 1.

### MAJOR

*   **`src/server/TowerService.luau:146`**
    *   **Description:** Tower `cooldown` only decrements inside the `if target then` block, freezing the reload timer when idle and forcing towers to hesitate for a full reload cycle whenever a new enemy enters range.
    *   **Severity:** MAJOR
    *   **Fix:** Move `tower.cooldown -= dt` outside of the `if target then` block so towers reload while idle and fire immediately upon spotting an enemy.
*   **`src/server/GameState.luau:33`**
    *   **Description:** `PlayerAdded` waits a hardcoded 0.5 seconds before broadcasting the initial state, causing clients with slow load times to permanently miss the state payload and get stuck with a broken "$0" / "Wave 0" UI. 
    *   **Severity:** MAJOR
    *   **Fix:** Have the client explicitly request the initial state via a RemoteEvent when `UIController` is ready, rather than relying on a server-side blind `task.wait()`.

### MINOR

*   **`src/client/TowerPanel.luau:71`**
    *   **Description:** The placed tower range ring's Y-position calculation (`pos.Y - 1.5`) subtracts from the model's pivot (which is `ground + 0.5`), burying the neon cylinder 1 stud underground where it cannot be seen.
    *   **Severity:** MINOR
    *   **Fix:** Change the Y offset to `pos.Y - 0.4` so it renders slightly above the ground (`ground + 0.1`), perfectly matching the ghost placement disc.
*   **`src/server/EnemyService.luau:172`**
    *   **Description:** When an enemy reaches a waypoint (`step >= distLeft`), it snaps to it and discards the rest of its movement `step` for that frame, artificially slowing enemies down around corners or during lag spikes.
    *   **Severity:** MINOR
    *   **Fix:** Use a `while step > 0` loop to consume the remaining distance and continue moving the enemy towards the subsequent waypoint in the same frame.
