

--[[
lunar script beta
report bugs in discord: [placeholder]
]]

-- sprouts:
-- basic: 0.705882, 0.745098, 0.729412
-- rare: 0.658824, 0.654902, 0.662745
-- gummy: 0.94902, 0.505882, 1
-- legendary: 0.0784314, 0.647059, 0.780392

local realloadstart = tick()
if _G.LUNAR_LOADING then return warn("[Lunar] Loading still in progress") end
_G.LUNAR_LOADING = true
pcall(function()
    getgenv().LUNAR_UNLOAD()
end)

local ContentProvider = game:GetService("ContentProvider")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local virtualuser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local events = require(ReplicatedStorage.Events)
local clientstatcache = require(ReplicatedStorage.ClientStatCache)
local localcollect = require(ReplicatedStorage.Collectors.LocalCollect)
local eggtypes = ReplicatedStorage.EggTypes
local eggtypesmodule = require(eggtypes)
local bufftilemodule = require(ReplicatedStorage.Gui.TileDisplay.BuffTile)
local recipes = require(ReplicatedStorage.BlenderRecipes)
local honeycombfile = require(ReplicatedStorage.HoneycombFileTools)
local alertboxes = require(ReplicatedStorage.AlertBoxes)
local beepopup = require(ReplicatedStorage.Gui.BeePopUp)
local beeinspector = require(ReplicatedStorage.Gui.BeeInspector)
local badgesmodule = require(ReplicatedStorage.Badges)
local numbercommas = require(ReplicatedStorage.NumberCommas)

repeat task.wait() until LocalPlayer:FindFirstChild("PlayerGui") and
    LocalPlayer.PlayerGui:FindFirstChild("LoadingScreenGui") and
    LocalPlayer.PlayerGui.LoadingScreenGui:FindFirstChild("LoadingMessage") and
    LocalPlayer.PlayerGui.LoadingScreenGui.LoadingMessage.Visible == false and
    LocalPlayer.Character and 
    LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and 
    LocalPlayer.Character:FindFirstChild("Humanoid");

local function supersaferequest(url,method,arg,body)
    if not method then method = "GET" end
    local properties = {
        Url = url,
        Method = method,
        Headers = {
            ["content-type"] = "application/json"
        },
        Body = body
    }
    for i, v in pairs(arg or {}) do
        properties[i]=v
    end
    local suc, res = pcall(function()
        local req = ((http and http.request) or (http_request) or (syn and syn.request) or request)(properties)
        if not req or not req.StatusCode or (req.StatusCode > 299 or req.StatusCode < 200) then
            error("general request failure, status code: " .. tostring((req or {}).StatusCode) .. " body: " .. tostring((req or {}).Body))
        end
        return req
    end)
    if not suc then
        warn("-- REQUEST FAILURE --\n" .. tostring(res))
        task.wait(0.5)
        if method ~= "POST" then return supersaferequest(url,method,arg) else setclipboard(tostring(HttpService:JSONEncode(body))) end
    else
        return res
    end
end

-- install the icon
local host = "https://github.com/lunar-repo/pic/raw/main/"
if not isfile("r_antlers.png") then
    writefile("r_antlers.png", supersaferequest(host .. "Reindeer_Antlers.png").Body)
end

local Fluent = loadstring(supersaferequest("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua").Body)()

