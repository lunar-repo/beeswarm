local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local RQValue = require(game.ReplicatedStorage.RQValue)
local RandomPools = require(game.ReplicatedStorage.RandomPools)
local WaxTypes = require(game.ReplicatedStorage.WaxTypes)
local BeequipFile = require(game.ReplicatedStorage.Beequips.BeequipFile)
local BeequipCaseEntry = require(game.ReplicatedStorage.Beequips.BeequipCaseEntry)
local ClientStatCache = require(game.ReplicatedStorage.ClientStatCache)
local Mods = game:GetService("ReplicatedStorage").StatModifiers
local BeeStatMods = require(game:GetService("ReplicatedStorage").BeeStats.BeeStatMods)
local TradeGui = require(game:GetService("ReplicatedStorage").Gui.TradeGui)

local WAX_NAMES = {"Soft", "Hard", "Caustic", "Debug"}

local BG_MAIN     = Color3.fromRGB(22, 20, 18)
local BG_TITLEBAR = Color3.fromRGB(32, 28, 24)
local BG_CARD     = Color3.fromRGB(27, 24, 21)
local BG_INPUT    = Color3.fromRGB(36, 32, 28)
local BG_INPUT_HI = Color3.fromRGB(46, 41, 35)
local BG_OPTION   = Color3.fromRGB(30, 27, 23)
local BG_OPTION_HI= Color3.fromRGB(42, 37, 31)
local BG_TABLE    = Color3.fromRGB(19, 17, 15)
local ACCENT      = Color3.fromRGB(255, 176, 32)
local ACCENT_DIM  = Color3.fromRGB(190, 135, 45)
local TEXT_HI     = Color3.fromRGB(240, 235, 225)
local TEXT_MID    = Color3.fromRGB(205, 198, 188)
local TEXT_MUTED  = Color3.fromRGB(140, 134, 124)
local BORDER      = Color3.fromRGB(54, 48, 41)

local function addHoverTween(obj, idleProp, hoverColor, idleColor)
	idleColor = idleColor or obj.BackgroundColor3
	obj.MouseEnter:Connect(function()
		TweenService:Create(obj, TweenInfo.new(0.12), { [idleProp] = hoverColor }):Play()
	end)
	obj.MouseLeave:Connect(function()
		TweenService:Create(obj, TweenInfo.new(0.12), { [idleProp] = idleColor }):Play()
	end)
end

local function _ugDefToTag(def)
    local suc, res = pcall(function()
        local tag = ""
        if def.BeeStat then
            tag = BeeStatMods.GetType(def.BeeStat).DisplayName
        elseif def.HiveBonusStat then
            tag = "[Hive Bonus]" .. require(Mods[def.HiveBonusStat]).Description({Value=0,Op=def.Op or'Add'}, def.Params)
        elseif def.BeeAbility then
            tag = "Ability: " .. def.BeeAbility .. " (from wax)"
        end
        return tag
    end)
    return suc and res or ("err:" .. tostring(res))
end

local function buildCheckpoint(beequip)
	local seed = beequip:GetSeed()
	local quality = beequip.Q*5
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

local function predictWaxOutcomes(beequip, waxName, maxWax, iterations)
	local cp = buildCheckpoint(beequip)
	if not cp then return nil, nil, "invalid beequip / no typedef" end

	local waxDef = WaxTypes.Get(waxName)
	if not waxDef then return nil, nil, "invalid wax type" end

	local survivalPct = {}
	for w = 1, maxWax do
		survivalPct[w] = 100 * (waxDef.SuccessRate ^ w)
	end

	local rawResults = {}
	for w = 1, maxWax do rawResults[w] = {} end

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

	local results = {}
	for w = 1, maxWax do
		local rows = {}
		for _, tag in ipairs(cp.allTags) do
			local b = rawResults[w][tag]
			if b and b.samples > 0 then
				local mean = b.sum / b.samples
				local variance = (b.sumSq / b.samples) - (mean * mean)
				local stdev = math.sqrt(math.max(variance, 0))
				table.insert(rows, {
					tag = tag,
					hitPct = 100 * b.hits / b.samples,
					mean = mean,
					stdev = stdev,
				})
			end
		end
		table.sort(rows, function(a, b) return a.hitPct > b.hitPct end)
		results[w] = rows
	end

	return results, survivalPct, nil
end

local function GetQuality(bq)
    return bq.Q
