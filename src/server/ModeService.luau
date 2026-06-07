--!strict
-- Owns the current game mode (server-authoritative) and broadcasts changes. A
-- "chapter" flows Explore -> Gauntlet -> ChapterComplete. The client reacts to
-- ModeChanged (camera, controls, HUD visibility).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local ModeService = {}

export type Mode = string -- "Explore" | "Gauntlet" | "ChapterComplete"

local current: Mode = "Explore"
local modeChanged = Remotes.event("ModeChanged")

-- set by init.server to run side effects on transitions (start the gauntlet, etc.)
ModeService.onChange = function(_mode: Mode) end :: (Mode) -> ()

function ModeService.get(): Mode
	return current
end

function ModeService.set(mode: Mode)
	if mode == current then
		return
	end
	current = mode
	modeChanged:FireAllClients(mode)
	ModeService.onChange(mode)
end

-- re-send to a client that just asked (RequestState path)
function ModeService.broadcast()
	modeChanged:FireAllClients(current)
end

return ModeService
