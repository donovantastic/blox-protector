--!strict
-- The contract between Xander's Studio map and the code. Build this in Studio
-- (graybox parts are fine) and the systems just work:
--
--   Workspace.Map               (Folder or Model)
--     ├─ Spawn   (Part)         enemies appear here
--     ├─ Base    (Part)         enemies leak here = you lose HP (the thing you defend)
--     └─ Path    (Folder)       waypoint Parts named "1","2","3",... in walk order
--
-- Enemies walk: Spawn -> 1 -> 2 -> ... -> Base. Towers may be placed anywhere off
-- the path (Map.distanceToPath gates that).

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathUtil = require(ReplicatedStorage:WaitForChild("Shared").PathUtil)

local Map = {}

local waypoints: { Vector3 } = {}
local buildZones: { BasePart } = {}

function Map.init()
	local map = Workspace:WaitForChild("Map")
	map:WaitForChild("Spawn")
	map:WaitForChild("Base")
	map:WaitForChild("Path")

	waypoints = PathUtil.getWaypoints(map)

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

-- Shortest XZ distance from `position` to the path.
function Map.distanceToPath(position: Vector3): number
	return PathUtil.distanceToPath(waypoints, position)
end

return Map
