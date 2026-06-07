--!strict
-- Chapter-driven flow: title card -> intro dialogue -> (wait for the player to read)
-- -> the chapter's waves with story beats -> VICTORY + end card. Finite per chapter
-- (Chapter 1 = a demo slice). Loses when base HP hits 0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Waves = require(Shared.Configs.Waves)
local Chapters = require(Shared.Configs.Chapters)
local Remotes = require(Shared.Remotes)
local EnemyService = require(script.Parent.EnemyService)
local GameState = require(script.Parent.GameState)
local Economy = require(script.Parent.EconomyService)

local WaveManager = {}

local BREATHER = 4 -- seconds between waves

local introDone = false
local playDialogue = Remotes.event("PlayDialogue")
local showCard = Remotes.event("ShowCard")
local notify = Remotes.event("Notify") -- mid-wave beats use the NON-blocking toast

-- called by init.server when a client reports the intro sequence finished
function WaveManager.markIntroDone()
	introDone = true
end

local function playing(): boolean
	return GameState.getStatus() == "playing"
end

local function runWave(waveNumber: number)
	local def = Waves.get(waveNumber)

	local spawnsRemaining = 0
	for _, group in def do
		spawnsRemaining += group.count
	end

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

	while playing() and (spawnsRemaining > 0 or #EnemyService.getActive() > 0) do
		task.wait(0.4)
	end
end

local function waitForIntro()
	local elapsed = 0
	while not introDone and elapsed < 40 and playing() do
		task.wait(0.2)
		elapsed += 0.2
	end
end

function WaveManager.start()
	task.spawn(function()
		local chapter = Chapters[1]

		showCard:FireAllClients("title", { title = chapter.title, subtitle = chapter.framing })
		task.wait(3)
		playDialogue:FireAllClients(chapter.introKey)
		waitForIntro()
		task.wait(1)

		for waveNumber = 1, chapter.waves do
			if not playing() then
				break
			end
			GameState.setWave(waveNumber)
			local beat = chapter.beats[waveNumber]
			if beat then
				notify:FireAllClients(beat) -- non-blocking; play continues
			end
			runWave(waveNumber)
			if not playing() then
				break
			end
			Economy.add(30 + waveNumber * 10) -- wave-clear bonus: keeps the economy flowing
			notify:FireAllClients(
				("Wave %d cleared!  +$%d"):format(waveNumber, 30 + waveNumber * 10)
			)
			task.wait(BREATHER)
		end

		if playing() then
			GameState.win()
			playDialogue:FireAllClients(chapter.endKey)
			task.wait(2.5)
			showCard:FireAllClients("end", chapter.endCard)
		end
		print("[Chapter] ended:", GameState.getStatus())
	end)
end

return WaveManager
