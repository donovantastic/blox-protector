--!strict
-- DEV graybox for Act 2 exploration: a free-walk town area with branching routes,
-- NPCs, a merchant, and an already-open gate. Studio-only + only if absent.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ExploreStage2 = {}

local FLOOR_CENTER = Vector3.new(250, 0, 0)
local FLOOR_SIZE = Vector3.new(150, 2, 110)

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

local function pathStrip(name: string, cframe: CFrame, size: Vector3, parent: Instance)
	local p = block(name, cframe, size, Color3.fromRGB(78, 83, 88), parent)
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local function nameLabel(npc: Part, text: string)
	local bg = Instance.new("BillboardGui")
	bg.Adornee = npc
	bg.Size = UDim2.fromOffset(180, 24)
	bg.StudsOffset = Vector3.new(0, 3.2, 0)
	bg.AlwaysOnTop = true
	bg.Parent = npc

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 16
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.35
	lbl.Text = text
	lbl.Parent = bg
end

local function npc(
	name: string,
	position: Vector3,
	color: Color3,
	parent: Instance,
	dialogue: string,
	avatarUserId: number
): Part
	local p = block(name, CFrame.new(position), Vector3.new(2, 5, 2), color, parent)
	p.CanCollide = false
	p:SetAttribute("Dialogue", dialogue)
	p:SetAttribute("AvatarUserId", avatarUserId)
	CollectionService:AddTag(p, "NPC")
	nameLabel(p, `{name}  [E]`)
	return p
end

