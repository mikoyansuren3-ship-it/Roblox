--!strict
-- Thin networking layer. The server calls Net.setup() once at boot to create
-- the remote instances; both sides then resolve them by name. Keeping the
-- canonical list here means the client never invents a remote the server
-- doesn't expose, which keeps the boundary server-authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local FOLDER_NAME = "RAP_Remotes"

-- Declared remotes. Add new names here as systems are built.
local REMOTE_EVENTS = {
	"DataChanged", -- server -> client: pushes a (partial or full) data snapshot
	"Notify", -- server -> client: transient toast / announcement text
	"Reveal", -- server -> client: harvest reveal payload (rarity, item, drop)
	"SelectSeed", -- client -> server: set which seed to plant next
	"ShopOpened", -- server -> client: a shop was opened (e.g. after teleport); payload = shop type
}

local REMOTE_FUNCTIONS = {
	"GetProfile", -- client -> server: fetch the caller's current data snapshot
	"BuySeed", -- client -> server: purchase a seed; returns ok/reason
	"BuyShovel", -- client -> server: purchase the next shovel tier; returns ok/reason
	"TeleportToShop", -- client -> server: teleport caller to a hub shop ("Seed" | "Shovel")
}

-- Server only: build the remote folder. Safe to call once.
function Net.setup(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for _, name in REMOTE_EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	for _, name in REMOTE_FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

local function folder(): Folder
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

return Net
