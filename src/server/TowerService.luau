--!strict
-- Towers: placement, targeting, hitscan combat, upgrades, sell. Server-authoritative.
-- Graybox-first (builds simple part towers; swap in Xander's models later by name).
-- Each placed tower exposes attributes (TowerId/TowerType/Level/Range/PlacementRadius)
-- so the client can draw range rings, overlap-check the ghost, and target upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Configs.Towers)
local Balance = require(Shared.Configs.Balance)
local PlacementService = require(script.Parent.PlacementService)
local Economy = require(script.Parent.EconomyService)
local EnemyService = require(script.Parent.EnemyService)

type Tower = {
	id: number,
	towerType: string,
	def: Towers.Tower,
	level: number,
	spent: number,
	position: Vector3,
	model: Model,
	turret: BasePart,
	cooldown: number,
}

local TowerService = {}

local towers: { [number]: Tower } = {}
local nextId = 0
local towersFolder: Folder
local tracersFolder: Folder

-- solo: a single shared unlocked set (the 3 starters)
local unlocked: { [string]: boolean } = {}
for _, t in Balance.StarterTowers do
	unlocked[t] = true
end

local GRAYBOX: { [string]: Color3 } = {
	Pelter = Color3.fromRGB(90, 170, 250),
	Sniper = Color3.fromRGB(250, 210, 90),
	Splash = Color3.fromRGB(150, 120, 240),
}

-- ---------------------------------------------------------------- model -------
local function buildTower(
	def: Towers.Tower,
	towerType: string,
	position: Vector3
): (Model, BasePart)
	local color = GRAYBOX[towerType] or Color3.fromRGB(180, 180, 190)
	local model = Instance.new("Model")
	model.Name = def.name

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local towersAssets = assets and assets:FindFirstChild("Towers")
	local template = towersAssets and towersAssets:FindFirstChild(def.model)
	if template and template:IsA("Model") and template.PrimaryPart then
		local clone = template:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		clone:PivotTo(CFrame.new(position))
		local turret = clone:FindFirstChild("Turret")
		return clone, (turret :: BasePart?) or clone.PrimaryPart :: BasePart
	end

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.Size = Vector3.new(def.placementRadius * 1.6, 1, def.placementRadius * 1.6)
	base.Position = position + Vector3.new(0, 0.5, 0)
	base.Color = color:Lerp(Color3.new(0, 0, 0), 0.35)
	base.Material = Enum.Material.SmoothPlastic
	base.Parent = model

	local turret = Instance.new("Part")
	turret.Name = "Turret"
	turret.Anchored = true
	turret.CanCollide = false
	turret.Size = Vector3.new(1.6, 1.6, 3) -- LookVector (-Z) is the barrel
	turret.Position = position + Vector3.new(0, 2.2, 0)
	turret.Color = color
	turret.Material = Enum.Material.SmoothPlastic
	turret.Parent = model

	model.PrimaryPart = base
	return model, turret
end

local function tracer(from: Vector3, to: Vector3, color: Color3)
	local dist = (to - from).Magnitude
	if dist < 0.05 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.2, 0.2, dist)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = tracersFolder
	Debris:AddItem(part, 0.06)
end

-- ---------------------------------------------------------------- combat ------
local function level(tower: Tower)
	return tower.def.levels[tower.level]
end

local function pickTarget(tower: Tower, enemies: { EnemyService.Enemy }): EnemyService.Enemy?
	local range = level(tower).range
	local best: EnemyService.Enemy? = nil
	local bestScore = -math.huge
	for _, enemy in enemies do
		if enemy.dead then
			continue
		end
		local d = (enemy.primary.Position - tower.position).Magnitude
		if d > range then
			continue
		end
		local score: number
		local mode = tower.def.targeting
		if mode == "first" then
			score = enemy.distance
		elseif mode == "last" then
			score = -enemy.distance
		elseif mode == "strongest" then
			score = enemy.health
		else -- "closest"
			score = -d
		end
		if score > bestScore then
			bestScore = score
			best = enemy
		end
	end
	return best
end

