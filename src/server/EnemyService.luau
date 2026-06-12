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
	stunnedUntil: number, -- os.clock() time a stun wears off (0 = not stunned); frozen + yellow
	confusedUntil: number, -- os.clock() time confusion wears off; walks BACKWARD + purple
}

-- A friendly pin summoned by the Pin Factory tower: walks the track the WRONG way
-- (toward the enemy spawn) and rams the first enemy it meets.
export type Ally = {
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
	windup: boolean, -- slingshot pin: true while rolling BACKWARD before it launches forward
	chainCount: number, -- storm pin: number of chain-lightning jumps on impact (0 = none)
	limbs: number, -- limb-shooter pin: limbs left to fire (0 = none / out of limbs)
	maxLimbs: number, -- limb-shooter pin: starting limb count (for the slowdown math)
	spawnOnDeath: number, -- trojan pin: how many mini pins it bursts into on impact (0 = none)
	floatHeight: number, -- floater pin: studs it hovers above the track (0 = rolls on the ground)
	drillDamage: number, -- drill pin: damage per tick as it bores THROUGH enemies (0 = not a drill)
	drillCooldown: number, -- drill pin: seconds until its next drill tick
	medic: boolean, -- medic pin: clears the stun off towers it passes (and doesn't ram)
	trail: boolean, -- trail pin: lays a glowing trail that boosts pins + burns enemies
	trailCooldown: number, -- trail pin: seconds until it drops the next trail blob
	stunDuration: number, -- stunner pin: seconds it freezes enemies on impact (0 = no stun)
	stunRadius: number, -- stunner pin: area of the stun
	lives: number, -- kitty pin: pounces left before it despawns (0 = not a kitty / used up)
	confuseDuration: number, -- confusion pin: seconds it turns enemies around (0 = none)
	confuseRadius: number, -- confusion pin: area of the confusion
}

-- A glowing blob a trail pin leaves behind: it speeds up friendly pins that pass
-- through it and burns enemies standing in it, until it fades.
type Trail = {
	position: Vector3,
	expireAt: number, -- os.clock() time it disappears
	damage: number, -- damage per tick to enemies inside
	radius: number,
	damageCooldown: number,
}

local EnemyService = {}

-- callbacks wired in init.server
EnemyService.onLeak = function(_enemy: Enemy) end :: (Enemy) -> ()
EnemyService.onDeath = function(_enemy: Enemy) end :: (Enemy) -> ()

local active: { Enemy } = {}
local allies: { Ally } = {}
local trails: { Trail } = {}
local nextId = 0
local container: Folder
local frozenUntil = 0 -- Defrag card: all enemies stop moving until this clock time

-- Friendly pins (allies) charge fast and ram anything within this radius. Each one
-- gets a random color when it spawns.
local ALLY_SPEED = 16
local ALLY_RAM_RADIUS = 5
local LIMB_COLOR = Color3.fromRGB(245, 245, 250) -- the white limbs the classic pin throws
local TRAIL_COLOR = Color3.fromRGB(120, 230, 255) -- the trail pin's glowing path
local TRAIL_RADIUS = 6
local TRAIL_BOOST = 1.6 -- how much faster pins move inside a trail

-- The pink an enemy turns while it's covered in paint (mixed with its own color so
-- you can still tell enemies apart). Purely visual — it's how you SEE the slow working.
local PAINT_COLOR = Color3.fromRGB(255, 95, 200)
local STUN_COLOR = Color3.fromRGB(255, 235, 90) -- enemies flash yellow while stunned
local CONFUSE_COLOR = Color3.fromRGB(180, 90, 240) -- enemies turn purple while confused

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
	attachment: string?, -- nil | "gun" | "rockets" | "storm" | "drill" | "medic" | "kitty" — gear
	bare: boolean? -- true = skip the mech (tracks/battery/drill spike); just a clean pin + needle
): (Model, BasePart)
	local RED = bodyColor or Color3.fromRGB(235, 40, 45) -- enemies red; friendly allies pass blue
	local BLACK = Color3.fromRGB(20, 20, 22)
	local STEEL = Color3.fromRGB(150, 165, 195)
	-- rotates a Cylinder part (its round faces point along X) so it stands upright along Y
	local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
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

	-- red flared spool: an upright cylinder core, a wide collar disc up top, a wide skirt
	-- disc at the base. The core is a plain Block part wearing a CylinderMesh — the mesh draws
	-- it as a vertical cylinder while the PART stays a box. We can't use a real Cylinder part
	-- here: the body is the PrimaryPart and the movement loop re-aims the PrimaryPart to face
	-- travel, which tips a Cylinder part onto its side. Block + CylinderMesh keeps the cylinder
	-- look AND stays upright (and the part's Color still drives the status tint). A little
	-- Reflectance gives it a glossy candy shine.
	local body = piece(
		"Body",
		Vector3.new(2.3, 3.4, 1.5), -- same footprint as the old box body, rounded into a cylinder
		CFrame.new(0, 0, 0),
		RED,
		Enum.Material.SmoothPlastic
	)
	body.Reflectance = 0.12
	local bodyMesh = Instance.new("CylinderMesh")
	bodyMesh.Parent = body
	local collar = piece(
		"Collar",
		Vector3.new(0.55, 2.9, 2.9),
		CFrame.new(0, 1.45, 0) * UPRIGHT,
		RED,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	collar.Reflectance = 0.12
	local skirt = piece(
		"Skirt",
		Vector3.new(0.8, 3.1, 3.1),
		CFrame.new(0, -1.3, 0) * UPRIGHT,
		RED,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	skirt.Reflectance = 0.12

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

	-- the mech: a normal pin has a drill-spike, tank tracks, and a battery. A "bare"
	-- pin skips all that and just gets a simple needle on top (a clean classic pin).
	if bare then
		local needle = piece(
			"Needle",
			Vector3.new(0.16, 2.6, 0.16),
			CFrame.new(0, 3.0, 0),
			STEEL,
			Enum.Material.Metal
		)
		needle.Reflectance = 0.25 -- a steel gleam
	else
		-- steel drill-spike on top: stacked discs of shrinking radius, like the Dev Drill
		local STEEL_TIP = Color3.fromRGB(225, 232, 245)
		local radii = { 0.5, 0.37, 0.25, 0.13 }
		local segHeight = 0.4
		local sy = 1.75 -- just above the collar
		for i, r in radii do
			piece(
				"Spike" .. i,
				Vector3.new(segHeight, r * 2, r * 2),
				CFrame.new(0, sy + segHeight / 2, 0) * UPRIGHT,
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
	end

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
	elseif attachment == "storm" then
		-- a tesla rig: a glowing energy core on the spike + two antenna rods with
		-- glowing ball tips. Neon material makes them actually emit light = very visible.
		local NEON = Color3.fromRGB(120, 235, 255)
		local ROD = Color3.fromRGB(60, 70, 90)
		piece(
			"Core",
			Vector3.new(1.5, 1.5, 1.5),
			CFrame.new(0, 3.7, 0),
			NEON,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		for _, side in { -1, 1 } do
			local x = side * 1.45
			piece(
				"Rod",
				Vector3.new(0.22, 1.5, 0.22),
				CFrame.new(x, 2.5, 0),
				ROD,
				Enum.Material.Metal
			)
			piece(
				"RodTip",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(x, 3.35, 0),
				NEON,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
		end
	elseif attachment == "drill" then
		-- a big drill cone on the FRONT (-Z, the way it travels): stacked discs that
		-- shrink toward the tip, like the Dev Drill but laid on its side
		local METAL = Color3.fromRGB(170, 180, 195)
		local TIP = Color3.fromRGB(232, 236, 245)
		local dRadii = { 0.7, 0.55, 0.4, 0.25, 0.12 }
		local z = -0.9 -- start just in front of the body
		for i, r in dRadii do
			piece(
				"DrillBit" .. i,
				Vector3.new(0.42, r * 2, r * 2),
				CFrame.new(0, 0.3, z) * CFrame.Angles(0, math.rad(90), 0), -- lay it pointing -Z
				METAL:Lerp(TIP, (i - 1) / #dRadii * 0.6),
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
			z -= 0.42
		end
	elseif attachment == "medic" then
		-- a white medkit with a red cross, on its back
		local WHITE = Color3.fromRGB(245, 245, 250)
		local REDX = Color3.fromRGB(220, 40, 40)
		piece(
			"Medkit",
			Vector3.new(1.3, 1.2, 0.5),
			CFrame.new(0, 0.35, 1.1),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		piece(
			"CrossV",
			Vector3.new(0.28, 0.8, 0.12),
			CFrame.new(0, 0.35, 1.36),
			REDX,
			Enum.Material.SmoothPlastic
		)
		piece(
			"CrossH",
			Vector3.new(0.8, 0.28, 0.12),
			CFrame.new(0, 0.35, 1.36),
			REDX,
			Enum.Material.SmoothPlastic
		)
	elseif attachment == "kitty" then
		-- cat ears (diamond blocks → triangle tips), whiskers, and a curvy tail
		local PINK = Color3.fromRGB(255, 150, 180)
		local DARK = Color3.fromRGB(30, 30, 35)
		for _, side in { -1, 1 } do
			piece(
				"Ear",
				Vector3.new(0.55, 0.55, 0.3),
				CFrame.new(side * 0.62, 1.95, 0) * CFrame.Angles(0, 0, math.rad(45)),
				RED,
				Enum.Material.SmoothPlastic
			)
			piece(
				"EarIn",
				Vector3.new(0.3, 0.3, 0.12),
				CFrame.new(side * 0.62, 1.95, -0.16) * CFrame.Angles(0, 0, math.rad(45)),
				PINK,
				Enum.Material.SmoothPlastic
			)
			for _, wy in { 0.05, -0.1, -0.25 } do -- three whiskers per cheek
				piece(
					"Whisker",
					Vector3.new(0.85, 0.04, 0.04),
					CFrame.new(side * 0.9, wy, -0.78),
					DARK,
					Enum.Material.SmoothPlastic
				)
			end
		end
		piece(
			"Tail1",
			Vector3.new(0.22, 1.1, 0.22),
			CFrame.new(0, 0.3, 1.25) * CFrame.Angles(math.rad(-35), 0, 0),
			RED,
			Enum.Material.SmoothPlastic
		)
		piece(
			"Tail2",
			Vector3.new(0.2, 0.9, 0.2),
			CFrame.new(0, 1.15, 1.6) * CFrame.Angles(math.rad(-70), 0, 0),
			RED,
			Enum.Material.SmoothPlastic
		)
	end

	model.PrimaryPart = body
	-- grow the whole model as one (bosses are big). ScaleTo scales every part around
	-- the pivot, so the proportions stay exactly the same — just bigger.
	if scale then
		model:ScaleTo(scale)
	end
	return model, body
end

-- The classic "Pin" (BFDI-style): red spool body, smug face, a long thin needle on
-- top, and four fire-able limbs — no tank gear. It shoots its own limbs at enemies.
local function buildClassicPin(modelName: string, scale: number?): (Model, BasePart)
	local RED = Color3.fromRGB(235, 40, 45)
	local BLACK = Color3.fromRGB(20, 20, 22)
	local WHITE = Color3.fromRGB(245, 245, 250)
	local STEEL = Color3.fromRGB(190, 198, 210)
	-- rotates a Cylinder part (its round faces point along X) so it stands upright along Y
	local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
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

	-- red spool body: an upright cylinder core with a wide collar disc up top and a wide skirt
	-- disc at the base. The core is a plain Block part wearing a CylinderMesh — the mesh draws
	-- it as a vertical cylinder while the PART stays a box. We can't use a real Cylinder part:
	-- the body is the PrimaryPart and the movement loop re-aims it to face travel, which tips a
	-- Cylinder part onto its side. Block + CylinderMesh keeps the cylinder look AND stays
	-- upright. A touch of Reflectance gives the plastic a glossy candy shine.
	local body = piece(
		"Body",
		Vector3.new(2.3, 3.4, 1.5), -- same footprint as the old box body, rounded into a cylinder
		CFrame.new(0, 0, 0),
		RED,
		Enum.Material.SmoothPlastic
	)
	body.Reflectance = 0.12
	local bodyMesh = Instance.new("CylinderMesh")
	bodyMesh.Parent = body
	local collar = piece(
		"Collar",
		Vector3.new(0.55, 2.9, 2.9),
		CFrame.new(0, 1.45, 0) * UPRIGHT,
		RED,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	collar.Reflectance = 0.12
	local skirt = piece(
		"Skirt",
		Vector3.new(0.8, 3.1, 3.1),
		CFrame.new(0, -1.3, 0) * UPRIGHT,
		RED,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	skirt.Reflectance = 0.12

	-- normal smug face (eyes, one raised brow, a smile) — same as the tank pin
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
	piece(
		"Brow",
		Vector3.new(0.6, 0.14, 0.12),
		CFrame.new(-0.45, 0.86, FZ) * CFrame.Angles(0, 0, math.rad(-18)),
		BLACK,
		Enum.Material.SmoothPlastic
	)
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

	-- a long thin needle on top
	local needle = piece(
		"Needle",
		Vector3.new(0.16, 2.6, 0.16),
		CFrame.new(0, 3.0, 0),
		STEEL,
		Enum.Material.Metal
	)
	needle.Reflectance = 0.25 -- a steel gleam

	-- four FIRE-ABLE limbs (2 arms up top, 2 legs at the base). Named Limb1..4 so they
	-- can be detached one at a time as it shoots them off.
	for _, side in { -1, 1 } do
		piece(
			if side < 0 then "Limb1" else "Limb2",
			Vector3.new(0.26, 1.4, 0.26),
			CFrame.new(side * 1.35, 0.2, -0.1) * CFrame.Angles(0, 0, math.rad(side * 35)),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		piece(
			if side < 0 then "Limb3" else "Limb4",
			Vector3.new(0.26, 1.3, 0.26),
			CFrame.new(side * 0.7, -1.2, -0.1) * CFrame.Angles(0, 0, math.rad(side * 16)),
			WHITE,
			Enum.Material.SmoothPlastic
		)
	end

	model.PrimaryPart = body
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
		stunnedUntil = 0,
		confusedUntil = 0,
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

-- Dev panel: despawn just the active enemies (leave pins/trails alone).
function EnemyService.clearEnemies()
	for _, enemy in active do
		enemy.model:Destroy()
	end
	table.clear(active)
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
	table.clear(trails) -- the trail blobs themselves fade on their own (Debris)
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

-- Stun ONE enemy: it freezes in place (and flashes yellow) for `duration` seconds.
function EnemyService.stunEnemy(enemy: Enemy, duration: number)
	if enemy.dead then
		return
	end
	enemy.stunnedUntil = os.clock() + duration
end

-- Confuse ONE enemy: it walks BACKWARD (toward the spawn) for `duration` seconds.
function EnemyService.confuseEnemy(enemy: Enemy, duration: number)
	if enemy.dead then
		return
	end
	enemy.confusedUntil = os.clock() + duration
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

	-- Roll the variant from one random number. mega/slingshot/storm/classic/trojan can
	-- happen at any level; shooter and rocket only appear once the factory is maxed out.
	--   [0, 0.01)   -> mega      (1%)
	--   [0.01,0.06) -> slingshot (5%)  winds backward, then launches forward for 2x
	--   [0.06,0.10) -> storm     (4%)  chain-lightning zaps a string of enemies
	--   [0.10,0.13) -> classic   (3%)  fires its own limbs, slowing to a stop
	--   [0.13,0.17) -> trojan    (4%)  bursts into a swarm of mini pins on impact
	--   [0.17,0.21) -> floater   (4%)  hovers above the track, explodes on contact
	--   [0.21,0.26) -> medic     (5%)  medkit pin: un-stuns towers it passes (no ram)
	--   [0.26,0.30) -> trail     (4%)  lays a glowing trail: speeds up pins + burns enemies
	--   [0.30,0.34) -> stunner   (4%)  freezes every enemy in the area on impact
	--   [0.34,0.38) -> kitty     (4%)  nine lives: pounces nine enemies before it dies
	--   [0.38,0.42) -> confusion (4%)  turns enemies around to walk the wrong way
	--   [0.42,0.46) -> plain     (4%)  a clean pin with no mech (just body + face + needle)
	--   [0.46,0.56) -> rocket    (10%, max only)  high damage + speed, explodes
	--   [0.56,0.81) -> shooter   (25%, max only)  carries a gun and fires as it advances
	local roll = math.random()
	local mega = roll < 0.01
	local slingshot = not mega and roll < 0.06
	local storm = not mega and not slingshot and roll < 0.10
	local classic = not mega and not slingshot and not storm and roll < 0.13
	local trojan = not mega and not slingshot and not storm and not classic and roll < 0.17
	local floater = not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and roll < 0.21
	local medic = not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and roll < 0.26
	local trail = not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and not medic
		and roll < 0.30
	local stunner = not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and not medic
		and not trail
		and roll < 0.34
	local kitty = not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and not medic
		and not trail
		and not stunner
		and roll < 0.38
	local confusion = not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and not medic
		and not trail
		and not stunner
		and not kitty
		and roll < 0.42
	local plain = not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and not medic
		and not trail
		and not stunner
		and not kitty
		and not confusion
		and roll < 0.46
	local rocket = maxLevel
		and not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and not medic
		and not trail
		and not stunner
		and not kitty
		and not confusion
		and not plain
		and roll < 0.56
	local shooter = maxLevel
		and not mega
		and not slingshot
		and not storm
		and not classic
		and not trojan
		and not floater
		and not medic
		and not trail
		and not stunner
		and not kitty
		and not confusion
		and not plain
		and not rocket
		and roll < 0.81

	-- defaults: a plain random-color pin heading straight for the enemy spawn
	local scale = 0.9
	local color = Color3.fromHSV(math.random(), 0.65, 1)
	local speed = ALLY_SPEED
	local dmg = damage
	local ramR = ALLY_RAM_RADIUS
	local explodeR = 0
	local attach: string? = nil
	local shootRange = 0
	local shootDmg = 0
	local windup = false
	local chainCount = 0
	local limbs = 0
	local maxLimbs = 0
	local spawnOnDeath = 0
	local floatHeight = 0
	local stunDuration = 0
	local stunRadius = 0
	local lives = 0
	local confuseDuration = 0
	local confuseRadius = 0
	local bare = false -- plain pin: built without the mech (tracks/battery/drill spike)
	local startWaypoint = startIdx - 1 -- normal pins head toward the spawn (path[1])

	if mega then
		scale, color, dmg = 2.6, Color3.fromRGB(255, 215, 0), damage * 10
		ramR, explodeR = ALLY_RAM_RADIUS * 2.5, ALLY_RAM_RADIUS * 5
	elseif slingshot then
		color = Color3.fromRGB(150, 80, 230) -- purple
		speed, dmg = ALLY_SPEED * 2.2, damage * 2 -- fast launch, double damage
		ramR = ALLY_RAM_RADIUS * 1.2
		windup = true
		startWaypoint = startIdx + 1 -- roll BACKWARD (toward the base) first
	elseif storm then
		scale = 1.1 -- a bit bigger so it stands out
		color = Color3.fromRGB(80, 220, 255) -- electric cyan
		attach = "storm" -- glowing tesla rig so it's unmistakable
		chainCount = 6 -- lightning leaps to up to 6 enemies on impact
	elseif classic then
		color = Color3.fromRGB(230, 30, 30) -- bright red
		shootRange, shootDmg = 20, damage -- fires its OWN limbs at enemies
		limbs, maxLimbs = 4, 4 -- ...and slows down with each one, until it stops
	elseif trojan then
		scale = 1.2 -- a fat, innocent-looking pin...
		color = Color3.fromRGB(70, 110, 60) -- sneaky army green
		spawnOnDeath = 6 -- ...that bursts into 6 mini pins on impact
	elseif floater then
		scale = 0.55 -- a little floating bomb
		color = Color3.fromRGB(255, 160, 40) -- warning orange
		floatHeight = 1 -- hovers just a little off the track
		explodeR = ALLY_RAM_RADIUS * 1.5 -- explodes the moment it touches an enemy
	elseif medic then
		color = Color3.fromRGB(245, 245, 250) -- white, like an ambulance
		attach = "medic" -- carries a medkit; un-stuns towers as it rolls by
	elseif trail then
		scale = 0.7
		color = TRAIL_COLOR -- glowing cyan comet
		speed = ALLY_SPEED * 1.4 -- zippy, so it lays a long trail
	elseif stunner then
		color = Color3.fromRGB(255, 235, 90) -- electric yellow
		stunDuration = 2 -- freezes enemies for 2s
		stunRadius = ALLY_RAM_RADIUS * 2
	elseif kitty then
		color = Color3.fromRGB(255, 170, 80) -- orange tabby
		attach = "kitty" -- ears, whiskers, a tail
		lives = 9 -- nine lives: pounces nine enemies before it's gone
	elseif confusion then
		color = CONFUSE_COLOR -- swirly purple
		confuseDuration = 3 -- turns enemies around for 3s
		confuseRadius = ALLY_RAM_RADIUS * 2
	elseif plain then
		bare = true -- a clean classic pin, no mech — otherwise a normal rammer
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

	local model: Model
	local primary: BasePart
	if classic then
		model, primary = buildClassicPin("AllyPin", scale)
	else
		model, primary = buildPinEnemy("AllyPin", scale, color, attach, bare)
	end
	local ally: Ally = {
		model = model,
		primary = primary,
		waypointIndex = startWaypoint,
		speed = speed,
		damage = dmg,
		dead = false,
		color = color,
		ramRadius = ramR,
		explodeRadius = explodeR,
		shootRange = shootRange,
		shootDamage = shootDmg,
		shootCooldown = 0,
		windup = windup,
		chainCount = chainCount,
		limbs = limbs,
		maxLimbs = maxLimbs,
		spawnOnDeath = spawnOnDeath,
		floatHeight = floatHeight,
		drillDamage = 0,
		drillCooldown = 0,
		medic = medic,
		trail = trail,
		trailCooldown = 0,
		stunDuration = stunDuration,
		stunRadius = stunRadius,
		lives = lives,
		confuseDuration = confuseDuration,
		confuseRadius = confuseRadius,
	}
	model:PivotTo(CFrame.new(path[startIdx] + Vector3.new(0, primary.Size.Y / 2, 0)))
	model.Parent = container
	table.insert(allies, ally)
end

-- Spawn a green DRILL pin near `position` (the Dev Drill tower spawns one on every
-- kill). It bores THROUGH enemies — damaging everything it touches without being
-- consumed — all the way to the enemy spawn.
function EnemyService.spawnDrillPin(damage: number, position: Vector3)
	local path = Map.getPath()
	if #path < 2 then
		return
	end
	local startIdx = 1
	local bestD = math.huge
	for i, wp in path do
		local d = (wp - position).Magnitude
		if d < bestD then
			bestD = d
			startIdx = i
		end
	end
	local color = Color3.fromRGB(60, 200, 90) -- drill green
	local model, primary = buildPinEnemy("DrillPin", 0.85, color, "drill")
	local ally: Ally = {
		model = model,
		primary = primary,
		waypointIndex = startIdx - 1,
		speed = ALLY_SPEED * 1.3,
		damage = damage,
		dead = false,
		color = color,
		ramRadius = ALLY_RAM_RADIUS,
		explodeRadius = 0,
		shootRange = 0,
		shootDamage = 0,
		shootCooldown = 0,
		windup = false,
		chainCount = 0,
		limbs = 0,
		maxLimbs = 0,
		spawnOnDeath = 0,
		floatHeight = 0,
		drillDamage = damage, -- bores through everything it touches
		drillCooldown = 0,
		medic = false,
		trail = false,
		trailCooldown = 0,
		stunDuration = 0,
		stunRadius = 0,
		lives = 0,
		confuseDuration = 0,
		confuseRadius = 0,
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

-- Detach one limb (a part named "Limb..") from a pin and return where it was, so we
-- can fling it from there. Returns nil if there are no limbs left.
local function detachLimb(model: Model): Vector3?
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Limb" then
			local pos = p.Position
			p:Destroy()
			return pos
		end
	end
	return nil
end

-- Fling a limb (a little white part) from `from` to `to`.
local function throwLimb(from: Vector3, to: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = LIMB_COLOR
	p.Size = Vector3.new(0.3, 1.0, 0.3)
	p.CFrame = CFrame.new(from, to)
	p.Parent = Workspace
	TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(to, to + (to - from)),
	}):Play()
	Debris:AddItem(p, 0.22)
end

-- Spawn a small plain pin near `position` (what a trojan bursts into). No variants —
-- just a fast little random-color rammer, so trojans can't chain-burst forever.
local function spawnMiniPin(damage: number, position: Vector3)
	local path = Map.getPath()
	if #path < 2 then
		return
	end
	local startIdx = 1
	local bestD = math.huge
	for i, wp in path do
		local d = (wp - position).Magnitude
		if d < bestD then
			bestD = d
			startIdx = i
		end
	end
	local color = Color3.fromHSV(math.random(), 0.6, 1)
	local model, primary = buildPinEnemy("MiniPin", 0.5, color)
	local ally: Ally = {
		model = model,
		primary = primary,
		waypointIndex = startIdx - 1,
		speed = ALLY_SPEED * 1.1,
		damage = damage,
		dead = false,
		color = color,
		ramRadius = ALLY_RAM_RADIUS * 0.7,
		explodeRadius = 0,
		shootRange = 0,
		shootDamage = 0,
		shootCooldown = 0,
		windup = false,
		chainCount = 0,
		limbs = 0,
		maxLimbs = 0,
		spawnOnDeath = 0, -- minis never burst (no infinite spawn)
		floatHeight = 0,
		drillDamage = 0,
		drillCooldown = 0,
		medic = false,
		trail = false,
		trailCooldown = 0,
		stunDuration = 0,
		stunRadius = 0,
		lives = 0,
		confuseDuration = 0,
		confuseRadius = 0,
	}
	model:PivotTo(CFrame.new(path[startIdx] + Vector3.new(0, primary.Size.Y / 2, 0)))
	model.Parent = container
	table.insert(allies, ally)
end

-- Drop a glowing trail blob at `position` that fades out over its lifetime.
local function dropTrail(position: Vector3, damage: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = TRAIL_COLOR
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(TRAIL_RADIUS * 1.6, TRAIL_RADIUS * 1.6, TRAIL_RADIUS * 1.6)
	p.Transparency = 0.4
	p.Position = position + Vector3.new(0, 0.5, 0)
	p.Parent = Workspace
	TweenService:Create(
		p,
		TweenInfo.new(2.5, Enum.EasingStyle.Linear),
		{ Transparency = 1, Size = Vector3.new(1, 1, 1) }
	):Play()
	Debris:AddItem(p, 2.5)
	table.insert(trails, {
		position = position,
		expireAt = os.clock() + 2.5,
		damage = damage,
		radius = TRAIL_RADIUS,
		damageCooldown = 0,
	})
end

-- Trails fade out, and while they last they burn enemies standing inside them.
local function stepTrails(dt: number)
	local now = os.clock()
	for i = #trails, 1, -1 do
		local t = trails[i]
		if now >= t.expireAt then
			table.remove(trails, i)
			continue
		end
		t.damageCooldown -= dt
		if t.damageCooldown <= 0 then
			for _, enemy in active do
				if
					not enemy.dead
					and (enemy.primary.Position - t.position).Magnitude <= t.radius
				then
					EnemyService.takeDamage(enemy, t.damage)
				end
			end
			t.damageCooldown = 0.3
		end
	end
end

-- Is `position` inside any active trail blob? (trail pins speed up here)
local function inTrail(position: Vector3): boolean
	for _, t in trails do
		if (position - t.position).Magnitude <= t.radius then
			return true
		end
	end
	return false
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

		-- trail pins drop a glowing blob behind them every so often
		if ally.trail then
			ally.trailCooldown -= dt
			if ally.trailCooldown <= 0 then
				dropTrail(ally.primary.Position, ally.damage)
				ally.trailCooldown = 0.18
			end
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
					local toPos = nearest.primary.Position -- grab before it might die
					EnemyService.takeDamage(nearest, ally.shootDamage)
					if ally.limbs > 0 then
						-- limb-shooter: hurl a limb, lose it, and slow down a notch
						local from = detachLimb(ally.model) or ally.primary.Position
						throwLimb(from, toPos)
						ally.limbs -= 1
						ally.speed = ALLY_SPEED * (ally.limbs / ally.maxLimbs)
						if ally.limbs <= 0 then
							ally.shootRange = 0 -- out of limbs — can't shoot
							ally.speed = 0 -- ...and stopped completely
						end
					else
						beam(ally.primary.Position, toPos, ally.color)
					end
					ally.shootCooldown = 0.6
				else
					ally.shootCooldown = 0.2 -- nothing in range; check again soon
				end
			end
		end

		-- drill pins bore THROUGH enemies: rapidly damage everything they touch and keep
		-- going (they're never "used up" on contact; they run to the spawn and stop there)
		if ally.drillDamage > 0 then
			ally.drillCooldown -= dt
			if ally.drillCooldown <= 0 then
				for _, enemy in active do
					local d = (enemy.primary.Position - ally.primary.Position).Magnitude
					if not enemy.dead and d <= ally.ramRadius then
						EnemyService.takeDamage(enemy, ally.drillDamage)
					end
				end
				ally.drillCooldown = 0.15
			end
		end

		-- kitty pin: NINE LIVES. It pounces an enemy it touches (one life per pounce, on
		-- a cooldown) and only despawns once all nine lives are used up.
		if ally.lives > 0 then
			ally.drillCooldown -= dt -- reused as the pounce timer (kitties don't drill)
			if ally.drillCooldown <= 0 then
				for _, enemy in active do
					local d = (enemy.primary.Position - ally.primary.Position).Magnitude
					if not enemy.dead and d <= ally.ramRadius then
						EnemyService.takeDamage(enemy, ally.damage)
						deathPop(ally.primary.Position, ally.color)
						ally.lives -= 1
						ally.drillCooldown = 0.35
						break
					end
				end
				if ally.lives <= 0 then
					ally.model:Destroy()
					table.remove(allies, i)
					continue
				end
			end
		end

		-- did we bump an enemy? (slingshot pins don't attack while winding; drill/kitty
		-- pins handle their own hits; medics are non-combat support — all skip this)
		local rammed = false
		if
			not ally.windup
			and ally.drillDamage <= 0
			and not ally.medic
			and not ally.trail
			and ally.lives <= 0
		then
			for _, enemy in active do
				local d = (enemy.primary.Position - ally.primary.Position).Magnitude
				if not enemy.dead and d <= ally.ramRadius then
					rammed = true
					break
				end
			end
		end
		if rammed then
			if ally.stunDuration > 0 then
				-- STUNNER: freeze every enemy in the area (and a small hit)
				for _, enemy in active do
					local d = (enemy.primary.Position - ally.primary.Position).Magnitude
					if not enemy.dead and d <= ally.stunRadius then
						EnemyService.stunEnemy(enemy, ally.stunDuration)
						EnemyService.takeDamage(enemy, ally.damage)
					end
				end
				bigBoom(ally.primary.Position, ally.color, ally.stunRadius)
			elseif ally.confuseDuration > 0 then
				-- CONFUSION: turn every enemy in the area around (and a small hit)
				for _, enemy in active do
					local d = (enemy.primary.Position - ally.primary.Position).Magnitude
					if not enemy.dead and d <= ally.confuseRadius then
						EnemyService.confuseEnemy(enemy, ally.confuseDuration)
						EnemyService.takeDamage(enemy, ally.damage)
					end
				end
				bigBoom(ally.primary.Position, ally.color, ally.confuseRadius)
			elseif ally.spawnOnDeath > 0 then
				-- TROJAN: small AoE hit, then BURST into a swarm of mini pins
				for _, enemy in active do
					local d = (enemy.primary.Position - ally.primary.Position).Magnitude
					if not enemy.dead and d <= ally.ramRadius then
						EnemyService.takeDamage(enemy, ally.damage)
					end
				end
				for _ = 1, ally.spawnOnDeath do
					spawnMiniPin(ally.damage, ally.primary.Position)
				end
				bigBoom(ally.primary.Position, ally.color, ALLY_RAM_RADIUS * 1.5)
			elseif ally.chainCount > 0 then
				-- STORM pin: lightning leaps from enemy to nearest enemy, chaining
				local hit: { [Enemy]: boolean } = {}
				local fromPos = ally.primary.Position
				for _ = 1, ally.chainCount do
					local best: Enemy? = nil
					local bestD = 18 -- how far the bolt can jump
					for _, enemy in active do
						if not enemy.dead and not hit[enemy] then
							local d = (enemy.primary.Position - fromPos).Magnitude
							if d <= bestD then
								bestD = d
								best = enemy
							end
						end
					end
					if not best then
						break
					end
					local toPos = best.primary.Position -- grab before it might die
					beam(fromPos, toPos, ally.color)
					EnemyService.takeDamage(best, ally.damage)
					hit[best] = true
					fromPos = toPos
				end
				deathPop(ally.primary.Position, ally.color)
			elseif ally.explodeRadius > 0 then
				-- MEGA / rocket pin: AoE blast hitting every enemy in range
				for _, enemy in active do
					local d = (enemy.primary.Position - ally.primary.Position).Magnitude
					if not enemy.dead and d <= ally.explodeRadius then
						EnemyService.takeDamage(enemy, ally.damage)
					end
				end
				bigBoom(ally.primary.Position, ally.color, ally.explodeRadius)
			else
				-- normal pin: hit the single enemy it touched
				for _, enemy in active do
					local d = (enemy.primary.Position - ally.primary.Position).Magnitude
					if not enemy.dead and d <= ally.ramRadius then
						EnemyService.takeDamage(enemy, ally.damage)
						break
					end
				end
				deathPop(ally.primary.Position, ally.color)
			end
			ally.model:Destroy()
			table.remove(allies, i)
			continue
		end

		local target = path[ally.waypointIndex]
		if not target then
			if ally.windup then
				-- reached the base end → SLINGSHOT: flip around and charge forward
				ally.windup = false
				ally.waypointIndex = #path - 1
				continue
			end
			ally.model:Destroy() -- reached the spawn without a kill — spent
			table.remove(allies, i)
			continue
		end
		local pos = ally.primary.Position - Vector3.new(0, ally.primary.Size.Y / 2, 0)
		local toTarget = target - pos
		local distLeft = toTarget.Magnitude
		-- pins move faster while inside a glowing trail
		local boost = if inTrail(ally.primary.Position) then TRAIL_BOOST else 1
		local stepDist = ally.speed * boost * dt
		local newGround: Vector3
		if stepDist >= distLeft then
			newGround = target
			-- winding up counts UP toward the base; otherwise count down toward the spawn
			ally.waypointIndex += if ally.windup then 1 else -1
		else
			newGround = pos + toTarget.Unit * stepDist
		end
		-- floaters hover at a steady height above the track (no bobbing)
		local newPos = newGround + Vector3.new(0, ally.primary.Size.Y / 2 + ally.floatHeight, 0)
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

		-- Status visual: yellow (stunned), purple (confused), pink (painted), else normal.
		local now = os.clock()
		local stunned = now < enemy.stunnedUntil
		local confused = now < enemy.confusedUntil
		local painted = now < enemy.slowUntil
		local wantColor = if stunned
			then enemy.baseColor:Lerp(STUN_COLOR, 0.7)
			elseif confused then enemy.baseColor:Lerp(CONFUSE_COLOR, 0.7)
			elseif painted then enemy.baseColor:Lerp(PAINT_COLOR, 0.7)
			else enemy.baseColor
		if enemy.primary.Color ~= wantColor then
			enemy.primary.Color = wantColor
		end

		if frozen or stunned then
			continue -- defragged or stunned: hold position
		end

		-- confused enemies walk BACKWARD (toward the spawn) instead of forward
		local targetIdx = if confused then enemy.waypointIndex - 1 else enemy.waypointIndex
		local target = path[targetIdx]
		if not target then
			if confused then
				continue -- backed all the way to the spawn; just wait out the confusion
			end
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
			if confused then
				enemy.waypointIndex = math.max(2, enemy.waypointIndex - 1)
				enemy.distance = math.max(0, enemy.distance - distLeft)
			else
				enemy.waypointIndex += 1
				enemy.distance += distLeft
			end
		else
			newGround = pos + toTarget.Unit * step
			enemy.distance = math.max(0, enemy.distance + (if confused then -step else step))
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
	stepTrails(dt) -- fade trail blobs + burn enemies in them
end

-- For TowerService targeting.
function EnemyService.getActive(): { Enemy }
	return active
end

-- For TowerService (medic pins un-stunning towers).
function EnemyService.getAllies(): { Ally }
	return allies
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
