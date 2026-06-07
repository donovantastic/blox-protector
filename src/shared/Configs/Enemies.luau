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
}

local Enemies: { [string]: Enemy } = {
	Grunt = {
		name = "Shiny Crawler",
		desc = "A jittery blob with 100% Reflectance. Too smooth for this world.",
		model = "Grunt",
		health = 10,
		speed = 14,
		reward = 5,
		leakDamage = 1,
	},

	Runner = {
		name = "Lag-Walker",
		desc = "A flickering entity that appears to move at 2 frames per second.",
		model = "Runner",
		health = 7,
		speed = 24,
		reward = 6,
		leakDamage = 1,
	},

	Brute = {
		name = "Mesh-Tank",
		desc = "A high-poly monstrosity that refuses to be garbage-collected.",
		model = "Brute",
		health = 45,
		speed = 9,
		reward = 18,
		leakDamage = 3,
	},
}

return Enemies