end

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
						table.insert(list, { name = "Case - " .. bq:GetDisplayName(), quality = (GetQuality(bq) or 0) * 5, beequip = bq })
					end
				end
			end
		end
		if stats.Beequips.Storage then
			for _, data in ipairs(stats.Beequips.Storage) do
				local bq = BeequipFile.FromData(data)
				table.insert(list, { name = "Storage - " .. bq:GetDisplayName(), quality = (GetQuality(bq) or 0) * 5, beequip = bq })
			end
		end
        if TradeGui.GetTheirOffer() then
            warn("trades detected")
            for i, data in pairs(TradeGui.GetTheirOffer()) do
                local pack = data.Pack
                if pack.Category == "Beequip" then
                    local bq = BeequipFile.FromData(pack.File)
                    table.insert(list, { name = "Trade - " .. bq:GetDisplayName(), quality = (GetQuality(bq) or 0) * 5, beequip = bq })
                else
                    warn("not a beequip")
                end
            end
        end
	end

	return list
end

local MAIN_W, MAIN_H = game:GetService("UserInputService").TouchEnabled and 680 or 880, 500

local INNER_PAD = 16

local LEFT_W = 280
local RIGHT_W = MAIN_W - LEFT_W - (INNER_PAD * 3)

local CONTENT_W = LEFT_W

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WaxPredictorGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = gethui()

local main = Instance.new("Frame")
main.Name = "wax"
main.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
main.Position = UDim2.new(0.5, -MAIN_W / 2, 0.5, -MAIN_H / 2)
main.BackgroundColor3 = BG_MAIN
main.BorderSizePixel = 0
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = BORDER
mainStroke.Thickness = 1
mainStroke.Parent = main

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = BG_TITLEBAR
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent = titleBar

local titleMask = Instance.new("Frame")
titleMask.BackgroundColor3 = BG_TITLEBAR
titleMask.BorderSizePixel = 0
titleMask.Size = UDim2.new(1, 0, 0, 14)
titleMask.Position = UDim2.new(0, 0, 1, -14)
titleMask.ZIndex = 0
titleMask.Parent = titleBar

local accentLine = Instance.new("Frame")
accentLine.BackgroundColor3 = ACCENT
accentLine.BorderSizePixel = 0
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.Position = UDim2.new(0, 0, 1, 0)
accentLine.ZIndex = 2
accentLine.Parent = titleBar

local hexIcon = Instance.new("TextLabel")
hexIcon.BackgroundTransparency = 1
hexIcon.Size = UDim2.new(0, 24, 1, 0)
hexIcon.Position = UDim2.new(0, 16, 0, 0)
hexIcon.Font = Enum .Font.GothamBold
hexIcon.Text = "⭐"
hexIcon.TextColor3 = ACCENT
hexIcon.TextSize = 20
hexIcon.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, -90, 1, 0)
titleLabel.Position = UDim2.new(0, 44, 0, 0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Lunar Predictor"
titleLabel.TextColor3 = TEXT_HI
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 9)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
closeBtn.BackgroundTransparency = 1
closeBtn.AutoButtonColor = false
closeBtn.Text = "x"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = TEXT_HI
closeBtn.TextSize = 16
closeBtn.Parent = titleBar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn
closeBtn.MouseEnter:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
end)
closeBtn.MouseLeave:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
end)
closeBtn.MouseButton1Click:Connect(function()
	_G.waxloaded = false
	screenGui:Destroy()
end)

local UIS = game:GetService("UserInputService")

do
	local dragging = false
	local dragStart
	local startPos

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart

			main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function addSectionLabel(y, text)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -INNER_PAD * 2, 0, 16)
	lbl.Position = UDim2.new(0, INNER_PAD, 0, y)
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = text
	lbl.TextColor3 = ACCENT_DIM
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = main
	return lbl
end

