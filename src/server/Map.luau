--!strict
-- The contract between Xander's Studio map and the code. Build this in Studio
-- (graybox parts are fine) and the systems just work:
--
--   Workspace.Map               (Folder or Model)
--     ├─ Spawn   (Part)         enemies appear here
--     ├─ Base    (Part)         enemies leak here = you lose HP (the thing you defend)
--     └─ Path    (Folder)       waypoint Parts named "1","2","3",... in walk order
--   + any number of Parts tagged "BuildZone" (CollectionService) — towers may only
--     be placed INSIDE one of these (and off the path). Tag via the Tag Editor.
--
-- Enemies walk: Spawn -> 1 -> 2 -> ... -> Base.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Map = {}

local waypoints: { Vector3 } = {}
local buildZones: { BasePart } = {}

local function numericSort(a: Instance, b: Instance): boolean
	return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge)
end

function Map.init()
	local map = Workspace:WaitForChild("Map")
	local spawn = map:WaitForChild("Spawn") :: BasePart
	local base = map:WaitForChild("Base") :: BasePart
	local path = map:WaitForChild("Path")

	local ordered = path:GetChildren()
	table.sort(ordered, numericSort)

	waypoints = { spawn.Position }
	for _, wp in ordered do
		if wp:IsA("BasePart") then
			table.insert(waypoints, wp.Position)
		end
	end
	table.insert(waypoints, base.Position)

	buildZones = {}
	for _, part in CollectionService:GetTagged("BuildZone") do
		if part:IsA("BasePart") then
			table.insert(buildZones, part)
		end
	end

	if #waypoints < 2 then
		warn("[Map] Path has no waypoints — enemies will run straight to Base.")
	end
	print(("[Map] ready: %d path points, %d build zones"):format(#waypoints, #buildZones))
end

-- Ordered world positions: Spawn, each waypoint, Base.
function Map.getPath(): { Vector3 }
	return waypoints
end

function Map.getBuildZones(): { BasePart }
	return buildZones
end

-- True if `position` is inside any BuildZone's XZ footprint (used by placement, Phase 2).
function Map.isInBuildZone(position: Vector3): boolean
	for _, zone in buildZones do
		local local_ = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size / 2
		if math.abs(local_.X) <= half.X and math.abs(local_.Z) <= half.Z then
			return true
		end
	end
	return false
end

return Map
