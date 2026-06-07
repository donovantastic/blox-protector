--!strict
-- DEV ONLY. Builds a graybox test map (Spawn / Base / S-path) if none exists, so
-- you can just press Play and see the loop without hand-building a map. Gated to
-- Studio + only when Workspace.Map is missing — once you/Xander build a real map,
-- this does nothing. Delete this file + its call in init.server when the real map lands.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DevTestMap = {}

local function block(
	name: string,
	pos: Vector3,
	size: Vector3,
	color: Color3,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

function DevTestMap.ensure()
	if not RunService:IsStudio() then
		return
	end
	if Workspace:FindFirstChild("Map") then
		return
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	block("Spawn", Vector3.new(-60, 1, 0), Vector3.new(8, 1, 8), Color3.fromRGB(80, 200, 120), map)
	block("Base", Vector3.new(60, 1, 0), Vector3.new(10, 4, 10), Color3.fromRGB(220, 80, 80), map)

	local path = Instance.new("Folder")
	path.Name = "Path"
	path.Parent = map
	local points = {
		Vector3.new(-30, 1, 0),
		Vector3.new(-30, 1, 30),
		Vector3.new(0, 1, 30),
		Vector3.new(0, 1, -30),
		Vector3.new(30, 1, -30),
		Vector3.new(30, 1, 0),
	}
	for i, pos in ipairs(points) do
		block(tostring(i), pos, Vector3.new(4, 1, 4), Color3.fromRGB(90, 90, 110), path)
	end

	-- visible road connecting Spawn -> waypoints -> Base. Purely cosmetic (the enemy
	-- path + no-build zone come from the waypoints); this just shows where the lane is.
	local full = { Vector3.new(-60, 1, 0) }
	for _, p in ipairs(points) do
		table.insert(full, p)
	end
	table.insert(full, Vector3.new(60, 1, 0))

	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = map
	local ROAD_W = 9
	local ROAD_COLOR = Color3.fromRGB(44, 46, 62)
	local function seg(name: string, cframe: CFrame, size: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false -- don't block placement/selection raycasts
		p.Size = size
		p.CFrame = cframe
		p.Color = ROAD_COLOR
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = road
	end
	for i = 1, #full - 1 do
		local a = Vector3.new(full[i].X, 0.6, full[i].Z)
		local b = Vector3.new(full[i + 1].X, 0.6, full[i + 1].Z)
		seg(
			"Seg" .. i,
			CFrame.lookAt((a + b) / 2, b),
			Vector3.new(ROAD_W, 0.4, (b - a).Magnitude + ROAD_W)
		)
	end
	for i, p in ipairs(full) do
		seg("Cap" .. i, CFrame.new(p.X, 0.6, p.Z), Vector3.new(ROAD_W, 0.4, ROAD_W))
	end

	print("[DevTestMap] built graybox test map (Spawn, Base, " .. #points .. " waypoints + road)")
end

return DevTestMap
