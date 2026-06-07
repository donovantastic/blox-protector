--!strict
-- Act 1 exploration: a 2.5D side-scroll camera that tracks the character along the
-- lane (movement stays on X thanks to the stage's invisible walls), [E] to talk to
-- nearby NPCs, and a clean handoff to the Gauntlet (overhead camera, character
-- frozen, tower UI shown) when ModeChanged says so.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Dialogue = require(Shared.Configs.Dialogue)
local DialogueController = require(script.Parent.DialogueController)

local player = Players.LocalPlayer

local ExploreController = {}

local NPC_RANGE = 10
local SIDE_Z = 26 -- camera distance to the side of the lane
local SIDE_Y = 7 -- camera height
local GAUNTLET_CF = CFrame.lookAt(Vector3.new(0, 72, 78), Vector3.new(0, 0, 4))

local mode = "Explore"

local function rootPart(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if mode == "Explore" then
		local root = rootPart()
		if root then
			local p = root.Position
			camera.CFrame = CFrame.lookAt(
				Vector3.new(p.X, p.Y + SIDE_Y, p.Z + SIDE_Z),
				Vector3.new(p.X, p.Y + 1.5, p.Z)
			)
		end
	else
		camera.CFrame = GAUNTLET_CF
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

local function applyModeToCharacter()
	local hum = humanoid()
	if hum then
		-- frozen + non-jumping during the gauntlet (it's mouse-driven there)
		hum.WalkSpeed = if mode == "Explore" then 16 else 0
		hum.JumpHeight = if mode == "Explore" then 7.2 else 0
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

local function setMode(newMode: string)
	mode = newMode
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	applyModeToCharacter()
end

function ExploreController.init()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	RunService:BindToRenderStep("ExploreCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E and mode == "Explore" then
			local npc = nearestNPC()
			if npc then
				local key = npc:GetAttribute("Dialogue")
				if typeof(key) == "string" and Dialogue[key] then
					DialogueController.play(key)
				end
			end
		end
	end)

	Remotes.event("ModeChanged").OnClientEvent:Connect(function(newMode)
		setMode(tostring(newMode))
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		applyModeToCharacter()
	end)
	applyModeToCharacter()
end

return ExploreController
