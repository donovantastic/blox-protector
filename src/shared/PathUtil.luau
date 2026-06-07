--!strict
-- Path geometry shared by the server (authoritative placement validation) and the
-- client (instant ghost green/red). Reads waypoints straight off a Map instance so
-- both sides agree without replicating extra data.

local PathUtil = {}

local function numericName(inst: Instance): number
	return tonumber(inst.Name) or math.huge
end

-- Ordered world points: Spawn, the numbered Path children, Base.
function PathUtil.getWaypoints(map: Instance): { Vector3 }
	local points: { Vector3 } = {}
	local spawn = map:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		table.insert(points, spawn.Position)
	end
	local path = map:FindFirstChild("Path")
	if path then
		local ordered = path:GetChildren()
		table.sort(ordered, function(a, b)
			return numericName(a) < numericName(b)
		end)
		for _, wp in ordered do
			if wp:IsA("BasePart") then
				table.insert(points, wp.Position)
			end
		end
	end
	local base = map:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		table.insert(points, base.Position)
	end
	return points
end

local function distanceToSegmentXZ(p: Vector3, a: Vector3, b: Vector3): number
	local p2 = Vector2.new(p.X, p.Z)
	local a2 = Vector2.new(a.X, a.Z)
	local b2 = Vector2.new(b.X, b.Z)
	local ab = b2 - a2
	local abLen2 = ab:Dot(ab)
	local t = if abLen2 > 0 then math.clamp((p2 - a2):Dot(ab) / abLen2, 0, 1) else 0
	local closest = a2 + ab * t
	return (p2 - closest).Magnitude
end

-- Shortest XZ distance from `position` to the path (any segment).
function PathUtil.distanceToPath(waypoints: { Vector3 }, position: Vector3): number
	local minDist = math.huge
	for i = 1, #waypoints - 1 do
		minDist = math.min(minDist, distanceToSegmentXZ(position, waypoints[i], waypoints[i + 1]))
	end
	return minDist
end

return PathUtil
