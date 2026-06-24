--!strict
-- Builds the shared overworld: grass terrain, paths, and hub buildings like the
-- seed store hut. Plot allocation stays in PlotService; this only owns static map art.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local WorldService = {}

local WOOD = Color3.fromRGB(120, 84, 48)
local WOOD_DARK = Color3.fromRGB(86, 58, 34)
local ROOF = Color3.fromRGB(74, 52, 38)
local SIGN_GREEN = Color3.fromRGB(54, 122, 78)

local function plotCenterX(index: number): number
	return GameConfig.Plots.Origin.X + (index - 1) * GameConfig.Plots.Spacing
end

local function surfaceY(): number
	return GameConfig.World.SurfaceY
end

local function makePart(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
}): BasePart
	local part = Instance.new("Part")
	part.Name = props.name
	part.Anchored = true
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color
	part.Material = props.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		part.Shape = props.shape
	end
	if props.transparency then
		part.Transparency = props.transparency
	end
	if props.canCollide ~= nil then
		part.CanCollide = props.canCollide
	end
	part.Parent = props.parent
	return part
end

local function buildTerrain(parent: Folder)
	local info = GameConfig.World.Terrain
	Workspace.Terrain:FillBlock(CFrame.new(info.Center), info.Size, Enum.Material.Grass)

	-- Flat spawn plateau so the hub area reads clearly on top of terrain.
	local plateau = makePart({
		name = "HubPlateau",
		size = Vector3.new(120, 1, 90),
		cframe = CFrame.new(GameConfig.World.SeedShop.Position.X, surfaceY() + 0.5, GameConfig.World.SeedShop.Position.Z + 35),
		color = Color3.fromRGB(96, 132, 78),
		material = Enum.Material.Grass,
		parent = parent,
	})
	plateau.Material = Enum.Material.LeafyGrass

	-- Stone path from the seed hut toward the plot row.
	for step = 0, 8 do
		makePart({
			name = "Path_" .. step,
			size = Vector3.new(10, 0.4, 8),
			cframe = CFrame.new(
				GameConfig.World.SeedShop.Position.X,
				surfaceY() + 0.2,
				GameConfig.World.SeedShop.Position.Z + 18 + step * 10
			),
			color = Color3.fromRGB(148, 140, 128),
			material = Enum.Material.Cobblestone,
			parent = parent,
		})
	end
end