local function createDropdown(parent, x, y, width, labelText, options, getDisplayText)
	getDisplayText = getDisplayText or function(o) return tostring(o) end

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(0, width, 0, 50)
	container.Position = UDim2.new(0, x, 0, y)
	container.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Font = Enum.Font.GothamMedium
	label.Text = labelText
	label.TextColor3 = TEXT_MUTED
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 34)
	button.Position = UDim2.new(0, 0, 0, 16)
	button.BackgroundColor3 = BG_INPUT
	button.AutoButtonColor = false
	button.Font = Enum.Font.Gotham
	button.TextColor3 = TEXT_MID
	button.TextSize = 13
	button.Text = "  Select..."
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Parent = container
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = button
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = BORDER
	btnStroke.Thickness = 1
	btnStroke.Parent = button
	addHoverTween(button, "BackgroundColor3", BG_INPUT_HI, BG_INPUT)

	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.new(0, 22, 1, 0)
	arrow.Position = UDim2.new(1, -26, 0, 0)
	arrow.Text = "▼"
	arrow.TextColor3 = TEXT_MUTED
	arrow.Font = Enum.Font.Gotham
	arrow.TextSize = 13
	arrow.Parent = button

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, 0, 0, 0)
	listFrame.Position = UDim2.new(0, 0, 1, 4)
	listFrame.BackgroundColor3 = BG_OPTION
	listFrame.BorderSizePixel = 0
	listFrame.Visible = false
	listFrame.ZIndex = 10
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.ScrollBarThickness = 4
	listFrame.Parent = button
    listFrame.ClipsDescendants = true
	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 8)
	listCorner.Parent = listFrame
	local listStroke = Instance.new("UIStroke")
	listStroke.Color = BORDER
	listStroke.Thickness = 1
	listStroke.Parent = listFrame
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
			optBtn.Size = UDim2.new(1, 0, 0, 28)
			optBtn.BackgroundColor3 = BG_OPTION
			optBtn.AutoButtonColor = false
			optBtn.Font = Enum.Font.Gotham
			optBtn.TextColor3 = TEXT_MID
			optBtn.TextSize = 12
			optBtn.Text = "  " .. getDisplayText(opt)
			optBtn.TextXAlignment = Enum.TextXAlignment.Left
			optBtn.ZIndex = 11
			optBtn.Parent = listFrame
            optBtn.BorderSizePixel = 0
			addHoverTween(optBtn, "BackgroundColor3", BG_OPTION_HI, BG_OPTION)
			optBtn.MouseButton1Click:Connect(function()
				selected = opt
				button.Text = "  " .. getDisplayText(opt)
				button.TextColor3 = TEXT_HI
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
			local h = math.min(#options * 28, 160)
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

addSectionLabel(58, "C O N F I G U R E")

local REFRESH_BTN_W = 34
local beequipDropdown = createDropdown(
	main, INNER_PAD, 78, LEFT_W - REFRESH_BTN_W - 8,
	"Beequip", getAllBeequips(),
	function(o) return string.format("%s  (%.4f★)", o.name, o.quality) end
)

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, REFRESH_BTN_W, 0, 34)
refreshBtn.Position = UDim2.new(0, INNER_PAD + (LEFT_W - REFRESH_BTN_W), 0, 94)
refreshBtn.BackgroundColor3 = BG_INPUT
refreshBtn.AutoButtonColor = false
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextColor3 = ACCENT
refreshBtn.TextSize = 15
refreshBtn.Text = "🔄"
refreshBtn.Parent = main
local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 8)
refreshCorner.Parent = refreshBtn
local refreshStroke = Instance.new("UIStroke")
refreshStroke.Color = BORDER
refreshStroke.Thickness = 1
refreshStroke.Parent = refreshBtn
addHoverTween(refreshBtn, "BackgroundColor3", BG_INPUT_HI, BG_INPUT)
refreshBtn.MouseButton1Click:Connect(function()
	beequipDropdown.refreshOptions(getAllBeequips())
end)

local HALF_GAP = 12
local HALF_W = (LEFT_W - HALF_GAP) / 2

local waxDropdown = createDropdown(
	main, INNER_PAD, 142, HALF_W,
	"Wax Type", WAX_NAMES, function(o) return o end
)

local countOptions = { 1, 2, 3, 4, 5 }
local countDropdown = createDropdown(
	main, INNER_PAD + HALF_W + HALF_GAP, 142, HALF_W,
	"Wax Count", countOptions, function(o) return tostring(o) .. "x" end
)

local predictBtn = Instance.new("TextButton")
predictBtn.Size = UDim2.new(0, LEFT_W, 0, 40)
predictBtn.Position = UDim2.new(0, INNER_PAD, 0, 206)
predictBtn.BackgroundColor3 = ACCENT
predictBtn.AutoButtonColor = false
predictBtn.Font = Enum.Font.GothamBold
predictBtn.TextColor3 = Color3.fromRGB(30, 22, 10)
predictBtn.TextSize = 14
predictBtn.Text = "PREDICT"
predictBtn.Parent = main
local predictCorner = Instance.new("UICorner")
predictCorner.CornerRadius = UDim.new(0, 9)
predictCorner.Parent = predictBtn
addHoverTween(predictBtn, "BackgroundColor3", Color3.fromRGB(255, 195, 80), ACCENT)

local divider = Instance.new("Frame")
divider.BackgroundColor3 = BORDER
divider.BorderSizePixel = 0
divider.Size = UDim2.new(1, -INNER_PAD * 2, 0, 1)
divider.Position = UDim2.new(0, INNER_PAD, 0, 262)
divider.Visible = false
divider.Parent = main

