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

-- A debuff a tower's shot leaves on the enemy it hits. Right now there's one kind:
-- a SLOW (paint gums the enemy up). slowMult is how fast it moves while painted
-- (0.5 = half speed); duration is how many seconds the paint lasts before it wears off.
export type Debuff = {
	slowMult: number, -- speed multiplier while painted (1 = no slow, 0.5 = half speed)
	duration: number, -- seconds the slow lasts after a hit
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
	debuff: Debuff?, -- optional: a status effect each shot applies (e.g. paint = slow)
	knockback: number?, -- optional: studs to bounce the enemy BACKWARD along the path
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

	Paintball = {
		name = "Paint Splatterer",
		desc = "Fires gloppy 1x1 paintballs. Low damage, but the splatter gums enemies up so they crawl.",
		model = "Paintball",
		cost = 60,
		placementRadius = 4,
		fireRate = 1.1, -- a steady stream of paint
		targeting = "first",
		-- Soft hits, but the SLOW is the point: a single Splatterer can keep one enemy
		-- gummed up the whole time (fires every ~0.9s, paint lasts 1.6s → never wears off
		-- while it keeps shooting). Pair it with a hard-hitting tower behind it.
		debuff = { slowMult = 0.55, duration = 1.6 }, -- 55% speed for 1.6s after each hit
		levels = {
			{ range = 16, damage = 4, cost = 60 },
			{ range = 20, damage = 6, cost = 90 },
			{ range = 24, damage = 10, cost = 150 },
		},
	},

	Superball = {
		name = "Super Bouncer",
		desc = "Fires a hyper-bouncy rubber ball that smacks enemies backward down the path.",
		model = "Superball",
		cost = 75,
		placementRadius = 4,
		fireRate = 0.9, -- slowish, but every hit sends them flying back
		targeting = "first", -- hit the leader and bowl it back into the crowd
		-- Light damage — the KNOCKBACK is the weapon. 8 studs back per hit roughly
		-- cancels a normal enemy's progress between shots, and outright bullies slow
		-- heavy enemies (a Mesh-Tank can get stuck bouncing in place). Tweak freely.
		knockback = 8, -- studs pushed back along the path each shot
		levels = {
			{ range = 18, damage = 5, cost = 75 },
			{ range = 22, damage = 8, cost = 120 },
			{ range = 26, damage = 14, cost = 200 },
		},
	},

	-- unlocked from the Act 2 Merchant (not a starter)
	Sword = {
		name = "Sword Fighter",
		desc = "A blocky knight who slices anything that wanders too close. Short reach, brutal hits.",
		model = "Sword",
		cost = 70,
		placementRadius = 4,
		fireRate = 1.6,
		targeting = "closest",
		levels = {
			{ range = 10, damage = 12, cost = 70 },
			{ range = 12, damage = 20, cost = 105 },
			{ range = 14, damage = 34, cost = 190 },
		},
	},
}

return Towers
