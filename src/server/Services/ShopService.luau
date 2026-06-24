--!strict
-- Handles purchases: seeds (by tree id) and the next shovel tier. All pricing
-- and validation are server-side; the client only sends intent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trees = require(Shared.Config.Trees)
local Shovels = require(Shared.Config.Shovels)
local Net = require(Shared.Net)

local DataManager = require(script.Parent.Parent.Data.DataManager)
local EconomyService = require(script.Parent.EconomyService)
local FarmingService = require(script.Parent.FarmingService)
local Replication = require(script.Parent.Replication)

local ShopService = {}

local function buySeed(player: Player, treeId: string, quantity: number): (boolean, string)
	local tree = Trees.ById[treeId]
	if not tree then
		return false, "Unknown seed"
	end
	if not tree.seedCost then
		return false, "That seed can't be bought"
	end
	quantity = math.clamp(math.floor(quantity or 1), 1, 100)
	local cost = tree.seedCost * quantity
	if not EconomyService.trySpend(player, cost) then
		return false, "Not enough coins"
	end
	EconomyService.grantSeed(player, treeId, quantity)
	return true, ("Bought %d %s seed(s)"):format(quantity, tree.name)
end

local function buyShovel(player: Player): (boolean, string)
	local profile = DataManager.get(player.UserId)
	if not profile then
		return false, "No data"
	end
	local nextShovel = Shovels.next(profile.data.Shovel)
	if not nextShovel then
		return false, "Already max shovel"
	end
	if not EconomyService.trySpend(player, nextShovel.cost) then
		return false, "Not enough coins"
	end
	profile.data.Shovel = nextShovel.id
	Replication.replicate(player)
	FarmingService.refreshLocks(player)
	Net.event("Notify"):FireClient(player, ("Upgraded to %s!"):format(nextShovel.name))
	return true, "Upgraded"
end

function ShopService.init()
	Net.func("BuySeed").OnServerInvoke = function(player, treeId, quantity)
		if typeof(treeId) ~= "string" then
			return false, "Bad request"
		end
		return buySeed(player, treeId, quantity)
	end

	Net.func("BuyShovel").OnServerInvoke = function(player)
		return buyShovel(player)
	end
end

return ShopService
