--!strict
-- Act 1 exploration + the mode camera handoff.
--   Explore  : 2.5D side-scroll camera (movement stays on X via the stage walls).
--   Talk [E] : freeze, zoom into a 2D silhouette conversation, then (if the NPC
--              gives one) reveal a card.
--   Gauntlet : free-range 3D — release to the default camera so you can wander +
--              zoom like the original tower defense; tower UI shows.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
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
local talking = false
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

local function talk(npc: BasePart)
	local key = npc:GetAttribute("Dialogue")
	if typeof(key) ~= "string" or not Dialogue[key] then
		return
	end
	talking = true
	setWalk(0)
	ConversationController.start(npc.Name)
	DialogueController.play(key, function()
		ConversationController.stop()
		talking = false
		if mode == "Explore" then
			setWalk(16)
		end
		local cardId = npc:GetAttribute("GivesCard")
		if typeof(cardId) == "string" and Cards[cardId] and not givenCards[cardId] then
			givenCards[cardId] = true
			CardController.reveal(Cards[cardId])
		end
	end)
end

local function applyMode()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = if mode == "Explore"
			then Enum.CameraType.Scriptable
			else Enum.CameraType.Custom
	end
	if not talking then
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
		if processed or talking then
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
