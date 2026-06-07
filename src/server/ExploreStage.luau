--!strict
-- DEV graybox for Act 1 exploration: a 2.5D lane (movement locked to X by invisible
-- walls), a spawn, Builderman to talk to ([E]), and a Gate at the end that triggers
-- the Gauntlet. Studio-only + only if absent (like DevTestMap) — a real stage replaces it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ExploreStage = {}

local function block(
	name: string,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	parent: Instance,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

function ExploreStage.ensure()
	if not RunService:IsStudio() then
		return
	end
	if Workspace:FindFirstChild("ExploreStage") then
		return
	end
	local stage = Instance.new("Model")
	stage.Name = "ExploreStage"
	stage.Parent = Workspace

	block(
		"Floor",
		CFrame.new(-120, 0, 0),
		Vector3.new(94, 2, 12),
		Color3.fromRGB(58, 62, 90),
		stage
	)
	-- invisible walls keep the character on the X lane (the 2.5D constraint)
	block("WallNear", CFrame.new(-120, 6, 6.5), Vector3.new(94, 14, 1), Color3.new(), stage, 1)
	block("WallFar", CFrame.new(-120, 6, -6.5), Vector3.new(94, 14, 1), Color3.new(), stage, 1)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ExploreSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 8)
	spawn.CFrame = CFrame.new(-155, 1.5, 0)
	spawn.Color = Color3.fromRGB(90, 200, 120)
	spawn.Parent = stage

	-- make this the ONLY spawn (drop the place's default Baseplate spawn so the
	-- player always starts on the lane, not at the gauntlet map)
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("SpawnLocation") and inst ~= spawn then
			inst:Destroy()
		end
	end

	local npc = block(
		"Builderman",
		CFrame.new(-120, 3.5, 0),
		Vector3.new(2, 5, 2),
		Color3.fromRGB(245, 210, 80),
		stage
	)
	npc.CanCollide = false
	npc:SetAttribute("Dialogue", "explore_intro")
	npc:SetAttribute("GivesCard", "rollback")
	CollectionService:AddTag(npc, "NPC")
	local bg = Instance.new("BillboardGui")
	bg.Adornee = npc
	bg.Size = UDim2.fromOffset(150, 24)
	bg.StudsOffset = Vector3.new(0, 3.2, 0)
	bg.AlwaysOnTop = true
	bg.Parent = npc
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 16
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.4
	lbl.Text = "Builderman  [E]"
	lbl.Parent = bg

	local gate = block(
		"Gate",
		CFrame.new(-78, 4, 0),
		Vector3.new(2, 8, 12),
		Color3.fromRGB(120, 200, 255),
		stage
	)
	gate.Material = Enum.Material.Neon
	gate.Transparency = 0.25
	gate:SetAttribute("IsGate", true)
end

return ExploreStage
