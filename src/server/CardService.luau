--!strict
-- The player's card hand (solo: one shared hand) + playing cards. Cards are granted
-- by NPCs (Builderman) and played in the gauntlet. Playing auto-targets the boss,
-- otherwise the strongest live enemy — no manual targeting, no input conflict with
-- tower placement. Server-authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Configs.Cards)
local Remotes = require(Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local GameState = require(script.Parent.GameState)

local CardService = {}

local hand: { string } = {}
local handChanged = Remotes.event("HandChanged")

function CardService.broadcast()
	handChanged:FireAllClients(hand)
end

local function indexOf(cardId: string): number?
	for i, id in hand do
		if id == cardId then
			return i
		end
	end
	return nil
end

function CardService.grant(cardId: string)
	if not Cards[cardId] then
		return
	end
	table.insert(hand, cardId)
	CardService.broadcast()
end

local function pickTarget(): EnemyService.Enemy?
	local best: EnemyService.Enemy? = nil
	local bestScore = -math.huge
	for _, e in EnemyService.getActive() do
		if not e.dead then
			-- boss first, then highest health
			local score = e.health + (if e.def.boss then 1e6 else 0)
			if score > bestScore then
				bestScore = score
				best = e
			end
		end
	end
	return best
end

-- Returns (ok, reason). On success applies the card's effect and discards it.
function CardService.play(_player: Player, cardId: string): (boolean, string)
	local idx = indexOf(cardId)
	if not idx then
		return false, "Card not in hand"
	end
	local card = Cards[cardId]
	if not card then
		return false, "Unknown card"
	end

	if card.effect == "damage" then
		local target = pickTarget()
		if not target then
			return false, "No target — save it for the swarm"
		end
		EnemyService.takeDamage(target, card.power)
	elseif card.effect == "freeze" then
		EnemyService.freezeAll(card.power)
	elseif card.effect == "heal" then
		GameState.healBase(card.power)
	else
		return false, "That card fizzled"
	end

	table.remove(hand, idx)
	CardService.broadcast()
	return true, "ok"
end

function CardService.reset()
	table.clear(hand)
	CardService.broadcast()
end

return CardService
