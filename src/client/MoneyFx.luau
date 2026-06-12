--!strict
-- ATM payout VFX. On AtmPayout, plays a cha-ching and bursts a few floating "$" labels
-- up out of each ATM that paid. Client-only effect (the cash itself is server-side).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local SoundController = require(script.Parent.SoundController)

local MoneyFx = {}

local GREEN = Color3.fromRGB(90, 220, 120)

local function dollar(position: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	local spread = 2.2
	part.Position = position
		+ Vector3.new(
			(math.random() - 0.5) * spread,
			6 + (math.random() - 0.5),
			(math.random() - 0.5) * spread
		)
	part.Parent = Workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(34, 34)
	bb.AlwaysOnTop = true
	bb.Adornee = part
	bb.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "$"
	label.TextColor3 = GREEN
	label.TextStrokeTransparency = 0.3
	label.Parent = bb

	-- float up + fade out
	local rise = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, rise, { Position = part.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, rise, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(part, 1)
end

function MoneyFx.init()
	Remotes.event("AtmPayout").OnClientEvent:Connect(function(positions, _total)
		SoundController.play("chaChing")
		if typeof(positions) == "table" then
			for _, pos in positions do
				if typeof(pos) == "Vector3" then
					for _ = 1, 5 do
						dollar(pos)
					end
				end
			end
		end
	end)
end

return MoneyFx
