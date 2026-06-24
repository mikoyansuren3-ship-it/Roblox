--!strict
-- Builds the shared overworld: a large cartoon-grass map, a central plaza, and
-- two open-air shop stalls (Seed + Shovel) with vendors and big neon trigger
-- pads. Plot allocation stays in PlotService; this only owns static map art.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local WorldService = {}

local WOOD = Color3.fromRGB(120, 84, 48)
local WOOD_DARK = Color3.fromRGB(86, 58, 34)
local ROOF = Color3.fromRGB(74, 52, 38)
local SKIN = Color3.fromRGB(236, 200, 162)
local PANTS = Color3.fromRGB(58, 64, 78)

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

----------------------------------------------------------------------
-- Terrain + hub plaza
----------------------------------------------------------------------

local function buildGround(world: Folder)
	local info = GameConfig.World.Terrain
	-- Clear any leftover smooth-terrain from older builds, then lay one big flat
	-- grass slab. A part (vs terrain fill) gives a clean low-poly cartoon look
	-- with no grass tufts to bury the ground trigger pads.
	Workspace.Terrain:Clear()
	makePart({
		name = "Ground",
		size = Vector3.new(info.Size.X, 4, info.Size.Z),
		cframe = CFrame.new(info.Center.X, GameConfig.World.SurfaceY - 2, info.Center.Z),
		color = info.GrassColor,
		material = Enum.Material.Grass,
		parent = world,
	})
end

local function buildHub(world: Folder)
	local hub = GameConfig.World.Hub
	local y = surfaceY()

	-- Stone plaza the two stalls sit on.
	makePart({
		name = "Plaza",
		size = Vector3.new(hub.PlazaSize.X, 0.5, hub.PlazaSize.Z),
		cframe = CFrame.new(hub.Center.X, y + 0.25, hub.Center.Z),
		color = hub.PlazaColor,
		material = Enum.Material.Cobblestone,
		parent = world,
	})

	-- Cobblestone spine paths leading north + south toward the plot rows.
	local rowSpacing = GameConfig.Plots.Grid.RowSpacing
	for _, dir in { 1, -1 } do
		makePart({
			name = "Path_" .. (dir == 1 and "N" or "S"),
			size = Vector3.new(18, 0.4, rowSpacing),
			cframe = CFrame.new(hub.Center.X, y + 0.3, hub.Center.Z + dir * (rowSpacing / 2)),
			color = Color3.fromRGB(150, 142, 128),
			material = Enum.Material.Cobblestone,
			parent = world,
		})
	end

	-- A safe spawn so players don't fall in the moment before they are pivoted
	-- to their plot on CharacterAdded.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(hub.Center.X, y + 0.75, hub.Center.Z + 18)
	spawn.Color = hub.PlazaColor
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world
	local deco = Instance.new("Decal")
	deco.Texture = "rbxasset://textures/SpawnLocation.png"
	deco.Face = Enum.NormalId.Top
	deco.Parent = spawn
end

----------------------------------------------------------------------
-- Shop stall (shared by Seed + Shovel)
----------------------------------------------------------------------

-- Builds a simple blocky vendor standing behind the counter, facing the front
-- (-Z in stall-local space). All parts anchored + non-collidable.
local function buildVendor(parent: Instance, baseCF: CFrame, shirt: Color3)
	local vendor = Instance.new("Model")
	vendor.Name = "Vendor"
	vendor.Parent = parent

	local function vp(name: string, size: Vector3, ox: number, oy: number, oz: number, color: Color3): BasePart
		return makePart({
			name = name,
			size = size,
			cframe = baseCF * CFrame.new(ox, oy, oz),
			color = color,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = vendor,
		})
	end

	vp("LegL", Vector3.new(1.3, 3, 1.3), -1, 1.5, 1.8, PANTS)
	vp("LegR", Vector3.new(1.3, 3, 1.3), 1, 1.5, 1.8, PANTS)
	vp("Torso", Vector3.new(3.4, 3.4, 1.7), 0, 4.7, 1.8, shirt)
	vp("ArmL", Vector3.new(1, 3.2, 1), -2.4, 4.6, 1.8, shirt)
	vp("ArmR", Vector3.new(1, 3.2, 1), 2.4, 4.6, 1.8, shirt)
	local head = vp("Head", Vector3.new(2, 2, 2), 0, 7.4, 1.8, SKIN)
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
end

