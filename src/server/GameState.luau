--!strict
-- Owns the round state (base HP, wave, win/lose) and the ONE client snapshot.
-- Solo for now: a single shared state. (Per-player state is a Phase 2 change.)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Economy = require(script.Parent.EconomyService)

local GameState = {}

local MAX_BASE_HP = 100

local baseHP = MAX_BASE_HP
local wave = 0
local status: "playing" | "won" | "lost" = "playing"

local stateChanged = Remotes.event("StateChanged")

local function snapshot()
	return {
		wave = wave,
		baseHP = baseHP,
		maxBaseHP = MAX_BASE_HP,
		cash = Economy.getCash(),
		status = status,
	}
end

-- Single broadcast path. Economy.onChange is wired to this in init.server.
function GameState.broadcast()
	stateChanged:FireAllClients(snapshot())
end

function GameState.init()
	baseHP = MAX_BASE_HP
	wave = 0
	status = "playing"
	-- send current state to anyone who joins
	Players.PlayerAdded:Connect(function()
		task.wait(0.5)
		GameState.broadcast()
	end)
end

function GameState.setWave(n: number)
	wave = n
	GameState.broadcast()
end

function GameState.getStatus()
	return status
end

function GameState.damageBase(amount: number)
	if status ~= "playing" then
		return
	end
	baseHP = math.max(0, baseHP - amount)
	if baseHP <= 0 then
		status = "lost"
	end
	GameState.broadcast()
end

function GameState.win()
	if status == "playing" then
		status = "won"
		GameState.broadcast()
	end
end

return GameState
