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
		power = 60,
	},
}

return Cards
