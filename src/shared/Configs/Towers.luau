--!strict
-- Tower definitions (BLOX PROTECTOR — classic-Roblox defenders vs "The Moderns").
-- ALL tower balance lives here — add a tower = add an entry + a graybox model named
-- the same as `model` under ReplicatedStorage.Assets.Towers.
--
-- Two radii per the design:
--   placementRadius : fixed footprint (studs). Validates placement (off the path,
--                     no overlap). Never changes with upgrades.
--   range           : attack radius (studs). GROWS with each upgrade level.
-- `levels[1]` is the base tower; placing costs `levels[1].cost` (== `cost`).

export type Level = {
	range: number, -- attack radius (studs)
	damage: number, -- damage per shot
	cost: number, -- cost to reach THIS level (level 1 = placement cost)
}

export type Tower = {
	name: string, -- lore display name
	desc: string, -- one-line flavor
	model: string, -- name under ReplicatedStorage.Assets.Towers (graybox to start)
	cost: number, -- in-round cash to place (level 1)
	placementRadius: number, -- fixed footprint, never changes
	fireRate: number, -- shots per second
	targeting: string, -- "first" | "last" | "closest" | "strongest"
	levels: { Level }, -- index = upgrade level (1 = base)
}

local Towers: { [string]: Tower } = {
	Pelter = {
		name = "Brick Slinger",
		desc = "A yellow-headed volunteer chucking 1x1 plastic cubes with surprising accuracy.",
		model = "Pelter",
		cost = 40,
		placementRadius = 4,
		fireRate = 1.3,
		targeting = "first",
		levels = {
			{ range = 16, damage = 6, cost = 40 },
			{ range = 20, damage = 9, cost = 65 },
			{ range = 26, damage = 16, cost = 115 },
		},
	},

	Sniper = {
		name = "Rocket Trooper",
		desc = "Armed with an '08 launcher — takes his time to aim, but his 'Oof' is final.",
		model = "Sniper",
		cost = 105,
		placementRadius = 4,
		fireRate = 0.4,
		targeting = "strongest",
		levels = {
			{ range = 40, damage = 18, cost = 105 },
			{ range = 48, damage = 30, cost = 180 },
			{ range = 60, damage = 55, cost = 320 },
		},
	},

	Splash = {
		name = "Bomb Bloxer",
		desc = "Lobs a physics-defying black bomb for a very classic (and very loud) boom.",
		model = "Splash",
		cost = 80,
		placementRadius = 5,
		fireRate = 0.8,
		targeting = "closest",
		levels = {
			{ range = 14, damage = 7, cost = 80 },
			{ range = 18, damage = 10, cost = 130 },
			{ range = 22, damage = 16, cost = 240 },
		},
	},
}

return Towers