-- entire gui module
local SaveFileName = "lunar-default.json"
local SaveTable = {}
local mainuimodule = (function()
    if isfile(SaveFileName) then
        SaveTable = HttpService:JSONDecode(readfile(SaveFileName))
    else
        writefile(SaveFileName, "{}")
    end

    local Library = {}

    if RunService:IsStudio() then
        LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("debugUi"):Destroy()
    end

    local Icons = RunService:IsStudio() and require(game:GetService("ReplicatedStorage").Icons) or loadstring(supersaferequest("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua").Body)()
    local IsMobile = UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled == false

    local function getIcon(name)
        if name:find("rbxasset") then
            local asset = {
                id = name,
                imageRectSize = Vector2.new(0,0),
                imageRectOffset = Vector2.new(0,0),
            }

            return asset
        end
        name = string.match(string.lower(name), "^%s*(.*)%s*$")
        local sizedicons = Icons['48px']
        local r = sizedicons[name]

        local rirs = r[2]
        local riro = r[3]

        local irs = Vector2.new(rirs[1], rirs[2])
        local iro = Vector2.new(riro[1], riro[2])

        local asset = {
            id = "rbxassetid://" .. r[1],
            imageRectSize = irs,
            imageRectOffset = iro,
        }

        return asset
    end

    local function addShadow(frame)
        local shadow = Instance.new("Frame")
        shadow.Size = UDim2.new(1, 0, 0, 80)
        shadow.Position = UDim2.new(0, 0, 1, -80)
        shadow.BackgroundColor3 = Color3.new(0, 0, 0)
        shadow.BackgroundTransparency = 0
        shadow.ZIndex = frame.ZIndex + 1
        shadow.Parent = frame.Parent
        
        local corner = Instance.new("UICorner", shadow)
        corner.CornerRadius = UDim.new(0, 5)
        
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0.6),
        })
        gradient.Parent = shadow

        local function update()
            local atBottom = (frame.CanvasPosition.Y + frame.AbsoluteWindowSize.Y + 10)
                >= frame.AbsoluteCanvasSize.Y - 1
            TweenService:Create(shadow, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                BackgroundTransparency = atBottom and 1 or 0
            }):Play()
        end

        frame:GetPropertyChangedSignal("CanvasPosition"):Connect(update)
        
        return shadow
    end

    local function createRipple(frame, x, y)
        local ripple = Instance.new("Frame")
        ripple.Name = "Ripple"
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)
        ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ripple.BackgroundTransparency = 0.6
        ripple.BorderSizePixel = 0
        ripple.Position = UDim2.fromOffset(x, y)
        ripple.Size = UDim2.fromOffset(0, 0)
        ripple.ZIndex = frame.ZIndex + 1
        ripple.ClipsDescendants = false

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ripple

        ripple.Parent = frame

        local absSize = frame.AbsoluteSize
        local maxDim = math.sqrt(absSize.X ^ 2 + absSize.Y ^ 2) * 0.2

        local TweenService = game:GetService("TweenService")
        local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        local expandTween = TweenService:Create(ripple, info, {
            Size = UDim2.fromOffset(maxDim, maxDim),
            BackgroundTransparency = 1,
        })

        expandTween:Play()
        expandTween.Completed:Connect(function()
            ripple:Destroy()
        end)
    end

    local SmoothScroll = (function()
        local RS, UIS, CAS = game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("ContextActionService")

        if not RS:IsClient() then
            error("SmoothScroll can only be used on the client")
        end

        local PlayerGui = RunService:IsStudio() and LocalPlayer:WaitForChild("PlayerGui") or CoreGui
        local Mouse		= LocalPlayer:GetMouse()
        local ipairs,pairs	= ipairs,pairs

        wait()

        local DEFAULT_SENS,DEFAULT_FRICT = Mouse.ViewSizeY/27, 0.78


        local Objects = {}
        local ScrollBarHolder
        local DraggingBar = false
        if not UIS.TouchEnabled then

            ScrollBarHolder = Instance.new("ScreenGui")
            ScrollBarHolder.Name = "SmoothScroll"
            ScrollBarHolder.Parent = PlayerGui

            RS.Heartbeat:Connect(function()
                for Frame, Info in pairs(Objects) do
                    if Info.Velocity > 0.05 or Info.Velocity < -0.05 then
                        Info.Velocity = Info.Velocity*Info.Frict				
                        if Info.Axis == "X" then
                            Frame.CanvasPosition = Vector2.new(Frame.CanvasPosition.X+Info.Velocity,Frame.CanvasPosition.Y)

                            if math.abs(Info.LastPos-Frame.CanvasPosition.X) == 0 then
                                Info.Velocity = 0
                            end
                            Info.LastPos = Frame.CanvasPosition.X
                        else
                            Frame.CanvasPosition = Vector2.new(Frame.CanvasPosition.X,Frame.CanvasPosition.Y+Info.Velocity)

                            if math.abs(Info.LastPos-Frame.CanvasPosition.Y) == 0 then
                                Info.Velocity = 0
                            end
                            Info.LastPos = Frame.CanvasPosition.Y
                        end
                    end
                end
            end)

            UIS.PointerAction:Connect(function(Wheel,Pan,Pinch,GP)
                if not DraggingBar then
                    local HoveredObjects = PlayerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)	
                    for i, Frame in ipairs(HoveredObjects) do
                        local Info = Objects[Frame]

                        if Info and Info.Visibility.Visible == true then
                            Info.Velocity = Info.Velocity - (Info.Sens * Pan.Y * (Info.Inverted and -1 or 1))
                            break
                        end
                    end
                end
            end)

            CAS:BindActionAtPriority("SmoothScroll", function(Name,State,Input)

                if DraggingBar then return Enum.ContextActionResult.Pass end

                local Processed = false

                local HoveredObjects = PlayerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)	
                for i, Frame in ipairs(HoveredObjects) do
                    local Info = Objects[Frame]

                    if Info and Info.Visibility.Visible == true then
                        Info.Velocity = Info.Velocity - (Info.Sens * Input.Position.Z * (Info.Inverted and -1 or 1))
                        Processed = true
                        break
                    end
                end

                return Processed and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass

            end, false, 8000, Enum.UserInputType.MouseWheel)

        end

        local OnScreenTracker = {}
        OnScreenTracker.__index = OnScreenTracker

        function OnScreenTracker.new(obj)

            assert(typeof(obj) == "Instance" and obj:IsA("GuiObject"), "Argument #1 expected GuiObject")
            local visibleChanged = Instance.new("BindableEvent")

            local self = setmetatable({
                GuiObject = obj;
                Visible = nil;
                Changed = visibleChanged.Event;
                _path = {};
                _conn = {};
                _root = nil;
                _visibleChanged = visibleChanged;
            }, OnScreenTracker)

            local function CheckVisible()
                local vis = (self._root and self._root.Enabled or false)
                if (vis) then
                    local path = self._path
                    for i, p in ipairs(path) do
                        if (not p.Visible) then
                            vis = false
                            break
                        end
                    end
                end
                if (vis ~= self.Visible) then
                    self.Visible = vis
                    visibleChanged:Fire(vis)
                end
            end

            local function BuildAncestryPath()
                for _,c in ipairs(self._conn) do c:Disconnect() end
                local path = {}
                local conn = {}
                local root = nil
                local parent = obj
                while (parent and (parent:IsA("GuiObject") or parent:IsA("Folder"))) do
                    if parent:IsA("GuiObject") then
                        conn[#conn + 1] = parent:GetPropertyChangedSignal("Visible"):Connect(CheckVisible)
                        path[#path + 1] = parent
                    end
                    parent = parent.Parent
                end
                if (parent and parent:IsA("LayerCollector")) then
                    conn[#conn + 1] = parent:GetPropertyChangedSignal("Enabled"):Connect(CheckVisible)
                    root = parent
                end
                self._path = path
                self._conn = conn
                self._root = root
                CheckVisible()
            end

            self._ancestry = obj.AncestryChanged:Connect(function(child, parent)
                BuildAncestryPath()
            end)
            BuildAncestryPath()

            return self

        end

        function OnScreenTracker:Destroy()
            self._visibleChanged:Fire(false)
            self._visibleChanged:Destroy()
            self._ancestry:Disconnect()
            for _,c in ipairs(self._conn) do c:Disconnect() end
        end


        local function CreateBar(Frame,Axis)
            Axis = Axis or "Y"
            if not (Frame and typeof(Frame) == "Instance" and Frame.ClassName == "ScrollingFrame") then
                warn("Invalid frame to create custom bar")
                return
            end

            local Bar = Instance.new("TextButton")
            Bar.Name = Frame.Name.."_Scroller_"..Axis
            Bar.Text = ""
            Bar.BackgroundTransparency = 1
            Bar.Visible = Objects[Frame].Visibility.Visible

            local absSize,absPos,scrollThick = Frame.AbsoluteSize,Frame.AbsolutePosition,Frame.ScrollBarThickness

            local BarDrag
            Bar.MouseButton1Down:Connect(function()
                if not DraggingBar and not BarDrag then
                    DraggingBar = true

                    local LastPos = Vector2.new(Mouse.X,Mouse.Y)
                    BarDrag = UIS.InputChanged:Connect(function(Input)
                        if Input.UserInputType == Enum.UserInputType.MouseMovement then

                            local Pos = Vector2.new(Input.Position.X,Input.Position.Y)
                            local Delta = Pos-LastPos
                            local DeltaPercent = (Axis == "Y" and Delta.Y or Delta.X)/(Axis == "Y" and Frame.AbsoluteWindowSize.Y or Frame.AbsoluteWindowSize.X)

                            local Parent = Frame:FindFirstAncestorWhichIsA("GuiBase2d")

                            local CanvasSize = Vector2.new(
                                (Frame.CanvasSize.X.Scale*Parent.AbsoluteSize.X)+Frame.CanvasSize.X.Offset,
                                (Frame.CanvasSize.Y.Scale*Parent.AbsoluteSize.Y)+Frame.CanvasSize.Y.Offset
                            )

                            Frame.CanvasPosition = Vector2.new(Frame.CanvasPosition.X+(Axis == "X" and CanvasSize.X*DeltaPercent or 0),Frame.CanvasPosition.Y+(Axis == "Y" and CanvasSize.Y*DeltaPercent or 0))

                            LastPos = Pos
                        end
                    end)
                end
            end)
            local DragEnded = UIS.InputEnded:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 and BarDrag then
                    DraggingBar = false
                    BarDrag:Disconnect()
                    BarDrag = nil
                end
            end)

            Objects[Frame].Visibility.Changed:Connect(function(Visible)
                Bar.Visible = Visible

                if not Visible and BarDrag then
                    DraggingBar = false
                    BarDrag:Disconnect()
                    BarDrag = nil
                end
            end)

            if Axis == "X" then
                Bar.Size = UDim2.new(0,absSize.X,0,scrollThick)
                Bar.Position = UDim2.new(
                    0,absPos.X,
                    0,absPos.Y+absSize.Y-scrollThick
                )
            else
                Bar.Size = UDim2.new(0,scrollThick,0,absSize.Y)
                Bar.Position = UDim2.new(
                    0,Frame.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Right and absPos.X+absSize.X-scrollThick or absPos.X,
                    0,absPos.Y
                )
            end

            local Updater
            Updater = Frame.Changed:Connect(function(Prop)
                if Objects[Frame] then
                    if Frame:FindFirstAncestorWhichIsA("GuiBase2d") then
                        if Prop == "AbsoluteSize" or Prop == "AbsolutePosition" or Prop == "AbsolutePosition" or Prop == "CanvasSize" or Prop == "ScrollBarThickness" then
                            absSize,absPos,scrollThick = Frame.AbsoluteSize,Frame.AbsolutePosition,Frame.ScrollBarThickness

                            if Axis == "X" then
                                Bar.Size = UDim2.new(0,absSize.X,0,scrollThick)
                                Bar.Position = UDim2.new(
                                    0,absPos.X,
                                    0,absPos.Y+absSize.Y-scrollThick
                                )
                            else
                                Bar.Size = UDim2.new(0,scrollThick,0,absSize.Y)
                                Bar.Position = UDim2.new(
                                    0,Frame.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Right and absPos.X+absSize.X-scrollThick or absPos.X,
                                    0,absPos.Y
                                )
                            end
                        end

                    end
                else
                    Bar:Destroy()
                    Updater:Disconnect()
                    DragEnded:Disconnect()
                    if BarDrag then
                        BarDrag:Disconnect()
                        BarDrag = nil
                    end
                end
            end)

            Bar.Parent = ScrollBarHolder
        end

        local SmoothScroll = {}

        function SmoothScroll.Enable(Frame, Sensitivity, Friction, Inverted, Axis)
            if UIS.MouseEnabled and not UIS.TouchEnabled then

                if not (Frame and typeof(Frame) == "Instance" and Frame.ClassName == "ScrollingFrame") then
                    warn("Invalid frame to smooth")
                    return
                end

                if not Objects[Frame] then
                    Frame.ScrollingEnabled = false

                    local Actives,Connections = {},{}

                    for _,desc in ipairs(Frame:GetDescendants()) do
                        if desc:IsA("GuiObject") then
                            Actives[desc] = desc.Active
                            desc.Active = false
                            Connections[#Connections+1] = desc:GetPropertyChangedSignal("Active"):Connect(function()
                                desc.Active = false
                            end)
                        end
                    end

                    local parent = Frame
                    while (parent and (parent:IsA("GuiObject") or parent:IsA("Folder"))) do
                        if parent:IsA("GuiObject") then
                            Actives[parent] = parent.Active
                            parent.Active = false
                            Connections[#Connections+1] = parent:GetPropertyChangedSignal("Active"):Connect(function()
                                parent.Active = false
                            end)
                        end
                        parent = parent.Parent
                    end

                    Connections[#Connections+1] = Frame.DescendantAdded:Connect(function(desc)
                        if desc:IsA("GuiObject") then
                            Objects[Frame].Actives[desc] = desc.Active
                            desc.Active = false
                            Objects[Frame].Connections[#Objects[Frame].Connections+1] = desc:GetPropertyChangedSignal("Active"):Connect(function()
                                desc.Active = false
                            end)
                        end
                    end)


                    if Axis and (Axis == "X" or Axis == "Y") then
                    else
                        Axis = "Y" --Default to Y
                        if (Frame.CanvasSize.Y.Offset>0 or Frame.CanvasSize.Y.Scale>0) then
                            Axis = "Y"
                        elseif (Frame.CanvasSize.X.Offset>0 or Frame.CanvasSize.X.Scale>0) then
                            Axis = "X"
                        end
                    end

                    Objects[Frame] = {
                        Connections	= Connections;
                        Actives		= Actives;

                        Velocity	= 0;
                        LastPos		= 0;
                        Visibility	= OnScreenTracker.new(Frame);

                        Inverted	= Inverted;
                        Axis		= Axis;
                        Frict		= math.clamp(type(Friction)=="number" and Friction or DEFAULT_FRICT,0.2,0.99);
                        Sens		= math.clamp(type(Sensitivity)=="number" and Sensitivity or DEFAULT_SENS,0.01,99999999999999999);
                    }

                    CreateBar(Frame, "X")
                    CreateBar(Frame, "Y")
                else
                    Objects[Frame].Sens		= math.clamp(type(Sensitivity)=="number" and Sensitivity or DEFAULT_SENS,0.01,99999999999999999);
                    Objects[Frame].Frict	= math.clamp(type(Friction)=="number" and Friction or DEFAULT_FRICT,0.2,0.99);
                    Objects[Frame].Inverted	= Inverted
                end
            end
        end

        function SmoothScroll.Disable(Frame)

            if Objects[Frame] then
                Frame.ScrollingEnabled = true
                for i,c in ipairs(Objects[Frame].Connections) do
                    c:Disconnect()
                end
                Objects[Frame].Visibility:Destroy()
                for desc,a in pairs(Objects[Frame].Actives) do
                    desc.Active = a
                end

                Objects[Frame] = nil
            end

        end

        return SmoothScroll
    end)()

    local function AddDrag(Frame, DragBar)
        local dragToggle = nil
        local dragSpeed = 0.15
        local dragInput = nil
        local dragStart = nil
        local dragPos = nil
        local Delta
        local Position
        local startPos
        local function updateInput(input)
            Delta = input.Position - dragStart
            Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + Delta.X, startPos.Y.Scale, startPos.Y.Offset + Delta.Y)
            TweenService:Create(Frame, TweenInfo.new(0.05), {Position = Position}):Play()
        end
        DragBar.InputBegan:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and UserInputService:GetFocusedTextBox() == nil then
                dragToggle = true
                dragStart = input.Position
                startPos = Frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragToggle = false
                    end
                end)
            end
        end)
        DragBar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragToggle then
                updateInput(input)
            end
        end)
    end

    function Library:CreateWindow(Properties)
        local Name = Properties.Name
        local Icon = Properties.Icon
        if typeof(Icon) == "number" then
            Icon = "rbxassetid://" .. Icon
        end
        local uilibrary = Instance.new("ScreenGui")
        local MainFrame = Instance.new("Frame")
        local UICorner = Instance.new("UICorner")
        local Frame_2 = Instance.new("Frame")
        local UICorner_2 = Instance.new("UICorner")
        local ImageLabel = Instance.new("ImageLabel")
        local TextLabel = Instance.new("TextLabel")
        local search = Instance.new("Frame")
        local UICorner_3 = Instance.new("UICorner")
        local ImageLabel_2 = Instance.new("ImageLabel")
        local TextBox = Instance.new("TextBox")
        local backgroundimagelabel = Instance.new("ImageLabel")
        local UICorner_4 = Instance.new("UICorner")
        local Frame_3 = Instance.new("Frame")
        local NavigationBar = Instance.new("ScrollingFrame")
        local UIListLayout = Instance.new("UIListLayout")
        AddDrag(MainFrame, Frame_2)

        uilibrary.Name = game:GetService("HttpService"):GenerateGUID()
        uilibrary.Parent = not RunService:IsStudio() and CoreGui or LocalPlayer.PlayerGui
        uilibrary.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        _G.globaluilibrary = uilibrary

        MainFrame.Parent = uilibrary
        MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        MainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
        MainFrame.BorderSizePixel = 0
        MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        MainFrame.Size = IsMobile and UDim2.new(0, 570, 0, 380) or UDim2.new(0, 670, 0, 420)

        UICorner.CornerRadius = UDim.new(0, 5)
        UICorner.Parent = MainFrame

        Frame_2.Parent = MainFrame
        Frame_2.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        Frame_2.BackgroundTransparency = 0.650
        Frame_2.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Frame_2.BorderSizePixel = 0
        Frame_2.Size = UDim2.new(1, 0, 0, 50)

        UICorner_2.CornerRadius = UDim.new(0, 5)
        UICorner_2.Parent = Frame_2

        ImageLabel.Parent = Frame_2
        ImageLabel.AnchorPoint = Vector2.new(0, 0.5)
        ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ImageLabel.BackgroundTransparency = 1.000
        ImageLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
        ImageLabel.BorderSizePixel = 0
        ImageLabel.Position = UDim2.new(0, 3, 0.5, 0)
        ImageLabel.Size = UDim2.new(0, 36, 0, 36)
        ImageLabel.Image = Icon

        TextLabel.Parent = Frame_2
        TextLabel.AnchorPoint = Vector2.new(0, 0.5)
        TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.BackgroundTransparency = 1.000
        TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TextLabel.BorderSizePixel = 0
        TextLabel.Position = UDim2.new(0, 50, 0.5, 0)
        TextLabel.Size = UDim2.new(0, 200, 0, 20)
        TextLabel.FontFace = Font.fromName("JosefinSans", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        TextLabel.Text = Name
        TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.TextSize = 12.000
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left

        search.Name = "search"
        search.Parent = Frame_2
        search.AnchorPoint = Vector2.new(1, 0.5)
        search.BackgroundColor3 = Color3.fromRGB(69, 81, 147)
        search.BackgroundTransparency = 0.650
        search.BorderColor3 = Color3.fromRGB(0, 0, 0)
        search.BorderSizePixel = 0
        search.Position = UDim2.new(1, -11, 0.5, 0)
        search.Size = UDim2.new(0, 139, 1, -24)

        UICorner_3.CornerRadius = UDim.new(0, 5)
        UICorner_3.Parent = search

        local searchasset = getIcon("search")
        ImageLabel_2.Parent = search
        ImageLabel_2.AnchorPoint = Vector2.new(1, 0.5)
        ImageLabel_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ImageLabel_2.BackgroundTransparency = 1.000
        ImageLabel_2.BorderColor3 = Color3.fromRGB(0, 0, 0)
        ImageLabel_2.BorderSizePixel = 0
        ImageLabel_2.Position = UDim2.new(1, -6, 0.5, 0)
        ImageLabel_2.Size = UDim2.new(0, 16, 0, 16)
        ImageLabel_2.Image = searchasset.id
        ImageLabel_2.ImageRectOffset = searchasset.imageRectOffset
        ImageLabel_2.ImageRectSize = searchasset.imageRectSize

        TextBox.Parent = search
        TextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.BackgroundTransparency = 1.000
        TextBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TextBox.BorderSizePixel = 0
        TextBox.ClipsDescendants = true
        TextBox.Position = UDim2.new(0, 4, 0, 0)
        TextBox.Size = UDim2.new(1, -34, 1, 0)
        TextBox.Font = Enum.Font.ArialBold
        TextBox.PlaceholderText = "Search"
        TextBox.Text = ""
        TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.TextSize = 14.000
        TextBox.TextXAlignment = Enum.TextXAlignment.Left

        backgroundimagelabel.Name = "backgroundimagelabel"
        backgroundimagelabel.Parent = MainFrame
        backgroundimagelabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        backgroundimagelabel.BackgroundTransparency = 1.00
        backgroundimagelabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
        backgroundimagelabel.BorderSizePixel = 0
        backgroundimagelabel.Size = UDim2.new(1, 0, 1, 0)
        backgroundimagelabel.ZIndex = 0
        backgroundimagelabel.Image = getcustomasset("banner.png")
        backgroundimagelabel.ImageColor3 = Color3.fromRGB(116, 116, 116)
        backgroundimagelabel.ScaleType = Enum.ScaleType.Crop

        UICorner_4.CornerRadius = UDim.new(0, 5)
        UICorner_4.Parent = backgroundimagelabel

        Frame_3.Parent = MainFrame
        Frame_3.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        Frame_3.BackgroundTransparency = 0.650
        Frame_3.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Frame_3.BorderSizePixel = 0
        Frame_3.Position = UDim2.new(0, 1, 0, 50)
        Frame_3.Size = UDim2.new(0, 160, 1, -50)

        NavigationBar.Parent = Frame_3
        NavigationBar.Active = true
        NavigationBar.AnchorPoint = Vector2.new(0, 0.5)
        NavigationBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        NavigationBar.BackgroundTransparency = 1.000
        NavigationBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
        NavigationBar.BorderSizePixel = 0
        NavigationBar.Position = UDim2.new(0, 0, 0.5, 0)
        NavigationBar.Size = UDim2.new(1, 0, 1, -6)
        NavigationBar.ScrollBarThickness = 2
        NavigationBar.ScrollBarImageColor3 = Color3.fromRGB(112, 131, 255)
        NavigationBar.ScrollBarImageTransparency = 0.4
        NavigationBar.CanvasSize = UDim2.new(0, 0, 0, 0)
        NavigationBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
        NavigationBar.ScrollingDirection = Enum.ScrollingDirection.Y
        NavigationBar.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
        NavigationBar.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
        NavigationBar.ClipsDescendants = true
        addShadow(NavigationBar)
        SmoothScroll.Enable(NavigationBar, 2, 0.9)

        UIListLayout.Parent = NavigationBar
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Padding = UDim.new(0, 4)
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        
        local PageHolder = Instance.new("Frame")
        PageHolder.Name = "PageHolder"
        PageHolder.Parent = MainFrame
        PageHolder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        PageHolder.BackgroundTransparency = 1.000
        PageHolder.BorderColor3 = Color3.fromRGB(0, 0, 0)
        PageHolder.BorderSizePixel = 0
        PageHolder.Position = UDim2.new(0, 161, 0, 50)
        PageHolder.Size = UDim2.new(1, -159, 1, -60)
        PageHolder.ClipsDescendants = true
        
        local Window = {}
        local TabStore = {}

        local function scoreMatch(feature, query)
            local fl = feature:lower()
            local score = 0

            if fl == query then return 100 end

            -- Multi-word: all words must appear
            local queryWords = {}
            for w in query:gmatch("%S+") do table.insert(queryWords, w) end

            if #queryWords > 1 then
                for _, qw in ipairs(queryWords) do
                    if not fl:find(qw, 1, true) then return 0 end
                    score = score + 1
                end
                -- Bonus: feature contains exact full query as substring
                if fl:find(query, 1, true) then score = score + 3 end
                if fl == query then return 100 end
                score = score - (#fl / 20)
                return score
            end

            -- Single word path (your existing logic)
            local s = fl:find(query, 1, true)
            if not s then return 0 end
            score = score + 1
            if s == 1 then score = score + 4 end
            for word in fl:gmatch("%S+") do
                if word:sub(1, #query) == query then score = score + 3; break end
                if word == query then score = score + 5; break end
            end
            score = score - (#fl / 20)
            return score
        end

        local function search(query)
            query = query:lower()
            local bestScore = 0
            local bestTab = nil

            for i, v in pairs(TabStore) do
                local tabScore = 0
                for _, f in pairs(v.Features) do
                    tabScore = tabScore + scoreMatch(f, query)
                end
                v.Frame.Visible = tabScore > 0
                if tabScore > bestScore then
                    bestScore = tabScore
                    bestTab = i
                end
            end

            if bestTab then
                Window:SelectTab(bestTab)
            end
        end

        TextBox:GetPropertyChangedSignal("Text"):Connect(function()
            local text = TextBox.Text
            if text ~= "" then
                search(text)
            else
                for _, v in pairs(TabStore) do
                    v.Frame.Visible = true
                end
            end
        end)
        
        function Window:CreateTab(Name, Icon)
            local TabButton = Instance.new("Frame")
            local Frame = Instance.new("Frame")
            local TextLabel = Instance.new("TextLabel")
            local ImageLabel = Instance.new("ImageLabel")
            local Asset = getIcon(Icon)
            local Page = Instance.new("Frame")
            local NFrame = Instance.new("Frame")
            local NTextLabel = Instance.new("TextLabel")
            local ScrollingFrame = Instance.new("ScrollingFrame")
            local UIListLayout = Instance.new("UIListLayout")

            Page.Name = "Page"
            Page.Parent = PageHolder
            Page.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Page.BackgroundTransparency = 1.000
            Page.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Page.BorderSizePixel = 0
            Page.Position = UDim2.new(0, 0, 0, -30)
            Page.Size = UDim2.new(1, 0, 1, 0)
            Page.Visible = false

            NFrame.Parent = Page
            NFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            NFrame.BackgroundTransparency = 0.750
            NFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            NFrame.BorderSizePixel = 0
            NFrame.Size = UDim2.new(1, -1, 0, 28)
            NFrame.Position = UDim2.fromOffset(-1, 0)

            NTextLabel.Parent = NFrame
            NTextLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            NTextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            NTextLabel.BackgroundTransparency = 1.000
            NTextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
            NTextLabel.BorderSizePixel = 0
            NTextLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
            NTextLabel.Size = UDim2.new(1, 0, 1, 0)
            NTextLabel.Font = Enum.Font.ArialBold
            NTextLabel.Text = Name
            NTextLabel.TextColor3 = Color3.fromRGB(151, 161, 255)
            NTextLabel.TextSize = 13.000

            ScrollingFrame.Parent = Page
            ScrollingFrame.Active = true
            ScrollingFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ScrollingFrame.BackgroundTransparency = 1.000
            ScrollingFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            ScrollingFrame.BorderSizePixel = 0
            ScrollingFrame.Position = UDim2.new(0, 0, 0, 28)
            ScrollingFrame.Size = UDim2.new(1, 0, 1, -28)
            ScrollingFrame.ScrollBarThickness = 0
            ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
            ScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
            ScrollingFrame.ClipsDescendants = true
            SmoothScroll.Enable(ScrollingFrame, 4, 0.9)

            UIListLayout.Parent = ScrollingFrame
            UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            UIListLayout.Padding = UDim.new(0, 3)

            TabButton.Name = "TabButton"
            TabButton.Parent = NavigationBar
            TabButton.BackgroundColor3 = Color3.fromRGB(61, 66, 136)
            TabButton.BackgroundTransparency = 1.000
            TabButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
            TabButton.BorderSizePixel = 0
            TabButton.Size = UDim2.new(1, -4, 0, 35)

            Frame.Parent = TabButton
            Frame.BackgroundColor3 = Color3.fromRGB(151, 161, 255)
            Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Frame.BorderSizePixel = 0
            Frame.AnchorPoint = Vector2.new(0, 0)
            Frame.Position = UDim2.new(0, 0, 0, 0)
            Frame.Size = UDim2.new(0, 1, 0, 0)

            TextLabel.Parent = TabButton
            TextLabel.AnchorPoint = Vector2.new(0, 0.5)
            TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            TextLabel.BackgroundTransparency = 1.000
            TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
            TextLabel.BorderSizePixel = 0
            TextLabel.Position = UDim2.new(0, 30, 0.5, 0)
            TextLabel.Size = UDim2.new(0, 200, 0, 20)
            TextLabel.Font = Enum.Font.ArialBold
            TextLabel.Text = Name
            TextLabel.TextColor3 = Color3.fromRGB(161, 161, 161)
            TextLabel.TextSize = 13.000
            TextLabel.TextXAlignment = Enum.TextXAlignment.Left

            ImageLabel.Parent = TabButton
            ImageLabel.AnchorPoint = Vector2.new(0, 0.5)
            ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ImageLabel.BackgroundTransparency = 1.000
            ImageLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
            ImageLabel.BorderSizePixel = 0
            ImageLabel.Position = UDim2.new(0, 7, 0.5, 0)
            ImageLabel.Size = UDim2.new(0, 16, 0, 16)
            ImageLabel.Image = Asset.id
            ImageLabel.ImageColor3 = Color3.fromRGB(161, 161, 161)
            ImageLabel.ImageRectOffset = Asset.imageRectOffset
            ImageLabel.ImageRectSize = Asset.imageRectSize
            ImageLabel.ScaleType = Enum.ScaleType.Fit

            local TInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear)
            local sepTween = nil

            local function SetSepAnchor(anchorY)
                Frame.AnchorPoint = Vector2.new(0, anchorY)
                Frame.Position = UDim2.new(0, Frame.Position.X.Offset, anchorY, Frame.Position.Y.Offset)
            end

            local function DeselectDirectional(goingDown, callback)
                Page.Position = UDim2.new(0, 0, 0, -10)
                Page.Visible = false
                TweenService:Create(TabButton, TInfo, {BackgroundTransparency = 1}):Play()
                TweenService:Create(TextLabel, TInfo, {TextColor3 = Color3.fromRGB(161, 161, 161)}):Play()
                TweenService:Create(ImageLabel, TInfo, {ImageColor3 = Color3.fromRGB(161, 161, 161)}):Play()
                SetSepAnchor(goingDown and 1 or 0) -- shrink toward new tab
                if sepTween then sepTween:Cancel() end
                sepTween = TweenService:Create(Frame, TInfo, {Size = UDim2.new(0, 1, 0, 0)})
                if callback then
                    sepTween.Completed:Connect(callback)
                end
                sepTween:Play()
            end

            local function SelectDirectional(goingDown)
                Page.Visible = true
                TweenService:Create(Page, TweenInfo.new(0.2), {Position = UDim2.fromOffset(0, 0)}):Play()
                TweenService:Create(TabButton, TInfo, {BackgroundTransparency = 0.65}):Play()
                TweenService:Create(TextLabel, TInfo, {TextColor3 = Color3.fromRGB(151, 161, 255)}):Play()
                TweenService:Create(ImageLabel, TInfo, {ImageColor3 = Color3.fromRGB(151, 161, 255)}):Play()
                SetSepAnchor(goingDown and 0 or 1) -- grow from direction it came from
                if sepTween then sepTween:Cancel() end
                Frame.Size = UDim2.new(0, 1, 0, 0)
                sepTween = TweenService:Create(Frame, TInfo, {Size = UDim2.new(0, 1, 1, 0)})
                sepTween:Play()
            end

            local this = {
                IsSelected = false,
                Frame = TabButton,
                Deselect = function() DeselectDirectional(true, nil) end,
                Select = function() SelectDirectional(true) end,
                DeselectDirectional = DeselectDirectional,
                SelectDirectional = SelectDirectional,
                Index = #TabStore + 1,
                Features = {},
                NumSections = 0
            }
            TabStore[#TabStore+1] = this

            local Click = Instance.new("TextButton")
            Click.Parent = TabButton
            Click.Text = ""
            Click.ZIndex = 2
            Click.BackgroundTransparency = 1
            Click.BorderSizePixel = 0
            Click.Size = UDim2.fromScale(1, 1)

            Click.MouseButton1Click:Connect(function()
                if this.IsSelected then return end

                local goingDown = true
                local prevTab = nil
                for _, v in pairs(TabStore) do
                    if v.IsSelected then
                        goingDown = this.Index > v.Index
                        prevTab = v
                        break
                    end
                end

                for _, v in pairs(TabStore) do
                    v.IsSelected = false
                end
                this.IsSelected = true

                if prevTab then
                    prevTab.DeselectDirectional(goingDown, function()
                        if this.IsSelected then
                            SelectDirectional(goingDown)
                        end
                    end)
                else
                    SelectDirectional(goingDown)
                end
            end)

            Click.MouseEnter:Connect(function()
                this.IsHover = true
                if not this.IsSelected then
                    TweenService:Create(TabButton, TInfo, {BackgroundTransparency = 0.8}):Play()
                end
            end)

            Click.MouseLeave:Connect(function()
                this.IsHover = false
                if not this.IsSelected then
                    TweenService:Create(TabButton, TInfo, {BackgroundTransparency = 1}):Play()
                end
            end)
            
            Click.MouseButton1Down:Connect(function()
                if not this.IsSelected then
                    TweenService:Create(TabButton, TInfo, {BackgroundTransparency = 0.7}):Play()
                end
            end)
            
            Click.MouseButton1Up:Connect(function()
                if not this.IsSelected then
                    if this.IsHover then
                        TweenService:Create(TabButton, TInfo, {BackgroundTransparency = 0.8}):Play()
                    else
                        TweenService:Create(TabButton, TInfo, {BackgroundTransparency = 1}):Play()
                    end
                end
            end)
            
            local Tab = {}
            
            function Tab:CreateSection(Name)
                this.NumSections = this.NumSections + 1
                if this.NumSections > 1 then
                    local filler = Instance.new("Frame", ScrollingFrame)
                    filler.BackgroundTransparency = 1
                    filler.Size = UDim2.new(0, 0, 0, 10)
                end
                --table.insert(this.Features, Name)
                local Section = Instance.new("Frame")
                local TextLabel = Instance.new("TextLabel")

                Section.Name = "Section"
                Section.Parent = ScrollingFrame
                Section.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Section.BackgroundTransparency = 1.000
                Section.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Section.BorderSizePixel = 0
                Section.Size = UDim2.new(1, 0, 0, 28)

                TextLabel.Parent = Section
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.BackgroundTransparency = 1.000
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BorderSizePixel = 0
                TextLabel.Position = UDim2.new(0, 10, 0, 0)
                TextLabel.Size = UDim2.new(1, -20, 1, 0)
                TextLabel.Font = Enum.Font.ArialBold
                TextLabel.Text = Name
                TextLabel.TextColor3 = Color3.fromRGB(199, 199, 199)
                TextLabel.TextSize = 13.000
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left
                TextLabel.ZIndex = 2
                local tlc = TextLabel:Clone()
                tlc.ZIndex = 1
                tlc.TextColor3 = Color3.fromRGB(0, 0, 0)
                tlc.Position = TextLabel.Position + UDim2.fromOffset(1, 1)
                tlc.Parent = TextLabel.Parent

                return {
                    Set = function(self, New)
                        TextLabel.Text = New
                        tlc.Text = New
                    end
                }
            end

            function Tab:CreateLabel(Text)
                local Toggle = Instance.new("Frame")
                local TextLabel = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")

                Toggle.Name = "Toggle"
                Toggle.Parent = ScrollingFrame
                Toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Toggle.BackgroundTransparency = 0.450
                Toggle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Toggle.BorderSizePixel = 0
                Toggle.Size = UDim2.new(1, -10, 0, 28)

                TextLabel.Parent = Toggle
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.BackgroundTransparency = 1.000
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BorderSizePixel = 0
                TextLabel.Position = UDim2.new(0, 10, 0, 0)
                TextLabel.Size = UDim2.new(0.5, 0, 0, 28)
                TextLabel.Font = Enum.Font.ArialBold
                TextLabel.Text = Text
                TextLabel.TextColor3 = Color3.fromRGB(145, 145, 145)
                TextLabel.TextSize = 13.000
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left

                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Toggle

                return {
                    Set = function(self, New)
                        TextLabel.Text = New
                    end
                }
            end
            
            function Tab:CreateToggle(Properties)
                local Flag = Properties.Flag
                local CurrentValue = Properties.CurrentValue
                local Name = Properties.Name
                local Callback = Properties.Callback or function() end
                Window.Flags[Flag] = {CurrentValue = CurrentValue}
                table.insert(this.Features, Name)
                
                local Toggle = Instance.new("Frame")
                local TextLabel = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")
                local Switch = Instance.new("Frame")
                local UICorner_2 = Instance.new("UICorner")
                local ball = Instance.new("Frame")
                local UICorner_3 = Instance.new("UICorner")

                Toggle.Name = "Toggle"
                Toggle.Parent = ScrollingFrame
                Toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Toggle.BackgroundTransparency = 0.450
                Toggle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Toggle.BorderSizePixel = 0
                Toggle.Size = UDim2.new(1, -10, 0, 28)

                TextLabel.Parent = Toggle
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.BackgroundTransparency = 1.000
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BorderSizePixel = 0
                TextLabel.Position = UDim2.new(0, 10, 0, 0)
                TextLabel.Size = UDim2.new(0.5, 0, 0, 28)
                TextLabel.Font = Enum.Font.ArialBold
                TextLabel.Text = Name
                TextLabel.TextColor3 = Color3.fromRGB(199, 199, 199)
                TextLabel.TextSize = 13.000
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left

                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Toggle

                Switch.Name = "Switch"
                Switch.Parent = Toggle
                Switch.AnchorPoint = Vector2.new(1, 0.5)
                Switch.BackgroundColor3 = Color3.fromRGB(67, 67, 67)
                Switch.BackgroundTransparency = 0.700
                Switch.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Switch.BorderSizePixel = 0
                Switch.Position = UDim2.new(1, -4, 0.5, 0)
                Switch.Size = UDim2.new(0, 48, 0, 20)

                UICorner_2.CornerRadius = UDim.new(1, 0)
                UICorner_2.Parent = Switch

                ball.Name = "ball"
                ball.Parent = Switch
                ball.AnchorPoint = Vector2.new(0, 0.5)
                ball.BackgroundColor3 = Color3.fromRGB(62, 62, 62)
                ball.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ball.BorderSizePixel = 0
                ball.Position = UDim2.new(0, 2, 0.5, 0)
                ball.Size = UDim2.new(0, 16, 0, 16)

                UICorner_3.CornerRadius = UDim.new(1, 0)
                UICorner_3.Parent = ball
                
                local Click = Instance.new("TextButton")
                Click.Parent = Switch
                Click.Text = ""
                Click.ZIndex = 2
                Click.BackgroundTransparency = 1
                Click.BorderSizePixel = 0
                Click.Size = UDim2.fromScale(1, 1)
                
                local TInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine)
                
                local function animation()
                    if CurrentValue then
                        TweenService:Create(Switch, TInfo, {BackgroundColor3 = Color3.fromRGB(69, 81, 147)}):Play()
                        TweenService:Create(ball, TInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                        TweenService:Create(ball, TInfo, {Position = UDim2.new(0, 30, 0.5, 0)}):Play()
                    else
                        TweenService:Create(Switch, TInfo, {BackgroundColor3 = Color3.fromRGB(67, 67, 67)}):Play()
                        TweenService:Create(ball, TInfo, {BackgroundColor3 = Color3.fromRGB(62, 62, 62)}):Play()
                        TweenService:Create(ball, TInfo, {Position = UDim2.new(0, 2, 0.5, 0)}):Play()
                    end
                end

                local F = Window.Flags[Flag]
                function F:Set(New, IsSave)
                    CurrentValue = New
                    Window.Flags[Flag].CurrentValue = CurrentValue
                    animation()
                    task.spawn(function()
                        Callback(New, IsSave)
                    end)
                end

                if ((SaveTable[Flag] or {}).CurrentValue == true and not Properties.NoSave) or CurrentValue then
                    F:Set(true, true)
                end
                
                Click.MouseButton1Click:Connect(function()
                    F:Set(not CurrentValue)
                end)
                
                Click.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch
                    then
                        TweenService:Create(ball, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {Size = UDim2.new(0, 16, 0, 10)}):Play()
                    end
                end)
                
                Click.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch
                    then
                        TweenService:Create(ball, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {Size = UDim2.new(0, 16, 0, 16)}):Play()
                    end
                end)

                return F
            end
            
            function Tab:CreateButton(Properties)
                local Name = Properties.Name
                local Callback = Properties.Callback or function() end
                table.insert(this.Features, Name)
                
                local Button = Instance.new("Frame")
                local TextLabel = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")
                local ImageLabel = Instance.new("ImageLabel")

                Button.Name = "Button"
                Button.Parent = ScrollingFrame
                Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Button.BackgroundTransparency = 0.450
                Button.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Button.BorderSizePixel = 0
                Button.Size = UDim2.new(1, -10, 0, 32)
                Button.ClipsDescendants = true

                TextLabel.Parent = Button
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.BackgroundTransparency = 1.000
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BorderSizePixel = 0
                TextLabel.Position = UDim2.new(0, 10, 0, 0)
                TextLabel.Size = UDim2.new(0.5, 0, 0, 32)
                TextLabel.Font = Enum.Font.ArialBold
                TextLabel.Text = Name
                TextLabel.TextColor3 = Color3.fromRGB(199, 199, 199)
                TextLabel.TextSize = 13.000
                TextLabel.TextXAlignment = Enum.TextXAlignment.Left

                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Button

                local mouseasset = getIcon("mouse-pointer-2")
                ImageLabel.Parent = Button
                ImageLabel.AnchorPoint = Vector2.new(1, 0.5)
                ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ImageLabel.BackgroundTransparency = 1.000
                ImageLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ImageLabel.BorderSizePixel = 0
                ImageLabel.Position = UDim2.new(1, -4, 0.5, 0)
                ImageLabel.Size = UDim2.new(0, 20, 0, 20)
                ImageLabel.Image = mouseasset.id
                ImageLabel.ImageRectOffset = mouseasset.imageRectOffset
                ImageLabel.ImageRectSize = mouseasset.imageRectSize
                
                Button.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch
                    then
                        task.spawn(function()
                            Callback()
                        end)
                        local absPos = Button.AbsolutePosition
                        local localX = input.Position.X - absPos.X
                        local localY = input.Position.Y - absPos.Y
                        createRipple(Button, localX, localY)
                    end
                end)
            end
            
            function Tab:CreateSlider(Properties)
                local Name = Properties.Name
                local Range = Properties.Range
                local Min = Range[1]
                local Max = Range[2]
                local CurrentValue = Properties.CurrentValue
                local Flag = Properties.Flag
                Window.Flags[Flag] = {CurrentValue = CurrentValue}
                local Callback = Properties.Callback or function() end
                local Suffix = Properties.Suffix or ""
                local Increment = Properties.Increment
                table.insert(this.Features, Name)

                local Slider = Instance.new("Frame")
                local SliderName = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")
                local Bar = Instance.new("Frame")
                local UICorner_2 = Instance.new("UICorner")
                local Ball = Instance.new("Frame")
                local UICorner_3 = Instance.new("UICorner")
                local Fill = Instance.new("Frame")
                local UICorner_4 = Instance.new("UICorner")
                Slider.Name = "Slider"
                Slider.Parent = ScrollingFrame
                Slider.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Slider.BackgroundTransparency = 0.450
                Slider.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Slider.BorderSizePixel = 0
                Slider.Size = UDim2.new(1, -10, 0, 32)
                SliderName.Name = "SliderName"
                SliderName.Parent = Slider
                SliderName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderName.BackgroundTransparency = 1.000
                SliderName.BorderColor3 = Color3.fromRGB(0, 0, 0)
                SliderName.BorderSizePixel = 0
                SliderName.Position = UDim2.new(0, 10, 0, 0)
                SliderName.Size = UDim2.new(0.5, 0, 0, 32)
                SliderName.Font = Enum.Font.ArialBold
                SliderName.Text = Name
                SliderName.TextColor3 = Color3.fromRGB(199, 199, 199)
                SliderName.TextSize = 13.000
                SliderName.TextXAlignment = Enum.TextXAlignment.Left
                SliderName.RichText = true
                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Slider
                Bar.Name = "Bar"
                Bar.Parent = Slider
                Bar.AnchorPoint = Vector2.new(1, 0.5)
                Bar.BackgroundColor3 = Color3.fromRGB(109, 109, 129)
                Bar.BackgroundTransparency = 0.500
                Bar.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Bar.BorderSizePixel = 0
                Bar.Position = UDim2.new(1, -16, 0.5, 0)
                Bar.Size = UDim2.new(0, 120, 0, 6)
                UICorner_2.CornerRadius = UDim.new(1, 0)
                UICorner_2.Parent = Bar
                Ball.Name = "Ball"
                Ball.Parent = Bar
                Ball.AnchorPoint = Vector2.new(0.5, 0.5)
                Ball.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Ball.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Ball.BorderSizePixel = 0
                Ball.Position = UDim2.new(0.5, 0, 0.5, 0)
                Ball.Size = UDim2.new(0, 16, 0, 16)
                Ball.ZIndex = 2
                UICorner_3.CornerRadius = UDim.new(1, 0)
                UICorner_3.Parent = Ball
                Fill.Name = "Fill"
                Fill.Parent = Bar
                Fill.BackgroundColor3 = Color3.fromRGB(103, 136, 255)
                Fill.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Fill.BorderSizePixel = 0
                Fill.Size = UDim2.new(0.5, 0, 1, 0)
                UICorner_4.CornerRadius = UDim.new(1, 0)
                UICorner_4.Parent = Fill
                
                -- Add after UICorner_4.Parent = Fill

                local BAR_DEFAULT_SIZE = UDim2.new(0, 120, 0, 6)
                local BAR_HOVER_SIZE = UDim2.new(0, 120, 0, 9)
                local BALL_DEFAULT_SIZE = UDim2.new(0, 16, 0, 16)
                local BALL_HOVER_SIZE = UDim2.new(0, 20, 0, 20)
                local TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

                local function valueToAlpha(val)
                    return (val - Min) / (Max - Min)
                end

                local function alphaToValue(alpha)
                    local raw = alpha * (Max - Min) + Min
                    local stepped = math.round(raw / Increment) * Increment
                    local decimals = math.max(0, math.ceil(-math.log10(Increment)))
                    return tonumber(string.format("%." .. decimals .. "f", math.clamp(stepped, Min, Max)))
                end

                local function updateVisuals(alpha, tween)
                    local val = alphaToValue(alpha)
                    SliderName.Text = Name .. " <font color=\"rgb(103, 136, 255)\">" .. val .. "<font color=\"rgb(141, 141, 141)\">" .. Suffix .. "</font></font>"
                    local targetFill = UDim2.new(alpha, 0, 1, 0)
                    local targetBall = UDim2.new(alpha, 0, 0.5, 0)
                    if tween then
                        TweenService:Create(Fill, TWEEN_INFO, {Size = targetFill}):Play()
                        TweenService:Create(Ball, TWEEN_INFO, {Position = targetBall}):Play()
                    else
                        Fill.Size = targetFill
                        Ball.Position = targetBall
                    end
                end

                if SaveTable[Flag] then
                    CurrentValue = SaveTable[Flag].CurrentValue
                    Window.Flags[Flag] = {CurrentValue = CurrentValue}
                    task.spawn(function()
                        Callback(CurrentValue)
                    end)
                end

                -- Set initial visuals without callback
                updateVisuals(valueToAlpha(CurrentValue), false)

                local dragging = false

                local function onDrag(inputX)
                    local barPos = Bar.AbsolutePosition.X
                    local barSize = Bar.AbsoluteSize.X
                    local alpha = math.clamp((inputX - barPos) / barSize, 0, 1)
                    local newValue = alphaToValue(alpha)
                    if newValue ~= Window.Flags[Flag].CurrentValue then
                        Window.Flags[Flag].CurrentValue = newValue
                        updateVisuals(valueToAlpha(newValue), true)
                        SliderName.Text = Name .. " <font color=\"rgb(103, 136, 255)\">" .. newValue .. "<font color=\"rgb(141, 141, 141)\">" .. Suffix .. "</font></font>"
                        Callback(newValue)
                    end
                end

                -- Hover
                local Hover = false
                local Hover2 = false
                Bar.MouseEnter:Connect(function()
                    Hover = true
                    TweenService:Create(Bar, TWEEN_INFO, {Size = BAR_HOVER_SIZE}):Play()
                    TweenService:Create(Ball, TWEEN_INFO, {Size = BALL_HOVER_SIZE}):Play()
                end)
                Bar.MouseLeave:Connect(function()
                    Hover = false
                    if not Hover2 and not dragging then
                        TweenService:Create(Bar, TWEEN_INFO, {Size = BAR_DEFAULT_SIZE}):Play()
                        TweenService:Create(Ball, TWEEN_INFO, {Size = BALL_DEFAULT_SIZE}):Play()
                    end
                end)
                Ball.MouseEnter:Connect(function()
                    Hover2 = true
                    TweenService:Create(Bar, TWEEN_INFO, {Size = BAR_HOVER_SIZE}):Play()
                    TweenService:Create(Ball, TWEEN_INFO, {Size = BALL_HOVER_SIZE}):Play()
                end)
                Ball.MouseLeave:Connect(function()
                    Hover2 = false
                    if not Hover and not dragging then
                        TweenService:Create(Bar, TWEEN_INFO, {Size = BAR_DEFAULT_SIZE}):Play()
                        TweenService:Create(Ball, TWEEN_INFO, {Size = BALL_DEFAULT_SIZE}):Play()
                    end
                end)
                
                Ball.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        onDrag(input.Position.X)
                    end
                end)

                -- Mouse
                Bar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        onDrag(input.Position.X)
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        onDrag(input.Position.X)
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                        dragging = false
                        if input.UserInputType == Enum.UserInputType.Touch or (not Hover and not Hover2) then
                            TweenService:Create(Bar, TWEEN_INFO, {Size = BAR_DEFAULT_SIZE}):Play()
                            TweenService:Create(Ball, TWEEN_INFO, {Size = BALL_DEFAULT_SIZE}):Play()
                        end
                    end
                end)

                -- Init label
                SliderName.Text = Name .. " <font color=\"rgb(103, 136, 255)\">" .. CurrentValue .. "<font color=\"rgb(141, 141, 141)\">" .. Suffix .. "</font></font>"
            end
            
            function Tab:CreateDropdown(Properties)
                local Name = Properties.Name
                local Flag = Properties.Flag
                local CurrentOption = Properties.CurrentOption
                local Options = Properties.Options
                local MultipleOptions = Properties.MultipleOptions
                local Callback = Properties.Callback or function() end
                table.insert(this.Features, Name)
                
                local Dropdown = Instance.new("Frame")
                local DropdownName = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")
                local ImageLabel = Instance.new("ImageLabel")
                local ScrollingFrame2 = Instance.new("ScrollingFrame")
                local UIListLayout = Instance.new("UIListLayout")

                Dropdown.Name = "Dropdown"
                Dropdown.Parent = ScrollingFrame
                Dropdown.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Dropdown.BackgroundTransparency = 0.450
                Dropdown.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Dropdown.BorderSizePixel = 0
                Dropdown.ClipsDescendants = true
                Dropdown.Size = UDim2.new(1, -10, 0, 32)
                Dropdown.ClipsDescendants = true

                DropdownName.Name = "SliderName"
                DropdownName.Parent = Dropdown
                DropdownName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                DropdownName.BackgroundTransparency = 1.000
                DropdownName.BorderColor3 = Color3.fromRGB(0, 0, 0)
                DropdownName.BorderSizePixel = 0
                DropdownName.Position = UDim2.new(0, 10, 0, 0)
                DropdownName.Size = UDim2.new(0.5, 0, 0, 32)
                DropdownName.Font = Enum.Font.ArialBold
                DropdownName.TextColor3 = Color3.fromRGB(199, 199, 199)
                DropdownName.TextSize = 13.000
                DropdownName.TextXAlignment = Enum.TextXAlignment.Left
                DropdownName.RichText = true

                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Dropdown

                ImageLabel.Parent = Dropdown
                ImageLabel.AnchorPoint = Vector2.new(1, 0)
                ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ImageLabel.BackgroundTransparency = 1.000
                ImageLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ImageLabel.BorderSizePixel = 0
                ImageLabel.Position = UDim2.new(1, -4, 0, 6)
                ImageLabel.Size = UDim2.new(0, 20, 0, 20)
                ImageLabel.Image = "rbxassetid://130996747355335"

                ScrollingFrame2.Parent = Dropdown
                ScrollingFrame2.Active = true
                ScrollingFrame2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ScrollingFrame2.BackgroundTransparency = 1.000
                ScrollingFrame2.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ScrollingFrame2.BorderSizePixel = 0
                ScrollingFrame2.Position = UDim2.new(0, 10, 0, 32)
                ScrollingFrame2.Size = UDim2.new(1, -20, 1, -42)
                ScrollingFrame2.ScrollBarThickness = 0
                ScrollingFrame2.AutomaticCanvasSize = Enum.AutomaticSize.Y
                ScrollingFrame2.CanvasSize = UDim2.new(0, 0, 0, 0)
                ScrollingFrame2.Visible = false

                UIListLayout.Parent = ScrollingFrame2
                UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout.Padding = UDim.new(0, 4)

                local function ValuesToTable(vals)
                    local a = {}
                    for i, _ in pairs(vals) do
                        if _ == true then
                            table.insert(a, i)
                        end
                    end
                    return a
                end

                local function DeepEqual(a, b)
                    if type(a) ~= type(b) then return false end
                    if type(a) ~= "table" then return a == b end
                    for k, v in pairs(a) do
                        if not DeepEqual(v, b[k]) then return false end
                    end
                    for k in pairs(b) do
                        if a[k] == nil then return false end
                    end
                    return true
                end

                if (SaveTable[Flag] or {}).CurrentOption and not DeepEqual(SaveTable[Flag].CurrentOption, Options) then
                    CurrentOption = ValuesToTable(SaveTable[Flag].CurrentOption)
                    task.spawn(function()
                        Callback(CurrentOption,true)
                    end)
                end
                local Values = {}
                for i, v in pairs(Options) do
                    Values[v] = false
                end
                for i, v in pairs(CurrentOption) do
                    Values[v] = true
                end
                Window.Flags[Flag] = {CurrentOption = Values}
                
                local Click = Instance.new("TextButton")
                Click.Parent = Dropdown
                Click.Text = ""
                Click.ZIndex = 2
                Click.BackgroundTransparency = 1
                Click.BorderSizePixel = 0
                Click.Size = UDim2.new(1, 0, 0, 32)
                
                local shadow
                if #Options > 3 then
                    shadow = addShadow(ScrollingFrame2)
                    shadow.Visible = false
                end
                
                local Opened = false
                Click.MouseButton1Click:Connect(function(input)
                    Opened = not Opened
                    if shadow then
                        shadow.Visible = Opened
                    end
                    ScrollingFrame2.Visible = Opened
                    if Opened then
                        local NewY = math.clamp(38 + (#Options * (28 + UIListLayout.Padding.Offset)), 0, 38 + (3 * (28 + UIListLayout.Padding.Offset)))
                        TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(Dropdown.Size.X.Scale, Dropdown.Size.X.Offset, Dropdown.Size.Y.Scale, NewY)}):Play()
                    else
                        ScrollingFrame2.CanvasPosition = Vector2.new(0, 0)
                        TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(Dropdown.Size.X.Scale, Dropdown.Size.X.Offset, Dropdown.Size.Y.Scale, 32)}):Play()
                    end
                end)
                
                local DropdownData = {
                    __DropdownOptions = {}
                }
                local function GetGoodstring(tbl)
                    local John = {}
                    
                    for i, v in pairs(tbl) do
                        if v == true then
                            table.insert(John, tostring(i))
                        end
                    end
                    
                    return #John == 1 and John[1] or ((#John == 0 and "no" or #John) .. " options")
                end
                
                function DropdownData:SetTitle(NewTitle)
                    Name = NewTitle
                    DropdownName.Text = Name .. " <font color=\"rgb(100, 100, 100)\">" .. GetGoodstring(Values) .. "</font>"
                end
                
                DropdownData:SetTitle(Name)
                            
                local function RefreshDropdown(List)
                    for i, v in pairs(ScrollingFrame2:GetChildren()) do
                        if v.Name == "Option" then
                            v:Destroy()
                        end
                    end
                    for i, v in pairs(List) do
                        local Option = Instance.new("Frame")
                        local UICorner_2 = Instance.new("UICorner")
                        local OName = Instance.new("TextLabel")
                        local ONameShadow = Instance.new("TextLabel")
                        
                        Option.Name = "Option"
                        Option.Parent = ScrollingFrame2
                        Option.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                        Option.BackgroundTransparency = 0.800
                        Option.BorderColor3 = Color3.fromRGB(0, 0, 0)
                        Option.BorderSizePixel = 0
                        Option.Size = UDim2.new(1, 0, 0, 28)
                        Option.ClipsDescendants = true

                        UICorner_2.CornerRadius = UDim.new(0, 5)
                        UICorner_2.Parent = Option

                        OName.Name = "OName"
                        OName.Parent = Option
                        OName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        OName.BackgroundTransparency = 1.000
                        OName.BorderColor3 = Color3.fromRGB(0, 0, 0)
                        OName.BorderSizePixel = 0
                        OName.Position = UDim2.new(0, 10, 0, 0)
                        OName.Size = UDim2.new(1, -20, 1, 0)
                        OName.ZIndex = 2
                        OName.Font = Enum.Font.ArialBold
                        OName.Text = tostring(v)
                        OName.TextColor3 = Color3.fromRGB(199, 199, 199)
                        OName.TextSize = 13.000
                        OName.TextXAlignment = Enum.TextXAlignment.Left

                        ONameShadow.Name = "ONameShadow"
                        ONameShadow.Parent = Option
                        ONameShadow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                        ONameShadow.BackgroundTransparency = 1.000
                        ONameShadow.BorderColor3 = Color3.fromRGB(0, 0, 0)
                        ONameShadow.BorderSizePixel = 0
                        ONameShadow.Position = UDim2.new(0, 11, 0, 1)
                        ONameShadow.Size = UDim2.new(1, -20, 1, 0)
                        ONameShadow.Font = Enum.Font.ArialBold
                        ONameShadow.Text = tostring(v)
                        ONameShadow.TextColor3 = Color3.fromRGB(0, 0, 0)
                        ONameShadow.TextSize = 13.000
                        ONameShadow.TextXAlignment = Enum.TextXAlignment.Left
                        
                        local Click = Instance.new("TextButton")
                        Click.Parent = Option
                        Click.Text = ""
                        Click.ZIndex = 2
                        Click.BackgroundTransparency = 1
                        Click.BorderSizePixel = 0
                        Click.Size = UDim2.fromScale(1, 1)
                        
                        table.insert(DropdownData.__DropdownOptions, {
                            Title = setmetatable({}, {
                                __newindex = function(a, b, c)
                                    if b == "Text" then
                                        OName.Text = c
                                        ONameShadow.Text = c
                                    end
                                end,
                            })
                        })
                        
                        local TInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear)
                        
                        Click.MouseButton1Click:Connect(function()
                            if Values[v] == true and not MultipleOptions then -- stop being able to unselect the selected option if multiple options if off, always have 1 selected
                                return
                            end
                            Values[v] = not Values[v]
                            if not MultipleOptions then
                                for e, b in pairs(Values) do
                                    if e ~= v then
                                        Values[e] = false
                                    end
                                end
                                for i, v in pairs(ScrollingFrame2:GetChildren()) do
                                    if v.Name == "Option" then
                                        TweenService:Create(v, TInfo, {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
                                        TweenService:Create(v.OName, TInfo, {TextColor3 = Color3.fromRGB(199, 199, 199)}):Play()
                                    end
                                end
                            end
                            if Values[v] then
                                TweenService:Create(Option, TInfo, {BackgroundColor3 = Color3.fromRGB(103, 136, 255)}):Play()
                                TweenService:Create(OName, TInfo, {TextColor3 = Color3.fromRGB(103, 136, 255)}):Play()
                            else
                                TweenService:Create(Option, TInfo, {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
                                TweenService:Create(OName, TInfo, {TextColor3 = Color3.fromRGB(199, 199, 199)}):Play()
                            end
                            
                            DropdownData:SetTitle(Name)
                            
                            task.spawn(function()
                                Callback(ValuesToTable(Values))
                            end)
                        end)
                        
                        Click.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1
                                or input.UserInputType == Enum.UserInputType.Touch
                            then
                                local absPos = Option.AbsolutePosition
                                local localX = input.Position.X - absPos.X
                                local localY = input.Position.Y - absPos.Y
                                createRipple(Option, localX, localY)
                            end
                        end)
                        
                        if Values[v] then
                            Option.BackgroundColor3 = Color3.fromRGB(103, 136, 255)
                            OName.TextColor3 = Color3.fromRGB(103, 136, 255)
                        end
                    end
                end
                RefreshDropdown(Options)
                
                return DropdownData
            end
            
            local TweenService = game:GetService("TweenService")

            function Tab:CreateKeybind(Properties)
                local CurrentKeybind = Properties.CurrentKeybind
                local Name = Properties.Name
                local Callback = Properties.Callback or function() end
                table.insert(this.Features, Name)

                local Keybind = Instance.new("Frame")
                local KeybindName = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")
                local Frame = Instance.new("Frame")
                local UICorner_2 = Instance.new("UICorner")
                local TextLabel = Instance.new("TextButton")
                local ImageLabel = Instance.new("ImageLabel")
                Keybind.Name = "Keybind"
                Keybind.Parent = ScrollingFrame
                Keybind.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Keybind.BackgroundTransparency = 0.450
                Keybind.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Keybind.BorderSizePixel = 0
                Keybind.ClipsDescendants = true
                Keybind.Size = UDim2.new(1, -10, 0, 28)
                KeybindName.Name = "KeybindName"
                KeybindName.Parent = Keybind
                KeybindName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                KeybindName.BackgroundTransparency = 1.000
                KeybindName.BorderColor3 = Color3.fromRGB(0, 0, 0)
                KeybindName.BorderSizePixel = 0
                KeybindName.Position = UDim2.new(0, 10, 0, 0)
                KeybindName.Size = UDim2.new(0.5, 0, 0, 32)
                KeybindName.Font = Enum.Font.ArialBold
                KeybindName.Text = Name
                KeybindName.TextColor3 = Color3.fromRGB(199, 199, 199)
                KeybindName.TextSize = 13.000
                KeybindName.TextXAlignment = Enum.TextXAlignment.Left
                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Keybind
                Frame.Parent = Keybind
                Frame.AnchorPoint = Vector2.new(1, 0.5)
                Frame.BackgroundColor3 = Color3.fromRGB(53, 53, 53)
                Frame.BackgroundTransparency = 0.700
                Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Frame.BorderSizePixel = 0
                Frame.Position = UDim2.new(1, -4, 0.5, 0)
                Frame.Size = UDim2.new(0, 30, 0, 20)
                Frame.ClipsDescendants = true
                UICorner_2.CornerRadius = UDim.new(0, 5)
                UICorner_2.Parent = Frame
                TextLabel.Parent = Frame
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.BackgroundTransparency = 1.000
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BorderSizePixel = 0
                TextLabel.Size = UDim2.new(1, 0, 1, 0)
                TextLabel.Font = Enum.Font.ArialBold
                TextLabel.Text = CurrentKeybind or ""
                TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.TextSize = 14.000
                TextLabel.ClipsDescendants = true

                ImageLabel.Parent = Frame
                ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ImageLabel.BackgroundTransparency = 1.000
                ImageLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ImageLabel.BorderSizePixel = 0
                ImageLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
                ImageLabel.Size = UDim2.new(0, 16, 0, 16)
                ImageLabel.Image = "rbxassetid://121142147574111"
                ImageLabel.Visible = false

                if CurrentKeybind == nil then
                    ImageLabel.Visible = true
                end

                local KeyInfo = {KeyCode = CurrentKeybind, Callback = Callback, Pressable = true}
                table.insert(Window.Keybinds, KeyInfo)

                local Debounce = false
                local Awaiting = false
                local PulseThread = nil

                local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local tweenInfoBounce = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

                local function SetAwaiting()
                    -- Pulse color orange to indicate waiting
                    if PulseThread then task.cancel(PulseThread) end
                    TweenService:Create(Frame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(71, 95, 175), BackgroundTransparency = 0.3}):Play()
                    TweenService:Create(TextLabel, tweenInfo, {TextColor3 = Color3.fromRGB(103, 136, 255)}):Play()
                    -- Pulsing loop
                    PulseThread = task.spawn(function()
                        while Awaiting do
                            TweenService:Create(Frame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.1}):Play()
                            task.wait(0.5)
                            TweenService:Create(Frame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.4}):Play()
                            task.wait(0.5)
                        end
                    end)
                end

                local function SetKeybind(keyName)
                    if PulseThread then task.cancel(PulseThread) PulseThread = nil end
                    TweenService:Create(Frame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(60, 180, 80), BackgroundTransparency = 0.2}):Play()
                    TweenService:Create(TextLabel, tweenInfo, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()

                    -- Set text first, then size to fit, then bounce
                    --TextLabel.Text = Replace[keyName] and tostring(Replace[keyName]) or keyName
                    task.wait() -- wait a frame for TextBounds to update
                    local targetWidth = math.max(30, TextLabel.TextBounds.X + 16)
                    local bigSize = UDim2.new(0, targetWidth + 8, 0, 24)
                    local normalSize = UDim2.new(0, targetWidth, 0, 20)

                    TweenService:Create(Frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = bigSize}):Play()
                    task.delay(0.1, function()
                        TweenService:Create(Frame, tweenInfoBounce, {Size = normalSize}):Play()
                    end)
                    task.delay(0.4, function()
                        TweenService:Create(Frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                            BackgroundColor3 = Color3.fromRGB(53, 53, 53), BackgroundTransparency = 0.700
                        }):Play()
                    end)
                end

                local function SetEmpty()
                    if PulseThread then task.cancel(PulseThread) PulseThread = nil end
                    TweenService:Create(Frame, tweenInfo, {BackgroundColor3 = Color3.fromRGB(53, 53, 53), BackgroundTransparency = 0.700}):Play()
                    TweenService:Create(TextLabel, tweenInfo, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                end

                TextLabel.MouseButton1Click:Connect(function()
                    if Debounce then return end
                    Debounce = true
                    KeyInfo.Pressable = false
                    ImageLabel.Visible = false
                    TextLabel.Text = "..."
                    Awaiting = true
                    SetAwaiting()
                    task.wait(0.1)
                    Debounce = false
                end)

                UserInputService.InputBegan:Connect(function(Input, Gpe)
                    if Gpe then return end
                    if Awaiting and Input.KeyCode.Name ~= "Unknown" then
                        local Previous = KeyInfo.KeyCode
                        KeyInfo.KeyCode = Input.KeyCode.Name
                        Awaiting = false
                        if Previous == KeyInfo.KeyCode then
                            KeyInfo.KeyCode = nil
                            ImageLabel.Visible = true
                            TextLabel.Text = ""
                            SetEmpty()
                            return
                        end
                        TextLabel.Text =  KeyInfo.KeyCode
                        SetKeybind(KeyInfo.KeyCode)
                    end
                    task.wait(0.1)
                    KeyInfo.Pressable = true
                end)
                
                local function UpdateFrameSize()
                    local textWidth = math.max(30, TextLabel.TextBounds.X + 16)
                    TweenService:Create(Frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, textWidth, 0, 20)
                    }):Play()
                end
                
                RunService.RenderStepped:Connect(UpdateFrameSize)
            end
            
            function Tab:CreateInput(Properties)
                local Name = Properties.Name
                local Flag = Properties.Flag
                local RemoveTextAfterFocusLost = Properties.RemoveTextAfterFocusLost
                local CurrentValue = Properties.CurrentValue
                local PlaceholderText = Properties.PlaceholderText
                local Callback = Properties.Callback or function() end
                table.insert(this.Features, Name)
                Window.Flags[Flag] = {CurrentValue = CurrentValue}
                
                local Input = Instance.new("Frame")
                local KeybindName = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")
                local Frame = Instance.new("Frame")
                local UICorner_2 = Instance.new("UICorner")
                local TextLabel = Instance.new("TextLabel")
                local ImageLabel = Instance.new("ImageLabel")
                local TextBox = Instance.new("TextBox")

                Input.Name = "Input"
                Input.Parent = ScrollingFrame
                Input.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Input.BackgroundTransparency = 0.450
                Input.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Input.BorderSizePixel = 0
                Input.ClipsDescendants = true
                Input.Size = UDim2.new(1, -10, 0, 28)

                KeybindName.Name = "KeybindName"
                KeybindName.Parent = Input
                KeybindName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                KeybindName.BackgroundTransparency = 1.000
                KeybindName.BorderColor3 = Color3.fromRGB(0, 0, 0)
                KeybindName.BorderSizePixel = 0
                KeybindName.Position = UDim2.new(0, 10, 0, 0)
                KeybindName.Size = UDim2.new(0.5, 0, 0, 32)
                KeybindName.Font = Enum.Font.ArialBold
                KeybindName.Text = Name
                KeybindName.TextColor3 = Color3.fromRGB(199, 199, 199)
                KeybindName.TextSize = 13.000
                KeybindName.TextXAlignment = Enum.TextXAlignment.Left

                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Input

                Frame.Parent = Input
                Frame.AnchorPoint = Vector2.new(1, 0.5)
                Frame.BackgroundColor3 = Color3.fromRGB(53, 53, 53)
                Frame.BackgroundTransparency = 0.700
                Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Frame.BorderSizePixel = 0
                Frame.ClipsDescendants = true
                Frame.Position = UDim2.new(1, -4, 0.5, 0)
                Frame.Size = UDim2.new(0, 0, 0, 20)

                UICorner_2.CornerRadius = UDim.new(0, 5)
                UICorner_2.Parent = Frame

                TextLabel.Parent = Frame
                TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.BackgroundTransparency = 1.000
                TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextLabel.BorderSizePixel = 0
                TextLabel.Size = UDim2.new(1, 0, 1, 0)
                TextLabel.Font = Enum.Font.ArialBold
                TextLabel.Text = ""
                TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextLabel.TextSize = 14.000

                ImageLabel.Parent = Frame
                ImageLabel.AnchorPoint = Vector2.new(1, 0.5)
                ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ImageLabel.BackgroundTransparency = 1.000
                ImageLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ImageLabel.BorderSizePixel = 0
                ImageLabel.Position = UDim2.new(1, -8, 0.5, 0)
                ImageLabel.Size = UDim2.new(0, 16, 0, 16)
                ImageLabel.Image = "rbxassetid://76137750753739"
                ImageLabel.ImageColor3 = Color3.fromRGB(161, 186, 255)

                TextBox.Parent = Frame
                TextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                TextBox.BackgroundTransparency = 1.000
                TextBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextBox.BorderSizePixel = 0
                TextBox.ClipsDescendants = true
                TextBox.Position = UDim2.new(0, 7, 0, 0)
                TextBox.Size = UDim2.new(1, -40, 1, 0)
                TextBox.Font = Enum.Font.ArialBold
                TextBox.PlaceholderColor3 = Color3.fromRGB(127, 127, 127)
                TextBox.PlaceholderText = PlaceholderText or "Input Text"
                TextBox.Text = CurrentValue or ""
                TextBox.TextColor3 = Color3.fromRGB(161, 186, 255)
                TextBox.TextSize = 12.000
                TextBox.TextXAlignment = Enum.TextXAlignment.Left
                TextBox.ClearTextOnFocus = false
                
                TextBox.FocusLost:Connect(function()
                    local Text = TextBox.Text
                    Window.Flags[Flag] = {CurrentValue = Text}
                    if Properties.RemoveTextAfterFocusLost then
                        TextBox.Text = ""
                    end
                    task.spawn(function()
                        Callback(Text)
                    end)
                end)

                if SaveTable[Flag] then
                    Window.Flags[Flag] = SaveTable[Flag]
                    TextBox.Text = SaveTable[Flag].CurrentValue
                    task.spawn(function()
                        Callback(TextBox.Text, true)
                    end)
                end
                
                RunService.RenderStepped:Connect(function()
                    local textWidth = math.max(30, TextBox.TextBounds.X + 50)
                    TweenService:Create(Frame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, math.clamp(textWidth, 0, 160), 0, 20)
                    }):Play()
                end)
            end
            
            function Tab:CreateColorPicker(Properties)
                local Name = Properties.Name
                local Color = Properties.Color -- default color
                local Flag = Properties.Flag
                local Callback = Properties.Callback or function() end
                Window.Flags[Flag] = {Color = Color}
                table.insert(this.Features, Name)
                
                local Colorpicker = Instance.new("Frame")
                local ColorpickerName = Instance.new("TextLabel")
                local UICorner = Instance.new("UICorner")
                local ColorIndicatorBackground = Instance.new("Frame")
                local UICorner_2 = Instance.new("UICorner")
                local ColorIndicator = Instance.new("Frame")
                local UICorner_3 = Instance.new("UICorner")
                local ColorSlider = Instance.new("Frame")
                local UIGradient = Instance.new("UIGradient")
                local UICorner_5 = Instance.new("UICorner")
                local Base = Instance.new("Frame")
                local UICorner_6 = Instance.new("UICorner")
                local UIGradient_2 = Instance.new("UIGradient")
                local Overlay = Instance.new("Frame")
                local UICorner_7 = Instance.new("UICorner")
                local UIGradient_3 = Instance.new("UIGradient")
                local HexValue = Instance.new("Frame")
                local UICorner_8 = Instance.new("UICorner")
                local HexValueText = Instance.new("TextBox")
                local FormatIndication = Instance.new("TextLabel")
                local RgbValue = Instance.new("Frame")
                local UICorner_9 = Instance.new("UICorner")
                local RgbValueText = Instance.new("TextBox")
                local FormatIndication_2 = Instance.new("TextLabel")
                local HsvValue = Instance.new("Frame")
                local UICorner_10 = Instance.new("UICorner")
                local HsvValueText = Instance.new("TextBox")
                local FormatIndication_3 = Instance.new("TextLabel")

                Colorpicker.Name = "Colorpicker"
                Colorpicker.Parent = ScrollingFrame
                Colorpicker.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Colorpicker.BackgroundTransparency = 0.450
                Colorpicker.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Colorpicker.BorderSizePixel = 0
                Colorpicker.ClipsDescendants = true
                Colorpicker.Size = UDim2.new(1, -10, 0, 140)

                ColorpickerName.Name = "SliderName"
                ColorpickerName.Parent = Colorpicker
                ColorpickerName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ColorpickerName.BackgroundTransparency = 1.000
                ColorpickerName.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ColorpickerName.BorderSizePixel = 0
                ColorpickerName.Position = UDim2.new(0, 10, 0, 0)
                ColorpickerName.Size = UDim2.new(0.5, 0, 0, 32)
                ColorpickerName.Font = Enum.Font.ArialBold
                ColorpickerName.Text = Name
                ColorpickerName.TextColor3 = Color3.fromRGB(199, 199, 199)
                ColorpickerName.TextSize = 13.000
                ColorpickerName.TextXAlignment = Enum.TextXAlignment.Left

                UICorner.CornerRadius = UDim.new(0, 5)
                UICorner.Parent = Colorpicker

                ColorIndicatorBackground.Name = "ColorIndicatorBackground"
                ColorIndicatorBackground.Parent = Colorpicker
                ColorIndicatorBackground.AnchorPoint = Vector2.new(1, 0.5)
                ColorIndicatorBackground.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                ColorIndicatorBackground.BackgroundTransparency = 0.300
                ColorIndicatorBackground.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ColorIndicatorBackground.BorderSizePixel = 0
                ColorIndicatorBackground.Position = UDim2.new(1, -4, 0, 16)
                ColorIndicatorBackground.Size = UDim2.new(0, 50, 0, 20)

                UICorner_2.CornerRadius = UDim.new(0, 5)
                UICorner_2.Parent = ColorIndicatorBackground

                ColorIndicator.Name = "ColorIndicator"
                ColorIndicator.Parent = Colorpicker
                ColorIndicator.AnchorPoint = Vector2.new(1, 0.5)
                ColorIndicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                ColorIndicator.BorderColor3 = Color3.fromRGB(0, 0, 0)
                ColorIndicator.BorderSizePixel = 0
                ColorIndicator.Position = UDim2.new(1, -6, 0, 16)
                ColorIndicator.Size = UDim2.new(0, 46, 0, 16)

                UICorner_3.CornerRadius = UDim.new(0, 4)
                UICorner_3.Parent = ColorIndicator

                ColorSlider.Name = "ColorSlider"
                ColorSlider.Parent = Colorpicker
                ColorSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ColorSlider.BorderColor3 = Color3.fromRGB(27, 42, 53)
                ColorSlider.ClipsDescendants = true
                ColorSlider.Position = UDim2.new(0, 10, 0, 120)
                ColorSlider.Size = UDim2.new(0, 173, 0, 12)

                UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.06, Color3.fromRGB(255, 85, 0)), ColorSequenceKeypoint.new(0.11, Color3.fromRGB(255, 170, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(254, 255, 0)), ColorSequenceKeypoint.new(0.22, Color3.fromRGB(169, 255, 0)), ColorSequenceKeypoint.new(0.28, Color3.fromRGB(83, 255, 0)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 1)), ColorSequenceKeypoint.new(0.39, Color3.fromRGB(0, 255, 86)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(0, 255, 171)), ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 252, 255)), ColorSequenceKeypoint.new(0.56, Color3.fromRGB(0, 167, 255)), ColorSequenceKeypoint.new(0.61, Color3.fromRGB(0, 82, 255)), ColorSequenceKeypoint.new(0.67, Color3.fromRGB(2, 0, 255)), ColorSequenceKeypoint.new(0.72, Color3.fromRGB(88, 0, 255)), ColorSequenceKeypoint.new(0.78, Color3.fromRGB(173, 0, 255)), ColorSequenceKeypoint.new(0.84, Color3.fromRGB(255, 0, 251)), ColorSequenceKeypoint.new(0.89, Color3.fromRGB(255, 0, 166)), ColorSequenceKeypoint.new(0.95, Color3.fromRGB(255, 0, 80)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))}
                UIGradient.Parent = ColorSlider

                UICorner_5.CornerRadius = UDim.new(0, 6)
                UICorner_5.Parent = ColorSlider

                Base.Name = "Base"
                Base.Parent = Colorpicker
                Base.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Base.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Base.BorderSizePixel = 0
                Base.Position = UDim2.new(0, 10, 0, 33)
                Base.Size = UDim2.new(0, 173, 0, 80)

                UICorner_6.CornerRadius = UDim.new(0, 6)
                UICorner_6.Parent = Base
                
                local HueThumb                = Instance.new("Frame")
                local HueThumbCorner          = Instance.new("UICorner")
                
                HueThumb.Name               = "HueThumb"
                HueThumb.Parent             = ColorSlider
                HueThumb.AnchorPoint        = Vector2.new(0.5, 0.5)
                HueThumb.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
                HueThumb.BorderSizePixel    = 0
                HueThumb.Size               = UDim2.new(0, 6, 0, 6)
                HueThumb.ZIndex             = 10
                HueThumb.ClipsDescendants   = false

                HueThumbCorner.CornerRadius = UDim.new(1, 0)
                HueThumbCorner.Parent       = HueThumb
                
                local Stroke = Instance.new("UIStroke", HueThumb)
                Stroke.Color = Color3.fromRGB(0, 0, 0)
                Stroke.Thickness = 1
                
                local ColorThumb                = Instance.new("Frame")
                local ColorThumbCorner          = Instance.new("UICorner")

                ColorThumb.Name               = "ColorThumb"
                ColorThumb.Parent             = Overlay
                ColorThumb.AnchorPoint        = Vector2.new(0.5, 0.5)
                ColorThumb.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
                ColorThumb.BorderColor3       = Color3.fromRGB(0, 0, 0)
                ColorThumb.BorderSizePixel    = 0
                ColorThumb.Size               = UDim2.fromOffset(6, 6)
                ColorThumb.ZIndex             = 10
                ColorThumb.ClipsDescendants   = false

                ColorThumbCorner.CornerRadius = UDim.new(1, 0)
                ColorThumbCorner.Parent       = ColorThumb
                
                local Stroke = Instance.new("UIStroke", ColorThumb)
                Stroke.Color = Color3.fromRGB(0, 0, 0)
                Stroke.Thickness = 1
                
                local function OnHTDrag(inputX)
                    local barPos = ColorSlider.AbsolutePosition.X
                    local barSize = ColorSlider.AbsoluteSize.X
                    local alpha = math.clamp((inputX - barPos) / barSize, 0, 1)
                    return alpha
                end

                local function OnCTDrag(inputX, inputY)
                    local barPos = Overlay.AbsolutePosition.X
                    local barSize = Overlay.AbsoluteSize.X
                    local x = math.clamp((inputX - barPos) / barSize, 0, 1)
                    local barPos = Overlay.AbsolutePosition.Y
                    local barSize = Overlay.AbsoluteSize.Y
                    local y = math.clamp((inputY - barPos) / barSize, 0, 1)
                    return x, y
                end


                local HueThumbPos

                local H, S, V = Color:ToHSV()
                ColorThumb.Position = UDim2.fromScale(1-V, 1-S)
                S = 1
                V = 1
                UIGradient_2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromHSV(H, S, V))}
                UIGradient_2.Rotation = 270
                UIGradient_2.Parent = Base
                
                HueThumbPos = H
                HueThumb.Position = UDim2.fromScale(H, 0.5)
                
                local OldHex
                local OldRgb
                local OldHsv
                
                local function UpdateEverything(InputX, InputY, X, Y, CallbackYes)
                    if not (X and Y) then 
                        X, Y = OnCTDrag(InputX, InputY)
                    end
                    TweenService:Create(ColorThumb, TweenInfo.new(0.1), {Position = UDim2.fromScale(X, Y)}):Play()
                    local RealColor = Color3.fromHSV(HueThumbPos, 1-Y, 1-X)
                    ColorIndicatorBackground.BackgroundColor3 = RealColor
                    ColorIndicator.BackgroundColor3 = RealColor
                    local ColorStr = tostring(RealColor)
                    HsvValueText.Text = string.format("%s, %s, %s", 
                        math.floor(tonumber(ColorStr:split(", ")[1]) * 360),
                        math.floor(tonumber(ColorStr:split(", ")[2]) * 255),
                        math.floor(tonumber(ColorStr:split(", ")[3]) * 255)
                    )
                    local R, G, B = math.floor((RealColor.R*255)+0.5),math.floor((RealColor.G*255)+0.5),math.floor((RealColor.B*255)+0.5)
                    RgbValueText.Text = string.format("%s, %s, %s", R, G, B)
                    HexValueText.Text = string.format("#%02x%02x%02x", R, G, B)
                    OldHex = HexValueText.Text
                    OldRgb = RgbValueText.Text
                    OldHsv = HsvValueText.Text
                    Window.Flags[Flag] = {Color = RealColor}
                    
                    if not CallbackYes then
                        task.spawn(function()
                            Callback(RealColor)
                        end)
                    end
                end
                
                local DraggingHueThumb = false
                local DraggingColorThumb = false
                local HueThumbDragInput
                local ColorThumbbDragInput
                ColorSlider.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        DraggingHueThumb = true
                        HueThumbDragInput = Input
                        while DraggingHueThumb and task.wait() do
                            local P = OnHTDrag(HueThumbDragInput.Position.X)
                            HueThumbPos = P
                            TweenService:Create(HueThumb, TweenInfo.new(0.1), {Position = UDim2.fromScale(P, 0.5)}):Play()
                            local CLR = Color3.fromHSV(P, 1, 1)
                            UIGradient_2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, CLR)}
                            UpdateEverything(nil, nil, ColorThumb.Position.X.Scale, ColorThumb.Position.Y.Scale)
                        end
                    end
                end)
                ColorSlider.InputChanged:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
                        HueThumbDragInput = Input
                    end
                end)
                
                ColorSlider.InputEnded:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        DraggingHueThumb = false
                    end
                end)
                
                UpdateEverything(nil, nil, ColorThumb.Position.X.Scale, ColorThumb.Position.Y.Scale, true)
                
                Overlay.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        DraggingColorThumb = true
                        ColorThumbbDragInput = Input
                        while DraggingColorThumb and task.wait() do
                            UpdateEverything(ColorThumbbDragInput.Position.X, ColorThumbbDragInput.Position.Y)
                        end
                    end
                end)
                Overlay.InputChanged:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
                        ColorThumbbDragInput = Input
                    end
                end)

                Overlay.InputEnded:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        DraggingColorThumb = false
                    end
                end)

                Overlay.Name = "Overlay"
                Overlay.Parent = Colorpicker
                Overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Overlay.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Overlay.BorderSizePixel = 0
                Overlay.Position = UDim2.new(0, 10, 0, 33)
                Overlay.Size = UDim2.new(0, 173, 0, 80)

                UICorner_7.CornerRadius = UDim.new(0, 6)
                UICorner_7.Parent = Overlay

                UIGradient_3.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 0, 0)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0))}
                UIGradient_3.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0.00, 1.00), NumberSequenceKeypoint.new(1.00, 0.00)}
                UIGradient_3.Parent = Overlay

                HexValue.Name = "HexValue"
                HexValue.Parent = Colorpicker
                HexValue.AnchorPoint = Vector2.new(1, 1)
                HexValue.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                HexValue.BackgroundTransparency = 0.500
                HexValue.BorderColor3 = Color3.fromRGB(0, 0, 0)
                HexValue.BorderSizePixel = 0
                HexValue.Position = UDim2.new(1, -10, 1, -10)
                HexValue.Size = UDim2.new(0, 100, 0, 26)

                UICorner_8.Parent = HexValue

                HexValueText.Name = "HexValueText"
                HexValueText.Parent = HexValue
                HexValueText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                HexValueText.BackgroundTransparency = 1.000
                HexValueText.BorderColor3 = Color3.fromRGB(0, 0, 0)
                HexValueText.BorderSizePixel = 0
                HexValueText.Size = UDim2.new(1, 0, 1, 0)
                HexValueText.Font = Enum.Font.ArialBold
                HexValueText.TextColor3 = Color3.fromRGB(255, 255, 255)
                HexValueText.TextSize = 14.000
                HexValueText.ClearTextOnFocus = false
                HexValueText.FocusLost:Connect(function()
                    local text = HexValueText.Text
                    if text:sub(1, 1) == "#" then
                        text = text:sub(2)
                    end
                    if not text:match("%x+%x+%x+") then
                        HexValueText.Text = OldHex
                        return
                    end
                    local seg1 = text:sub(1, 2)
                    local seg2 = text:sub(3, 4)
                    local seg3 = text:sub(5, 6)
                    local r, g, b = tonumber(seg1, 16), tonumber(seg2, 16), tonumber(seg3, 16)
                    local h, s, v = Color3.fromRGB(r, g, b):ToHSV()
                    HueThumbPos = h
                    TweenService:Create(HueThumb, TweenInfo.new(0.1), {Position = UDim2.fromScale(h, 0.5)}):Play()
                    UIGradient_2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromHSV(h, 1, 1))}
                    UpdateEverything(nil, nil, 1-v, 1-s)
                end)

                FormatIndication.Name = "FormatIndication"
                FormatIndication.Parent = HexValue
                FormatIndication.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                FormatIndication.BackgroundTransparency = 1.000
                FormatIndication.BorderColor3 = Color3.fromRGB(0, 0, 0)
                FormatIndication.BorderSizePixel = 0
                FormatIndication.Position = UDim2.new(-1, -7, 0, 0)
                FormatIndication.Size = UDim2.new(1, 0, 1, 0)
                FormatIndication.Font = Enum.Font.ArialBold
                FormatIndication.Text = "HEX"
                FormatIndication.TextColor3 = Color3.fromRGB(141, 141, 141)
                FormatIndication.TextSize = 14.000
                FormatIndication.TextWrapped = true
                FormatIndication.TextXAlignment = Enum.TextXAlignment.Right

                RgbValue.Name = "RgbValue"
                RgbValue.Parent = Colorpicker
                RgbValue.AnchorPoint = Vector2.new(1, 1)
                RgbValue.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                RgbValue.BackgroundTransparency = 0.500
                RgbValue.BorderColor3 = Color3.fromRGB(0, 0, 0)
                RgbValue.BorderSizePixel = 0
                RgbValue.Position = UDim2.new(1, -10, 1, -40)
                RgbValue.Size = UDim2.new(0, 100, 0, 26)

                UICorner_9.Parent = RgbValue

                RgbValueText.Name = "RgbValueText"
                RgbValueText.Parent = RgbValue
                RgbValueText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                RgbValueText.BackgroundTransparency = 1.000
                RgbValueText.BorderColor3 = Color3.fromRGB(0, 0, 0)
                RgbValueText.BorderSizePixel = 0
                RgbValueText.Size = UDim2.new(1, 0, 1, 0)
                RgbValueText.Font = Enum.Font.ArialBold
                RgbValueText.TextColor3 = Color3.fromRGB(255, 255, 255)
                RgbValueText.TextSize = 14.000
                RgbValueText.ClearTextOnFocus = false
                RgbValueText.FocusLost:Connect(function()
                    local text = RgbValueText.Text
                    text = text:gsub(" ", "")
                    if not text:match("%d+,%d+,%d+") then
                        RgbValueText.Text = OldRgb
                        return
                    end
                    local seg1 = text:split(",")[1]
                    local seg2 = text:split(",")[2]
                    local seg3 = text:split(",")[3]
                    local r, g, b = tonumber(seg1), tonumber(seg2), tonumber(seg3)
                    if not (r and g and b) then
                        RgbValueText.Text = OldRgb
                        return
                    end
                    if (r < 0 or r > 255) or (g < 0 or g > 255) or (b < 0 or b > 255) then
                        RgbValueText.Text = OldRgb
                        return
                    end
                    local h, s, v = Color3.fromRGB(r, g, b):ToHSV()
                    HueThumbPos = h
                    TweenService:Create(HueThumb, TweenInfo.new(0.1), {Position = UDim2.fromScale(h, 0.5)}):Play()
                    UIGradient_2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromHSV(h, 1, 1))}
                    UpdateEverything(nil, nil, 1-v, 1-s)
                end)

                FormatIndication_2.Name = "FormatIndication"
                FormatIndication_2.Parent = RgbValue
                FormatIndication_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                FormatIndication_2.BackgroundTransparency = 1.000
                FormatIndication_2.BorderColor3 = Color3.fromRGB(0, 0, 0)
                FormatIndication_2.BorderSizePixel = 0
                FormatIndication_2.Position = UDim2.new(-1, -7, 0, 0)
                FormatIndication_2.Size = UDim2.new(1, 0, 1, 0)
                FormatIndication_2.Font = Enum.Font.ArialBold
                FormatIndication_2.Text = "RGB"
                FormatIndication_2.TextColor3 = Color3.fromRGB(141, 141, 141)
                FormatIndication_2.TextSize = 14.000
                FormatIndication_2.TextWrapped = true
                FormatIndication_2.TextXAlignment = Enum.TextXAlignment.Right

                HsvValue.Name = "HsvValue"
                HsvValue.Parent = Colorpicker
                HsvValue.AnchorPoint = Vector2.new(1, 1)
                HsvValue.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                HsvValue.BackgroundTransparency = 0.500
                HsvValue.BorderColor3 = Color3.fromRGB(0, 0, 0)
                HsvValue.BorderSizePixel = 0
                HsvValue.Position = UDim2.new(1, -10, 1, -70)
                HsvValue.Size = UDim2.new(0, 100, 0, 26)

                UICorner_10.Parent = HsvValue

                HsvValueText.Name = "HsvValueText"
                HsvValueText.Parent = HsvValue
                HsvValueText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                HsvValueText.BackgroundTransparency = 1.000
                HsvValueText.BorderColor3 = Color3.fromRGB(0, 0, 0)
                HsvValueText.BorderSizePixel = 0
                HsvValueText.Size = UDim2.new(1, 0, 1, 0)
                HsvValueText.Font = Enum.Font.ArialBold
                HsvValueText.TextColor3 = Color3.fromRGB(255, 255, 255)
                HsvValueText.TextSize = 14.000
                HsvValueText.FocusLost:Connect(function()
                    local text = HsvValueText.Text
                    text = text:gsub(" ", "")
                    if not text:match("%d+,%d+,%d+") then
                        HsvValueText.Text = OldRgb
                        return
                    end
                    local seg1 = text:split(",")[1]
                    local seg2 = text:split(",")[2]
                    local seg3 = text:split(",")[3]
                    local h, s, v = tonumber(seg1), tonumber(seg2), tonumber(seg3)
                    if not (h and s and v) then
                        HsvValueText.Text = OldRgb
                        return
                    end
                    if (h < 0 or h > 360) or (s < 0 or s > 255) or (v < 0 or v > 255) then
                        HsvValueText.Text = OldRgb
                        return
                    end
                    h, s, v = h / 360, s / 255, v / 255
                    h, s, v = Color3.fromHSV(h, s, v):ToHSV()
                    print(h, s, v)
                    HueThumbPos = h
                    TweenService:Create(HueThumb, TweenInfo.new(0.1), {Position = UDim2.fromScale(h, 0.5)}):Play()
                    UIGradient_2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromHSV(h, 1, 1))}
                    UpdateEverything(nil, nil, 1-v, 1-s)
                end)


                FormatIndication_3.Name = "FormatIndication"
                FormatIndication_3.Parent = HsvValue
                FormatIndication_3.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                FormatIndication_3.BackgroundTransparency = 1.000
                FormatIndication_3.BorderColor3 = Color3.fromRGB(0, 0, 0)
                FormatIndication_3.BorderSizePixel = 0
                FormatIndication_3.Position = UDim2.new(-1, -7, 0, 0)
                FormatIndication_3.Size = UDim2.new(1, 0, 1, 0)
                FormatIndication_3.Font = Enum.Font.ArialBold
                FormatIndication_3.Text = "HSV"
                FormatIndication_3.TextColor3 = Color3.fromRGB(141, 141, 141)
                FormatIndication_3.TextSize = 14.000
                FormatIndication_3.TextWrapped = true
                FormatIndication_3.TextXAlignment = Enum.TextXAlignment.Right
                
                local Click = Instance.new("TextButton")
                Click.Parent = Colorpicker
                Click.Text = ""
                Click.ZIndex = 2
                Click.BackgroundTransparency = 1
                Click.BorderSizePixel = 0
                Click.Size = UDim2.new(1, 0, 0, 32)
                
                local IsOpen = true
                local function Collapse()
                    Colorpicker.Size = UDim2.new(1, -10, 0, 32)
                    HexValue.Visible = false
                    RgbValue.Visible = false
                    HsvValue.Visible = false
                    ColorSlider.Visible = false
                    Overlay.Visible = false
                    Base.Visible = false
                end
                local function Open()
                    Colorpicker.Size = UDim2.new(1, -10, 0, 140)
                    HexValue.Visible = true
                    RgbValue.Visible = true
                    HsvValue.Visible = true
                    ColorSlider.Visible = true
                    Overlay.Visible = true
                    Base.Visible = true
                end
                
                Click.MouseButton1Click:Connect(function()
                    IsOpen = not IsOpen
                    if not IsOpen then
                        Collapse()
                    else
                        Open()
                    end
                end)
                
                Collapse()
                
            end
            
            return Tab
        end
        
        Window.Keybinds = {}
        UserInputService.InputBegan:Connect(function(Input, Gpe)
            if Gpe then return end
            for i, v in pairs(Window.Keybinds) do
                if v.Pressable and v.KeyCode and Input.KeyCode == Enum.KeyCode[v.KeyCode] then
                    v.Callback()
                end
            end
        end)
        
        function Window:SelectTab(Num)
            for i,v in pairs(TabStore) do
                if v ~= TabStore[Num] then
                    v.IsSelected = false
                    v.Deselect()
                end
            end
            TabStore[Num].IsSelected = true
            TabStore[Num].Select()
        end
        
        Window.Flags = {}
        Library.__Window__ = MainFrame

        return Window
    end

    function Library:Destroy()
        pcall(function()
            Library.__Window__.Parent:Destroy()
        end)
    end

    local NotifQueue = {}
    function Library:Notify(text)
        if NotifQueue[text] then return end
        NotifQueue[text] = true
        task.delay(7, function()
            NotifQueue[text] = nil
        end)
        Fluent:Notify({
            Title = "Lunar",
            Content = text,
            Duration = 7
        })
    end

    return Library
