--[[
  Wax Outcome Predictor GUI
  Draggable frame, dropdown for beequip + wax type + wax count,
  Predict button, scrolling results panel grouped by wax count.
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local RQValue = require(game.ReplicatedStorage.RQValue)
local RandomPools = require(game.ReplicatedStorage.RandomPools)
local WaxTypes = require(game.ReplicatedStorage.WaxTypes)
local BeequipFile = require(game.ReplicatedStorage.Beequips.BeequipFile)
local BeequipCaseEntry = require(game.ReplicatedStorage.Beequips.BeequipCaseEntry)
local ClientStatCache = require(game.ReplicatedStorage.ClientStatCache)
local StatModifiers = require(game.ReplicatedStorage.StatModifiers)
local BeeStatMods -- optional, falls back if not present
pcall(function() BeeStatMods = require(game.ReplicatedStorage.BeeStats.BeeStatMods) end)

local function _ugDefToTag(def)
	local tag
	if def.BeeStat then
		tag = "B:" .. def.BeeStat
	elseif def.HiveBonusStat then
		tag = ("H:" .. def.HiveBonusStat) .. "|O:" .. (def.Op or "Add")
	elseif def.BeeAbility then
		tag = "A:" .. def.BeeAbility
	elseif def.BeeAbilityPool then
		local s = ""
		for _, v in ipairs(def.BeeAbilityPool) do s = s .. v[1] .. "/" end
		tag = "AP:" .. s
	end
	if def.Params then
		tag = tag .. "|P:"
		for k, v in pairs(def.Params) do tag = tag .. k .. ":" .. tostring(v) .. "|" end
	end
	return tag
end

local function buildCheckpoint(beequip)
	local seed = beequip:GetSeed()
	local quality = beequip:GetQuality() or 0
	local typedef = beequip:GetTypeDef()
	if not typedef then return nil end
	local oldRNG = typedef.OldRNG

	local rng = Random.new(seed)
	local function rngFn() return rng:NextNumber() end

	if typedef.Modifiers then
		for _, m in ipairs(typedef.Modifiers) do RQValue.Resolve(m, quality, rngFn, oldRNG) end
	end
	if typedef.HiveBonuses then
		for _, h in ipairs(typedef.HiveBonuses) do RQValue.Resolve(h, quality, rngFn, oldRNG) end
	end

	local rc = beequip:GetTurpentineUpgradeCount()
	while rc > 0 do rng:NextNumber() rc = rc - 1 end

	if typedef.Abilities then
		for _, a in ipairs(typedef.Abilities) do
			if a.NamePool then RandomPools.SelectFromOrderedList(a.NamePool, rngFn) end
		end
	end

	local defByTag, hitCount, totalVal, allTags = {}, {}, {}, {}
	local poolNonCaustic, poolAll = {}, {}

	if typedef.Upgrades then
		for _, def in ipairs(typedef.Upgrades) do
			local tag = _ugDefToTag(def)
			defByTag[tag] = def
			hitCount[tag] = 0
			totalVal[tag] = 0
			table.insert(allTags, tag)
			local chance = RQValue.Resolve(def.Chance, quality, rngFn, oldRNG) or 0
			if not def.CausticOnly then table.insert(poolNonCaustic, { tag, chance }) end
			table.insert(poolAll, { tag, chance })
		end
	end

	local function removeFromPool(pool, tag)
		for i, e in ipairs(pool) do
			if e[1] == tag then table.remove(pool, i) return end
		end
	end

	local function rollUpgrade(waxName)
		local pool = (waxName == "Caustic" or waxName == "Debug") and poolAll or poolNonCaustic
		local picked = RandomPools.SelectFromOrderedList(pool, rngFn)
		if not picked then return end
		local def = defByTag[picked]
		local val = RQValue.Resolve(def.Value, quality, rngFn, oldRNG)
		totalVal[picked] = totalVal[picked] + (val or 0)
		hitCount[picked] = hitCount[picked] + 1
		if def.Max and hitCount[picked] >= def.Max then
			removeFromPool(poolNonCaustic, picked)
			removeFromPool(poolAll, picked)
		end
	end

	local history = beequip:GetWaxHistory()
	if history and typedef.Upgrades then
		for _, entry in ipairs(history) do
			local waxId, success, burn = entry[1], entry[2], entry[3]
			if success then
				if burn and burn > 0 then for _ = 1, burn do rng:NextNumber() end end
				local waxDef = WaxTypes.TypeByID[waxId]
				local upgradeCount = waxDef and waxDef.Upgrades or 0
				for _ = 1, upgradeCount do rollUpgrade(waxDef.Name) end
			end
		end
	end

	return {
		rng = rng, quality = quality, oldRNG = oldRNG,
		defByTag = defByTag, allTags = allTags,
		hitCount = hitCount, totalVal = totalVal,
		poolNonCaustic = poolNonCaustic, poolAll = poolAll,
	}
end

local function deepCopyArr(arr)
	local out = {}
	for i, e in ipairs(arr) do out[i] = { e[1], e[2] } end
	return out
end
local function deepCopyMap(m)
	local out = {}
	for k, v in pairs(m) do out[k] = v end
	return out
end

-- returns results[waxCount] = { {tag=, hitPct=, mean=, stdev=}, ... } sorted desc by hitPct
-- and survivalPct[waxCount]
local function predictWaxOutcomes(beequip, waxName, maxWax, iterations)
	local cp = buildCheckpoint(beequip)
	if not cp then return nil, nil, "invalid beequip / no typedef" end

	local waxDef = WaxTypes.Get(waxName)
	if not waxDef then return nil, nil, "invalid wax type" end

	local rawResults = {}
	for w = 1, maxWax do rawResults[w] = {} end
	local survivalCount = {}
	for w = 1, maxWax do survivalCount[w] = 0 end

	for _ = 1, iterations do
		local trialRng = cp.rng:Clone()
		local hitCount = deepCopyMap(cp.hitCount)
		local totalVal = deepCopyMap(cp.totalVal)
		local poolNonCaustic = deepCopyArr(cp.poolNonCaustic)
		local poolAll = deepCopyArr(cp.poolAll)

		local function rngFn() return trialRng:NextNumber() end
		local function removeFromPool(pool, tag)
			for i, e in ipairs(pool) do
				if e[1] == tag then table.remove(pool, i) return end
			end
		end
		local function rollUpgrade()
			local pool = (waxName == "Caustic" or waxName == "Debug") and poolAll or poolNonCaustic
			local picked = RandomPools.SelectFromOrderedList(pool, rngFn)
			if not picked then return end
			local def = cp.defByTag[picked]
			local val = RQValue.Resolve(def.Value, cp.quality, rngFn, cp.oldRNG)
			totalVal[picked] = totalVal[picked] + (val or 0)
			hitCount[picked] = hitCount[picked] + 1
			if def.Max and hitCount[picked] >= def.Max then
				removeFromPool(poolNonCaustic, picked)
				removeFromPool(poolAll, picked)
			end
		end

		for w = 1, maxWax do
			local success = math.random() <= waxDef.SuccessRate
			if not success then break end
			survivalCount[w] = survivalCount[w] + 1

			local burnCount = math.random(32)
			for _ = 1, burnCount do trialRng:NextNumber() end
			for _ = 1, waxDef.Upgrades do rollUpgrade() end

			local bucket = rawResults[w]
			for _, tag in ipairs(cp.allTags) do
				bucket[tag] = bucket[tag] or { sum = 0, sumSq = 0, hits = 0, samples = 0 }
				local b = bucket[tag]
				b.sum = b.sum + totalVal[tag]
				b.sumSq = b.sumSq + totalVal[tag] * totalVal[tag]
				b.samples = b.samples + 1
				if hitCount[tag] > (cp.hitCount[tag] or 0) then b.hits = b.hits + 1 end
			end
		end
	end

	local results, survivalPct = {}, {}
	for w = 1, maxWax do
		survivalPct[w] = 100 * survivalCount[w] / iterations
		local rows = {}
		for _, tag in ipairs(cp.allTags) do
			local b = rawResults[w][tag]
			if b and b.hits > 0 then
				local mean = b.sum / b.samples
				local variance = (b.sumSq / b.samples) - (mean * mean)
				local stdev = math.sqrt(math.max(variance, 0))
				table.insert(rows, {
					tag = tag,
					def = cp.defByTag[tag],
					hitPct = 100 * b.hits / b.samples,
					mean = mean,
					stdev = stdev,
				})
			end
		end
		table.sort(rows, function(a, b) return a.hitPct > b.hitPct end)
		results[w] = rows
	end

	return results, survivalPct
end

-- ============================================================
-- GATHER BEEQUIPS
-- ============================================================

local function getAllBeequips()
	local stats = ClientStatCache:Get()
	local list = {}

	if stats and stats.Beequips then
		if stats.Beequips.Case then
			for _, data in ipairs(stats.Beequips.Case) do
				local entry = BeequipCaseEntry.FromData(data)
				if entry:HasBeequip() then
					local bq = entry:FetchBeequip(stats, false)
					if bq then
						table.insert(list, { name = "Case - " .. bq:GetDisplayName(), quality = (bq:GetQuality() or 0) * 5, beequip = bq })
					end
				end
			end
		end
		if stats.Beequips.Storage then
			for _, data in ipairs(stats.Beequips.Storage) do
				local bq = BeequipFile.FromData(data)
				table.insert(list, { name = "Storage - " .. bq:GetDisplayName(), quality = (bq:GetQuality() or 0) * 5, beequip = bq })
			end
		end
	end

	return list
end

local WAX_NAMES = { "Soft", "Hard", "Caustic", "Debug" } -- Swirled excluded (no Upgrades)

-- ============================================================
-- GUI
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WaxPredictorGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 420, 0, 480)
main.Position = UDim2.new(0.5, -210, 0.5, -240)
main.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
main.BorderSizePixel = 0
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

-- title bar (drag handle)
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Wax Outcome Predictor"
titleLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 44)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 13
closeBtn.Parent = titleBar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function()
	_G.waxloaded = false
	screenGui:Destroy()
