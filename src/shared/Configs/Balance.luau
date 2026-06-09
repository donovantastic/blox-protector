--!strict
-- Global tuning knobs that aren't per-tower / per-enemy.

local Balance = {
	-- Placement
	PathClearance = 5, -- studs the path lane needs clear of a tower's footprint
	WallMaxDist = 6, -- a "wall" tower must be placed within this many studs of the path
	HotbarSlots = 10, -- loadout cap: two rows of 5 (press T to page). Slots past the
	-- starters stay locked until earned; a loadout-choice mechanic lands once there are
	-- more than 10 towers to pick from.
	SellRefund = 0.6, -- fraction of total cash spent on a tower, refunded on sell

	-- Starter loadout: the towers unlocked from the start (fill the first slots;
	-- remaining slots are "locked" placeholders for future unlocks / crates).
	StarterTowers = {
		"Pelter",
		"Sniper",
		"Splash",
		"Paintball",
		"Superball",
		"Drill",
		"Trowel",
		"Summoner",
	},

	-- Combat
	TowerTickRate = 0.05, -- seconds between tower target/fire evaluations
}

return Balance
