--!strict
-- Forest tree species. Mirrors the design canvas. `grow` is seconds to mature,
-- `seedCost` is the shop price of one seed (nil = luck-only, never buyable),
-- `value` is the Coins paid on harvest. `leaf` tints the grown model.

local Rarities = require(script.Parent.Rarities)

export type Tree = {
	id: string,
	name: string,
	rarity: Rarities.Rarity,
	grow: number,
	seedCost: number?,
	value: number,
	leaf: Color3,
}

local Trees = {}

Trees.List = {
	{ id = "Oak", name = "Oak", rarity = "Common", grow = 30, seedCost = 5, value = 10, leaf = Color3.fromRGB(86, 156, 74) },
	{ id = "Birch", name = "Birch", rarity = "Uncommon", grow = 60, seedCost = 25, value = 28, leaf = Color3.fromRGB(140, 196, 96) },
	{ id = "Pine", name = "Pine", rarity = "Uncommon", grow = 90, seedCost = 40, value = 45, leaf = Color3.fromRGB(54, 120, 88) },
	{ id = "Maple", name = "Maple", rarity = "Rare", grow = 120, seedCost = 120, value = 140, leaf = Color3.fromRGB(214, 102, 64) },
	{ id = "Cherry", name = "Cherry Blossom", rarity = "Rare", grow = 180, seedCost = 200, value = 220, leaf = Color3.fromRGB(244, 178, 206) },
	{ id = "Willow", name = "Willow", rarity = "Epic", grow = 300, seedCost = 600, value = 700, leaf = Color3.fromRGB(150, 178, 120) },
	{ id = "Redwood", name = "Redwood", rarity = "Epic", grow = 360, seedCost = 850, value = 950, leaf = Color3.fromRGB(120, 78, 56) },
	{ id = "GoldenOak", name = "Golden Oak", rarity = "Legendary", grow = 600, seedCost = 3000, value = 3200, leaf = Color3.fromRGB(240, 196, 80) },
	{ id = "Rainbow", name = "Rainbow Eucalyptus", rarity = "Legendary", grow = 720, seedCost = 4200, value = 4500, leaf = Color3.fromRGB(120, 200, 220) },
	{ id = "Sequoia", name = "Ancient Sequoia", rarity = "Mythic", grow = 1200, seedCost = 15000, value = 15000, leaf = Color3.fromRGB(96, 140, 90) },
	{ id = "WorldTree", name = "World Tree", rarity = "Mythic", grow = 1500, seedCost = 21000, value = 22000, leaf = Color3.fromRGB(130, 220, 160) },
	{ id = "Spirit", name = "Spirit Tree", rarity = "Secret", grow = 1800, seedCost = nil, value = 80000, leaf = Color3.fromRGB(180, 230, 255) },
	{ id = "Bonsai", name = "Crystal Bonsai", rarity = "Secret", grow = 2100, seedCost = nil, value = 120000, leaf = Color3.fromRGB(200, 180, 255) },
} :: { Tree }

-- id -> Tree lookup, built once.
Trees.ById = {} :: { [string]: Tree }
for _, tree in Trees.List do
	Trees.ById[tree.id] = tree
end

-- All trees of a given rarity (used for seed-drop rolls).
function Trees.ofRarity(rarity: Rarities.Rarity): { Tree }
	local out = {}
	for _, tree in Trees.List do
		if tree.rarity == rarity then
			table.insert(out, tree)
		end
	end
	return out
end

return Trees
