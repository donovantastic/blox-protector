--!strict
-- Click a placed tower (when not arming a hotbar tower) to select it: shows a range
-- ring + a panel with its stats and Upgrade / Sell. Server is authoritative on both.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Configs.Towers)
local Balance = require(Shared.Configs.Balance)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local upgradeRemote = Remotes.event("UpgradeTower")
local sellRemote = Remotes.event("SellTower")

local TowerPanel = {}

local selected: Model? = nil
local panel: Frame
local nameLabel: TextLabel
local statsLabel: TextLabel
local upgradeBtn: TextButton
local sellBtn: TextButton
local ring: BasePart
local conn: RBXScriptConnection? = nil

local function towerUnderMouse(): Model?
	local tf = Workspace:FindFirstChild("Towers")
	if not tf then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { tf }
	local ray = mouse.UnitRay
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("TowerId") then
			return model
		end
	end
	return nil
end

local function refresh()
	local model = selected
	if not model or not model.Parent then
		panel.Visible = false
		ring.Transparency = 1
		return
	end
	local towerType = model:GetAttribute("TowerType") :: string
	local def = Towers[towerType]
	local levelNum = (model:GetAttribute("Level") :: number?) or 1
	local lv = def.levels[levelNum]
	local spent = (model:GetAttribute("Spent") :: number?) or def.cost

	nameLabel.Text = def.name .. "  ·  Lv " .. levelNum
	statsLabel.Text = ("Range %d   Damage %d   Rate %.1f/s"):format(
		lv.range,
		lv.damage,
		def.fireRate
	)

	local nextLv = def.levels[levelNum + 1]
	if nextLv then
		upgradeBtn.Text = "Upgrade  →  $" .. nextLv.cost
		upgradeBtn.AutoButtonColor = true
		upgradeBtn.BackgroundColor3 = if ClientState.cash >= nextLv.cost
			then Color3.fromRGB(40, 90, 60)
			else Color3.fromRGB(48, 50, 60)
	else
		upgradeBtn.Text = "MAX LEVEL"
		upgradeBtn.AutoButtonColor = false
		upgradeBtn.BackgroundColor3 = Color3.fromRGB(40, 42, 52)
	end
	sellBtn.Text = "Sell  +$" .. math.floor(spent * Balance.SellRefund)

	-- range ring
	local pos = model:GetPivot().Position
	ring.Transparency = 0.75
	ring.Size = Vector3.new(0.2, lv.range * 2, lv.range * 2)
	ring.CFrame = CFrame.new(Vector3.new(pos.X, pos.Y - 1.5, pos.Z))
		* CFrame.Angles(0, 0, math.rad(90))
	panel.Visible = true
end

local function selectTower(model: Model?)
	if conn then
		conn:Disconnect()
		conn = nil
	end
	selected = model
	if model then
		conn = model.AttributeChanged:Connect(refresh)
		-- also drop selection if the model is removed (sold)
		model.AncestryChanged:Connect(function()
			if not model.Parent and selected == model then
				selectTower(nil)
			end
		end)
	end
	refresh()
end

local function styleButton(parent: Instance, y: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -20, 0, 40)
	b.Position = UDim2.fromOffset(10, y)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(235, 238, 245)
	b.AutoButtonColor = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	b.Parent = parent
	return b
end

function TowerPanel.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TowerPanel"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(240, 200)
	panel.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	panel.Parent = gui

	nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -20, 0, 28)
	nameLabel.Position = UDim2.fromOffset(10, 12)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(235, 238, 245)
	nameLabel.Parent = panel

	statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, -20, 0, 24)
	statsLabel.Position = UDim2.fromOffset(10, 44)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 13
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextColor3 = Color3.fromRGB(165, 172, 188)
	statsLabel.Parent = panel

	upgradeBtn = styleButton(panel, 86, Color3.fromRGB(40, 90, 60))
	sellBtn = styleButton(panel, 134, Color3.fromRGB(90, 50, 50))

	ring = Instance.new("Part")
	ring.Name = "TowerRangeRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Transparency = 1
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 200, 255)
	ring.Shape = Enum.PartType.Cylinder
	ring.Parent = Workspace

	upgradeBtn.Activated:Connect(function()
		if selected then
			upgradeRemote:FireServer(selected:GetAttribute("TowerId"))
		end
	end)
	sellBtn.Activated:Connect(function()
		if selected then
			sellRemote:FireServer(selected:GetAttribute("TowerId"))
			selectTower(nil)
		end
	end)

	-- click to select a placed tower (only when not arming a hotbar tower)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if ClientState.selectedTower then
			return -- placement mode owns the click
		end
		selectTower(towerUnderMouse())
	end)

	ClientState.onChange(refresh)
end

return TowerPanel
