--!strict
-- Allocates one of the 8 soil plots to each player on join and frees it on
-- leave. All plots are pre-built in a 2-row x 4-column grid at init; assigning
-- just stamps ownership + signage onto the next free one. Footprint is tier
-- driven (profile.PlotTier) so plots can be expanded later without relaying out.

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local DataManager = require(script.Parent.Parent.Data.DataManager)

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
}

local plotsFolder: Folder
local slots: { [number]: number? } = {} -- plot index -> owner userId (nil = free)
local byUser: { [number]: Plot } = {}
local plotModels: { [number]: Model } = {}

local SOIL = GameConfig.Plots.Color
local EDGE = GameConfig.Plots.EdgeColor

local function footprintForTier(tier: number): number
	return GameConfig.Plots.SizeTiers[tier] or GameConfig.Plots.BaseSize
end

-- index -> (x, z, row): rows 1-2 along Z, columns 1-4 along X, centered on hub.
local function gridInfo(index: number): (number, number, number)
	local grid = GameConfig.Plots.Grid
	local col = ((index - 1) % grid.Columns) + 1
	local row = math.floor((index - 1) / grid.Columns) + 1
	local x = (col - (grid.Columns + 1) / 2) * grid.ColumnSpacing
	local z = (row == 1) and grid.RowSpacing or -grid.RowSpacing
	return x, z, row
end

local function centerCFrame(index: number): CFrame
	local x, z = gridInfo(index)
	return CFrame.new(x, GameConfig.World.SurfaceY + GameConfig.Plots.Height / 2, z)
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function setSignText(model: Model, text: string)
	local sign = model:FindFirstChild("Sign")
	local board = sign and sign:FindFirstChild("Board")
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Resizes the base + rebuilds the fence and hub-facing sign for `footprint`.
-- Slot pads are owned by FarmingService and repositioned separately.
local function applyFootprint(model: Model, footprint: number)
	local index = model:GetAttribute("PlotIndex") :: number
	local height = GameConfig.Plots.Height
	local base = model:FindFirstChild("Base") :: BasePart
	base.Size = Vector3.new(footprint, height, footprint)
	base.CFrame = centerCFrame(index)
	model:SetAttribute("FootprintSize", footprint)

	-- Spawn pad (invisible) at the plot center.
	local pad = model:FindFirstChild("SpawnPad") :: BasePart?
	if not pad then
		pad = makePart("SpawnPad", Vector3.new(4, 1, 4), CFrame.new(), Color3.new(), Enum.Material.SmoothPlastic, model)
		pad.CanCollide = false
		pad.Transparency = 1
	end
	pad.CFrame = centerCFrame(index) * CFrame.new(0, height / 2 + GameConfig.Plots.SpawnHeight, 0)

	-- Corner fence posts marking the (expandable) boundary.
	local oldFence = model:FindFirstChild("Fence")
	if oldFence then
		oldFence:Destroy()
	end
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model
	local h = footprint / 2 - 0.6
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			makePart(
				"Post",
				Vector3.new(1.4, 3.2, 1.4),
				centerCFrame(index) * CFrame.new(sx * h, height / 2 + 1.6, sz * h),
				EDGE,
				Enum.Material.WoodPlanks,
				fence
			)
		end
	end

	-- Hub-facing sign.
	local oldSign = model:FindFirstChild("Sign")
	if oldSign then
		oldSign:Destroy()
	end
	local x, z, row = gridInfo(index)
	local hubFacing = (row == 1) and -1 or 1
	local edge = footprint / 2 + 1.5
	local yaw = (row == 1) and 0 or math.pi
	local signCF = CFrame.new(x, GameConfig.World.SurfaceY, z + hubFacing * edge) * CFrame.Angles(0, yaw, 0)

	local signModel = Instance.new("Model")
	signModel.Name = "Sign"
	signModel.Parent = model
	local woodDark = Color3.fromRGB(86, 58, 34)
	makePart("Post", Vector3.new(0.8, 5, 0.8), signCF * CFrame.new(0, 2.5, 0), woodDark, Enum.Material.Wood, signModel)
	local board = makePart("Board", Vector3.new(10, 3, 0.5), signCF * CFrame.new(0, 5.5, 0), woodDark, Enum.Material.Wood, signModel)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 230, 210)
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = gui
end

local function buildPlotModel(index: number): Model
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	makePart("Base", Vector3.new(GameConfig.Plots.BaseSize, GameConfig.Plots.Height, GameConfig.Plots.BaseSize), centerCFrame(index), SOIL, Enum.Material.Ground, model)

	model.PrimaryPart = model:FindFirstChild("Base") :: BasePart
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model.Parent = plotsFolder

	applyFootprint(model, GameConfig.Plots.BaseSize)
	setSignText(model, ("Plot %d\nAvailable"):format(index))
	return model
end

function PlotService.init()
	plotsFolder = Workspace:FindFirstChild("Plots") :: Folder
	if plotsFolder then
		plotsFolder:Destroy()
	end
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	for i = 1, GameConfig.Plots.Max do
		slots[i] = nil
		plotModels[i] = buildPlotModel(i)
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
	local model = plotModels[index]
	model:SetAttribute("OwnerUserId", player.UserId)

	local profile = DataManager.get(player.UserId)
	local tier = (profile and profile.data.PlotTier) or 1
	applyFootprint(model, footprintForTier(tier))
	setSignText(model, ("%s's Plot"):format(player.Name))

	local plot: Plot = { index = index, model = model }
	byUser[player.UserId] = plot
	return plot
end

function PlotService.release(player: Player)
	local plot = byUser[player.UserId]
	if not plot then
		return
	end
	slots[plot.index] = nil
	local model = plot.model
	model:SetAttribute("OwnerUserId", 0)
	applyFootprint(model, GameConfig.Plots.BaseSize)
	setSignText(model, ("Plot %d\nAvailable"):format(plot.index))
	byUser[player.UserId] = nil
end

function PlotService.get(player: Player): Plot?
	return byUser[player.UserId]
end

-- Resizes a player's plot to a new tier (geometry only). Slot repositioning is
-- the farming system's job; callers should refresh it afterwards.
function PlotService.applyPlotSize(player: Player, tier: number)
	local plot = byUser[player.UserId]
	if not plot then
		return
	end
	applyFootprint(plot.model, footprintForTier(tier))
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
