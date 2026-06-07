--!strict
-- Pure-2D silhouette conversation scene (Block Tales-ish). Talking to an NPC slides
-- in a near-full-screen 2D framing: a moody backdrop + two silhouette figures (NPC
-- left, you right). The dialogue box (higher DisplayOrder) plays at the bottom over
-- it. Graybox silhouettes — Xander's art / real portraits drop in later.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ConversationController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local backdrop: Frame
local npcNameLabel: TextLabel

local SILHOUETTE = Color3.fromRGB(8, 8, 14) -- near-black figures, read against the bright backlit backdrop

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

-- a simple blocky humanoid silhouette (head + body) with a name under it
local function silhouette(parent: Instance, onLeft: boolean): TextLabel
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(0.3, 0.66)
	holder.Position = if onLeft then UDim2.fromScale(0.08, 0.24) else UDim2.fromScale(0.62, 0.24)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local body = Instance.new("Frame")
	body.Size = UDim2.fromScale(0.62, 0.6)
	body.Position = UDim2.fromScale(0.19, 0.4)
	body.BackgroundColor3 = SILHOUETTE
	body.BorderSizePixel = 0
	corner(body, 20)
	body.Parent = holder

	local head = Instance.new("Frame")
	head.Size = UDim2.fromScale(0.42, 0.32)
	head.Position = UDim2.fromScale(0.29, 0.08)
	head.BackgroundColor3 = SILHOUETTE
	head.BorderSizePixel = 0
	corner(head, 16)
	head.Parent = holder

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1.2, 0.08)
	name.Position = UDim2.fromScale(-0.1, -0.12) -- above the figure (clear of the bottom box)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0 -- solid dark outline so it reads on the bright backdrop
	name.Parent = holder
	return name
end

function ConversationController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Conversation"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(96, 116, 210)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local grad = Instance.new("UIGradient")
	-- bright at top -> medium at bottom: a backlit "sky" so the dark figures pop
	grad.Color = ColorSequence.new(Color3.fromRGB(154, 178, 255), Color3.fromRGB(72, 60, 124))
	grad.Rotation = 90
	grad.Parent = backdrop

	npcNameLabel = silhouette(backdrop, true)
	local youName = silhouette(backdrop, false)
	youName.Text = "You"
end

function ConversationController.start(name: string)
	npcNameLabel.Text = name
	gui.Enabled = true
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
end

function ConversationController.stop()
	gui.Enabled = false
end

return ConversationController