end)()


local window = mainuimodule:CreateWindow({
    Name = "Lunar - BSS V1.0, BETA",
    Icon = getcustomasset("r_antlers.png"),
})

local api = {
    ["getRoot"] = function()
        return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    end,
    ["getHumanoid"] = function()
        return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    end,
    ["isAlive"] = function()
        return LocalPlayer.Character ~= nil
            and LocalPlayer.Character:FindFirstChild("Humanoid") ~= nil
            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") ~= nil
            and LocalPlayer.Character.Humanoid.Health > 0
    end,
    ["magnitude"] = function(pointA, pointB, check)
        local mag = (pointA - pointB).magnitude
        if check then
            return (mag <= check)
        end
        return mag
    end,
    ["getnearestbubbles"] = function(field)
        local bubbles = {}
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        for i, bubble in pairs(workspace.Particles:GetChildren()) do
            if bubble.Name:find("Bubble") and isfield(bubble.Position) == field then
                table.insert(bubbles, {
                    distance = (root.Position - bubble.Position).magnitude,
                    bubble = bubble
                })
            end
        end
        table.sort(bubbles, function(a, b)
            return a.distance < b.distance
        end)
        local rawbubbles = {}
        for i, v in pairs(bubbles) do
            table.insert(rawbubbles, v.bubble)
        end
        return rawbubbles
    end,
    ["getnearestfuzzes"] = function(field)
        local fuzz = {}
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        for i, fuzzyinstance in pairs(workspace.Particles:GetChildren()) do
            if fuzzyinstance.Name == "DustBunnyInstance" and fuzzyinstance:FindFirstChild("Plane") and isfield(fuzzyinstance.Plane.Position) == field then
                table.insert(fuzz, {
                    distance = (root.Position - fuzzyinstance.Plane.Position).magnitude,
                    bomb = fuzzyinstance
                })
            end
        end
        table.sort(fuzz, function(a, b)
            return a.distance < b.distance
        end)
        local rawfuzz = {}
        for i, v in pairs(fuzz) do
            table.insert(rawfuzz, v.bomb)
        end
        return rawfuzz
    end,
    ["getleafonfield"] = function(leafstore, field)
        local leaves = {}
        for i, leaf in pairs(leafstore) do
            if isfield(leaf.Parent.Position) == field then
                table.insert(leaves, leaf)
            end
        end
        local toreturn = #leaves > 0 and leaves[1]
        table.clear(leaves)
        return toreturn
    end
}