end)

-- drag logic
do
	local dragging, dragStart, startPos
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	titleBar.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- ===== generic dropdown builder =====
local function createDropdown(parent, posY, labelText, options, getDisplayText)
	getDisplayText = getDisplayText or function(o) return tostring(o) end

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, -24, 0, 50)
	container.Position = UDim2.new(0, 12, 0, posY)
	container.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Font = Enum.Font.Gotham
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(180, 180, 190)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 30)
	button.Position = UDim2.new(0, 0, 0, 18)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
	button.AutoButtonColor = false
	button.Font = Enum.Font.Gotham
	button.TextColor3 = Color3.fromRGB(230, 230, 235)
	button.TextSize = 13
	button.Text = "  Select..."
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Parent = container
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = button

	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.new(0, 20, 1, 0)
	arrow.Position = UDim2.new(1, -24, 0, 0)
	arrow.Text = "v"
	arrow.TextColor3 = Color3.fromRGB(180, 180, 190)
	arrow.Font = Enum.Font.Gotham
	arrow.TextSize = 14
	arrow.Parent = button

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, 0, 0, 0)
	listFrame.Position = UDim2.new(0, 0, 1, 2)
	listFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
	listFrame.BorderSizePixel = 0
	listFrame.Visible = false
	listFrame.ZIndex = 10
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.ScrollBarThickness = 4
	listFrame.Parent = button
	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 6)
	listCorner.Parent = listFrame
	local listLayout = Instance.new("UIListLayout")
	listLayout.Parent = listFrame

	local selected = nil
	local onSelect

	local function refreshOptions(opts)
		options = opts
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for _, opt in ipairs(options) do
			local optBtn = Instance.new("TextButton")
			optBtn.Size = UDim2.new(1, 0, 0, 26)
			optBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
			optBtn.AutoButtonColor = true
			optBtn.Font = Enum.Font.Gotham
			optBtn.TextColor3 = Color3.fromRGB(225, 225, 230)
			optBtn.TextSize = 12
			optBtn.Text = "  " .. getDisplayText(opt)
			optBtn.TextXAlignment = Enum.TextXAlignment.Left
			optBtn.ZIndex = 11
			optBtn.Parent = listFrame
			optBtn.MouseButton1Click:Connect(function()
				selected = opt
				button.Text = "  " .. getDisplayText(opt)
				listFrame.Visible = false
				listFrame.Size = UDim2.new(1, 0, 0, 0)
				if onSelect then onSelect(opt) end
			end)
		end
	end
	refreshOptions(options)

	button.MouseButton1Click:Connect(function()
		listFrame.Visible = not listFrame.Visible
		if listFrame.Visible then
			local h = math.min(#options * 26, 150)
			listFrame.Size = UDim2.new(1, 0, 0, h)
		else
			listFrame.Size = UDim2.new(1, 0, 0, 0)
		end
	end)

	return {
		container = container,
		getSelected = function() return selected end,
		setOnSelect = function(fn) onSelect = fn end,
		refreshOptions = refreshOptions,
	}
end

-- ===== beequip dropdown =====
local beequipList = getAllBeequips()
local beequipDropdown = createDropdown(main, 46, "Beequip", beequipList, function(o)
	return string.format("%s  (%.2f⭐)", o.name, o.quality)
end)

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 70, 0, 30)
refreshBtn.Position = UDim2.new(1, -82, 0, 64)
refreshBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextColor3 = Color3.fromRGB(225, 225, 230)
refreshBtn.TextSize = 12
refreshBtn.Text = "Refresh"
refreshBtn.Parent = main
local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 6)
refreshCorner.Parent = refreshBtn
refreshBtn.MouseButton1Click:Connect(function()
	beequipList = getAllBeequips()
	beequipDropdown.refreshOptions(beequipList)
end)

