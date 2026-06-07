--!strict
-- Client entrypoint: HUD, hotbar, and ghost-preview tower placement.

local SoundController = require(script.SoundController)
local UIController = require(script.UIController)
local Hotbar = require(script.Hotbar)
local PlacementController = require(script.PlacementController)
local TowerPanel = require(script.TowerPanel)
local DialogueController = require(script.DialogueController)
local CardController = require(script.CardController)
local HandController = require(script.HandController)
local ConversationController = require(script.ConversationController)
local ExploreController = require(script.ExploreController)

SoundController.init()
UIController.init()
Hotbar.init()
PlacementController.init()
TowerPanel.init()
DialogueController.init()
CardController.init()
HandController.init()
ConversationController.init()
ExploreController.init()

print("[Client] HUD + hotbar + placement + tower panel + story + conversation + explore ready")
