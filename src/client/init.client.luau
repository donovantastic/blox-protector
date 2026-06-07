--!strict
-- Client entrypoint: HUD, hotbar, and ghost-preview tower placement.

local UIController = require(script.UIController)
local Hotbar = require(script.Hotbar)
local PlacementController = require(script.PlacementController)
local TowerPanel = require(script.TowerPanel)
local DialogueController = require(script.DialogueController)
local CardController = require(script.CardController)

UIController.init()
Hotbar.init()
PlacementController.init()
TowerPanel.init()
DialogueController.init()
CardController.init()

print("[Client] HUD + hotbar + placement + tower panel + story UI ready")