local allprices = {
    Glider = {Name = "Glider", Requirements = {}, Cost = {{Category = "Honey", Amount = 5000000}}}
}
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.Collectors).Get, 1)) do
    local Ingredients = {
        {Category = "Honey", Amount = v.Cost or 0}
    }
    for i, v in pairs(v.Ingredients or {}) do
        table.insert(Ingredients, {Type = v[1], Amount = v[2], Category = "Eggs"})
    end
    rawset(allprices, i, {
        Cost = Ingredients,
        Requirements = v.Requirements or {},
        Name = i
    })
end
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.Backpacks).GetStat, 1)) do
    local Ingredients = {
        {Category = "Honey", Amount = v.Cost or 0}
    }
    for i, v in pairs(v.Ingredients or {}) do
        table.insert(Ingredients, {Type = v[1], Amount = v[2], Category = "Eggs"})
    end
    rawset(allprices, i, {
        Cost = Ingredients,
        Requirements = v.Requirements or {},
        Name = i
    })
end
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.Accessories).Exists, 1)) do
    local Ingredients = {
        {Category = "Honey", Amount = v.Cost or 0}
    }
    for i, v in pairs(v.Ingredients or {}) do
        table.insert(Ingredients, {Type = v[1], Amount = v[2], Category = "Eggs"})
    end
    rawset(allprices, i, {
        Cost = Ingredients,
        Requirements = v.Requirements or {},
        Name = i
    })
end
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.PlanterTypes).Get, 1)) do
    rawset(allprices, i .. "Planter", {
        Cost = v.Cost,
        Requirements = v.PurchaseRequirements or {},
        Name = i
    })
end

for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.Sprinklers).Get, 1)) do
    rawset(allprices, i, {
        Cost = {{Category = "Honey", Amount = v.Cost}},
        Requirements = v.Requirements or {},
        Name = i
    })
end

local gearmeta = {
    Helmet = {"noob", "hat"},
    ["Basic Boots"] = {"noob", "boots"},
    ["Belt Pocket"] = {"noob", "belt"},
    Jar = {"noob", "backpack"},
    Backpack = {"noob", "backpack"},
    Canister = {"noob", "backpack"},
    Rake = {"noob", "tool"},
    Clippers = {"noob", "tool"},
    Magnet = {"noob", "tool"},
    Vacuum = {"noob", "tool"},
    ["Mega-Jug"] = {"pro", "backpack"},
    Compressor = {"pro", "backpack"},
    ["Elite Barrel"] = {"pro", "backpack"},
    ["Port-O-Hive"] = {"pro", "backpack"},
    Parachute = {"pro", "glider"},
    ["Super-Scooper"] = {"pro", "tool"},
    Pulsar = {"pro", "tool"},
    ["Electro-Magnet"] = {"pro", "tool"},
    Scissors = {"pro", "tool"},
    ["Honey Dipper"] = {"pro", "tool"},
    ["Propeller Hat"] = {"pro", "hat"},
    ["Brave Guard"] = {"pro", "rightshoulder"},
    ["Hasty Guard"] = {"pro", "rightshoulder"},
    ["Bomber Guard"] = {"pro", "leftshoulder"},
    ["Looker Guard"] = {"pro", "leftshoulder"},
    ["Belt Bag"] = {"pro", "belt"},
    ["Hiking Boots"] = {"pro", "boots"},
    PlasticPlanter = {"dapper", "planter"},
    CandyPlanter = {"dapper", "planter"},
    TackyPlanter = {"dapper", "planter"},
    PesticidePlanter = {"dapper", "planter"},
    PlentyPlanter = {"dapper", "planter"},
    ["Red Guard"] = {"redhq", "leftshoulder"},
    ["Elite Red Guard"] = {"redhq", "leftshoulder"},
    ["Riley Guard"] = {"redhq", "leftshoulder"},
    Scythe = {"redhq", "tool"},
    ["Red Port-O-Hive"] = {"redhq", "backpack"},
    ["Fire Mask"] = {"redhq", "hat"},
    ["Red ClayPlanter"] = {"redhq", "planter"},
    ["Heat-TreatedPlanter"] = {"redhq", "planter"},
    ["Dark Scythe"] = {"redhq", "tool"},
    ["Bubble Wand"] = {"bluehq", "tool"},
    ["Blue Guard"] = {"bluehq", "rightshoulder"},
    ["Elite Blue Guard"] = {"bluehq", "rightshoulder"},
    ["Bucko Guard"] = {"bluehq", "rightshoulder"},
    ["Blue Port-O-Hive"] = {"bluehq", "backpack"},
    ["Bubble Mask"] = {"bluehq", "hat"},
    ["Blue ClayPlanter"] = {"bluehq", "planter"},
    HydroponicPlanter = {"bluehq", "planter"},
    ["Tide Popper"] = {"bluehq", "tool"},
    ["Basic Sprinkler"] = {"badgeguild", "sprinkler"},
    ["Silver Soakers"] = {"badgeguild", "sprinkler"},
    ["Golden Gushers"] = {"badgeguild", "sprinkler"},
    ["Diamond Drenchers"] = {"badgeguild", "sprinkler"},
    ["The Supreme Saturator"] = {"badgeguild", "sprinkler"},
    ["Golden Rake"] = {"top", "tool"},
    ["Spark Staff"] = {"top", "tool"},
    ["Porcelain Dipper"] = {"top", "tool"},
    ["Porcelain Port-O-Hive"] = {"top", "backpack"},
    Glider = {"top", "glider"},
    ["Mondo Belt Bag"] = {"top", "belt"},
    ["Beekeeper's Mask"] = {"top", "hat"},
    ["Beekeeper's Boots"] = {"top", "boots"},
    ["Petal Belt"] = {"petal", "belt"},
    PetalPlanter = {"petal", "planter"},
    ["Petal Wand"] = {"petal", "tool"},
    ["Coconut Clogs"] = {"coconut", "boots"},
    ["Coconut Canister"] = {"coconut", "backpack"},
    ["Coconut Belt"] = {"coconut", "belt"},
}

local hasaccessshopfuncs = {
    noob = function()
        return true
    end,
    pro = function()
        return #getbeesdata().all >= 10
    end,
    dapper = function()
        return #getbeesdata().all >= 10 and not workspace.Gates["Dapper Shop"].Door.CanCollide
    end,
    master = function()
        return #getbeesdata().all >= 15 and not workspace.Gates["Master Room Gate"].Door.CanCollide
    end,
    redhq = function()
        for i, v in pairs(workspace.Gates:GetChildren()) do
            if v.Name == "Red HQ Gate" and v:FindFirstChild("Frame") then
                return #getbeesdata().all >= 15 and not v.Door.CanCollide
            end
        end
    end,
    bluehq = function()
        return not workspace.Gates["Blue HQ Gate"].Door.CanCollide
    end,
    top = function()
        return #getbeesdata().all >= 25
    end,
    badgeguild = function()
        return #getbeesdata().all >= 15 and not workspace.Gates["Badge Build Gate"].Door.CanCollide
    end,
    basicegg = function()
        return true
    end,
    petal = function()
        return #getbeesdata.all >= 35
    end,
    coconut = function()
        return #getbeesdata().all >= 35 and not workspace.Gates["Coconut Gate"].Door.CanCollide
    end
}

function getclientstatcache(...)
    return clientstatcache:Get({...})
end

function updatestatcache()
    clientstatcache:Update()
end

local tasks = {
    tasks = {},
    events = {}
}
function tasks.add(name, func)
    if rawget(tasks.tasks, name) ~= nil then
        return
    end
    local done = Instance.new("BindableEvent")
    local finished = false
    local thread = task.spawn(function()
        local s,r=pcall(func)
        if not s then warn("task error (" .. name .. ")", r) end
        finished = true
        done:Fire()
    end)
    rawset(tasks.tasks, name, thread)
    rawset(tasks.events, name, done)
    if finished then return done:Destroy(), rawset(tasks.tasks, name, nil), rawset(tasks.events, name, nil) end
    done.Event:Wait()  -- resumes next frame the thread dies, no polling
    done:Destroy()
    rawset(tasks.tasks, name, nil)
    rawset(tasks.events, name, nil)
