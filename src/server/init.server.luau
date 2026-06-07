--!strict
-- Server entrypoint. Boots services, wires enemy outcomes to economy + base,
-- handles the tower remotes (server-authoritative), and starts the waves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevTestMap = require(script.DevTestMap)
local Map = require(script.Map)
local GameState = require(script.GameState)
local Economy = require(script.EconomyService)
local EnemyService = require(script.EnemyService)
local TowerService = require(script.TowerService)
local WaveManager = require(script.WaveManager)

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

DevTestMap.ensure() -- dev-only: builds a graybox map if none exists (Studio)
Map.init()
Economy.init()
GameState.init()
EnemyService.init()
TowerService.init()

-- single client-snapshot path: any cash change re-broadcasts state
Economy.onChange = GameState.broadcast

-- enemy outcomes
EnemyService.onLeak = function(enemy)
	GameState.damageBase(enemy.def.leakDamage)
end
EnemyService.onDeath = function(enemy)
	Economy.add(enemy.def.reward)
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

GameState.broadcast()
WaveManager.start()

print("[Server] tower-defense booted — waves incoming")
