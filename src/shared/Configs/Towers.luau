--!strict
-- Tower definitions. ALL tower balance lives here — add a tower = add an entry
-- + a graybox model named the same as `model` under ReplicatedStorage.Assets.Towers.
--
-- Two radii per Christian's design:
--   placementRadius : fixed footprint (studs). Used to validate placement (must
--                     fit in a BuildZone, off the path, not overlapping another
--                     tower). Does NOT change with upgrades.
--   range           : attack radius (studs). GROWS with each upgrade level.
--
-- `levels[1]` is the base tower; placing costs `cost`. Each later level costs its
-- own `cost` to upgrade into.

export type Level = {
	range: number, -- attack radius (studs)
	damage: number, -- damage per shot
	cost: number, -- cost to reach THIS level (level 1 = placement cost is `Tower.cost`)
}

export type Tower = {
	name: string,
	model: string, -- name under ReplicatedStorage.Assets.Towers (graybox to start)
	cost: number, -- in-round cash to place (level 1)
	placementRadius: number, -- fixed footprint, never changes
	fireRate: number, -- shots per second
	targeting: string, -- "first" | "last" | "closest" | "strongest"
	levels: { Level }, -- index = upgrade level (1 = base)
}

local Towers: { [string]: Tower } = {
	Pelter = {
		name = "Pelter",
		model = "Pelter",
		cost = 50,
		placementRadius = 4,
		fireRate = 1.0,
		targeting = "first",
		levels = {
			{ range = 16, damage = 4, cost = 50 }, -- base (placement)
			{ range = 20, damage = 7, cost = 75 },
			{ range = 26, damage = 12, cost = 140 },
		},
	},

	Sniper = {
		name = "Sniper",
		model = "Sniper",
		cost = 120,
		placementRadius = 4,
		fireRate = 0.4, -- slow but hits hard + long range
		targeting = "strongest",
		levels = {
			{ range = 40, damage = 18, cost = 120 },
			{ range = 48, damage = 30, cost = 180 },
			{ range = 60, damage = 55, cost = 320 },
		},
	},

	Splash = {
		name = "Splash",
		model = "Splash",
		cost = 90,
		placementRadius = 5, -- bigger footprint
		fireRate = 0.8,
		targeting = "closest",
		levels = {
			{ range = 14, damage = 6, cost = 90 }, -- (splash AoE handled in TowerService later)
			{ range = 18, damage = 10, cost = 130 },
			{ range = 22, damage = 16, cost = 240 },
		},
	},
}

return Towers
