--!strict
-- Authoritative placement validation. Pure-ish (Map + configs only) so it can't
-- desync from the rules. The client mirrors the same checks for the ghost tint;
-- this is the source of truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Shared").Configs
local Towers = require(Configs.Towers)
local Balance = require(Configs.Balance)
local Map = require(script.Parent.Map)

local PlacementService = {}

export type Existing = { def: Towers.Tower, position: Vector3 }

-- Returns (ok, reason). `existing` = already-placed towers (for overlap), `cash` =
-- current in-round cash, `unlocked` = set of tower types the player may place.
function PlacementService.validate(
	towerType: string,
	position: Vector3,
	existing: { Existing },
	cash: number,
	unlocked: { [string]: boolean }
): (boolean, string)
	local def = Towers[towerType]
	if not def then
		return false, "Unknown tower"
	end
	if not unlocked[towerType] then
		return false, "Tower locked"
	end
	if cash < def.cost then
		return false, "Not enough cash"
	end
	if Map.distanceToPath(position) < (Balance.PathClearance + def.placementRadius) then
		return false, "Too close to the path"
	end
	for _, t in existing do
		local d = (Vector2.new(position.X, position.Z) - Vector2.new(t.position.X, t.position.Z)).Magnitude
		if d < (def.placementRadius + t.def.placementRadius) then
			return false, "Overlaps another tower"
		end
	end
	return true, "ok"
end

return PlacementService
