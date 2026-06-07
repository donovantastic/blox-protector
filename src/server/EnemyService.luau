--!strict
-- Spawns enemies and walks them along the path (server-authoritative, CFrame-
-- driven — no Humanoid physics jank). Tracks health + distance-travelled (the
-- latter is what tower targeting will use for "first"/"last"). Graybox-first:
-- if a model isn't in ReplicatedStorage.Assets.Enemies yet, it builds a colored
-- part so the loop works before Xander makes art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Enemies = require(ReplicatedStorage:WaitForChild("Shared").Configs.Enemies)
local Map = require(script.Parent.Map)

export type Enemy = {
	id: number,
	model: Model,
	primary: BasePart,
	def: Enemies.Enemy,
	health: number,
	maxHealth: number,
	waypointIndex: number, -- next path point we're walking toward
	distance: number, -- total studs travelled (for targeting)
	dead: boolean,
}

local EnemyService = {}

-- callbacks wired in init.server
EnemyService.onLeak = function(_enemy: Enemy) end :: (Enemy) -> ()
EnemyService.onDeath = function(_enemy: Enemy) end :: (Enemy) -> ()

local active: { Enemy } = {}
local nextId = 0
local container: Folder

local GRAYBOX_COLORS: { [string]: Color3 } = {
	Grunt = Color3.fromRGB(200, 80, 80),
	Runner = Color3.fromRGB(240, 200, 70),
	Brute = Color3.fromRGB(120, 60, 160),
}

local function buildModel(def: Enemies.Enemy): (Model, BasePart)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local enemiesFolder = assets and assets:FindFirstChild("Enemies")
	local template = enemiesFolder and enemiesFolder:FindFirstChild(def.model)

	if template and template:IsA("Model") and template.PrimaryPart then
		local clone = template:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		return clone, clone.PrimaryPart :: BasePart
	end

	-- graybox fallback
	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 2, 2)
	part.Color = GRAYBOX_COLORS[def.model] or Color3.fromRGB(200, 80, 80)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	local model = Instance.new("Model")
	model.Name = def.model
	part.Parent = model
	model.PrimaryPart = part
	return model, part
end

function EnemyService.init()
	container = Workspace:FindFirstChild("Enemies") :: Folder
	if not container then
		container = Instance.new("Folder")
		container.Name = "Enemies"
		container.Parent = Workspace
	end
	RunService.Heartbeat:Connect(function(dt: number)
		EnemyService.step(dt)
	end)
end

-- Spawn one enemy of `enemyType`, scaled by `healthMult`.
function EnemyService.spawn(enemyType: string, healthMult: number): Enemy?
	local def = Enemies[enemyType]
	if not def then
		warn("[Enemy] unknown enemy type:", enemyType)
		return nil
	end
	local path = Map.getPath()
	if #path == 0 then
		return nil
	end

	local model, primary = buildModel(def)
	nextId += 1
	local hp = math.floor(def.health * healthMult + 0.5)

	primary.CFrame = CFrame.new(path[1] + Vector3.new(0, primary.Size.Y / 2, 0))
	model.Parent = container
	model:SetAttribute("Health", hp)
	model:SetAttribute("MaxHealth", hp)

	local enemy: Enemy = {
		id = nextId,
		model = model,
		primary = primary,
		def = def,
		health = hp,
		maxHealth = hp,
		waypointIndex = 2, -- we start at path[1], walk toward path[2]
		distance = 0,
		dead = false,
	}
	table.insert(active, enemy)
	return enemy
end

local function despawn(enemy: Enemy)
	enemy.dead = true
	enemy.model:Destroy()
end

-- Apply damage; returns true if this killed it.
function EnemyService.takeDamage(enemy: Enemy, amount: number): boolean
	if enemy.dead then
		return false
	end
	enemy.health -= amount
	enemy.model:SetAttribute("Health", math.max(0, enemy.health))
	if enemy.health <= 0 then
		despawn(enemy)
		EnemyService.onDeath(enemy)
		return true
	end
	return false
end

-- Move every active enemy one frame along the path.
function EnemyService.step(dt: number)
	local path = Map.getPath()
	for i = #active, 1, -1 do
		local enemy = active[i]
		if enemy.dead then
			table.remove(active, i)
			continue
		end

		local target = path[enemy.waypointIndex]
		if not target then
			-- reached the Base → leak
			despawn(enemy)
			table.remove(active, i)
			EnemyService.onLeak(enemy)
			continue
		end

		local pos = enemy.primary.Position - Vector3.new(0, enemy.primary.Size.Y / 2, 0)
		local toTarget = target - pos
		local distLeft = toTarget.Magnitude
		local step = enemy.def.speed * dt

		local newGround: Vector3
		if step >= distLeft then
			newGround = target
			enemy.waypointIndex += 1
			enemy.distance += distLeft
		else
			newGround = pos + toTarget.Unit * step
			enemy.distance += step
		end

		local newPos = newGround + Vector3.new(0, enemy.primary.Size.Y / 2, 0)
		if distLeft > 0.05 then
			enemy.primary.CFrame =
				CFrame.lookAt(newPos, target + Vector3.new(0, enemy.primary.Size.Y / 2, 0))
		else
			enemy.primary.Position = newPos
		end
	end
end

-- For TowerService (Phase 2) targeting.
function EnemyService.getActive(): { Enemy }
	return active
end

return EnemyService
