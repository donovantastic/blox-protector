--!strict
-- Owns the round state (base HP, wave, tower cap, win/lose) and the ONE client
-- snapshot. Solo for now: a single shared state. (Per-player state is a Phase 2 change.)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Balance = require(Shared.Configs.Balance)
local Economy = require(script.Parent.EconomyService)

local GameState = {}

local MAX_BASE_HP = 100
local DEV_NO_LOSE = true -- dev test: base takes damage for feedback but never actually loses

local baseHP = MAX_BASE_HP
local wave = 0
local towerLimit = Balance.TowerLimitStart -- max towers placed at once; grows with progression
local towersPlaced = 0
local status: "playing" | "won" | "lost" = "playing"

local stateChanged = Remotes.event("StateChanged")

local function snapshot()
	return {
		wave = wave,
		baseHP = baseHP,
		maxBaseHP = MAX_BASE_HP,
		cash = Economy.getCash(),
		towersPlaced = towersPlaced,
		towerLimit = towerLimit,
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
	towerLimit = Balance.TowerLimitStart
	towersPlaced = 0
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

-- ---- tower placement cap -----------------------------------------------------
function GameState.canPlaceTower(): boolean
	return towersPlaced < towerLimit
end

function GameState.getTowerLimit(): number
	return towerLimit
end

function GameState.getTowersPlaced(): number
	return towersPlaced
end

-- TowerService calls this on every place / sell / reset so the HUD + cap stay current.
function GameState.setTowersPlaced(n: number)
	towersPlaced = n
	GameState.broadcast()
end

-- the growth hook: progression bumps the cap (XP/money mechanic TBD).
function GameState.setTowerLimit(n: number)
	towerLimit = n
	GameState.broadcast()
end

function GameState.damageBase(amount: number)
	if status ~= "playing" then
		return
	end
	baseHP = math.max(if DEV_NO_LOSE then 1 else 0, baseHP - amount)
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

-- Hotfix card: restore base HP (capped).
function GameState.healBase(amount: number)
	if status ~= "playing" then
		return
	end
	baseHP = math.min(MAX_BASE_HP, baseHP + amount)
	GameState.broadcast()
end

-- Fresh start for the next gauntlet (Act 2).
function GameState.reset()
	baseHP = MAX_BASE_HP
	wave = 0
	towerLimit = Balance.TowerLimitStart
	towersPlaced = 0
	status = "playing"
	GameState.broadcast()
end

return GameState
