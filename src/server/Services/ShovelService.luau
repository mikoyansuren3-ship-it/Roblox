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

local HANDLE_WOOD = Color3.fromRGB(140, 100, 64)

-- Blade tint per tier (handle stays wood); falls back to steel grey.
local HEAD_COLOR: { [string]: Color3 } = {
	Wooden = Color3.fromRGB(120, 84, 48),
	Copper = Color3.fromRGB(184, 115, 51),
	Iron = Color3.fromRGB(160, 162, 170),
	Gold = Color3.fromRGB(223, 184, 64),
	Diamond = Color3.fromRGB(120, 220, 235),
	Emerald = Color3.fromRGB(64, 200, 120),
}

-- A small, hand-sized shovel: a short shaft with a T-grip on top and a flat
-- spade blade at the bottom whose tip curls forward into a shallow scoop (the
-- dip). Every part is welded to the Handle and CanCollide=false + Massless so it
-- has no physical effect on the player or world.
local function buildTool(shovelId: string): Tool
	local shovel = Shovels.ById[shovelId] or Shovels.Order[1]
	local headColor = HEAD_COLOR[shovel.id] or Color3.fromRGB(160, 160, 160)
	local bladeMat = (shovel.id == "Wooden") and Enum.Material.Wood or Enum.Material.Metal

	local tool = Instance.new("Tool")
	tool.Name = shovel.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = ("%d slot(s)  |  +%d%% luck"):format(shovel.slots, math.floor(shovel.luck * 100))
	tool:SetAttribute("ShovelId", shovel.id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.18, 2.6, 0.18)
	handle.Color = HANDLE_WOOD
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- Welds a cosmetic part to the handle. `cf` is a handle-local CFrame offset.
	local function attach(name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = handle.CFrame * cf
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end

	-- T-grip across the top of the shaft.
	attach("Grip", CFrame.new(0, 1.3, 0), Vector3.new(0.55, 0.16, 0.16), HANDLE_WOOD, Enum.Material.Wood)

	-- Flat spade blade hanging below the shaft.
	attach("Blade", CFrame.new(0, -1.72, 0), Vector3.new(0.82, 1.2, 0.08), headColor, bladeMat)
	-- Tip curled forward = the scoop / dip at the bottom of the blade.
	attach("BladeTip", CFrame.new(0, -2.26, 0.1) * CFrame.Angles(math.rad(32), 0, 0), Vector3.new(0.82, 0.34, 0.1), headColor, bladeMat)

	-- Translation-only grip: the idle pose already points the blade down-forward.
	tool.Grip = CFrame.new(0, 0.9, 0)

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
