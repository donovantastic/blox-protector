--!strict
-- Persistent meta currency 🪙 (across the chapter, unlike in-round Cash). Earned
-- from NPCs / pickups; spent at the Merchant to unlock towers. Solo: one shared purse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local CoinService = {}

local coins = 0
local coinsChanged = Remotes.event("CoinsChanged")

function CoinService.broadcast()
	coinsChanged:FireAllClients(coins)
end

function CoinService.get(): number
	return coins
end

function CoinService.grant(amount: number)
	coins += amount
	CoinService.broadcast()
end

function CoinService.trySpend(amount: number): boolean
	if coins < amount then
		return false
	end
	coins -= amount
	CoinService.broadcast()
	return true
end

return CoinService
