--!strict
-- Client HUD for the Forest loop: coins, seed bar, shop teleports + stores,
-- Tree Dex, rare-reveal moment, and toast notifications. Server stays
-- authoritative; this only sends intent and renders snapshots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Trees = require(Shared.Config.Trees)
local Shovels = require(Shared.Config.Shovels)
local Rarities = require(Shared.Config.Rarities)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GREEN_DARK = Color3.fromRGB(18, 28, 22)
local GREEN_PANEL = Color3.fromRGB(26, 40, 32)
local GOLD = Color3.fromRGB(241, 213, 120)
local TEXT = Color3.fromRGB(228, 238, 230)
local SEED_GREEN = Color3.fromRGB(54, 122, 78)
local SHOVEL_BROWN = Color3.fromRGB(110, 80, 48)

local state = { data = nil }
local selectedSeedId = "Oak"
local knownDex: { [string]: boolean } = {}
local dexInitialized = false

-- Forward declarations for things referenced before they're defined.
local renderSeeds
local renderTreeDex
local renderShovelShop
local toast
local openShop
local seedShopFrame: Frame
local shovelShopFrame: Frame
local dexFrame: Frame

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

local function rarityColor(rarity: string): Color3
	local info = Rarities.Data[rarity]
	return info and info.color or TEXT
end

local function formatDuration(seconds: number): string
	if seconds >= 3600 then
		return ("%.1fh"):format(seconds / 3600)
	end
	if seconds >= 60 then
		return ("%.0fm"):format(seconds / 60)
	end
	return ("%ds"):format(seconds)
end

local function countDiscovered(dex: { [string]: boolean }?): number
	local total = 0
	if not dex then
		return 0
	end
	for _, tree in Trees.List do
		if dex[tree.id] then
			total += 1
		end
	end
	return total
end

local function handleDexDiscoveries(data)
	local dex = data.TreeDex or {}
	if not dexInitialized then
		for id in dex do
			knownDex[id] = true
		end
		dexInitialized = true
		return
	end
	for _, tree in Trees.List do
		if dex[tree.id] and not knownDex[tree.id] then
			knownDex[tree.id] = true
			toast(("New discovery: %s"):format(tree.name))
		end
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "RAP_HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

----------------------------------------------------------------------
-- Coins + seed bar
----------------------------------------------------------------------

local coinsPill = Instance.new("Frame")
coinsPill.Name = "Coins"
coinsPill.Position = UDim2.fromOffset(16, 16)
coinsPill.Size = UDim2.fromOffset(180, 44)
coinsPill.BackgroundColor3 = GREEN_DARK
coinsPill.BackgroundTransparency = 0.1
coinsPill.BorderSizePixel = 0
coinsPill.Parent = gui
corner(coinsPill, 12)

local coinsLabel = Instance.new("TextLabel")
coinsLabel.BackgroundTransparency = 1
coinsLabel.Size = UDim2.fromScale(1, 1)
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.TextSize = 20
coinsLabel.TextColor3 = GOLD
coinsLabel.Text = "0"
coinsLabel.Parent = coinsPill
padding(coinsLabel, 6)

local seedBar = Instance.new("Frame")
seedBar.Name = "SeedBar"
seedBar.AnchorPoint = Vector2.new(0.5, 1)
seedBar.Position = UDim2.new(0.5, 0, 1, -84) -- sits above the Roblox tool hotbar
seedBar.Size = UDim2.fromOffset(560, 64)
seedBar.BackgroundColor3 = GREEN_DARK
seedBar.BackgroundTransparency = 0.1
seedBar.BorderSizePixel = 0
seedBar.Parent = gui
corner(seedBar, 14)
padding(seedBar, 8)

local seedLayout = Instance.new("UIListLayout")
seedLayout.FillDirection = Enum.FillDirection.Horizontal
seedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
seedLayout.VerticalAlignment = Enum.VerticalAlignment.Center
seedLayout.Padding = UDim.new(0, 6)
seedLayout.SortOrder = Enum.SortOrder.LayoutOrder
seedLayout.Parent = seedBar

local function selectSeed(treeId: string)
	selectedSeedId = treeId
	Net.event("SelectSeed"):FireServer(treeId)
	if state.data then
		renderSeeds(state.data)
	end
end

