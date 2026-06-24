--!strict
-- The core Forest loop: plant a seed in a slot, watch it grow, harvest it for
-- Coins plus a seed-drop roll (the gacha "reveal" moment).
--
-- Interaction is driven by server-side ProximityPrompts: prompt.Triggered fires
-- ON THE SERVER with the triggering player, so plant/harvest are inherently
-- server-authoritative — no client request to validate or spoof.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trees = require(Shared.Config.Trees)
local Shovels = require(Shared.Config.Shovels)
local Rarities = require(Shared.Config.Rarities)
local Roll = require(Shared.Util.Roll)
local Net = require(Shared.Net)

local DataManager = require(script.Parent.Parent.Data.DataManager)
local EconomyService = require(script.Parent.EconomyService)
local Replication = require(script.Parent.Replication)

local FarmingService = {}

-- Slot pad layout on the 48x48 base: 3 columns x 2 rows (local offsets).
local SLOT_OFFSETS: { Vector3 } = {
	Vector3.new(-15, 1, -9),
	Vector3.new(0, 1, -9),
	Vector3.new(15, 1, -9),
	Vector3.new(-15, 1, 9),
	Vector3.new(0, 1, 9),
	Vector3.new(15, 1, 9),
}

type SlotRuntime = {
	pad: BasePart,
	prompt: ProximityPrompt,
	label: TextLabel,
	plant: Model?,
	treeId: string?,
	growAt: number,
	grown: boolean,
	locked: boolean,
}

type PlotRuntime = {
	base: BasePart,
	slots: { [number]: SlotRuntime },
}

local runtime: { [number]: PlotRuntime } = {}
local selectedSeed: { [number]: string } = {} -- userId -> treeId to plant next

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function totalLuck(player: Player): number
	local profile = DataManager.get(player.UserId)
	if not profile then
		return 0
	end
	local shovel = Shovels.ById[profile.data.Shovel] or Shovels.Order[1]
	return shovel.luck
end

local function unlockedSlots(player: Player): number
	local profile = DataManager.get(player.UserId)
	if not profile then
		return 1
	end
	local shovel = Shovels.ById[profile.data.Shovel] or Shovels.Order[1]
	return shovel.slots
end

-- Each species maps to its own generated mesh template in
-- ReplicatedStorage/Shared/Assets/Trees. If a species mesh is missing we fall
-- back by rarity band, then to Default. Resolved lazily so a missing Assets
-- folder degrades gracefully to the part-based placeholder instead of erroring.
local SPECIES_MODEL: { [string]: string } = {
	Oak = "Default",
	Birch = "Birch",
	Pine = "Pine",
	Maple = "Maple",
	Cherry = "Cherry",
	Willow = "Willow",
	Redwood = "Redwood",
	GoldenOak = "GoldenOak",
	Rainbow = "Rainbow",
	Sequoia = "Sequoia",
	WorldTree = "WorldTree",
	Spirit = "Spirit",
	Bonsai = "Crystal",
}

local RARITY_FALLBACK: { [string]: string } = {
	Common = "Default",
	Uncommon = "Default",
	Rare = "Cherry",
	Epic = "Willow",
	Legendary = "GoldenOak",
	Mythic = "Sequoia",
	Secret = "Crystal",
}

local function getTreeTemplate(tree: Trees.Tree): BasePart?
	local assets = Shared:FindFirstChild("Assets")
	local trees = assets and assets:FindFirstChild("Trees")
	if not trees then
		return nil
	end
	local name = SPECIES_MODEL[tree.id] or RARITY_FALLBACK[tree.rarity] or "Default"
	local template = trees:FindFirstChild(name)
		or trees:FindFirstChild(RARITY_FALLBACK[tree.rarity] or "Default")
		or trees:FindFirstChild("Default")
	if template and template:IsA("BasePart") then
		return template
	end
	return nil
end

