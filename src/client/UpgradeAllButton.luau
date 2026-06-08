--!strict
-- A single always-on HUD button that upgrades EVERY placed tower one level at
-- once, paying the normal total cost. The label shows the live total so you know
-- the price before you click. The server is authoritative — it re-checks cash and
-- only charges for the towers it can actually upgrade (TowerService.upgradeAll).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Configs.Towers)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local upgradeAllRemote = Remotes.event("UpgradeAllTowers")

local UpgradeAllButton = {}

local btn: TextButton

-- Add up what one round of "upgrade everything" would cost right now: for each
-- placed tower that isn't max level, the price of its next level.
local function totalCost(): (number, number)
	local cost, count = 0, 0
	local tf = Workspace:FindFirstChild("Towers")
	if not tf then
		return 0, 0
	end
	for _, model in tf:GetChildren() do
		if not model:GetAttribute("TowerId") then
			continue
		end
		local towerType = model:GetAttribute("TowerType") :: string?
		local def = towerType and Towers[towerType]
		if not def then
			continue
		end
		local levelNum = (model:GetAttribute("Level") :: number?) or 1
		local nextLv = def.levels[levelNum + 1]
		if nextLv then
			cost += nextLv.cost
			count += 1
		end
	end
	return cost, count
end

local function refresh()
	local cost, count = totalCost()
	if count == 0 then
		btn.Text = "Upgrade All  (no towers)"
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.fromRGB(40, 42, 52)
		return
	end
	btn.Text = ("⬆ Upgrade All  →  $%d"):format(cost)
	btn.AutoButtonColor = true
	-- green if you can afford the whole lot, dim if you can only afford some
	btn.BackgroundColor3 = if ClientState.cash >= cost
		then Color3.fromRGB(40, 90, 60)
		else Color3.fromRGB(70, 64, 40)
end

function UpgradeAllButton.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "UpgradeAllButton"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- sit just above the tower panel (right-center, 240 wide, 200 tall, anchored
	-- at 0.5). Its top edge is at 50% - 100px, so we park our bottom 8px above that.
	btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = UDim2.new(1, -16, 0.5, -108)
	btn.Size = UDim2.fromOffset(240, 40)
	btn.BackgroundColor3 = Color3.fromRGB(40, 90, 60)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = Color3.fromRGB(235, 238, 245)
	btn.Text = "⬆ Upgrade All"
	btn.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	btn.Parent = gui

	btn.Activated:Connect(function()
		upgradeAllRemote:FireServer()
	end)

	-- keep the price label live: cash changes drive most of it, and a light
	-- heartbeat catches towers being placed / upgraded / sold meanwhile
	ClientState.onChange(refresh)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			refresh()
		end
	end)
	refresh()
end

return UpgradeAllButton