local function aim(tower: Tower, targetPos: Vector3)
	local flat = Vector3.new(targetPos.X, tower.turret.Position.Y, targetPos.Z)
	if (flat - tower.turret.Position).Magnitude > 0.05 then
		tower.turret.CFrame = CFrame.lookAt(tower.turret.Position, flat)
	end
end

local function fire(tower: Tower, target: EnemyService.Enemy)
	local muzzle = tower.turret.Position
		+ tower.turret.CFrame.LookVector * (tower.turret.Size.Z / 2)
	tracer(
		muzzle,
		target.primary.Position,
		GRAYBOX[tower.towerType] or Color3.fromRGB(255, 255, 255)
	)
	EnemyService.takeDamage(target, level(tower).damage)
end

function TowerService.step(dt: number)
	local enemies = EnemyService.getActive()
	for _, tower in towers do
		local target = pickTarget(tower, enemies)
		if target then
			aim(tower, target.primary.Position)
			tower.cooldown -= dt
			if tower.cooldown <= 0 then
				fire(tower, target)
				tower.cooldown = 1 / tower.def.fireRate
			end
		end
	end
end

-- ---------------------------------------------------------------- api ----------
local function existingForValidation(): { PlacementService.Existing }
	local out = {}
	for _, t in towers do
		table.insert(out, { def = t.def, position = t.position })
	end
	return out
end

local function applyAttributes(tower: Tower)
	tower.model:SetAttribute("TowerId", tower.id)
	tower.model:SetAttribute("TowerType", tower.towerType)
	tower.model:SetAttribute("Level", tower.level)
	tower.model:SetAttribute("Range", level(tower).range)
	tower.model:SetAttribute("PlacementRadius", tower.def.placementRadius)
	tower.model:SetAttribute("Spent", tower.spent)
end

-- Returns (ok, reason). On success the tower is built + cash spent.
function TowerService.place(
	_player: Player,
	towerType: string,
	position: Vector3
): (boolean, string)
	local def = Towers[towerType]
	if not def then
		return false, "Unknown tower"
	end
	local ok, reason = PlacementService.validate(
		towerType,
		position,
		existingForValidation(),
		Economy.getCash(),
		unlocked
	)
	if not ok then
		return false, reason
	end
	if not Economy.trySpend(def.cost) then
		return false, "Not enough cash"
	end

	local model, turret = buildTower(def, towerType, position)
	nextId += 1
	local tower: Tower = {
		id = nextId,
		towerType = towerType,
		def = def,
		level = 1,
		spent = def.cost,
		position = position,
		model = model,
		turret = turret,
		cooldown = 0,
	}
	towers[tower.id] = tower
	applyAttributes(tower)
	model.Parent = towersFolder
	return true, "ok"
end

function TowerService.upgrade(_player: Player, towerId: number): (boolean, string)
	local tower = towers[towerId]
	if not tower then
		return false, "No such tower"
	end
	local nextLevel = tower.def.levels[tower.level + 1]
	if not nextLevel then
		return false, "Max level"
	end
	if not Economy.trySpend(nextLevel.cost) then
		return false, "Not enough cash"
	end
	tower.level += 1
	tower.spent += nextLevel.cost
	applyAttributes(tower)
	return true, "ok"
end

function TowerService.sell(_player: Player, towerId: number): (boolean, string)
	local tower = towers[towerId]
	if not tower then
		return false, "No such tower"
	end
	Economy.add(math.floor(tower.spent * Balance.SellRefund))
	tower.model:Destroy()
	towers[towerId] = nil
	return true, "ok"
end

function TowerService.reset()
	for id, tower in towers do
		tower.model:Destroy()
		towers[id] = nil
	end
end

function TowerService.init()
	towersFolder = Instance.new("Folder")
	towersFolder.Name = "Towers"
	towersFolder.Parent = Workspace
	tracersFolder = Instance.new("Folder")
	tracersFolder.Name = "Tracers"
	tracersFolder.Parent = Workspace
	RunService.Heartbeat:Connect(function(dt)
		TowerService.step(dt)
	end)
end

return TowerService
