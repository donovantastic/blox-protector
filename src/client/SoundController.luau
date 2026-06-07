--!strict
-- Client-only sound playback. Sound ids are placeholders until configured.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sounds = require(game.ReplicatedStorage:WaitForChild("Shared").Configs.Sounds)

local SoundController = {}

local FOLDER_NAME = "BloxProtectorSounds"
local PLACEHOLDER_ID = "rbxassetid://0"

local folder: Folder?
local templates: { [string]: Sound } = {}
local failed: { [string]: boolean } = {}
local initialized = false

local function isPlayableId(soundId: string): boolean
	return soundId ~= "" and soundId ~= PLACEHOLDER_ID
end

local function getFolder(): Folder
	local existing = SoundService:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = SoundService
	return created
end

function SoundController.init()
	if initialized then
		return
	end
	initialized = true
	folder = getFolder()

	local preloadList: { Instance } = {}
	for name, config in Sounds do
		if isPlayableId(config.id) then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = config.id
			sound.Volume = config.volume
			sound.Parent = folder
			templates[name] = sound
			table.insert(preloadList, sound)
		end
	end

	if #preloadList > 0 then
		local ok = pcall(function()
			ContentProvider:PreloadAsync(preloadList)
		end)
		if not ok then
			for _, sound in preloadList do
				failed[sound.Name] = true
			end
		end
	end
end

function SoundController.play(name: string)
	if not initialized then
		SoundController.init()
	end

	if failed[name] then
		return
	end

	local template = templates[name]
	if not template or not isPlayableId(template.SoundId) then
		return
	end

	local playbackFolder = folder
	if not playbackFolder then
		return
	end

	local sound = template:Clone()
	sound.Parent = playbackFolder
	local ok = pcall(function()
		sound:Play()
	end)
	if not ok then
		failed[name] = true
		sound:Destroy()
		return
	end

	Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 0.25)
end

return SoundController
