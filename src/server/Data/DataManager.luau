--!strict
-- Server-authoritative player data, backed by ProfileStore (the 2026 standard
-- successor to ProfileService). ProfileStore handles session locking, retries,
-- autosaving, shutdown saves, and cross-server lock handoff for us.
--
-- This module keeps the SAME public API the rest of the codebase already uses
-- (init / load / get / save returning a { userId, key, data } profile), so no
-- other system had to change. `data` is a live reference to Profile.Data, so any
-- mutation by EconomyService/FarmingService/etc. is auto-saved by ProfileStore.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Types = require(Shared.Types)

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

export type Profile = {
	userId: number,
	key: string,
	data: Types.ProfileData,
	_profile: any, -- underlying ProfileStore profile
}

local DataManager = {}

local KEY_PREFIX = "Player_"

local store: any = nil -- the ProfileStore (real or .Mock)
local profiles: { [number]: Profile } = {}

-- Detect whether live DataStores are reachable (false in Studio without API
-- access). When unreachable we use ProfileStore.Mock so the game still runs.
local function dataStoresAvailable(): boolean
	local ok = pcall(function()
		DataStoreService:GetDataStore("__probe__"):GetAsync("__probe__")
	end)
	return ok
end

function DataManager.init()
	if store then
		return
	end
	local base = ProfileStore.New(GameConfig.DataStoreName, ProfileTemplate)
	if dataStoresAvailable() then
		store = base
	else
		warn("[DataManager] DataStores unavailable - using ProfileStore.Mock. "
			.. "Data will NOT persist. (In Studio: enable 'Studio Access to API Services'.)")
		store = base.Mock
	end
end

-- Loads (or creates) a profile and claims the session. Returns nil if the
-- session could not be started (e.g. the player left mid-load).
function DataManager.load(player: Player): Profile?
	assert(store, "DataManager.init() must run before load()")
	local userId = player.UserId
	local key = KEY_PREFIX .. userId

	local profile = store:StartSessionAsync(key, {
		Cancel = function()
			-- Stop trying if the player has already left.
			return player.Parent ~= game:GetService("Players")
		end,
	})

	if not profile then
		return nil
	end

	-- The player may have left while the session was starting.
	if player.Parent ~= game:GetService("Players") then
		profile:EndSession()
		return nil
	end

	profile:AddUserId(userId) -- GDPR association
	profile:Reconcile() -- backfill any new template fields

	-- If another server steals the session, ProfileStore ends ours here.
	profile.OnSessionEnd:Connect(function()
		profiles[userId] = nil
		if player.Parent == game:GetService("Players") then
			player:Kick("Your data is active on another server. Please rejoin.")
		end
	end)

	local wrapped: Profile = {
		userId = userId,
		key = key,
		data = profile.Data,
		_profile = profile,
	}
	profiles[userId] = wrapped
	return wrapped
end

function DataManager.get(userId: number): Profile?
	return profiles[userId]
end

-- ProfileStore autosaves on its own. `release = true` ends the session (final
-- save) on leave/shutdown; `release = false` forces an immediate save, which we
-- rarely need but keep for API compatibility.
function DataManager.save(userId: number, release: boolean)
	local wrapped = profiles[userId]
	if not wrapped then
		return
	end
	local profile = wrapped._profile
	if release then
		profile:EndSession()
		profiles[userId] = nil
	elseif profile:IsActive() then
		profile:Save()
	end
end

return DataManager
