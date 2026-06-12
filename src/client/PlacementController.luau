--!strict
-- Ghost-preview tower placement. While a hotbar tower is selected, a translucent
-- ghost + range disc follow the mouse; green = placeable, red = blocked (on path /
-- can't afford / overlaps). The ghost is a clone of the REAL model from
-- ReplicatedStorage.Assets.Towers when one exists (graybox otherwise), so what you
-- see is what you place. R rotates the ghost in 45° steps and the tower is placed
-- facing that way. Left-click places (server re-validates), right-click / Esc cancels.
-- Stays selected after a place so you can drop several.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Configs.Towers)
local Balance = require(Shared.Configs.Balance)
local PathUtil = require(Shared.PathUtil)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local placeRemote = Remotes.event("PlaceTower")

local PlacementController = {}

local GREEN = Color3.fromRGB(80, 220, 120)
local RED = Color3.fromRGB(230, 90, 90)

local ghostFolder: Folder
type Ghost = {
	model: Model?, -- real-model preview (when Assets.Towers has it)
	highlight: Highlight?,
	base: BasePart?, -- graybox preview pieces (fallback)
	turret: BasePart?,
	disc: BasePart,
	towerType: string,
	wall: boolean,
}
local ghost: Ghost? = nil
local lastValid = false
local lastPos: Vector3? = nil
local rotationDeg = 0 -- R rotates the ghost (and the placed tower) in 45° steps

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clearGhost()
	if ghost then
		ghostFolder:ClearAllChildren()
		ghost = nil
	end
end

-- show/hide without destroying the parts' own transparencies
local function setGhostHidden(hidden: boolean)
	for _, d in ghostFolder:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function buildGhost(towerType: string, def: Towers.Tower)
	clearGhost()

	-- prefer a translucent clone of the real tower model so the preview matches
	-- what actually gets built
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local towersAssets = assets and assets:FindFirstChild("Towers")
	local template = towersAssets and towersAssets:FindFirstChild(def.model)
	local model: Model? = nil
	local highlight: Highlight? = nil
	local base: BasePart? = nil
	local turret: BasePart? = nil

	if template and template:IsA("Model") and template.PrimaryPart then
		local clone = template:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				if d.Transparency < 1 then
					d.Transparency = 0.45
				end
			elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
		clone.Parent = ghostFolder
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineTransparency = 0.2
		hl.Adornee = clone
		hl.Parent = clone
		model = clone
		highlight = hl
	else
		-- graybox fallback (no model in Assets.Towers yet)
		local b = Instance.new("Part")
		b.Anchored = true
		b.CanCollide = false
		b.Transparency = 0.45
		b.Material = Enum.Material.SmoothPlastic
		-- a wall ghost is a wide slab; a normal tower ghost is a square footprint
		b.Size = if def.wall
			then Vector3.new(11, 5, 1.4)
			else Vector3.new(def.placementRadius * 1.6, 1, def.placementRadius * 1.6)
		b.Parent = ghostFolder
		base = b

		local t = Instance.new("Part")
		t.Anchored = true
		t.CanCollide = false
		t.Transparency = 0.45
		t.Material = Enum.Material.SmoothPlastic
		t.Size = Vector3.new(1.6, 1.6, 3)
		t.Parent = ghostFolder
		turret = t
	end

	local range = def.levels[1].range
	local disc = Instance.new("Part")
	disc.Anchored = true
	disc.CanCollide = false
	disc.Transparency = 0.75
	disc.Material = Enum.Material.Neon
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, range * 2, range * 2)
	disc.Parent = ghostFolder

	ghost = {
		model = model,
		highlight = highlight,
		base = base,
		turret = turret,
		disc = disc,
		towerType = towerType,
		wall = def.wall == true,
	}
end

