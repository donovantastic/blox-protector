--!strict
-- DEV graybox gauntlet maps (Spawn / Base / numbered Path + a visible road). One
-- layout per act so each battle plays on its own map. Studio-only. Rebuilds on
-- demand (buildGauntlet) — a real map replaces this later.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DevTestMap = {}

type Layout = { spawn: Vector3, base: Vector3, points: { Vector3 } }

local LAYOUTS: { [number]: Layout } = {
	[1] = { -- Chapter 1: the S-path
		spawn = Vector3.new(-60, 1, 0),
		base = Vector3.new(60, 1, 0),
		points = {
			Vector3.new(-30, 1, 0),
			Vector3.new(-30, 1, 30),
			Vector3.new(0, 1, 30),
			Vector3.new(0, 1, -30),
			Vector3.new(30, 1, -30),
			Vector3.new(30, 1, 0),
		},
	},
	[2] = { -- Chapter 2: a longer double-zigzag
		spawn = Vector3.new(-62, 1, 0),
		base = Vector3.new(62, 1, 28),
		points = {
			Vector3.new(-38, 1, -28),
			Vector3.new(-38, 1, 28),
			Vector3.new(-8, 1, 28),
			Vector3.new(-8, 1, -28),
			Vector3.new(22, 1, -28),
			Vector3.new(22, 1, 28),
			Vector3.new(48, 1, 28),
		},
	},
}

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

local function buildRoad(map: Instance, full: { Vector3 })
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
		p.CanQuery = false
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
end

-- (Re)build the gauntlet map for the given act. Studio-only.
function DevTestMap.buildGauntlet(act: number)
	if not RunService:IsStudio() then
		return
	end
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local layout = LAYOUTS[act] or LAYOUTS[1]

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	block("Spawn", layout.spawn, Vector3.new(8, 1, 8), Color3.fromRGB(80, 200, 120), map)
	block("Base", layout.base, Vector3.new(10, 4, 10), Color3.fromRGB(220, 80, 80), map)

	local path = Instance.new("Folder")
	path.Name = "Path"
	path.Parent = map
	for i, pos in ipairs(layout.points) do
		block(tostring(i), pos, Vector3.new(4, 1, 4), Color3.fromRGB(90, 90, 110), path)
	end

	local full = { layout.spawn }
	for _, p in ipairs(layout.points) do
		table.insert(full, p)
	end
	table.insert(full, layout.base)
	buildRoad(map, full)

	print(("[DevTestMap] built gauntlet map for act %d (%d waypoints)"):format(act, #layout.points))
end

-- Initial build (Act 1) so the boot-time Map.init has something to read.
function DevTestMap.ensure()
	if Workspace:FindFirstChild("Map") then
		return
	end
	DevTestMap.buildGauntlet(1)
end

return DevTestMap
