--!strict
-- Your card hand (gauntlet only). Cards sit bottom-right; click one to play it —
-- the server auto-targets the boss / strongest enemy. Cards disappear as they're
-- spent (HandChanged from the server is the source of truth).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Configs.Cards)
local Remotes = require(Shared.Remotes)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer
local playCard = Remotes.event("PlayCard")

local HandController = {}

local gui: ScreenGui
local row: Frame
local mode = "Explore"
local hand: { string } = {}

local function buildCard(cardId: string, order: number)
	local card = Cards[cardId]
	if not card then
		return
	end

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(116, 158)
	btn.BackgroundColor3 = Color3.fromRGB(248, 248, 244)
	btn.AutoButtonColor = true
	btn.Text = ""
	btn.LayoutOrder = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(245, 196, 63)
	stroke.Parent = btn

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -10, 0, 34)
	name.Position = UDim2.fromOffset(5, 8)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 15
	name.TextWrapped = true
	name.TextColor3 = Color3.fromRGB(30, 32, 40)
	name.Text = card.name
	name.Parent = btn

	local art = Instance.new("Frame")
	art.Size = UDim2.fromOffset(96, 60)
	art.Position = UDim2.fromOffset(10, 46)
	art.BackgroundColor3 = Color3.fromRGB(40, 46, 74)
	art.BorderSizePixel = 0
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 6)
	ac.Parent = art
	art.Parent = btn

	local play = Instance.new("TextLabel")
	play.Size = UDim2.new(1, -10, 0, 40)
	play.Position = UDim2.fromOffset(5, 112)
	play.BackgroundTransparency = 1
	play.Font = Enum.Font.GothamBold
	play.TextSize = 13
	play.TextColor3 = Color3.fromRGB(150, 120, 30)
	play.Text = "CLICK TO PLAY"
	play.Parent = btn

	btn.Activated:Connect(function()
		playCard:FireServer(cardId)
		SoundController.play("cardPlay")
	end)
	btn.Parent = row
end

local function render()
	for _, child in row:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, cardId in hand do
		buildCard(cardId, i)
	end
	gui.Enabled = (mode == "Gauntlet" and #hand > 0)
end

function HandController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hand"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.new(1, -16, 1, -16)
	row.Size = UDim2.fromOffset(380, 158)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	Remotes.event("HandChanged").OnClientEvent:Connect(function(newHand)
		hand = if typeof(newHand) == "table" then newHand else {}
		render()
	end)
	Remotes.event("ModeChanged").OnClientEvent:Connect(function(newMode)
		mode = tostring(newMode)
		render()
	end)
end

return HandController