-- ===== wax type dropdown =====
local waxDropdown = createDropdown(main, 104, "Wax Type", WAX_NAMES, function(o) return o end)

-- ===== wax count dropdown =====
local countOptions = { 1, 2, 3, 4, 5 }
local countDropdown = createDropdown(main, 162, "Number of Waxes to Apply", countOptions, function(o)
	return tostring(o) .. "x"
end)

-- ===== predict button =====
local predictBtn = Instance.new("TextButton")
predictBtn.Size = UDim2.new(1, -24, 0, 36)
predictBtn.Position = UDim2.new(0, 12, 0, 220)
predictBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
predictBtn.Font = Enum.Font.GothamBold
predictBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
predictBtn.TextSize = 14
predictBtn.Text = "Predict"
predictBtn.Parent = main
local predictCorner = Instance.new("UICorner")
predictCorner.CornerRadius = UDim.new(0, 8)
predictCorner.Parent = predictBtn

-- ===== results scroll area =====
local resultsFrame = Instance.new("ScrollingFrame")
resultsFrame.Size = UDim2.new(1, -24, 1, -270)
resultsFrame.Position = UDim2.new(0, 12, 0, 264)
resultsFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
resultsFrame.BorderSizePixel = 0
resultsFrame.ScrollBarThickness = 5
resultsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
resultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
resultsFrame.Parent = main
local resultsCorner = Instance.new("UICorner")
resultsCorner.CornerRadius = UDim.new(0, 8)
resultsCorner.Parent = resultsFrame

