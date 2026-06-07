--!strict
-- Blocky bottom dialogue box for story beats. Built entirely in client code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage:WaitForChild("Shared").Remotes)
local Dialogue = require(ReplicatedStorage.Shared.Configs.Dialogue)
local SoundController = require(script.Parent.SoundController)

local DialogueController = {}

type Line = { speaker: string, mood: string, text: string }

local CHARS_PER_SECOND = 28

local playing = false
local typing = false
local currentText = ""
local revealRequested = false
local advanceRequested = false
local sequenceToken = 0

local gui: ScreenGui
local blocker: TextButton
local box: Frame
local nameTab: TextLabel
local portrait: Frame
local portraitInitial: TextLabel
local textLabel: TextLabel
local moodStripe: Frame

local MOOD_COLORS: { [string]: Color3 } = {
	Angry = Color3.fromRGB(224, 72, 72),
	Happy = Color3.fromRGB(72, 190, 96),
	Shocked = Color3.fromRGB(242, 205, 72),
	Neutral = Color3.fromRGB(82, 150, 225),
	Serious = Color3.fromRGB(115, 105, 190),
	Excited = Color3.fromRGB(245, 145, 55),
}

local function moodColor(mood: string): Color3
	return MOOD_COLORS[mood] or Color3.fromRGB(82, 150, 225)
end

local function firstInitial(speaker: string): string
	local first = string.sub(speaker, 1, 1)
	return if first == "" then "?" else string.upper(first)
end

local function splitGraphemes(text: string): { string }
	local chars: { string } = {}
	for first, last in utf8.graphemes(text) do
		table.insert(chars, string.sub(text, first, last))
	end
	return chars
end

local function showLine(line: Line, token: number)
	currentText = line.text
	revealRequested = false
	advanceRequested = false
	typing = true

	local color = moodColor(line.mood)
	nameTab.Text = line.speaker
	nameTab.BackgroundColor3 = color
	portrait.BackgroundColor3 = color
	portraitInitial.Text = firstInitial(line.speaker)
	moodStripe.BackgroundColor3 = color
	textLabel.Text = ""

	local chars = splitGraphemes(line.text)
	for i = 1, #chars do
		if token ~= sequenceToken or revealRequested then
			break
		end
		textLabel.Text = table.concat(chars, "", 1, i)
		if i % 2 == 0 then
			SoundController.play("blip")
		end
		task.wait(1 / CHARS_PER_SECOND)
	end

	textLabel.Text = line.text
	typing = false
end

local function requestAdvance()
	if not playing then
		return
	end
	if typing then
		revealRequested = true
		textLabel.Text = currentText
	else
		advanceRequested = true
	end
end

local function playSequence(sequenceKey: string, fireDone: boolean, onDone: (() -> ())?)
	if playing then
		return
	end

	local sequence = Dialogue[sequenceKey] :: { Line }?
	if not sequence or #sequence == 0 then
		return
	end

	playing = true
	sequenceToken += 1
	local token = sequenceToken
	gui.Enabled = true
	blocker.Visible = true
	box.Visible = true

	for _, line in sequence do
		if token ~= sequenceToken then
			break
		end
		showLine(line, token)
		while token == sequenceToken and playing and not advanceRequested do
			task.wait()
		end
		advanceRequested = false
	end

	if token == sequenceToken then
		box.Visible = false
		blocker.Visible = false
		gui.Enabled = false
		playing = false
		typing = false
		revealRequested = false
		if fireDone then
			Remotes.event("DialogueDone"):FireServer()
		end
		if onDone then
			onDone()
		end
	end
end

-- Public: play a sequence locally (NPC chats) without signalling DialogueDone.
-- `onDone` fires when the sequence finishes (used to grant cards, etc.).
function DialogueController.play(sequenceKey: string, onDone: (() -> ())?)
	playSequence(sequenceKey, false, onDone)
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function DialogueController.init()
	local player = Players.LocalPlayer

	gui = Instance.new("ScreenGui")
	gui.Name = "Dialogue"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 80
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	blocker = Instance.new("TextButton")
	blocker.Name = "InputBlocker"
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.Visible = false
	blocker.ZIndex = 1
	blocker.Parent = gui

	box = Instance.new("Frame")
	box.Name = "DialogueBox"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -24)
	box.Size = UDim2.fromOffset(720, 150)
	box.BackgroundColor3 = Color3.fromRGB(250, 250, 245)
	box.Visible = false
	box.ZIndex = 2
	addCorner(box, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = Color3.fromRGB(28, 28, 34)
	stroke.Parent = box
	box.Parent = gui

	nameTab = Instance.new("TextLabel")
	nameTab.Name = "NameTab"
	nameTab.Position = UDim2.fromOffset(22, -28)
	nameTab.Size = UDim2.fromOffset(190, 36)
	nameTab.Font = Enum.Font.GothamBlack
	nameTab.TextSize = 18
	nameTab.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameTab.TextStrokeTransparency = 0.45
	nameTab.ZIndex = 3
	addCorner(nameTab, 8)
	local tabStroke = Instance.new("UIStroke")
	tabStroke.Thickness = 4
	tabStroke.Color = Color3.fromRGB(28, 28, 34)
	tabStroke.Parent = nameTab
	nameTab.Parent = box

	portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.Position = UDim2.fromOffset(24, 24)
	portrait.Size = UDim2.fromOffset(96, 96)
	portrait.ZIndex = 3
	addCorner(portrait, 8)
	local portraitStroke = Instance.new("UIStroke")
	portraitStroke.Thickness = 4
	portraitStroke.Color = Color3.fromRGB(28, 28, 34)
	portraitStroke.Parent = portrait
	portrait.Parent = box

	portraitInitial = Instance.new("TextLabel")
	portraitInitial.Size = UDim2.fromScale(1, 1)
	portraitInitial.BackgroundTransparency = 1
	portraitInitial.Font = Enum.Font.GothamBlack
	portraitInitial.TextSize = 56
	portraitInitial.TextColor3 = Color3.fromRGB(255, 255, 255)
	portraitInitial.TextStrokeTransparency = 0.35
	portraitInitial.ZIndex = 4
	portraitInitial.Parent = portrait

	moodStripe = Instance.new("Frame")
	moodStripe.Name = "MoodStripe"
	moodStripe.Position = UDim2.fromOffset(142, 24)
	moodStripe.Size = UDim2.fromOffset(6, 96)
	moodStripe.BorderSizePixel = 0
	moodStripe.ZIndex = 3
	addCorner(moodStripe, 6)
	moodStripe.Parent = box

	textLabel = Instance.new("TextLabel")
	textLabel.Name = "Line"
	textLabel.Position = UDim2.fromOffset(164, 24)
	textLabel.Size = UDim2.new(1, -190, 1, -44)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 25
	textLabel.TextColor3 = Color3.fromRGB(35, 35, 42)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextWrapped = true
	textLabel.ZIndex = 3
	textLabel.Parent = box

	blocker.Activated:Connect(requestAdvance)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
			requestAdvance()
		end
	end)

	Remotes.event("PlayDialogue").OnClientEvent:Connect(function(sequenceKey)
		playSequence(tostring(sequenceKey), true)
	end)
end

return DialogueController