renderSeeds = function(data)
	for _, child in seedBar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local order = 0
	for _, tree in Trees.List do
		local count = data.Seeds[tree.id]
		if count and count > 0 then
			order += 1
			local btn = Instance.new("TextButton")
			btn.Name = tree.id
			btn.LayoutOrder = order
			btn.Size = UDim2.fromOffset(96, 48)
			btn.BackgroundColor3 = (tree.id == selectedSeedId) and GREEN_PANEL or GREEN_DARK
			btn.AutoButtonColor = true
			btn.BorderSizePixel = 0
			btn.Text = ("%s\nx%d"):format(tree.name, count)
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = 12
			btn.TextColor3 = TEXT
			btn.Parent = seedBar
			corner(btn, 10)

			local stripe = Instance.new("Frame")
			stripe.Size = UDim2.new(1, 0, 0, 3)
			stripe.Position = UDim2.fromScale(0, 1)
			stripe.AnchorPoint = Vector2.new(0, 1)
			stripe.BackgroundColor3 = rarityColor(tree.rarity)
			stripe.BorderSizePixel = 0
			stripe.Parent = btn
			corner(stripe, 2)

			if tree.id == selectedSeedId then
				local ring = Instance.new("UIStroke")
				ring.Color = GOLD
				ring.Thickness = 2
				ring.Parent = btn
			end

			btn.Activated:Connect(function()
				selectSeed(tree.id)
			end)
		end
	end
end

----------------------------------------------------------------------
-- Shop + Dex modals
----------------------------------------------------------------------

local function makeModal(name: string, title: string, height: number): (Frame, TextButton, ScrollingFrame)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(420, height)
	frame.BackgroundColor3 = GREEN_DARK
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	corner(frame, 16)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(16, 12)
	titleLabel.Size = UDim2.new(1, -32, 0, 28)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = TEXT
	titleLabel.Text = title
	titleLabel.Parent = frame

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	close.BorderSizePixel = 0
	close.Text = "X"
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = TEXT
	close.Parent = frame
	corner(close, 8)
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(16, 52)
	list.Size = UDim2.new(1, -32, 1, -68)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	return frame, close, list
end

local shovelList: ScrollingFrame
local seedList: ScrollingFrame
do
	local frame, _, list = makeModal("ShovelShop", "Shovel Store", 460)
	shovelShopFrame = frame
	shovelList = list
end
do
	local frame, _, list = makeModal("SeedShop", "Tree Seed Store", 460)
	seedShopFrame = frame
	seedList = list
end

-- Tree Dex frame.
dexFrame = Instance.new("Frame")
dexFrame.Name = "TreeDex"
dexFrame.AnchorPoint = Vector2.new(0.5, 0.5)
dexFrame.Position = UDim2.fromScale(0.5, 0.5)
dexFrame.Size = UDim2.fromOffset(540, 500)
dexFrame.BackgroundColor3 = GREEN_DARK
dexFrame.BorderSizePixel = 0
dexFrame.Visible = false
dexFrame.Parent = gui
corner(dexFrame, 16)

local dexTitle = Instance.new("TextLabel")
dexTitle.BackgroundTransparency = 1
dexTitle.Position = UDim2.fromOffset(16, 12)
dexTitle.Size = UDim2.new(1, -32, 0, 28)
dexTitle.Font = Enum.Font.GothamBold
dexTitle.TextSize = 22
dexTitle.TextXAlignment = Enum.TextXAlignment.Left
dexTitle.TextColor3 = TEXT
dexTitle.Text = "Tree Dex"
dexTitle.Parent = dexFrame

local dexProgress = Instance.new("TextLabel")
dexProgress.Name = "Progress"
dexProgress.BackgroundTransparency = 1
dexProgress.Position = UDim2.fromOffset(16, 40)
dexProgress.Size = UDim2.new(1, -32, 0, 20)
dexProgress.Font = Enum.Font.GothamMedium
dexProgress.TextSize = 14
dexProgress.TextXAlignment = Enum.TextXAlignment.Left
dexProgress.TextColor3 = GOLD
dexProgress.Text = "0 / 13 discovered"
dexProgress.Parent = dexFrame

local dexClose = Instance.new("TextButton")
dexClose.AnchorPoint = Vector2.new(1, 0)
dexClose.Position = UDim2.new(1, -12, 0, 12)
dexClose.Size = UDim2.fromOffset(28, 28)
dexClose.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
dexClose.BorderSizePixel = 0
dexClose.Text = "X"
dexClose.Font = Enum.Font.GothamBold
dexClose.TextSize = 16
dexClose.TextColor3 = TEXT
dexClose.Parent = dexFrame
corner(dexClose, 8)

