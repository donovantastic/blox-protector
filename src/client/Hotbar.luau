--!strict
-- Bottom hotbar: 5 slots, the 3 starter towers in the first slots (rest locked).
-- Click a slot or press 1-5 to arm a tower for placement; press again / Esc to cancel.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Configs.Towers)
local Balance = require(Shared.Configs.Balance)
local ClientState = require(script.Parent.ClientState)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer

local Hotbar = {}

type Slot = { button: TextButton, towerType: string?, cost: TextLabel, accent: Frame }
local slots: { Slot } = {}

local KEY_TO_SLOT: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

local function selectSlot(index: number)
	local slot = slots[index]
	if not slot or not slot.towerType then
		return
	end
	if ClientState.selectedTower == slot.towerType then
		ClientState.setSelected(nil)
	else
		ClientState.setSelected(slot.towerType)
	end
	SoundController.play("uiClick")
end

local function buildSlot(parent: Instance, index: number, towerType: string?): Slot
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. index
	button.Size = UDim2.fromOffset(108, 96)
	button.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
	button.AutoButtonColor = false
	button.Text = ""
	button.LayoutOrder = index
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 4)
	accent.Position = UDim2.fromScale(0, 0)
	accent.BackgroundColor3 = Color3.fromRGB(90, 170, 250)
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.Parent = button

	local key = Instance.new("TextLabel")
	key.Size = UDim2.fromOffset(20, 20)
	key.Position = UDim2.fromOffset(6, 6)
	key.BackgroundTransparency = 1
	key.Font = Enum.Font.GothamBold
	key.TextSize = 14
	key.TextColor3 = Color3.fromRGB(150, 156, 170)
	key.Text = tostring(index)
	key.Parent = button

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -10, 0, 26)
	name.Position = UDim2.fromOffset(5, 30)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextColor3 = Color3.fromRGB(235, 238, 245)
	name.Parent = button

	local cost = Instance.new("TextLabel")
	cost.Size = UDim2.new(1, -10, 0, 22)
	cost.Position = UDim2.fromOffset(5, 62)
	cost.BackgroundTransparency = 1
	cost.Font = Enum.Font.GothamBold
	cost.TextSize = 14
	cost.Parent = button

	if towerType then
		local def = Towers[towerType]
		name.Text = def.name
		cost.Text = "$" .. def.cost
		cost.TextColor3 = Color3.fromRGB(120, 220, 120)
		button.Activated:Connect(function()
			selectSlot(index)
		end)
	else
		name.Text = "Locked"
		name.TextColor3 = Color3.fromRGB(110, 114, 128)
		cost.Text = "—"
		cost.TextColor3 = Color3.fromRGB(90, 94, 108)
		button.BackgroundColor3 = Color3.fromRGB(20, 21, 27)
	end

	button.Parent = parent
	return { button = button, towerType = towerType, cost = cost, accent = accent }
end

local function refresh()
	for _, slot in slots do
		local selected = slot.towerType ~= nil and ClientState.selectedTower == slot.towerType
		slot.accent.BackgroundTransparency = if selected then 0 else 1
		slot.button.BackgroundColor3 = if selected
			then Color3.fromRGB(40, 46, 60)
			else (if slot.towerType
				then Color3.fromRGB(26, 28, 36)
				else Color3.fromRGB(20, 21, 27))
		if slot.towerType then
			local def = Towers[slot.towerType]
			local afford = ClientState.cash >= def.cost
			slot.cost.TextColor3 = if afford
				then Color3.fromRGB(120, 220, 120)
				else Color3.fromRGB(230, 110, 110)
		end
	end
end

function Hotbar.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -16)
	row.Size = UDim2.fromOffset(108 * Balance.HotbarSlots + 10 * (Balance.HotbarSlots - 1), 96)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	for i = 1, Balance.HotbarSlots do
		slots[i] = buildSlot(row, i, Balance.StarterTowers[i])
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local slotIndex = KEY_TO_SLOT[input.KeyCode]
		if slotIndex then
			selectSlot(slotIndex)
		end
	end)

	ClientState.onChange(refresh)
	refresh()
end

return Hotbar
