--!strict
-- Exploration + the mode/camera handoff.
--   Explore "sidescroll" (Act 1): 2.5D side camera, movement on X via stage walls.
--   Explore "freewalk"   (Act 2): default 3rd-person camera, roam freely.
--   Talk [E]: freeze, 2D avatar conversation, then grant (card / coins / buy).
--   Gauntlet: free-range 3D (default camera), tower UI.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Dialogue = require(Shared.Configs.Dialogue)
local Cards = require(Shared.Configs.Cards)
local DialogueController = require(script.Parent.DialogueController)
local ConversationController = require(script.Parent.ConversationController)
local CardController = require(script.Parent.CardController)

local player = Players.LocalPlayer

local ExploreController = {}

local NPC_RANGE = 10
local SIDE_Z = 26
local SIDE_Y = 7

local mode = "Explore"
local style = "sidescroll"
local busy = false -- talking / reveal / cutscene: input + walk locked
local cutscene = false
local claimed: { [Instance]: boolean } = {} -- NPCs whose one-time gift was taken

local function rootPart(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function setWalk(speed: number)
	local hum = humanoid()
	if hum then
		hum.WalkSpeed = speed
		hum.JumpHeight = if speed > 0 then 7.2 else 0
	end
end

local function sideScrollActive(): boolean
	return mode == "Explore" and style == "sidescroll" and not cutscene
end

local function updateCamera()
	if not sideScrollActive() then
		return -- freewalk / gauntlet / cutscene use other cameras
	end
	local camera = Workspace.CurrentCamera
	local root = rootPart()
	if camera and root then
		local p = root.Position
		camera.CFrame = CFrame.lookAt(
			Vector3.new(p.X, p.Y + SIDE_Y, p.Z + SIDE_Z),
			Vector3.new(p.X, p.Y + 1.5, p.Z)
		)
	end
end

local function nearestNPC(): BasePart?
	local root = rootPart()
	if not root then
		return nil
	end
	local best: BasePart? = nil
	local bestD = NPC_RANGE
	for _, npc in CollectionService:GetTagged("NPC") do
		if npc:IsA("BasePart") then
			local d = (npc.Position - root.Position).Magnitude
			if d < bestD then
				bestD = d
				best = npc
			end
		end
	end
	return best
end

local function endBeat()
	cutscene = false
	busy = false
	setWalk(16)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = if sideScrollActive()
			then Enum.CameraType.Scriptable
			else Enum.CameraType.Custom
	end
end

-- cut the camera to a gate so you see it power on, then hand back
local function gateCutscene(gpos: Vector3)
	local camera = Workspace.CurrentCamera
	if not camera then
		endBeat()
		return
	end
	busy = true
	cutscene = true
	setWalk(0)
	camera.CameraType = Enum.CameraType.Scriptable
	local shot = CFrame.lookAt(gpos + Vector3.new(11, 5, 17), gpos)
	TweenService
		:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = shot,
		})
		:Play()
	task.delay(2.9, function()
		if style == "sidescroll" then
			local cam = Workspace.CurrentCamera
			local root = rootPart()
			if cam and root then
				local p = root.Position
				local back = CFrame.lookAt(
					Vector3.new(p.X, p.Y + SIDE_Y, p.Z + SIDE_Z),
					Vector3.new(p.X, p.Y + 1.5, p.Z)
				)
				TweenService
					:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = back })
					:Play()
			end
			task.delay(0.5, endBeat)
		else
			endBeat() -- freewalk: hand the camera back to the default
		end
	end)
end

local function onConversationDone(npc: BasePart)
	local cardId = npc:GetAttribute("GivesCard")
	local coins = npc:GetAttribute("GivesCoins")
	local isMerchant = npc:GetAttribute("IsMerchant")

	if typeof(cardId) == "string" and Cards[cardId] and not claimed[npc] then
		claimed[npc] = true
		CardController.reveal(Cards[cardId], function()
			Remotes.event("GrantCard"):FireServer(cardId)
			endBeat() -- the gate's power-on cutscene arrives via GatePoweredOn
		end)
	elseif typeof(coins) == "number" and not claimed[npc] then
		claimed[npc] = true
		Remotes.event("GrantCoins"):FireServer(coins)
		endBeat()
	elseif isMerchant == true then
		local sells = npc:GetAttribute("SellsTower")
		if typeof(sells) == "string" then
			Remotes.event("BuyTower"):FireServer(sells)
		end
		endBeat()
	else
		endBeat()
	end
end

local function talk(npc: BasePart)
	local key = npc:GetAttribute("Dialogue")
	if typeof(key) ~= "string" or not Dialogue[key] then
		return
	end
	busy = true
	setWalk(0)
	local avatarId = npc:GetAttribute("AvatarUserId")
	ConversationController.start(npc.Name, if typeof(avatarId) == "number" then avatarId else nil)
	DialogueController.play(key, function()
		ConversationController.stop()
		onConversationDone(npc)
	end)
end

local function applyMode()
	local camera = Workspace.CurrentCamera
	if camera and not cutscene then
		camera.CameraType = if sideScrollActive()
			then Enum.CameraType.Scriptable
			else Enum.CameraType.Custom
	end
	if not busy then
		setWalk(16)
	end
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, name in { "Hotbar", "TowerPanel", "HUD" } do
			local gui = pg:FindFirstChild(name)
			if gui and gui:IsA("ScreenGui") then
				gui.Enabled = (mode == "Gauntlet")
			end
		end
	end
end

function ExploreController.init()
	RunService:BindToRenderStep("ExploreCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or busy then
			return
		end
		if input.KeyCode == Enum.KeyCode.E and mode == "Explore" then
			local npc = nearestNPC()
			if npc then
				talk(npc)
			end
		end
	end)

	Remotes.event("ModeChanged").OnClientEvent:Connect(function(newMode, newStyle)
		mode = tostring(newMode)
		style = tostring(newStyle or "sidescroll")
		applyMode()
	end)

	-- a gate powered on (Builderman's card, or buying the Sword): cut to it
	Remotes.event("GatePoweredOn").OnClientEvent:Connect(function(pos)
		if typeof(pos) == "Vector3" and not busy and not cutscene then
			gateCutscene(pos)
		end
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		applyMode()
	end)
	applyMode()
end

return ExploreController
