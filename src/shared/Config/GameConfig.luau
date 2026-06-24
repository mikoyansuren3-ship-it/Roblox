--!strict
-- Central tuning constants shared by server and client.

local GameConfig = {
	GameName = "Restore a Planet",

	-- DataStore
	DataStoreName = "PlayerData_v1", -- bump the suffix to wipe/migrate live data
	AutosaveInterval = 60, -- seconds between background saves

	-- Shared overworld (terrain + hub buildings)
	World = {
		SurfaceY = 0, -- Y of the walkable terrain top
		Terrain = {
			Center = Vector3.new(200, -16, 0),
			Size = Vector3.new(560, 32, 420),
		},
		SeedShop = {
			Position = Vector3.new(200, 0, -130),
		},
	},

	-- Per-player plots laid out along +X on the terrain
	Plots = {
		Max = 6, -- how many players a single server can host
		Size = Vector3.new(48, 1, 48),
		Spacing = 80, -- studs between plot centers along the X axis
		Origin = Vector3.new(0, 0, 0), -- center of plot 1
		Color = Color3.fromRGB(86, 125, 70),
		SpawnHeight = 5, -- how high above the plot to drop the character
	},

	-- Economy starting point
	StartingCoins = 0,
}

return GameConfig
