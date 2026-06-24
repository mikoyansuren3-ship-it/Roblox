--!strict
-- Server entry point. Rojo turns this directory into a Script named "Server",
-- so its child modules are reachable via `script.<Child>`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local DataManager = require(script.Data.DataManager)
local WorldService = require(script.Services.WorldService)
local PlotService = require(script.Services.PlotService)
local FarmingService = require(script.Services.FarmingService)
local ShopService = require(script.Services.ShopService)
local PlayerService = require(script.Services.PlayerService)

-- Create remotes first so anything joining can resolve them.
Net.setup()

-- Order matters: data + plots + farming must be ready before players use them.
DataManager.init()
WorldService.init()
PlotService.init()
FarmingService.init()
ShopService.init()
PlayerService.init()

print(("[%s] Server initialized."):format(GameConfig.GameName))