local dexList = Instance.new("ScrollingFrame")
dexList.Name = "List"
dexList.Position = UDim2.fromOffset(16, 72)
dexList.Size = UDim2.new(1, -32, 1, -88)
dexList.BackgroundTransparency = 1
dexList.BorderSizePixel = 0
dexList.ScrollBarThickness = 4
dexList.CanvasSize = UDim2.new()
dexList.AutomaticCanvasSize = Enum.AutomaticSize.Y
dexList.Parent = dexFrame

local dexGrid = Instance.new("UIGridLayout")
dexGrid.CellSize = UDim2.fromOffset(156, 118)
dexGrid.CellPadding = UDim2.fromOffset(8, 8)
dexGrid.SortOrder = Enum.SortOrder.LayoutOrder
dexGrid.Parent = dexList

-- Now that all three modals exist, closeModals can capture them safely.
local function closeModals(except: Frame?)
	if dexFrame ~= except then
		dexFrame.Visible = false
	end
	if shovelShopFrame ~= except then
		shovelShopFrame.Visible = false
	end
	if seedShopFrame ~= except then
		seedShopFrame.Visible = false
	end
end

local function openSeedShop()
	if seedShopFrame.Visible then
		return
	end
	closeModals(seedShopFrame)
	seedShopFrame.Visible = true
end

local function openShovelShop()
	if shovelShopFrame.Visible then
		return
	end
	closeModals(shovelShopFrame)
	shovelShopFrame.Visible = true
end

openShop = function(shopType: string)
	if shopType == "Seed" then
		openSeedShop()
	elseif shopType == "Shovel" then
		openShovelShop()
	end
end

----------------------------------------------------------------------
-- Shop contents
----------------------------------------------------------------------

type ShovelRow = {
	row: Frame,
	action: TextLabel,
	buy: TextButton,
}

local shovelRows: { ShovelRow } = {}

local function buildShovelShopRows()
	for order, shovel in Shovels.Order do
		local row = Instance.new("Frame")
		row.Name = shovel.id
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 58)
		row.BackgroundColor3 = GREEN_PANEL
		row.BorderSizePixel = 0
		row.Parent = shovelList
		corner(row, 8)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(10, 6)
		name.Size = UDim2.new(0.55, 0, 0, 20)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = TEXT
		name.Text = shovel.name
		name.Parent = row

		local stats = Instance.new("TextLabel")
		stats.BackgroundTransparency = 1
		stats.Position = UDim2.fromOffset(10, 28)
		stats.Size = UDim2.new(0.55, 0, 0, 22)
		stats.Font = Enum.Font.Gotham
		stats.TextSize = 11
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextColor3 = Color3.fromRGB(170, 182, 176)
		stats.Text = ("%d slots  |  +%d%% luck"):format(shovel.slots, math.floor(shovel.luck * 100))
		stats.Parent = row

		local action = Instance.new("TextLabel")
		action.Name = "Action"
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -8, 0.5, 0)
		action.Size = UDim2.fromOffset(118, 32)
		action.BackgroundTransparency = 1
		action.Font = Enum.Font.GothamMedium
		action.TextSize = 12
		action.TextColor3 = Color3.fromRGB(140, 150, 145)
		action.Text = ""
		action.Parent = row

		local buy = Instance.new("TextButton")
		buy.Name = "Buy"
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -8, 0.5, 0)
		buy.Size = UDim2.fromOffset(118, 32)
		buy.BackgroundColor3 = SHOVEL_BROWN
		buy.BorderSizePixel = 0
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 12
		buy.TextColor3 = TEXT
		buy.Visible = false
		buy.Parent = row
		corner(buy, 8)
		buy.Activated:Connect(function()
			local ok, msg = Net.func("BuyShovel"):InvokeServer()
			if not ok and typeof(msg) == "string" then
				toast(msg)
			end
		end)

		table.insert(shovelRows, { row = row, action = action, buy = buy })
	end
end