end
function tasks.delete(name)
    local _task = tasks.tasks[tostring(name)]
    if not _task then return warn("Task \"" .. tostring(name) .. "\" doesn't exist") end
    local event = tasks.events[tostring(name)]
    task.cancel(_task)
    event:Fire()
    tasks.tasks[name] = nil
    tasks.events[name] = nil
    print("Task \"" .. tostring(name) .. "\" ended")
end
function tasks.deleteall()
    for name, _ in pairs(tasks.tasks) do
        tasks.delete(name)
    end
end

local allvars = {
    remotes=false,
    timeatload = _G.lunartimeatload or os.clock(),
    discordwebhookurl = "",
    discordwebhookenabled = false,
    webhookinterval = 5,
    lastdiscordupdate = 0,
    disconnected = false,
    starthoney = getclientstatcache("Honey"),
    isrunning = true,
    autofarm = false,
    autodig = false,
    autosprinkler = false,
    autoprogress = false,
    autoconvert = true,
    ignorehoneytokens = false,
    convertatx = 100,
    converthiveballoon = false,
    convertballoonat = 15,
    tweentimeout = 20,
    hive = nil,
    api = api,
    fieldtofarm = nil,
    farmingfield = "Sunflower Field",
    tweenspeed = 12,
    redosprinklers = true,
    sprinklefield = nil,
    allowedcrafts = {},
    autoprogcapabs = {"Purchase gear", "Add bees and use royal jelly", "Automaticaly select fields", "Redeem codes", "Use the blender", "Collect secret rares"},
    isloaded = true,
    movespeed = 70,
    speedhackenabled = false,
    dynamicmovespeedmultiplier = 2,
    dynamicspeedhackenabled = false,
    dynamicmovespeedmaximum = 100,
    killvic = false,
    vicnotifier = false,
    maxviclevel = 12,
    minviclevel = 1,
    ignorevicbee = {},
    avoidmobs = true,
    vicaveragebeelevel = true,
    autoprogbadgeorder = {},
    autoprogjson = [[
        [
            {
                "event": "collectibles"
            },
            {
                "event": "bees",
                "value": 50
            },
            {
                "event": "codes",
                "value": [
                    "38217",
                    "BeesBuzz123",
                    "BopMaster",
                    "Connoisseur",
                    "Crawlers",
                    "Nectar",
                    "Roof",
                    "Wax"
                ],
                "bees": 0
            },
            {
                "event": "field",
                "value": ["Sunflower Field", "Bamboo Field", "Pineapple Patch", "Pine Tree Forest"]
            },
            {
                "event": "badges",
                "value": [
                    "Pine Tree Forest",
                    "Bamboo Field",
                    "Pumpkin Patch",
                    "Cactus Field",
                    "Rose Field",
                    "Blue Flower Field"
                ]
            },
            {
                "event": "gear",
                "value": [
                    "Jar",
                    "Rake",
                    "Backpack",
                    "Magnet",
                    "Canister",
                    "Vacuum",
                    "Belt Pocket",
                    "Basic Boots",
                    "Compressor",
                    "Super-Scooper",
                    "Pulsar",
                    "Electro-Magnet",
                    "Helmet",
                    "Port-O-Hive",
                    "Honey Dipper",
                    "Propeller Hat",
                    "Looker Guard",
                    "Brave Guard",
                    "Hiking Boots",
                    "Belt Bag",
                    "Bubble Wand",
                    "Basic Sprinkler",
                    "PlasticPlanter",
                    "Blue Port-O-Hive",
                    "Silver Soakers",
                    "Elite Blue Guard",
                    "Elite Red Guard",
                    "CandyPlanter",
                    "Glider",
                    "Porcelain Dipper",
                    "Porcelain Port-O-Hive",
                    "Blue ClayPlanter",
                    "Red ClayPlanter",
                    "Bubble Mask",
                    "Golden Gushers",
                    "TackyPlanter",
                    "Diamond Drenchers",
                    "PesticidePlanter",
                    "The Supreme Saturator"
                ]
            }
        ]
    ]],
    autoprogdata = nil,
    fieldbeereqs = {
        [0] = {"Sunflower Field", "Dandelion Field", "Mushroom Field", "Blue Flower Field", "Clover Field"},
        [5] = {"Strawberry Field", "Spider Field", "Bamboo Field"},
        [10] = {"Pineapple Patch", "Stump Field"},
        [15] = {"Rose Field", "Pine Tree Forest", "Pumpkin Patch", "Cactus Field"},
        [20] = {"Ant Field"},
        [25] = {"Mountain Top Field"},
        [30] = {},
        [35] = {"Coconut Field", "Pepper Patch"}
    },
    redeemedcodes = false,
    forcetasks = {
        fireflies = false,
        killvic = false,
        autoprogbadges = {},
    },
    farmfireflies = false,
    fireflyfield = nil,
    nextautoprogitem = nil,
    farmmeteorites = false,
    lastmeteordetect = math.huge,
    lastfarmbadge = nil,
}
_G.lunartimeatload = allvars.timeatload

local slotkeytotype = {
    ["Left Shoulder"]  = "leftshoulder",
    ["Right Shoulder"] = "rightshoulder",
    ["Container"]      = "backpack",
    ["Belt"]           = "belt",
    ["Boots"]          = "boots",
    ["Hat"]            = "hat",
    ["Tool"]           = "tool",
}

local priorites = {
    ["Red Boost"] = {Enabled = false, Asset = "rbxassetid://1442863423"},
    ["Blue Boost"] = {Enabled = false, Asset = "rbxassetid://1442863423"},
    ["White Boost"] = {Enabled = false, Asset = "http://www.roblox.com/asset/?id=3877732821"},
    ["Baby Love"] = {Enabled = false, Asset = "rbxassetid://1472256444"},
    ["Crosshairs"] = {Enabled = false, Asset = "rbxassetid://8173559749"},
    ["Scratch"] = {Enabled = false, Asset = "rbxassetid://1104415222", Default = 5},
    ["Focus"] = {Enabled = false, Asset = "rbxassetid://1629649299"},
    ["Inflate"] = {Enabled = false, Asset = "rbxassetid://8083436978"},
    ["Surprise Party"] = {Enabled = false, Asset = "rbxassetid://8083943936"},
    ["Summon Frog"] = {Enabled = false, Asset = "http://www.roblox.com/asset/?id=4528414666"},
    ["Cloud"] = {Enabled = false, Asset = "rbxassetid://3582501342"},
    ["Tabby Love"] = {Enabled = false, Asset = "rbxassetid://1753904608"},
    ["Haste"] = {Enabled = false, Asset = "http://www.roblox.com/asset/?id=65867881"},
    ["Melody"] = {Enabled = false, Asset = "http://www.roblox.com/asset/?id=253828517"},
    ["Festive Blessing"] = {Enabled = false, Asset = "rbxassetid://2652424740", Default = 3},
    ["Beesmas Cheer"] = {Enabled = false, Asset = "rbxassetid://2652364563", Default = 3},
    ["Blue Bomb"] = {Enabled = false, Asset = "rbxassetid://1442725244"},
    ["Red Bomb"] = {Enabled = false, Asset = "rbxassetid://1442764904"},
    ["White Bomb"] = {Enabled = false, Asset = "rbxassetid://1442764904"},
    ["Inspire"] = {Enabled = false, Asset = "rbxassetid://2000457501", Default = 4},
    ["Gummy Blob"] = {Enabled = false, Asset = "http://www.roblox.com/asset/?id=177997841"},
    ["Gummy Shower"] = {Enabled = false, Asset = "rbxassetid://1839454544"},
    ["Snowflake"] = {Enabled = false, Asset = "rbxassetid://6087969886"},
    ["Gumdrops"] = {Enabled = false, Asset = "rbxassetid://1838129169"},
    ["Sunflower Seed"] = {Enabled = false, Asset = "rbxassetid://1952682401"},
    ["Strawberry"] = {Enabled = false, Asset = "rbxassetid://1952740625"},
    ["Blueberry"] = {Enabled = false, Asset = "rbxassetid://2028453802"},
    ["Pineapple"] = {Enabled = false, Asset = "rbxassetid://1952796032"},
}
local rawpriortable = {}
local a = 0
local function addtopriorities(names)
    for j = 1, #names do
        a+=1
        rawpriortable[a]=names[j]
    end
end
-- Boosts
addtopriorities({"Red Boost", "Blue Boost", "White Boost", "Blue Bomb", "Red Bomb", "White Bomb"})
-- Abilties
addtopriorities({"Inspire", "Haste", "Melody", "Focus"})
-- Other
addtopriorities({"Gummy Blob", "Gummy Shower", "Tabby Love", "Cloud",
    "Summon Frog", "Surprise Party", "Scratch", "Crosshairs", "Baby Love", 
    "Beesmas Cheer", "Festive Blessing", "Inflate"
})
-- Loot
addtopriorities({"Strawberry", "Blueberry", "Pineapple", "Sunflower Seed", "Snowflake"})

function getequippedforslottype(equipped, slotType)
    for key, gearName in pairs(equipped) do
        if slotkeytotype[key] == slotType then
            return gearName
        end
    end
    return nil
end

-- flip fieldbeerequs
local newfieldreqs = {}
for i, v in pairs(allvars.fieldbeereqs) do
    for _, b in pairs(v) do
        newfieldreqs[b] = i
    end
end
allvars.fieldbeereqs = newfieldreqs

local function loadautoprogress()
    allvars.autoprogdata = HttpService:JSONDecode(allvars.autoprogjson)
end
task.spawn(function()
    while allvars.isrunning and task.wait(0.1) do
        loadautoprogress()
    end
end)

-- set up fields
local fieldids = {}
local sortedfields = {}
for i, v in workspace.FlowerZones:GetChildren() do
    local n = tostring(v)
    if not (n:find("Ant") or n:find("Brick") or n:find("Hub")) then
        fieldids[v.ID.Value] = n
        table.insert(sortedfields, n)
    end
end
table.sort(sortedfields)

local newzones
if not workspace:FindFirstChild("NewFlowerZones") then
    newzones = Instance.new("Folder", workspace)
    newzones.Name = "NewFlowerZones"
else
    newzones = workspace.NewFlowerZones
end

local flowers = getgenv().cacheflowers or {}
local rawflowers = getgenv().cacherawflowers or {}
if #rawflowers == 0 then
    for i, v in pairs(workspace.Flowers:GetChildren()) do
        table.insert(rawflowers, v)
        local id = tonumber(v.Name:match("FP(%d+)-"))
        local field = fieldids[id]
        if not field then continue end
        if not flowers[field] then flowers[field] = {} end
        if (v.Position - workspace.FlowerZones[field].Position).magnitude <= 30 then
            table.insert(flowers[field], v)
        end
    end
    getgenv().cacheflowers = flowers
    getgenv().cacherawflowers = rawflowers
end

function addraycastzones()
    local zones = {}
    local OFFSET = 2

    for _, p in ipairs(rawflowers) do
        local idStr = string.match(p.Name, "FP-(%d+)")
        if idStr then
            local id = tonumber(idStr)
            zones[id] = zones[id] or {}
            table.insert(zones[id], p)
        end
    end

    for id, zoneFlowers in pairs(zones) do
        local fieldName = fieldids[id]
        if not fieldName then continue end

        local minX = math.huge
        local maxX = -math.huge
        local minZ = math.huge
        local maxZ = -math.huge

        for _, p in ipairs(zoneFlowers) do
            local pos = p.Position

            if pos.X < minX then minX = pos.X end
            if pos.X > maxX then maxX = pos.X end
            if pos.Z < minZ then minZ = pos.Z end
            if pos.Z > maxZ then maxZ = pos.Z end
        end

        minX -= 4
        maxX += 4
        minZ -= 4
        maxZ += 4

        local firstFlower = zoneFlowers[1]

        local zonePart = Instance.new("Part")
        zonePart.Name = fieldName
        zonePart.Anchored = true
        zonePart.CanCollide = false
        zonePart.Transparency = 1

        zonePart.Size = Vector3.new(
            maxX - minX,
            1,
            maxZ - minZ
        )

        zonePart.Position = Vector3.new(
            (minX + maxX) / 2,
            firstFlower.Position.Y,
            (minZ + maxZ) / 2
        )

        zonePart.Parent = workspace.NewFlowerZones
    end
end
if #workspace.NewFlowerZones:GetChildren() == 0 then
    addraycastzones()
end

