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
	abilityCooldown: number, -- seconds left before this enemy can use its drill ability again
}

-- A friendly pin summoned by the Pin Factory tower: walks the track the WRONG way
-- (toward the enemy spawn) and rams the first enemy it meets.
type Ally = {
	model: Model,
	primary: BasePart,
	waypointIndex: number, -- counts DOWN toward the enemy spawn (path[1])
	speed: number,
	damage: number,
	dead: boolean,
	color: Color3, -- this pin's random body color (also used for its pop)
	ramRadius: number, -- how close an enemy must be to get rammed (bigger for the mega pin)
	explodeRadius: number, -- mega pin: AoE blast radius on impact (0 = normal single-target pin)
	shootRange: number, -- shooter pin: how far it can shoot enemies (0 = no gun)
	shootDamage: number, -- shooter pin: damage per shot
	shootCooldown: number, -- shooter pin: seconds left until it can shoot again
}

local EnemyService = {}

-- callbacks wired in init.server
EnemyService.onLeak = function(_enemy: Enemy) end :: (Enemy) -> ()
EnemyService.onDeath = function(_enemy: Enemy) end :: (Enemy) -> ()

local active: { Enemy } = {}
local allies: { Ally } = {}
local nextId = 0
local container: Folder
local frozenUntil = 0 -- Defrag card: all enemies stop moving until this clock time

-- Friendly pins (allies) charge fast and ram anything within this radius. Each one
-- gets a random color when it spawns.
local ALLY_SPEED = 16
local ALLY_RAM_RADIUS = 5

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