-- Fallback: simple part-based plant if the mesh templates aren't present.
local function buildPlaceholder(tree: Trees.Tree, cf: CFrame, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Plant"

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(102, 70, 48)
	trunk.Size = Vector3.new(1.2, 6 * scale, 1.2)
	trunk.CFrame = cf * CFrame.new(0, (6 * scale) / 2, 0)
	trunk.Parent = model

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.Material = Enum.Material.Grass
	leaves.Color = tree.leaf
	leaves.Size = Vector3.new(6, 6, 6) * scale
	leaves.CFrame = cf * CFrame.new(0, 6 * scale + (3 * scale) - 1, 0)
	leaves.Parent = model

	model.PrimaryPart = trunk
	return model
end

-- Build a plant from the generated mesh templates. `scale` 0..1 drives
-- sapling->grown. Grown rare trees (Legendary+) get a glow + sparkle accent.
local function buildPlant(tree: Trees.Tree, cf: CFrame, scale: number): Model
	local template = getTreeTemplate(tree)
	if not template then
		return buildPlaceholder(tree, cf, scale)
	end

	local model = Instance.new("Model")
	model.Name = "Plant"

	local mesh = template:Clone()
	mesh.Name = "Tree"
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.Size = template.Size * scale
	local height = mesh.Size.Y
	-- Pad is 1 stud tall, so its top sits 0.5 above pad center; seat the mesh on it.
	mesh.CFrame = cf * CFrame.new(0, 0.5 + height / 2, 0)
	mesh.Parent = model
	model.PrimaryPart = mesh

	if scale >= 0.99 and Rarities.rank(tree.rarity) >= Rarities.rank("Legendary") then
		local color = Rarities.Data[tree.rarity].color

		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 4
		light.Range = 18
		light.Parent = mesh

		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(color)
		sparkle.Rate = 14
		sparkle.Lifetime = NumberRange.new(1, 1.8)
		sparkle.Speed = NumberRange.new(1, 2.5)
		sparkle.Size = NumberSequence.new(0.45)
		sparkle.Transparency = NumberSequence.new(0.15)
		sparkle.LightEmission = 1
		sparkle.Parent = mesh
	end

	return model
end

local function clearPlant(slot: SlotRuntime)
	if slot.plant then
		slot.plant:Destroy()
		slot.plant = nil
	end
	slot.treeId = nil
	slot.grown = false
	slot.growAt = 0
end

-- Update a slot's pad, prompt, and label to reflect its current state.
local function refreshSlot(player: Player, index: number)
	local plot = runtime[player.UserId]
	if not plot then
		return
	end
	local slot = plot.slots[index]
	if not slot then
		return
	end

	slot.locked = index > unlockedSlots(player)

	if slot.locked then
		slot.pad.Color = Color3.fromRGB(70, 70, 70)
		slot.pad.Transparency = 0.4
		slot.prompt.Enabled = true
		slot.prompt.ActionText = "Locked"
		slot.prompt.ObjectText = "Upgrade shovel"
		slot.label.Text = ""
		return
	end

	slot.pad.Color = Color3.fromRGB(120, 90, 60)
	slot.pad.Transparency = 0

	if not slot.treeId then
		-- Empty: ready to plant.
		local seedId = selectedSeed[player.UserId] or "Oak"
		local tree = Trees.ById[seedId]
		slot.prompt.Enabled = true
		slot.prompt.ActionText = "Plant"
		slot.prompt.ObjectText = tree and tree.name or seedId
		slot.label.Text = ""
	elseif slot.grown then
		slot.prompt.Enabled = true
		slot.prompt.ActionText = "Harvest"
		local tree = Trees.ById[slot.treeId]
		slot.prompt.ObjectText = tree and tree.name or slot.treeId
		slot.label.Text = "Ready!"
		slot.label.TextColor3 = Color3.fromRGB(150, 240, 150)
	else
		-- Growing.
		slot.prompt.Enabled = false
		slot.label.TextColor3 = Color3.fromRGB(230, 230, 230)
	end
end

----------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------

local function plant(player: Player, index: number)
	local plot = runtime[player.UserId]
	local profile = DataManager.get(player.UserId)
	if not plot or not profile then
		return
	end
	local slot = plot.slots[index]
	if not slot or slot.locked or slot.treeId then
		return
	end

	local seedId = selectedSeed[player.UserId] or "Oak"
	local tree = Trees.ById[seedId]
	if not tree then
		return
	end

	if not EconomyService.consumeSeed(player, seedId) then
		Net.event("Notify"):FireClient(player, ("No %s seeds left!"):format(tree.name))
		return
	end

	local now = os.time()
	profile.data.Plots[index] = { seedId = seedId, plantedAt = now, grown = false }
	profile.data.Stats.TreesPlanted += 1

	slot.treeId = seedId
	slot.grown = false
	slot.growAt = now + tree.grow
	slot.plant = buildPlant(tree, slot.pad.CFrame, 0.25)
	slot.plant.Parent = slot.pad

	refreshSlot(player, index)
	Replication.replicate(player)
end

local function harvest(player: Player, index: number)
	local plot = runtime[player.UserId]
	local profile = DataManager.get(player.UserId)
	if not plot or not profile then
		return
	end
	local slot = plot.slots[index]
	if not slot or not slot.treeId or not slot.grown then
		return
	end

	local tree = Trees.ById[slot.treeId]
	if not tree then
		clearPlant(slot)
		return
	end

	-- Payout.
	EconomyService.addCoins(player, tree.value)
	profile.data.Stats.TreesHarvested += 1
	profile.data.TreeDex[tree.id] = true

	-- Seed-drop roll (the gacha reveal). Luck biases toward rarer tiers.
	local droppedSeedId: string? = nil
	local droppedRarity: Rarities.Rarity? = nil
	local rolledRarity = Roll.rarity(totalLuck(player))
	local candidates = Trees.ofRarity(rolledRarity)
	local dropped = Roll.choice(candidates)
	if dropped then
		droppedSeedId = dropped.id
		droppedRarity = dropped.rarity
		EconomyService.grantSeed(player, dropped.id, 1)
		profile.data.TreeDex[dropped.id] = true
	end

	-- Clear the slot.
	profile.data.Plots[index] = nil
	clearPlant(slot)
	refreshSlot(player, index)
	Replication.replicate(player)

	-- Reveal to the harvester.
	Net.event("Reveal"):FireClient(player, {
		treeId = tree.id,
		treeName = tree.name,
		rarity = tree.rarity,
		value = tree.value,
		dropSeedId = droppedSeedId,
		dropName = dropped and dropped.name or nil,
		dropRarity = droppedRarity,
	})

	-- Server-wide announce on a rare drop.
	if droppedRarity and Rarities.Data[droppedRarity].announce and dropped then
		Net.event("Notify"):FireAllClients(("%s found a %s %s seed!"):format(player.Name, droppedRarity, dropped.name))
	end
end

----------------------------------------------------------------------
-- Plot setup / teardown
----------------------------------------------------------------------

local function makeSlot(player: Player, plot: PlotRuntime, index: number)
	local pad = Instance.new("Part")
	pad.Name = "Slot_" .. index
	pad.Anchored = true
	pad.Size = Vector3.new(9, 1, 9)
	pad.CFrame = plot.base.CFrame * CFrame.new(SLOT_OFFSETS[index])
	pad.Material = Enum.Material.Ground
	pad.Color = Color3.fromRGB(120, 90, 60)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad:SetAttribute("SlotIndex", index)
	pad.Parent = plot.base.Parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Plant"
	prompt.ObjectText = "Seed"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Status"
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextStrokeTransparency = 0.4
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Text = ""
	label.Parent = billboard

	local slot: SlotRuntime = {
		pad = pad,
		prompt = prompt,
		label = label,
		plant = nil,
		treeId = nil,
		growAt = 0,
		grown = false,
		locked = false,
	}
	plot.slots[index] = slot

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		local s = plot.slots[index]
		if not s or s.locked then
			if s and s.locked then
				Net.event("Notify"):FireClient(player, "Upgrade your shovel to unlock this slot.")
			end
			return
		end
		if s.treeId and s.grown then
			harvest(player, index)
		elseif not s.treeId then
			plant(player, index)
		end
	end)
