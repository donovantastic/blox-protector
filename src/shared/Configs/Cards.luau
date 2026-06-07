--!strict
-- Cards. "Vanilla" starters early, weird/obscure ones as the story progresses.
-- Cards are earned (NPCs, secrets, rewards) and played in battles / the boss fight.
-- `effect` is interpreted by the card-combat layer (next slice).

export type Card = {
	id: string,
	name: string,
	desc: string,
	rarity: string, -- "Starter" | "Common" | "Rare" | "Weird"
	effect: string, -- "damage" | "heal" | "freeze" | ... (resolved in combat)
	power: number,
}

local Cards: { [string]: Card } = {
	rollback = {
		id = "rollback",
		name = "Rollback",
		desc = "Revert a target to an earlier, weaker build. Heavy damage — save it for something big.",
		rarity = "Starter",
		effect = "damage",
		power = 150,
	},
	defrag = {
		id = "defrag",
		name = "Defrag",
		desc = "Freeze every corrupt process on the field for a few seconds. Buy yourself breathing room.",
		rarity = "Common",
		effect = "freeze",
		power = 4, -- seconds
	},
	hotfix = {
		id = "hotfix",
		name = "Hotfix",
		desc = "Patch the Database Core back up. Restores a chunk of base HP.",
		rarity = "Common",
		effect = "heal",
		power = 30, -- base HP restored
	},
	kill9 = {
		id = "kill9",
		name = "Kill -9",
		desc = "Force-quit the toughest process. No prompts, no mercy. (Hidden — you found it!)",
		rarity = "Secret",
		effect = "damage",
		power = 420,
	},
}

return Cards
