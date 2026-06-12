--!strict
-- Swap placeholder SoundIds with real Roblox asset ids before shipping.

export type Sound = {
	id: string,
	volume: number,
}

-- Two slots use a BUILT-IN engine sound so you hear feedback immediately (no upload
-- /browse). Swap any of these for nicer Creator-Store ids: Studio → View → Toolbox →
-- Audio → search → right-click → Copy Asset ID → paste as "rbxassetid://<number>".
local Sounds: { [string]: Sound } = {
	blip = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3 },
	cardReveal = { id = "rbxassetid://0", volume = 0.55 },
	cardPlay = { id = "rbxassetid://0", volume = 0.5 },
	waveClear = { id = "rbxassetid://0", volume = 0.65 },
	victory = { id = "rbxassetid://0", volume = 0.75 },
	defeat = { id = "rbxassetid://0", volume = 0.75 },
	uiClick = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25 },
	bossSpawn = { id = "rbxassetid://0", volume = 0.8 },
	chaChing = { id = "rbxassetid://0", volume = 0.6 }, -- ATM payout (swap in a real cash-register id)
}

return Sounds
