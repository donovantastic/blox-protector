-- Paste into the Studio Command Bar (Edit mode) and run once to generate a graybox
-- test map: Workspace.Map with Spawn, Base, and an S-shaped Path. Then Save the place.
-- Re-running deletes the old Map first, so it's safe to tweak + re-run.

local old = workspace:FindFirstChild("Map")
if old then old:Destroy() end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function block(name, pos, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Spawn (green) and Base (red)
block("Spawn", Vector3.new(-60, 1, 0), Vector3.new(8, 1, 8), Color3.fromRGB(80, 200, 120), map)
block("Base", Vector3.new(60, 1, 0), Vector3.new(10, 4, 10), Color3.fromRGB(220, 80, 80), map)

-- S-shaped path of numbered waypoints (enemies walk Spawn -> 1 -> 2 -> ... -> Base)
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

print(("[TestMap] built: Spawn, Base, and %d waypoints. Press Play."):format(#points))
