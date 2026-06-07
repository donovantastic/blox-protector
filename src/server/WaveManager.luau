--!strict
-- Drives the round: spawn a wave, wait for it to be cleared, breather, next wave.
-- Endless for the slice (loses when base HP hits 0). Add a win-at-wave-N later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Waves = require(ReplicatedStorage:WaitForChild("Shared").Configs.Waves)
local EnemyService = require(script.Parent.EnemyService)
local GameState = require(script.Parent.GameState)

local WaveManager = {}

local INTRO_DELAY = 4 -- seconds before wave 1
local BREATHER = 3 -- seconds between waves

local function playing(): boolean
	return GameState.getStatus() == "playing"
end

local function runWave(waveNumber: number)
	local def = Waves.get(waveNumber)

	local spawnsRemaining = 0
	for _, group in def do
		spawnsRemaining += group.count
	end

	-- spawn each group concurrently, paced by its spacing
	for _, group in def do
		task.spawn(function()
			for _ = 1, group.count do
				if not playing() then
					return
				end
				EnemyService.spawn(group.enemyType, group.healthMult)
				spawnsRemaining -= 1
				task.wait(group.spacing)
			end
		end)
	end

	-- wave is done when nothing left to spawn AND nothing alive
	while playing() and (spawnsRemaining > 0 or #EnemyService.getActive() > 0) do
		task.wait(0.4)
	end
end

function WaveManager.start()
	task.spawn(function()
		task.wait(INTRO_DELAY)
		local waveNumber = 0
		while playing() do
			waveNumber += 1
			GameState.setWave(waveNumber)
			runWave(waveNumber)
			if not playing() then
				break
			end
			task.wait(BREATHER)
		end
		print("[Wave] round ended:", GameState.getStatus())
	end)
end

return WaveManager
