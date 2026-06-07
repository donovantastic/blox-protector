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

-- solo: a single shared unlocked set (the 3 starters; more from the Merchant)
local unlocked: { [string]: boolean } = {}
for _, t in Balance.StarterTowers do
	unlocked[t] = true
end

function TowerService.unlock(towerType: string)
	unlocked[towerType] = true
end

function TowerService.isUnlocked(towerType: string): boolean
	return unlocked[towerType] == true
end

local GRAYBOX: { [string]: Color3 } = {
	Pelter = Color3.fromRGB(90, 170, 250),
	Sniper = Color3.fromRGB(250, 210, 90),
	Splash = Color3.fromRGB(150, 120, 240),
	Sword = Color3.fromRGB(185, 192, 205),
	Paintball = Color3.fromRGB(255, 95, 200), -- hot pink — matches the paint splatter
	Superball = Color3.fromRGB(120, 235, 90), -- bouncy lime rubber ball
	Drill = Color3.fromRGB(255, 140, 40), -- molten-orange industrial drill
}

-- A custom graybox for the Drill: a tiered metal cone (a stack of discs that shrink
-- toward a point), built from Cylinder parts. Each disc is rotated 90° so its flat
-- faces point up/down — stacking them makes the stepped drill-bit shape. Replaced
-- automatically if a real "Drill" model is ever added under Assets.Towers.
local function buildDrillModel(model: Model, position: Vector3): (Model, BasePart)
	local METAL = Color3.fromRGB(150, 168, 198) -- bluish steel, like the reference
	local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- stand a cylinder on its end

	-- wide mounting disc on the ground
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.8, 5.6, 5.6) -- 0.8 thick, 5.6 across
	base.CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)) * UPRIGHT
	base.Color = METAL:Lerp(Color3.new(0, 0, 0), 0.4)
	base.Material = Enum.Material.Metal
	base.Parent = model

	-- the drill itself: discs of shrinking radius stacked into a cone
	local radii = { 2.2, 1.75, 1.35, 1.0, 0.65, 0.32 }
	local segHeight = 0.85
	local y = 0.8 -- start at the top of the base
	for i, r in radii do
		local seg = Instance.new("Part")
		seg.Name = "Bit" .. i
		seg.Anchored = true
		seg.CanCollide = false
		seg.Shape = Enum.PartType.Cylinder
		seg.Size = Vector3.new(segHeight, r * 2, r * 2)
		seg.CFrame = CFrame.new(position + Vector3.new(0, y + segHeight / 2, 0)) * UPRIGHT
		-- lighten toward the tip so the metal catches the light like the picture
		seg.Color = METAL:Lerp(Color3.fromRGB(228, 234, 246), (i - 1) / #radii * 0.55)
		seg.Material = Enum.Material.Metal
		seg.Parent = model
		y += segHeight
	end

	-- invisible aim point at the tip: TowerService rotates this to face enemies and
	-- fires the tracer from here, while the cone itself stays standing upright
	local turret = Instance.new("Part")
	turret.Name = "Turret"
	turret.Anchored = true
	turret.CanCollide = false
	turret.Transparency = 1
	turret.Size = Vector3.new(0.4, 0.4, 1.2) -- thin; -Z is the "barrel" for the muzzle
	turret.Position = position + Vector3.new(0, y, 0)
	turret.Parent = model

	model.PrimaryPart = base
	return model, turret
end

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

	-- the Drill gets a hand-built cone graybox instead of the plain box
	if towerType == "Drill" then
		return buildDrillModel(model, position)
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
	turret.Position = position + Vector3.new(0, 1.8, 0) -- sits on the base (no gap)
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
	local killed = EnemyService.takeDamage(target, level(tower).damage)
	-- if this tower's shot carries a debuff (paint = slow), splatter the enemy —
	-- but only if it's still alive (no point painting something we just destroyed)
	local debuff = tower.def.debuff
	if debuff and not killed then
		EnemyService.applySlow(target, debuff.slowMult, debuff.duration)
	end
	-- superball: bounce the enemy back down the path (skip if we just killed it)
	if tower.def.knockback and not killed then
		EnemyService.knockback(target, tower.def.knockback)
	end
end

function TowerService.step(dt: number)
	local enemies = EnemyService.getActive()
	for _, tower in towers do
		if tower.cooldown > 0 then
			tower.cooldown = math.max(0, tower.cooldown - dt) -- reload even while idle
		end
		local target = pickTarget(tower, enemies)
		if target then
			aim(tower, target.primary.Position)
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
	-- snap to ground level (the gauntlet floor is flat at y=0) so a high raycast
	-- hit can never leave the tower floating
	position = Vector3.new(position.X, 0, position.Z)
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
