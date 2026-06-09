--!strict
-- Tiny shared client state so the Hotbar, PlacementController, and HUD stay in
-- sync (current cash + which tower is selected for placement).

local ClientState = {}

ClientState.cash = 0
ClientState.selectedTower = nil :: string?
ClientState.skipCutscenes = false -- dev toggle: skip the gate power-on cinematic

local listeners: { () -> () } = {}

function ClientState.onChange(fn: () -> ())
	table.insert(listeners, fn)
end

local function fire()
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function ClientState.setCash(n: number)
	if n ~= ClientState.cash then
		ClientState.cash = n
		fire()
	end
end

function ClientState.setSelected(towerType: string?)
	if towerType ~= ClientState.selectedTower then
		ClientState.selectedTower = towerType
		fire()
	end
end

return ClientState
