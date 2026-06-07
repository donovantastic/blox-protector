--!strict
-- Wave definitions. Two ways to define a wave:
--   1. Explicitly, in `EXPLICIT` (hand-tuned early waves).
--   2. Procedurally, via `generate()` once you run past the explicit list — count
--      and enemy health scale up so it never "ends" during the slice.
--
-- A wave is a list of "groups": { enemyType, count, spacing, healthMult }.
-- spacing = seconds between spawns within the group.

export type Group = {
	enemyType: string,
	count: number,
	spacing: number,
	healthMult: number,
}

export type Wave = { Group }

local Waves = {}

-- Hand-tuned opening waves. Keep these readable — this is where game feel lives.
local EXPLICIT: { Wave } = {
	{ { enemyType = "Grunt", count = 6, spacing = 0.8, healthMult = 1 } },
	{ { enemyType = "Grunt", count = 10, spacing = 0.7, healthMult = 1 } },
	{
		{ enemyType = "Grunt", count = 8, spacing = 0.6, healthMult = 1.1 },
		{ enemyType = "Runner", count = 4, spacing = 0.5, healthMult = 1 },
	},
	{ { enemyType = "Grunt", count = 14, spacing = 0.5, healthMult = 1.2 } },
	{
		{ enemyType = "Brute", count = 2, spacing = 1.5, healthMult = 1 },
		{ enemyType = "Grunt", count = 10, spacing = 0.5, healthMult = 1.2 },
	},
}

-- Procedural fallback for waves beyond the explicit list (1-indexed wave number).
local function generate(waveNumber: number): Wave
	local over = waveNumber - #EXPLICIT
	local count = 10 + over * 3
	local healthMult = 1.2 + over * 0.18
	-- sprinkle a brute every few waves
	local wave: Wave = {
		{ enemyType = "Grunt", count = count, spacing = 0.45, healthMult = healthMult },
	}
	if waveNumber % 3 == 0 then
		table.insert(wave, {
			enemyType = "Brute",
			count = 1 + math.floor(over / 3),
			spacing = 1.2,
			healthMult = healthMult,
		})
	end
	if waveNumber % 2 == 0 then
		table.insert(
			wave,
			{ enemyType = "Runner", count = 5 + over, spacing = 0.4, healthMult = healthMult }
		)
	end
	return wave
end

-- Returns the wave definition for a 1-indexed wave number (never nil).
function Waves.get(waveNumber: number): Wave
	return EXPLICIT[waveNumber] or generate(waveNumber)
end

return Waves