local function groundPoint(): Vector3?
	-- exclude the Map (Spawn/Base/waypoint blocks) so the ray hits the ground, not
	-- a raised block — otherwise the tower spawns floating on top of it
	local filter: { Instance } = { ghostFolder }
	for _, name in { "Enemies", "Tracers", "Towers", "Map" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(filter, f)
		end
	end
	rayParams.FilterDescendantsInstances = filter
	local ray = mouse.UnitRay
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 2000, rayParams)
	return if result then result.Position else nil
end

local function isValid(def: Towers.Tower, pos: Vector3): boolean
	if ClientState.cash < def.cost then
		return false
	end
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return false
	end
	local waypoints = PathUtil.getWaypoints(map)
	local distToPath = PathUtil.distanceToPath(waypoints, pos)
	if def.wall then
		-- a wall must be ON the path, not beside it
		if distToPath > Balance.WallMaxDist then
			return false
		end
	elseif distToPath < (Balance.PathClearance + def.placementRadius) then
		return false
	end
	local towersFolder = Workspace:FindFirstChild("Towers")
	if towersFolder then
		for _, m in towersFolder:GetChildren() do
			local mp = m:GetPivot().Position
			local pr = (m:GetAttribute("PlacementRadius") :: number?) or 4
			local d = (Vector2.new(pos.X, pos.Z) - Vector2.new(mp.X, mp.Z)).Magnitude
			if d < (def.placementRadius + pr) then
				return false
			end
		end
	end
	return true
end

local function update()
	local sel = ClientState.selectedTower
	if not sel then
		clearGhost()
		return
	end
	local def = Towers[sel]
	if not def then
		clearGhost()
		return
	end
	if not ghost or ghost.towerType ~= sel then
		buildGhost(sel, def)
	end
	local g = ghost :: Ghost

	local pos = groundPoint()
	if pos then
		pos = Vector3.new(pos.X, 0, pos.Z) -- ground level: keep the ghost + tower flat
	end
	lastPos = pos
	if not pos then
		setGhostHidden(true)
		lastValid = false
		return
	end
	setGhostHidden(false)

	lastValid = isValid(def, pos)
	local tint = if lastValid then GREEN else RED

	g.disc.Transparency = 0.78
	g.disc.Color = tint
	g.disc.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))

	if g.model then
		-- real-model ghost: pivot to the cursor with the chosen rotation; the
		-- highlight (not the bricks) carries the green/red verdict
		g.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(rotationDeg), 0))
		local hl = g.highlight
		if hl then
			hl.OutlineColor = tint
			hl.FillColor = tint
			hl.FillTransparency = if lastValid then 1 else 0.7
		end
	elseif g.wall then
		-- wall preview: a tall slab on the lane, no turret
		local base = g.base :: BasePart
		base.Transparency = 0.4
		base.Color = tint
		base.CFrame = CFrame.new(pos + Vector3.new(0, base.Size.Y / 2, 0))
			* CFrame.Angles(0, math.rad(rotationDeg), 0)
		local turret = g.turret :: BasePart
		turret.Transparency = 1
	else
		local base = g.base :: BasePart
		local turret = g.turret :: BasePart
		base.Transparency = 0.45
		turret.Transparency = 0.45
		base.Color = tint
		turret.Color = tint
		base.Position = pos + Vector3.new(0, 0.5, 0)
		turret.CFrame = CFrame.new(pos + Vector3.new(0, 2.2, 0))
			* CFrame.Angles(0, math.rad(rotationDeg), 0)
	end
end

function PlacementController.init()
	ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "TowerGhost"
	ghostFolder.Parent = Workspace

	RunService.RenderStepped:Connect(update)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local sel = ClientState.selectedTower
			if sel and lastValid and lastPos then
				placeRemote:FireServer(sel, lastPos, rotationDeg)
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			-- quarter-of-a-quarter turn: 8 taps = full circle
			if ClientState.selectedTower then
				rotationDeg = (rotationDeg + 45) % 360
			end
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.KeyCode == Enum.KeyCode.Escape
			or input.KeyCode == Enum.KeyCode.Q
		then
			ClientState.setSelected(nil)
		end
	end)
end

return PlacementController
