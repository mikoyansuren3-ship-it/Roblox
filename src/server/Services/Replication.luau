--!strict
-- Single place that pushes server data state to clients. Centralizing this means
-- every system mutates DataManager data and then calls replicate(player) — the
-- client never receives state from anywhere else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local DataManager = require(script.Parent.Parent.Data.DataManager)

local Replication = {}

function Replication.replicate(player: Player)
	local profile = DataManager.get(player.UserId)
	if profile then
		Net.event("DataChanged"):FireClient(player, profile.data)
	end
end

return Replication
