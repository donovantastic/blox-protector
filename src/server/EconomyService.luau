--!strict
-- In-round Cash 💵 — earned from kills, spent on placing/upgrading towers.
-- Resets each match. (Persistent meta Coins 🪙 are Phase 2, a separate service.)
--
-- This module deliberately does NOT broadcast. It calls `onChange` so GameState
-- owns the single client snapshot (avoids a circular dependency).

local Economy = {}

local STARTING_CASH = 275

local cash = STARTING_CASH

-- set by init.server (GameState.broadcast). Fired whenever cash changes.
Economy.onChange = function() end :: () -> ()

function Economy.init()
	cash = STARTING_CASH
end

function Economy.getCash(): number
	return cash
end

function Economy.add(amount: number)
	cash += amount
	Economy.onChange()
end

-- Returns true and deducts if affordable; false otherwise.
function Economy.trySpend(amount: number): boolean
	if cash < amount then
		return false
	end
	cash -= amount
	Economy.onChange()
	return true
end

return Economy