function randomstring(l)
    local str = ""
    local chars = ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):split("")
    for i = 1, l or 16 do
        str = str .. chars[math.random(1, #chars)]
    end
    return str
end

if not workspace:FindFirstChild("CaveFolder") then
    local CaveFolder = Instance.new("Folder", workspace)
    CaveFolder.Name = "CaveFolder"

    local FillPart = Instance.new("Part", CaveFolder)
    FillPart.Name = randomstring()
    FillPart.Position = Vector3.new(-29.765, 70.252, -144)
    FillPart.Size = Vector3.new(149.529, 10.607, 89.198)
    FillPart.Transparency = 1
end

function checkcave(startPos, endPos)
    local direction = (endPos - startPos).Unit
    local ray = Ray.new(startPos, direction * (endPos - startPos).magnitude)
    return workspace:FindPartOnRayWithWhitelist(ray, {workspace.CaveFolder}) ~= nil
end

local Pit = workspace.Decorations["30BeeZone"].Pit
local HiveHubPortal = (function()
    for i, v in pairs(workspace.Map.Ground.Campsite:GetChildren()) do
        if v.Name == "TradeHubPortalPart" and v:FindFirstChild("TouchInterest") then
            return v
        end
    end
end)()
local RetroPortal = workspace.RetroEvent.RetroChallengePortal.Trigger

function safewalk(v3, precise)
    tasks.add("walk", function()
        local hum = allvars.api.getHumanoid()
        local root = allvars.api.getRoot()
        if not hum or not root then return end
        local start = tick()
        repeat
            if tick() - start >= 4 then
                return tweento(v3, 20, nil)
            end
            hum:MoveTo(v3)
            wait()
        until not allvars.autofarm or allvars.api.magnitude(root.Position * Vector3.new(1, 0, 1), v3 * Vector3.new(1, 0, 1), (precise and 1 or 4))
    end)
end

function isfield(pos)
    local hit = workspace:FindPartOnRayWithWhitelist(Ray.new(pos + Vector3.new(0, 100, 0), Vector3.new(0, -999, 0)), {newzones})
    return hit and hit.Parent.Name == newzones.Name and hit
end

function stoptween()
    local root = allvars.api.getRoot()
    local hum = allvars.api.getHumanoid()
    if not root then return end
    if not hum then return end

    if _G.nocliptween then
        pcall(function() _G.nocliptween:Disconnect() end)
    end

    if root:FindFirstChild("AlignPosition") then
        root.AlignPosition:Destroy()
    end
    if root:FindFirstChild("AlignOrientation") then
        root.AlignOrientation:Destroy()
    end
end

function disableall()
    stoptween()
    --[[if gettingtoken then
        gettingtoken:Disconnect()
    end]]

    local hum = allvars.api.getHumanoid()
    local root = allvars.api.getRoot()

    if hum and root then
        hum:MoveTo(root.Position)
        hum:ChangeState(Enum.HumanoidStateType.Landed)
        root.Velocity = Vector3.zero
    end

    Pit.CanTouch = true
    HiveHubPortal.CanTouch = true
    RetroPortal.CanTouch = true

    disablenoclip()
end

local nocliporiginal = {}
function enablenoclip()
    local char = LocalPlayer.Character
    if not char then return end
    for i, v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.CanCollide then
            nocliporiginal[v] = true
            v.CanCollide = false
        end
    end
end

function disablenoclip()
    local char = LocalPlayer.Character
    if not char then return end
    for i, v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") and nocliporiginal[v] then
            v.CanCollide = true
        end
    end
    table.clear(nocliporiginal)
end

function tweento(vect, speed, caveavoid, precise)
    Pit.CanTouch = false
    HiveHubPortal.CanTouch = false
    RetroPortal.CanTouch = false
    if _G.nocliptween then
        _G.nocliptween:Disconnect()
    end
    
    local start = tick()
    local root = allvars.api.getRoot()
    local hum = allvars.api.getHumanoid()
    if not root then return end
    if not hum then return end

    if root:FindFirstChild("AlignPosition") then
        root.AlignPosition:Destroy()
    end
    if root:FindFirstChild("AlignOrientation") then
        root.AlignOrientation:Destroy()
    end
    
    local usespeedarg = speed ~= nil

    if checkcave(root.Position, vect) and not caveavoid then
        tweento(Vector3.new(21, 125, -50), speed, true)
    end

    local tweeningposition = Instance.new("AlignPosition")
    tweeningposition.Mode = Enum.PositionAlignmentMode.OneAttachment
    tweeningposition.Attachment0 = root.RootAttachment
    tweeningposition.MaxForce = math.huge
    tweeningposition.Position = vect
    tweeningposition.Parent = root

    local tweeningorientation = Instance.new("AlignOrientation")
    tweeningorientation.Attachment0 = root.RootAttachment
    tweeningorientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    tweeningorientation.RigidityEnabled = true
    tweeningorientation.CFrame = root.CFrame
    tweeningorientation.Parent = root

    _G.nocliptween = RunService.RenderStepped:Connect(function()
        enablenoclip()
    end)

    hum:ChangeState(Enum.HumanoidStateType.Landed)
    RunService.Heartbeat:Wait()
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    repeat
        speed = usespeedarg and speed or allvars.tweenspeed
        tweeningposition.MaxVelocity = speed * 10
        if allvars.api.magnitude(root.Position, vect, precise and 0.1 or 1.5) then break end
        if not root:FindFirstChild("AlignPosition") then break end
        if not root:FindFirstChild("AlignOrientation") then break end
        task.wait()
    until (tick() - start) > allvars.tweentimeout

    disableall()
end

local ActivateButton = LocalPlayer.PlayerGui.ScreenGui.ActivateButton
local TOPBAR_OFFSET = 40
local box = LocalPlayer.PlayerGui.ScreenGui.QuestionBox

function showalluis()
    if not _G.globaluilibrary then return end
    _G.globaluilibrary.Enabled = true
end

function hidealluis()
    if not _G.globaluilibrary then return end
    _G.globaluilibrary.Enabled = false
end

function pressactivatebutton()
    firesignal(ActivateButton.MouseButton1Click)
end

function getCenter(frame)
    local pos = frame.AbsolutePosition
    local size = frame.AbsoluteSize
    return pos.X + size.X/2, (pos.Y + size.Y/2) + TOPBAR_OFFSET
end

function holdframeandmove(frame, nx, ny)
    local x, y = getCenter(frame)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
    RunService.RenderStepped:Wait()
    VirtualInputManager:SendMouseMoveEvent(nx, ny, game)
    RunService.RenderStepped:Wait()
    VirtualInputManager:SendMouseButtonEvent(nx, ny, 0, false, game, 0)
    RunService.RenderStepped:Wait()
end

function clickframe(frame)
    local x, y = getCenter(frame)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
    RunService.RenderStepped:Wait()
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    RunService.RenderStepped:Wait()
end

function claimhive()
    while not LocalPlayer:FindFirstChild("Honeycomb") do
        print("Claiming hive")
        for i = 6, 1, -1 do
            if LocalPlayer:FindFirstChild("Honeycomb") then break end
            local comb = workspace.Honeycombs["Hive" .. i]
            if comb:FindFirstChild("Owner") and not comb.Owner.Value then
                tweento(comb.patharrow.Base.Position + Vector3.new(0, 2.5, 0))
                if not comb.Owner.Value then
                    if allvars.remotes then
                        events.ClientCall("ClaimHive", i)
                        updatestatcache()
                    else
                        pressactivatebutton()
                    end
                end
                task.wait(1.5)
                break
            end
        end
        task.wait()
    end
end

local loadcomp = tick()
claimhive()
allvars.hive = LocalPlayer:FindFirstChild("Honeycomb").Value
realloadstart = realloadstart + (tick() - loadcomp)

function deepcopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[deepcopy(k)] = deepcopy(v)
    end
    return setmetatable(copy, getmetatable(t))
end

function blendercraft(name, amount)
    local capabilities = allvars.autoprogcapabs
    if allvars.autoprogress and not table.find(capabilities, "Use the blender") then return end
    tasks.add("blender", function()
        local ticketsneeded = amount
        local displayname = eggtypesmodule.Get(name).DisplayName
        local recipe = deepcopy(recipes.Get(name))
        recipe.Cost = recipe.Ingredients
        for i, v in pairs(recipe.Cost) do
            v.Amount = v.Amount * amount
        end
        if not reallycanafford(recipe) or not hasaccessshopfuncs.badgeguild() then return end
        ticketsneeded = math.ceil(ticketsneeded / (recipe.AutoCompletePerTicket))
        print("tickets:",ticketsneeded, "name:", displayname)
        if (getclientstatcache("Eggs", "Ticket") or 0) < ticketsneeded then return end
        tweento(workspace.Toys.Blender.Platform.Circle.Position+Vector3.new(0,5,0))
        if allvars.remotes then
            local fails = 0
            while events.ClientCall("BlenderCommand", "PlaceOrder", {
                Recipe = name,
                Count = amount
            }) == false and fails <= 3 do
                fails = fails + 1
                print("blender failure", name)
                task.wait(1)
            end
            events.ClientCall("BlenderCommand", "SpeedUpOrder")
            task.wait(1)
            updatestatcache()
            return
        end
        repeat task.wait() until ActivateButton.TextBox.Text == "Open the Blender Menu"
        hidealluis()
        local blenderui = LocalPlayer.PlayerGui.ScreenGui.Blender
        while not blenderui.Visible do
            pressactivatebutton()
            if blenderui.Visible then break end
            RunService.RenderStepped:Wait()
        end
        if not blenderui.Visible then return end
        while blenderui.Box.RecipeInfo.RecipeName.Text ~= ("- " .. displayname .. " -") do
            firesignal(blenderui.Box.ForwardButton.MouseButton1Click)
            RunService.RenderStepped:Wait()
        end
        firesignal(blenderui.Box.SelectBox.SelectButton.MouseButton1Click)
        while tonumber(blenderui.Box.QuantitySelect.QuantityLabel.Text) ~= amount do
            firesignal(blenderui.Box.QuantitySelect.PlusButton.MouseButton1Click)
            RunService.RenderStepped:Wait()
        end
        firesignal(blenderui.Box.QuantitySelect.ConfirmButton.MouseButton1Click)
        repeat task.wait() until blenderui.Box.RecipeProgress.Visible
        RunService.RenderStepped:Wait()
        firesignal(blenderui.Box.RecipeProgress.TicketButton.MouseButton1Click)
        RunService.RenderStepped:Wait()
        local startTime = tick()
        repeat clickframe(box.Box.YesButton) until not box.Visible or tick() - startTime > 5
        if tick() - startTime > 5 then
            firesignal(blenderui.Box.RecipeProgress.EndButton.MouseButton1Click)
        end
        RunService.RenderStepped:Wait()
        firesignal(blenderui.Box.CloseButton.MouseButton1Click)
        task.wait(1.5)
        showalluis()
    end)
end

function hasearnbadges(amount, tier)
    local unlocked = 0
    for _, badgetier in pairs(getclientstatcache("Badges")) do
        if badgetier >= tier then
            unlocked = unlocked + 1
        end
    end
    return unlocked >= amount
end

function sortbestbadges(amount, tier, lowestrequired, claimonly)
    local tofarm = {}
    local tiermul = {1, 10, 100, 1000, 20000}
    for i, v in pairs(badgesmodule:GetSets()) do
        if allvars.autoprogress and badgesmodule.CheckIfSetIsReadyToCollect(v.Name, getclientstatcache()) then
            smartclaimbadge(v.Name, getclientstatcache("Badges")[v.Name])
            continue
        end
        if claimonly then continue end
        if #tofarm >= amount then break end
        if ((getclientstatcache("Badges") or {})[v.Name] or 0) >= tier then continue end
        local task = v.Task
        if task.Type == "Collect Pollen" and #getbeesdata().all >= (allvars.fieldbeereqs[task.Zone] or math.huge) then
            local reqpollen = task.Amounts and task.Amounts[tier] or (task.Amount * tiermul[tier])
            local done = getclientstatcache("Totals", "Pollen", "Zones", task.Zone) or 0
            table.insert(tofarm, {zone=task.Zone,amount=reqpollen-done,req=reqpollen,done=done,name=v.Name})
        end
    end
    if allvars.autoprogress then
        local orderindex = {}
        for i, zone in ipairs(allvars.autoprogbadgeorder) do
            orderindex[zone] = i
        end
        table.sort(tofarm, function(a, b)
            local ai = orderindex[a.zone] or math.huge
            local bi = orderindex[b.zone] or math.huge
            if ai ~= bi then
                return ai < bi
            end
            if lowestrequired then
                return a.amount < b.amount
            else
                return a.amount > b.amount
            end
        end)
    else
        table.sort(tofarm, function(a, b)
            if lowestrequired then
                return a.amount < b.amount
            else
                return a.amount > b.amount
            end
        end)
    end
    return tofarm
end

function reallycanafford(data, autoprog)
    local affordhoney = true
    local requirementsmet = true
    local hasmaterials = true
    for i, v in pairs(data.Cost) do
        if v.Type == nil then
            if getclientstatcache("Honey") < v.Amount then
                affordhoney = false
            end
        else
            if not getclientstatcache(v.Category, v.Type) or getclientstatcache(v.Category, v.Type) < v.Amount then
                if not autoprog then
                    local function craft()
                        blendercraft(v.Type, v.Amount - (getclientstatcache(v.Category, v.Type) or 0))
                    end
                    if v.Type == "Glitter" then
                        if table.find(allvars.allowedcrafts, "Glitter") then
                            craft()
                        end
                    elseif v.Type == "MoonCharm" then
                        if table.find(allvars.allowedcrafts, "Moon Charm") then
                            craft()
                        else
                            allvars.forcetasks.fireflies = true
                        end
                    elseif v.Type == "Stinger" then
                        allvars.forcetasks.killvic = true
                    else
                        if table.find(allvars.allowedcrafts, eggtypesmodule.Get(v.Type).DisplayName) then
                            craft()
                        end
                    end
                end
                hasmaterials = false
            end
        end
    end

    for i, v in pairs(data.Requirements) do
        if v.Type == "Completed Quests" then
            if not getclientstatcache("Totals", "QuestPoolCounts", v.Pool) or getclientstatcache("Totals", "QuestPoolCounts", v.Pool) < v.Amount then
                requirementsmet = false
            end
        elseif v.Type == "Earn Badges" then
            if not hasearnbadges(v.Amount, v.Tier) then
                allvars.forcetasks.autoprogbadges = sortbestbadges(v.Amount, v.Tier, true)
                requirementsmet = false
            end
        end
    end

    return affordhoney and requirementsmet and hasmaterials
end

function getbeesdata()
    local gifted = {}
    local all = {}
    local emptycells = 0
    for i, v in pairs(allvars.hive.Cells:GetChildren()) do
        local bee = {}
        if v:FindFirstChild("Faceplate") and v.CellType.Value ~= "Empty" then
            bee.name = v.CellType.Value
            bee.Gifted = v:FindFirstChild("GiftedCell") ~= nil
            bee.X = v.CellX.Value
            bee.Y = v.CellY.Value
            if bee.gifted then table.insert(gifted, bee) end
            table.insert(all, bee)
        elseif v.CellType.Value == "Empty" and not v.CellLocked.Value then
            emptycells = emptycells + 1
        end
    end
    return {
        gifted = gifted,
        all = all,
        emptycells = emptycells
    }
end

function truncatetime(sec)
    local second = tostring(math.round(sec)%60)
    local minute = tostring(math.floor(sec / 60 - math.floor(sec / 3600) * 60))
    local hour = tostring(math.floor(sec / 3600))

    return (#hour == 1 and "0"..hour or hour)..":"..(#minute == 1 and "0"..minute or minute)..":"..(#second == 1 and "0"..second or second)
end

function truncate(num)
    num = tonumber(math.round(num))
    if not num or num ~= num then return "0" end
    local neg = num < 0
    if neg then num = -num end
    if num == 0 then return "0" end
    local savenum = ""
    local i = 0
    local suffixes = {"k","M","B","T","qd","Qn","sx","Sp","O","N"}
    while num > 999 do
        i = i + 1
        local suff = suffixes[i]
        if suff == nil then
            return neg and "-inf" or "inf"
        end
        num = num/1000
        local n = math.floor(num*100)/100
        local s = (n == math.floor(n)) and tostring(math.floor(n)) or tostring(n)
        savenum = s..suff
    end
    local result = i == 0 and tostring(num) or savenum
    return neg and "-"..result or result
end

function getEggPrice(bought)
    local base = 1000
    local cost = base
    for i = 0, bought - 1 do
        cost = 1.5 * cost + base / (i + 1)
    end
    return math.min(cost, 10000000)
end

function getlootimagebyname(name)
    return eggtypes:FindFirstChild(name .. "Icon") and eggtypes:FindFirstChild(name .. "Icon").Texture
end

function openbsstab(name)
    local eggscontent =
        LocalPlayer.PlayerGui
            :WaitForChild("ScreenGui")
            :WaitForChild("Menus")
            :WaitForChild("Children")
            :WaitForChild(name)
            :WaitForChild("Content")

    local function openeggs()
        pcall(function()
            if eggscontent.Parent.Position.X.Scale < 0 then
                local start = 0
                repeat
                    if tick() - start > 1.5 then
                        start = tick()
                        firesignal(LocalPlayer.PlayerGui.ScreenGui.Menus.ChildTabs[name .. " Tab"].MouseButton1Click)
                    end
                    task.wait()
                until eggscontent.Parent.Position.X.Scale == 0
            end
        end)

        return eggscontent
    end
    
    return openeggs()
end

function smartfeedbee(cell, treat, tosearch, amount)
    tasks.add("feeding cell", function()
        local success, result = pcall(function()
            if allvars.remotes then
                local NewTreatAmount, Modified, NewHoneycomb, NewDiscoveredBees, EggUses = events.ClientCall("ConstructHiveCellFromEgg", cell.CellX.Value, cell.CellY.Value, treat:gsub(" ", ""):gsub("Egg", ""), amount or 1, false)
                if Modified then
                    clientstatcache:Set({ "Eggs", treat }, NewTreatAmount)
                    clientstatcache:Set("DiscoveredBees", NewDiscoveredBees)
                    clientstatcache:Set("Honeycomb", NewHoneycomb)
                    clientstatcache:Set({ "Totals", "EggUses" }, EggUses)
                    require(game.ReplicatedStorage.GateManager).UpdateGateColors()
                end
                return
            end
            hidealluis()
            local content
            content = openbsstab("Eggs")
            local TIMEOUT = 10
            local startTime = tick()

            local function finditeminventorybyname(name)
                content = openbsstab("Eggs")
                for _, child in ipairs(content.EggRows:GetChildren()) do
                    if child.Name == "EggRow" and child.TypeName.Text == name then
                        return child
                    end
                end
            end

            local function isVisible(frame)
                local sfPos = content.AbsolutePosition
                local sfSize = content.AbsoluteSize

                local fPos = frame.AbsolutePosition
                local fSize = frame.AbsoluteSize

                return fPos.Y >= sfPos.Y and (fPos.Y + fSize.Y) <= (sfPos.Y + sfSize.Y)
            end

            while (tick() - startTime) < TIMEOUT do
                content = openbsstab("Eggs")
                local row = finditeminventorybyname(treat)
                if row and isVisible(row) then
                    local startTime = tick()
                    repeat
                        for i = 1, 5 do
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.O, false, game, 0)
                            RunService.RenderStepped:Wait()
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.O, false, game, 0)
                            RunService.RenderStepped:Wait()
                        end
                        local icon = row:FindFirstChild("EggSlot")
                        if not icon then return showalluis() end
                        local cam = workspace.CurrentCamera
                        cam.CameraType = Enum.CameraType.Scriptable
                        cam.CFrame = CFrame.fromMatrix(cam.CFrame.Position, Vector3.new(-1,0,0), Vector3.new(0,1,0))
                        RunService.RenderStepped:Wait()
                        local cellpos = cam:WorldToViewportPoint(cell.Backplate.Position)
                        holdframeandmove(icon, cellpos.X, cellpos.Y)
                    until box.Visible or tick() - startTime > TIMEOUT

                    if box.Box.TextBox.Text:find(tosearch or treat) then
                        local startTime = tick()
                        repeat clickframe(box.Box.YesButton) until not box.Visible or tick() - startTime > TIMEOUT
                        return showalluis()
                    else
                        local startTime = tick()
                        repeat clickframe(box.Box.NoButton) until not box.Visible or tick() - startTime > TIMEOUT
                    end
                else
                    local x, y = getCenter(content)
                    VirtualInputManager:SendMouseWheelEvent(x, y, false, game)
                end
                wait(0.02)
            end
            showalluis()
        end)
        if not success then
            warn("smartfeedbee:", result)
        end
        showalluis()
    end)
end

function getbeelevelforcombat()
    return math.round(honeycombfile.GetAverageBeeLevel(getclientstatcache("Honeycomb")))
end

function buygear(gearName, shop, amount)
    task.spawn(function()
        if allvars.discordwebhookenabled and allvars.discordwebhookurl:match("(https://discord%.com)") then
            supersaferequest(allvars.discordwebhookurl, "POST", nil, HttpService:JSONEncode(buildautoprogbuybody(gearName, allvars.autoprogress)))
        end
    end)
    tasks.add("buying gear", function()
        local pos
        if shop == "noob" then
            pos = Vector3.new(91, 5, 290)
        elseif shop == "pro" then
            pos = Vector3.new(160, 69, -161)
        elseif shop == "redhq" then
            pos = Vector3.new(-327, 20, 205)
        elseif shop == "bluehq" then
            pos = Vector3.new(294, 4, 98)
        elseif shop == "dapper" then
            pos = Vector3.new(515, 138, -327)
        elseif shop == "top" then
            pos = Vector3.new(-18, 176, -127)
        elseif shop == "badgeguild" then
            pos = Vector3.new(-393, 69, 1)
        elseif shop == "basicegg" then
            pos = Vector3.new(-139, 5, 244)
        elseif shop == "petal" then
            pos = Vector3.new(-500, 52, 477)
        elseif shop == "coconut" then
            pos = Vector3.new(-139, 72, 505)
        elseif shop == "bean" then
            pos = Vector3.new(351, 92, -81)
        elseif shop == "ticket" then
            pos = Vector3.new(-16, 184, -225)
        end
        if not allvars.api.magnitude(allvars.api.getRoot().Position, pos, 8) then
            tweento(pos)
        end
        if allvars.remotes then
            local gearinstance = workspace.Shops:FindFirstChild(gearName, true) or workspace.Shops:FindFirstChild(gearName:gsub(" ", ""), true)
            if not gearinstance then error("gearinstance is nil so no buy item goodbye") end
            local fails = 0
            local function purchase()
                local res = events.ClientCall("ItemPackageEvent", "Purchase", {
                    Type = gearinstance.ItemType.Value,
                    Category = gearinstance.ItemCategory.Value,
                    Amount = gearinstance:FindFirstChild("ItemAmount") and (amount or 1) or nil
                })
                updatestatcache()
                return res
            end
            while fails <= 3 do
                local res = purchase()
                if res == true then
                    return
                else
                    fails = fails + 1
                    warn("purchase failure", gearName, res)
                    task.wait(1)
                end
            end
            return
        end
        repeat task.wait() until ActivateButton.TextBox.Text == "Open Shop" or ActivateButton.TextBox.Text == "Leave Shop"
        while ActivateButton.TextBox.Text == "Open Shop" do
            pressactivatebutton()
            --print("opening shop")
            if ActivateButton.TextBox.Text == "Leave Shop" then break end
            RunService.RenderStepped:Wait()
        end
        local shopui = LocalPlayer.PlayerGui.ScreenGui.Shop
        local activeshop = LocalPlayer.PlayerGui.Camera.Controllers.Shop.ActiveShop.Value
        local itemsorders = {}
        for i, v in pairs(activeshop.Items:GetChildren()) do
            itemsorders[v.Name] = v.Order.Value
        end
        while shopui.ItemInfo.ItemName.Text ~= gearName do
            if ActivateButton.TextBox.Text ~= "Leave Shop" then return end
            local maxIndex = #activeshop.Items:GetChildren()
            local current = itemsorders[shopui.ItemInfo.ItemName.Text]
            local target = itemsorders[gearName]
            local distRight = (target - current) % maxIndex
            local distLeft = (current - target) % maxIndex
            local btn = distLeft < distRight and "LeftButton" or "RightButton"
            firesignal(shopui.Scroller[btn].MouseButton1Click)
            RunService.Heartbeat:Wait()
            task.wait(0.1)
        end
        local normalprice = shopui.ItemInfo.ItemCost.Text
        firesignal(shopui.Scroller.BuyButton.MouseButton1Click)
        repeat task.wait() until not shopui.Scroller.BuyButton.Text:find("Buy") or ActivateButton.TextBox.Text ~= "Leave Shop" or shopui.ItemInfo.ItemCost.Text ~= normalprice
        if ActivateButton.TextBox.Text ~= "Leave Shop" then return end
        --print("done")
        local start = 0
        repeat
            if tick() - start >= 0.8 then
                pressactivatebutton()
                start = tick()
            end
            task.wait()
        until ActivateButton.TextBox.Text ~= "Leave Shop"
    end)
end

function addbasicbee()
    local result = nil
    tasks.add("hatching egg", function()
        local basiceggs = getclientstatcache("Eggs", "Basic") or 1
        if basiceggs < 1 then
            local bought = getclientstatcache("Totals", "Purchases", "Eggs", "Basic") or 1
            if getclientstatcache("Honey") < getEggPrice(bought) then return end
            buygear("Basic Egg", "basicegg")
        end
        basiceggs = getclientstatcache("Eggs", "Basic")
        tweento((LocalPlayer.SpawnPos.Value+Vector3.new(allvars.hive.Name == "Hive6" and 19 or -19, 0,12)).Position, nil, nil, true)
        local used = 0
        for y = 1, 10 do
            for x = 1, 5 do
                local oldcell = allvars.hive.Cells["C" .. x .. "," .. y]
                if oldcell:FindFirstChild("Faceplate") then
                    if oldcell.CellType.Value == "BasicBee" then
                        if (getclientstatcache("Eggs", "RoyalJelly") or 0) > 0 then
                            print(
                                "feed1",
                                "x:", x,
                                "y:", y,
                                "oldcell:", oldcell,
                                "newcell:", allvars.hive.Cells["C" .. x .. "," .. y],
                                "same:", allvars.hive.Cells["C" .. x .. "," .. y] == oldcell,
                                "celltype:", oldcell.CellType.Value,
                                "newcelltype:", allvars.hive.Cells["C" .. x .. "," .. y].CellType.Value,
                                "faceplate:", oldcell:FindFirstChild("Faceplate"),
                                "newfaceplate:", allvars.hive.Cells["C" .. x .. "," .. y]:FindFirstChild("Faceplate")
                            )
                            smartfeedbee(oldcell, "Royal Jelly", "Transform")
                            continue
                        end
                    end
                end
                if not oldcell.CellLocked.Value and oldcell.CellType.Value == "Empty" and getclientstatcache("Eggs", "Basic") > 0 then
                    smartfeedbee(oldcell, "Basic Egg")
                    local s, bee = pcall(function()
                        local start = tick()
                        repeat
                            oldcell = allvars.hive.Cells:WaitForChild("C" .. x .. "," .. y)
                            task.wait()
                        until oldcell.CellType.Value:sub(-3) == "Bee" or tick() - start > 3
                        if tick() - start > 3 then error("timeout " .. oldcell.CellType.Value) end
                        return oldcell.CellType.Value:sub(1, -4)
                    end)
                    if s then print("Hatched \"" .. tostring(bee) .. "\" bee") else warn(bee) end
                    if (getclientstatcache("Eggs", "RoyalJelly") or 0) > 0 and tostring(bee) == "Basic" then
                        repeat task.wait() until allvars.hive.Cells["C" .. x .. "," .. y]:FindFirstChild("Faceplate")
                        task.wait(0.2)
                        print(
                            "feed2",
                            "x:", x,
                            "y:", y,
                            "oldcell:", oldcell,
                            "newcell:", allvars.hive.Cells["C" .. x .. "," .. y],
                            "same:", allvars.hive.Cells["C" .. x .. "," .. y] == oldcell,
                            "celltype:", oldcell.CellType.Value,
                            "newcelltype:", allvars.hive.Cells["C" .. x .. "," .. y].CellType.Value,
                            "faceplate:", oldcell:FindFirstChild("Faceplate"),
                            "newfaceplate:", allvars.hive.Cells["C" .. x .. "," .. y]:FindFirstChild("Faceplate")
                        )
                        smartfeedbee(oldcell, "Royal Jelly", "Transform")
                    end
                    used = used + 1
                    if used >= basiceggs then result = true return end
                end
            end
        end
        result = false
    end)
    return result
end

function getBuffTime(buffName, convertToHMS)
    local buff = bufftilemodule.GetBuffTile(buffName)
    if not buff or not buff.TimerDur or not buff.TimerStart then 
        return 0 
    end

    local toReturn = buff.TimerDur - (math.floor(require(ReplicatedStorage.OsTime)()) - buff.TimerStart)
    if convertToHMS then 
        toReturn = truncatetime(toReturn) 
    end
    
    return toReturn
end

function isNight()
    return not (game:GetService("Lighting").ClockTime > 10)
end

function isfarmingpopstar()
    local popstartime = getBuffTime("Pop Star Aura")
    if popstartime > 0 and allvars.farmbloat then return true end
    local bubblebloat = getBuffTime("Bubble Bloat")
    if popstartime > 0 and bubblebloat > 0 and allvars.farmbloatwhenlow and bubblebloat < 7500 then return true end

    return false
end

function getBagPercentage()
    local pollencount = LocalPlayer.CoreStats.Pollen.Value
    local maxpollen = LocalPlayer.CoreStats.Capacity.Value
    local percentage = pollencount / maxpollen * 100
    return percentage
end

function getpolleninballoon()
    for i, v in pairs(workspace.Balloons.HiveBalloons:GetChildren()) do
        if v.Name == "HiveBalloonInstance" and v:FindFirstChild("BalloonRoot") and v:FindFirstChild("BalloonBody") then
            if allvars.api.magnitude(v.BalloonRoot.Position * Vector3.new(1, 0, 0), LocalPlayer.SpawnPos.Value.Position * Vector3.new(1, 0, 0), 7) then
                local pollentext = 0
                local suc, res = pcall(function()
                    pollentext = v.BalloonBody.GuiAttach.Gui.Bar.TextLabel.Text:gsub(",", "")
                end)
                if not suc then warn("Error fetching pollen in balloon:", res) end
                return tonumber(pollentext)
            end
        end
    end
    return 0
end

function shouldconvertnow()
    local doconvert = false
    if getBagPercentage() >= allvars.convertatx then
        doconvert = "Converting at the hive"
    end
    if allvars.converthiveballoon then
        local blessing = getBuffTime("Balloon Blessing")
        if blessing <= (allvars.convertballoonat * 60) and getpolleninballoon() > 0 then
            doconvert = "Converting hive balloon"
        end
    end
    if isfarmingpopstar() then
        doconvert = false
    end
    return doconvert
end

function trytoconvert()
    tasks.add("convert handler", function()
        local toconvert = shouldconvertnow()
        if toconvert then
            print(toconvert) -- Prints the reason of converting
            local hivepos = (LocalPlayer.SpawnPos.Value + Vector3.new(0, 0, 7)).Position
            local root = allvars.api.getRoot()
            while root and root.Parent and allvars.isrunning and allvars.autofarm and allvars.autoconvert do
                local shouldistopnow = false
                if getBagPercentage() == 0 then
                    shouldistopnow = true
                end
                if allvars.converthiveballoon then
                    local blessing = getBuffTime("Balloon Blessing")
                    if blessing <= (allvars.convertballoonat * 60) then
                        shouldistopnow = false
                    end
                end
                if shouldistopnow then break end
                if not (allvars.api.magnitude(root.Position, hivepos, 6) and ActivateButton.Visible) then
                    tweento(hivepos, nil, nil, true)
                end
                local startedpressing = tick()
                while ActivateButton.TextBox.Text == "Make Honey" do
                    if allvars.remotes then
                        events.ClientCall("PlayerHiveCommand", "ToggleHoneyMaking")
                    else
                        pressactivatebutton()
                    end
                    if tick() - startedpressing >= 5 then
                        warn("Unable to convert!")
                        allvars.api.getHumanoid().Health = 0
                        startedpressing = tick()
                    end
                    task.wait(1.5)
                end
                task.wait()
            end
            if not root.Parent or not allvars.isrunning or not allvars.autofarm or not allvars.autoconvert then return end
            -- wait for all bees to finish converting
            local waiting = tick()
            while tick() - waiting <= 5 and allvars.autofarm and allvars.isrunning do task.wait() end
            allvars.lastfarmbadge = nil -- resend hooky
        end
    end)
end

function canCollectToken(token)
    return isfield(token.Position) 
        and (not allvars.api.magnitude(allvars.api.getRoot().Position * Vector3.new(1, 0, 1), token.Position * Vector3.new(1, 0, 1), 4))
        and (token.Position - isfield(token.Position).Position).Y <= 10 and (token.Position - isfield(token.Position).Position).Y >= 2
        and ispathclear(allvars.api.getRoot().Position, token.Position)
end

function farmobj(part, farmuntilgone, parttowait)
    tasks.add("farming object", function()
        local root = allvars.api.getRoot()
        local hum = allvars.api.getHumanoid()
        if not root or not hum then return end
        local start = tick()
        while task.wait() do
            if not (root.Parent and hum.Parent and part.Parent) then
                break
            end
            if not allvars.isrunning or not allvars.autofarm then return end
            if part:GetAttribute("collected") then
                return
            end
            if tick() - start >= 5 then
                task.spawn(function()
                    part:SetAttribute("collected", true)
                    task.wait(1.5)
                    part:SetAttribute("collected", false)
                end)
                return
            end
            if farmuntilgone and parttowait.Parent then
                hum:MoveTo(part.Position)
            else
                if not canCollectToken(part) then
                    part:SetAttribute("collected", true)
                else
                    hum:MoveTo(part.Position)
                end
            end
        end
    end)
end

function collecttokensonfield(field, forcetokens)
    if not forcetokens then
        if allvars.ignorealltokens then return end
    end
    local root = allvars.api.getRoot()
    local hum = allvars.api.getHumanoid()
    if not root or not hum then return end
    local sortedtokens = {}
    for i, v in pairs(workspace.Collectibles:GetChildren()) do
        if isfield(v.Position) and isfield(v.Position).Name == field.Name and not v:GetAttribute("collected") then
            local Priority = 1
            local Ignore = false
            if not ispathclear(root.Position, v.Position) then
                Ignore = true
            end
            if v:FindFirstChild("BackDecal") then
                if v.BackDecal.Texture == "rbxassetid://1629547638" then
                    Priority = math.huge
                elseif v.BackDecal.Texture == "rbxassetid://1472135114" and allvars.ignorehoneytokens and not forcetokens then
                    Ignore = true
                else
                    for i, priority in pairs(priorites) do
                        if v.BackDecal.Texture == priority.Asset and priority.Enabled then
                            Priority = priority.Default or 2
                        end
                    end
                end
            end
            if not Ignore then
                table.insert(sortedtokens, {
                    Distance = allvars.api.magnitude(root.Position, v.Position),
                    Priority = Priority,
                    Token = v
                })
            end
        end
    end
    table.sort(sortedtokens, function(a, b)
        if a.Priority ~= b.Priority then
            return a.Priority > b.Priority
        end
        return a.Distance < b.Distance
    end)
    local Token = #sortedtokens > 0 and sortedtokens[1].Token
    table.clear(sortedtokens)
    if not Token then
        return
    end
    farmobj(Token)
end

function smartclaimbadge(name, tier)
    tasks.add("claiming badge", function()
        local tries = 0
        while tries <= 3 do
            task.spawn(function()
                if allvars.discordwebhookenabled and allvars.discordwebhookurl:match("(https://discord%.com)") then
                    supersaferequest(allvars.discordwebhookurl, "POST", nil, HttpService:JSONEncode(buildbadgebody(name, nil, nil, true, tier)))
                end
            end)
            if allvars.remotes then
                if not events.ClientCall("BadgeEvent", "Collect", name) then
                    tries = tries + 1
                    task.wait(0.5)
                end
                updatestatcache()
            else
                hidealluis()
                local content
                content = openbsstab("Badges")
                local TIMEOUT = 10
                local startTime = tick()

                local function findbagebyname(name)
                    content = openbsstab("Badges")
                    for _, child in ipairs(content.Frame:GetChildren()) do
                        if child.Name == "BadgeBox" and child.TitleBar.Text:find(name .. " Badge") then
                            return child
                        end
                    end
                end

                local function isVisible(frame)
                    local sfPos = content.AbsolutePosition
                    local sfSize = content.AbsoluteSize

                    local fPos = frame.AbsolutePosition
                    local fSize = frame.AbsoluteSize

                    return fPos.Y >= sfPos.Y and (fPos.Y + fSize.Y) <= (sfPos.Y + sfSize.Y)
                end

                while (tick() - startTime) < TIMEOUT do
                    content = openbsstab("Badges")
                    local row = findbagebyname(name)
                    if row and isVisible(row) then
                        local startTime = tick()
                        while (tick() - startTime < TIMEOUT) and (row.TaskBar.FillBar.Size.X.Scale >= 1) and not row.TitleBar.Text:find("Grandmaster") do
                            clickframe(row.TaskBar.FillBar)
                        end
                        return warn("badge loop end"), showalluis()
                    else
                        local x, y = getCenter(content)
                        VirtualInputManager:SendMouseWheelEvent(x, y, y >= row.AbsolutePosition.Y, game)
                    end
                    wait(0.02)
                end
                showalluis()
            end
        end
    end)
end

function smartredeemcode(code)
    tasks.add("redeeming code", function()
        local tries = 0
        while tries <= 3 do
            if allvars.remotes then
                events.ClientCall("PromoCodeEvent", code)
            else
                openbsstab("System")
                pcall(function()
                    local promobox = LocalPlayer.PlayerGui.ScreenGui.Menus.Children.System.Content.PromoCodeBox
                    promobox.TextField.Text = code
                    firesignal(promobox.RedeemButton.MouseButton1Click)
                end)
            end
            task.wait(LocalPlayer:GetNetworkPing()+0.1)
            local codes = ReplicatedStorage.Events.RetrievePlayerStats:InvokeServer().Codes
            if table.find(codes or {}, code) then return end
            tries = tries + 1
        end
    end)
end

function randompoint(part)
    local size = part.Size / 1.75
    local cf = part.CFrame
    local x = math.random() - 0.5
    local z = math.random() - 0.5
    local localPos = Vector3.new(x * size.X, 0, z * size.Z)
    return cf:PointToWorldSpace(localPos)
end

function builddiscordtimestamp()
    return "<t:" .. os.time() .. ":T>"
end

function buildwebhookbody()
    local embed1 = {
        fields = {},
        color = 0x1cc3e3,
        author = {
            name = "Lunar - Honey Update",
            icon_url = "https://github.com/lunar-repo/pic/raw/main/Reindeer_Antlers.png"
        }
    }

    local embed2 = {
        fields = {},
        color = 0x1cc3e3,
        author = {
            name = "Lunar - Auto Progression",
            icon_url = "https://github.com/lunar-repo/pic/raw/main/Reindeer_Antlers.png"
        }
    }

    local embeds = {embed1}

    local blessing = bufftilemodule.GetBuffTile("Balloon Blessing")
    local balloonpollen = truncate(getpolleninballoon())

    table.insert(embed1.fields, {
        name = "<:honey:1514946024521601054> Honey Per Hour",
        value = allvars.honeyperhourstring,
        inline = true
    })

    table.insert(embed1.fields, {
        name = "<:honey:1514946024521601054> Session Honey",
        value = allvars.sessionhoneystring,
        inline = true
    })

    table.insert(embed1.fields, {
        name = "<:honey:1514946024521601054> Current Honey",
        value = truncate(getclientstatcache("Honey")),
        inline = true
    })

    table.insert(embed1.fields, {
        name = "<:time:1514946582884126820> Elapsed Time",
        value = allvars.elapsedtimestring,
        inline = true
    })

    table.insert(embed1.fields, {
        name = "<:blessing:1516865755344404730> Balloon Blessing",
        value = blessing and (blessing.Combo .. "x") or "0x",
        inline = true
    })

    table.insert(embed1.fields, {
        name = "<:bblessing:1516865755344404730> Balloon Pollen",
        value = balloonpollen,
        inline = true
    })

    table.insert(embed2.fields, {
        name = "<:tool:1514948429028261898> Next Item",
        value = allvars.nextautoprogitemstring:gsub("Next Item: ", ""),
        inline = true
    })

    table.insert(embed2.fields, {
        name = "<:hiveslot:1514948404848103556> Next Hive Slot",
        value = allvars.nexthiveslotstring:gsub("Next Hive Slot: ", ""),
        inline = true
    })

    table.insert(embed2.fields, {
        name = "<:basicegg:1514948357120856104> Next Egg",
        value = allvars.nextbasiceggstring:gsub("Next Egg: ", ""),
        inline = true
    })

    table.insert(embed2.fields, {
        name = "<:puppy:1514957876580581466> Bees",
        value = #getbeesdata().all,
        inline = true
    })

    if allvars.autoprogress then
        table.insert(embeds, embed2)
    end

    local body = {
        content = string.rep("-", 30),
        embeds = embeds
    }

    return body
end

function builddisconnectbody(reason)
    local body = {
        content = string.rep("-", 30),
        embeds = {{
            fields = {},
            color = 0xd62c29,
            author = {
                name = "Lunar - Disconnected",
                icon_url = "https://github.com/lunar-repo/pic/raw/main/warn.png"
            },
            description = reason,
        }}
    }

    return body
end

function builddeathbody()
    local deathinfield = allvars.api.getRoot() and isfield(allvars.api.getRoot().Position)
    local body = {
        content = string.rep("-", 30),
        embeds = {{
            fields = {},
            color = 0xFF8585,
            author = {
                name = "Lunar - Died",
                icon_url = "https://github.com/lunar-repo/pic/raw/main/Reindeer_Antlers.png"
            },
            description = (deathinfield and (":cry: You died in the " .. deathinfield.Name) or ":cry: You died") .. ". " .. builddiscordtimestamp()
        }}
    }

    return body
end

function buildautoprogbuybody(name, autoprog)
    local body = {
        content = string.rep("-", 30),
        embeds = {{
            fields = {},
            color = 0x4AFF8C,
            author = {
                name = "Lunar" .. (autoprog and " - Auto Progression" or ""),
                icon_url = "https://github.com/lunar-repo/pic/raw/main/Reindeer_Antlers.png"
            },
            description = "Buying " .. name .. " " .. builddiscordtimestamp(),
            title = "<:tool:1514948429028261898> Purchasing Item"
        }}
    }

    return body
end

function buildviciousbody(field, viclevel, gifted)
    local body = {
        content = string.rep("-", 30),
        embeds = {{
            fields = {},
            color = 0,
            author = {
                name = "Lunar - Combat",
                icon_url = "https://github.com/lunar-repo/pic/raw/main/Reindeer_Antlers.png"
            },
            description = "Attacking level " .. viclevel .. (gifted and " gifted " or " ") .. "vicious bee in the " .. field .. " " .. builddiscordtimestamp(),
            title = "<:vic:1517959433374793799> Vicious Bee"
        }}
    }

    return body
end

function buildfirefliesbody(field)
    local body = {
        content = string.rep("-", 30),
        embeds = {{
            fields = {},
            color = 0xFFF04A,
            author = {
                name = "Lunar - Fireflies",
                icon_url = "https://static.wikia.nocookie.net/bee-swarm-simulator/images/0/06/FirefliesFlying.png/revision/latest?cb=20231204025707"
            },
            title = "Fireflies detected",
            description = "In the " .. field .. " " .. builddiscordtimestamp()
        }}
    }

    return body
end

function buildbadgebody(field, req, done, redeem, tier)
    local body = {
        content = string.rep("-", 30),
        embeds = {{
            fields = {},
            color = 0x8f00ff,
            author = {
                name = "Lunar - Badges",
                icon_url = "https://github.com/lunar-repo/pic/raw/main/Reindeer_Antlers.png"
            },
            title = "<:badge:1518701426669519078> " .. (not redeem and "Farming" or "Redeeming") .. " " .. field .. " Badge",
            description = not redeem and string.format("Current Progress: %s/%s", truncate(done), truncate(req)) or string.format("Current Tier: %s", badgesmodule.GetTierNames()[tier+1])
        }}
    }

    return body
end

function findaphid(field)
    for i, v in pairs(workspace.Monsters:GetChildren()) do
        if v.Name:lower():find("Aphid") and v:FindFirstChild("HumanoidRootPart") and isfield(v.HumanoidRootPart.Position) == field then
            return v
        end
    end
end

function avoidmobs(field)
    if not allvars.avoidmobs then return end
    tasks.add("avoiding mob", function()
        if not allvars.autofarm or not allvars.isrunning then return end
        local humanoid = allvars.api.getHumanoid()
        local root = allvars.api.getRoot()
        if not humanoid or humanoid.Health <= 0 or not root then return end

        local aphid = findaphid()
        if aphid then
            local function getaphidpos()
                return aphid.HumanoidRootPart.Position
            end

            local function clamptozone(pos, zonepart)
                local cf = zonepart.CFrame
                local half = zonepart.Size/2
                local localpos = cf:PointToObjectSpace(pos)
                local x = math.clamp(localpos.X, -half.X, half.X)
                local z = math.clamp(localpos.Z, -half.Z, half.Z)
                return cf:PointToWorldSpace(Vector3.new(x, localpos.Y, z))
            end

            while aphid.Parent and task.wait() do
                local playerpos = allvars.api.getRoot().Position
                local aphidpos = getaphidpos()
                local threshold = aphid.PrimaryPart.Size.Magnitude * 1.5

                local toplayer = playerpos - aphidpos
                local dist = toplayer.Magnitude

                if dist < threshold then
                    local awaydir = toplayer.Unit
                    local towardcenter = (field.Position - playerpos).Unit

                    local movedir = (awaydir * 0.7 + towardcenter * 0.3).Unit
                    local movepos = playerpos + movedir * threshold
                    movepos = clamptozone(movepos, field)
                    humanoid:MoveTo(movepos)
                end
            end
        end

        local werewolf = workspace.Monsters:FindFirstChild("Werewolf (Lvl 7)")
        if werewolf and werewolf:FindFirstChild("Target") and werewolf.Target.Value == LocalPlayer.Character then
            print("avoiding werewolf")
            tweento(workspace.NewFlowerZones["Cactus Field"].Position, 16)
            while werewolf.Parent do
                humanoid.Jump = true
                task.wait(0.8)
            end
            return print("avoided the big bad wolf")
        end

        local monsterTarget = {}
        for _, v in pairs(workspace.Monsters:GetChildren()) do
            if v.Name:find("Vicious") or v.Name:find("Stump") or v.Name:find("Windy") or v.Name:find("Stick") or v.Name:find("Aphid") then continue end
            if v:FindFirstChild("HumanoidRootPart") and isfield(v.HumanoidRootPart.Position) == field and v:FindFirstChild("Target") and v.Target.Value == LocalPlayer.Character then
                table.insert(monsterTarget, v)
            end
        end

        if #monsterTarget > 0 then
            safewalk(field.Position, true)
            for i, v in pairs(monsterTarget) do
                local i = 0
                local starthp = v.Humanoid.Health
                local starttick = tick()
                while humanoid.Parent and v.Parent and task.wait() do
                    if v.Humanoid.Health == starthp and tick() - starttick >= 45 then
                        warn("timeout on attack no damage dealt")
                        local tweeningposition = Instance.new("AlignPosition")
                        tweeningposition.Mode = Enum.PositionAlignmentMode.OneAttachment
                        tweeningposition.Attachment0 = root.RootAttachment
                        tweeningposition.MaxForce = math.huge
                        tweeningposition.Position = field.Position + Vector3.new(0, 30, 0)
                        tweeningposition.Parent = root
                        tweeningposition.MaxVelocity = 150
                        tweeningposition.Name = "monsterfix"

                        local tweeningorientation = Instance.new("AlignOrientation")
                        tweeningorientation.Attachment0 = root.RootAttachment
                        tweeningorientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
                        tweeningorientation.RigidityEnabled = true
                        tweeningorientation.CFrame = root.CFrame
                        tweeningorientation.Parent = root
                        tweeningorientation.Name = "monsterfix"
                        repeat task.wait() until not v.Parent
                        tweeningposition.Position = field.Position + Vector3.new(0, 5, 0)
                        repeat task.wait() until allvars.api.magnitude(root.Position, field.Position + Vector3.new(0, 5, 0), 3)
                        tweeningposition:Destroy()
                        tweeningorientation:Destroy()
                    end
                    if not allvars.autofarm or not allvars.isrunning then return end
                    if field.Name == "Pine Tree Forest" then
                        local p = Vector3.new(0, 0, 10)
                        i = i + 1
                        if i % 2 == 0 then
                            safewalk(field.Position + p, true)
                        else
                            safewalk(field.Position - p, true)
                        end
                    end
                    humanoid.Jump = true
                    task.wait(0.8)
                end
            end
        end
    end)
end

function farmfireflies()
    if not allvars.api.getRoot() then return {} end
    if not isNight() then
        allvars.fireflyfield = nil
    end
    local flies = {}
    for i, v in pairs(workspace.NPCBees:GetChildren()) do
        if v.Name == "Firefly" then
            local fireflyfield = isfield(v.Position)
            local fields = {
                "Spider Field",
                "Bamboo Field",
                "Strawberry Field",
                "Rose Field",
                "Pineapple Patch",
                "Cactus Field"
            }
            for _, v in pairs(deepcopy(fields)) do
                if #getbeesdata().all < allvars.fieldbeereqs[v] then
                    table.remove(fields, table.find(fields, v))
                end
            end
            if fireflyfield and v.BodyVelocity.Velocity == Vector3.zero and allvars.fireflyfield ~= fireflyfield and (v.Position - fireflyfield.Position).Y < 3 then
                allvars.fireflyfield = fireflyfield
                if not table.find(fields, fireflyfield.Name) then
                    allvars.fireflyfield = nil
                    return {}
                end
                print("Fireflies in the " .. tostring(fireflyfield))
                task.spawn(function()
                    if allvars.discordwebhookenabled and allvars.discordwebhookurl:match("(https://discord%.com)") then
                        supersaferequest(allvars.discordwebhookurl, "POST", nil, HttpService:JSONEncode(buildfirefliesbody(fireflyfield.Name)))
                    end
                end)
            end
            if (fireflyfield and table.find(fields, fireflyfield.Name) and v.BodyVelocity.Velocity == Vector3.zero) or allvars.fireflyfield then
                allvars.fieldtofarm = allvars.fireflyfield
            end
            if fireflyfield and table.find(fields, fireflyfield.Name) and allvars.api.getRoot() and isfield(allvars.api.getRoot().Position) == fireflyfield and v.BodyVelocity.Velocity == Vector3.zero  then
                if not table.find(flies, v) then
                    table.insert(flies, v.Position)
                end
            end
        end
    end

    local current = allvars.api.getRoot().Position
    local sorted = {}
    local remaining = {table.unpack(flies)}

    while #remaining > 0 do
        local bestIdx, bestDist = 1, (remaining[1] - current).Magnitude
        for i = 2, #remaining do
            local d = (remaining[i] - current).Magnitude
            if d < bestDist then bestIdx, bestDist = i, d end
        end
        current = table.remove(remaining, bestIdx)
        table.insert(sorted, current)
    end

    return sorted
end

function getmetorites()
    local meteors = {}
    local field
    for i, v in pairs(workspace.Particles:GetChildren()) do
        if v.Name == "WarningDisk" and tostring(v.BrickColor) == "Royal Purple" then
            table.insert(meteors, {part=v, size=v.Size.X, trans=v.Transparency})
            local mfield = isfield(v.Position)
            if mfield and #getbeesdata().all >= allvars.fieldbeereqs[mfield] then
                field = mfield
            end
        end
    end

    -- prioritize the rites
    table.sort(meteors, function(a, b)
        local scoreA = a.size + (a.trans * 10)
        local scoreB = b.size + (b.trans * 10)
        return scoreA < scoreB
    end)

    if #meteors == 0 then
        allvars.lastmeteordetect = tick()
    end

    return meteors, field
end

function farmmeteorites()
    local meteors, field = getmetorites()
    if field and #meteors > 0 then
        tasks.add("farming meteors", function()
            while tick() - allvars.lastmeteordetect <= 8 do
                meteors, field = getmetorites()
                if field and #meteors > 0 then
                    local root = allvars.api.getRoot()
                    if not root then continue end
                    local fieldmag = allvars.api.magnitude(root.Position * Vector3.new(0, 1, 0), field.Position * Vector3.new(0, 1, 0), 25)
                    if not isfield(root.Position) or isfield(root.Position).Name ~= field.Name or not fieldmag then
                        tweento(field.Position + Vector3.new(0, 5, 0))
                    end
                    local bestmeteor = meteors[1]
                    farmobj(bestmeteor, true, bestmeteor)
                    local j = tick()
                    while tick() - j >= 6 do
                        collecttokensonfield()
                        task.wait()
                    end
                end
            end
        end)
    end
end

function getnexthiveslotprice()
    local slot = (getclientstatcache("Totals", "Purchases", "HiveSlots") or 0) + 1
    local cost = 3000000
    for i = 0, slot - 2 do
        if slot <= 15 then
            cost = cost + cost * 0.25 + cost / (i + 1) + 1000000
        else
            local scale = (slot - 15) / 10
            cost = cost + cost * (0.24 + 0.35 * math.pow(scale, 1.2)) + cost / (i + 1) + 1000000
        end
    end
    return math.floor(cost + 0.5)
end

function getsprinkler()
    return getclientstatcache("EquippedSprinkler")
end

function placesprinklers(field, samespot)
    tasks.add("placing sprinklers", function()
        local jumps = {
            B = 1, S = 2, G = 3, D = 4, T = 1
        }
        local sprinkler = getsprinkler()
        if sprinkler == "None" then return end
        print(string.format("Placing %s in %s", sprinkler, field.Name))
        local shortname = sprinkler:sub(1, 1)
        local WAIT_TIME = 0
        local JUMP_TIME = 0.4
        local NEXT = 0
        local lastuse = tick()
        for i = 1, jumps[shortname] or 0 do
            local root, hum = allvars.api.getRoot(), allvars.api.getHumanoid()
            if not root or not hum then continue end
            if field and not samespot then
                if shortname == "B" or shortname == "T" then
                    safewalk(field.Position)
                    wait(WAIT_TIME)
                elseif shortname == "S" then
                    if i == 1 then
                        safewalk(field.Position + Vector3.new(20, 0, 0))
                        wait(WAIT_TIME)
                    else
                        safewalk(field.Position - Vector3.new(20, 0, 0))
                        wait(WAIT_TIME)
                    end
                elseif shortname == "G" then
                    if i == 1 then
                        safewalk(field.Position + Vector3.new(20, 0, 0))
                        wait(WAIT_TIME)
                    elseif i == 2 then
                        safewalk(field.Position - Vector3.new(20, 0, 0))
                        wait(WAIT_TIME)
                    else
                        safewalk(field.Position + Vector3.new(0, 0, 20))
                        wait(WAIT_TIME)
                    end
                elseif shortname == "D" then
                    if i == 1 then
                        safewalk(field.Position + Vector3.new(20, 0, 0))
                        wait(WAIT_TIME)
                    elseif i == 2 then
                        safewalk(field.Position - Vector3.new(20, 0, 0))
                        wait(WAIT_TIME)
                    elseif i == 3 then
                        safewalk(field.Position + Vector3.new(0, 0, 20))
                        wait(WAIT_TIME)
                    else
                        safewalk(field.Position - Vector3.new(0, 0, 20))
                        wait(WAIT_TIME)
                    end
                end
            end

            local function isready()
                return tick() - lastuse >= (1.5 + LocalPlayer:GetNetworkPing())
            end
            if not isready() then
                repeat task.wait() until isready()
            end
            lastuse = tick()
            local oldjp = hum.JumpPower
            hum.JumpPower = 70
            hum.Jump = true
            task.wait(JUMP_TIME)
            hum.JumpPower = oldjp
            events.ClientCall("PlayerActivesCommand", {Name = "Sprinkler Builder"})
            if NEXT > 0 then task.wait(NEXT) end
        end
    end)
end

local function addBounds(model)
    local cf, size = model:GetBoundingBox()

    local bounds = Instance.new("Part")
    bounds.Name = "bounds"
    bounds.Size = size + Vector3.new(16, 16, 16, 16)
    bounds.CFrame = cf
    bounds.Transparency = 1
    bounds.CanCollide = false
    bounds.CanTouch = false
    bounds.CanQuery = false
    bounds.Anchored = true
    bounds.Parent = model

    return bounds
end

function getharmfulobjects()
    local warningDisks = {}
    for i,v in pairs(workspace.Particles:GetChildren()) do
        if v.Name == "WarningDisk" or v.Name == "Thorn" or v.Name == "Vicious" then 
            table.insert(warningDisks, v) 
        end
    end
    for i,v in pairs(workspace.Monsters:GetChildren()) do
        if not v:FindFirstChild("bounds") then
            addBounds(v)
        end
        table.insert(warningDisks, v.bounds) 
    end
    return warningDisks
end

function ispathclear(fromPos, toPos)
    local dir = toPos - fromPos
    if dir.Magnitude < 0.01 then return true end
    local mid = (fromPos + toPos) / 2
    local dist = dir.Magnitude
    local cf = CFrame.lookAt(mid, mid + dir.Unit)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    for _, disk in pairs(getharmfulobjects()) do
        params.FilterDescendantsInstances = {disk}
        local s = disk.Size
        local size = Vector3.new(s.X, s.Y, dist)
        if #workspace:GetPartBoundsInBox(cf, size, params) > 0 then
            return false
        end
    end
    return true
end

function issafefromharm(pos, disks, excludeDisk)
    for _, disk in ipairs(disks) do
        if disk ~= excludeDisk then
            local diskRadius = disk.Size.X / 2
            local dist = (Vector3.new(pos.X, disk.Position.Y, pos.Z) - disk.Position).Magnitude
            if dist < diskRadius then
                return false
            end
        end
    end
    return true
end

function avoidharm(field, fieldCenter)
    local playerPos = allvars.api.getRoot().Position
    local warningDisks = getharmfulobjects()

    local ray = Ray.new(playerPos + Vector3.new(0, 100, 0), Vector3.new(1, -735, 1))
    local touchedWarningDisk = workspace:FindPartOnRayWithWhitelist(ray, warningDisks)

    if touchedWarningDisk then
        local diskRadius = touchedWarningDisk.Size.X / 2
        local diskCenter = touchedWarningDisk.Position
        local dirToPlayer = (playerPos - diskCenter).Unit

        if fieldCenter then
            local dirToFieldCenter = (Vector3.new(fieldCenter.X, diskCenter.Y, fieldCenter.Z) - diskCenter).Unit
            dirToPlayer = (dirToPlayer + dirToFieldCenter).Unit
        end

        local playerToCenter = (playerPos - diskCenter).Magnitude
        local playerToDisk = playerToCenter - diskRadius
        local safePos = diskCenter + dirToPlayer * (diskRadius + 4 + playerToDisk + 5)

        if (safePos - playerPos).Magnitude < 0.5 then
            safePos = playerPos + Vector3.new(1, 0, 0)
        end

        local function posValid(pos)
            return (not field or isfield(pos)) and issafefromharm(pos, warningDisks, touchedWarningDisk)
        end

        if not posValid(safePos) then
            local perp = Vector3.new(-dirToPlayer.Z, 0, dirToPlayer.X)
            local alt1 = diskCenter + perp * (diskRadius + 9)
            local alt2 = diskCenter - perp * (diskRadius + 9)
            if posValid(alt1) then
                safePos = alt1
            elseif posValid(alt2) then
                safePos = alt2
            else
                return
            end
        end

        allvars.api.getHumanoid():MoveTo(safePos + Vector3.new(1, 0, 1))
    end
end

function killviciousbee()
    if allvars.killvic or allvars.forcetasks.killvic then
        local thorn = workspace.Particles.WTs:FindFirstChild("WaitingThorn")
        local vicbee
        local viclevel = -1
        local gifted = false
        for i, v in pairs(workspace.Monsters:GetChildren()) do
            if v.Name:find("Vicious Bee") then
                vicbee = v
                viclevel = tonumber(v.Name:match("Lvl (%d+)"))
                gifted = v.Name:lower():find("gifted") ~= nil
                break
            end
        end
        if thorn then
            if viclevel <= (allvars.vicaveragebeelevel and getbeelevelforcombat() or allvars.maxviclevel) and viclevel >= allvars.minviclevel then
                local field = isfield(thorn.Position)
                if field and #getbeesdata().all >= allvars.fieldbeereqs[field.Name] then
                    allvars.fieldtofarm = field
                    if isfield(allvars.api.getRoot().Position) ~= field then
                        tweento(field.Position + Vector3.new(0, 5, 0))
                    end 
                    if not thorn.Parent then return killviciousbee() end
                    --avoidmobs(field)
                    if not thorn.Parent then return killviciousbee() end
                    safewalk(thorn.Position)
                    task.wait(0.5)
                    killviciousbee()
                end
            end
        elseif vicbee and not allvars.ignorevicbee[vicbee] then
            local field = isfield(vicbee.HumanoidRootPart.Position)
            if field and viclevel <= (allvars.vicaveragebeelevel and getbeelevelforcombat() or allvars.maxviclevel) and viclevel >= allvars.minviclevel then
                task.spawn(function()
                    if allvars.discordwebhookenabled and allvars.discordwebhookurl:match("(https://discord%.com)") then
                        supersaferequest(allvars.discordwebhookurl, "POST", nil, HttpService:JSONEncode(buildviciousbody(field.Name, viclevel, gifted)))
                    end
                end)
                allvars.fieldtofarm = field
                if isfield(allvars.api.getRoot().Position) ~= field then
                    tweento(field.Position)
                end
                tasks.add("killing vic", function()
                    local starthp = vicbee:GetAttribute("starthealth") or vicbee.Humanoid.Health
                    vicbee:SetAttribute("starthealth", starthp)
                    local starttick = tick()
                    while vicbee.Parent and (allvars.killvic or allvars.forcetasks.killvic) and task.wait() do
                        if isfield(allvars.api.getRoot().Position) ~= field then
                            tweento(field.Position)
                        end
                        if vicbee.Humanoid.Health > (starthp - 50) and tick() - starttick >= 30 then
                            allvars.ignorevicbee[vicbee] = true
                            warn("little damage dealt in 30 sec, stuck on vic bee. ignoring vicious bee for now")
                            return
                        end
                        avoidharm(field, field.Position)
                        collecttokensonfield(field)
                    end
                end)
            end
        end
        allvars.forcetasks.killvic = false
    end
end

function mainautofarmloop()
    local timewithoutmovement = tick()
    allvars.mainautofarmtask = task.spawn(function()
        while allvars.autofarm and allvars.isrunning do
            local _test1 = tick()
            local root = allvars.api.getRoot()
            local humanoid = allvars.api.getHumanoid()
            if not root or not humanoid then task.wait() continue end
            local oldrootposition = root.Position
            trytoconvert()
            allvars.fieldtofarm = workspace.NewFlowerZones[allvars.farmingfield]

            -- auto prog field
            if allvars.autoprogress and allvars.autoprogdata then
                local capabilities = allvars.autoprogcapabs
                local _earlybreak = false
                for i, v in pairs(allvars.autoprogdata) do
                    if v.event == "badges" then
                        allvars.autoprogbadgeorder = v.value
                    elseif v.event == "field" and table.find(capabilities, "Automaticaly select fields") then
                        local selectedField = v.value[1]
                        for _, field in ipairs(v.value) do
                            if #getbeesdata().all >= allvars.fieldbeereqs[field] then
                                selectedField = field
                            else
                                break
                            end
                        end
                        allvars.fieldtofarm = workspace.NewFlowerZones[selectedField]
                    elseif v.event == "codes" and table.find(capabilities, "Redeem codes")  and not allvars.redeemedcodes then
                        if #getbeesdata().all >= (v.bees or 0) then
                            local codes = ReplicatedStorage.Events.RetrievePlayerStats:InvokeServer().Codes
                            for _, code in pairs(v.value) do
                                if not table.find(codes or {}, code:lower()) then
                                    smartredeemcode(code:lower())
                                end
                            end
                            _earlybreak = true
                            allvars.redeemedcodes = true
                        end
                    elseif v.event == "collectibles" and table.find(capabilities, "Collect secret rares")  then
                        local function bees(n) return function() return #getbeesdata().all >= n end end
                        local positions = {
                            { pos = Vector3.new(34.86427688598633, 57.96503829956055, 190.51075744628906), req = bees(0), label = "royal jelly on dandelion" },
                            { pos = Vector3.new(139.45660400390625, 64.43104553222656, 258.4818115234375), req = bees(0), label = "royal jelly infront of star hall" },
                            { pos = Vector3.new(314.3119201660156, 61.6384162902832, 213.96385192871094), req = bees(0), label = "royal jelly where brown bear is" },
                            { pos = Vector3.new(-189.31715393066406, 64.26322937011719, 367.29473876953125), req = bees(0), label = "royal jelly behind onett" },
                            { pos = Vector3.new(-233.2725830078125, 43.782169342041016, 418.7121887207031), req = bees(0), label = "royal jelly on ticket tent" },
                            { pos = Vector3.new(87.33222961425781, 54.94021987915039, 396.049072265625), req = bees(0), label = "ticket near ant" },
                            { pos = Vector3.new(-374.18780517578125, 19.293209075927734, 494.7056884765625), req = bees(0), label = "ticket in maze" },
                            { pos = Vector3.new(-168.46104431152344, 33.840431213378906, 76.9292984008789), req = bees(0), label = "ticket on mother bear house" },
                            { pos = Vector3.new(14.022793769836426, 4.5928144454956055, 68.14900207519531), req = bees(0), label = "hidden ticket under stairs" },
                            { pos = Vector3.new(98.66006469726562, 35.20281219482422, 355.489013671875), req = bees(0), label = "hidden ticket in demon thing" },
                            { pos = Vector3.new(-64.23152160644531, 37.71692657470703, 113.38774108886719), req = bees(0), label = "royal jelly on mushroom" },
                            { pos = Vector3.new(146.3509063720703, 37.49603271484375, 266.0859375), req = bees(0), label = "royal jelly hidden in noob shop" },
                            { pos = Vector3.new(-365.9684143066406, 18.3247127532959, 464.2096252441406), req = bees(0), label = "jellybean in maze" },
                            { pos = Vector3.new(263.9461975097656, 57.138309478759766, 108.3685073852539), req = hasaccessshopfuncs.bluehq, label = "royal jelly in blue hq" },
                            { pos = Vector3.new(110.86051177978516, 63.71779251098633, -59.57771682739258), req = bees(5), label = "royal jelly on bamboo stick" },
                            { pos = Vector3.new(218.61819458007812, 35.426795959472656, -29.125577926635742), req = bees(5), label = "hidden royal jelly in stairs" },
                            { pos = Vector3.new(142.53514099121094, 69.52711486816406, -217.0493927001953), req = bees(10), label = "royal jelly in pro bear maze" },
                            { pos = Vector3.new(175.8548583984375, 69.52711486816406, -223.7711944580078), req = bees(10), label = "sunflower seeds in pro bear maze" },
                            { pos = Vector3.new(191.82347106933594, 68.65254974365234, -163.64181518554688), req = bees(10), label = "pineapple behind decoration" },
                            { pos = Vector3.new(369.31427001953125, 84.816162109375, -237.07652282714844), req = bees(10), label = "glue behind big pineapple and stump field" },
                            { pos = Vector3.new(338.76171875, 130.92079162597656, -233.84364318847656), req = bees(10), label = "ticket on pineapple" },
                            { pos = Vector3.new(518.9127807617188, 177.1676788330078, -291.61981201171875), req = bees(10), label = "royal jelly on dapper shop" },
                            { pos = Vector3.new(499.40087890625, 177.16831970214844, -420.6256103515625), req = bees(10), label = "honeysucks on dapper shop" },
                            { pos = Vector3.new(600.6361083984375, 177.1673126220703, -436.89813232421875), req = bees(10), label = "smooth dice on dapper shop" },
                            { pos = Vector3.new(535.6323852539062, 183.0349578857422, -351.06561279296875), req = bees(10), label = "bloom shaker on dapper shop" },
                            { pos = Vector3.new(524.5060424804688, 151.90162658691406, -411.8759765625), req = hasaccessshopfuncs.dapper, label = "star jelly in dapper shop" },
                            { pos = Vector3.new(-293.51275634765625, 50.17993927001953, 266.9001159667969), req = bees(15), label = "royal jelly on rock" },
                            { pos = Vector3.new(-122.99150085449219, 67.37088775634766, -218.43646240234375), req = bees(15), label = "royal jelly behind pumpkin" },
                            { pos = Vector3.new(-43.689491271972656, 148.99264526367188, -249.78903198242188), req = bees(15), label = "royal jelly in tiny space near cloud" },
                            { pos = Vector3.new(-383.7144470214844, 55.4559211730957, 82.08206176757812), req = bees(15), label = "another royal jelly on rock" },
                            { pos = Vector3.new(-357.5382080078125, 129.8998565673828, -227.21456909179688), req = bees(15), label = "royal jelly on pine tree" },
                            { pos = Vector3.new(-232.84506225585938, 184.9242706298828, -249.955322265625), req = bees(15), label = "ticket on cloud" },
                            { pos = Vector3.new(-336.5309143066406, 132.36778259277344, -384.9282531738281), req = bees(15), label = "glitter in diamond mask room" },
                            { pos = Vector3.new(-468.9040832519531, 100.25933837890625, 173.32984924316406), req = bees(15), label = "loaded dice on red hq" },
                            { pos = Vector3.new(83.80662536621094, 69.47663879394531, -142.1493377685547), req = bees(15), label = "gold egg in cave" },
                            { pos = Vector3.new(-436.2663879394531, 94.3154296875, 49.612403869628906), req = hasaccessshopfuncs.badgeguild, label = "star jelly in badge guild" },
                            { pos = Vector3.new(-481.0661315917969, 71.7060546875, -0.2596874237060547), req = hasaccessshopfuncs.master, label = "star jelly in master room" },
                        }

                        local eligible = {}
                        for _, entry in ipairs(positions) do
                            local hasToken = false
                            for _, token in pairs(workspace.Collectibles:GetChildren()) do
                                if allvars.api.magnitude(token.Position, entry.pos, 1) and token.Transparency == 0 then
                                    hasToken = true
                                    break
                                end
                            end
                            if hasToken and entry.req() and allvars.api.getRoot() then
                                table.insert(eligible, entry)
                            end
                        end

                        local current = allvars.api.getRoot().Position
                        while #eligible > 0 do
                            local bestIdx, bestDist = 1, (eligible[1].pos - current).Magnitude
                            for i = 2, #eligible do
                                local d = (eligible[i].pos - current).Magnitude
                                if d < bestDist then bestIdx, bestDist = i, d end
                            end
                            local entry = table.remove(eligible, bestIdx)
                            print("collecting: " .. entry.label)
                            if checkcave(current, entry.pos) then
                                tweento(entry.pos, 7, true, nil, true)
                            else
                                tweento(entry.pos, 7, nil, nil, true)
                            end
                            current = entry.pos 
                            task.wait()
                        end
                    elseif v.event == "bees" and table.find(capabilities, "Add bees and use royal jelly")  then
                        if #getbeesdata().all < v.value and getbeesdata().emptycells > 0 then
                            if #getbeesdata().all >= 25 then
                                if getclientstatcache("Honey") >= getnexthiveslotprice() then
                                    buygear("Hive Slot", "top")
                                end
                                if getbeesdata().emptycells == 0 then
                                    continue
                                end
                            end
                            if addbasicbee() then _earlybreak = true end
                        end
                    elseif v.event == "gear" and table.find(capabilities, "Purchase gear") then
                        local owned = {}
                        for _, v in pairs(getclientstatcache("Accessories") or {}) do
                            table.insert(owned, v)
                        end
                        for _, v in pairs(getclientstatcache("Parachutes") or {}) do
                            table.insert(owned, v)
                        end
                        for _, v in pairs(getclientstatcache("Collectors") or {}) do
                            table.insert(owned, v)
                        end
                        for _, v in pairs(getclientstatcache("Backpacks") or {}) do
                            table.insert(owned, v)
                        end
                        for _, v in pairs(getclientstatcache("Sprinklers") or {}) do
                            table.insert(owned, v)
                        end
                        for v, _ in pairs(getclientstatcache("Totals", "Purchases", "Eggs") or {}) do
                            if v:match(".+(Planter)") then
                                table.insert(owned, v)
                            end
                        end
                        
                        -- find highest owned index per slot
                        local highestOwnedPerSlot = {}
                        for i, gearName in ipairs(v.value) do
                            if table.find(owned, gearName) then
                                local meta = gearmeta[gearName]
                                if meta then
                                    local slotType = meta[2]
                                    if not highestOwnedPerSlot[slotType] or i > highestOwnedPerSlot[slotType] then
                                        highestOwnedPerSlot[slotType] = i
                                    end
                                end
                            end
                        end

                        for i, gearName in ipairs(v.value) do
                            local meta = gearmeta[gearName]
                            if not meta then continue end
                            local slotType = meta[2]
                            -- skip if below or equal to highest owned in this slot
                            if highestOwnedPerSlot[slotType] and i <= highestOwnedPerSlot[slotType] then continue end
                            local buyName = slotType == "planter" and gearName:sub(1, -8) .. " Planter" or gearName
                            if not hasaccessshopfuncs[meta[1]]() then
                                allvars.nextautoprogitem = "[Locked]"
                                continue
                            end

                            if reallycanafford(allprices[gearName], true) then
                                allvars.nextautoprogitem = buyName
                                print("Buy:", buyName)
                                buygear(buyName, meta[1])
                                _earlybreak = true
                            else
                                allvars.nextautoprogitem = buyName
                                reallycanafford(allprices[gearName])
                            end
                            break
                        end
                    end
                end
                sortbestbadges(nil,nil,nil,true) -- redeem badges
                local badgestofarm = allvars.forcetasks.autoprogbadges
                if #badgestofarm > 0 then
                    local badge = badgestofarm[1]
                    allvars.fieldtofarm = workspace.NewFlowerZones[badge.zone]
                    if (allvars.lastfarmbadge or {}).zone ~= badge.zone then
                        allvars.lastfarmbadge = {zone = badge.zone}
                        task.spawn(function()
                            if allvars.discordwebhookenabled and allvars.discordwebhookurl:match("(https://discord%.com)") then
                                supersaferequest(allvars.discordwebhookurl, "POST", nil, HttpService:JSONEncode(buildbadgebody(badge.name, badge.req, badge.done)))
                            end
                        end)
                    end
                end
                if _earlybreak then continue end  -- go buy next item, or just do the next auto-prog event
            end        

            if allvars.farmfireflies or allvars.forcetasks.fireflies then
                local fireflies = farmfireflies()
                for i, ff in pairs(fireflies) do
                    safewalk(ff, true)
                end
                allvars.forcetasks.fireflies = false
            end

            if allvars.farmfireflies or allvars.forcetasks.meteors then
                farmmeteorites()
                allvars.forcetasks.meteors = false
            end

            killviciousbee()

            local fieldtofarm = allvars.fieldtofarm
            local fieldmag = allvars.api.magnitude(root.Position * Vector3.new(0, 1, 0), fieldtofarm.Position * Vector3.new(0, 1, 0), 25)
            if not isfield(root.Position) or isfield(root.Position).Name ~= fieldtofarm.Name or not fieldmag then
                tweento(fieldtofarm.Position + Vector3.new(0, 5, 0))
            end
            if fieldtofarm ~= allvars.sprinklefield then
                allvars.sprinklefield = fieldtofarm
                allvars.redosprinklers = true
            end
            if allvars.autosprinkler and allvars.redosprinklers then
                wait(0.5)
                placesprinklers(fieldtofarm)
                allvars.redosprinklers = false
            end
            avoidmobs(fieldtofarm)
            collecttokensonfield(fieldtofarm)
            avoidmobs(fieldtofarm)
            if not allvars.api.magnitude(root.Position, oldrootposition, 2) then
                timewithoutmovement = tick()
            end
            if tick() - timewithoutmovement > 2 then
                timewithoutmovement = tick()
                humanoid:MoveTo(randompoint(fieldtofarm))
            end
            local _test2 = tick() - _test1
            --print("main iteration:",_test2)
            task.wait()
        end
    end)
end

local deathconnection
local function deathhandler(char)
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 4)
    if not humanoid then return end
    deathconnection = humanoid.Died:Once(function()
        task.spawn(function()
            if allvars.discordwebhookenabled and allvars.discordwebhookurl:match("(https://discord%.com)") then
                supersaferequest(allvars.discordwebhookurl, "POST", nil, HttpService:JSONEncode(builddeathbody()))
            end
        end)
        warn("you died, killing all tasks")
        tasks.deleteall()
        disableall()
    end)
