--!strict
-- Client entrypoint: HUD, hotbar, and ghost-preview tower placement.

local UIController = require(script.UIController)
local Hotbar = require(script.Hotbar)
local PlacementController = require(script.PlacementController)

UIController.init()
Hotbar.init()
PlacementController.init()

print("[Client] HUD + hotbar + placement ready")