local function buildSeedProps(parent: Instance, baseCF: CFrame, accent: Color3)
	-- Seed crate beside the stall.
	makePart({
		name = "SeedCrate",
		size = Vector3.new(3, 3, 3),
		cframe = baseCF * CFrame.new(-13.5, 1.5, -1),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	-- A pair of flower pots with bright blooms.
	for i, side in { -1, 1 } do
		local x = side == -1 and -13.5 or 13.5
		makePart({
			name = "Pot" .. i,
			size = Vector3.new(2.2, 2, 2.2),
			cframe = baseCF * CFrame.new(x, 1, -4),
			color = Color3.fromRGB(168, 96, 64),
			material = Enum.Material.Slate,
			shape = Enum.PartType.Cylinder,
			parent = parent,
		})
		makePart({
			name = "Bloom" .. i,
			size = Vector3.new(2.4, 2.4, 2.4),
			cframe = baseCF * CFrame.new(x, 3, -4),
			color = accent,
			material = Enum.Material.Grass,
			shape = Enum.PartType.Ball,
			parent = parent,
		})
	end
end

local function buildShovelProps(parent: Instance, baseCF: CFrame, accent: Color3)
	-- Stacked crates beside the stall.
	makePart({
		name = "Crate1",
		size = Vector3.new(3, 3, 3),
		cframe = baseCF * CFrame.new(13.5, 1.5, -1),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	makePart({
		name = "Crate2",
		size = Vector3.new(2.6, 2.6, 2.6),
		cframe = baseCF * CFrame.new(13.5, 4.1, -1),
		color = WOOD_DARK,
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	-- Shovel rack: a board with a couple of leaning shovels.
	makePart({
		name = "Rack",
		size = Vector3.new(0.5, 6, 5),
		cframe = baseCF * CFrame.new(-13.5, 3, -2),
		color = WOOD_DARK,
		material = Enum.Material.Wood,
		parent = parent,
	})
	for i = -1, 1, 2 do
		makePart({
			name = "ShovelHandle" .. i,
			size = Vector3.new(0.4, 5, 0.4),
			cframe = baseCF * CFrame.new(-13, 3.2, -2 + i * 1.4) * CFrame.Angles(math.rad(8), 0, 0),
			color = Color3.fromRGB(150, 110, 70),
			material = Enum.Material.Wood,
			parent = parent,
		})
		makePart({
			name = "ShovelHead" .. i,
			size = Vector3.new(1.4, 1.6, 0.3),
			cframe = baseCF * CFrame.new(-13, 0.9, -2 + i * 1.4),
			color = accent,
			material = Enum.Material.Metal,
			parent = parent,
		})
	end
end

-- Builds one open-air stall. shopType is "Seed" or "Shovel"; theme comes from
-- GameConfig.World.Shops[shopType]. The stall front is open (-Z); back + sides
-- are solid and the counter blocks entry, so the player can't walk inside.
local function buildShopStall(world: Folder, shopType: string): Model
	local cfg = GameConfig.World.Shops[shopType]
	local hub = GameConfig.World.Hub.Center
	local baseCF = CFrame.new(hub.X + cfg.Offset.X, surfaceY(), hub.Z + cfg.Offset.Z)

	local model = Instance.new("Model")
	model.Name = shopType .. "Shop"
	model.Parent = world

	local function part(name: string, size: Vector3, ox: number, oy: number, oz: number, color: Color3, material: Enum.Material): BasePart
		return makePart({
			name = name,
			size = size,
			cframe = baseCF * CFrame.new(ox, oy, oz),
			color = color,
			material = material,
			parent = model,
		})
	end

	part("Floor", Vector3.new(22, 0.6, 12), 0, 0.3, 0, WOOD_DARK, Enum.Material.WoodPlanks)
	part("WallBack", Vector3.new(22, 9, 0.6), 0, 4.8, 5.7, WOOD, Enum.Material.Wood)
	part("WallLeft", Vector3.new(0.6, 9, 12), -10.7, 4.8, 0, WOOD, Enum.Material.Wood)
	part("WallRight", Vector3.new(0.6, 9, 12), 10.7, 4.8, 0, WOOD, Enum.Material.Wood)

	-- Corner posts.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part("Post", Vector3.new(1, 9.8, 1), sx * 10.4, 4.9, sz * 5.4, WOOD_DARK, Enum.Material.Wood)
		end
	end

	part("Roof", Vector3.new(24, 0.7, 14), 0, 9.7, 0, ROOF, Enum.Material.WoodPlanks)

	-- Counter (blocks the open front so the stall is not enterable).
	part("Counter", Vector3.new(19, 3, 1.8), 0, 1.5, -4.6, WOOD_DARK, Enum.Material.WoodPlanks)
	part("CounterTop", Vector3.new(19.8, 0.5, 2.4), 0, 3.05, -4.6, WOOD, Enum.Material.Wood)

	-- Scalloped striped awning across the front edge.
	for i = 0, 9 do
		local x = -10 + i * 2.2 + 1.1
		local color = (i % 2 == 0) and cfg.AwningA or cfg.AwningB
		makePart({
			name = "Awning" .. i,
			size = Vector3.new(2.3, 0.3, 3.6),
			cframe = baseCF * CFrame.new(x, 8.7, -6.7) * CFrame.Angles(math.rad(-30), 0, 0),
			color = color,
			material = Enum.Material.SmoothPlastic,
			parent = model,
		})
	end

	-- 3D sign on the roof.
	part("SignPostL", Vector3.new(0.6, 2.4, 0.6), -6, 10.9, -5.4, WOOD_DARK, Enum.Material.Wood)
	part("SignPostR", Vector3.new(0.6, 2.4, 0.6), 6, 10.9, -5.4, WOOD_DARK, Enum.Material.Wood)
	local sign = part("Sign", Vector3.new(16, 3.2, 0.7), 0, 12.3, -5.4, cfg.SignColor, Enum.Material.Wood)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.LuckiestGuy
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(248, 248, 240)
	signLabel.TextStrokeTransparency = 0.4
	signLabel.Text = cfg.Sign
	signLabel.Parent = signGui

	buildVendor(model, baseCF, cfg.VendorShirt)
	if shopType == "Seed" then
		buildSeedProps(model, baseCF, cfg.Accent)
	else
		buildShovelProps(model, baseCF, cfg.Accent)
	end

	-- Big flat neon trigger pad in front of the stall.
	local radius = GameConfig.World.TriggerRadius
	local trigger = makePart({
		name = "TriggerPad",
		size = Vector3.new(0.5, radius * 2, radius * 2),
		cframe = baseCF * CFrame.new(0, 0.4, -GameConfig.World.TriggerForward) * CFrame.Angles(0, 0, math.rad(90)),
		color = cfg.TriggerColor,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		transparency = 0.3,
		canCollide = false,
		parent = model,
	})
	trigger:SetAttribute("ShopType", shopType)
	trigger:SetAttribute("TriggerRadius", radius)
	CollectionService:AddTag(trigger, "ShopTrigger")

	-- Faint outer ring for a bit of polish.
	makePart({
		name = "TriggerRing",
		size = Vector3.new(0.4, radius * 2 + 2, radius * 2 + 2),
		cframe = baseCF * CFrame.new(0, 0.3, -GameConfig.World.TriggerForward) * CFrame.Angles(0, 0, math.rad(90)),
		color = cfg.TriggerColor,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		transparency = 0.7,
		canCollide = false,
		parent = model,
	})

	-- Backup interaction: press E on the pad if the auto-zone ever misses.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrowsePrompt"
	prompt.ActionText = "Browse"
	prompt.ObjectText = cfg.Sign
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = radius
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = trigger

	model.PrimaryPart = trigger
	return model
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

local function removeLegacyBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
end

-- Landing CFrame for a teleport: just above the center of the shop's neon pad.
function WorldService.getShopLanding(shopType: string): CFrame?
	local world = Workspace:FindFirstChild("World")
	local shop = world and world:FindFirstChild(shopType .. "Shop")
	local pad = shop and shop:FindFirstChild("TriggerPad")
	if pad and pad:IsA("BasePart") then
		return CFrame.new(pad.Position + Vector3.new(0, 4, 0))
	end
	return nil
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

	buildGround(world)
	buildHub(world)
	buildShopStall(world, "Seed")
	buildShopStall(world, "Shovel")

	-- Anchor point used by other systems if needed.
	local marker = Instance.new("Part")
	marker.Name = "WorldOrigin"
	marker.Anchored = true
	marker.CanCollide = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = CFrame.new(GameConfig.World.Hub.Center.X, surfaceY(), GameConfig.World.Hub.Center.Z)
	marker.Parent = world
end

return WorldService