-- Custom multi-part graybox for the Push-Pin enemy: a red flared "pin" body with a
-- smug face and a little steel drill-spike on top. Everything is built around the
-- body (the PrimaryPart) at the local origin; the movement loop pivots the whole
-- model, so all of these parts travel together.
local function buildPinEnemy(
	modelName: string,
	scale: number?,
	bodyColor: Color3?,
	attachment: string? -- nil | "gun" | "rockets" — extra gear bolted on for special pins
): (Model, BasePart)
	local RED = bodyColor or Color3.fromRGB(225, 35, 35) -- enemies red; friendly allies pass blue
	local BLACK = Color3.fromRGB(20, 20, 22)
	local STEEL = Color3.fromRGB(150, 165, 195)
	local model = Instance.new("Model")
	model.Name = modelName

	local function piece(
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end

	-- red flared body: a tall core, a wide collar up top, a wide skirt at the base
	local body = piece(
		"Body",
		Vector3.new(2.3, 3.4, 1.5),
		CFrame.new(0, 0, 0),
		RED,
		Enum.Material.SmoothPlastic
	)
	piece(
		"Collar",
		Vector3.new(2.9, 0.55, 1.85),
		CFrame.new(0, 1.45, 0),
		RED,
		Enum.Material.SmoothPlastic
	)
	piece(
		"Skirt",
		Vector3.new(3.1, 0.8, 2.0),
		CFrame.new(0, -1.3, 0),
		RED,
		Enum.Material.SmoothPlastic
	)

	-- cartoon face on the front (-Z is the direction it walks, so it leads with its face)
	local FZ = -0.78
	piece(
		"EyeL",
		Vector3.new(0.32, 0.42, 0.12),
		CFrame.new(-0.45, 0.45, FZ),
		BLACK,
		Enum.Material.SmoothPlastic
	)
	piece(
		"EyeR",
		Vector3.new(0.32, 0.42, 0.12),
		CFrame.new(0.45, 0.45, FZ),
		BLACK,
		Enum.Material.SmoothPlastic
	)
	-- the smug raised eyebrow
	piece(
		"Brow",
		Vector3.new(0.6, 0.14, 0.12),
		CFrame.new(-0.45, 0.86, FZ) * CFrame.Angles(0, 0, math.rad(-18)),
		BLACK,
		Enum.Material.SmoothPlastic
	)
	-- smile: a flat middle with two ends turned up (ends sit higher than the middle)
	piece(
		"MouthMid",
		Vector3.new(0.7, 0.14, 0.1),
		CFrame.new(0, -0.45, FZ),
		BLACK,
		Enum.Material.SmoothPlastic
	)
	piece(
		"MouthL",
		Vector3.new(0.34, 0.14, 0.1),
		CFrame.new(-0.48, -0.36, FZ) * CFrame.Angles(0, 0, math.rad(38)),
		BLACK,
		Enum.Material.SmoothPlastic
	)
	piece(
		"MouthR",
		Vector3.new(0.34, 0.14, 0.1),
		CFrame.new(0.48, -0.36, FZ) * CFrame.Angles(0, 0, math.rad(-38)),
		BLACK,
		Enum.Material.SmoothPlastic
	)

	-- steel drill-spike on top: stacked discs of shrinking radius, like the Dev Drill
	local STEEL_TIP = Color3.fromRGB(225, 232, 245)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local radii = { 0.5, 0.37, 0.25, 0.13 }
	local segHeight = 0.4
	local sy = 1.75 -- just above the collar
	for i, r in radii do
		piece(
			"Spike" .. i,
			Vector3.new(segHeight, r * 2, r * 2),
			CFrame.new(0, sy + segHeight / 2, 0) * upright,
			STEEL:Lerp(STEEL_TIP, (i - 1) / #radii * 0.6),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		sy += segHeight
	end

	-- tank tracks at the base (it rolls, it doesn't walk): two dark treads, each with
	-- a front and rear wheel poking out the ends
	local TRACK = Color3.fromRGB(40, 43, 50)
	local WHEEL = Color3.fromRGB(72, 76, 84)
	for _, side in { -1, 1 } do
		local x = side * 1.6
		piece(
			if side < 0 then "TrackL" else "TrackR",
			Vector3.new(0.7, 1.0, 2.8),
			CFrame.new(x, -1.2, 0),
			TRACK,
			Enum.Material.Metal
		)
		for _, z in { -1.0, 1.0 } do
			piece(
				"Wheel",
				Vector3.new(0.78, 0.9, 0.9),
				CFrame.new(x, -1.25, z),
				WHEEL,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end

	-- a battery strapped to its back (+Z is the back, since it leads with its face)
	local BATTERY = Color3.fromRGB(70, 180, 95)
	local GOLD = Color3.fromRGB(235, 200, 80)
	piece(
		"Battery",
		Vector3.new(1.2, 1.5, 0.7),
		CFrame.new(0, 0.25, 1.15),
		BATTERY,
		Enum.Material.SmoothPlastic
	)
	piece( -- a stripe around its middle
		"BatteryBand",
		Vector3.new(1.26, 0.34, 0.76),
		CFrame.new(0, 0.05, 1.15),
		GOLD,
		Enum.Material.SmoothPlastic
	)
	piece( -- the little + terminal on top
		"BatteryTip",
		Vector3.new(0.34, 0.34, 0.34),
		CFrame.new(0, 1.05, 1.15) * CFrame.Angles(0, 0, math.rad(90)),
		GOLD,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	-- special gear (built BEFORE ScaleTo so it grows with the pin)
	if attachment == "gun" then
		local GUNMETAL = Color3.fromRGB(45, 48, 56)
		piece(
			"Gun",
			Vector3.new(0.6, 0.55, 1.1),
			CFrame.new(0, 2.0, -0.4),
			GUNMETAL,
			Enum.Material.Metal
		)
		piece(
			"Barrel",
			Vector3.new(1.6, 0.3, 0.3),
			CFrame.new(0, 2.05, -1.2) * CFrame.Angles(0, math.rad(90), 0), -- point it forward
			GUNMETAL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	elseif attachment == "rockets" then
		for _, side in { -1, 1 } do
			local x = side * 1.75
			piece(
				"Rocket",
				Vector3.new(1.8, 0.7, 0.7),
				CFrame.new(x, 0.1, -0.1) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(235, 235, 240),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			piece( -- red nose cone
				"RocketTip",
				Vector3.new(0.5, 0.62, 0.62),
				CFrame.new(x, 0.1, -1.05) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(220, 50, 40),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end

	model.PrimaryPart = body
	-- grow the whole model as one (bosses are big). ScaleTo scales every part around
	-- the pivot, so the proportions stay exactly the same — just bigger.
	if scale then
		model:ScaleTo(scale)
	end
	return model, body
end

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

	-- the Push-Pin gets a hand-built multi-part graybox instead of a plain box
	if def.model == "Pin" then
		return buildPinEnemy(def.model, def.scale)
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

	-- PivotTo moves the WHOLE model (every part), not just the primary — so multi-part
	-- enemies like the Push-Pin keep their pieces together as they travel.
	model:PivotTo(CFrame.new(path[1] + Vector3.new(0, primary.Size.Y / 2, 0)))
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
		-- wait one full cooldown before the first drill (a brief grace period)
		abilityCooldown = if def.ability then def.ability.cooldown else 0,
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

-- Wipe the board for a fresh round: destroy every enemy AND every friendly pin.
function EnemyService.reset()
	for _, enemy in active do
		enemy.model:Destroy()
	end
	table.clear(active)
	for _, ally in allies do
		ally.model:Destroy()
	end
	table.clear(allies)
	frozenUntil = 0
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

-- Bounce ONE enemy `studs` BACKWARD along the path (the Superball tower). We don't
-- shove it in a straight line — we walk it back along the waypoints it already
-- passed, stepping past earlier waypoints if the hit is big enough, and stopping at
-- the spawn (it can't be knocked off the start of the track).
function EnemyService.knockback(enemy: Enemy, studs: number)
	if enemy.dead then
		return
	end
	local path = Map.getPath()
	if #path == 0 then
		return
	end
	local half = enemy.primary.Size.Y / 2
	local pos = enemy.primary.Position - Vector3.new(0, half, 0) -- ground position
	local idx = enemy.waypointIndex -- heading toward path[idx], came from path[idx-1]
	local remaining = studs
	while remaining > 0 do
		local prev = path[idx - 1]
		if not prev then
			break -- reached the spawn end; nothing further back to bounce toward
		end
		local toPrev = prev - pos
		local back = toPrev.Magnitude
		if remaining < back then
			pos = pos + toPrev.Unit * remaining -- land partway down this segment
			remaining = 0
		else
			pos = prev -- snap to the earlier waypoint and keep bouncing back
			remaining -= back
			idx -= 1
		end
	end
	enemy.waypointIndex = math.max(2, idx) -- can't head toward anything before path[2]
	enemy.distance = math.max(0, enemy.distance - (studs - remaining)) -- keep targeting honest
	-- move the WHOLE model to the new spot while keeping its current facing
	local facing = enemy.primary.CFrame - enemy.primary.CFrame.Position
	enemy.model:PivotTo(facing + (pos + Vector3.new(0, half, 0)))
end

-- Spawn a FRIENDLY pin near `nearPosition` that charges UP the track (toward the
-- enemy spawn) and rams the first enemy it meets for `damage`. Used by the Pin
-- Factory tower. `maxLevel` (the factory is fully upgraded) unlocks rarer variants.
function EnemyService.spawnAlly(damage: number, nearPosition: Vector3, maxLevel: boolean)
	local path = Map.getPath()
	if #path < 2 then
		return
	end
	-- start it at the path point closest to the summoning tower
	local startIdx = 1
	local bestD = math.huge
	for i, wp in path do
		local d = (wp - nearPosition).Magnitude
		if d < bestD then
			bestD = d
			startIdx = i
		end
	end

	-- Roll the variant from one random number. The mega jackpot can always happen;
	-- the shooter and rocket variants only appear once the factory is maxed out.
	--   [0, 0.01)  -> mega   (1%)
	--   [0.01,0.11)-> rocket (10%, max only)  high damage + speed, explodes
	--   [0.11,0.36)-> shooter(25%, max only)  carries a gun and fires as it advances
	local roll = math.random()
	local mega = roll < 0.01
	local rocket = maxLevel and not mega and roll < 0.11
	local shooter = maxLevel and not mega and not rocket and roll < 0.36

	-- defaults: a plain random-color pin
	local scale = 0.9
	local color = Color3.fromHSV(math.random(), 0.65, 1)
	local speed = ALLY_SPEED
	local dmg = damage
	local ramR = ALLY_RAM_RADIUS
	local explodeR = 0
	local attach: string? = nil
	local shootRange = 0
	local shootDmg = 0

	if mega then
		scale, color, dmg = 2.6, Color3.fromRGB(255, 215, 0), damage * 10
		ramR, explodeR = ALLY_RAM_RADIUS * 2.5, ALLY_RAM_RADIUS * 5
	elseif rocket then
		scale, color = 1.3, Color3.fromRGB(255, 90, 40)
		speed, dmg = ALLY_SPEED * 2, damage * 3 -- high speed + high damage
		ramR, explodeR = ALLY_RAM_RADIUS * 1.4, ALLY_RAM_RADIUS * 2 -- the rockets blow up
		attach = "rockets"
	elseif shooter then
		color = Color3.fromRGB(120, 130, 150)
		attach = "gun"
		shootRange, shootDmg = 22, damage -- shoots enemies as it rolls in
	end

	local model, primary = buildPinEnemy("AllyPin", scale, color, attach)
	local ally: Ally = {
		model = model,
		primary = primary,
		waypointIndex = startIdx - 1, -- head toward the enemy spawn
		speed = speed,
		damage = dmg,
		dead = false,
		color = color,
		ramRadius = ramR,
		explodeRadius = explodeR,
		shootRange = shootRange,
		shootDamage = shootDmg,
		shootCooldown = 0,
	}
	model:PivotTo(CFrame.new(path[startIdx] + Vector3.new(0, primary.Size.Y / 2, 0)))
	model.Parent = container
	table.insert(allies, ally)
end

-- A big expanding blast sphere, sized to the explosion radius (the mega pin's boom).
local function bigBoom(position: Vector3, color: Color3, radius: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(2, 2, 2)
	p.Position = position
	p.Parent = Workspace
	local full = radius * 2 -- diameter
	TweenService:Create(
		p,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(full, full, full), Transparency = 1 }
	):Play()
	Debris:AddItem(p, 0.4)
end

-- A quick shot line from a shooter pin to its target.
local function beam(from: Vector3, to: Vector3, color: Color3)
	local dist = (to - from).Magnitude
	if dist < 0.05 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.18, 0.18, dist)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = Workspace
	Debris:AddItem(p, 0.06)
end

-- Move the friendly pins up the track; ram (and spend themselves on) the first
-- enemy they touch.
local function stepAllies(dt: number)
	local path = Map.getPath()
	for i = #allies, 1, -1 do
		local ally = allies[i]
		if ally.dead then
			table.remove(allies, i)
			continue
		end

		-- shooter pins fire at the nearest enemy in range as they advance
		if ally.shootRange > 0 then
			ally.shootCooldown -= dt
			if ally.shootCooldown <= 0 then
				local nearest: Enemy? = nil
				local nd = ally.shootRange
				for _, enemy in active do
					if not enemy.dead then
						local d = (enemy.primary.Position - ally.primary.Position).Magnitude
						if d <= nd then
							nd = d
							nearest = enemy
						end
					end
				end
				if nearest then
					EnemyService.takeDamage(nearest, ally.shootDamage)
					beam(ally.primary.Position, nearest.primary.Position, ally.color)
					ally.shootCooldown = 0.6
				else
					ally.shootCooldown = 0.2 -- nothing in range; check again soon
				end
			end
		end

		-- did we bump an enemy?
		local rammed = false
		for _, enemy in active do
			local d = (enemy.primary.Position - ally.primary.Position).Magnitude
			if not enemy.dead and d <= ally.ramRadius then
				rammed = true
				break
			end
		end
		if rammed then
			-- normal pin hits the one it touched; the MEGA pin EXPLODES, hitting every
			-- enemy in a blast 5x as wide
			local blast = if ally.explodeRadius > 0 then ally.explodeRadius else ally.ramRadius
			local single = ally.explodeRadius <= 0
			for _, enemy in active do
				local d = (enemy.primary.Position - ally.primary.Position).Magnitude
				if not enemy.dead and d <= blast then
					EnemyService.takeDamage(enemy, ally.damage)
					if single then
						break
					end
				end
			end
			if ally.explodeRadius > 0 then
				bigBoom(ally.primary.Position, ally.color, ally.explodeRadius)
			else
				deathPop(ally.primary.Position, ally.color)
			end
			ally.model:Destroy()
			table.remove(allies, i)
			continue
		end

		local target = path[ally.waypointIndex]
		if not target then
			ally.model:Destroy() -- reached the spawn without a kill — spent
			table.remove(allies, i)
			continue
		end
		local pos = ally.primary.Position - Vector3.new(0, ally.primary.Size.Y / 2, 0)
		local toTarget = target - pos
		local distLeft = toTarget.Magnitude
		local stepDist = ally.speed * dt
		local newGround: Vector3
		if stepDist >= distLeft then
			newGround = target
			ally.waypointIndex -= 1
		else
			newGround = pos + toTarget.Unit * stepDist
		end
		local newPos = newGround + Vector3.new(0, ally.primary.Size.Y / 2, 0)
		if distLeft > 0.001 then
			ally.model:PivotTo(CFrame.lookAt(newPos, newPos + toTarget.Unit))
		else
			ally.model:PivotTo(CFrame.new(newPos))
		end
	end
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
			enemy.model:PivotTo(CFrame.lookAt(newPos, newPos + toTarget.Unit))
		else
			enemy.model:PivotTo(CFrame.new(newPos))
		end
	end
	stepAllies(dt) -- friendly pins march the other way
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
