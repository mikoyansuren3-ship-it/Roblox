--!strict
-- Gives the player a visible shovel Tool that matches their current shovel tier,
-- so "Equipped" in the shop is backed by something you can actually see in the
-- hotbar / in-hand. Farming is driven by ProximityPrompts (press E), so this
-- tool is purely cosmetic and is built fully non-collidable + massless so it
-- never pushes the player or anything else around.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shovels = require(ReplicatedStorage:WaitForChild("Shared").Config.Shovels)
local DataManager = require(script.Parent.Parent.Data.DataManager)

local ShovelService = {}

local HANDLE_WOOD = Color3.fromRGB(120, 84, 52)

-- Blade tint per tier (handle stays wood); falls back to steel grey.
local HEAD_COLOR: { [string]: Color3 } = {
	Wooden = Color3.fromRGB(120, 84, 48),
	Copper = Color3.fromRGB(184, 115, 51),
	Iron = Color3.fromRGB(160, 162, 170),
	Gold = Color3.fromRGB(223, 184, 64),
	Diamond = Color3.fromRGB(120, 220, 235),
	Emerald = Color3.fromRGB(64, 200, 120),
}

-- Builds a shovel shaped like a real spade: a D-handle on top (a frame with a
-- handhold opening + two ears), a round shaft, and a rounded scoop blade with a
-- raised rim so the dip is clearly visible. Every part is welded to the Handle
-- and is CanCollide=false + Massless so it has no physical effect.
local function buildTool(shovelId: string): Tool
	local shovel = Shovels.ById[shovelId] or Shovels.Order[1]
	local headColor = HEAD_COLOR[shovel.id] or Color3.fromRGB(160, 160, 160)
	local bladeMat = (shovel.id == "Wooden") and Enum.Material.Wood or Enum.Material.Metal
	-- The recessed scoop face is shaded darker than the raised rim so the dip reads clearly.
	local dipColor = headColor:Lerp(Color3.fromRGB(0, 0, 0), 0.45)

	local tool = Instance.new("Tool")
	tool.Name = shovel.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = ("%d slot(s)  |  +%d%% luck"):format(shovel.slots, math.floor(shovel.luck * 100))
	tool:SetAttribute("ShovelId", shovel.id)

	-- Root shaft (thin; a round cylinder is layered over it for looks).
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.16, 1.8, 0.16)
	handle.Color = HANDLE_WOOD
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- Welds a cosmetic part to the handle. `cf` is a handle-local CFrame offset.
	local function attach(name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.Massless = true
		if shape then
			part.Shape = shape
		end
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = handle.CFrame * cf
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end

	-- Round shaft over the box root.
	attach("Shaft", CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.5, 0.24, 0.24), HANDLE_WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)

	-- D-handle on top: four bars frame a handhold opening, plus two ears.
	attach("GripTop", CFrame.new(0, 1.5, 0), Vector3.new(0.8, 0.24, 0.2), HANDLE_WOOD, Enum.Material.Wood)
	attach("GripBottom", CFrame.new(0, 1.0, 0), Vector3.new(0.8, 0.24, 0.2), HANDLE_WOOD, Enum.Material.Wood)
	attach("GripLeft", CFrame.new(-0.31, 1.25, 0), Vector3.new(0.18, 0.3, 0.2), HANDLE_WOOD, Enum.Material.Wood)
	attach("GripRight", CFrame.new(0.31, 1.25, 0), Vector3.new(0.18, 0.3, 0.2), HANDLE_WOOD, Enum.Material.Wood)
	attach("EarLeft", CFrame.new(-0.36, 1.68, 0) * CFrame.Angles(0, 0, math.rad(22)), Vector3.new(0.18, 0.34, 0.2), HANDLE_WOOD, Enum.Material.Wood)
	attach("EarRight", CFrame.new(0.36, 1.68, 0) * CFrame.Angles(0, 0, math.rad(-22)), Vector3.new(0.18, 0.34, 0.2), HANDLE_WOOD, Enum.Material.Wood)

	-- Spade blade: a flat face, a rounded bottom, and a raised rim on the sides +
	-- bottom so the scoop has an obvious dip.
	attach("BladeFace", CFrame.new(0, -1.45, 0), Vector3.new(0.78, 1.0, 0.08), dipColor, bladeMat)
	attach("BladeBottom", CFrame.new(0, -1.9, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.08, 0.78, 0.78), headColor, bladeMat, Enum.PartType.Cylinder)
	attach("RimLeft", CFrame.new(-0.4, -1.45, 0.16), Vector3.new(0.08, 1.08, 0.36), headColor, bladeMat)
	attach("RimRight", CFrame.new(0.4, -1.45, 0.16), Vector3.new(0.08, 1.08, 0.36), headColor, bladeMat)
	attach("RimBottom", CFrame.new(0, -1.95, 0.16), Vector3.new(0.72, 0.2, 0.36), headColor, bladeMat)

	-- Hold near the top; the 180° spin faces the scoop's dip forward (away from
	-- the player) instead of back into them.
	tool.Grip = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, math.rad(180), 0)

	return tool
end

local function clearExisting(player: Player)
	local function scrub(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ShovelId") ~= nil then
				child:Destroy()
			end
		end
	end
	scrub(player:FindFirstChildOfClass("Backpack"))
	scrub(player.Character)
end

-- Builds the shovel tool for the player's saved tier and drops it in the hotbar.
-- Re-equips only if a shovel was already out, so a fresh spawn leaves hands free
-- while an upgrade keeps it in-hand. Safe to call repeatedly.
function ShovelService.giveShovel(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Was a shovel already out? Preserve that across an upgrade, but a fresh
	-- spawn just drops it in the hotbar (hands free until the player selects it).
	local wasEquipped = false
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ShovelId") ~= nil then
			wasEquipped = true
			break
		end
	end

	local profile = DataManager.get(player.UserId)
	local shovelId = (profile and profile.data.Shovel) or "Wooden"

	clearExisting(player)
	local tool = buildTool(shovelId)
	tool.Parent = player:FindFirstChildOfClass("Backpack") or character
	if wasEquipped then
		humanoid:EquipTool(tool)
	end
end

return ShovelService
