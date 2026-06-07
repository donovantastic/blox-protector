--!strict
-- Server entrypoint. Boots services, builds the Act-1 exploration stage + the
-- gauntlet map, wires the mode flow (Explore -> reach the Gate -> Gauntlet ->
-- survive -> ChapterComplete), and handles the tower remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Aesthetic = require(script.Aesthetic)
local ExploreStage = require(script.ExploreStage)
local DevTestMap = require(script.DevTestMap)
local Map = require(script.Map)
local GameState = require(script.GameState)
local Economy = require(script.EconomyService)
local EnemyService = require(script.EnemyService)
local TowerService = require(script.TowerService)
local WaveManager = require(script.WaveManager)
local ModeService = require(script.ModeService)

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

Aesthetic.apply()
ExploreStage.ensure() -- Act 1 lane (Studio graybox)
DevTestMap.ensure() -- gauntlet map (Studio graybox)
Map.init()
Economy.init()
GameState.init()
EnemyService.init()
TowerService.init()

Economy.onChange = GameState.broadcast
EnemyService.onLeak = function(enemy)
	GameState.damageBase(enemy.def.leakDamage)
end
EnemyService.onDeath = function(enemy)
	Economy.add(enemy.def.reward)
end

-- mode flow: entering the gauntlet starts the waves; surviving completes the chapter
ModeService.onChange = function(mode)
	if mode == "Gauntlet" then
		WaveManager.start()
	end
end
WaveManager.onComplete = function(won)
	if won then
		ModeService.set("ChapterComplete")
	end
end

-- the Gate in the exploration lane: touching it locks into the gauntlet
local stage = Workspace:FindFirstChild("ExploreStage")
local gate = stage and stage:FindFirstChild("Gate")
if gate and gate:IsA("BasePart") then
	gate.Touched:Connect(function(hit)
		if ModeService.get() ~= "Explore" then
			return
		end
		if Players:GetPlayerFromCharacter(hit.Parent) then
			ModeService.set("Gauntlet")
		end
	end)
end

-- tower remotes (validate types; reject + Notify on failure)
local notify = Remotes.event("Notify")
local function report(player: Player, ok: boolean, reason: string)
	if not ok then
		notify:FireClient(player, reason)
	end
end

Remotes.event("PlaceTower").OnServerEvent:Connect(function(player, towerType, position)
	if typeof(towerType) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	report(player, TowerService.place(player, towerType, position))
end)
Remotes.event("UpgradeTower").OnServerEvent:Connect(function(player, towerId)
	if typeof(towerId) ~= "number" then
		return
	end
	report(player, TowerService.upgrade(player, towerId))
end)
Remotes.event("SellTower").OnServerEvent:Connect(function(player, towerId)
	if typeof(towerId) ~= "number" then
		return
	end
	report(player, TowerService.sell(player, towerId))
end)
Remotes.event("DialogueDone").OnServerEvent:Connect(function()
	WaveManager.markIntroDone()
end)
Remotes.event("RequestState").OnServerEvent:Connect(function()
	GameState.broadcast()
	ModeService.broadcast()
end)

GameState.broadcast()
ModeService.broadcast()

print("[Server] BLOX PROTECTOR booted — Explore mode")