local resultsLayout = Instance.new("UIListLayout")
resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
resultsLayout.Padding = UDim.new(0, 6)
resultsLayout.Parent = resultsFrame

local resultsPadding = Instance.new("UIPadding")
resultsPadding.PaddingTop = UDim.new(0, 8)
resultsPadding.PaddingLeft = UDim.new(0, 8)
resultsPadding.PaddingRight = UDim.new(0, 8)
resultsPadding.PaddingBottom = UDim.new(0, 8)
resultsPadding.Parent = resultsFrame

local function clearResults()
	for _, c in ipairs(resultsFrame:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function addSectionHeader(text, order)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(120, 170, 255)
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order
	lbl.Parent = resultsFrame
end

local function addStatLine(text, order)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 16)
	lbl.Font = Enum.Font.Code
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(210, 210, 215)
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order
	lbl.Parent = resultsFrame
end

predictBtn.MouseButton1Click:Connect(function()
	local beequipChoice = beequipDropdown.getSelected()
	local waxChoice = waxDropdown.getSelected()
	local countChoice = countDropdown.getSelected()

	clearResults()

	if not beequipChoice then
		addStatLine("Pick a beequip first.", 1)
		return
	end
	if not waxChoice then
		addStatLine("Pick a wax type first.", 1)
		return
	end
	if not countChoice then
		addStatLine("Pick a wax count first.", 1)
		return
	end

	addStatLine("Running simulation...", 1)
	task.wait()

	local results, survivalPct, errMsg = predictWaxOutcomes(beequipChoice.beequip, waxChoice, countChoice, 5000)
	clearResults()

	if not results then
		addStatLine("Error: " .. tostring(errMsg), 1)
		return
	end

	local order = 1
	for w = 1, countChoice do
		addSectionHeader(string.format(
			"After %d %s wax(es) -- survived %.2f%%", w, waxChoice, survivalPct[w]
		), order)
		order += 1

		if #results[w] == 0 then
			addStatLine("  (no upgrade hits possible)", order)
			order += 1
		else
			for _, row in ipairs(results[w]) do
				addStatLine(string.format(
					"  %-32s %5.1f%%  | avg %.2f (+/-%.2f)",
					row.tag, row.hitPct, row.mean, row.stdev
				), order)
				order += 1
			end
		end
	end
end)