local function buildSeedShop(parent: Folder): Model
	local shopPos = GameConfig.World.SeedShop.Position
	local y = surfaceY()
	local model = Instance.new("Model")
	model.Name = "SeedShop"
	model.Parent = parent

	-- Floor
	makePart({
		name = "Floor",
		size = Vector3.new(18, 0.6, 14),
		cframe = CFrame.new(shopPos.X, y + 0.3, shopPos.Z),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
		parent = model,
	})

	-- Back wall
	makePart({
		name = "WallBack",
		size = Vector3.new(18, 10, 0.8),
		cframe = CFrame.new(shopPos.X, y + 5.4, shopPos.Z - 6.6),
		color = WOOD,
		material = Enum.Material.Wood,
		parent = model,
	})

	-- Side walls
	makePart({
		name = "WallLeft",
		size = Vector3.new(0.8, 10, 14),
		cframe = CFrame.new(shopPos.X - 8.6, y + 5.4, shopPos.Z),
		color = WOOD,
		material = Enum.Material.Wood,
		parent = model,
	})
	makePart({
		name = "WallRight",
		size = Vector3.new(0.8, 10, 14),
		cframe = CFrame.new(shopPos.X + 8.6, y + 5.4, shopPos.Z),
		color = WOOD,
		material = Enum.Material.Wood,
		parent = model,
	})

	-- Front wall with door gap (two side panels)
	makePart({
		name = "WallFrontLeft",
		size = Vector3.new(6, 10, 0.8),
		cframe = CFrame.new(shopPos.X - 6, y + 5.4, shopPos.Z + 6.6),
		color = WOOD,
		material = Enum.Material.Wood,
		parent = model,
	})
	makePart({
		name = "WallFrontRight",
		size = Vector3.new(6, 10, 0.8),
		cframe = CFrame.new(shopPos.X + 6, y + 5.4, shopPos.Z + 6.6),
		color = WOOD,
		material = Enum.Material.Wood,
		parent = model,
	})
	makePart({
		name = "WallFrontTop",
		size = Vector3.new(6, 3, 0.8),
		cframe = CFrame.new(shopPos.X, y + 8.9, shopPos.Z + 6.6),
		color = WOOD,
		material = Enum.Material.Wood,
		parent = model,
	})

	-- Roof slabs
	makePart({
		name = "Roof",
		size = Vector3.new(20, 0.8, 16),
		cframe = CFrame.new(shopPos.X, y + 11.2, shopPos.Z) * CFrame.Angles(0, 0, math.rad(8)),
		color = ROOF,
		material = Enum.Material.Slate,
		parent = model,
	})

	-- Counter visible through the door.
	makePart({
		name = "Counter",
		size = Vector3.new(10, 3, 2),
		cframe = CFrame.new(shopPos.X, y + 2.1, shopPos.Z + 2),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
		parent = model,
	})

	-- Hanging sign
	local sign = makePart({
		name = "Sign",
		size = Vector3.new(10, 2.4, 0.4),
		cframe = CFrame.new(shopPos.X, y + 9.2, shopPos.Z + 7.4),
		color = SIGN_GREEN,
		material = Enum.Material.Wood,
		parent = model,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextSize = 42
	signLabel.TextColor3 = Color3.fromRGB(240, 248, 242)
	signLabel.Text = "Seed Store"
	signLabel.Parent = signGui

	-- Walk-up circle in front of the hut (toward the plots).
	local triggerRadius = 7
	local trigger = makePart({
		name = "TriggerPad",
		size = Vector3.new(triggerRadius * 2, 0.35, triggerRadius * 2),
		cframe = CFrame.new(shopPos.X, y + 0.18, shopPos.Z + 14),
		color = Color3.fromRGB(72, 196, 108),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		transparency = 0.45,
		canCollide = false,
		parent = model,
	})
	trigger:SetAttribute("TriggerRadius", triggerRadius)
	trigger:SetAttribute("ShopType", "Seed")
	CollectionService:AddTag(trigger, "SeedShopTrigger")

	local ring = makePart({
		name = "TriggerRing",
		size = Vector3.new(triggerRadius * 2 + 1.2, 0.2, triggerRadius * 2 + 1.2),
		cframe = trigger.CFrame,
		color = Color3.fromRGB(241, 213, 120),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		transparency = 0.65,
		canCollide = false,
		parent = model,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrowsePrompt"
	prompt.ActionText = "Browse"
	prompt.ObjectText = "Seeds"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = triggerRadius + 2
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- zone auto-opens; kept for future mobile fallback
	prompt.Parent = trigger

	local hint = Instance.new("BillboardGui")
	hint.Name = "Hint"
	hint.Size = UDim2.fromOffset(180, 36)
	hint.StudsOffset = Vector3.new(0, 4, 0)
	hint.AlwaysOnTop = true
	hint.Parent = trigger
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.fromScale(1, 1)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 16
	hintLabel.TextStrokeTransparency = 0.4
	hintLabel.TextColor3 = Color3.fromRGB(228, 238, 230)
	hintLabel.Text = "Stand on the circle"
	hintLabel.Parent = hint

	model.PrimaryPart = trigger
	return model
end

local function removeLegacyBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
end

function WorldService.init()
	removeLegacyBaseplate()

	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace

	buildTerrain(world)
	buildSeedShop(world)

	-- Anchor point used by other systems if needed.
	local marker = Instance.new("Part")
	marker.Name = "WorldOrigin"
	marker.Anchored = true
	marker.CanCollide = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = CFrame.new(plotCenterX(1), surfaceY(), GameConfig.Plots.Origin.Z)
	marker.Parent = world
end

return WorldService