renderShovelShop = function(data)
	local currentIndex = Shovels.indexOf(data.Shovel)
	for index, entry in shovelRows do
		local shovel = Shovels.Order[index]
		local ring = entry.row:FindFirstChildOfClass("UIStroke")
		if ring then
			ring:Destroy()
		end

		if index < currentIndex then
			entry.action.Visible = true
			entry.action.Text = "Owned"
			entry.action.TextColor3 = Color3.fromRGB(140, 150, 145)
			entry.buy.Visible = false
			entry.row.BackgroundColor3 = GREEN_PANEL
		elseif index == currentIndex then
			entry.action.Visible = true
			entry.action.Text = "Equipped"
			entry.action.TextColor3 = GOLD
			entry.buy.Visible = false
			entry.row.BackgroundColor3 = Color3.fromRGB(34, 48, 40)
			local equipped = Instance.new("UIStroke")
			equipped.Color = GOLD
			equipped.Thickness = 2
			equipped.Parent = entry.row
		elseif index == currentIndex + 1 then
			entry.action.Visible = false
			entry.buy.Visible = true
			if shovel.cost <= 0 then
				entry.buy.Text = "Free"
			else
				entry.buy.Text = ("Upgrade  %s"):format(comma(shovel.cost))
			end
			entry.row.BackgroundColor3 = GREEN_PANEL
		else
			entry.action.Visible = true
			entry.action.Text = "Locked"
			entry.action.TextColor3 = Color3.fromRGB(110, 114, 122)
			entry.buy.Visible = false
			entry.row.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
		end
	end
end

local function buildSeedShopRows()
	local order = 0
	for _, tree in Trees.List do
		if tree.seedCost then
			order += 1
			local row = Instance.new("Frame")
			row.LayoutOrder = order
			row.Size = UDim2.new(1, 0, 0, 44)
			row.BackgroundColor3 = GREEN_PANEL
			row.BorderSizePixel = 0
			row.Parent = seedList
			corner(row, 8)

			local stripe = Instance.new("Frame")
			stripe.Size = UDim2.new(0, 4, 1, 0)
			stripe.BackgroundColor3 = rarityColor(tree.rarity)
			stripe.BorderSizePixel = 0
			stripe.Parent = row
			corner(stripe, 2)

			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.fromOffset(14, 0)
			name.Size = UDim2.new(0.58, 0, 1, 0)
			name.Font = Enum.Font.GothamMedium
			name.TextSize = 14
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = rarityColor(tree.rarity)
			name.Text = ("%s  (%s)"):format(tree.name, tree.rarity)
			name.Parent = row

			local buy = Instance.new("TextButton")
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.new(1, -8, 0.5, 0)
			buy.Size = UDim2.fromOffset(120, 32)
			buy.BackgroundColor3 = SEED_GREEN
			buy.BorderSizePixel = 0
			buy.Font = Enum.Font.GothamBold
			buy.TextSize = 13
			buy.TextColor3 = TEXT
			buy.Text = ("Buy  %s"):format(comma(tree.seedCost))
			buy.Parent = row
			corner(buy, 8)

			buy.Activated:Connect(function()
				local ok, msg = Net.func("BuySeed"):InvokeServer(tree.id, 1)
				if not ok and typeof(msg) == "string" then
					toast(msg)
				end
			end)
		end
	end
end

----------------------------------------------------------------------
-- HUD buttons: shop teleports (right) + Tree Dex (left)
----------------------------------------------------------------------

local teleportStrip = Instance.new("Frame")
teleportStrip.Name = "ShopTeleports"
teleportStrip.AnchorPoint = Vector2.new(1, 0)
teleportStrip.Position = UDim2.new(1, -16, 0, 16)
teleportStrip.Size = UDim2.fromOffset(150, 100)
teleportStrip.BackgroundTransparency = 1
teleportStrip.Parent = gui

local stripLayout = Instance.new("UIListLayout")
stripLayout.FillDirection = Enum.FillDirection.Vertical
stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
stripLayout.Padding = UDim.new(0, 8)
stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
stripLayout.Parent = teleportStrip

local function makeTeleportButton(text: string, color: Color3, shopType: string, order: number)
	local btn = Instance.new("TextButton")
	btn.Name = shopType .. "Teleport"
	btn.LayoutOrder = order
	btn.Size = UDim2.fromOffset(150, 44)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = TEXT
	btn.Text = text
	btn.Parent = teleportStrip
	corner(btn, 12)

	btn.Activated:Connect(function()
		local ok, success = pcall(function()
			return Net.func("TeleportToShop"):InvokeServer(shopType)
		end)
		-- ShopOpened from the server also opens it; opening here keeps it snappy.
		if ok and success then
			openShop(shopType)
		end
	end)
	return btn
end