function ExploreStage2.ensure()
	if not RunService:IsStudio() then
		return
	end
	if Workspace:FindFirstChild("ExploreStage2") then
		return
	end

	local stage = Instance.new("Model")
	stage.Name = "ExploreStage2"
	stage.Parent = Workspace

	block("Floor", CFrame.new(FLOOR_CENTER), FLOOR_SIZE, Color3.fromRGB(87, 128, 96), stage)

	local wallY = 8
	block(
		"WallNorth",
		CFrame.new(250, wallY, -55.5),
		Vector3.new(150, 16, 1),
		Color3.new(),
		stage,
		1
	)
	block(
		"WallSouth",
		CFrame.new(250, wallY, 55.5),
		Vector3.new(150, 16, 1),
		Color3.new(),
		stage,
		1
	)
	block("WallWest", CFrame.new(174.5, wallY, 0), Vector3.new(1, 16, 110), Color3.new(), stage, 1)
	block("WallEast", CFrame.new(325.5, wallY, 0), Vector3.new(1, 16, 110), Color3.new(), stage, 1)

	local pathY = 1.2
	pathStrip("PathMainA", CFrame.new(195, pathY, 0), Vector3.new(36, 0.4, 8), stage)
	pathStrip("PathMainB", CFrame.new(235, pathY, 0), Vector3.new(44, 0.4, 8), stage)
	pathStrip("PathMainC", CFrame.new(281, pathY, 0), Vector3.new(48, 0.4, 8), stage)
	pathStrip("PathGate", CFrame.new(311, pathY, 0), Vector3.new(22, 0.4, 14), stage)
	pathStrip("PathNorthFork", CFrame.new(230, pathY, -18), Vector3.new(8, 0.4, 36), stage)
	pathStrip("PathNorthBend", CFrame.new(250, pathY, -32), Vector3.new(42, 0.4, 8), stage)
	pathStrip("PathSouthFork", CFrame.new(258, pathY, 19), Vector3.new(8, 0.4, 38), stage)
	pathStrip("PathSouthBend", CFrame.new(238, pathY, 34), Vector3.new(40, 0.4, 8), stage)
	pathStrip("PathMarket", CFrame.new(286, pathY, 22), Vector3.new(38, 0.4, 8), stage)

	block(
		"OldBrickShop",
		CFrame.new(213, 8, -34),
		Vector3.new(16, 14, 14),
		Color3.fromRGB(132, 102, 90),
		stage
	)
	block(
		"TowerOffice",
		CFrame.new(274, 12, -38),
		Vector3.new(18, 22, 16),
		Color3.fromRGB(112, 118, 129),
		stage
	)
	block(
		"BlueTownhouse",
		CFrame.new(292, 7, 35),
		Vector3.new(14, 12, 18),
		Color3.fromRGB(91, 121, 151),
		stage
	)
	block(
		"CheckpointKiosk",
		CFrame.new(205, 5, 28),
		Vector3.new(12, 8, 10),
		Color3.fromRGB(151, 132, 83),
		stage
	)
	block(
		"LowWallNorth",
		CFrame.new(247, 2.25, -18),
		Vector3.new(28, 2.5, 3),
		Color3.fromRGB(91, 94, 98),
		stage
	)
	block(
		"LowWallSouth",
		CFrame.new(269, 2.25, 34),
		Vector3.new(24, 2.5, 3),
		Color3.fromRGB(91, 94, 98),
		stage
	)
	block(
		"BenchBlock",
		CFrame.new(222, 2.4, 19),
		Vector3.new(10, 2.8, 3),
		Color3.fromRGB(106, 83, 67),
		stage
	)
	block(
		"StoneCrateA",
		CFrame.new(187, 3, -24),
		Vector3.new(6, 4, 6),
		Color3.fromRGB(105, 109, 112),
		stage
	)
	block(
		"StoneCrateB",
		CFrame.new(308, 3, -22),
		Vector3.new(7, 4, 5),
		Color3.fromRGB(118, 116, 108),
		stage
	)

	local crystalA = block(
		"DataCrystalA",
		CFrame.new(236, 5, -45),
		Vector3.new(2, 8, 2),
		Color3.fromRGB(75, 255, 218),
		stage
	)
	crystalA.Material = Enum.Material.Neon
	local crystalB = block(
		"DataCrystalB",
		CFrame.new(315, 5, 25),
		Vector3.new(2, 8, 2),
		Color3.fromRGB(175, 110, 255),
		stage
	)
	crystalB.Material = Enum.Material.Neon
	local crystalC = block(
		"DataCrystalC",
		CFrame.new(184, 4, 37),
		Vector3.new(2, 6, 2),
		Color3.fromRGB(255, 226, 83),
		stage
	)
	crystalC.Material = Enum.Material.Neon

	block(
		"TreeTrunkA",
		CFrame.new(191, 4, 16),
		Vector3.new(3, 6, 3),
		Color3.fromRGB(95, 65, 43),
		stage
	)
	block(
		"TreeTopA",
		CFrame.new(191, 8.5, 16),
		Vector3.new(10, 7, 10),
		Color3.fromRGB(67, 139, 78),
		stage
	)
	block(
		"TreeTrunkB",
		CFrame.new(302, 4, -43),
		Vector3.new(3, 6, 3),
		Color3.fromRGB(95, 65, 43),
		stage
	)
	block(
		"TreeTopB",
		CFrame.new(302, 8.5, -43),
		Vector3.new(11, 7, 11),
		Color3.fromRGB(58, 128, 73),
		stage
	)

	local spawn = block(
		"Act2Spawn",
		CFrame.new(184, 2, 0),
		Vector3.new(6, 1, 8),
		Color3.fromRGB(90, 200, 120),
		stage,
		1
	)
	spawn.CanCollide = false

	local telamon = npc(
		"Telamon",
		Vector3.new(231, 3.5, -32),
		Color3.fromRGB(245, 200, 86),
		stage,
		"act2_defrag",
		261
	)
	telamon:SetAttribute("GivesCard", "defrag")

	local stickmasterluke = npc(
		"Stickmasterluke",
		Vector3.new(274, 3.5, 0),
		Color3.fromRGB(83, 169, 222),
		stage,
		"act2_hotfix",
		80254
	)
	stickmasterluke:SetAttribute("GivesCard", "hotfix")

	local noob = npc(
		"Noob",
		Vector3.new(237, 3.5, 34),
		Color3.fromRGB(255, 221, 80),
		stage,
		"act2_coins",
		156
	)
	noob:SetAttribute("GivesCoins", 120)

	local merchant = npc(
		"Merchant",
		Vector3.new(289, 3.5, 22),
		Color3.fromRGB(132, 91, 184),
		stage,
		"act2_merchant",
		505306
	)
	merchant:SetAttribute("IsMerchant", true)
	merchant:SetAttribute("SellsTower", "Sword")
	merchant:SetAttribute("Price", 100)

	local gate = block(
		"Gate",
		CFrame.new(321, 5, 0),
		Vector3.new(2, 8, 14),
		Color3.fromRGB(110, 200, 255),
		stage
	)
	gate.Material = Enum.Material.Neon
	gate.Transparency = 0.2
	gate:SetAttribute("IsGate", true)
	gate:SetAttribute("Unlocked", true)
end

return ExploreStage2
