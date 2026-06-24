--!strict
-- Canonical type definitions for saved player data. The runtime default lives
-- in src/server/Data/ProfileTemplate.luau and MUST stay in sync with this shape.

export type PlotSlot = {
	seedId: string?, -- which seed is planted, nil if empty
	plantedAt: number, -- os.time() when planted (0 if empty)
	grown: boolean, -- has the grow timer completed
}

export type Stats = {
	TreesPlanted: number,
	TreesHarvested: number,
	PlasticCollected: number,
	Playtime: number,
}

export type Settings = {
	Music: boolean,
	SFX: boolean,
}

export type ProfileData = {
	-- Economy
	Coins: number,

	-- Progression
	Rebirths: number,
	RegionUnlocked: number, -- index into the prestige region list (1 = Meadow)

	-- Forest
	Plots: { [number]: PlotSlot }, -- keyed by plot slot index
	PlotTier: number, -- plot footprint tier (1 = base size); drives expansion
	Shovel: string, -- current shovel tier id
	Seeds: { [string]: number }, -- seedId -> count owned

	-- Ocean
	Tool: string, -- current collection tool tier id
	Boat: string, -- current boat tier id ("None" = beach only)
	FishermanLevel: number, -- 0 = not hired
	FishermanLastCollect: number, -- os.time() of last idle settlement

	-- Inventory / collection
	Inventory: { [string]: number }, -- unsold itemId -> count
	TreeDex: { [string]: boolean }, -- discovered tree species
	TrashDex: { [string]: boolean }, -- discovered trash items

	-- Companions
	Companions: { string }, -- owned companion ids
	EquippedCompanions: { string }, -- currently equipped ids

	-- Meta
	Stats: Stats,
	Settings: Settings,
	LastLogin: number,
	LoginStreak: number,
	TotalLogins: number,
}

return {}
