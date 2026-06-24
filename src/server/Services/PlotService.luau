--!strict
-- Allocates a physical plot to each player on join and frees it on leave.
-- Plots are laid out on a simple line along +X for now; the real map art slots
-- in later by replacing the generated base with a template model. Keeping the
-- allocation logic separate from the visuals means that swap is painless.

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
}

local plotsFolder: Folder
local slots: { [number]: number? } = {} -- plot index -> owner userId (nil = free)
local byUser: { [number]: Plot } = {}

local function plotCenter(index: number): Vector3
	local plots = GameConfig.Plots
	return Vector3.new(
		plots.Origin.X + (index - 1) * plots.Spacing,
		GameConfig.World.SurfaceY + plots.Size.Y / 2,
		plots.Origin.Z
	)
end

local function plotCFrame(index: number): CFrame
	return CFrame.new(plotCenter(index))
end

function PlotService.init()
	plotsFolder = Workspace:FindFirstChild("Plots") :: Folder
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "Plots"
		plotsFolder.Parent = Workspace
	end
	for i = 1, GameConfig.Plots.Max do
		slots[i] = nil
	end
end

local function firstFreeSlot(): number?
	for i = 1, GameConfig.Plots.Max do
		if slots[i] == nil then
			return i
		end
	end
	return nil
end

local function buildPlotModel(player: Player, index: number): Model
	local model = Instance.new("Model")
	model.Name = "Plot_" .. player.UserId

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.Size = GameConfig.Plots.Size
	base.CFrame = plotCFrame(index)
	base.Material = Enum.Material.Grass
	base.Color = GameConfig.Plots.Color
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = model

	local spawnPad = Instance.new("Part")
	spawnPad.Name = "SpawnPad"
	spawnPad.Anchored = true
	spawnPad.CanCollide = false
	spawnPad.Transparency = 1
	spawnPad.Size = Vector3.new(4, 1, 4)
	spawnPad.CFrame = plotCFrame(index)
		* CFrame.new(0, GameConfig.Plots.Size.Y / 2 + GameConfig.Plots.SpawnHeight, 0)
	spawnPad.Parent = model

	model.PrimaryPart = base
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlotIndex", index)
	model.Parent = plotsFolder
	return model
end

-- Claims a free plot for the player. Returns nil if the server is full.
function PlotService.assign(player: Player): Plot?
	if byUser[player.UserId] then
		return byUser[player.UserId]
	end
	local index = firstFreeSlot()
	if not index then
		warn(("[PlotService] no free plot for %s"):format(player.Name))
		return nil
	end
	slots[index] = player.UserId
	local plot: Plot = { index = index, model = buildPlotModel(player, index) }
	byUser[player.UserId] = plot
	return plot
end

function PlotService.release(player: Player)
	local plot = byUser[player.UserId]
	if not plot then
		return
	end
	slots[plot.index] = nil
	if plot.model then
		plot.model:Destroy()
	end
	byUser[player.UserId] = nil
end

function PlotService.get(player: Player): Plot?
	return byUser[player.UserId]
end

-- Drops the player's character onto their plot's spawn pad.
function PlotService.teleportToPlot(player: Player)
	local plot = byUser[player.UserId]
	local character = player.Character
	if not plot or not character then
		return
	end
	local pad = plot.model:FindFirstChild("SpawnPad")
	if pad and pad:IsA("BasePart") then
		character:PivotTo(pad.CFrame)
	end
end

return PlotService
