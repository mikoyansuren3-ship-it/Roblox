--!strict
-- Weighted rarity roller. Luck biases the roll toward rarer tiers by scaling
-- each non-Common weight up by (1 + luck). The result is renormalized, so luck
-- never breaks the distribution — it just shifts mass upward. Returns a rarity.

local Rarities = require(script.Parent.Parent.Config.Rarities)

local Roll = {}

-- Roll a rarity. `luck` is additive (0 = base odds, 1.0 = doubled rare weights).
-- `maxRarity` optionally caps the result (e.g. a tool gate) by zeroing tiers above it.
function Roll.rarity(luck: number, maxRarity: Rarities.Rarity?): Rarities.Rarity
	luck = math.max(0, luck or 0)
	local maxRank = maxRarity and Rarities.rank(maxRarity) or #Rarities.Order

	-- Build effective weights.
	local weights: { number } = {}
	local total = 0
	for rank, name in Rarities.Order do
		local info = Rarities.Data[name]
		local w = 0
		if rank <= maxRank then
			-- Commons are not boosted by luck; everything rarer scales with it.
			local boost = (name == "Common") and 1 or (1 + luck)
			w = info.weight * boost
		end
		weights[rank] = w
		total += w
	end

	if total <= 0 then
		return "Common"
	end

	local pick = math.random() * total
	local cursor = 0
	for rank, w in weights do
		cursor += w
		if pick <= cursor then
			return Rarities.Order[rank]
		end
	end
	return "Common"
end

-- Uniform choice from a list (used after a rarity is rolled, to pick a species).
function Roll.choice(list)
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

return Roll
