--!strict
-- Server entrypoint. Boots services, builds the Act-1 exploration stage + the
-- gauntlet map, wires the mode flow (Explore -> reach the Gate -> Gauntlet ->
-- survive -> ChapterComplete), and handles the tower remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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
local CardService = require(script.CardService)

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
		-- move players to a vantage over the gauntlet map (free 3D camera takes over)
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			if char then
				char:PivotTo(CFrame.new(0, 6, 55))
			end
		end
		WaveManager.start()
	end
end
WaveManager.onComplete = function(won)
	if won then
		ModeService.set("ChapterComplete")
	end
end

-- the Gate: sealed (red) until Builderman powers it on; then touching it locks in
local notify = Remotes.event("Notify")
local stage = Workspace:FindFirstChild("ExploreStage")
local gate = stage and stage:FindFirstChild("Gate")
if gate and gate:IsA("BasePart") then
	local sealedDebounce = false
	gate.Touched:Connect(function(hit)
		if ModeService.get() ~= "Explore" then
			return
		end
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr then
			return
		end
		if gate:GetAttribute("Unlocked") then
			ModeService.set("Gauntlet")
		elseif not sealedDebounce then
			sealedDebounce = true
			notify:FireClient(plr, "The gate is sealed — talk to Builderman first.")
			task.delay(3, function()
				sealedDebounce = false
			end)
		end
	end)
end

-- "powering on" effect when Builderman unlocks the gate: flicker -> spark burst ->
-- flash white -> settle to a glowing blue
local function powerOnGate(gatePart: BasePart)
	local attach = Instance.new("Attachment")
	attach.Parent = gatePart

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(150, 225, 255), Color3.fromRGB(255, 255, 255))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Speed = NumberRange.new(10, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 0
	sparks.Parent = attach

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 200, 255)
	light.Range = 20
	light.Brightness = 0
	light.Parent = gatePart

	local snd = Instance.new("Sound")
	snd.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	snd.Volume = 0.6
	snd.Parent = gatePart

	task.spawn(function()
		task.wait(0.55) -- let the client's cutscene camera arrive at the gate first
		for _ = 1, 3 do
			gatePart.Transparency = 0.75
			task.wait(0.07)
			gatePart.Transparency = 0.2
			task.wait(0.07)
		end
		pcall(function()
			snd:Play()
		end)
		sparks:Emit(45)
		light.Brightness = 4
		gatePart.Color = Color3.fromRGB(255, 255, 255)
		gatePart.Transparency = 0
		TweenService:Create(
			gatePart,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad),
			{ Color = Color3.fromRGB(110, 200, 255), Transparency = 0.15 }
		):Play()
		TweenService:Create(light, TweenInfo.new(0.9), { Brightness = 1.4 }):Play()
		task.wait(1.2)
		attach:Destroy()
		Debris:AddItem(snd, 2)
	end)
end

-- start each player in the right place for the current mode (backstop vs spawn picks)
local function placeCharacter(char: Model)
	if ModeService.get() == "Gauntlet" then
		char:PivotTo(CFrame.new(0, 6, 55))
	else
		local s = Workspace:FindFirstChild("ExploreStage")
		local sp = s and s:FindFirstChild("ExploreSpawn")
		local pos = if sp and sp:IsA("BasePart")
			then sp.Position + Vector3.new(0, 4, 0)
			else Vector3.new(-152, 5, 0)
		char:PivotTo(CFrame.new(pos))
	end
end
local function hookPlayer(plr: Player)
	plr.CharacterAdded:Connect(function(char)
		task.wait(0.3)
		placeCharacter(char)
	end)
	if plr.Character then
		task.spawn(function()
			task.wait(0.3)
			placeCharacter(plr.Character :: Model)
		end)
	end
end
Players.PlayerAdded:Connect(hookPlayer)
for _, plr in Players:GetPlayers() do
	hookPlayer(plr)
end

-- tower remotes (validate types; reject + Notify on failure)
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
	CardService.broadcast()
end)

-- card remotes
Remotes.event("GrantCard").OnServerEvent:Connect(function(_player, cardId)
	if typeof(cardId) ~= "string" then
		return
	end
	CardService.grant(cardId)
	-- Builderman handing you the card powers on the gate (red -> blue, passable)
	if gate and gate:IsA("BasePart") and not gate:GetAttribute("Unlocked") then
		gate:SetAttribute("Unlocked", true)
		powerOnGate(gate)
	end
end)
Remotes.event("PlayCard").OnServerEvent:Connect(function(player, cardId)
	if typeof(cardId) ~= "string" then
		return
	end
	report(player, CardService.play(player, cardId))
end)

GameState.broadcast()
ModeService.broadcast()

print("[Server] BLOX PROTECTOR booted — Explore mode")
