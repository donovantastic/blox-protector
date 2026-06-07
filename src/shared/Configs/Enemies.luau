--!strict
-- Enemy definitions. Add an enemy = add an entry + a graybox model named the same
-- as `model` under ReplicatedStorage.Assets.Enemies. Per-wave scaling (health
-- multiplier, etc.) is applied by WaveManager, not baked in here.

export type Enemy = {
	name: string,
	model: string, -- name under ReplicatedStorage.Assets.Enemies
	health: number, -- base health (wave scaling multiplies this)
	speed: number, -- studs/second along the path
	reward: number, -- in-round cash granted on kill
	leakDamage: number, -- base HP lost if it reaches the end
}

local Enemies: { [string]: Enemy } = {
	Grunt = {
		name = "Grunt",
		model = "Grunt",
		health = 10,
		speed = 14,
		reward = 5,
		leakDamage = 1,
	},

	Runner = {
		name = "Runner",
		model = "Runner",
		health = 7,
		speed = 24, -- fast, low health
		reward = 6,
		leakDamage = 1,
	},

	Brute = {
		name = "Brute",
		model = "Brute",
		health = 45,
		speed = 9, -- slow tank
		reward = 18,
		leakDamage = 3,
	},
}

return Enemies
