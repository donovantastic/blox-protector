--!strict
-- Swap placeholder SoundIds with real Roblox asset ids before shipping.

export type Sound = {
	id: string,
	volume: number,
}

local Sounds: { [string]: Sound } = {
	blip = { id = "rbxassetid://0", volume = 0.35 },
	cardReveal = { id = "rbxassetid://0", volume = 0.55 },
	cardPlay = { id = "rbxassetid://0", volume = 0.5 },
	waveClear = { id = "rbxassetid://0", volume = 0.65 },
	victory = { id = "rbxassetid://0", volume = 0.75 },
	defeat = { id = "rbxassetid://0", volume = 0.75 },
	uiClick = { id = "rbxassetid://0", volume = 0.35 },
	bossSpawn = { id = "rbxassetid://0", volume = 0.8 },
}

return Sounds
