--!strict
-- Enemy definitions (BLOX PROTECTOR — "The Moderns" / corruption mobs). Add an enemy
-- = add an entry + a graybox model named the same as `model` under
-- ReplicatedStorage.Assets.Enemies. Per-wave scaling is applied by WaveManager.

export type Enemy = {
	name: string, -- lore display name
	desc: string, -- one-line flavor
	model: string, -- name under ReplicatedStorage.Assets.Enemies (also graybox color key)
	health: number, -- base health (wave scaling multiplies this)
	speed: number, -- studs/second along the path
	reward: number, -- in-round cash granted on kill
	leakDamage: number, -- base HP lost if it reaches the Database Core
	scale: number?, -- graybox size multiplier (default 1); bosses are big
	boss: boolean?, -- true for the chapter boss
	-- optional: a "drill" ability that disables towers. While walking, the enemy
	-- drills the nearest tower within `range` and stuns it (can't fire) for `stun`
	-- seconds, then waits `cooldown` seconds before it can drill again.
	ability: {
		range: number, -- studs it can reach a tower from
		stun: number, -- seconds the tower is disabled
		cooldown: number, -- seconds between drills
	}?,
}

local Enemies: { [string]: Enemy } = {
	Grunt = {
		name = "Shiny Crawler",
		desc = "A jittery blob with 100% Reflectance. Too smooth for this world.",
		model = "Grunt",
		health = 8,
		speed = 11,
		reward = 7,
		leakDamage = 1,
	},

	Runner = {
		name = "Lag-Walker",
		desc = "A flickering entity that appears to move at 2 frames per second.",
		model = "Runner",
		health = 6,
		speed = 16,
		reward = 7,
		leakDamage = 1,
	},

	Brute = {
		name = "Mesh-Tank",
		desc = "A high-poly monstrosity that refuses to be garbage-collected.",
		model = "Brute",
		health = 34,
		speed = 7,
		reward = 24,
		leakDamage = 3,
	},

	Pin = {
		name = "The Pushpin",
		desc = "A smug push-pin tank with a drill for a head. Rolls in on treads and refuses to be deleted.",
		model = "Pin",
		health = 220, -- elite: way tankier than a normal mob
		speed = 6, -- heavy treads = slow
		reward = 120, -- worth the effort to bring down
		leakDamage = 10, -- a big bite if it reaches the Core, but not instant-death
		scale = 2.6, -- scaled up — a proper big elite
		boss = true, -- gets the boss healthbar + "Boss" tag (your Drill targets it first)
		-- its signature move: drill a nearby tower and knock it offline for a bit
		ability = { range = 16, stun = 2.5, cooldown = 4 },
	},

	Boss = {
		name = "The Compiler",
		desc = "The Great Smoothing, compiled into one entity. Roll it back before it overwrites the server.",
		model = "Boss",
		health = 420,
		speed = 5,
		reward = 250,
		leakDamage = 100, -- if it reaches the Core, you're done
		scale = 3.8,
		boss = true,
	},

	Boss2 = {
		name = "The Mainframe",
		desc = "Where the Smoothing compiles itself. Bigger, slower, and far harder to roll back.",
		model = "Boss2",
		health = 720,
		speed = 4,
		reward = 400,
		leakDamage = 100,
		scale = 4.6,
		boss = true,
	},
}

return Enemies
