--!strict
-- Default data for a brand-new player. The DataManager reconciles every loaded
-- profile against this template, so adding a new key here automatically gives
-- existing players a sensible default on their next load. Keep this in sync with
-- the ProfileData type in ReplicatedStorage/Shared/Types.

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.GameConfig)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Types)

local ProfileTemplate: Types.ProfileData = {
	-- Economy
	Coins = GameConfig.StartingCoins,

	-- Progression
	Rebirths = 0,
	RegionUnlocked = 1,

	-- Forest
	Plots = {},
	PlotTier = 1,
	Shovel = "Wooden",
	Seeds = { Oak = 3 }, -- start with a few Oak seeds so there's something to do

	-- Ocean
	Tool = "Hands",
	Boat = "None",
	FishermanLevel = 0,
	FishermanLastCollect = 0,

	-- Inventory / collection
	Inventory = {},
	TreeDex = {},
	TrashDex = {},

	-- Companions
	Companions = {},
	EquippedCompanions = {},

	-- Meta
	Stats = {
		TreesPlanted = 0,
		TreesHarvested = 0,
		PlasticCollected = 0,
		Playtime = 0,
	},
	Settings = {
		Music = true,
		SFX = true,
	},
	LastLogin = 0,
	LoginStreak = 0,
	TotalLogins = 0,
}

return ProfileTemplate
