--!strict
-- Bottom hotbar: capped at 5 slots across. Press T to page through the rest
-- (slots 1-5, then 6-10...). Slots keep their real number as the label, and the
-- matching number key arms that tower (paging to it first if it's off-screen).
-- Press the slot / its number again, or Esc, to cancel.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Configs.Towers)
local Balance = require(Shared.Configs.Balance)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local Hotbar = {}

local PAGE_SIZE = 5 -- max slots shown across at once; press T for the next page
local SLOT_W, SLOT_H = 108, 96

type Slot = { button: TextButton, towerType: string?, cost: TextLabel, accent: Frame }
local slots: { Slot } = {} -- only the current page's slots are built at a time
local row: Frame
local hint: TextLabel
local currentPage = 0 -- 0-indexed; page 0 = slots 1-5, page 1 = slots 6-10
local unlockedTowers: { string } = table.clone(Balance.StarterTowers)

local KEY_TO_SLOT: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

local function totalSlots(): number
	return Balance.HotbarSlots
end

local function pageCount(): number
	return math.max(1, math.ceil(totalSlots() / PAGE_SIZE))
end

local rebuild: () -> () -- forward declaration (selectAbsolute pages by calling it)

-- arm the tower in absolute slot `n`, paging to it first if it's off the current page
local function selectAbsolute(n: number)
	local towerType = unlockedTowers[n]
	if not towerType then
		return
	end
	local page = math.floor((n - 1) / PAGE_SIZE)
	if page ~= currentPage then
		currentPage = page
		rebuild()
	end
	if ClientState.selectedTower == towerType then
		ClientState.setSelected(nil)
	else
		ClientState.setSelected(towerType)
	end
end

local function buildSlot(parent: Instance, index: number, towerType: string?): Slot
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. index
	button.Size = UDim2.fromOffset(SLOT_W, SLOT_H)
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
			selectAbsolute(index)
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
	if hint then
		if pageCount() > 1 then
			local first = currentPage * PAGE_SIZE + 1
			local last = math.min(first + PAGE_SIZE - 1, totalSlots())
			hint.Text = ("slots %d–%d      T ▸ more"):format(first, last)
			hint.Visible = true
		else
			hint.Visible = false
		end
	end
end

rebuild = function()
	for _, slot in slots do
		slot.button:Destroy()
	end
	table.clear(slots)
	local startIndex = currentPage * PAGE_SIZE
	local pos = 0
	for i = 1, PAGE_SIZE do
		local absolute = startIndex + i
		if absolute <= totalSlots() then
			pos += 1
			slots[pos] = buildSlot(row, absolute, unlockedTowers[absolute])
		end
	end
	refresh()
end

function Hotbar.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -16)
	row.Size = UDim2.fromOffset(SLOT_W * PAGE_SIZE + 10 * (PAGE_SIZE - 1), SLOT_H)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -(16 + SLOT_H + 6))
	hint.Size = UDim2.fromOffset(280, 18)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(150, 156, 170)
	hint.Text = ""
	hint.Visible = false
	hint.Parent = gui

	rebuild()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local slotIndex = KEY_TO_SLOT[input.KeyCode]
		if slotIndex then
			selectAbsolute(slotIndex)
		elseif input.KeyCode == Enum.KeyCode.T then
			currentPage = (currentPage + 1) % pageCount()
			rebuild()
		end
	end)

	Remotes.event("TowerUnlocked").OnClientEvent:Connect(function(towerType)
		local t = tostring(towerType)
		if Towers[t] and not table.find(unlockedTowers, t) then
			table.insert(unlockedTowers, t)
			rebuild()
		end
	end)

	ClientState.onChange(refresh)
	refresh()
end

return Hotbar
