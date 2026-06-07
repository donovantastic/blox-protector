--!strict
-- Central remote registry. The server creates the RemoteEvents on first require;
-- the client waits for them. Add a remote = add its name to EVENTS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	-- server -> client
	"StateChanged", -- {wave, baseHP, maxBaseHP, cash, status}
	"Notify", -- (message: string) small toast
	"PlayDialogue", -- (sequenceKey: string) play a Dialogue[key] sequence
	"ShowCard", -- (kind: string, data: table) title / end card
	"ModeChanged", -- (mode: string) "Explore" | "Gauntlet" | "ChapterComplete"
	-- client -> server
	"PlaceTower",
	"UpgradeTower",
	"SellTower",
	"DialogueDone", -- () client finished the intro sequence; server may start waves
	"RequestState", -- () client HUD is ready; server replies with a state snapshot
	"GrantCard", -- (cardId: string) client claims a card an NPC handed over
	"PlayCard", -- (cardId: string) play a card; server auto-targets (boss / strongest)
	"HandChanged", -- (hand: {string}) server -> client: current hand of card ids
	"GrantCoins", -- (amount: number) client claims coins from an NPC
	"BuyTower", -- (towerType: string) client buys a tower at the Merchant
	"CoinsChanged", -- (coins: number) server -> client: current coin total
	"TowerUnlocked", -- (towerType: string) server -> client: tower now placeable
	"GatePoweredOn", -- (position: Vector3) server -> client: cut the camera to this gate
}

local Remotes = {}
local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
