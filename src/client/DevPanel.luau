--!strict
-- Dev/admin panel (testing tool). A "🛠 DEV" button (top-left) and the backtick key
-- (`) both toggle a panel of cheat buttons. Each button fires DevCommand to the
-- server, which does the real work (server-authoritative, like everything else).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local devCommand = Remotes.event("DevCommand")

local player = Players.LocalPlayer

local DevPanel = {}

-- each button: a label + the action (and optional value) sent to the server
local BUTTONS: { { label: string, action: string, value: number? } } = {
	{ label = "💰  +$1,000", action = "money", value = 1000 },
	{ label = "💰  +$10,000", action = "money", value = 10000 },
	{ label = "🗼  Unlock All Towers", action = "unlockAll" },
	{ label = "⏭  Skip Wave", action = "skipWave" },
	{ label = "❤  Heal Base", action = "healBase" },
	{ label = "💀  Clear Enemies", action = "clearEnemies" },
	{ label = "🏆  Win Round", action = "win" },
}

function DevPanel.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = player:WaitForChild("PlayerGui")

	-- always-visible toggle button (top-left)
	local toggle = Instance.new("TextButton")
	toggle.Position = UDim2.fromOffset(16, 64) -- below the coin chip (16,16 + 40 tall), no overlap
	toggle.Size = UDim2.fromOffset(78, 30)
	toggle.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	toggle.BackgroundTransparency = 0.15
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 14
	toggle.TextColor3 = Color3.fromRGB(120, 210, 255)
	toggle.Text = "🛠 DEV"
	toggle.Parent = gui
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 8)
	tc.Parent = toggle

	-- the panel itself (hidden until toggled)
	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.Position = UDim2.fromOffset(16, 102) -- opens just under the DEV toggle
	panel.Size = UDim2.fromOffset(230, #BUTTONS * 46 + 50)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 10)
	pc.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 200, 255)
	stroke.Thickness = 2
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(120, 210, 255)
	title.Text = "DEV PANEL  ( ` to toggle )"
	title.Parent = panel

	local list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(10, 40)
	list.Size = UDim2.new(1, -20, 1, -48)
	list.BackgroundTransparency = 1
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	for _, b in BUTTONS do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 40)
		btn.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
		btn.AutoButtonColor = true
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 15
		btn.TextColor3 = Color3.fromRGB(240, 244, 255)
		btn.Text = b.label
		btn.TextXAlignment = Enum.TextXAlignment.Left
		local bp = Instance.new("UIPadding")
		bp.PaddingLeft = UDim.new(0, 12)
		bp.Parent = btn
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = btn
		btn.Parent = list
		btn.Activated:Connect(function()
			devCommand:FireServer(b.action, b.value)
		end)
	end

	local function setOpen(open: boolean)
		panel.Visible = open
	end

	toggle.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backquote then
			setOpen(not panel.Visible)
		end
	end)
end

return DevPanel