local resultsLabel = addSectionLabel(58, "R E S U L T S")
resultsLabel.Position = UDim2.new(0, LEFT_W + INNER_PAD * 2, 0, 58)

local RESULTS_Y = 78
local resultsFrame = Instance.new("ScrollingFrame")
resultsFrame.Size = UDim2.new(
	0,
	RIGHT_W,
	0,
	MAIN_H - RESULTS_Y - INNER_PAD
)

resultsFrame.Position = UDim2.new(
	0,
	LEFT_W + INNER_PAD * 2,
	0,
	RESULTS_Y
)
resultsFrame.BackgroundColor3 = BG_TABLE
resultsFrame.BorderSizePixel = 0
resultsFrame.ScrollBarThickness = 6
resultsFrame.ScrollingDirection = Enum.ScrollingDirection.XY
resultsFrame.AutomaticCanvasSize = Enum.AutomaticSize.XY
resultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
resultsFrame.Parent = main
local resultsCorner = Instance.new("UICorner")
resultsCorner.CornerRadius = UDim.new(0, 9)
resultsCorner.Parent = resultsFrame
local resultsStroke = Instance.new("UIStroke")
resultsStroke.Color = BORDER
resultsStroke.Thickness = 1
resultsStroke.Parent = resultsFrame

local resultsLayout = Instance.new("UIListLayout")
resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
resultsLayout.Padding = UDim.new(0, 4)
resultsLayout.Parent = resultsFrame

local resultsPadding = Instance.new("UIPadding")
resultsPadding.PaddingTop = UDim.new(0, 10)
resultsPadding.PaddingLeft = UDim.new(0, 10)
resultsPadding.PaddingRight = UDim.new(0, 10)
resultsPadding.PaddingBottom = UDim.new(0, 10)
resultsPadding.Parent = resultsFrame

local function clearResults()
	for _, c in ipairs(resultsFrame:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function addPlainLine(text, order, color, bold, size)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 18)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lbl.Text = text
	lbl.TextColor3 = color or TEXT_MID
	lbl.TextSize = size or 12
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order
	lbl.Parent = resultsFrame
	return lbl
end

local function shortenTag(tag)
	local prefix, rest = tag:match("^(%a+):(.+)$")
	if not prefix then return tag end
	rest = rest:gsub("|P:.*$", "")
	local label = ({ B = "Base Stat", H = "Hive Bonus", A = "Ability", AP = "AbilPool" })[prefix] or prefix
	return label .. ": " .. rest
end

local MAIN_W, MAIN_H = 920, 500