makeTeleportButton("Seed Shop", SEED_GREEN, "Seed", 1)
makeTeleportButton("Shovel Shop", SHOVEL_BROWN, "Shovel", 2)

local dexButton = Instance.new("TextButton")
dexButton.Name = "TreeDexButton"
dexButton.Position = UDim2.fromOffset(16, 68)
dexButton.Size = UDim2.fromOffset(120, 44)
dexButton.BackgroundColor3 = Color3.fromRGB(72, 98, 132)
dexButton.BorderSizePixel = 0
dexButton.Text = "Tree Dex"
dexButton.Font = Enum.Font.GothamBold
dexButton.TextSize = 18
dexButton.TextColor3 = TEXT
dexButton.Parent = gui
corner(dexButton, 12)

renderTreeDex = function(data)
	local dex = data.TreeDex or {}
	local discovered = countDiscovered(dex)
	dexProgress.Text = ("%d / %d discovered"):format(discovered, #Trees.List)

	for _, child in dexList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for order, tree in Trees.List do
		local found = dex[tree.id] == true
		local card = Instance.new("Frame")
		card.Name = tree.id
		card.LayoutOrder = order
		card.BackgroundColor3 = found and GREEN_PANEL or Color3.fromRGB(22, 24, 28)
		card.BorderSizePixel = 0
		card.Parent = dexList
		corner(card, 10)

		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(1, 0, 0, 4)
		stripe.BackgroundColor3 = found and rarityColor(tree.rarity) or Color3.fromRGB(70, 74, 82)
		stripe.BorderSizePixel = 0
		stripe.Parent = card
		corner(stripe, 2)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(8, 10)
		name.Size = UDim2.new(1, -16, 0, 22)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = found and rarityColor(tree.rarity) or Color3.fromRGB(110, 114, 122)
		name.Text = found and tree.name or "???"
		name.Parent = card

		local rarity = Instance.new("TextLabel")
		rarity.BackgroundTransparency = 1
		rarity.Position = UDim2.fromOffset(8, 32)
		rarity.Size = UDim2.new(1, -16, 0, 18)
		rarity.Font = Enum.Font.GothamMedium
		rarity.TextSize = 12
		rarity.TextXAlignment = Enum.TextXAlignment.Left
		rarity.TextColor3 = found and TEXT or Color3.fromRGB(90, 94, 102)
		rarity.Text = found and tree.rarity or "Unknown"
		rarity.Parent = card

		local stats = Instance.new("TextLabel")
		stats.BackgroundTransparency = 1
		stats.Position = UDim2.fromOffset(8, 54)
		stats.Size = UDim2.new(1, -16, 0, 36)
		stats.Font = Enum.Font.Gotham
		stats.TextSize = 11
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextYAlignment = Enum.TextYAlignment.Top
		stats.TextWrapped = true
		stats.TextColor3 = found and Color3.fromRGB(170, 182, 176) or Color3.fromRGB(70, 74, 82)
		if found then
			stats.Text = ("Grow: %s\nValue: %s coins"):format(formatDuration(tree.grow), comma(tree.value))
		else
			stats.Text = "Harvest or find a seed drop to discover."
		end
		stats.Parent = card

		if found then
			local ring = Instance.new("UIStroke")
			ring.Color = rarityColor(tree.rarity)
			ring.Thickness = 1
			ring.Transparency = 0.35
			ring.Parent = card
		end
	end
end

dexButton.Activated:Connect(function()
	local opening = not dexFrame.Visible
	closeModals(if opening then dexFrame else nil)
	dexFrame.Visible = opening
end)
dexClose.Activated:Connect(function()
	dexFrame.Visible = false
end)

----------------------------------------------------------------------
-- Toast + reveal
----------------------------------------------------------------------

toast = function(text)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -156) -- above the seed bar + hotbar
	label.Size = UDim2.fromOffset(440, 36)
	label.BackgroundColor3 = GREEN_DARK
	label.BackgroundTransparency = 0.1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 15
	label.TextColor3 = TEXT
	label.Text = text
	label.Parent = gui
	corner(label, 10)

	task.spawn(function()
		task.wait(2.5)
		local tween = TweenService:Create(label, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

local function reveal(payload)
	if not payload then
		return
	end
	local rarity = payload.dropRarity or payload.rarity
	local color = rarityColor(rarity)

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(320, 150)
	card.BackgroundColor3 = GREEN_DARK
	card.BorderSizePixel = 0
	card.Parent = gui
	corner(card, 16)

	local ring = Instance.new("UIStroke")
	ring.Color = color
	ring.Thickness = 3
	ring.Parent = card

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(0, 14)
	header.Size = UDim2.new(1, 0, 0, 22)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 18
	header.TextColor3 = GOLD
	header.Text = ("Harvested %s  (+%s)"):format(payload.treeName or "Tree", comma(payload.value or 0))
	header.Parent = card

	local big = Instance.new("TextLabel")
	big.BackgroundTransparency = 1
	big.Position = UDim2.fromOffset(0, 48)
	big.Size = UDim2.new(1, 0, 0, 44)
	big.Font = Enum.Font.GothamBold
	big.TextSize = 26
	big.TextColor3 = color
	if payload.dropName then
		big.Text = ("%s Seed!"):format(payload.dropName)
	else
		big.Text = "No seed dropped"
	end
	big.Parent = card

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 100)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.Font = Enum.Font.GothamMedium
	sub.TextSize = 16
	sub.TextColor3 = color
	sub.Text = rarity and (rarity:upper()) or ""
	sub.Parent = card

	card.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(320, 150),
	}):Play()

	local hold = 1.4
	if rarity == "Mythic" or rarity == "Secret" or rarity == "Legendary" then
		hold = 2.6
	end
	task.spawn(function()
		task.wait(hold)
		local fade = TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		for _, d in card:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		fade:Play()
		fade.Completed:Wait()
		card:Destroy()
	end)
