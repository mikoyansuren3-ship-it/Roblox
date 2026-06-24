--!strict
-- Orchestrates the player lifecycle: load data, assign a plot, replicate the
-- snapshot to the client, and clean up + save on leave. This is the only place
-- that ties the data and plot systems together for a player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local DataManager = require(script.Parent.Parent.Data.DataManager)
local PlotService = require(script.Parent.PlotService)
local FarmingService = require(script.Parent.FarmingService)
local WorldService = require(script.Parent.WorldService)
local ShovelService = require(script.Parent.ShovelService)
local Replication = require(script.Parent.Replication)

local PlayerService = {}

-- Push the current data snapshot to one client.
local function replicate(player: Player)
	Replication.replicate(player)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = GameConfig.Character.WalkSpeed
	end
	-- Small delay so the HumanoidRootPart exists before we move it.
	task.wait(0.2)
	PlotService.teleportToPlot(player)
	ShovelService.giveShovel(player)
end

local function onPlayerAdded(player: Player)
	local profile = DataManager.load(player)
	if not profile then
		player:Kick("Your data could not be loaded safely. Please rejoin in a moment.")
		return
	end

	-- Login meta.
	local data = profile.data
	local now = os.time()
	data.TotalLogins += 1
	data.LastLogin = now

	local plot = PlotService.assign(player)
	if plot then
		FarmingService.onPlotReady(player, plot.model)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	replicate(player)
end

local function onPlayerRemoving(player: Player)
	FarmingService.releasePlot(player)
	PlotService.release(player)
	DataManager.save(player.UserId, true)
end

function PlayerService.init()
	-- GetProfile lets the client pull a snapshot on demand (e.g. on join race).
	Net.func("GetProfile").OnServerInvoke = function(player: Player)
		local profile = DataManager.get(player.UserId)
		return profile and profile.data or nil
	end

	-- Teleport the caller to a hub shop's neon pad, then tell the client to open
	-- the matching shop UI.
	Net.func("TeleportToShop").OnServerInvoke = function(player: Player, shopType)
		if shopType ~= "Seed" and shopType ~= "Shovel" then
			return false
		end
		local landing = WorldService.getShopLanding(shopType)
		local character = player.Character
		if not landing or not character then
			return false
		end
		character:PivotTo(landing)
		Net.event("ShopOpened"):FireClient(player, shopType)
		return true
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already present (e.g. live script reload).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService
