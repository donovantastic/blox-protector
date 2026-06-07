--!strict
-- Retro-Roblox mood: saturated colors + neon pop on blocky geometry (the "moody
-- database" look). Runtime-safe Lighting tweaks only (no Technology change). Tweak
-- or delete freely — purely cosmetic.

local Lighting = game:GetService("Lighting")

local Aesthetic = {}

function Aesthetic.apply()
	Lighting.Brightness = 2
	Lighting.ClockTime = 15
	Lighting.Ambient = Color3.fromRGB(64, 66, 92)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 98, 130)
	Lighting.FogColor = Color3.fromRGB(18, 20, 38)
	Lighting.FogEnd = 700
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4

	if not Lighting:FindFirstChild("ProtectorBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "ProtectorBloom"
		bloom.Intensity = 0.7
		bloom.Threshold = 1.1
		bloom.Size = 24
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChild("ProtectorColor") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ProtectorColor"
		cc.Saturation = 0.28
		cc.Contrast = 0.08
		cc.TintColor = Color3.fromRGB(235, 240, 255)
		cc.Parent = Lighting
	end
end

return Aesthetic
