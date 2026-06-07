--!strict
-- Owns the current game mode + camera style (server-authoritative) and broadcasts
-- changes. A "chapter" flows Explore -> Gauntlet -> Explore -> Gauntlet -> Complete.
-- style: "sidescroll" (Act 1 lane) | "freewalk" (Act 2 roam). Clients react via
-- ModeChanged(mode, style): camera, controls, HUD visibility.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local ModeService = {}

export type Mode = string -- "Explore" | "Gauntlet" | "ChapterComplete"

local current: Mode = "Explore"
local currentStyle = "sidescroll"
local modeChanged = Remotes.event("ModeChanged")

-- set by init.server to run side effects on transitions (start the gauntlet, etc.)
ModeService.onChange = function(_mode: Mode) end :: (Mode) -> ()

function ModeService.get(): Mode
	return current
end

function ModeService.getStyle(): string
	return currentStyle
end

function ModeService.set(mode: Mode, style: string?)
	local newStyle = style or currentStyle
	local modeMoved = mode ~= current
	if not modeMoved and newStyle == currentStyle then
		return
	end
	current = mode
	currentStyle = newStyle
	modeChanged:FireAllClients(current, currentStyle)
	if modeMoved then
		ModeService.onChange(mode)
	end
end

function ModeService.broadcast()
	modeChanged:FireAllClients(current, currentStyle)
end

return ModeService
