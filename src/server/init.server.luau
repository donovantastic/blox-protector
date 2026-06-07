--!strict
-- Server entrypoint. Boots the services, wires the enemy outcomes to the
-- economy + base, and starts the waves. (TowerService/PlacementService land here
-- in the next milestone.)

local DevTestMap = require(script.DevTestMap)
local Map = require(script.Map)
local GameState = require(script.GameState)
local Economy = require(script.EconomyService)
local EnemyService = require(script.EnemyService)
local WaveManager = require(script.WaveManager)

DevTestMap.ensure() -- dev-only: builds a graybox map if none exists (Studio)
Map.init()
Economy.init()
GameState.init()
EnemyService.init()

-- single client-snapshot path: any cash change re-broadcasts state
Economy.onChange = GameState.broadcast

-- enemy outcomes
EnemyService.onLeak = function(enemy)
	GameState.damageBase(enemy.def.leakDamage)
end
EnemyService.onDeath = function(enemy)
	Economy.add(enemy.def.reward)
end

GameState.broadcast()
WaveManager.start()

print("[Server] tower-defense booted — waves incoming")
