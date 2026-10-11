--!strict
-- Central tuning constants shared by server and client.

local GameConfig = {
	GameName = "Restore a Planet",

	-- DataStore
	DataStoreName = "PlayerData_v1", -- bump the suffix to wipe/migrate live data
	AutosaveInterval = 60, -- seconds between background saves

	-- Character tuning
	Character = {
		WalkSpeed = 28, -- bumped from the default 16 so the bigger map feels brisk
	},

	-- Shared overworld: big cartoon map with a central shop hub.
	World = {
		SurfaceY = 0, -- Y of the walkable ground top

		Terrain = {
			Center = Vector3.new(0, -16, 0),
			Size = Vector3.new(900, 32, 900), -- large playable area centered on the hub
			GrassColor = Color3.fromRGB(112, 196, 86), -- bright, saturated cartoon grass
		},

		-- Central plaza where the two shop stalls sit.
		Hub = {
			Center = Vector3.new(0, 0, 0),
			PlazaSize = Vector3.new(150, 1, 96),
			PlazaColor = Color3.fromRGB(154, 146, 124),
		},

		-- Both stalls share buildShopStall(); only theme + offset differ.
		Shops = {
			Seed = {
				Offset = Vector3.new(-34, 0, 0), -- left of hub center
				AwningA = Color3.fromRGB(74, 168, 96), -- green
				AwningB = Color3.fromRGB(238, 232, 198), -- cream
				Sign = "Seed Shop",
				SignColor = Color3.fromRGB(54, 122, 78),
				Accent = Color3.fromRGB(96, 184, 110),
				VendorShirt = Color3.fromRGB(72, 150, 92),
				TriggerColor = Color3.fromRGB(96, 220, 130),
			},
			Shovel = {
				Offset = Vector3.new(34, 0, 0), -- right of hub center
				AwningA = Color3.fromRGB(126, 88, 52), -- brown
				AwningB = Color3.fromRGB(205, 210, 214), -- silver
				Sign = "Shovel Shop",
				SignColor = Color3.fromRGB(120, 84, 48),
				Accent = Color3.fromRGB(150, 120, 90),
				VendorShirt = Color3.fromRGB(120, 96, 64),
				TriggerColor = Color3.fromRGB(120, 200, 240),
			},
		},

		TriggerRadius = 14, -- big glowing pad (~5 avatars across)
		TriggerForward = 19, -- studs in front of each stall the pad center sits
	},

	-- Per-player plots: 8 claimable soil plots in a 2-row x 4-column grid.
	Plots = {
		Max = 8, -- server capacity; grid below can be widened to raise this
		Grid = {
			Columns = 4,
			Rows = 2,
			ColumnSpacing = 140, -- X centers: -210, -70, 70, 210
			RowSpacing = 150, -- |Z| of each row (north = +, south = -)
		},
		BaseSize = 96, -- tier 1 footprint (studs square) -- big plots
		SizeTiers = { 96, 144, 192 }, -- expandable footprints (purchase flow is future work)
		Height = 1, -- soil base thickness
		Color = Color3.fromRGB(124, 86, 54), -- warm brown soil (clearly not grass)
		EdgeColor = Color3.fromRGB(92, 64, 40), -- fence / border posts
		SpawnHeight = 5, -- how high above the plot to drop the character
	},

	-- Economy starting point
	StartingCoins = 0,
}

return GameConfig