end

deathhandler(LocalPlayer.Character)

local respawnhandlerconnection = LocalPlayer.CharacterAdded:Connect(function(char)
    repeat task.wait() until char.Parent == workspace
    disableall()
    claimhive()
    allvars.redosprinklers = true
    deathhandler(char)
    if allvars.mainautofarmtask then task.cancel(allvars.mainautofarmtask) end
    if allvars.autofarm then
        task.spawn(function()
            local rebootautofarm = function() warn("unknown") end
            rebootautofarm = function()
                tasks.deleteall()
                mainautofarmloop()
                repeat task.wait() until allvars.mainautofarmtask and coroutine.status(allvars.mainautofarmtask) == "dead"
                if not allvars.autofarm or not allvars.isrunning then return end
                rebootautofarm()
            end
            rebootautofarm()
        end)
    end
end)

local function maketoggle(tab,name,flag,callback,default,nosave)
    return tab:CreateToggle({
        Name = name,
        CurrentValue = default,
        Flag = flag,
        Callback = callback,
        NoSave = nosave
    })
end

local function makebutton(tab,name,callback)
    return tab:CreateButton({
        Name = name,
        Callback = callback,
    })
end

local function makedropdown(tab,name,flag,options,multi,callback,default)
    return tab:CreateDropdown({
        Name = name,
        Options = options,
        CurrentOption = default or {},
        MultipleOptions = multi,
        Flag = flag,
        Callback = callback
    })
