--!strict
-- Server entrypoint. Boots services and wires the chapter progression:
--   Act 1 lane (Explore) -> Gate -> Gauntlet -> Act 2 roam (Explore) -> Gate ->
--   Gauntlet (final) -> ChapterComplete. Plus gates, towers, cards, coins/merchant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Aesthetic = require(script.Aesthetic)
local ExploreStage = require(script.ExploreStage)
local ExploreStage2 = require(script.ExploreStage2)
local DevTestMap = require(script.DevTestMap)
local Map = require(script.Map)
local GameState = require(script.GameState)
local Economy = require(script.EconomyService)
local EnemyService = require(script.EnemyService)
local TowerService = require(script.TowerService)
local WaveManager = require(script.WaveManager)
local ModeService = require(script.ModeService)
local CardService = require(script.CardService)
local CoinService = require(script.CoinService)

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local notify = Remotes.event("Notify")

local SWORD_PRICE = 100

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

-- ---- gates -------------------------------------------------------------------
local function powerOnGate(gatePart: BasePart)
	Remotes.event("GatePoweredOn"):FireAllClients(gatePart.Position)
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

local function wireGate(gatePart: BasePart, hint: string)
	local sealedDebounce = false
	gatePart.Touched:Connect(function(hit)
		if ModeService.get() ~= "Explore" then
			return
		end
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr then
			return
		end
		if gatePart:GetAttribute("Unlocked") then
			ModeService.set("Gauntlet")
		elseif not sealedDebounce then
			sealedDebounce = true
			notify:FireClient(plr, hint)
			task.delay(3, function()
				sealedDebounce = false
			end)
		end
	end)
end

-- Act 1 gate (sealed until Builderman powers it on)
local stage1 = Workspace:FindFirstChild("ExploreStage")
local act1Gate = stage1 and stage1:FindFirstChild("Gate")
if act1Gate and act1Gate:IsA("BasePart") then
	wireGate(act1Gate, "The gate is sealed — talk to Builderman first.")
end

-- the Act 2 gate (set up when Act 2 builds); buying the Sword powers it on
local act2Gate: BasePart? = nil

-- ---- progression -------------------------------------------------------------
local act = 1

local function teleportAll(cf: CFrame)
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char then
			char:PivotTo(cf)
		end
	end
end

local function act2SpawnCFrame(): CFrame
	local s = Workspace:FindFirstChild("ExploreStage2")
	local sp = s and s:FindFirstChild("Act2Spawn")
	if sp and sp:IsA("BasePart") then
		return CFrame.new(sp.Position + Vector3.new(0, 4, 0))
	end
	return CFrame.new(250, 6, 0)
end

-- secret card pickups: touch the part -> grant the card + remove it
local function wireSecretCards(container: Instance)
	for _, part in container:GetDescendants() do
		local cardId = part:GetAttribute("SecretCard")
		if part:IsA("BasePart") and typeof(cardId) == "string" then
			local taken = false
			part.Touched:Connect(function(hit)
				if not taken and Players:GetPlayerFromCharacter(hit.Parent) then
					taken = true
					CardService.grant(cardId)
					notify:FireAllClients("★ Secret card found — it's in your hand!")
					part:Destroy()
				end
			end)
		end
	end
end

ModeService.onChange = function(mode)
	if mode == "Gauntlet" then
		-- fresh gauntlet on this act's own map
		DevTestMap.buildGauntlet(act)
		Map.init()
		GameState.reset()
		Economy.init()
		TowerService.reset()
		EnemyService.reset() -- clear leftover enemies + friendly pins from the last round
		teleportAll(CFrame.new(0, 6, 55))
		WaveManager.start(act, act == 2)
	end
end

WaveManager.onComplete = function(won)
	if not won then
		return
	end
	if act == 1 then
		act = 2
		ExploreStage2.ensure()
		local stage2 = Workspace:FindFirstChild("ExploreStage2")
		if stage2 then
			local gate2 = stage2:FindFirstChild("Gate") -- built sealed (red) by ExploreStage2
			if gate2 and gate2:IsA("BasePart") then
				act2Gate = gate2
				wireGate(gate2, "Sealed. Buy the Sword from the Merchant to power it on.")
			end
			wireSecretCards(stage2)
		end
		teleportAll(act2SpawnCFrame())
		notify:FireAllClients("Sector cleared! A new area opens — walk the lane, and look up...")
		ModeService.set("Explore", "sidescroll")
	else
		ModeService.set("ChapterComplete")
	end
end

-- ---- character placement (backstop vs spawn picks) ---------------------------
local function placeCharacter(char: Model)
	if ModeService.get() == "Gauntlet" then
		char:PivotTo(CFrame.new(0, 6, 55))
	elseif act == 2 then
		char:PivotTo(act2SpawnCFrame())
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

-- ---- remotes -----------------------------------------------------------------
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
	CoinService.broadcast()
end)

Remotes.event("GrantCard").OnServerEvent:Connect(function(_player, cardId)
	if typeof(cardId) ~= "string" then
		return
	end
	CardService.grant(cardId)
	-- Builderman's card powers on the Act 1 gate
	if act1Gate and act1Gate:IsA("BasePart") and not act1Gate:GetAttribute("Unlocked") then
		act1Gate:SetAttribute("Unlocked", true)
		powerOnGate(act1Gate)
	end
end)
Remotes.event("PlayCard").OnServerEvent:Connect(function(player, cardId)
	if typeof(cardId) ~= "string" then
		return
	end
	report(player, CardService.play(player, cardId))
end)

-- coins + merchant
Remotes.event("GrantCoins").OnServerEvent:Connect(function(_player, amount)
	if typeof(amount) ~= "number" then
		return
	end
	CoinService.grant(math.clamp(math.floor(amount), 0, 100000))
end)
Remotes.event("BuyTower").OnServerEvent:Connect(function(player, towerType)
	if typeof(towerType) ~= "string" then
		return
	end
	if TowerService.isUnlocked(towerType) then
		notify:FireClient(player, "You already own that one.")
		return
	end
	if not CoinService.trySpend(SWORD_PRICE) then
		notify:FireClient(player, "Not enough coins — find more first!")
		return
	end
	TowerService.unlock(towerType)
	Remotes.event("TowerUnlocked"):FireAllClients(towerType)
	notify:FireAllClients("Unlocked the Sword Fighter! The gate powers on — onward!")
	-- buying the Sword powers on the sealed Act 2 gate
	if act2Gate and act2Gate:IsA("BasePart") and not act2Gate:GetAttribute("Unlocked") then
		act2Gate:SetAttribute("Unlocked", true)
		powerOnGate(act2Gate)
	end
end)

GameState.broadcast()
ModeService.broadcast()
CoinService.broadcast()

print("[Server] BLOX PROTECTOR booted — Explore mode")