end

----------------------------------------------------------------------
-- Shop zone detection (unified ShopTrigger pads)
----------------------------------------------------------------------

-- World-space XZ distance from each tagged pad's center; robust regardless of
-- the pad's part shape/orientation (the old local-space check was fragile).
local insideState: { [BasePart]: boolean } = {}

local function watchTrigger(inst: Instance)
	if inst:IsA("BasePart") then
		insideState[inst] = false
	end
end

for _, t in CollectionService:GetTagged("ShopTrigger") do
	watchTrigger(t)
end
CollectionService:GetInstanceAddedSignal("ShopTrigger"):Connect(watchTrigger)
CollectionService:GetInstanceRemovedSignal("ShopTrigger"):Connect(function(inst)
	insideState[inst :: BasePart] = nil
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		for trigger in insideState do
			insideState[trigger] = false
		end
		return
	end
	local pos = hrp.Position
	for trigger, wasInside in insideState do
		if trigger.Parent then
			local radius = trigger:GetAttribute("TriggerRadius")
			if typeof(radius) ~= "number" then
				radius = 14
			end
			local dx = pos.X - trigger.Position.X
			local dz = pos.Z - trigger.Position.Z
			local inside = (dx * dx + dz * dz) <= radius * radius and math.abs(pos.Y - trigger.Position.Y) <= 14
			if inside and not wasInside then
				local shopType = trigger:GetAttribute("ShopType")
				if typeof(shopType) == "string" then
					openShop(shopType)
				end
			end
			insideState[trigger] = inside
		end
	end
end)

-- Backup: pressing E on a pad's ProximityPrompt opens the matching shop.
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
	if triggerPlayer ~= player then
		return
	end
	local pad = prompt.Parent
	local shopType = pad and pad:IsA("BasePart") and pad:GetAttribute("ShopType")
	if typeof(shopType) == "string" then
		openShop(shopType)
	end
end)

----------------------------------------------------------------------
-- Render + networking
----------------------------------------------------------------------

local function render(data)
	if not data then
		return
	end
	handleDexDiscoveries(data)
	state.data = data
	coinsLabel.Text = comma(data.Coins or 0)
	renderSeeds(data)
	renderTreeDex(data)
	renderShovelShop(data)
end

Net.event("DataChanged").OnClientEvent:Connect(render)
Net.event("Notify").OnClientEvent:Connect(function(text)
	if typeof(text) == "string" then
		toast(text)
	end
end)
Net.event("Reveal").OnClientEvent:Connect(reveal)
Net.event("ShopOpened").OnClientEvent:Connect(function(shopType)
	if typeof(shopType) == "string" then
		openShop(shopType)
	end
end)

buildShovelShopRows()
buildSeedShopRows()

task.spawn(function()
	local ok, data = pcall(function()
		return Net.func("GetProfile"):InvokeServer()
	end)
	if ok then
		render(data)
	end
end)
