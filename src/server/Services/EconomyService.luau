--!strict
-- All currency and seed mutations funnel through here so balance changes are
-- server-authoritative and always followed by replication. Never mutate
-- profile.data.Coins / Seeds directly from other systems.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trees = require(Shared.Config.Trees)

local DataManager = require(script.Parent.Parent.Data.DataManager)
local Replication = require(script.Parent.Replication)

local EconomyService = {}

function EconomyService.getCoins(player: Player): number
	local profile = DataManager.get(player.UserId)
	return profile and profile.data.Coins or 0
end

-- Adds (or subtracts) coins, clamped at zero. Returns the new balance.
function EconomyService.addCoins(player: Player, amount: number): number
	local profile = DataManager.get(player.UserId)
	if not profile then
		return 0
	end
	profile.data.Coins = math.max(0, profile.data.Coins + amount)
	Replication.replicate(player)
	return profile.data.Coins
end

-- Attempts to spend coins. Returns true on success, false if too poor.
function EconomyService.trySpend(player: Player, amount: number): boolean
	local profile = DataManager.get(player.UserId)
	if not profile or profile.data.Coins < amount then
		return false
	end
	profile.data.Coins -= amount
	Replication.replicate(player)
	return true
end

function EconomyService.getSeedCount(player: Player, treeId: string): number
	local profile = DataManager.get(player.UserId)
	return profile and (profile.data.Seeds[treeId] or 0) or 0
end

function EconomyService.grantSeed(player: Player, treeId: string, count: number)
	local profile = DataManager.get(player.UserId)
	if not profile or not Trees.ById[treeId] then
		return
	end
	profile.data.Seeds[treeId] = (profile.data.Seeds[treeId] or 0) + count
	Replication.replicate(player)
end

-- Consumes one seed if available. Returns true if a seed was spent.
function EconomyService.consumeSeed(player: Player, treeId: string): boolean
	local profile = DataManager.get(player.UserId)
	if not profile then
		return false
	end
	local have = profile.data.Seeds[treeId] or 0
	if have <= 0 then
		return false
	end
	profile.data.Seeds[treeId] = have - 1
	Replication.replicate(player)
	return true
end

return EconomyService
