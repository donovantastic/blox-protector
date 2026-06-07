--!strict
-- Ghost-preview tower placement. While a hotbar tower is selected, a translucent
-- ghost + range disc follow the mouse; green = placeable, red = blocked (on path /
-- can't afford / overlaps). Left-click places (server re-validates), right-click /
-- Esc cancels. Stays selected after a place so you can drop several.

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
type Ghost = { base: BasePart, turret: BasePart, disc: BasePart, towerType: string }
local ghost: Ghost? = nil
local lastValid = false
local lastPos: Vector3? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clearGhost()
	if ghost then
		ghostFolder:ClearAllChildren()
		ghost = nil
	end
end

local function buildGhost(towerType: string, def: Towers.Tower)
	clearGhost()
	local base = Instance.new("Part")
	base.Anchored = true
	base.CanCollide = false
	base.Transparency = 0.45
	base.Material = Enum.Material.SmoothPlastic
	base.Size = Vector3.new(def.placementRadius * 1.6, 1, def.placementRadius * 1.6)
	base.Parent = ghostFolder

	local turret = Instance.new("Part")
	turret.Anchored = true
	turret.CanCollide = false
	turret.Transparency = 0.45
	turret.Material = Enum.Material.SmoothPlastic
	turret.Size = Vector3.new(1.6, 1.6, 3)
	turret.Parent = ghostFolder

	local range = def.levels[1].range
	local disc = Instance.new("Part")
	disc.Anchored = true
	disc.CanCollide = false
	disc.Transparency = 0.75
	disc.Material = Enum.Material.Neon
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, range * 2, range * 2)
	disc.Parent = ghostFolder

	ghost = { base = base, turret = turret, disc = disc, towerType = towerType }
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
	if PathUtil.distanceToPath(waypoints, pos) < (Balance.PathClearance + def.placementRadius) then
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
	lastPos = pos
	if not pos then
		for _, child in ghostFolder:GetChildren() do
			(child :: BasePart).Transparency = 1
		end
		lastValid = false
		return
	end

	lastValid = isValid(def, pos)
	local tint = if lastValid then GREEN else RED

	g.base.Transparency = 0.45
	g.turret.Transparency = 0.45
	g.disc.Transparency = 0.78
	g.base.Color = tint
	g.turret.Color = tint
	g.disc.Color = tint
	g.base.Position = pos + Vector3.new(0, 0.5, 0)
	g.turret.CFrame = CFrame.new(pos + Vector3.new(0, 2.2, 0))
	g.disc.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
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
				placeRemote:FireServer(sel, lastPos)
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
