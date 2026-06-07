--!strict
-- Global tuning knobs that aren't per-tower / per-enemy.

local Balance = {
	-- Placement
	PathClearance = 5, -- studs the path lane needs clear of a tower's footprint
	WallMaxDist = 6, -- a "wall" tower must be placed within this many studs of the path
	HotbarSlots = 8, -- total hotbar slots (some locked at start)
	SellRefund = 0.6, -- fraction of total cash spent on a tower, refunded on sell

	-- Starter loadout: the towers unlocked from the start (fill the first slots;
	-- remaining slots are "locked" placeholders for future unlocks / crates).
	StarterTowers = { "Pelter", "Sniper", "Splash", "Paintball", "Superball", "Drill", "Trowel" },

	-- Combat
	TowerTickRate = 0.05, -- seconds between tower target/fire evaluations
}

return Balance
