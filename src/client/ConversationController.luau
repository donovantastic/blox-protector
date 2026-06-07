--!strict
-- 2D conversation scene. Talking to an NPC slides in a framed 2D stage with two
-- avatar portraits — the NPC (left) and YOU (right), pulled live from Roblox avatar
-- thumbnails (GetUserThumbnailAsync). The dialogue box (higher DisplayOrder) plays
-- at the bottom over it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ConversationController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local backdrop: Frame
local leftImg: ImageLabel
local leftName: TextLabel
local rightImg: ImageLabel

local BUILDERMAN_USER_ID = 156 -- the real, original Builderman

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

-- a portrait slot: a colored rounded backing + the avatar image + a name label
local function avatarSlot(
	parent: Instance,
	onLeft: boolean,
	backing: Color3
): (ImageLabel, TextLabel)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(0.26, 0.5)
	holder.Position = if onLeft then UDim2.fromScale(0.1, 0.22) else UDim2.fromScale(0.64, 0.22)
	holder.BackgroundColor3 = backing
	holder.BackgroundTransparency = 0.1
	corner(holder, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 22, 30)
	stroke.Parent = holder
	holder.Parent = parent

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = holder

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1.2, 0.16)
	name.Position = UDim2.fromScale(-0.1, -0.2)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0
	name.Parent = holder
	return img, name
end

local function loadAvatar(img: ImageLabel, userId: number)
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.AvatarBust,
				Enum.ThumbnailSize.Size420x420
			)
		end)
		if ok and content then
			img.Image = content
		end
	end)
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
	backdrop.BackgroundColor3 = Color3.fromRGB(58, 70, 128)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(96, 116, 196), Color3.fromRGB(28, 26, 56))
	grad.Rotation = 90
	grad.Parent = backdrop

	leftImg, leftName = avatarSlot(backdrop, true, Color3.fromRGB(240, 200, 70)) -- NPC: yellow backing
	local youImg, youName = avatarSlot(backdrop, false, Color3.fromRGB(70, 130, 220)) -- You: blue backing
	rightImg = youImg
	youName.Text = "You"
end

-- `npcUserId` (optional): the avatar to show for the NPC; defaults to Builderman.
function ConversationController.start(name: string, npcUserId: number?)
	leftName.Text = name
	leftImg.Image = ""
	rightImg.Image = ""
	loadAvatar(leftImg, npcUserId or BUILDERMAN_USER_ID)
	loadAvatar(rightImg, player.UserId)

	gui.Enabled = true
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
end

function ConversationController.stop()
	gui.Enabled = false
end

return ConversationController
