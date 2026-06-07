--!strict
-- Act 1 exploration + the mode camera handoff.
--   Explore  : 2.5D side-scroll camera (movement stays on X via the stage walls).
--   Talk [E] : freeze, 2D avatar conversation, then the card reveal, then a short
--              cutscene cutting to the gate as Builderman powers it on (the spark).
--   Gauntlet : free-range 3D — default camera so you can wander + zoom; tower UI shows.

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
local busy = false -- talking / reveal / cutscene: input + walk locked
local cutscene = false
local givenCards: { [string]: boolean } = {}

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

local function updateCamera()
	if cutscene then
		return -- a cutscene tween owns the camera
	end
	if mode ~= "Explore" then
		return -- gauntlet uses the default free/zoomable camera
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
	if mode == "Explore" then
		setWalk(16)
	end
end

-- cut the camera to the gate so you see it power on, then hand back to side-scroll
local function gateCutscene()
	local stage = Workspace:FindFirstChild("ExploreStage")
	local gate = stage and stage:FindFirstChild("Gate")
	local camera = Workspace.CurrentCamera
	if not gate or not gate:IsA("BasePart") or not camera then
		endBeat()
		return
	end
	cutscene = true
	camera.CameraType = Enum.CameraType.Scriptable
	local gpos = gate.Position
	local shot = CFrame.lookAt(gpos + Vector3.new(11, 5, 17), gpos)
	TweenService
		:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = shot,
		})
		:Play()
	task.delay(2.9, function()
		local cam = Workspace.CurrentCamera
		local root = rootPart()
		if cam and root then
			local p = root.Position
			local back = CFrame.lookAt(
				Vector3.new(p.X, p.Y + SIDE_Y, p.Z + SIDE_Z),
				Vector3.new(p.X, p.Y + 1.5, p.Z)
			)
			TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = back })
				:Play()
		end
		task.delay(0.5, endBeat)
	end)
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
		local cardId = npc:GetAttribute("GivesCard")
		if typeof(cardId) == "string" and Cards[cardId] and not givenCards[cardId] then
			givenCards[cardId] = true
			CardController.reveal(Cards[cardId], function()
				-- granting the card powers on the gate; cut to it
				Remotes.event("GrantCard"):FireServer(cardId)
				gateCutscene()
			end)
		else
			endBeat()
		end
	end)
end

local function applyMode()
	local camera = Workspace.CurrentCamera
	if camera and not cutscene then
		camera.CameraType = if mode == "Explore"
			then Enum.CameraType.Scriptable
			else Enum.CameraType.Custom
	end
	if not busy then
		setWalk(16)
	end
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, name in { "Hotbar", "TowerPanel" } do
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

	Remotes.event("ModeChanged").OnClientEvent:Connect(function(newMode)
		mode = tostring(newMode)
		applyMode()
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		applyMode()
	end)
	applyMode()
end

return ExploreController
