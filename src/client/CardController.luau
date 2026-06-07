--!strict
-- Retro story cards for title beats and the demo end screen.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage:WaitForChild("Shared").Remotes)

local CardController = {}

type CardData = {
	title: string?,
	subtitle: string?,
	framing: string?,
	teaser: string?,
	thanks: string?,
}

local gui: ScreenGui
local overlay: Frame
local accent: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local smallLabel: TextLabel
local currentToken = 0

local FADE = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function tweenAlpha(alpha: number)
	TweenService:Create(overlay, FADE, { BackgroundTransparency = alpha }):Play()
	TweenService:Create(accent, FADE, { BackgroundTransparency = alpha }):Play()
	TweenService:Create(
		titleLabel,
		FADE,
		{ TextTransparency = alpha, TextStrokeTransparency = math.clamp(alpha + 0.2, 0, 1) }
	):Play()
	TweenService:Create(
		subtitleLabel,
		FADE,
		{ TextTransparency = alpha, TextStrokeTransparency = math.clamp(alpha + 0.35, 0, 1) }
	):Play()
	TweenService:Create(smallLabel, FADE, { TextTransparency = alpha }):Play()
end

local function configure(kind: string, data: CardData)
	titleLabel.Text = data.title or "BLOX PROTECTOR"
	if kind == "end" then
		subtitleLabel.Text = data.teaser or ""
		smallLabel.Text = data.thanks or ""
		accent.BackgroundColor3 = Color3.fromRGB(88, 210, 120)
	else
		subtitleLabel.Text = data.subtitle or data.framing or ""
		smallLabel.Text = ""
		accent.BackgroundColor3 = Color3.fromRGB(245, 196, 63)
	end
end

local function showCard(kind: string, rawData: any)
	if kind ~= "title" and kind ~= "end" then
		return
	end

	currentToken += 1
	local token = currentToken
	local data = (if typeof(rawData) == "table" then rawData else {}) :: CardData

	configure(kind, data)
	gui.Enabled = true
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	accent.BackgroundTransparency = 1
	titleLabel.TextTransparency = 1
	titleLabel.TextStrokeTransparency = 1
	subtitleLabel.TextTransparency = 1
	subtitleLabel.TextStrokeTransparency = 1
	smallLabel.TextTransparency = 1

	tweenAlpha(0)

	if kind == "title" then
		task.delay(2.95, function()
			if token ~= currentToken then
				return
			end
			tweenAlpha(1)
			task.delay(0.5, function()
				if token == currentToken then
					overlay.Visible = false
					gui.Enabled = false
				end
			end)
		end)
	end
end

function CardController.init()
	local player = Players.LocalPlayer

	gui = Instance.new("ScreenGui")
	gui.Name = "StoryCards"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 70
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 9, 13)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = gui

	local stack = Instance.new("Frame")
	stack.AnchorPoint = Vector2.new(0.5, 0.5)
	stack.Position = UDim2.fromScale(0.5, 0.47)
	stack.Size = UDim2.fromOffset(760, 260)
	stack.BackgroundTransparency = 1
	stack.Parent = overlay

	accent = Instance.new("Frame")
	accent.AnchorPoint = Vector2.new(0.5, 0)
	accent.Position = UDim2.fromScale(0.5, 0)
	accent.Size = UDim2.fromOffset(460, 8)
	accent.BorderSizePixel = 0
	addCorner(accent, 8)
	accent.Parent = stack

	titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromOffset(0, 28)
	titleLabel.Size = UDim2.new(1, 0, 0, 112)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 64
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.TextStrokeTransparency = 1
	titleLabel.TextWrapped = true
	titleLabel.Parent = stack

	subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Position = UDim2.fromOffset(30, 146)
	subtitleLabel.Size = UDim2.new(1, -60, 0, 62)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.TextSize = 28
	subtitleLabel.TextColor3 = Color3.fromRGB(245, 196, 63)
	subtitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subtitleLabel.TextStrokeTransparency = 1
	subtitleLabel.TextWrapped = true
	subtitleLabel.Parent = stack

	smallLabel = Instance.new("TextLabel")
	smallLabel.Position = UDim2.fromOffset(70, 212)
	smallLabel.Size = UDim2.new(1, -140, 0, 34)
	smallLabel.BackgroundTransparency = 1
	smallLabel.Font = Enum.Font.GothamBold
	smallLabel.TextSize = 18
	smallLabel.TextColor3 = Color3.fromRGB(180, 186, 205)
	smallLabel.TextWrapped = true
	smallLabel.Parent = stack

	Remotes.event("ShowCard").OnClientEvent:Connect(function(kind, data)
		showCard(tostring(kind), data)
	end)
end

return CardController
