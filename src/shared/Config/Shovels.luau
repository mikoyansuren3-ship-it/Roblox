--!strict
-- Shovel upgrade track. `slots` = how many planting tiles are unlocked,
-- `luck` = additive luck multiplier applied to seed-drop rolls (0.25 = +25%),
-- `digSpeed` = plant action speed multiplier (reserved for later), `cost` in Coins.

export type Shovel = {
	id: string,
	name: string,
	slots: number,
	luck: number,
	digSpeed: number,
	cost: number,
}

local Shovels = {}

-- Ordered cheapest -> most expensive; index is the upgrade order.
Shovels.Order = {
	{ id = "Wooden", name = "Wooden Shovel", slots = 1, luck = 0.0, digSpeed = 1.0, cost = 0 },
	{ id = "Copper", name = "Copper Shovel", slots = 1, luck = 0.10, digSpeed = 1.5, cost = 250 },
	{ id = "Iron", name = "Iron Shovel", slots = 2, luck = 0.25, digSpeed = 2.0, cost = 2000 },
	{ id = "Gold", name = "Gold Shovel", slots = 3, luck = 0.50, digSpeed = 3.0, cost = 15000 },
	{ id = "Diamond", name = "Diamond Shovel", slots = 4, luck = 1.00, digSpeed = 4.5, cost = 120000 },
	{ id = "Emerald", name = "Emerald Shovel", slots = 6, luck = 2.00, digSpeed = 6.0, cost = 900000 },
} :: { Shovel }

Shovels.MaxSlots = 6 -- highest slots value across all tiers

Shovels.ById = {} :: { [string]: Shovel }
for _, shovel in Shovels.Order do
	Shovels.ById[shovel.id] = shovel
end

function Shovels.indexOf(id: string): number
	for index, shovel in Shovels.Order do
		if shovel.id == id then
			return index
		end
	end
	return 1
end

-- The next tier up, or nil if already maxed.
function Shovels.next(id: string): Shovel?
	local index = Shovels.indexOf(id)
	return Shovels.Order[index + 1]
end

return Shovels
