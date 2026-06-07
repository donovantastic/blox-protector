--!strict
-- Minimal HUD, built in code so there's nothing to wire in Studio yet: Cash,
-- Wave, Base HP across the top + a center GAME OVER / VICTORY overlay. Restyle
-- (or replace with a real ScreenGui) whenever you want — it only reads StateChanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local ClientState = require(script.Parent.ClientState)

local UIController = {}

local function chip(parent: Instance, order: number, color: Color3): TextLabel
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(190, 48)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	frame.BackgroundTransparency = 0.1
	frame.LayoutOrder = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 4, 1, -12)
	stripe.Position = UDim2.fromOffset(8, 6)
	stripe.BackgroundColor3 = color
	stripe.BorderSizePixel = 0
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = stripe
	stripe.Parent = frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.fromOffset(20, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(235, 238, 245)
	label.Text = "—"
	label.Parent = frame
	frame.Parent = parent
	return label
end

function UIController.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local top = Instance.new("Frame")
	top.Size = UDim2.new(1, 0, 0, 70)
	top.BackgroundTransparency = 1
	top.Parent = gui
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.fromOffset(600, 48)
	row.BackgroundTransparency = 1
	row.Parent = top
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = row

	local cash = chip(row, 1, Color3.fromRGB(120, 220, 120))
	local wave = chip(row, 2, Color3.fromRGB(120, 180, 240))
	local hp = chip(row, 3, Color3.fromRGB(240, 110, 110))

	local status = Instance.new("TextLabel")
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.42)
	status.Size = UDim2.fromOffset(520, 90)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBlack
	status.TextSize = 56
	status.TextStrokeTransparency = 0.4
	status.Visible = false
	status.Parent = gui

	Remotes.event("StateChanged").OnClientEvent:Connect(function(state)
		ClientState.setCash(state.cash)
		cash.Text = "$ " .. state.cash
		wave.Text = "Wave " .. state.wave
		hp.Text = "Base " .. state.baseHP .. " / " .. state.maxBaseHP
		if state.status == "lost" then
			status.Text = "GAME OVER"
			status.TextColor3 = Color3.fromRGB(240, 90, 90)
			status.Visible = true
		elseif state.status == "won" then
			status.Text = "VICTORY"
			status.TextColor3 = Color3.fromRGB(120, 230, 130)
			status.Visible = true
		else
			status.Visible = false
		end
	end)

	-- transient toast for server rejections (e.g. "Too close to the path")
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -124)
	toast.Size = UDim2.fromOffset(360, 36)
	toast.BackgroundColor3 = Color3.fromRGB(44, 26, 26)
	toast.BackgroundTransparency = 1
	toast.TextColor3 = Color3.fromRGB(240, 150, 150)
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 16
	toast.Visible = false
	local tcorner = Instance.new("UICorner")
	tcorner.CornerRadius = UDim.new(0, 8)
	tcorner.Parent = toast
	toast.Parent = gui

	local toastToken = 0
	Remotes.event("Notify").OnClientEvent:Connect(function(message)
		toast.Text = tostring(message)
		toast.Visible = true
		toast.BackgroundTransparency = 0.15
		toastToken += 1
		local myToken = toastToken
		task.delay(1.6, function()
			if myToken == toastToken then
				toast.Visible = false
			end
		end)
	end)

	-- HUD ready -> ask the server for current state (robust vs join/load timing)
	Remotes.event("RequestState"):FireServer()
end

return UIController
