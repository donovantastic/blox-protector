--!strict
-- DEV graybox for Act 2: a 2.5D side-scroll lane (same locked camera as Act 1, just
-- longer), with NPCs + a merchant along it, a parkour climb up to a HIDDEN secret
-- card, and a sealed gate (powers on when you buy the Sword). Studio-only + if absent.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ExploreStage2 = {}

local CX = 262 -- lane centre X

local function block(
	name: string,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function nameTag(adornee: BasePart, text: string)
	local bg = Instance.new("BillboardGui")
	bg.Adornee = adornee
	bg.Size = UDim2.fromOffset(170, 24)
	bg.StudsOffset = Vector3.new(0, 3.2, 0)
	bg.AlwaysOnTop = true
	bg.Parent = adornee
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 16
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.3
	lbl.Text = text .. "  [E]"
	lbl.Parent = bg
end

local function npc(parent: Instance, x: number, name: string, attrs: { [string]: any })
	local p = block(
		name,
		CFrame.new(x, 3.5, 0),
		Vector3.new(2, 5, 2),
		Color3.fromRGB(235, 200, 120),
		parent
	)
	p.CanCollide = false
	for k, v in attrs do
		p:SetAttribute(k, v)
	end
	CollectionService:AddTag(p, "NPC")
	nameTag(p, name)
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

	-- the lane (X axis); invisible walls keep movement on X (2.5D)
	block("Floor", CFrame.new(CX, 0, 0), Vector3.new(122, 2, 12), Color3.fromRGB(54, 60, 84), stage)
	block("WallNear", CFrame.new(CX, 8, 6.5), Vector3.new(122, 18, 1), Color3.new(), stage).Transparency =
		1
	block("WallFar", CFrame.new(CX, 8, -6.5), Vector3.new(122, 18, 1), Color3.new(), stage).Transparency =
		1

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Act2Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 8)
	spawn.CFrame = CFrame.new(CX - 56, 1.5, 0)
	spawn.Color = Color3.fromRGB(90, 200, 120)
	spawn.Parent = stage

	-- NPCs along the lane (left -> right)
	npc(
		stage,
		CX - 38,
		"Telamon",
		{ Dialogue = "act2_defrag", GivesCard = "defrag", AvatarUserId = 261 }
	)
	npc(stage, CX - 18, "Noob", { Dialogue = "act2_coins", GivesCoins = 120, AvatarUserId = 156 })
	npc(
		stage,
		CX,
		"Stickmasterluke",
		{ Dialogue = "act2_hotfix", GivesCard = "hotfix", AvatarUserId = 80254 }
	)
	npc(stage, CX + 26, "Merchant", {
		Dialogue = "act2_merchant",
		IsMerchant = true,
		SellsTower = "Sword",
		Price = 100,
		AvatarUserId = 505306,
	})

	-- parkour climb up to a hidden card (off the main flow, before the gate)
	local px = CX + 40
	local climb = { { px, 5 }, { px + 5, 10 }, { px, 15 }, { px + 5, 20 }, { px, 25 } }
	for i, step in climb do
		block(
			"Step" .. i,
			CFrame.new(step[1], step[2], 0),
			Vector3.new(4, 1, 4),
			Color3.fromRGB(70, 76, 104),
			stage
		)
	end
	local secret = block(
		"SecretCard",
		CFrame.new(px, 29, 0),
		Vector3.new(2.4, 3.4, 0.4),
		Color3.fromRGB(245, 220, 90),
		stage
	)
	secret.Material = Enum.Material.Neon
	secret.CanCollide = false
	secret:SetAttribute("SecretCard", "kill9")
	nameTag(secret, "???")

	-- backdrop scenery (behind the far wall — pure decoration)
	for i = 0, 5 do
		local bx = CX - 50 + i * 22
		block(
			"Bldg" .. i,
			CFrame.new(bx, 7 + (i % 3) * 4, -18),
			Vector3.new(12, 14 + (i % 3) * 8, 10),
			Color3.fromRGB(38, 42, 64),
			stage
		)
		block(
			"Crystal" .. i,
			CFrame.new(bx + 8, 9, -14),
			Vector3.new(2, 12, 2),
			Color3.fromRGB(120, 90, 200),
			stage
		).Material =
			Enum.Material.Neon
	end

	-- sealed gate at the far end (powers on when you buy the Sword)
	local gate = block(
		"Gate",
		CFrame.new(CX + 58, 4, 0),
		Vector3.new(2, 8, 12),
		Color3.fromRGB(228, 64, 64),
		stage
	)
	gate.Material = Enum.Material.Neon
	gate.Transparency = 0.2
	gate:SetAttribute("IsGate", true)
	gate:SetAttribute("Unlocked", false)
end

return ExploreStage2
