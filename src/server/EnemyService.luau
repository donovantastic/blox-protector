--!strict
-- Spawns enemies and walks them along the path (server-authoritative, CFrame-
-- driven — no Humanoid physics jank). Tracks health + distance-travelled (the
-- latter is what tower targeting will use for "first"/"last"). Graybox-first:
-- if a model isn't in ReplicatedStorage.Assets.Enemies yet, it builds a colored
-- part so the loop works before Xander makes art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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
	bar: Frame?, -- health-bar fill
	slowMult: number, -- current speed multiplier from paint (1 = normal speed)
	slowUntil: number, -- os.clock() time the paint wears off (0 = not painted)
	baseColor: Color3, -- the enemy's normal color, so we can restore it after the paint fades
}

local EnemyService = {}

-- callbacks wired in init.server
EnemyService.onLeak = function(_enemy: Enemy) end :: (Enemy) -> ()
EnemyService.onDeath = function(_enemy: Enemy) end :: (Enemy) -> ()

local active: { Enemy } = {}
local nextId = 0
local container: Folder
local frozenUntil = 0 -- Defrag card: all enemies stop moving until this clock time

-- The pink an enemy turns while it's covered in paint (mixed with its own color so
-- you can still tell enemies apart). Purely visual — it's how you SEE the slow working.
local PAINT_COLOR = Color3.fromRGB(255, 95, 200)

local GRAYBOX_COLORS: { [string]: Color3 } = {
	Grunt = Color3.fromRGB(200, 80, 80),
	Runner = Color3.fromRGB(240, 200, 70),
	Brute = Color3.fromRGB(120, 60, 160),
	Boss = Color3.fromRGB(210, 70, 235),
	Boss2 = Color3.fromRGB(245, 110, 50),
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
	part.Size = Vector3.new(2, 2, 2) * (def.scale or 1)
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

local function buildHealthBar(primary: BasePart): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Adornee = primary
	gui.Size = UDim2.fromOffset(56, 8)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 240
	gui.Parent = primary

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
end

local function deathPop(position: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1, 1, 1)
	p.Position = position
	p.Parent = Workspace
	TweenService:Create(
		p,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(5, 5, 5), Transparency = 1 }
	):Play()
	Debris:AddItem(p, 0.3)
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
	model:SetAttribute("EnemyId", nextId)
	model:SetAttribute("Health", hp)
	model:SetAttribute("MaxHealth", hp)
	model:SetAttribute("Boss", def.boss == true)

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
		slowMult = 1, -- not painted yet → full speed
		slowUntil = 0,
		baseColor = primary.Color,
	}
	enemy.bar = buildHealthBar(primary)
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
	if enemy.bar then
		enemy.bar.Size = UDim2.fromScale(math.max(0, enemy.health) / enemy.maxHealth, 1)
	end
	if enemy.health <= 0 then
		deathPop(enemy.primary.Position, enemy.primary.Color)
		despawn(enemy)
		EnemyService.onDeath(enemy)
		return true
	end
	return false
end

-- Freeze all enemies for `duration` seconds (Defrag card).
function EnemyService.freezeAll(duration: number)
	frozenUntil = os.clock() + duration
end

-- Splatter ONE enemy with paint: it moves at `mult` of its speed for `duration`
-- seconds (the Paint Splatterer tower calls this on every hit). Getting hit again
-- just refreshes the timer, so steady fire keeps an enemy gummed up the whole time.
function EnemyService.applySlow(enemy: Enemy, mult: number, duration: number)
	if enemy.dead then
		return
	end
	enemy.slowMult = mult
	enemy.slowUntil = os.clock() + duration
end

-- Move every active enemy one frame along the path.
function EnemyService.step(dt: number)
	local path = Map.getPath()
	local frozen = os.clock() < frozenUntil
	for i = #active, 1, -1 do
		local enemy = active[i]
		if enemy.dead then
			table.remove(active, i)
			continue
		end

		-- Paint visual: pink while the slow is active, back to normal once it wears off.
		local painted = os.clock() < enemy.slowUntil
		local wantColor = if painted
			then enemy.baseColor:Lerp(PAINT_COLOR, 0.7)
			else enemy.baseColor
		if enemy.primary.Color ~= wantColor then
			enemy.primary.Color = wantColor
		end

		if frozen then
			continue -- defragged: hold position
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
		-- paint slows the enemy down: full speed normally, slowMult while painted
		local speed = if painted then enemy.def.speed * enemy.slowMult else enemy.def.speed
		local step = speed * dt

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
		if distLeft > 0.001 then
			-- face along the direction of travel — always a valid lookAt (avoids the
			-- "position == lookAt" error when we land exactly on a waypoint).
			enemy.primary.CFrame = CFrame.lookAt(newPos, newPos + toTarget.Unit)
		else
			enemy.primary.CFrame = CFrame.new(newPos)
		end
	end
end

-- For TowerService targeting.
function EnemyService.getActive(): { Enemy }
	return active
end

-- For card targeting: find a live enemy by its EnemyId.
function EnemyService.getById(id: number): Enemy?
	for _, e in active do
		if e.id == id and not e.dead then
			return e
		end
	end
	return nil
end

return EnemyService