local function buildResultsTable(results, survivalPct, maxWax)
	clearResults()
	local order = 1

	local survParts = {}
	for w = 1, maxWax do
		table.insert(survParts, string.format("wax %d: %.1f%%", w, survivalPct[w]))
	end
	addPlainLine("Survival odds (independent of seed) -  " .. table.concat(survParts, "   "),
		order, TEXT_MUTED, false, 11)
	order += 1

	local spacer = Instance.new("Frame")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(1, 0, 0, 6)
	spacer.LayoutOrder = order
	spacer.Parent = resultsFrame
	order += 1

	local tagSet, tagOrder = {}, {}
	for w = 1, maxWax do
		for _, row in ipairs(results[w]) do
			if not tagSet[row.tag] then
				tagSet[row.tag] = true
				table.insert(tagOrder, row.tag)
			end
		end
	end

	if #tagOrder == 0 then
		addPlainLine("No upgrade hits possible for this wax on this beequip.", order)
		return
	end

	local byTagPerLevel = {}
	for w = 1, maxWax do
		byTagPerLevel[w] = {}
		for _, row in ipairs(results[w]) do
			byTagPerLevel[w][row.tag] = row
		end
	end

	table.sort(tagOrder, function(a, b)
		local ra = byTagPerLevel[maxWax][a]
		local rb = byTagPerLevel[maxWax][b]
		return (ra and ra.hitPct or -1) > (rb and rb.hitPct or -1)
	end)

	-- one card per upgrade, full width, auto-height
	for i, tag in ipairs(tagOrder) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.fromRGB(24, 21, 18)
		card.BorderSizePixel = 0
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.Size = UDim2.new(1, 0, 0, 0)
		card.LayoutOrder = order
		card.Parent = resultsFrame
		order += 1

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = BORDER
		cardStroke.Thickness = 1
		cardStroke.Parent = card

		local cardLayout = Instance.new("UIListLayout")
		cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cardLayout.Padding = UDim.new(0, 6)
		cardLayout.Parent = card

		local cardPad = Instance.new("UIPadding")
		cardPad.PaddingTop = UDim.new(0, 10)
		cardPad.PaddingBottom = UDim.new(0, 10)
		cardPad.PaddingLeft = UDim.new(0, 12)
		cardPad.PaddingRight = UDim.new(0, 12)
		cardPad.Parent = card

		-- header: full width, as long as it needs to be, never truncated
		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 18)
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.Font = Enum.Font.GothamBold
		header.Text = shortenTag(tag)
		header.TextColor3 = ACCENT
		header.TextSize = 14
		header.TextWrapped = true
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.LayoutOrder = 1
		header.Parent = card

		-- wrapping pill row for wax progression
		local pillRow = Instance.new("Frame")
		pillRow.BackgroundTransparency = 1
		pillRow.Size = UDim2.new(1, 0, 0, 0)
		pillRow.AutomaticSize = Enum.AutomaticSize.Y
		pillRow.LayoutOrder = 2
		pillRow.Parent = card

		local pillLayout = Instance.new("UIListLayout")
		pillLayout.FillDirection = Enum.FillDirection.Horizontal
		pillLayout.Wraps = true
		pillLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pillLayout.Padding = UDim.new(0, 6)
		pillLayout.Parent = pillRow

		for w = 1, maxWax do
			local r = byTagPerLevel[w][tag]

			local pill = Instance.new("Frame")
			pill.BackgroundColor3 = BG_INPUT
			pill.AutomaticSize = Enum.AutomaticSize.X
			pill.Size = UDim2.new(0, 0, 0, 36)
			pill.LayoutOrder = w
			pill.Parent = pillRow

			local pillCorner = Instance.new("UICorner")
			pillCorner.CornerRadius = UDim.new(0, 6)
			pillCorner.Parent = pill

			local pillPad = Instance.new("UIPadding")
			pillPad.PaddingLeft = UDim.new(0, 10)
			pillPad.PaddingRight = UDim.new(0, 10)
			pillPad.Parent = pill

			local pillLayoutV = Instance.new("UIListLayout")
			pillLayoutV.FillDirection = Enum.FillDirection.Vertical
			pillLayoutV.VerticalAlignment = Enum.VerticalAlignment.Center
			pillLayoutV.HorizontalAlignment = Enum.HorizontalAlignment.Center
			pillLayoutV.Padding = UDim.new(0, 1)
			pillLayoutV.Parent = pill

			local waxLabel = Instance.new("TextLabel")
			waxLabel.BackgroundTransparency = 1
			waxLabel.AutomaticSize = Enum.AutomaticSize.X
			waxLabel.Size = UDim2.new(0, 0, 0, 12)
			waxLabel.Font = Enum.Font.GothamMedium
			waxLabel.Text = "WAX " .. w
			waxLabel.TextColor3 = TEXT_MUTED
			waxLabel.TextSize = 9
			waxLabel.Parent = pill

			local statLine = Instance.new("TextLabel")
			statLine.BackgroundTransparency = 1
			statLine.AutomaticSize = Enum.AutomaticSize.X
			statLine.Size = UDim2.new(0, 0, 0, 16)
			statLine.Font = Enum.Font.GothamBold
			statLine.TextSize = 13
			statLine.Parent = pill

			if r then
				statLine.Text = string.format("%.0f%%  ·  %+.2f", r.hitPct, r.mean)
				statLine.TextColor3 = r.hitPct >= 50 and TEXT_HI or TEXT_MID
			else
				statLine.Text = "—"
				statLine.TextColor3 = Color3.fromRGB(85, 80, 73)
			end

			pill.Parent = pillRow
		end
	end
end

predictBtn.MouseButton1Click:Connect(function()
	local beequipChoice = beequipDropdown.getSelected()
	local waxChoice = waxDropdown.getSelected()
	local countChoice = countDropdown.getSelected()

	clearResults()

	if not beequipChoice then
		addPlainLine("Pick a beequip first.", 1)
		return
	end
	if not waxChoice then
		addPlainLine("Pick a wax type first.", 1)
		return
	end
	if not countChoice then
		addPlainLine("Pick a wax count first.", 1)
		return
	end

	addPlainLine("Running simulation...", 1)
	task.wait()

	local results, survivalPct, errMsg = predictWaxOutcomes(beequipChoice.beequip, waxChoice, countChoice, 14000)

	if not results then
		clearResults()
		addPlainLine("Error: " .. tostring(errMsg), 1, Color3.fromRGB(235, 100, 100))
		return
	end

	buildResultsTable(results, survivalPct, countChoice)
end)