end

-- Called by PlayerService once the player's plot model exists.
function FarmingService.onPlotReady(player: Player, plotModel: Model)
	local base = plotModel:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		return
	end

	local plot: PlotRuntime = { base = base, slots = {} }
	runtime[player.UserId] = plot
	selectedSeed[player.UserId] = selectedSeed[player.UserId] or "Oak"

	for index = 1, Shovels.MaxSlots do
		makeSlot(player, plot, index)
	end

	-- Restore saved plantings.
	local profile = DataManager.get(player.UserId)
	if profile then
		for index, saved in profile.data.Plots do
			local tree = Trees.ById[saved.seedId or ""]
			local slot = plot.slots[index]
			if tree and slot then
				local growAt = saved.plantedAt + tree.grow
				local grown = saved.grown or os.time() >= growAt
				slot.treeId = tree.id
				slot.grown = grown
				slot.growAt = growAt
				slot.plant = buildPlant(tree, slot.pad.CFrame, grown and 1 or 0.25)
				slot.plant.Parent = slot.pad
			end
		end
	end

	for index = 1, Shovels.MaxSlots do
		refreshSlot(player, index)
	end
end

function FarmingService.releasePlot(player: Player)
	runtime[player.UserId] = nil
	selectedSeed[player.UserId] = nil
end

function FarmingService.setSelectedSeed(player: Player, treeId: string)
	if not Trees.ById[treeId] then
		return
	end
	selectedSeed[player.UserId] = treeId
	-- Refresh empty-slot prompt labels.
	local plot = runtime[player.UserId]
	if plot then
		for index, slot in plot.slots do
			if not slot.treeId then
				refreshSlot(player, index)
			end
		end
	end
end

-- Re-evaluate slot locks (e.g. after a shovel upgrade).
function FarmingService.refreshLocks(player: Player)
	local plot = runtime[player.UserId]
	if not plot then
		return
	end
	for index = 1, Shovels.MaxSlots do
		refreshSlot(player, index)
	end
end

----------------------------------------------------------------------
-- Growth loop
----------------------------------------------------------------------

function FarmingService.init()
	-- Seed selection from the client.
	Net.event("SelectSeed").OnServerEvent:Connect(function(player, treeId)
		if typeof(treeId) == "string" then
			FarmingService.setSelectedSeed(player, treeId)
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0

		local now = os.time()
		for userId, plot in runtime do
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				continue
			end
			for index, slot in plot.slots do
				if slot.treeId and not slot.grown then
					local remaining = slot.growAt - now
					if remaining <= 0 then
						-- Matured.
						slot.grown = true
						local profile = DataManager.get(userId)
						if profile and profile.data.Plots[index] then
							profile.data.Plots[index].grown = true
						end
						local tree = Trees.ById[slot.treeId]
						if tree and slot.plant then
							slot.plant:Destroy()
							slot.plant = buildPlant(tree, slot.pad.CFrame, 1)
							slot.plant.Parent = slot.pad
						end
						refreshSlot(player, index)
					else
						slot.label.Text = ("%ds"):format(remaining)
					end
				end
			end
		end
	end)
end

return FarmingService
