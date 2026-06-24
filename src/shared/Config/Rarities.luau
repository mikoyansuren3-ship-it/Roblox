--!strict
-- The shared 7-tier rarity ladder. Drives trees, beach trash, and ocean trash.
-- `weight` is the no-luck base spawn weight (percent). Luck multipliers later
-- reweight toward the top tiers. Colors mirror the design canvas.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type RarityInfo = {
	weight: number,
	color: Color3,
	announce: boolean, -- server-wide announcement when a player pulls this tier
	buyable: boolean, -- whether a seed/item of this tier can be bought (vs luck-only)
}

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" } :: { Rarity }

Rarities.Data = {
	Common = { weight = 55, color = Color3.fromRGB(180, 180, 180), announce = false, buyable = true },
	Uncommon = { weight = 27, color = Color3.fromRGB(63, 162, 102), announce = false, buyable = true },
	Rare = { weight = 11, color = Color3.fromRGB(123, 175, 233), announce = false, buyable = true },
	Epic = { weight = 4.5, color = Color3.fromRGB(147, 134, 242), announce = false, buyable = true },
	Legendary = { weight = 1.8, color = Color3.fromRGB(241, 180, 103), announce = false, buyable = true },
	Mythic = { weight = 0.59, color = Color3.fromRGB(208, 135, 112), announce = true, buyable = true },
	Secret = { weight = 0.11, color = Color3.fromRGB(180, 142, 173), announce = true, buyable = false },
} :: { [Rarity]: RarityInfo }

-- Index of a rarity in the ladder (1 = Common). Useful for "max rarity" gates.
function Rarities.rank(rarity: Rarity): number
	for i, name in Rarities.Order do
		if name == rarity then
			return i
		end
	end
	return 0
end

return Rarities
