--!strict
-- Persistent coin total (top-left). Updated by CoinsChanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local CoinHUD = {}

function CoinHUD.init()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "CoinHUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local chip = Instance.new("Frame")
	chip.AnchorPoint = Vector2.new(0, 0)
	chip.Position = UDim2.fromOffset(16, 16)
	chip.Size = UDim2.fromOffset(120, 40)
	chip.BackgroundColor3 = Color3.fromRGB(36, 33, 20)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = chip
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(245, 196, 63)
	stroke.Parent = chip
	chip.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 20
	label.TextColor3 = Color3.fromRGB(245, 210, 90)
	label.Text = "🪙 0"
	label.Parent = chip

	Remotes.event("CoinsChanged").OnClientEvent:Connect(function(coins)
		label.Text = "🪙 " .. tostring(coins)
	end)
end

return CoinHUD