end

local function makeslider(tab,name,flag,range,increment,suffix,callback,default)
    return tab:CreateSlider({
        Name = name,
        Range = range,
        Increment = increment,
        Suffix = suffix,
        CurrentValue = default or range[1],
        Flag = flag,
        Callback = callback
    })
end

local function maketextbox(tab,name,flag,placeholder,removeafterfocus,callback,default)
    return tab:CreateInput({
        Name = name,
        CurrentValue = default or "",
        PlaceholderText = placeholder,
        RemoveTextAfterFocusLost = removeafterfocus,
        Flag = flag,
        Callback = callback
    })
end

-- create tabs
local homeTab = window:CreateTab("Information", "trending-up")
local autofarmTab = window:CreateTab("Auto-Farm", "layers-2")
local combatTab = window:CreateTab("Combat", "swords")
local webhookTab = window:CreateTab("Webhook", "globe")
local waxTab = window:CreateTab("Prediction", "flask-conical")
local settingsTab = window:CreateTab("Config", "settings")

-- home info stuff
homeTab:CreateSection("Statistics")
local elapsedtimelabel = homeTab:CreateLabel("Elapsed Time: N/A")
local honeyperhourlabel = homeTab:CreateLabel("Honey Per Hour: N/A")
local sessionhoneylabel = homeTab:CreateLabel("Session Honey: N/A")
homeTab:CreateSection("Auto Progression")
local autoprogtasknowlabel = homeTab:CreateLabel("Next Item: N/A")
local nexthiveslotlabel = homeTab:CreateLabel("Next Hive Slot: N/A")
local nextbasicegg = homeTab:CreateLabel("Next Egg: N/A")

task.spawn(function()
    while allvars.isloaded do
        local capabilities = allvars.autoprogcapabs
        if not table.find(capabilities, "Purchase gear") then
            allvars.nextautoprogitem = "[Disabled]"
        end
        local hiveslotnum = (getclientstatcache("Totals", "Purchases", "HiveSlots") or 0) + 1
        local boughtbasiceggs = getclientstatcache("Totals", "Purchases", "Eggs", "Basic") or 1
        local nextbasiceggprice = getEggPrice(boughtbasiceggs)
        local currenthoney = getclientstatcache("Honey")
        local timepassed = math.round(os.clock() - allvars.timeatload)
        local honeyearned = currenthoney - allvars.starthoney
        local honeyperhournum = math.floor(honeyearned / timepassed) * 3600
        local elapsedtimestring = truncatetime(os.clock() - allvars.timeatload)
        local honeyperhourstring = truncate(honeyperhournum)
        local sessionhoneynum = math.floor(currenthoney - allvars.starthoney)
        local sessionhoneystring = truncate(sessionhoneynum)
        local nextautoprogitemstring = "Next Item: " .. (allvars.nextautoprogitem or "N/A")
        local nexthiveslotstring = "Next Hive Slot: " .. (
            table.find(capabilities, "Add bees and use royal jelly") and 
                (truncate(currenthoney) .. "/" .. truncate(getnexthiveslotprice()) .. " (#" .. hiveslotnum .. ")")
            or "[Disabled]")
        local nextbasiceggstring = "Next Egg: " .. (
            table.find(capabilities, "Add bees and use royal jelly") and
                (truncate(currenthoney) .. "/" .. truncate(nextbasiceggprice))
            or "[Disabled]")

        autoprogtasknowlabel:Set(nextautoprogitemstring)
        nexthiveslotlabel:Set(nexthiveslotstring)
        nextbasicegg:Set(nextbasiceggstring)
        elapsedtimelabel:Set(string.format("Elapsed Time: %s", elapsedtimestring))
        honeyperhourlabel:Set(string.format("Honey Per Hour: %s", honeyperhourstring))
        sessionhoneylabel:Set(string.format("Session Honey: %s", sessionhoneystring))

        allvars.elapsedtimestring = elapsedtimestring
        allvars.honeyperhourstring = honeyperhourstring
        allvars.sessionhoneystring = sessionhoneystring
        allvars.nextautoprogitemstring = nextautoprogitemstring
        allvars.nexthiveslotstring = nexthiveslotstring
        allvars.nextbasiceggstring = nextbasiceggstring

        if allvars.discordwebhookenabled and tick() - allvars.lastdiscordupdate >= (allvars.webhookinterval * 60) and allvars.discordwebhookurl:match("(https://discord%.com)") and not allvars.disconnected then
            allvars.lastdiscordupdate = tick()
            task.spawn(function()
                supersaferequest(allvars.discordwebhookurl, "POST", nil, HttpService:JSONEncode(buildwebhookbody()))
            end)
        end

        task.wait(0.1)
    end
end)

-- autofarm toggles
autofarmTab:CreateSection("Autofarm Main")
local autofarmtoggle = maketoggle(autofarmTab, "Autofarm", "autofarm", function(s)
    allvars.autofarm=s
    if not s then
        pcall(function()
            task.cancel(allvars.mainautofarmtask)
        end)
        tasks.deleteall()
        for i, v in pairs(workspace.FieldDecos:GetChildren()) do
            if v.Name == "Sundower" then
                v.Circle.CanCollide = true
            end
        end
        for i, v in pairs(workspace.FieldDecos:GetChildren()) do
            if v.Name == "Bamboo" then
                v.CanCollide = true
            end
        end
        for i, v in pairs(workspace.Decorations.Misc:GetChildren()) do
            if v.Name == "Mushroom" then
                v:GetChildren()[1].CanCollide = true
                v:GetChildren()[2].CanCollide = true
            end
        end
        for i, v in pairs(workspace.Decorations.JumpGames.Mushroom:GetChildren()) do
            v.CanCollide = true
        end
        for i, v in pairs(workspace.Decorations.JumpGames.RockClimbBamboo:GetChildren()) do
            v.CanCollide = true
        end
        workspace.Gates["15 Bee Gate"].Frame.CanCollide = false
        disableall()
    else
        print("Doing: Autofarm")
        for i, v in pairs(workspace.FieldDecos:GetChildren()) do
            if v.Name == "Sundower" then
                v.Circle.CanCollide = false
            end
        end
        for i, v in pairs(workspace.FieldDecos:GetChildren()) do
            if v.Name == "Bamboo" then
                v.CanCollide = false
            end
        end
        for i, v in pairs(workspace.Decorations.Misc:GetChildren()) do
            if v.Name == "Mushroom" then
                v:GetChildren()[1].CanCollide = false
                v:GetChildren()[2].CanCollide = false
            end
        end
        for i, v in pairs(workspace.Decorations.JumpGames.Mushroom:GetChildren()) do
            v.CanCollide = false
        end
        for i, v in pairs(workspace.Decorations.JumpGames.RockClimbBamboo:GetChildren()) do
            v.CanCollide = false
        end
        workspace.Gates["15 Bee Gate"].Frame.CanCollide = true
        disableall()
        task.spawn(function()
            local rebootautofarm = function() warn("unknown") end
            rebootautofarm = function()
                tasks.deleteall()
                mainautofarmloop()
                repeat task.wait() until allvars.mainautofarmtask and coroutine.status(allvars.mainautofarmtask) == "dead"
                if not allvars.autofarm or not allvars.isrunning then return end
                rebootautofarm()
            end
            rebootautofarm()
        end)
    end
end,nil,true)
maketoggle(autofarmTab, "Auto Dig", "autodig", function(s)
    allvars.autodig=s
end)
maketoggle(autofarmTab, "Auto Sprinkler", "autosprinkler", function(s)
    allvars.autosprinkler=s
    if not s then tasks.delete("placing sprinklers") end
end)
makedropdown(autofarmTab, "Field To Farm", "farmingfield", sortedfields, false, function(s)
    disableall()
    if #getbeesdata().all < allvars.fieldbeereqs[s[1]] then
        allvars.farmingfield = "Sunflower Field"
        return mainuimodule:Notify("You do not have enough bees for this zone. Selected sunflower field")
    end
    allvars.farmingfield = s[1]
end, {"Sunflower Field"})

-- auto prog
autofarmTab:CreateSection("Auto Progression")
maketoggle(autofarmTab, "Auto Progression", "autoprogress", function(s)
    allvars.autoprogress=s
    if not s then allvars.nextautoprogitem = nil end
end)
local rawcraftrecipenames = {
    "Red Extract", "Blue Extract", "Glue", "Enzymes", "Oil", "Gumdrops",
    "Moon Charm", "Glitter", "Star Jelly", "Tropical Drink", "Purple Potion",
    "Super Smoothie", "Soft Wax", "Hard Wax", "Caustic Wax", "Swirled Wax",
    "Field Dice", "Smooth Dice", "Loaded Dice", "Turpentine"
}
allvars.allowedcrafts = rawcraftrecipenames
makedropdown(autofarmTab, "Allowed Materials To Craft", "allowedcraftingmaterials", rawcraftrecipenames, true, function(s)
    allvars.allowedcrafts = {}
    for _, v in pairs(s) do
        table.insert(allvars.allowedcrafts, v)
    end
end, allvars.allowedcrafts)
makedropdown(autofarmTab, "Auto Progression Capabilities", "autoprogcapabs", allvars.autoprogcapabs, true, function(s,l)
    if #s < #allvars.autoprogcapabs and not l then
        mainuimodule:Notify("Disabling auto progression features may limit or softlock the stage of your account when auto-farming. Choose what to disable with caution.")
    end
    allvars.autoprogcapabs = {}
    for _, v in pairs(s) do
        table.insert(allvars.autoprogcapabs, v)
    end
end, allvars.autoprogcapabs)

-- convert stuff
autofarmTab:CreateSection("Converting")
maketoggle(autofarmTab, "Convert Honey", "autoconvert", function(s)
    allvars.autoconvert=s
    if not s then tasks.delete("convert handler") end
end, true)
makeslider(autofarmTab, "Convert Honey At X Percent", "convertatx", {1, 100}, 1, "", function(s)
    allvars.convertatx=s
end, 100)
maketoggle(autofarmTab, "Convert Balloon", "autoconvertballoon", function(s)
    allvars.converthiveballoon=s
end)
makeslider(autofarmTab, "Convert Balloon At X Minutes", "convertballoonatx", {1, 59}, 1, "", function(s)
    allvars.convertballoonat=s
end, 15)

-- farm options stuff
autofarmTab:CreateSection("Farming Options")
maketoggle(autofarmTab, "Farm Pop Star", "farmpopstar", function(s)
    allvars.farmbloat=s
end)
maketoggle(autofarmTab, "Farm Pop Star When <5x Bubble Bloat", "farmpopstarwhenlow", function(s)
    allvars.farmbloatwhenlow=s
end)
maketoggle(autofarmTab, "Farm Fireflies", "farmfireflies", function(s)
    allvars.farmfireflies=s
end)
maketoggle(autofarmTab, "Farm Meteorites", "farmmeteorites", function(s)
    allvars.farmmeteorites=s
end)

-- combat stuff
combatTab:CreateSection("Combat")
maketoggle(combatTab, "Avoid Mobs", "avoidmobs", function(s)
    allvars.avoidmobs=s
    if not s then
        tasks.delete("avoiding mob")
    end
end, true)
combatTab:CreateSection("Vicious Bee")
maketoggle(combatTab, "Kill Vicious Bee", "killvic", function(s)
    allvars.killvic=s
end)
makeslider(combatTab, "Min Level", "minviclevel", {1, 12}, 1, "", function(s)
    allvars.minviclevel=s
end, 1)
makeslider(combatTab, "Max Level", "maxviclevel", {1, 12}, 1, "", function(s)
    allvars.maxviclevel=s
end, 12)
maketoggle(combatTab, "Use Average Bee Level As Max", "vicaveragebeelevel", function(s)
    allvars.vicaveragebeelevel=s
end)
maketoggle(combatTab, "Vic In-Game Notifier", "vicnotifier", function(s)
    allvars.vicnotifier=s
end)

-- webhook stuff
webhookTab:CreateSection("Webhook")
maketoggle(webhookTab, "Enable Webhook", "discordwebhookenabled", function(s)
    allvars.discordwebhookenabled=s
    if s then allvars.lastdiscordupdate = 0 end
end)
maketextbox(webhookTab, "Webhook URL", "discordwebhookurl", "https://discord.com/api/webhooks/", false, function(s,l)
    if s == "" then return end
    if not s:match("(https://discord%.com)") and not l then
        mainuimodule:Notify("Invalid URL.")
    end
    local suc, req = pcall(game.HttpGet, game, s)
    if (not suc or not req or not HttpService:JSONDecode(req) or not HttpService:JSONDecode(req).token) and not l then
        return mainuimodule:Notify("Webhook does not exist.")
    end
    allvars.discordwebhookurl = s
    allvars.lastdiscordupdate = 0
    if not l then mainuimodule:Notify("Webhook set.") end
end)
makeslider(webhookTab, "Send Update Every X Minutes", "convertballoonatx", {1, 60}, 1, "", function(s)
    allvars.webhookinterval=s
end, 5)

-- wax stuff
waxTab:CreateSection("Wax Predictor")
makebutton(waxTab, "Load Beequip Predictor", function()
    if _G.waxloaded then return end
    _G.waxloaded = true
    loadstring(supersaferequest("https://raw.githubusercontent.com/lunar-repo/beeswarm/refs/heads/main/wax.lua").Body)()
end)

-- settings stuff
settingsTab:CreateSection("Movespeed")
local dynamicmovespeedtoggle
local normalmovespeedtoggle
normalmovespeedtoggle = maketoggle(settingsTab, "Enable Movespeed", "speedhackenabled", function(s)
    allvars.speedhackenabled=s
    if s and allvars.dynamicspeedhackenabled then
        dynamicmovespeedtoggle:Set(false)
    end
end)
makeslider(settingsTab, "Movespeed", "movespeed", {20, 90}, 1, "", function(s)
    allvars.movespeed=s
end, 70)
dynamicmovespeedtoggle = maketoggle(settingsTab, "Enable Dynamic Movespeed", "dynamicspeedhackenabled", function(s)
    allvars.dynamicspeedhackenabled=s
    if s and allvars.speedhackenabled then
        normalmovespeedtoggle:Set(false)
    end
end)
makeslider(settingsTab, "Dynamic Movespeed", "dynamicmovespeedmultiplier", {1.01, 5}, 0.01, "x", function(s)
    allvars.dynamicmovespeedmultiplier=s
end, 2)
makeslider(settingsTab, "Maximum Dynamic Movespeed", "dynamicmovespeedmaximum", {20, 150}, 3, "", function(s)
    allvars.dynamicmovespeedmaximum=s
end, 100)
settingsTab:CreateSection("Tweening")
makeslider(settingsTab, "Tween Speed", "tweenspeed", {1, 24}, 1, "", function(s,l)
    if s > 12 and not l and allvars.tweenspeed > s then
        mainuimodule:Notify("Tween Speed above 12 is not recommended unless using on an alt account.")
    end
    allvars.tweenspeed=s
end, 12)
settingsTab:CreateLabel("Don't set tween speed above 12 unless using only on alts.")
settingsTab:CreateSection("Safety")
maketoggle(settingsTab, "Use Remotes", "remotes", function(s)
    allvars.remotes=s
end)

function getnormalwalkspeed()
    return tonumber(events.ClientCall("RetrievePlayerStatsSummary").Movespeed.Desc)
end

task.spawn(function()
    while allvars.isloaded and task.wait() do
        local hum = allvars.api.getHumanoid()
        if not hum then continue end
        if not allvars.speedhackenabled and not allvars.dynamicspeedhackenabled then
            hum.WalkSpeed = getnormalwalkspeed()
            continue
        end
        if allvars.speedhackenabled and not allvars.dynamicspeedhackenabled then
            hum.WalkSpeed = allvars.movespeed
        elseif allvars.dynamicspeedhackenabled then
            hum.WalkSpeed = math.min(allvars.dynamicmovespeedmaximum, getnormalwalkspeed() * allvars.dynamicmovespeedmultiplier)
            task.wait(0.5)
        end
    end
end)

local autodigconnection = RunService.RenderStepped:Connect(function()
    if not allvars.isrunning then return end
    if allvars.autodig then
        localcollect:Run()
    end
end)

if #getbeesdata().all == 0 then
    local loadcomp = tick()
    addbasicbee()
    realloadstart = realloadstart + (tick() - loadcomp)
end

local antiafkconnection = LocalPlayer.Idled:Connect(function()
    virtualuser:CaptureController()
    virtualuser:ClickButton2(Vector2.new())
end)

function serverhop()
    local servers = {}
    local req = supersaferequest("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true").Body
    local body = HttpService:JSONDecode(req)

    if body and body.data then
        for i, v in next, body.data do
            if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= game.JobId then
                table.insert(servers, 1, v.id)
            end
        end
    end

    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], game:GetService("Players").LocalPlayer)
    else
        return warn("Couldn't find a server.")
    end
end

local disconnecthandlerconnection = GuiService.ErrorMessageChanged:Connect(function(message)
    local text = CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay"):WaitForChild("ErrorPrompt"):WaitForChild("MessageArea"):WaitForChild("ErrorFrame"):WaitForChild("ErrorMessage").Text
    warn(text)
    if text:lower():find("error code") then
        task.spawn(function()
            allvars.disconnected = true
            allvars.isrunning = false
            queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/lunar-repo/beeswarm/refs/heads/main/test.lua'))()")
            local sent = false
            if allvars.discordwebhookenabled and allvars.discordwebhookurl:match("(https://discord%.com)") then
                repeat
                    local req = supersaferequest(allvars.discordwebhookurl .. "?wait=true", "POST", nil, HttpService:JSONEncode(builddisconnectbody(message)))
                    local json = req and req.StatusCode == 200 and req.Body and HttpService:JSONDecode(req.Body)
                    sent = json and type(json.timestamp) == "string"
                until sent
            end
            while true do
                serverhop()
                task.wait(1)
            end
        end)
    end
end)

local vicaddedhandler = workspace.Monsters.ChildAdded:Connect(function(v)
    if v.Name:find("Vicious Bee") then
        if allvars.vicnotifier then
            alertboxes.Push(nil, "\t" .. v.Name .. " detected in " .. isfield(v:WaitForChild("HumanoidRootPart").Position).Name .. "\t", nil, "Vicious")
        end
    end
end)

task.spawn(function()
    while allvars.isloaded do
        local Old = HttpService:JSONEncode(window.Flags)
        task.wait(1)
        if not allvars.isloaded then return end
        local New = HttpService:JSONEncode(window.Flags)
        if New ~= Old then
            warn("AutoSaving ...")
            writefile(SaveFileName, New)
        end
    end
end)


local oldpopup
oldpopup = hookfunction(beepopup.Show, newcclosure(function(...)
    if allvars.autofarm and allvars.isrunning then
        return
    end
    return oldpopup(...)
end))

local oldinspect
oldinspect = hookfunction(beeinspector.Open, newcclosure(function(...)
    if allvars.autofarm and allvars.isrunning then
        return
    end
    return oldinspect(...)
end))

getgenv().LUNAR_UNLOAD = function()
    allvars.isloaded = false
    autofarmtoggle:Set(false)
    tasks.deleteall()
    _G.globaluilibrary:Destroy()
    _G.waxloaded = false
    if gethui():FindFirstChild("wax") then gethui().wax:Destroy() end
    autodigconnection:Disconnect()
    antiafkconnection:Disconnect()
    disconnecthandlerconnection:Disconnect()
    respawnhandlerconnection:Disconnect()
    vicaddedhandler:Disconnect()
    if deathconnection then deathconnection:Disconnect() end
    restorefunction(beepopup.Open)
    restorefunction(beeinspector.Open)
end

task.spawn(function()
    if SaveTable.autofarm and SaveTable.autofarm.CurrentValue then
        task.wait(1)
        if not allvars.autofarm then autofarmtoggle:Set(true) end
    end
end)

alertboxes.Push(nil, "Thank you for using Lunar BSS | Loaded in " .. string.format("%.2f", tick() - realloadstart) .. "s", nil, "Rainbow")

task.wait(1)
_G.LUNAR_LOADING = false
