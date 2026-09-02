--[[
    ========================================================================================
     ARCANE LINEAGE - ALL-IN-ONE MASTER HUB (LinoriaLib GUI + SaveManager + ThemeManager)
    ========================================================================================
    Features:
    • [Auto Farm Whitelist]: Fast Menu-Scan (Hops directly from MainMenu if 0 targets),
      Smooth anti-jitter 3-phase Sky-Tween flight (default 1500 Y), Auto-Harvest, Auto-ServerHop,
      Adaptable Multi-Item Discord Webhook Notifications.
    • [Desert & Sanctum Fake Item Blacklist]: Ignores Vastic Grave Desert Crylights & Sanctum Decoys.
    • [Auto Combat QTE]: Perfect Dodge 100%, Sword (100% single-click, 0.25s debounced sweet-spot precision),
      Dagger (100% dynamic arc-size weakpoint precision tracking), Hammer (PID Bang-Bang),
      Axe (Threshold Equilibrium), Fist/Cestus (Sequential combos),
      Spear (Active Button Clicker), Chest Lockpicking.
    • [Movement Suite with Keybinds]: Fly Hack (X), NoClip (V), Velocity Speedhack (B),
      CFrame Speed Bypass (N), Infinite Jump Boost (J) with LinoriaLib Keybind Pickers.
    • [Teleport Suite]: Smooth Anti-Jitter Sky-Tween (default 1500 Y) to ALL 35+ Class Trainers,
      Towns, Church (Heavens Point), Desert, Merchants, and Landmarks with full cancel support
      and height/speed sliders.
    • [Ingredient ESP]: Custom BillboardGui OOP Engine with Distance, Persistent Mode, Whitelist filter.
    • [FPS Booster & Optimization]: Remove Fog, Atmosphere, Shadows, Foliage, Materials, Instant Clean RAM.
    • [Config & Theme System]: SaveManager & ThemeManager (Full save/load configurations).
    ========================================================================================
--]]

local globalEnv = (getgenv and getgenv()) or _G
local currentInitTime = os.clock()
if globalEnv._ArcaneHubInitLock and (currentInitTime - globalEnv._ArcaneHubInitLock < 3) then
    return
end
globalEnv._ArcaneHubInitLock = currentInitTime

if not game:IsLoaded() then
    local loaded = false
    local conn
    conn = game.Loaded:Connect(function() loaded = true end)
    local startTime = os.clock()
    while not game:IsLoaded() and not loaded and (os.clock() - startTime < 8) do
        task.wait(0.1)
    end
    if conn then conn:Disconnect() end
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local startWait = os.clock()
    while not Players.LocalPlayer and (os.clock() - startWait < 10) do
        task.wait(0.1)
    end
    LocalPlayer = Players.LocalPlayer
end
local PlayerGui = LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5))

if shared.ArcaneHub then
    pcall(function()
        if type(shared.ArcaneHub) == "table" and shared.ArcaneHub.Unload then
            shared.ArcaneHub.Unload()
        elseif shared.ArcaneHub.Unload then
            shared.ArcaneHub:Unload()
        end
    end)
    shared.ArcaneHub = nil
end

local HubState = {
    running = true,
    connections = {},
}

local function registerConnection(conn)
    if conn then
        table.insert(HubState.connections, conn)
    end
    return conn
end

-- Force destroy any lingering old Linoria GUIs
pcall(function()
    local parentObj = (gethui and gethui()) or game:GetService("CoreGui") or PlayerGui
    if parentObj then
        for _, gui in ipairs(parentObj:GetChildren()) do
            if gui.Name == "LinoriaLib" or gui.Name == "Arcane Hub" then
                gui:Destroy()
            end
        end
    end
end)

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local GuiCollisionService = nil
pcall(function()
    GuiCollisionService = require(game.ReplicatedStorage:WaitForChild("GuiCollisionService", 5))
end)

local HttpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local function getQueuePayload()
    return [=[
task.spawn(function()
    task.wait(1.5)
    local genv = (getgenv and getgenv()) or _G
    if genv._ArcaneHubRunning or (shared and shared.ArcaneHub) then
        return
    end

    local executed = false
    -- 1. Try loading from executor local script
    local fileCandidates = {
        "MainScript.lua",
        "Arcane_Hub_ZeroLib.lua",
        "scripts/MainScript.lua",
        "scripts/Arcane_Hub_ZeroLib.lua",
    }
    for _, path in ipairs(fileCandidates) do
        if not executed and readfile and isfile and isfile(path) then
            local ok, src = pcall(readfile, path)
            if ok and type(src) == "string" and #src > 100 then
                local loadOk, fn = pcall(loadstring, src)
                if loadOk and type(fn) == "function" then
                    local runOk, err = pcall(fn)
                    if runOk then executed = true; break end
                end
            end
        end
    end

    -- 2. Master GitHub Loader
    if not executed then
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/ZeroDepTrai/Arcane-Lineage-Hub/main/MainScript.lua"))()
        end)
    end
end)
]=]
end

local lastQueueTimestamp = 0
local function queueTeleportScript(force)
    local now = os.clock()
    if not force and (now - lastQueueTimestamp < 4) then
        return true
    end
    lastQueueTimestamp = now

    local clearQueueFn = clearqueueonteleport 
        or clearteleportqueue 
        or clear_teleport_queue 
        or (syn and syn.clear_teleport_queue)
        or (getgenv and (getgenv().clearqueueonteleport or getgenv().clearteleportqueue or getgenv().clear_teleport_queue))

    if clearQueueFn then
        pcall(clearQueueFn)
    end

    local queueFn = queue_on_teleport 
        or queueonteleport 
        or (syn and syn.queue_on_teleport) 
        or (fluxus and fluxus.queue_on_teleport) 
        or (Krnl and Krnl.queue_on_teleport)
        or (getgenv and (getgenv().queue_on_teleport or getgenv().queueonteleport))

    if queueFn then
        local ok, err = pcall(function()
            queueFn(getQueuePayload())
        end)
        return ok
    end
    return false
end

-- =============================================================================
-- LOAD LINORIA GUI LIBRARY + THEME & SAVE MANAGERS
-- =============================================================================
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

local function safeHttpGet(url)
    local content = nil
    for attempt = 1, 3 do
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and res and #res > 0 then
            content = res
            break
        end
        task.wait(0.3)
    end
    return content
end

local libSource = safeHttpGet(repo .. "Library.lua")
local themeSource = safeHttpGet(repo .. "addons/ThemeManager.lua")
local saveSource = safeHttpGet(repo .. "addons/SaveManager.lua")

if not libSource then
    warn("[ArcaneHub]  Unable to load LinoriaLib from GitHub! Please try again in a few seconds.")
    return
end

-- =============================================================================
-- EMBEDDED ZEROLIB UI ENGINE (v2.7 HIGH-READABILITY EDITION)
-- =============================================================================
local ZeroLib = (function()
--[[
    ========================================================================================
    🩸 ZEROLIB v2.7 - COMPREHENSIVE PRODUCTION ENGINE
    ========================================================================================
    • Full Linoria Multi-Select Dictionary Support: Options[id].Value[item] == true
    • 1-Based Number Index Default Resolution: Default = 1 resolves to Values[1]
    • Multi-Callback Dispatcher: Supports both initial Callback and multiple OnChanged listeners
    • Anti-AFK Conflict Fix: Default Menu Key is Enum.KeyCode.End (no more random minimize)
    • Live Config Manager with Dynamic Dropdown & Refresh
    • 100% Native Gradient ColorPicker (Hue + Sat/Val + RGB + Hex)
    • Dynamic Real-Time Watermark (FPS + Ping ms)
    • Full Unload & Resource Cleanup
    ========================================================================================
--]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- =============================================================================
-- TYPOGRAPHY ENGINE (BUILDERSANS & GOTHAM HYBRID)
-- =============================================================================
local DevFont = {
    Title = Enum.Font.BuilderSansBold or Enum.Font.GothamBold,
    Bold = Enum.Font.BuilderSansBold or Enum.Font.GothamBold,
    Medium = Enum.Font.BuilderSansMedium or Enum.Font.GothamMedium,
    Regular = Enum.Font.BuilderSans or Enum.Font.Gotham,
}

local function applyFont(label, weight)
    if weight == "Bold" or weight == true then
        label.Font = DevFont.Bold
    elseif weight == "Medium" then
        label.Font = DevFont.Medium
    else
        label.Font = DevFont.Regular
    end
end

local ZeroLib = {
    Themes = {
        Crimson = {
            Name = "Crimson Bloodline",
            MainBg = Color3.fromRGB(8, 8, 10),
            SidebarBg = Color3.fromRGB(11, 11, 14),
            CardBg = Color3.fromRGB(14, 14, 18),
            CardInner = Color3.fromRGB(20, 20, 26),
            CardStroke = Color3.fromRGB(32, 32, 40),
            Accent = Color3.fromRGB(239, 68, 68),
            AccentGlow = Color3.fromRGB(185, 28, 28),
            AccentSecondary = Color3.fromRGB(244, 63, 94),
            TextMain = Color3.fromRGB(250, 250, 250),
            TextMuted = Color3.fromRGB(155, 155, 165),
            TextDark = Color3.fromRGB(90, 90, 100),
            Success = Color3.fromRGB(34, 197, 94),
            Warning = Color3.fromRGB(245, 158, 11),
            Danger = Color3.fromRGB(239, 68, 68),
        },
        CyberCyan = {
            Name = "Cyber-Tactical Cyan",
            MainBg = Color3.fromRGB(10, 12, 16),
            SidebarBg = Color3.fromRGB(13, 16, 22),
            CardBg = Color3.fromRGB(16, 20, 26),
            CardInner = Color3.fromRGB(22, 28, 38),
            CardStroke = Color3.fromRGB(32, 42, 56),
            Accent = Color3.fromRGB(6, 182, 212),
            AccentGlow = Color3.fromRGB(8, 145, 178),
            AccentSecondary = Color3.fromRGB(14, 165, 233),
            TextMain = Color3.fromRGB(248, 250, 252),
            TextMuted = Color3.fromRGB(145, 160, 180),
            TextDark = Color3.fromRGB(85, 100, 120),
            Success = Color3.fromRGB(34, 197, 94),
            Warning = Color3.fromRGB(245, 158, 11),
            Danger = Color3.fromRGB(239, 68, 68),
        },
        MidnightViolet = {
            Name = "Midnight Violet",
            MainBg = Color3.fromRGB(9, 8, 13),
            SidebarBg = Color3.fromRGB(12, 10, 18),
            CardBg = Color3.fromRGB(16, 14, 24),
            CardInner = Color3.fromRGB(24, 20, 34),
            CardStroke = Color3.fromRGB(38, 32, 54),
            Accent = Color3.fromRGB(168, 85, 247),
            AccentGlow = Color3.fromRGB(126, 34, 206),
            AccentSecondary = Color3.fromRGB(192, 132, 252),
            TextMain = Color3.fromRGB(250, 245, 255),
            TextMuted = Color3.fromRGB(160, 155, 175),
            TextDark = Color3.fromRGB(100, 95, 115),
            Success = Color3.fromRGB(34, 197, 94),
            Warning = Color3.fromRGB(245, 158, 11),
            Danger = Color3.fromRGB(239, 68, 68),
        },
        EmeraldGlass = {
            Name = "Emerald Glass",
            MainBg = Color3.fromRGB(8, 11, 9),
            SidebarBg = Color3.fromRGB(10, 15, 12),
            CardBg = Color3.fromRGB(14, 20, 16),
            CardInner = Color3.fromRGB(18, 28, 22),
            CardStroke = Color3.fromRGB(28, 42, 34),
            Accent = Color3.fromRGB(16, 185, 129),
            AccentGlow = Color3.fromRGB(5, 150, 105),
            AccentSecondary = Color3.fromRGB(52, 211, 153),
            TextMain = Color3.fromRGB(245, 255, 250),
            TextMuted = Color3.fromRGB(140, 160, 150),
            TextDark = Color3.fromRGB(85, 105, 95),
            Success = Color3.fromRGB(34, 197, 94),
            Warning = Color3.fromRGB(245, 158, 11),
            Danger = Color3.fromRGB(239, 68, 68),
        }
    },
    ActiveTheme = "CyberCyan",
    Toggles = {},
    Options = {},
    Flags = {},
    Windows = {},
    ActiveNotifications = {},
    Notifications = nil,
    Watermark = nil,
    PopoverLayer = nil,
    ActivePopover = nil,
    IsVisible = true,
    ToggleKey = Enum.KeyCode.End,
    ThemeObjects = {},
    Connections = {},
    Font = DevFont
}

local globalEnv = (getgenv and getgenv()) or _G
globalEnv.Toggles = ZeroLib.Toggles
globalEnv.Options = ZeroLib.Options
globalEnv.ZeroLib = ZeroLib
pcall(function() shared.ZeroLib = ZeroLib end)
pcall(function() shared.Toggles = ZeroLib.Toggles end)
pcall(function() shared.Options = ZeroLib.Options end)
pcall(function() _G.ZeroLib = ZeroLib end)
pcall(function() _G.Toggles = ZeroLib.Toggles end)
pcall(function() _G.Options = ZeroLib.Options end)

local Icons = {
    Combat = "rbxassetid://10734975692",   -- Material Symbols: Swords
    Farm = "rbxassetid://10709769841",     -- Material Symbols: Sprout / Leaf
    World = "rbxassetid://10723415903",    -- Material Symbols: Globe
    Teleport = "rbxassetid://10723415903", -- Material Symbols: Globe / Portal
    Settings = "rbxassetid://10734950309", -- Material Symbols: Sliders
    Player = "rbxassetid://10747373176",   -- Material Symbols: Zap / Speed
    Movement = "rbxassetid://10747373176", -- Material Symbols: Zap / Speed
    Visuals = "rbxassetid://10723415205",  -- Material Symbols: Eye
    Terminal = "rbxassetid://10734950020", -- Material Symbols: Terminal
    Dot = "rbxassetid://10709773823"
}
ZeroLib.Icons = Icons

local function tween(object, info, properties)
    local tw = TweenService:Create(object, info, properties)
    tw:Play()
    return tw
end

local function fastTween(object, properties, duration)
    return tween(object, TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
end

local function round(val, decimalPlaces)
    local shift = 10 ^ (decimalPlaces or 0)
    return math.floor(val * shift + 0.5) / shift
end

local function makeDraggable(topbar, mainFrame)
    local dragging = false
    local dragInput, dragStart, startPos

    local c1 = topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    local c2 = topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    local c3 = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    table.insert(ZeroLib.Connections, c1)
    table.insert(ZeroLib.Connections, c2)
    table.insert(ZeroLib.Connections, c3)
end

function ZeroLib:SetToggleKey(key)
    if typeof(key) == "EnumItem" then
        self.ToggleKey = key
    elseif type(key) == "string" then
        self.ToggleKey = Enum.KeyCode[key] or self.ToggleKey
    end
end

-- =============================================================================
-- UNLOAD SYSTEM
-- =============================================================================
function ZeroLib:Unload()
    print("[ZeroLib] 🧹 Cleaning up and unloading GUI...")

    for _, conn in ipairs(self.Connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        elseif type(conn) == "table" and conn.Disconnect then
            pcall(conn.Disconnect)
        end
    end
    table.clear(self.Connections)

    for _, win in ipairs(self.Windows) do
        if win.Gui and win.Gui.Parent then
            win.Gui:Destroy()
        end
    end
    table.clear(self.Windows)

    if self.Watermark and self.Watermark.Gui and self.Watermark.Gui.Parent then
        self.Watermark.Gui:Destroy()
    end
    self.Watermark = nil

    if self.Notifications and self.Notifications.Gui and self.Notifications.Gui.Parent then
        self.Notifications.Gui:Destroy()
    end
    self.Notifications = nil

    getgenv().ZeroLib = nil
    print("[ZeroLib] ✨ Unloaded successfully!")
end

-- =============================================================================
-- THEME ENGINE
-- =============================================================================
function ZeroLib:RegisterThemeObject(inst, prop, themeKey)
    table.insert(self.ThemeObjects, { Instance = inst, Property = prop, Key = themeKey })
    local theme = self.Themes[self.ActiveTheme]
    if theme and theme[themeKey] and inst and inst.Parent then
        inst[prop] = theme[themeKey]
    end
end

function ZeroLib:SetTheme(themeName)
    if not self.Themes[themeName] then return end
    self.ActiveTheme = themeName
    local theme = self.Themes[themeName]

    for _, item in ipairs(self.ThemeObjects) do
        if item.Instance and item.Instance.Parent and theme[item.Key] then
            pcall(function()
                item.Instance[item.Property] = theme[item.Key]
            end)
        end
    end

    for _, tog in pairs(self.Toggles) do
        if tog.UpdateVisuals then tog:UpdateVisuals() end
    end

    for _, opt in pairs(self.Options) do
        if opt.UpdateVisuals then opt:UpdateVisuals() end
    end

    for _, win in ipairs(self.Windows) do
        for _, tab in ipairs(win.Tabs) do
            if tab == win.ActiveTab then
                tab.Button.BackgroundColor3 = theme.CardBg
                tab.Label.TextColor3 = theme.TextMain
                tab.Icon.ImageColor3 = theme.Accent
                tab.Button.Indicator.BackgroundColor3 = theme.Accent
                tab.Button.Indicator.BackgroundTransparency = 0
            else
                tab.Button.BackgroundTransparency = 1
                tab.Label.TextColor3 = theme.TextMuted
                tab.Icon.ImageColor3 = theme.TextMuted
                tab.Button.Indicator.BackgroundTransparency = 1
            end
        end
    end

    for _, notif in ipairs(self.ActiveNotifications) do
        if notif.Card and notif.Card.Parent then
            notif.Card.BackgroundColor3 = theme.CardBg
            if notif.AccentBar then notif.AccentBar.BackgroundColor3 = theme.Accent end
            if notif.ProgressBar then notif.ProgressBar.BackgroundColor3 = theme.Accent end
            if notif.TitleLabel then notif.TitleLabel.TextColor3 = theme.TextMain end
            if notif.ContentLabel then notif.ContentLabel.TextColor3 = theme.TextMuted end
            if notif.Stroke then notif.Stroke.Color = theme.CardStroke end
        end
    end

    if self.Watermark and self.Watermark.Frame and self.Watermark.Frame.Parent then
        self.Watermark.Frame.BackgroundColor3 = theme.MainBg
        if self.Watermark.Line then self.Watermark.Line.BackgroundColor3 = theme.Accent end
        if self.Watermark.Label then self.Watermark.Label.TextColor3 = theme.TextMain end
    end
end

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================
function ZeroLib:InitNotifications()
    if self.Notifications then return self.Notifications end

    local parentGui = (function()
        local pgui = LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 3))
        if pgui then return pgui end
        local hui = gethui and gethui()
        if hui and not hui:IsA("ScreenGui") and not hui:IsA("GuiObject") then return hui end
        return CoreGui or pgui
    end)()

    local notifGui = Instance.new("ScreenGui")
    notifGui.Name = "ZeroLib_Notifications"
    notifGui.ResetOnSpawn = false
    notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    notifGui.Parent = parentGui

    local notifContainer = Instance.new("Frame")
    notifContainer.Name = "Container"
    notifContainer.Size = UDim2.new(0, 270, 1, -30)
    notifContainer.Position = UDim2.new(1, -285, 0, 15)
    notifContainer.BackgroundTransparency = 1
    notifContainer.Parent = notifGui

    local layout = Instance.new("UIListLayout")
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = notifContainer

    self.Notifications = { Gui = notifGui, Container = notifContainer }
    return self.Notifications
end

function ZeroLib:Notify(data)
    local notifs = self:InitNotifications()
    local theme = self.Themes[self.ActiveTheme]

    local title = type(data) == "table" and data.Title or "Notification"
    local content = type(data) == "table" and (data.Content or data.Text or "") or tostring(data)
    local duration = type(data) == "table" and data.Duration or 3.5
    local notifType = type(data) == "table" and data.Type or "Info"

    local typeColor = theme.Accent
    if type(data) == "table" and data.Color then
        typeColor = data.Color
    elseif notifType == "Warning" then
        typeColor = theme.Warning
    elseif notifType == "Error" or notifType == "Danger" then
        typeColor = theme.Danger
    else
        typeColor = theme.Accent
    end

    local card = Instance.new("Frame")
    card.Name = "NotifCard"
    card.Size = UDim2.new(1, 0, 0, 0)
    card.BackgroundColor3 = theme.CardBg
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = notifs.Container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = theme.CardStroke
    stroke.Thickness = 1
    stroke.Parent = card

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, 0)
    accentBar.BackgroundColor3 = typeColor
    accentBar.BorderSizePixel = 0
    accentBar.Parent = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 18)
    titleLabel.Position = UDim2.new(0, 10, 0, 6)
    titleLabel.BackgroundTransparency = 1
    applyFont(titleLabel, "Bold")
    titleLabel.Text = title
    titleLabel.TextColor3 = theme.TextMain
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = card

    local contentLabel = Instance.new("TextLabel")
    contentLabel.Size = UDim2.new(1, -20, 0, 0)
    contentLabel.Position = UDim2.new(0, 10, 0, 24)
    contentLabel.BackgroundTransparency = 1
    applyFont(contentLabel, "Regular")
    contentLabel.Text = content
    contentLabel.TextColor3 = theme.TextMuted
    contentLabel.TextSize = 11.5
    contentLabel.TextWrapped = true
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextYAlignment = Enum.TextYAlignment.Top
    contentLabel.Parent = card

    local progressTrack = Instance.new("Frame")
    progressTrack.Size = UDim2.new(1, 0, 0, 2)
    progressTrack.Position = UDim2.new(0, 0, 1, -2)
    progressTrack.BackgroundColor3 = theme.CardInner
    progressTrack.BorderSizePixel = 0
    progressTrack.Parent = card

    local progressBar = Instance.new("Frame")
    progressBar.Size = UDim2.new(1, 0, 1, 0)
    progressBar.BackgroundColor3 = typeColor
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressTrack

    local notifObj = {
        Card = card,
        AccentBar = accentBar,
        ProgressBar = progressBar,
        TitleLabel = titleLabel,
        ContentLabel = contentLabel,
        Stroke = stroke
    }
    table.insert(self.ActiveNotifications, notifObj)

    local textHeight = TextService:GetTextSize(content, 10, DevFont.Regular, Vector2.new(250, 1000)).Y
    local finalHeight = math.max(50, 32 + textHeight)

    fastTween(card, { Size = UDim2.new(1, 0, 0, finalHeight) }, 0.2)
    tween(progressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })

    task.delay(duration, function()
        if card and card.Parent then
            local tw = fastTween(card, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, 0.16)
            tw.Completed:Connect(function()
                card:Destroy()
                local idx = table.find(ZeroLib.ActiveNotifications, notifObj)
                if idx then table.remove(ZeroLib.ActiveNotifications, idx) end
            end)
        end
    end)
end

-- =============================================================================
-- REAL-TIME WATERMARK
-- =============================================================================
function ZeroLib:SetWatermark(gameTitle)
    local theme = self.Themes[self.ActiveTheme]
    local parentGui = (function()
        local pgui = LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 3))
        if pgui then return pgui end
        local hui = gethui and gethui()
        if hui and not hui:IsA("ScreenGui") and not hui:IsA("GuiObject") then return hui end
        return CoreGui or pgui
    end)()

    gameTitle = gameTitle or "Arcane Lineage"

    if not self.Watermark then
        local wmGui = Instance.new("ScreenGui")
        wmGui.Name = "ZeroLib_Watermark"
        wmGui.ResetOnSpawn = false
        wmGui.Parent = parentGui

        local wmFrame = Instance.new("Frame")
        wmFrame.Name = "WatermarkFrame"
        wmFrame.Size = UDim2.new(0, 0, 0, 24)
        wmFrame.Position = UDim2.new(0, 16, 0, 16)
        wmFrame.BackgroundColor3 = theme.MainBg
        wmFrame.BorderSizePixel = 0
        wmFrame.Parent = wmGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = wmFrame

        local stroke = Instance.new("UIStroke")
        stroke.Color = theme.CardStroke
        stroke.Thickness = 1
        stroke.Parent = wmFrame

        local accentLine = Instance.new("Frame")
        accentLine.Size = UDim2.new(0, 2, 1, -8)
        accentLine.Position = UDim2.new(0, 4, 0, 4)
        accentLine.BackgroundColor3 = theme.Accent
        accentLine.BorderSizePixel = 0
        accentLine.Parent = wmFrame

        local label = Instance.new("TextLabel")
        label.Name = "TextLabel"
        label.Size = UDim2.new(1, -16, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        applyFont(label, "Bold")
        label.TextColor3 = theme.TextMain
        label.TextSize = 11.5
        label.Parent = wmFrame

        self.Watermark = { Gui = wmGui, Frame = wmFrame, Label = label, Line = accentLine, Title = gameTitle }
        self:RegisterThemeObject(wmFrame, "BackgroundColor3", "MainBg")
        self:RegisterThemeObject(stroke, "Color", "CardStroke")
        self:RegisterThemeObject(accentLine, "BackgroundColor3", "Accent")

        local frameCount = 0
        local lastUpdate = os.clock()
        local currentFps = 60

        local renderConn = RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            local now = os.clock()
            if now - lastUpdate >= 0.4 then
                currentFps = math.floor(frameCount / (now - lastUpdate))
                frameCount = 0
                lastUpdate = now

                local ping = 0
                pcall(function()
                    if StatsService and StatsService.Network and StatsService.Network.ServerStatsItem and StatsService.Network.ServerStatsItem["Data Ping"] then
                        ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
                    end
                end)

                if self.Watermark and self.Watermark.Label and self.Watermark.Label.Parent then
                    local display = string.format("%s  |  %d FPS  |  %d ms", self.Watermark.Title, currentFps, ping)
                    self.Watermark.Label.Text = display
                    local txtWidth = TextService:GetTextSize(display, 10, DevFont.Bold, Vector2.new(1000, 24)).X
                    self.Watermark.Frame.Size = UDim2.new(0, txtWidth + 22, 0, 24)
                end
            end
        end)
        table.insert(self.Connections, renderConn)
    else
        self.Watermark.Title = gameTitle
    end
end

-- =============================================================================
-- WINDOW BUILDER (COMPACT & SLEEK 560x400)
-- =============================================================================
function ZeroLib:CreateWindow(config)
    local theme = self.Themes[self.ActiveTheme]
    local parentGui = (function()
        local pgui = LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 3))
        if pgui then return pgui end
        local hui = gethui and gethui()
        if hui and not hui:IsA("ScreenGui") and not hui:IsA("GuiObject") then return hui end
        return CoreGui or pgui
    end)()

    local titleText = config.Title or "ARCANE LINEAGE"
    local subTitleText = config.SubTitle or "CRIMSON v2.7"
    local windowSize = config.Size or UDim2.new(0, 680, 0, 480)
    local toggleKey = config.ToggleKey or Enum.KeyCode.End
    ZeroLib.ToggleKey = toggleKey

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ZeroLib_UI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parentGui

    -- Popover Layer
    local popoverLayer = Instance.new("Frame")
    popoverLayer.Name = "PopoverLayer"
    popoverLayer.Size = UDim2.new(1, 0, 1, 0)
    popoverLayer.BackgroundTransparency = 1
    popoverLayer.ZIndex = 500
    popoverLayer.Parent = screenGui
    ZeroLib.PopoverLayer = popoverLayer

    -- Popover Click-Outside Listener with Anchor Safety
    local clickConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if ZeroLib.ActivePopover and ZeroLib.ActivePopover.Close then
                local pos = input.Position
                local popInst = ZeroLib.ActivePopover.Instance
                local anchor = ZeroLib.ActivePopover.Anchor

                local inPop = false
                if popInst and popInst.Parent then
                    local absPos = popInst.AbsolutePosition
                    local absSize = popInst.AbsoluteSize
                    inPop = (pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y)
                end

                local inAnchor = false
                if anchor and anchor.Parent then
                    local aPos = anchor.AbsolutePosition
                    local aSize = anchor.AbsoluteSize
                    inAnchor = (pos.X >= aPos.X and pos.X <= aPos.X + aSize.X and pos.Y >= aPos.Y and pos.Y <= aPos.Y + aSize.Y)
                end

                if not inPop and not inAnchor and not ZeroLib.ActivePopover.IgnoreClick then
                    ZeroLib.ActivePopover.Close()
                end
            end
        end
    end)
    table.insert(ZeroLib.Connections, clickConn)

    -- Main Shell Frame
    local mainShell = Instance.new("Frame")
    mainShell.Name = "MainShell"
    mainShell.Size = windowSize
    mainShell.Position = UDim2.new(0.5, -windowSize.X.Offset / 2, 0.5, -windowSize.Y.Offset / 2)
    mainShell.BackgroundColor3 = theme.MainBg
    mainShell.BorderSizePixel = 0
    mainShell.ClipsDescendants = false
    mainShell.Parent = screenGui

    local shellCorner = Instance.new("UICorner")
    shellCorner.CornerRadius = UDim.new(0, 6)
    shellCorner.Parent = mainShell

    local shellStroke = Instance.new("UIStroke")
    shellStroke.Color = theme.CardStroke
    shellStroke.Thickness = 1
    shellStroke.Parent = mainShell

    ZeroLib:RegisterThemeObject(mainShell, "BackgroundColor3", "MainBg")
    ZeroLib:RegisterThemeObject(shellStroke, "Color", "CardStroke")

    -- Topbar (Height: 36px)
    local topbar = Instance.new("Frame")
    topbar.Name = "Topbar"
    topbar.Size = UDim2.new(1, 0, 0, 36)
    topbar.BackgroundColor3 = theme.SidebarBg
    topbar.BorderSizePixel = 0
    topbar.Parent = mainShell

    local topbarCorner = Instance.new("UICorner")
    topbarCorner.CornerRadius = UDim.new(0, 6)
    topbarCorner.Parent = topbar

    local topbarBottomLine = Instance.new("Frame")
    topbarBottomLine.Size = UDim2.new(1, 0, 0, 1)
    topbarBottomLine.Position = UDim2.new(0, 0, 1, -1)
    topbarBottomLine.BackgroundColor3 = theme.CardStroke
    topbarBottomLine.BorderSizePixel = 0
    topbarBottomLine.Parent = topbar

    ZeroLib:RegisterThemeObject(topbar, "BackgroundColor3", "SidebarBg")
    ZeroLib:RegisterThemeObject(topbarBottomLine, "BackgroundColor3", "CardStroke")

    makeDraggable(topbar, mainShell)

    -- Brand Icon & Clean Title
    local titleIcon = Instance.new("ImageLabel")
    titleIcon.Size = UDim2.new(0, 16, 0, 16)
    titleIcon.Position = UDim2.new(0, 10, 0.5, -8)
    titleIcon.BackgroundTransparency = 1
    titleIcon.Image = Icons.Terminal
    titleIcon.ImageColor3 = theme.Accent
    titleIcon.Parent = topbar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 150, 1, 0)
    titleLabel.Position = UDim2.new(0, 32, 0, 0)
    titleLabel.BackgroundTransparency = 1
    applyFont(titleLabel, "Bold")
    titleLabel.Text = titleText
    titleLabel.TextColor3 = theme.TextMain
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = topbar

    ZeroLib:RegisterThemeObject(titleIcon, "ImageColor3", "Accent")
    ZeroLib:RegisterThemeObject(titleLabel, "TextColor3", "TextMain")

    -- Topbar Buttons (Minimize & Full UNLOAD Button)
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Size = UDim2.new(0, 56, 1, 0)
    controlsFrame.Position = UDim2.new(1, -60, 0, 0)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.Parent = topbar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(0, 2, 0.5, -11)
    minBtn.BackgroundColor3 = theme.CardBg
    minBtn.BorderSizePixel = 0
    applyFont(minBtn, "Bold")
    minBtn.Text = "-"
    minBtn.TextColor3 = theme.TextMuted
    minBtn.TextSize = 13
    minBtn.Parent = controlsFrame

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = minBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(0, 28, 0.5, -11)
    closeBtn.BackgroundColor3 = theme.Danger
    closeBtn.BorderSizePixel = 0
    applyFont(closeBtn, "Bold")
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 12
    closeBtn.Parent = controlsFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        ZeroLib:Unload()
    end)

    minBtn.MouseButton1Click:Connect(function()
        ZeroLib.IsVisible = not ZeroLib.IsVisible
        mainShell.Visible = ZeroLib.IsVisible
    end)

    -- Toggle GUI Key Listener (Strict check to prevent false AFK pulses)
    local keyConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == ZeroLib.ToggleKey then
            ZeroLib.IsVisible = not ZeroLib.IsVisible
            mainShell.Visible = ZeroLib.IsVisible
        end
    end)
    table.insert(ZeroLib.Connections, keyConn)

    -- Sidebar (Slim 130px)
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 130, 1, -36)
    sidebar.Position = UDim2.new(0, 0, 0, 36)
    sidebar.BackgroundColor3 = theme.SidebarBg
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainShell

    local sidebarRightLine = Instance.new("Frame")
    sidebarRightLine.Size = UDim2.new(0, 1, 1, 0)
    sidebarRightLine.Position = UDim2.new(1, -1, 0, 0)
    sidebarRightLine.BackgroundColor3 = theme.CardStroke
    sidebarRightLine.BorderSizePixel = 0
    sidebarRightLine.Parent = sidebar

    ZeroLib:RegisterThemeObject(sidebar, "BackgroundColor3", "SidebarBg")
    ZeroLib:RegisterThemeObject(sidebarRightLine, "BackgroundColor3", "CardStroke")

    local tabList = Instance.new("ScrollingFrame")
    tabList.Name = "TabList"
    tabList.Size = UDim2.new(1, -10, 1, -12)
    tabList.Position = UDim2.new(0, 5, 0, 6)
    tabList.BackgroundTransparency = 1
    tabList.BorderSizePixel = 0
    tabList.ScrollBarThickness = 2
    tabList.Parent = sidebar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabList

    -- Page Container
    local pageContainer = Instance.new("Frame")
    pageContainer.Name = "PageContainer"
    pageContainer.Size = UDim2.new(1, -130, 1, -36)
    pageContainer.Position = UDim2.new(0, 130, 0, 36)
    pageContainer.BackgroundTransparency = 1
    pageContainer.Parent = mainShell

    local Window = {
        Gui = screenGui,
        Main = mainShell,
        Tabs = {},
        ActiveTab = nil,
    }
    table.insert(ZeroLib.Windows, Window)

    -- ADD TAB
    function Window:AddTab(tabConfig)
        local tabName = type(tabConfig) == "table" and tabConfig.Name or tostring(tabConfig)
        local tabIconAsset = type(tabConfig) == "table" and tabConfig.Icon or Icons.Combat

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab_" .. tabName
        tabBtn.Size = UDim2.new(1, 0, 0, 30)
        tabBtn.BackgroundColor3 = theme.CardBg
        tabBtn.BackgroundTransparency = 1
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = ""
        tabBtn.Parent = tabList

        local tabBtnCorner = Instance.new("UICorner")
        tabBtnCorner.CornerRadius = UDim.new(0, 4)
        tabBtnCorner.Parent = tabBtn

        local tabIcon = Instance.new("ImageLabel")
        tabIcon.Size = UDim2.new(0, 14, 0, 14)
        tabIcon.Position = UDim2.new(0, 8, 0.5, -7)
        tabIcon.BackgroundTransparency = 1
        tabIcon.Image = tabIconAsset
        tabIcon.ImageColor3 = theme.TextMuted
        tabIcon.Parent = tabBtn

        local tabLabel = Instance.new("TextLabel")
        tabLabel.Size = UDim2.new(1, -28, 1, 0)
        tabLabel.Position = UDim2.new(0, 26, 0, 0)
        tabLabel.BackgroundTransparency = 1
        applyFont(tabLabel, "Medium")
        tabLabel.Text = tabName
        tabLabel.TextColor3 = theme.TextMuted
        tabLabel.TextSize = 12
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.Parent = tabBtn

        local activeIndicator = Instance.new("Frame")
        activeIndicator.Name = "Indicator"
        activeIndicator.Size = UDim2.new(0, 2, 0, 14)
        activeIndicator.Position = UDim2.new(0, 2, 0.5, -7)
        activeIndicator.BackgroundColor3 = theme.Accent
        activeIndicator.BackgroundTransparency = 1
        activeIndicator.BorderSizePixel = 0
        activeIndicator.Parent = tabBtn

        local indCorner = Instance.new("UICorner")
        indCorner.CornerRadius = UDim.new(1, 0)
        indCorner.Parent = activeIndicator

        -- Content Page
        local tabPage = Instance.new("ScrollingFrame")
        tabPage.Name = "Page_" .. tabName
        tabPage.Size = UDim2.new(1, -12, 1, -12)
        tabPage.Position = UDim2.new(0, 6, 0, 6)
        tabPage.BackgroundTransparency = 1
        tabPage.BorderSizePixel = 0
        tabPage.ScrollBarThickness = 3
        tabPage.Visible = false
        tabPage.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabPage.Parent = pageContainer

        local leftColumn = Instance.new("Frame")
        leftColumn.Name = "LeftColumn"
        leftColumn.Size = UDim2.new(0.5, -4, 1, 0)
        leftColumn.Position = UDim2.new(0, 0, 0, 0)
        leftColumn.BackgroundTransparency = 1
        leftColumn.Parent = tabPage

        local leftLayout = Instance.new("UIListLayout")
        leftLayout.Padding = UDim.new(0, 6)
        leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
        leftLayout.Parent = leftColumn

        local rightColumn = Instance.new("Frame")
        rightColumn.Name = "RightColumn"
        rightColumn.Size = UDim2.new(0.5, -4, 1, 0)
        rightColumn.Position = UDim2.new(0.5, 4, 0, 0)
        rightColumn.BackgroundTransparency = 1
        rightColumn.Parent = tabPage

        local rightLayout = Instance.new("UIListLayout")
        rightLayout.Padding = UDim.new(0, 6)
        rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rightLayout.Parent = rightColumn

        local function updateCanvasSize()
            local lHeight = leftLayout.AbsoluteContentSize.Y
            local rHeight = rightLayout.AbsoluteContentSize.Y
            local maxH = math.max(lHeight, rHeight)
            tabPage.CanvasSize = UDim2.new(0, 0, 0, maxH + 14)
        end

        leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
        rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

        local Tab = {
            Name = tabName,
            Button = tabBtn,
            Icon = tabIcon,
            Label = tabLabel,
            Page = tabPage,
            LeftColumn = leftColumn,
            RightColumn = rightColumn,
        }

        function Tab:Select()
            local curTheme = ZeroLib.Themes[ZeroLib.ActiveTheme]
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                t.Button.BackgroundTransparency = 1
                t.Label.TextColor3 = curTheme.TextMuted
                t.Icon.ImageColor3 = curTheme.TextMuted
                t.Button.Indicator.BackgroundTransparency = 1
            end
            tabPage.Visible = true
            tabBtn.BackgroundTransparency = 0
            tabBtn.BackgroundColor3 = curTheme.CardBg
            tabLabel.TextColor3 = curTheme.TextMain
            tabIcon.ImageColor3 = curTheme.Accent
            activeIndicator.BackgroundColor3 = curTheme.Accent
            activeIndicator.BackgroundTransparency = 0
            Window.ActiveTab = Tab
        end

        tabBtn.MouseButton1Click:Connect(function()
            Tab:Select()
        end)

        -- GROUPBOX BUILDER
        local function createGroupbox(parentCol, title)
            local card = Instance.new("Frame")
            card.Name = "Group_" .. title
            card.Size = UDim2.new(1, 0, 0, 32)
            card.BackgroundColor3 = theme.CardBg
            card.BorderSizePixel = 0
            card.Parent = parentCol

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 5)
            cardCorner.Parent = card

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = theme.CardStroke
            cardStroke.Thickness = 1
            cardStroke.Parent = card

            ZeroLib:RegisterThemeObject(card, "BackgroundColor3", "CardBg")
            ZeroLib:RegisterThemeObject(cardStroke, "Color", "CardStroke")

            local headerFrame = Instance.new("Frame")
            headerFrame.Size = UDim2.new(1, 0, 0, 24)
            headerFrame.BackgroundTransparency = 1
            headerFrame.Parent = card

            local accentPip = Instance.new("Frame")
            accentPip.Size = UDim2.new(0, 2, 0, 10)
            accentPip.Position = UDim2.new(0, 8, 0.5, -5)
            accentPip.BackgroundColor3 = theme.Accent
            accentPip.BorderSizePixel = 0
            accentPip.Parent = headerFrame

            local pipCorner = Instance.new("UICorner")
            pipCorner.CornerRadius = UDim.new(1, 0)
            pipCorner.Parent = accentPip

            local cardHeader = Instance.new("TextLabel")
            cardHeader.Size = UDim2.new(1, -24, 1, 0)
            cardHeader.Position = UDim2.new(0, 16, 0, 0)
            cardHeader.BackgroundTransparency = 1
            applyFont(cardHeader, "Bold")
            cardHeader.Text = title
            cardHeader.TextColor3 = theme.TextMain
            cardHeader.TextSize = 12.5
            cardHeader.TextXAlignment = Enum.TextXAlignment.Left
            cardHeader.Parent = headerFrame

            local headerDiv = Instance.new("Frame")
            headerDiv.Size = UDim2.new(1, -16, 0, 1)
            headerDiv.Position = UDim2.new(0, 8, 1, -1)
            headerDiv.BackgroundColor3 = theme.CardStroke
            headerDiv.BorderSizePixel = 0
            headerDiv.Parent = headerFrame

            ZeroLib:RegisterThemeObject(accentPip, "BackgroundColor3", "Accent")
            ZeroLib:RegisterThemeObject(cardHeader, "TextColor3", "TextMain")
            ZeroLib:RegisterThemeObject(headerDiv, "BackgroundColor3", "CardStroke")

            local container = Instance.new("Frame")
            container.Name = "Container"
            container.Size = UDim2.new(1, -16, 0, 0)
            container.Position = UDim2.new(0, 8, 0, 26)
            container.BackgroundTransparency = 1
            container.Parent = card

            local cLayout = Instance.new("UIListLayout")
            cLayout.Padding = UDim.new(0, 5)
            cLayout.SortOrder = Enum.SortOrder.LayoutOrder
            cLayout.Parent = container

            cLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                card.Size = UDim2.new(1, 0, 0, cLayout.AbsoluteContentSize.Y + 34)
            end)

            local Group = { Card = card, Container = container }

            function Group:Resize()
                pcall(function()
                    card.Size = UDim2.new(1, 0, 0, cLayout.AbsoluteContentSize.Y + 34)
                end)
            end

            -- 100% NATIVE PRO COLORPICKER
            local function createProColorPicker(cpId, defaultColor, callback, anchorButton)
                local curColor = defaultColor or Color3.fromRGB(239, 68, 68)
                local h, s, v = curColor:ToHSV()

                local pickerFrame = Instance.new("Frame")
                pickerFrame.Name = "ProColorPicker_" .. cpId
                pickerFrame.Size = UDim2.new(0, 184, 0, 186)
                pickerFrame.BackgroundColor3 = theme.CardBg
                pickerFrame.BorderSizePixel = 0
                pickerFrame.ClipsDescendants = true
                pickerFrame.Visible = false
                pickerFrame.ZIndex = 700
                pickerFrame.Parent = ZeroLib.PopoverLayer

                local pCorner = Instance.new("UICorner")
                pCorner.CornerRadius = UDim.new(0, 5)
                pCorner.Parent = pickerFrame

                local pStroke = Instance.new("UIStroke")
                pStroke.Color = theme.CardStroke
                pStroke.Thickness = 1
                pStroke.Parent = pickerFrame

                ZeroLib:RegisterThemeObject(pickerFrame, "BackgroundColor3", "CardBg")
                ZeroLib:RegisterThemeObject(pStroke, "Color", "CardStroke")

                -- 1. Saturation / Value 2D Box
                local svBox = Instance.new("Frame")
                svBox.Name = "SVBox"
                svBox.Size = UDim2.new(1, -16, 0, 95)
                svBox.Position = UDim2.new(0, 8, 0, 8)
                svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                svBox.BorderSizePixel = 0
                svBox.ClipsDescendants = true
                svBox.ZIndex = 701
                svBox.Parent = pickerFrame

                local svCorner = Instance.new("UICorner")
                svCorner.CornerRadius = UDim.new(0, 4)
                svCorner.Parent = svBox

                local satOverlay = Instance.new("Frame")
                satOverlay.Name = "SatOverlay"
                satOverlay.Size = UDim2.new(1, 0, 1, 0)
                satOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                satOverlay.BorderSizePixel = 0
                satOverlay.ZIndex = 702
                satOverlay.Parent = svBox

                local satGrad = Instance.new("UIGradient")
                satGrad.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1)
                })
                satGrad.Parent = satOverlay

                local valOverlay = Instance.new("Frame")
                valOverlay.Name = "ValOverlay"
                valOverlay.Size = UDim2.new(1, 0, 1, 0)
                valOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                valOverlay.BorderSizePixel = 0
                valOverlay.ZIndex = 703
                valOverlay.Parent = svBox

                local valGrad = Instance.new("UIGradient")
                valGrad.Rotation = 90
                valGrad.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0)
                })
                valGrad.Parent = valOverlay

                local svCursor = Instance.new("Frame")
                svCursor.Name = "SVCursor"
                svCursor.Size = UDim2.new(0, 10, 0, 10)
                svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
                svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                svCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                svCursor.BorderSizePixel = 0
                svCursor.ZIndex = 705
                svCursor.Parent = svBox

                local curCorner = Instance.new("UICorner")
                curCorner.CornerRadius = UDim.new(1, 0)
                curCorner.Parent = svCursor

                local curStroke = Instance.new("UIStroke")
                curStroke.Color = Color3.fromRGB(0, 0, 0)
                curStroke.Thickness = 1.5
                curStroke.Parent = svCursor

                -- 2. Rainbow Hue Bar
                local hueBar = Instance.new("Frame")
                hueBar.Name = "HueBar"
                hueBar.Size = UDim2.new(1, -16, 0, 12)
                hueBar.Position = UDim2.new(0, 8, 0, 110)
                hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                hueBar.BorderSizePixel = 0
                hueBar.ZIndex = 701
                hueBar.Parent = pickerFrame

                local hueCorner = Instance.new("UICorner")
                hueCorner.CornerRadius = UDim.new(0, 3)
                hueCorner.Parent = hueBar

                local rainbowGrad = Instance.new("UIGradient")
                rainbowGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
                })
                rainbowGrad.Parent = hueBar

                local hueCursor = Instance.new("Frame")
                hueCursor.Name = "HueCursor"
                hueCursor.Size = UDim2.new(0, 5, 1, 4)
                hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
                hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                hueCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                hueCursor.BorderSizePixel = 0
                hueCursor.ZIndex = 705
                hueCursor.Parent = hueBar

                local hCurCorner = Instance.new("UICorner")
                hCurCorner.CornerRadius = UDim.new(0, 2)
                hCurCorner.Parent = hueCursor

                local hCurStroke = Instance.new("UIStroke")
                hCurStroke.Color = Color3.fromRGB(0, 0, 0)
                hCurStroke.Thickness = 1
                hCurStroke.Parent = hueCursor

                -- 3. Live Preview & Hex Input Row
                local bottomRow = Instance.new("Frame")
                bottomRow.Size = UDim2.new(1, -16, 0, 24)
                bottomRow.Position = UDim2.new(0, 8, 0, 128)
                bottomRow.BackgroundTransparency = 1
                bottomRow.Parent = pickerFrame

                local previewBox = Instance.new("Frame")
                previewBox.Size = UDim2.new(0, 24, 0, 24)
                previewBox.BackgroundColor3 = curColor
                previewBox.BorderSizePixel = 0
                previewBox.ZIndex = 701
                previewBox.Parent = bottomRow

                local prevCorner = Instance.new("UICorner")
                prevCorner.CornerRadius = UDim.new(0, 4)
                prevCorner.Parent = previewBox

                local prevStroke = Instance.new("UIStroke")
                prevStroke.Color = theme.CardStroke
                prevStroke.Thickness = 1
                prevStroke.Parent = previewBox

                local hexInput = Instance.new("TextBox")
                hexInput.Size = UDim2.new(1, -30, 1, 0)
                hexInput.Position = UDim2.new(0, 30, 0, 0)
                hexInput.BackgroundColor3 = theme.CardInner
                hexInput.BorderSizePixel = 0
                applyFont(hexInput, "Bold")
                hexInput.Text = "#" .. curColor:ToHex():upper()
                hexInput.TextColor3 = theme.TextMain
                hexInput.TextSize = 11.5
                hexInput.ZIndex = 701
                hexInput.Parent = bottomRow

                local hexCorner = Instance.new("UICorner")
                hexCorner.CornerRadius = UDim.new(0, 4)
                hexCorner.Parent = hexInput

                local hexStroke = Instance.new("UIStroke")
                hexStroke.Color = theme.CardStroke
                hexStroke.Thickness = 1
                hexStroke.Parent = hexInput

                -- 4. Editable RGB Inputs Row
                local rgbRow = Instance.new("Frame")
                rgbRow.Size = UDim2.new(1, -16, 0, 22)
                rgbRow.Position = UDim2.new(0, 8, 0, 156)
                rgbRow.BackgroundTransparency = 1
                rgbRow.Parent = pickerFrame

                local rgbLayout = Instance.new("UIListLayout")
                rgbLayout.FillDirection = Enum.FillDirection.Horizontal
                rgbLayout.Padding = UDim.new(0, 4)
                rgbLayout.Parent = rgbRow

                local function createRgbBox(labelTxt, initialVal)
                    local f = Instance.new("Frame")
                    f.Size = UDim2.new(0.333, -3, 1, 0)
                    f.BackgroundColor3 = theme.CardInner
                    f.BorderSizePixel = 0
                    f.ZIndex = 701
                    f.Parent = rgbRow

                    local fc = Instance.new("UICorner")
                    fc.CornerRadius = UDim.new(0, 3)
                    fc.Parent = f

                    local fs = Instance.new("UIStroke")
                    fs.Color = theme.CardStroke
                    fs.Thickness = 1
                    fs.Parent = f

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(0, 12, 1, 0)
                    lbl.Position = UDim2.new(0, 3, 0, 0)
                    lbl.BackgroundTransparency = 1
                    applyFont(lbl, "Bold")
                    lbl.Text = labelTxt
                    lbl.TextColor3 = theme.TextMuted
                    lbl.TextSize = 9
                    lbl.ZIndex = 702
                    lbl.Parent = f

                    local tb = Instance.new("TextBox")
                    tb.Size = UDim2.new(1, -16, 1, 0)
                    tb.Position = UDim2.new(0, 14, 0, 0)
                    tb.BackgroundTransparency = 1
                    applyFont(tb, "Medium")
                    tb.Text = tostring(math.floor(initialVal * 255))
                    tb.TextColor3 = theme.TextMain
                    tb.TextSize = 11
                    tb.ZIndex = 702
                    tb.Parent = f

                    return tb
                end

                local rBox = createRgbBox("R", curColor.R)
                local gBox = createRgbBox("G", curColor.G)
                local bBox = createRgbBox("B", curColor.B)

                local ColorObj = {
                    Value = curColor,
                    H = h,
                    S = s,
                    V = v,
                    IsOpen = false,
                    Callbacks = callback and { callback } or {},
                    Type = "ColorPicker"
                }

                local function updateColor(newH, newS, newV)
                    ColorObj.H = newH or ColorObj.H
                    ColorObj.S = newS or ColorObj.S
                    ColorObj.V = newV or ColorObj.V

                    local finalColor = Color3.fromHSV(ColorObj.H, ColorObj.S, ColorObj.V)
                    ColorObj.Value = finalColor

                    svBox.BackgroundColor3 = Color3.fromHSV(ColorObj.H, 1, 1)
                    svCursor.Position = UDim2.new(ColorObj.S, 0, 1 - ColorObj.V, 0)
                    hueCursor.Position = UDim2.new(ColorObj.H, 0, 0.5, 0)
                    previewBox.BackgroundColor3 = finalColor
                    anchorButton.BackgroundColor3 = finalColor
                    hexInput.Text = "#" .. finalColor:ToHex():upper()

                    rBox.Text = tostring(math.floor(finalColor.R * 255))
                    gBox.Text = tostring(math.floor(finalColor.G * 255))
                    bBox.Text = tostring(math.floor(finalColor.B * 255))

                    for _, cb in ipairs(ColorObj.Callbacks) do
                        pcall(cb, finalColor)
                    end
                end

                function ColorObj:SetValue(col)
                    self.Value = col
                    local nh, ns, nv = col:ToHSV()
                    updateColor(nh, ns, nv)
                end

                function ColorObj:OnChanged(fn)
                    table.insert(self.Callbacks, fn)
                end

                function ColorObj:TogglePicker(open)
                    if open == nil then open = not self.IsOpen end
                    self.IsOpen = open

                    if open then
                        if ZeroLib.ActivePopover and ZeroLib.ActivePopover.Close then
                            ZeroLib.ActivePopover.Close()
                        end

                        local absPos = anchorButton.AbsolutePosition
                        local absSize = anchorButton.AbsoluteSize
                        pickerFrame.Position = UDim2.new(0, absPos.X - 160, 0, absPos.Y + absSize.Y + 4)
                        pickerFrame.Visible = true
                        pickerFrame.Size = UDim2.new(0, 184, 0, 0)
                        fastTween(pickerFrame, { Size = UDim2.new(0, 184, 0, 186) }, 0.16)

                        ZeroLib.ActivePopover = {
                            Instance = pickerFrame,
                            Anchor = anchorButton,
                            Close = function() ColorObj:TogglePicker(false) end
                        }
                    else
                        fastTween(pickerFrame, { Size = UDim2.new(0, 184, 0, 0) }, 0.12).Completed:Connect(function()
                            if not self.IsOpen then pickerFrame.Visible = false end
                        end)
                        if ZeroLib.ActivePopover and ZeroLib.ActivePopover.Instance == pickerFrame then
                            ZeroLib.ActivePopover = nil
                        end
                    end
                end

                local slidingSV = false
                local svBtn = Instance.new("TextButton")
                svBtn.Size = UDim2.new(1, 0, 1, 0)
                svBtn.BackgroundTransparency = 1
                svBtn.Text = ""
                svBtn.ZIndex = 706
                svBtn.Parent = svBox

                svBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        slidingSV = true
                        local relX = math.clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
                        local relY = math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
                        updateColor(nil, relX, 1 - relY)
                    end
                end)

                local slidingHue = false
                local hueBtn = Instance.new("TextButton")
                hueBtn.Size = UDim2.new(1, 0, 1, 0)
                hueBtn.BackgroundTransparency = 1
                hueBtn.Text = ""
                hueBtn.ZIndex = 706
                hueBtn.Parent = hueBar

                hueBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        slidingHue = true
                        local relX = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
                        updateColor(relX, nil, nil)
                    end
                end)

                local endConn = UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        slidingSV = false
                        slidingHue = false
                    end
                end)
                table.insert(ZeroLib.Connections, endConn)

                local moveConn = UserInputService.InputChanged:Connect(function(input)
                    if slidingSV and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local relX = math.clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
                        local relY = math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
                        updateColor(nil, relX, 1 - relY)
                    elseif slidingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local relX = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
                        updateColor(relX, nil, nil)
                    end
                end)
                table.insert(ZeroLib.Connections, moveConn)

                hexInput.FocusLost:Connect(function()
                    local raw = hexInput.Text:gsub("#", "")
                    local ok, col = pcall(Color3.fromHex, raw)
                    if ok and col then
                        ColorObj:SetValue(col)
                    end
                end)

                local function parseRgb()
                    local r = math.clamp(tonumber(rBox.Text) or 0, 0, 255) / 255
                    local g = math.clamp(tonumber(gBox.Text) or 0, 0, 255) / 255
                    local b = math.clamp(tonumber(bBox.Text) or 0, 0, 255) / 255
                    ColorObj:SetValue(Color3.new(r, g, b))
                end

                rBox.FocusLost:Connect(parseRgb)
                gBox.FocusLost:Connect(parseRgb)
                bBox.FocusLost:Connect(parseRgb)

                anchorButton.MouseButton1Click:Connect(function()
                    ColorObj:TogglePicker()
                end)

                ZeroLib.Options[cpId] = ColorObj
                return ColorObj
            end

            -- 1. TOGGLE COMPONENT
            function Group:AddToggle(id, toggleConfig)
                local text = toggleConfig.Text or id
                local default = toggleConfig.Default or false
                local callback = toggleConfig.Callback

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 20)
                row.BackgroundTransparency = 1
                row.Parent = container

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -74, 1, 0)
                label.BackgroundTransparency = 1
                applyFont(label, "Medium")
                label.Text = text
                label.TextColor3 = default and theme.TextMain or theme.TextMuted
                label.TextSize = 11.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                local subContainer = Instance.new("Frame")
                subContainer.Size = UDim2.new(0, 74, 1, 0)
                subContainer.Position = UDim2.new(1, -74, 0, 0)
                subContainer.BackgroundTransparency = 1
                subContainer.Parent = row

                local subLayout = Instance.new("UIListLayout")
                subLayout.FillDirection = Enum.FillDirection.Horizontal
                subLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                subLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                subLayout.Padding = UDim.new(0, 4)
                subLayout.Parent = subContainer

                local switch = Instance.new("TextButton")
                switch.Size = UDim2.new(0, 30, 0, 15)
                switch.BackgroundColor3 = default and theme.Accent or theme.CardInner
                switch.BorderSizePixel = 0
                switch.Text = ""
                switch.Parent = subContainer

                local swCorner = Instance.new("UICorner")
                swCorner.CornerRadius = UDim.new(1, 0)
                swCorner.Parent = switch

                local knob = Instance.new("Frame")
                knob.Size = UDim2.new(0, 11, 0, 11)
                knob.Position = default and UDim2.new(1, -13, 0.5, -5.5) or UDim2.new(0, 2, 0.5, -5.5)
                knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                knob.BorderSizePixel = 0
                knob.Parent = switch

                local knobCorner = Instance.new("UICorner")
                knobCorner.CornerRadius = UDim.new(1, 0)
                knobCorner.Parent = knob

                local ToggleObj = {
                    Value = default,
                    Callbacks = callback and { callback } or {},
                    Type = "Toggle"
                }

                function ToggleObj:UpdateVisuals()
                    local curTheme = ZeroLib.Themes[ZeroLib.ActiveTheme]
                    local targetPos = self.Value and UDim2.new(1, -13, 0.5, -5.5) or UDim2.new(0, 2, 0.5, -5.5)
                    local targetBg = self.Value and curTheme.Accent or curTheme.CardInner
                    fastTween(knob, { Position = targetPos }, 0.12)
                    fastTween(switch, { BackgroundColor3 = targetBg }, 0.12)
                    label.TextColor3 = self.Value and curTheme.TextMain or curTheme.TextMuted
                end

                function ToggleObj:SetValue(val)
                    self.Value = val
                    self:UpdateVisuals()
                    for _, fn in ipairs(self.Callbacks) do
                        pcall(fn, val)
                    end
                end

                function ToggleObj:OnChanged(fn)
                    table.insert(self.Callbacks, fn)
                end

                switch.MouseButton1Click:Connect(function()
                    ToggleObj:SetValue(not ToggleObj.Value)
                end)

                -- INLINE KEYBIND & KEYPICKER
                function ToggleObj:AddKeybind(kbId, kbConfig)
                    kbConfig = kbConfig or {}
                    local rawDefault = kbConfig.Default
                    local kbDefault = Enum.KeyCode.Unknown
                    if typeof(rawDefault) == "EnumItem" then
                        kbDefault = rawDefault
                    elseif type(rawDefault) == "string" then
                        kbDefault = Enum.KeyCode[rawDefault] or Enum.KeyCode.Unknown
                    end

                    local kbMode = kbConfig.Mode or "Toggle"
                    local kbCallback = kbConfig.Callback

                    local kbBtn = Instance.new("TextButton")
                    kbBtn.Size = UDim2.new(0, 36, 0, 15)
                    kbBtn.BackgroundColor3 = theme.CardInner
                    kbBtn.BorderSizePixel = 0
                    applyFont(kbBtn, "Bold")
                    kbBtn.Text = kbDefault.Name ~= "Unknown" and kbDefault.Name or "NONE"
                    kbBtn.TextColor3 = theme.TextMuted
                    kbBtn.TextSize = 10
                    kbBtn.LayoutOrder = 1
                    kbBtn.Parent = subContainer

                    local kCorner = Instance.new("UICorner")
                    kCorner.CornerRadius = UDim.new(0, 3)
                    kCorner.Parent = kbBtn

                    local kStroke = Instance.new("UIStroke")
                    kStroke.Color = theme.CardStroke
                    kStroke.Thickness = 1
                    kStroke.Parent = kbBtn

                    ZeroLib:RegisterThemeObject(kbBtn, "BackgroundColor3", "CardInner")
                    ZeroLib:RegisterThemeObject(kStroke, "Color", "CardStroke")

                    local KeybindObj = {
                        Value = kbDefault,
                        Mode = kbMode,
                        Binding = false,
                        Callbacks = kbCallback and { kbCallback } or {},
                        Type = "Keybind"
                    }

                    function KeybindObj:OnChanged(fn)
                        table.insert(self.Callbacks, fn)
                    end

                    function KeybindObj:SetValue(key)
                        if typeof(key) == "EnumItem" then
                            self.Value = key
                        elseif type(key) == "string" then
                            self.Value = Enum.KeyCode[key] or Enum.KeyCode.Unknown
                        end
                        kbBtn.Text = self.Value.Name ~= "Unknown" and self.Value.Name or "NONE"
                        for _, fn in ipairs(self.Callbacks) do
                            pcall(fn, self.Value)
                        end
                    end

                    kbBtn.MouseButton1Click:Connect(function()
                        KeybindObj.Binding = true
                        kbBtn.Text = "..."
                        kbBtn.TextColor3 = ZeroLib.Themes[ZeroLib.ActiveTheme].Accent
                    end)

                    local kbConn = UserInputService.InputBegan:Connect(function(input, gpe)
                        if KeybindObj.Binding and not gpe then
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                KeybindObj.Binding = false
                                if input.KeyCode == Enum.KeyCode.Escape then
                                    KeybindObj:SetValue(Enum.KeyCode.Unknown)
                                else
                                    KeybindObj:SetValue(input.KeyCode)
                                end
                                kbBtn.TextColor3 = ZeroLib.Themes[ZeroLib.ActiveTheme].TextMuted
                            end
                        elseif not gpe and input.KeyCode == KeybindObj.Value and KeybindObj.Value ~= Enum.KeyCode.Unknown then
                            if KeybindObj.Mode == "Toggle" then
                                ToggleObj:SetValue(not ToggleObj.Value)
                            elseif KeybindObj.Mode == "Hold" then
                                ToggleObj:SetValue(true)
                            end
                            for _, fn in ipairs(KeybindObj.Callbacks) do
                                pcall(fn, ToggleObj.Value)
                            end
                        end
                    end)
                    table.insert(ZeroLib.Connections, kbConn)

                    local kbEndConn = UserInputService.InputEnded:Connect(function(input, gpe)
                        if not gpe and input.KeyCode == KeybindObj.Value and KeybindObj.Mode == "Hold" then
                            ToggleObj:SetValue(false)
                        end
                    end)
                    table.insert(ZeroLib.Connections, kbEndConn)

                    ZeroLib.Options[kbId or (id .. "_Keybind")] = KeybindObj
                    return KeybindObj
                end

                ToggleObj.AddKeyPicker = ToggleObj.AddKeybind

                -- INLINE PRO COLORPICKER
                function ToggleObj:AddColorPicker(cpId, cpConfig)
                    local cpDefault = cpConfig.Default or Color3.fromRGB(239, 68, 68)
                    local cpCallback = cpConfig.Callback

                    local colorBox = Instance.new("TextButton")
                    colorBox.Size = UDim2.new(0, 16, 0, 15)
                    colorBox.BackgroundColor3 = cpDefault
                    colorBox.BorderSizePixel = 0
                    colorBox.Text = ""
                    colorBox.LayoutOrder = 2
                    colorBox.Parent = subContainer

                    local cCorner = Instance.new("UICorner")
                    cCorner.CornerRadius = UDim.new(0, 3)
                    cCorner.Parent = colorBox

                    local cStroke = Instance.new("UIStroke")
                    cStroke.Color = theme.CardStroke
                    cStroke.Thickness = 1
                    cStroke.Parent = colorBox

                    ZeroLib:RegisterThemeObject(cStroke, "Color", "CardStroke")

                    return createProColorPicker(cpId or (id .. "_Color"), cpDefault, cpCallback, colorBox)
                end

                ZeroLib.Toggles[id] = ToggleObj
                return ToggleObj
            end

            -- 2. BUTTON COMPONENT
            function Group:AddButton(btnConfig, callbackArg)
                local text, callback
                if type(btnConfig) == "table" then
                    text = btnConfig.Text or "Button"
                    callback = btnConfig.Func or btnConfig.Callback or function() end
                else
                    text = tostring(btnConfig or "Button")
                    callback = callbackArg or function() end
                end

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 24)
                btn.BackgroundColor3 = theme.CardInner
                btn.BorderSizePixel = 0
                applyFont(btn, "Bold")
                btn.Text = text
                btn.TextColor3 = theme.TextMain
                btn.TextSize = 12
                btn.Parent = container

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 4)
                bCorner.Parent = btn

                local bStroke = Instance.new("UIStroke")
                bStroke.Color = theme.CardStroke
                bStroke.Thickness = 1
                bStroke.Parent = btn

                ZeroLib:RegisterThemeObject(btn, "BackgroundColor3", "CardInner")
                ZeroLib:RegisterThemeObject(btn, "TextColor3", "TextMain")
                ZeroLib:RegisterThemeObject(bStroke, "Color", "CardStroke")

                btn.MouseButton1Click:Connect(function()
                    fastTween(btn, { Size = UDim2.new(1, -2, 0, 25) }, 0.06).Completed:Connect(function()
                        fastTween(btn, { Size = UDim2.new(1, 0, 0, 26) }, 0.06)
                    end)
                    pcall(callback)
                end)

                return btn
            end

            -- 3. SLIDER COMPONENT
            function Group:AddSlider(id, sliderConfig)
                local text = sliderConfig.Text or id
                local min = sliderConfig.Min or 0
                local max = sliderConfig.Max or 100
                local default = sliderConfig.Default or min
                local rounding = sliderConfig.Rounding or 0
                local suffix = sliderConfig.Suffix or ""
                local callback = sliderConfig.Callback

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 30)
                row.BackgroundTransparency = 1
                row.Parent = container

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -60, 0, 14)
                label.BackgroundTransparency = 1
                applyFont(label, "Regular")
        label.Text = text
        label.TextColor3 = theme.TextMuted
        label.TextSize = 11.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                local valLabel = Instance.new("TextLabel")
                valLabel.Size = UDim2.new(0, 60, 0, 14)
                valLabel.Position = UDim2.new(1, -60, 0, 0)
                valLabel.BackgroundTransparency = 1
                applyFont(valLabel, "Bold")
                valLabel.Text = tostring(default) .. suffix
                valLabel.TextColor3 = theme.Accent
                valLabel.TextSize = 11.5
                valLabel.TextXAlignment = Enum.TextXAlignment.Right
                valLabel.Parent = row

                local sliderBar = Instance.new("TextButton")
                sliderBar.Size = UDim2.new(1, 0, 0, 6)
                sliderBar.Position = UDim2.new(0, 0, 0, 18)
                sliderBar.BackgroundColor3 = theme.CardInner
                sliderBar.BorderSizePixel = 0
                sliderBar.Text = ""
                sliderBar.Parent = row

                local barCorner = Instance.new("UICorner")
                barCorner.CornerRadius = UDim.new(1, 0)
                barCorner.Parent = sliderBar

                local fill = Instance.new("Frame")
                local startPercent = math.clamp((default - min) / (max - min), 0, 1)
                fill.Size = UDim2.new(startPercent, 0, 1, 0)
                fill.BackgroundColor3 = theme.Accent
                fill.BorderSizePixel = 0
                fill.Parent = sliderBar

                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(1, 0)
                fillCorner.Parent = fill

                ZeroLib:RegisterThemeObject(label, "TextColor3", "TextMuted")
                ZeroLib:RegisterThemeObject(sliderBar, "BackgroundColor3", "CardInner")
                ZeroLib:RegisterThemeObject(valLabel, "TextColor3", "Accent")
                ZeroLib:RegisterThemeObject(fill, "BackgroundColor3", "Accent")

                local SliderObj = {
                    Value = default,
                    Callbacks = callback and { callback } or {},
                    Type = "Slider"
                }

                function SliderObj:UpdateVisuals()
                    local curTheme = ZeroLib.Themes[ZeroLib.ActiveTheme]
                    valLabel.TextColor3 = curTheme.Accent
                    fill.BackgroundColor3 = curTheme.Accent
                end

                local function updateSlider(input)
                    local percent = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
                    local rawVal = min + (max - min) * percent
                    local finalVal = round(rawVal, rounding)
                    SliderObj.Value = finalVal
                    fill.Size = UDim2.new(percent, 0, 1, 0)
                    valLabel.Text = tostring(finalVal) .. suffix
                    for _, fn in ipairs(SliderObj.Callbacks) do
                        pcall(fn, finalVal)
                    end
                end

                function SliderObj:SetValue(val)
                    val = math.clamp(val, min, max)
                    self.Value = val
                    local percent = math.clamp((val - min) / (max - min), 0, 1)
                    fill.Size = UDim2.new(percent, 0, 1, 0)
                    valLabel.Text = tostring(val) .. suffix
                    for _, fn in ipairs(self.Callbacks) do
                        pcall(fn, val)
                    end
                end

                function SliderObj:OnChanged(fn)
                    table.insert(self.Callbacks, fn)
                end

                local sliding = false
                sliderBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        updateSlider(input)
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateSlider(input)
                    end
                end)

                ZeroLib.Options[id] = SliderObj
                return SliderObj
            end

            -- 4. DROPDOWN COMPONENT (FULL DICTIONARY & INDEX RESOLUTION SUPPORT)
            function Group:AddDropdown(id, dropConfig)
                local text = dropConfig.Text or id
                local values = dropConfig.Values or {}
                local isMulti = dropConfig.Multi or false
                local rawDefault = dropConfig.Default
                local callback = dropConfig.Callback

                -- 1. Resolve Initial Value
                local initialValue
                if isMulti then
                    initialValue = {}
                    if type(rawDefault) == "table" then
                        for k, v in pairs(rawDefault) do
                            if type(k) == "number" and type(v) == "string" then
                                initialValue[v] = true
                            elseif type(k) == "string" and v == true then
                                initialValue[k] = true
                            end
                        end
                    elseif type(rawDefault) == "string" then
                        initialValue[rawDefault] = true
                    end
                else
                    if type(rawDefault) == "number" then
                        initialValue = values[rawDefault] or values[1] or ""
                    elseif type(rawDefault) == "string" then
                        initialValue = rawDefault
                    else
                        initialValue = values[1] or ""
                    end
                end

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 38)
                row.BackgroundTransparency = 1
                row.Parent = container

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 0, 14)
                label.BackgroundTransparency = 1
                applyFont(label, "Regular")
        label.Text = text
        label.TextColor3 = theme.TextMuted
        label.TextSize = 11.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                local function getDisplayText(val)
                    if isMulti then
                        local selected = {}
                        for _, item in ipairs(values) do
                            if val and val[item] == true then
                                table.insert(selected, item)
                            end
                        end
                        return #selected > 0 and table.concat(selected, ", ") or "None selected"
                    else
                        return tostring(val or "")
                    end
                end

                local dropBtn = Instance.new("TextButton")
                dropBtn.Size = UDim2.new(1, 0, 0, 22)
                dropBtn.Position = UDim2.new(0, 0, 0, 16)
                dropBtn.BackgroundColor3 = theme.CardInner
                dropBtn.BorderSizePixel = 0
                applyFont(dropBtn, "Medium")
                dropBtn.Text = "  " .. getDisplayText(initialValue)
                dropBtn.TextColor3 = theme.TextMain
                dropBtn.TextSize = 11.5
                dropBtn.TextXAlignment = Enum.TextXAlignment.Left
                dropBtn.Parent = row

                local dCorner = Instance.new("UICorner")
                dCorner.CornerRadius = UDim.new(0, 4)
                dCorner.Parent = dropBtn

                local dStroke = Instance.new("UIStroke")
                dStroke.Color = theme.CardStroke
                dStroke.Thickness = 1
                dStroke.Parent = dropBtn

                local arrow = Instance.new("TextLabel")
                arrow.Size = UDim2.new(0, 16, 1, 0)
                arrow.Position = UDim2.new(1, -18, 0, 0)
                arrow.BackgroundTransparency = 1
                applyFont(arrow, "Bold")
                arrow.Text = "▼"
                arrow.TextColor3 = theme.TextMuted
                arrow.TextSize = 9.5
                arrow.Parent = dropBtn

                ZeroLib:RegisterThemeObject(label, "TextColor3", "TextMuted")
                ZeroLib:RegisterThemeObject(dropBtn, "BackgroundColor3", "CardInner")
                ZeroLib:RegisterThemeObject(dropBtn, "TextColor3", "TextMain")
                ZeroLib:RegisterThemeObject(dStroke, "Color", "CardStroke")

                local dropMenu = Instance.new("ScrollingFrame")
                dropMenu.Name = "DropMenu_" .. id
                dropMenu.Size = UDim2.new(0, 200, 0, 0)
                dropMenu.BackgroundColor3 = theme.CardBg
                dropMenu.BorderSizePixel = 0
                dropMenu.ClipsDescendants = true
                dropMenu.Visible = false
                dropMenu.ZIndex = 600
                dropMenu.ScrollBarThickness = 2
                dropMenu.Parent = ZeroLib.PopoverLayer

                local mCorner = Instance.new("UICorner")
                mCorner.CornerRadius = UDim.new(0, 4)
                mCorner.Parent = dropMenu

                local mStroke = Instance.new("UIStroke")
                mStroke.Color = theme.CardStroke
                mStroke.Thickness = 1
                mStroke.Parent = dropMenu

                local mLayout = Instance.new("UIListLayout")
                mLayout.Padding = UDim.new(0, 2)
                mLayout.SortOrder = Enum.SortOrder.LayoutOrder
                mLayout.Parent = dropMenu

                local DropObj = {
                    Value = initialValue,
                    Values = values,
                    Multi = isMulti,
                    Callbacks = callback and { callback } or {},
                    IsOpen = false,
                    LastCloseTime = 0,
                    Type = "Dropdown"
                }

                local function isItemSelected(valName)
                    if isMulti then
                        return DropObj.Value and DropObj.Value[valName] == true
                    else
                        return DropObj.Value == valName
                    end
                end

                local function rebuildMenu()
                    local curTheme = ZeroLib.Themes[ZeroLib.ActiveTheme]
                    for _, c in ipairs(dropMenu:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end

                    for _, v in ipairs(DropObj.Values) do
                        local selected = isItemSelected(v)
                        local itemBtn = Instance.new("TextButton")
                        itemBtn.Size = UDim2.new(1, -4, 0, 20)
                        itemBtn.Position = UDim2.new(0, 2, 0, 0)
                        itemBtn.BackgroundColor3 = selected and curTheme.CardInner or curTheme.CardBg
                        itemBtn.BackgroundTransparency = selected and 0 or 1
                        itemBtn.BorderSizePixel = 0
                        applyFont(itemBtn, "Medium")
                        itemBtn.Text = (isMulti and (selected and "  ✓ " or "  - ") or "  ") .. tostring(v)
                        itemBtn.TextColor3 = selected and curTheme.Accent or curTheme.TextMuted
                        itemBtn.TextSize = 11.5
                        itemBtn.TextXAlignment = Enum.TextXAlignment.Left
                        itemBtn.ZIndex = 601
                        itemBtn.Parent = dropMenu

                        local iCorner = Instance.new("UICorner")
                        iCorner.CornerRadius = UDim.new(0, 3)
                        iCorner.Parent = itemBtn

                        itemBtn.MouseButton1Click:Connect(function()
                            if isMulti then
                                if not DropObj.Value then DropObj.Value = {} end
                                if DropObj.Value[v] == true then
                                    DropObj.Value[v] = nil
                                else
                                    DropObj.Value[v] = true
                                end
                                DropObj:SetValue(DropObj.Value)
                                rebuildMenu()
                            else
                                DropObj:SetValue(v)
                                DropObj:ToggleMenu(false)
                            end
                        end)
                    end
                    dropMenu.CanvasSize = UDim2.new(0, 0, 0, #DropObj.Values * 22)
                end

                function DropObj:ToggleMenu(open)
                    if open == nil then open = not self.IsOpen end

                    local absPos = dropBtn.AbsolutePosition
                    local absSize = dropBtn.AbsoluteSize

                    if open then
                        if ZeroLib.ActivePopover and ZeroLib.ActivePopover.Close then
                            ZeroLib.ActivePopover.Close()
                        end

                        self.IsOpen = true
                        rebuildMenu()
                        dropMenu.Position = UDim2.new(0, absPos.X, 0, absPos.Y - 4)
                        dropMenu.Size = UDim2.new(0, absSize.X, 0, 0)
                        dropMenu.BackgroundTransparency = 0.4
                        dropMenu.Visible = true

                        local totalH = math.min(140, #DropObj.Values * 22 + 4)
                        tween(dropMenu, TweenInfo.new(0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, absSize.X, 0, totalH),
                            Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 3),
                            BackgroundTransparency = 0
                        })
                        tween(arrow, TweenInfo.new(0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Rotation = 180 })

                        ZeroLib.ActivePopover = {
                            Instance = dropMenu,
                            Anchor = dropBtn,
                            Close = function() DropObj:ToggleMenu(false) end
                        }
                    else
                        self.IsOpen = false

                        tween(arrow, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 })
                        local closeTw = tween(dropMenu, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, absSize.X, 0, 0),
                            Position = UDim2.new(0, absPos.X, 0, absPos.Y - 3),
                            BackgroundTransparency = 0.5
                        })

                        closeTw.Completed:Connect(function()
                            if not self.IsOpen then dropMenu.Visible = false end
                        end)

                        if ZeroLib.ActivePopover and ZeroLib.ActivePopover.Instance == dropMenu then
                            ZeroLib.ActivePopover = nil
                        end
                    end
                end

                function DropObj:UpdateVisuals()
                    local curTheme = ZeroLib.Themes[ZeroLib.ActiveTheme]
                    dropBtn.BackgroundColor3 = curTheme.CardInner
                    dropBtn.TextColor3 = curTheme.TextMain
                    dStroke.Color = curTheme.CardStroke
                    dropMenu.BackgroundColor3 = curTheme.CardBg
                    mStroke.Color = curTheme.CardStroke
                    rebuildMenu()
                end

                function DropObj:SetValue(val)
                    if self.Multi then
                        if type(val) == "table" then
                            local dict = {}
                            for k, v in pairs(val) do
                                if type(k) == "number" and type(v) == "string" then
                                    dict[v] = true
                                elseif type(k) == "string" and v == true then
                                    dict[k] = true
                                end
                            end
                            self.Value = dict
                        elseif type(val) == "string" then
                            self.Value = { [val] = true }
                        end
                    else
                        if type(val) == "number" then
                            self.Value = self.Values[val] or self.Values[1] or ""
                        else
                            self.Value = val
                        end
                    end

                    dropBtn.Text = "  " .. getDisplayText(self.Value)
                    for _, fn in ipairs(self.Callbacks) do
                        pcall(fn, self.Value)
                    end
                end

                function DropObj:SetValues(newVals)
                    self.Values = newVals
                    if self.Multi then
                        self.Value = {}
                        self:SetValue({})
                    else
                        if not table.find(newVals, self.Value) then
                            self:SetValue(newVals[1] or "")
                        end
                    end
                    rebuildMenu()
                end

                function DropObj:OnChanged(fn)
                    table.insert(self.Callbacks, fn)
                end

                dropBtn.MouseButton1Click:Connect(function()
                    DropObj:ToggleMenu()
                end)

                ZeroLib.Options[id] = DropObj
                return DropObj
            end

            -- 5. COMPACT INPUT
            function Group:AddInput(id, inputConfig)
                local text = inputConfig.Text or id
                local default = inputConfig.Default or ""
                local placeholder = inputConfig.Placeholder or "Type here..."
                local callback = inputConfig.Callback

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 38)
                row.BackgroundTransparency = 1
                row.Parent = container

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 0, 14)
                label.BackgroundTransparency = 1
                applyFont(label, "Regular")
        label.Text = text
        label.TextColor3 = theme.TextMuted
        label.TextSize = 11.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                local boxFrame = Instance.new("Frame")
                boxFrame.Size = UDim2.new(1, 0, 0, 22)
                boxFrame.Position = UDim2.new(0, 0, 0, 16)
                boxFrame.BackgroundColor3 = theme.CardInner
                boxFrame.BorderSizePixel = 0
                boxFrame.Parent = row

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 4)
                bCorner.Parent = boxFrame

                local boxStroke = Instance.new("UIStroke")
                boxStroke.Color = theme.CardStroke
                boxStroke.Thickness = 1
                boxStroke.Parent = boxFrame

                local textBox = Instance.new("TextBox")
                textBox.Size = UDim2.new(1, -12, 1, 0)
                textBox.Position = UDim2.new(0, 6, 0, 0)
                textBox.BackgroundTransparency = 1
                applyFont(textBox, "Regular")
                textBox.Text = default
                textBox.PlaceholderText = placeholder
                textBox.TextColor3 = theme.TextMain
                textBox.PlaceholderColor3 = theme.TextDark
                textBox.TextSize = 11.5
                textBox.TextXAlignment = Enum.TextXAlignment.Left
                textBox.Parent = boxFrame

                ZeroLib:RegisterThemeObject(label, "TextColor3", "TextMuted")
                ZeroLib:RegisterThemeObject(boxFrame, "BackgroundColor3", "CardInner")
                ZeroLib:RegisterThemeObject(boxStroke, "Color", "CardStroke")
                ZeroLib:RegisterThemeObject(textBox, "TextColor3", "TextMain")

                local InputObj = {
                    Value = default,
                    Callbacks = callback and { callback } or {},
                    Type = "Input"
                }

                function InputObj:SetValue(val)
                    self.Value = val
                    textBox.Text = tostring(val)
                    for _, fn in ipairs(self.Callbacks) do
                        pcall(fn, val)
                    end
                end

                function InputObj:OnChanged(fn)
                    table.insert(self.Callbacks, fn)
                end

                textBox.FocusLost:Connect(function()
                    InputObj.Value = textBox.Text
                    for _, fn in ipairs(InputObj.Callbacks) do
                        pcall(fn, textBox.Text)
                    end
                end)

                ZeroLib.Options[id] = InputObj
                return InputObj
            end

            -- 6. STANDALONE COLORPICKER
            function Group:AddColorPicker(id, cpConfig)
                local text = cpConfig.Text or id
                local defaultColor = cpConfig.Default or Color3.fromRGB(239, 68, 68)
                local callback = cpConfig.Callback

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 22)
                row.BackgroundTransparency = 1
                row.Parent = container

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -30, 1, 0)
                label.BackgroundTransparency = 1
                applyFont(label, "Regular")
        label.Text = text
        label.TextColor3 = theme.TextMuted
        label.TextSize = 11.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                local colorBox = Instance.new("TextButton")
                colorBox.Size = UDim2.new(0, 22, 0, 16)
                colorBox.Position = UDim2.new(1, -22, 0.5, -8)
                colorBox.BackgroundColor3 = defaultColor
                colorBox.BorderSizePixel = 0
                colorBox.Text = ""
                colorBox.Parent = row

                local cCorner = Instance.new("UICorner")
                cCorner.CornerRadius = UDim.new(0, 3)
                cCorner.Parent = colorBox

                local cStroke = Instance.new("UIStroke")
                cStroke.Color = theme.CardStroke
                cStroke.Thickness = 1
                cStroke.Parent = colorBox

                ZeroLib:RegisterThemeObject(label, "TextColor3", "TextMuted")
                ZeroLib:RegisterThemeObject(cStroke, "Color", "CardStroke")

                return createProColorPicker(id, defaultColor, callback, colorBox)
            end

            -- 7. LABEL & DIVIDER (WITH INLINE KEYPICKER / COLORPICKER SUPPORT)
            function Group:AddLabel(text)
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 18)
                row.BackgroundTransparency = 1
                row.Parent = container

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -50, 1, 0)
                label.BackgroundTransparency = 1
                applyFont(label, "Regular")
        label.Text = text
        label.TextColor3 = theme.TextMuted
        label.TextSize = 11.5
                label.TextWrapped = true
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                ZeroLib:RegisterThemeObject(label, "TextColor3", "TextMuted")

                local subContainer = Instance.new("Frame")
                subContainer.Size = UDim2.new(0, 50, 1, 0)
                subContainer.Position = UDim2.new(1, -50, 0, 0)
                subContainer.BackgroundTransparency = 1
                subContainer.Parent = row

                local subLayout = Instance.new("UIListLayout")
                subLayout.FillDirection = Enum.FillDirection.Horizontal
                subLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                subLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                subLayout.Padding = UDim.new(0, 4)
                subLayout.Parent = subContainer

                local LabelObj = {
                    Instance = label,
                    Row = row,
                    Text = text
                }

                function LabelObj:SetText(newTxt)
                    self.Text = newTxt
                    label.Text = newTxt
                end

                function LabelObj:AddKeybind(kbId, kbConfig)
                    kbConfig = kbConfig or {}
                    local rawDefault = kbConfig.Default
                    local kbDefault = Enum.KeyCode.Unknown
                    if typeof(rawDefault) == "EnumItem" then
                        kbDefault = rawDefault
                    elseif type(rawDefault) == "string" then
                        kbDefault = Enum.KeyCode[rawDefault] or Enum.KeyCode.Unknown
                    end

                    local kbMode = kbConfig.Mode or "Toggle"
                    local kbCallback = kbConfig.Callback

                    local kbBtn = Instance.new("TextButton")
                    kbBtn.Size = UDim2.new(0, 36, 0, 15)
                    kbBtn.BackgroundColor3 = theme.CardInner
                    kbBtn.BorderSizePixel = 0
                    applyFont(kbBtn, "Bold")
                    kbBtn.Text = kbDefault.Name ~= "Unknown" and kbDefault.Name or "NONE"
                    kbBtn.TextColor3 = theme.TextMuted
                    kbBtn.TextSize = 10
                    kbBtn.Parent = subContainer

                    local kCorner = Instance.new("UICorner")
                    kCorner.CornerRadius = UDim.new(0, 3)
                    kCorner.Parent = kbBtn

                    local kStroke = Instance.new("UIStroke")
                    kStroke.Color = theme.CardStroke
                    kStroke.Thickness = 1
                    kStroke.Parent = kbBtn

                    ZeroLib:RegisterThemeObject(kbBtn, "BackgroundColor3", "CardInner")
                    ZeroLib:RegisterThemeObject(kStroke, "Color", "CardStroke")

                    local KeybindObj = {
                        Value = kbDefault,
                        Mode = kbMode,
                        Binding = false,
                        Callbacks = kbCallback and { kbCallback } or {},
                        Type = "Keybind"
                    }

                    function KeybindObj:OnChanged(fn)
                        table.insert(self.Callbacks, fn)
                    end

                    function KeybindObj:SetValue(key)
                        if typeof(key) == "EnumItem" then
                            self.Value = key
                        elseif type(key) == "string" then
                            self.Value = Enum.KeyCode[key] or Enum.KeyCode.Unknown
                        end
                        kbBtn.Text = self.Value.Name ~= "Unknown" and self.Value.Name or "NONE"
                        for _, fn in ipairs(self.Callbacks) do
                            pcall(fn, self.Value)
                        end
                    end

                    kbBtn.MouseButton1Click:Connect(function()
                        KeybindObj.Binding = true
                        kbBtn.Text = "..."
                        kbBtn.TextColor3 = ZeroLib.Themes[ZeroLib.ActiveTheme].Accent
                    end)

                    local kbConn = UserInputService.InputBegan:Connect(function(input, gpe)
                        if KeybindObj.Binding and not gpe then
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                KeybindObj.Binding = false
                                if input.KeyCode == Enum.KeyCode.Escape then
                                    KeybindObj:SetValue(Enum.KeyCode.Unknown)
                                else
                                    KeybindObj:SetValue(input.KeyCode)
                                end
                                kbBtn.TextColor3 = ZeroLib.Themes[ZeroLib.ActiveTheme].TextMuted
                            end
                        elseif not gpe and input.KeyCode == KeybindObj.Value and KeybindObj.Value ~= Enum.KeyCode.Unknown then
                            for _, fn in ipairs(KeybindObj.Callbacks) do
                                pcall(fn, KeybindObj.Value)
                            end
                        end
                    end)
                    table.insert(ZeroLib.Connections, kbConn)

                    ZeroLib.Options[kbId] = KeybindObj
                    return KeybindObj
                end

                LabelObj.AddKeyPicker = LabelObj.AddKeybind

                function LabelObj:AddColorPicker(cpId, cpConfig)
                    local cpDefault = cpConfig.Default or Color3.fromRGB(239, 68, 68)
                    local cpCallback = cpConfig.Callback

                    local colorBox = Instance.new("TextButton")
                    colorBox.Size = UDim2.new(0, 16, 0, 15)
                    colorBox.BackgroundColor3 = cpDefault
                    colorBox.BorderSizePixel = 0
                    colorBox.Text = ""
                    colorBox.Parent = subContainer

                    local cCorner = Instance.new("UICorner")
                    cCorner.CornerRadius = UDim.new(0, 3)
                    cCorner.Parent = colorBox

                    local cStroke = Instance.new("UIStroke")
                    cStroke.Color = theme.CardStroke
                    cStroke.Thickness = 1
                    cStroke.Parent = colorBox

                    ZeroLib:RegisterThemeObject(cStroke, "Color", "CardStroke")

                    return createProColorPicker(cpId, cpDefault, cpCallback, colorBox)
                end

                setmetatable(LabelObj, {
                    __index = function(t, k)
                        return label[k]
                    end,
                    __newindex = function(t, k, v)
                        label[k] = v
                    end
                })

                return LabelObj
            end

            function Group:AddDivider()
                local div = Instance.new("Frame")
                div.Size = UDim2.new(1, 0, 0, 1)
                div.BackgroundColor3 = theme.CardStroke
                div.BorderSizePixel = 0
                div.Parent = container

                ZeroLib:RegisterThemeObject(div, "BackgroundColor3", "CardStroke")
                return div
            end

            return Group
        end

        function Tab:AddLeftGroupbox(title)
            return createGroupbox(leftColumn, title)
        end

        function Tab:AddRightGroupbox(title)
            return createGroupbox(rightColumn, title)
        end

        table.insert(Window.Tabs, Tab)

        if #Window.Tabs == 1 then
            Tab:Select()
        end

        return Tab
    end

    return Window
end

-- =============================================================================
-- LINORIA-STYLE SAVE & CONFIG MANAGER
-- =============================================================================
local SaveManager = {
    Folder = "arcane_configs",
    Ignore = {},
    AutoloadLabel = nil
}

function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:BuildFolderTree()
    if makefolder then
        if not isfolder(self.Folder) then pcall(makefolder, self.Folder) end
        if not isfolder(self.Folder .. "/settings") then pcall(makefolder, self.Folder .. "/settings") end
    end
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in ipairs(list) do
        self.Ignore[key] = true
    end
end

function SaveManager:Save(name)
    if not name or name:gsub("%s+", "") == "" then
        return false, "invalid config name"
    end
    self:BuildFolderTree()

    local data = { Toggles = {}, Options = {}, objects = {} }

    for idx, toggle in pairs(ZeroLib.Toggles) do
        if not self.Ignore[idx] then
            data.Toggles[idx] = toggle.Value
            table.insert(data.objects, { type = "Toggle", idx = idx, value = toggle.Value })
        end
    end

    for idx, option in pairs(ZeroLib.Options) do
        if not self.Ignore[idx] then
            if option.Type == "Slider" or option.Type == "Input" or option.Type == "Dropdown" then
                data.Options[idx] = option.Value
                table.insert(data.objects, { type = option.Type, idx = idx, value = option.Value })
            elseif option.Type == "Keybind" or option.Type == "KeyPicker" then
                local kName = (typeof(option.Value) == "EnumItem") and option.Value.Name or tostring(option.Value)
                data.Options[idx] = kName
                table.insert(data.objects, { type = "KeyPicker", idx = idx, key = kName })
            elseif option.Type == "ColorPicker" then
                local hex = option.Value:ToHex()
                data.Options[idx] = hex
                table.insert(data.objects, { type = "ColorPicker", idx = idx, value = hex })
            end
        end
    end

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then return false, "json encode error" end

    local fullPath = self.Folder .. "/settings/" .. name .. ".json"
    if writefile then
        writefile(fullPath, encoded)
        return true
    end
    return false, "executor missing writefile"
end

function SaveManager:Load(name)
    if not name or name:gsub("%s+", "") == "" then
        return false, "invalid config name"
    end
    self:BuildFolderTree()

    local fullPath = self.Folder .. "/settings/" .. name .. ".json"
    -- Fallback to legacy path if not in settings subfolder
    if not (isfile and isfile(fullPath)) then
        local legacyPath = self.Folder .. "/" .. name .. ".json"
        if isfile and isfile(legacyPath) then
            fullPath = legacyPath
        else
            return false, "invalid file"
        end
    end

    local raw = readfile(fullPath)
    local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok or type(data) ~= "table" then return false, "json decode error" end

    -- Support both Linoria objects array and Toggles/Options dictionary
    if data.Toggles then
        for k, v in pairs(data.Toggles) do
            if ZeroLib.Toggles[k] and not self.Ignore[k] then
                pcall(function() ZeroLib.Toggles[k]:SetValue(v) end)
            end
        end
    end

    if data.Options then
        for k, v in pairs(data.Options) do
            if ZeroLib.Options[k] and not self.Ignore[k] then
                pcall(function()
                    if ZeroLib.Options[k].Type == "Keybind" or ZeroLib.Options[k].Type == "KeyPicker" then
                        local key = Enum.KeyCode[v] or Enum.KeyCode.Unknown
                        ZeroLib.Options[k]:SetValue(key)
                    elseif ZeroLib.Options[k].Type == "ColorPicker" then
                        local col = Color3.fromHex(v)
                        if col then ZeroLib.Options[k]:SetValue(col) end
                    else
                        ZeroLib.Options[k]:SetValue(v)
                    end
                end)
            end
        end
    end

    if data.objects then
        for _, obj in ipairs(data.objects) do
            if obj.type == "Toggle" and ZeroLib.Toggles[obj.idx] and not self.Ignore[obj.idx] then
                pcall(function() ZeroLib.Toggles[obj.idx]:SetValue(obj.value) end)
            elseif obj.type == "ColorPicker" and ZeroLib.Options[obj.idx] and not self.Ignore[obj.idx] then
                pcall(function()
                    local col = Color3.fromHex(obj.value)
                    if col then ZeroLib.Options[obj.idx]:SetValue(col) end
                end)
            elseif (obj.type == "KeyPicker" or obj.type == "Keybind") and ZeroLib.Options[obj.idx] and not self.Ignore[obj.idx] then
                pcall(function()
                    local key = Enum.KeyCode[obj.key] or Enum.KeyCode.Unknown
                    ZeroLib.Options[obj.idx]:SetValue(key)
                end)
            elseif ZeroLib.Options[obj.idx] and not self.Ignore[obj.idx] then
                pcall(function() ZeroLib.Options[obj.idx]:SetValue(obj.value or obj.text) end)
            end
        end
    end

    return true
end

function SaveManager:Delete(name)
    if not name or name == "" then return false end
    self:BuildFolderTree()
    local path = self.Folder .. "/settings/" .. name .. ".json"
    if isfile and isfile(path) and delfile then
        delfile(path)
        -- If this was the autoload config, reset autoload
        local autoName = self:GetAutoloadName()
        if autoName == name then
            self:ResetAutoload()
        end
        return true
    end
    return false
end

function SaveManager:RefreshConfigList()
    self:BuildFolderTree()
    local list = {}
    if listfiles then
        local scanPaths = { self.Folder .. "/settings", self.Folder }
        for _, folder in ipairs(scanPaths) do
            if isfolder and isfolder(folder) then
                pcall(function()
                    for _, p in ipairs(listfiles(folder)) do
                        local fName = p:match("([^/\\]+)%.json$")
                        if fName and not table.find(list, fName) then
                            table.insert(list, fName)
                        end
                    end
                end)
            end
        end
    end
    return #list > 0 and list or { "default" }
end

function SaveManager:GetAutoloadName()
    self:BuildFolderTree()
    local paths = { self.Folder .. "/settings/autoload.txt", self.Folder .. "/autoload.txt" }
    for _, p in ipairs(paths) do
        if isfile and isfile(p) and readfile then
            local name = readfile(p):gsub("%s+", "")
            if #name > 0 then return name end
        end
    end
    return nil
end

function SaveManager:SetAutoload(name)
    if not name or name == "" then return false end
    self:BuildFolderTree()
    -- Ensure file exists by saving current config if needed
    local path = self.Folder .. "/settings/" .. name .. ".json"
    if not (isfile and isfile(path)) then
        self:Save(name)
    end
    if writefile then
        writefile(self.Folder .. "/settings/autoload.txt", name)
        if self.AutoloadLabel and self.AutoloadLabel.SetText then
            self.AutoloadLabel:SetText("Current autoload config: " .. name)
        end
        return true
    end
    return false
end

function SaveManager:ResetAutoload()
    self:BuildFolderTree()
    local paths = { self.Folder .. "/settings/autoload.txt", self.Folder .. "/autoload.txt" }
    for _, p in ipairs(paths) do
        if isfile and isfile(p) and delfile then
            pcall(delfile, p)
        end
    end
    if self.AutoloadLabel and self.AutoloadLabel.SetText then
        self.AutoloadLabel:SetText("Current autoload config: none")
    end
    return true
end

function SaveManager:LoadAutoloadConfig()
    local name = self:GetAutoloadName()
    if name then
        local success, err = self:Load(name)
        if success then
            ZeroLib:Notify({ Title = "Auto Load", Content = string.format("Auto loaded config %q", name), Type = "Success" })
            return true
        else
            -- If missing, auto-save default
            self:Save(name)
            return false
        end
    end
    return false
end

function SaveManager:BuildConfigSection(groupbox)
    self:BuildFolderTree()
    self:SetIgnoreIndexes({ "SaveManager_ConfigName", "SaveManager_ConfigList" })

    groupbox:AddInput("SaveManager_ConfigName", {
        Text = "Config name",
        Placeholder = "my_config",
        Default = "default",
        Callback = function(val) end
    })

    local configDropdown = groupbox:AddDropdown("SaveManager_ConfigList", {
        Text = "Config list",
        Values = self:RefreshConfigList(),
        Default = 1,
        Callback = function(val)
            if ZeroLib.Options.SaveManager_ConfigName and val then
                ZeroLib.Options.SaveManager_ConfigName:SetValue(val)
            end
        end
    })

    groupbox:AddDivider()

    -- 1. Create config button
    groupbox:AddButton({
        Text = "Create config",
        Func = function()
            local name = ZeroLib.Options.SaveManager_ConfigName and ZeroLib.Options.SaveManager_ConfigName.Value or "default"
            if name:gsub("%s+", "") == "" then
                return ZeroLib:Notify({ Title = "Warning", Content = "Invalid config name (empty)", Type = "Warning" })
            end
            local success, err = self:Save(name)
            if success then
                ZeroLib:Notify({ Title = "Config Created", Content = string.format("Created config %q", name), Type = "Success" })
                configDropdown:SetValues(self:RefreshConfigList())
                configDropdown:SetValue(name)
            else
                ZeroLib:Notify({ Title = "Error", Content = "Failed to save config: " .. tostring(err), Type = "Error" })
            end
        end
    })

    -- 2. Load config button
    groupbox:AddButton({
        Text = "Load config",
        Func = function()
            local name = ZeroLib.Options.SaveManager_ConfigList and ZeroLib.Options.SaveManager_ConfigList.Value or (ZeroLib.Options.SaveManager_ConfigName and ZeroLib.Options.SaveManager_ConfigName.Value) or "default"
            local success, err = self:Load(name)
            if success then
                ZeroLib:Notify({ Title = "Config Loaded", Content = string.format("Loaded config %q", name), Type = "Success" })
            else
                ZeroLib:Notify({ Title = "Error", Content = "Failed to load config: " .. tostring(err), Type = "Error" })
            end
        end
    })

    -- 3. Overwrite config button
    groupbox:AddButton({
        Text = "Overwrite config",
        Func = function()
            local name = ZeroLib.Options.SaveManager_ConfigList and ZeroLib.Options.SaveManager_ConfigList.Value or (ZeroLib.Options.SaveManager_ConfigName and ZeroLib.Options.SaveManager_ConfigName.Value) or "default"
            local success, err = self:Save(name)
            if success then
                ZeroLib:Notify({ Title = "Config Overwritten", Content = string.format("Overwrote config %q", name), Type = "Success" })
            else
                ZeroLib:Notify({ Title = "Error", Content = "Failed to overwrite config: " .. tostring(err), Type = "Error" })
            end
        end
    })

    -- 4. Delete config button
    groupbox:AddButton({
        Text = "Delete config",
        Func = function()
            local name = ZeroLib.Options.SaveManager_ConfigList and ZeroLib.Options.SaveManager_ConfigList.Value or (ZeroLib.Options.SaveManager_ConfigName and ZeroLib.Options.SaveManager_ConfigName.Value)
            if name then
                local success = self:Delete(name)
                if success then
                    ZeroLib:Notify({ Title = "Config Deleted", Content = string.format("Deleted config %q", name), Type = "Info" })
                    configDropdown:SetValues(self:RefreshConfigList())
                end
            end
        end
    })

    -- 5. Refresh list button
    groupbox:AddButton({
        Text = "Refresh list",
        Func = function()
            local fresh = self:RefreshConfigList()
            configDropdown:SetValues(fresh)
            ZeroLib:Notify({ Title = "Refreshed", Content = string.format("Refreshed configs list (%d profiles)", #fresh), Type = "Info" })
        end
    })

    groupbox:AddDivider()

    -- 6. Set as autoload button
    groupbox:AddButton({
        Text = "Set as autoload",
        Func = function()
            local name = ZeroLib.Options.SaveManager_ConfigList and ZeroLib.Options.SaveManager_ConfigList.Value or (ZeroLib.Options.SaveManager_ConfigName and ZeroLib.Options.SaveManager_ConfigName.Value) or "default"
            self:SetAutoload(name)
            ZeroLib:Notify({ Title = "Autoload Set", Content = string.format("Set %q to auto load", name), Type = "Success" })
        end
    })

    -- 7. Reset autoload button
    groupbox:AddButton({
        Text = "Reset autoload",
        Func = function()
            self:ResetAutoload()
            ZeroLib:Notify({ Title = "Autoload Reset", Content = "Reset autoload config", Type = "Info" })
        end
    })

    -- 8. Current autoload config label (exact Linoria layout)
    local autoName = self:GetAutoloadName()
    self.AutoloadLabel = groupbox:AddLabel("Current autoload config: " .. (autoName or "none"))
end

-- Backward compatibility aliases
local ConfigManager = {
    Folder = "arcane_configs",
    Init = function(self) SaveManager:BuildFolderTree() end,
    Save = function(self, name, silent) return SaveManager:Save(name) end,
    Load = function(self, name, silent) return SaveManager:Load(name) end,
    GetConfigs = function(self) return SaveManager:RefreshConfigList() end,
    SetAutoLoad = function(self, name) return SaveManager:SetAutoload(name) end,
    ClearAutoLoad = function(self) return SaveManager:ResetAutoload() end,
    GetAutoLoad = function(self) return SaveManager:GetAutoloadName() end
}

ZeroLib.SaveManager = SaveManager
ZeroLib.ConfigManager = ConfigManager

return ZeroLib

end)()

local Library = ZeroLib
local ThemeManager = nil
local SaveManager = nil

-- =============================================================================
-- SHARED UTILITY FUNCTIONS
-- =============================================================================

-- =============================================================================
-- LOGGING & SILENT CONSOLE MANAGEMENT
-- =============================================================================
local function hubLog(...)
    if _G.ArcaneHubDebug then
        hubLog(...)
    end
end

local function singleClick(button)
    if not button then return end
    if firesignal then
        if button:IsA("TextButton") or button:IsA("ImageButton") then
            firesignal(button.MouseButton1Click)
        end
    end
end

local function safeClick(button)
    if not button then return end
    if firesignal then
        if button:IsA("TextButton") or button:IsA("ImageButton") then
            firesignal(button.MouseButton1Click)
            firesignal(button.Activated)
        end
    end
end

local function pressKey(keyCode)
    task.spawn(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.04)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- =============================================================================
-- ITEM BLACKLIST SYSTEM (VASTIC GRAVE DESERT + FORGOTTEN SANCTUM)
-- =============================================================================
local function isBlacklistedCrylight(obj)
    if not Toggles.BlacklistDesert or not Toggles.BlacklistDesert.Value then return false end
    if not obj:IsA("Model") and not obj:IsA("BasePart") then return false end
    local pos = obj:GetPivot().Position

    -- 1. Desert Grave area (Vastic Grave in Desert @ X: 1423, Y: 617, Z: -4468)
    if (pos - Vector3.new(1423.0, 616.8, -4468.0)).Magnitude < 150 then
        return true
    end

    -- 2. Bounding box of area Forgotten Sanctum / Desert Pyramid
    if pos.X > 8800 and pos.Y > 1000 then
        return true
    end

    -- 3. Distance check for pyramid/sanctum
    if (pos - Vector3.new(10831.2, 1581.7, -3463.6)).Magnitude < 2000 then
        return true
    end
    if (pos - Vector3.new(10450.0, 1570.0, -3480.0)).Magnitude < 2000 then
        return true
    end

    -- 4. test duong dan thu muc cha
    local path = obj:GetFullName():lower()
    if path:find("vastic") or path:find("grave") or path:find("forgotten") or path:find("sanctum") or path:find("pyramid") or path:find("dungeon") or path:find("menu") then
        return true
    end

    return false
end

-- =============================================================================
-- AUTOMATED SERVER HOPPING SYSTEM (JSON PERSISTENT - 20 SERVER CYCLE)
-- =============================================================================
local ServerHopper = {
    isHopping = false,
    visitedFile = "ArcaneHub_VisitedServers.json",
    lastAttemptServer = nil,
}

local function getVisitedServers()
    if not isfile or not readfile or not isfile(ServerHopper.visitedFile) then return {} end
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(ServerHopper.visitedFile))
    end)
    if success and type(data) == "table" then return data end
    return {}
end

local function saveVisitedServer(jobId)
    if not writefile then return end
    local visited = getVisitedServers()
    visited[jobId] = os.time()
    local count = 0
    for _ in pairs(visited) do count = count + 1 end
    if count >= 20 then
        hubLog(string.format("[ServerHop] 🔄 has ghe qua %d server. is reset list de tai su dung server cu!", count))
        visited = { [jobId] = os.time() }
    end
    pcall(function()
        writefile(ServerHopper.visitedFile, HttpService:JSONEncode(visited))
    end)
end

function ServerHopper.hop()
    if ServerHopper.isHopping then return end
    ServerHopper.isHopping = true

    task.spawn(function()
        hubLog("[ServerHop]  Searching for a new server...")
        local placeId = game.PlaceId
        local visited = getVisitedServers()
        local maxBuffer = Options.MaxPlayerBuffer and Options.MaxPlayerBuffer.Value or 2
        local candidates = {}
        local nextCursor = ""

        for _ = 1, 5 do
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s", placeId, nextCursor)
            local success, res = pcall(function() return game:HttpGet(url) end)
            if success and res then
                local data = HttpService:JSONDecode(res)
                if data and data.data then
                    for _, s in ipairs(data.data) do
                        local maxP = s.maxPlayers or 25
                        local playing = s.playing or 0
                        if s.id ~= game.JobId and playing <= (maxP - maxBuffer) and not visited[s.id] then
                            table.insert(candidates, s)
                        end
                    end
                    if #candidates >= 5 then break end
                    nextCursor = data.nextPageCursor or ""
                    if nextCursor == "" then break end
                end
            end
            task.wait(0.5)
        end

        if #candidates > 0 then
            local targetServer = candidates[1]
            hubLog(string.format("[ServerHop]  Teleporting to server: %s (%d/%d players)...", targetServer.id, targetServer.playing, targetServer.maxPlayers))
            ServerHopper.lastAttemptServer = targetServer.id
            saveVisitedServer(targetServer.id)

            if Toggles.AutoLoadOnChangingServer and Toggles.AutoLoadOnChangingServer.Value then
                queueTeleportScript()
            end
            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
            end)

            local timeout = Options.TeleportTimeout and Options.TeleportTimeout.Value or 8
            task.wait(timeout)
            if ServerHopper.isHopping then
                warn("[ServerHop] ⏱️ Teleport timed out. Automatically switching to another server...")
                ServerHopper.isHopping = false
                ServerHopper.hop()
            end
        else
            warn("[ServerHop]  No available servers found. Resetting list and retrying...")
            if writefile then pcall(function() writefile(ServerHopper.visitedFile, "{}") end) end
            ServerHopper.isHopping = false
            task.wait(2)
            ServerHopper.hop()
        end
    end)
end

registerConnection(TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    warn(string.format("[ServerHop]  Teleport failed: %s (%s). Switching server now...", tostring(teleportResult), tostring(errorMessage)))
    if ServerHopper.lastAttemptServer then saveVisitedServer(ServerHopper.lastAttemptServer) end
    ServerHopper.isHopping = false
    task.wait(1)
    ServerHopper.hop()
end))

-- =============================================================================
-- DISCORD WEBHOOK NOTIFIER (MULTI-ITEM ADAPTABLE)
-- =============================================================================
local function sendDiscordReport(harvestedMap, totalHarvested)
    local webhookUrl = Options.DiscordWebhook and Options.DiscordWebhook.Value or ""
    if #webhookUrl < 10 or not HttpRequest then return end

    task.spawn(function()
        local itemListStr = ""
        for name, count in pairs(harvestedMap) do
            itemListStr = itemListStr .. string.format("• **%s**: `x%d`\n", name, count)
        end
        if #itemListStr == 0 then itemListStr = string.format("• **Item**: `x%d`\n", totalHarvested) end

        local payload = {
            username = "Arcane Lineage • Master Hub",
            avatar_url = "https://cdn-icons-png.flaticon.com/512/3655/3655581.png",
            embeds = {{
                title = "🌿 HARVEST REPORT",
                description = string.format("Character has finished harvesting **%d** resources!", totalHarvested),
                color = 0x10B981, -- Emerald Green
                fields = {
                    { name = "📦 Harvested Items", value = itemListStr, inline = false },
                    { name = "👤 Player", value = string.format("||%s|| (||%s||)", LocalPlayer.Name, LocalPlayer.DisplayName), inline = true }
                },
                footer = { text = "Arcane Lineage • Automated Intelligence System" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        pcall(function()
            HttpRequest({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

-- =============================================================================

-- =============================================================================
-- CORRUPT SERVER DETECTOR & HUNTER ENGINE
-- =============================================================================
local CorruptHunter = {
    running = false,
    thread = nil,
}

local function checkIsCorruptServer()
    local isCorrupt = false
    local eventName = "None"

    -- 1. Check CurrentEvent in ReplicatedStorage
    local ev = ReplicatedStorage:FindFirstChild("CurrentEvent")
    if ev and ev:IsA("StringValue") and ev.Value ~= "" and ev.Value ~= "None" then
        isCorrupt = true
        eventName = ev.Value
    end

    -- 2. Check ShadowSky in ReplicatedStorage
    local ss = ReplicatedStorage:FindFirstChild("ShadowSky")
    if ss and ss:IsA("BoolValue") and ss.Value == true then
        isCorrupt = true
        if eventName == "None" then eventName = "Shadow Sky (Corrupted)" end
    end

    -- 3. Check Lighting PostEffects
    local lighting = game:GetService("Lighting")
    if lighting then
        local sc = lighting:FindFirstChild("ShadowCorrupt")
        if sc and sc:IsA("PostEffect") and sc.Enabled then
            isCorrupt = true
            if eventName == "None" then eventName = "Shadow Corrupt Effect" end
        end
        local cs = lighting:FindFirstChild("CursedSky")
        if cs and cs:IsA("PostEffect") and cs.Enabled then
            isCorrupt = true
            if eventName == "None" then eventName = "Cursed Sky Effect" end
        end
        local lss = lighting:FindFirstChild("ShadowSky")
        if lss and lss:IsA("PostEffect") and lss.Enabled then
            isCorrupt = true
            if eventName == "None" then eventName = "Shadow Sky Effect" end
        end
    end

    -- 4. Check for Aberrant mobs in Living
    local living = workspace:FindFirstChild("Living")
    if living then
        for _, m in ipairs(living:GetChildren()) do
            local mn = m.Name:lower()
            if mn:find("aberrant") or mn:find("corrupt") then
                isCorrupt = true
                if eventName == "None" then eventName = "Aberrant Spawn: " .. m.Name end
                break
            end
        end
    end

    return isCorrupt, eventName
end

local function sendCorruptServerWebhook(eventName)
    local webhookUrl = Options.DiscordWebhook and Options.DiscordWebhook.Value or ""
    if #webhookUrl < 10 or not HttpRequest then return end

    task.spawn(function()
        local pingContent = Toggles.CorruptPingRole and Toggles.CorruptPingRole.Value and "@everyone" or nil
        local reg = tostring(ReplicatedStorage:FindFirstChild("Region") and ReplicatedStorage.Region.Value or "Unknown")
        local pCount = #Players:GetPlayers()
        local pMax = Players.MaxPlayers or 20

        local payload = {
            username = "Arcane Lineage • Event Hunter",
            avatar_url = "https://cdn-icons-png.flaticon.com/512/1042/1042340.png",
            content = pingContent,
            embeds = {{
                title = "🔮 CORRUPTED SERVER DETECTED",
                description = string.format("Special Corrupted server event detected: **%s**!", eventName),
                color = 0x8B5CF6, -- Neon Purple
                fields = {
                    { name = "⚡ Event", value = string.format("**%s**", eventName), inline = true },
                    { name = "👥 Players", value = string.format("%d / %d", pCount, pMax), inline = true },
                    { name = "🌍 Region", value = string.format("`%s`", reg), inline = true },
                    { name = "👤 Discovered By", value = string.format("||%s||", LocalPlayer.Name), inline = true }
                },
                footer = { text = "Arcane Lineage • Automated Intelligence System" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        pcall(function()
            HttpRequest({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

function CorruptHunter.start()
    if CorruptHunter.running then return end
    CorruptHunter.running = true
    hubLog("[CorruptHunter]  Starting Corrupted Server hunter cycle...")
    Library:Notify(" Starting Corrupted Server search...", 4)

    CorruptHunter.thread = task.spawn(function()
        task.wait(2.5) -- Wait for ReplicatedStorage and Lighting to load
        while CorruptHunter.running do
            local isCorrupt, eventName = checkIsCorruptServer()
            if isCorrupt then
                hubLog(string.format("[CorruptHunter]  CORRUPT SERVER DETECTED: '%s'!", eventName))
                Library:Notify(string.format(" CORRUPT SERVER DETECTED: %s!", eventName), 10)
                sendCorruptServerWebhook(eventName)
                
                local stay = Toggles.StayInCorruptServer and Toggles.StayInCorruptServer.Value
                if stay ~= false then
                    hubLog("[CorruptHunter]  Stopped Server Hop to remain in Corrupted Server!")
                    CorruptHunter.running = false
                    if Toggles.HuntCorruptServer then
                        Toggles.HuntCorruptServer:SetValue(false)
                    end
                    break
                end
            else
                hubLog("[CorruptHunter] ⏳ Current server is not a Corrupted Server. is preparing switch server tiep theo...")
                Library:Notify("⏳ Not a Corrupted Server. Server hopping...", 3)
                task.wait(1.5)
                ServerHopper.hop()
                task.wait(10) -- Wait for teleport
            end
            task.wait(4)
        end
    end)
end

function CorruptHunter.stop()
    CorruptHunter.running = false
    if CorruptHunter.thread then
        task.cancel(CorruptHunter.thread)
        CorruptHunter.thread = nil
    end
end

-- AUTO START & MENU-SKIP
-- =============================================================================
local function handleAutoStart()
    hubLog("[AutoStart] Checking Skip Intro and Start Menu...")
    local startTime = os.clock()
    while os.clock() - startTime < 15 do
        if Toggles.AutoSkipIntro and Toggles.AutoSkipIntro.Value and PlayerGui then
            for _, desc in ipairs(PlayerGui:GetDescendants()) do
                if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                    local name = desc.Name:lower()
                    local text = desc:IsA("TextButton") and desc.Text:lower() or ""
                    if name:find("skip") or text:find("skip") then
                        safeClick(desc)
                    end
                end
            end
        end

        local mainMenu = PlayerGui and PlayerGui:FindFirstChild("MainMenu")
        local mainMenuUI = PlayerGui and PlayerGui:FindFirstChild("MainMenuUI")

        if mainMenu and mainMenu.Enabled then
            local playBtn = mainMenu:FindFirstChild("Play", true)
            if playBtn then safeClick(playBtn) end
        end

        if mainMenuUI and mainMenuUI.Enabled then
            local yesBtn = mainMenuUI:FindFirstChild("Yes", true) and mainMenuUI.Yes:FindFirstChildWhichIsA("TextButton", true)
            if yesBtn then safeClick(yesBtn) end
        end

        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hud = PlayerGui and PlayerGui:FindFirstChild("HUD")
        if root and hud and hud.Enabled then
            hubLog("[AutoStart]  Entered game world successfully!")
            break
        end

        task.wait(0.4)
    end
end

-- =============================================================================
-- SMOOTH SKY-TWEEN WITH ANTI-JITTER BODYVELOCITY & NOCLIP
-- =============================================================================
local FlightController = {
    active = false,
    noclipConn = nil,
    currentTween = nil,
}

local function enableFlightState()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    if hum then
        hum.PlatformStand = true
        hum.AutoRotate = false
    end

    if not FlightController.noclipConn then
        FlightController.noclipConn = registerConnection(RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, part in ipairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                local r = c:FindFirstChild("HumanoidRootPart")
                if r then
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end))
    end
end

local function disableFlightState()
    if FlightController.noclipConn then
        FlightController.noclipConn:Disconnect()
        FlightController.noclipConn = nil
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum.AutoRotate = true
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function smoothTweenTo(targetCFrame, speed, cancelCheckFn, keepFlightState)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return false end

    enableFlightState()

    local distance = (root.Position - targetCFrame.Position).Magnitude
    local duration = math.max(0.1, distance / speed)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, { CFrame = targetCFrame })
    FlightController.currentTween = tween
    tween:Play()

    local completed = false
    task.spawn(function()
        tween.Completed:Wait()
        completed = true
    end)

    local startTime = os.clock()
    while not completed and (os.clock() - startTime < duration + 2) do
        if cancelCheckFn and not cancelCheckFn() then
            pcall(function() tween:Cancel() end)
            FlightController.currentTween = nil
            disableFlightState()
            return false
        end
        task.wait(0.04)
    end

    FlightController.currentTween = nil
    if not keepFlightState then
        disableFlightState()
    end
    return true
end

-- =============================================================================
-- AUTO FARM INGREDIENTS (MULTI-ITEM SCAN + SKY TWEEN 1500 Y)
-- =============================================================================
local Farmer = {
    running = false,
}

local function getAccurateGroundPosition(targetPos)
    local char = LocalPlayer.Character
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = char and { char } or {}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    -- 1. Uu tien quet cuc bo tu targetPos.Y + 25 xuong -100 studs (bat floor cave / indoors / mat dat nearby)
    local localOrigin = Vector3.new(targetPos.X, targetPos.Y + 25, targetPos.Z)
    local localHit = workspace:Raycast(localOrigin, Vector3.new(0, -120, 0), rayParams)
    if localHit then
        return Vector3.new(targetPos.X, localHit.Position.Y + 3.0, targetPos.Z)
    end

    -- 2. Scan from high altitude down for outdoor targets
    local highOrigin = Vector3.new(targetPos.X, targetPos.Y + 250, targetPos.Z)
    local highHit = workspace:Raycast(highOrigin, Vector3.new(0, -500, 0), rayParams)
    if highHit then
        return Vector3.new(targetPos.X, highHit.Position.Y + 3.0, targetPos.Z)
    end

    -- 3. Safe fallback if chunk is not yet streamed
    return Vector3.new(targetPos.X, targetPos.Y + 3.0, targetPos.Z)
end

local function calculateSafeStandPosition(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local curPos = root and root.Position or (targetPos + Vector3.new(0, 0, 4))
    
    local flatDir = Vector3.new(curPos.X - targetPos.X, 0, curPos.Z - targetPos.Z)
    if flatDir.Magnitude < 0.1 then flatDir = Vector3.new(0, 0, 3.5) end
    
    -- Position offset 3.5 studs from ore center and snap to ground
    local rawStandPos = targetPos + flatDir.Unit * 3.5
    local standPos = getAccurateGroundPosition(rawStandPos)
    return standPos
end

local function flyToItem(targetPosition, cancelCheckFn)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local cancelFn = cancelCheckFn or function() return Farmer.running or Miner.running end
    if not cancelFn() then return false end

    local currentPos = root.Position
    local distance = (currentPos - targetPosition).Magnitude
    local safeArrivalPos = calculateSafeStandPosition(targetPosition)

    -- If already close to ore/item (< 12 studs): face target directly
    if distance < 12 then
        root.CFrame = CFrame.lookAt(safeArrivalPos, Vector3.new(targetPosition.X, safeArrivalPos.Y, targetPosition.Z))
        return true
    end

    -- 3-Phase Safe Sky-Tween flight through high altitude
    enableFlightState()

    local cruiseSpeed = Options.CruiseSpeed and Options.CruiseSpeed.Value or 180
    local skyHeight = Options.SkyHeight and Options.SkyHeight.Value or 1500
    local ascendSpeed = Options.AscendSpeed and Options.AscendSpeed.Value or 150
    local descendSpeed = Options.DescendSpeed and Options.DescendSpeed.Value or 150

    local skyY = math.max(skyHeight, currentPos.Y + 200, targetPosition.Y + 200)

    -- Phase 1: Fly straight up to high altitude
    local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), ascendSpeed, cancelFn, true)
    if not s1 or not cancelFn() then
        disableFlightState()
        return false
    end

    -- Phase 2: Glide horizontally across airspace (maintain FlightState)
    local s2 = smoothTweenTo(CFrame.new(safeArrivalPos.X, skyY, safeArrivalPos.Z), cruiseSpeed, cancelFn, true)
    if not s2 or not cancelFn() then
        disableFlightState()
        return false
    end

    -- Phase 3: Descend safely onto stand position near ore / item
    local s3 = smoothTweenTo(CFrame.lookAt(safeArrivalPos, Vector3.new(targetPosition.X, safeArrivalPos.Y, targetPosition.Z)), descendSpeed, cancelFn, false)
    
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    return s3
end

local function harvestItem(model)
    if not model or not model.Parent then return false end
    local startTime = os.clock()
    local timeout = Options.PickupTimeout and Options.PickupTimeout.Value or 5

    while HubState.running and model and model.Parent and (os.clock() - startTime < timeout) and Farmer.running do
        local cd = model:FindFirstChildWhichIsA("ClickDetector", true)
        if cd and fireclickdetector then fireclickdetector(cd) end
        task.wait(0.2)
    end
    return (model.Parent == nil)
end

function Farmer.runCycle()
    if Farmer.running then return end
    Farmer.running = true

    task.spawn(function()
        hubLog("[AutoFarm]  [STEP 1]: Scanning selected ingredients directly at Menu...")
        task.wait(2.5)

        local selectedMap = (Options.FarmItemsWhitelist and Options.FarmItemsWhitelist.Value) or { ["Crylight"] = true }

        local harvestList = {}
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc.Parent and selectedMap[desc.Name] and not isBlacklistedCrylight(desc) then
                table.insert(harvestList, { instance = desc, name = desc.Name })
            end
        end

        hubLog(string.format("[AutoFarm]  Ket qua test tai Menu: Tim thay %d nguyen lieu hop le.", #harvestList))

        if #harvestList > 0 then
            hubLog("[AutoFarm]  detected nguyen lieu muc tieu! is auto bam Play de vao game thu hoach...")
            handleAutoStart()

            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local curPos = root and root.Position or Vector3.zero

            -- Sap xep Nearest Neighbor de gom cum lum clean cac item nearby nhau before
            local sortedHarvestList = {}
            local remainingList = {}
            for _, itm in ipairs(harvestList) do table.insert(remainingList, itm) end

            while #remainingList > 0 do
                local nearestIdx = 1
                local nearestDist = math.huge
                for idx, itmData in ipairs(remainingList) do
                    local itmInst = itmData.instance
                    if itmInst and itmInst.Parent then
                        local d = (curPos - itmInst:GetPivot().Position).Magnitude
                        if d < nearestDist then
                            nearestDist = d
                            nearestIdx = idx
                        end
                    end
                end
                local bestItem = table.remove(remainingList, nearestIdx)
                table.insert(sortedHarvestList, bestItem)
                if bestItem.instance and bestItem.instance.Parent then
                    curPos = bestItem.instance:GetPivot().Position
                end
            end
            harvestList = sortedHarvestList

            local harvestedCounts = {}
            local totalHarvested = 0
            for i, itemData in ipairs(harvestList) do
                if not Farmer.running then break end
                local item = itemData.instance
                local itemName = itemData.name
                if item and item.Parent then
                    local targetPos = item:GetPivot().Position
                    hubLog(string.format("[AutoFarm]  [%d/%d] Harvesting %s at (%.1f, %.1f, %.1f)...", i, #harvestList, itemName, targetPos.X, targetPos.Y, targetPos.Z))

                    local flew = flyToItem(targetPos, function() return Farmer.running end)
                    if flew and item and item.Parent then
                        local picked = harvestItem(item)
                        if picked then
                            totalHarvested = totalHarvested + 1
                            harvestedCounts[itemName] = (harvestedCounts[itemName] or 0) + 1
                        end
                        task.wait(0.3)
                    end
                end
            end

            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and Farmer.running then
                local skyHeight = Options.SkyHeight and Options.SkyHeight.Value or 1500
                local ascendSpeed = Options.AscendSpeed and Options.AscendSpeed.Value or 150
                smoothTweenTo(CFrame.new(root.Position.X, skyHeight, root.Position.Z), ascendSpeed, function() return Farmer.running end)
            end

            if totalHarvested > 0 and Toggles.NotifyOnHarvest and Toggles.NotifyOnHarvest.Value then
                sendDiscordReport(harvestedCounts, totalHarvested)
            end
        else
            hubLog("[AutoFarm]  Server not co nguyen lieu muc tieu! is Server Hop now tu Main Menu...")
        end

        disableFlightState()

        if Toggles.AutoServerHop and Toggles.AutoServerHop.Value and Farmer.running then
            task.wait(1)
            ServerHopper.hop()
        end
    end)
end

function Farmer.stop()
    Farmer.running = false
    if FlightController.currentTween then
        FlightController.currentTween:Cancel()
        FlightController.currentTween = nil
    end
    disableFlightState()
    hubLog("[AutoFarm] Auto Farm stopped.")
end

-- =============================================================================
-- COMBAT STATE DETECTOR
-- =============================================================================
local function isInCombat()
    local char = LocalPlayer.Character
    if not char then return false end

    -- 1. Server attribute / child in character (100% accurate ground truth)
    if char:FindFirstChild("FightInProgress") then
        return true
    end

    -- 2. Check ReplicatedStorage.Fights
    local RS = game:GetService("ReplicatedStorage")
    local rsFights = RS:FindFirstChild("Fights")
    if rsFights then
        local myName = LocalPlayer.Name
        local charName = char.Name
        for _, fight in ipairs(rsFights:GetChildren()) do
            local t1 = fight:FindFirstChild("Team1")
            local t2 = fight:FindFirstChild("Team2")
            if (t1 and (t1:FindFirstChild(myName) or t1:FindFirstChild(charName))) or
               (t2 and (t2:FindFirstChild(myName) or t2:FindFirstChild(charName))) then
                return true
            end
        end
    end

    -- 3. Check active Combat UI components in PlayerGui
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if combatGui and combatGui.Enabled then
        local actionBG = combatGui:FindFirstChild("ActionBG")
        local deciding = combatGui:FindFirstChild("Deciding")
        local dodge = combatGui:FindFirstChild("DodgeQTE")
        local atkInd = combatGui:FindFirstChild("AttackIndicator")
        if (actionBG and actionBG.Visible) or 
           (deciding and deciding.Visible) or 
           (dodge and dodge.Visible) or 
           (atkInd and atkInd.Visible and atkInd.ImageTransparency < 0.9) then
            return true
        end
    end

    return false
end


-- =============================================================================
-- AUTO FARM LEVEL & COMBAT HELPER (LEVEL 1-20 UNDERGROUND & LEVEL 20-50 ENGINE)
-- =============================================================================
local LevelFarmer = {
    running = false,
    noclipConn = nil,
    undergroundPlatform = nil,
    farmSpotLv1_30 = Vector3.new(5131.5, 662.4, -3947.6),   -- The Crossing Safe Block (Lv 1 - 30)
    farmSpotLv30_50 = Vector3.new(3067.7, 623.9, -3832.3),  -- Desert Safe Block (Lv 30 - 50)
    farmSpots = {
        ["The Crossing (Caldera / Starter Mobs)"] = Vector3.new(5986.4, 616.8, -4260.2),
        ["Deeproot Canopy (Westwood / Forest Mobs)"] = Vector3.new(7595.9, 599.3, -3361.3),
        ["Waving Sands (Desert / Sand Mobs)"] = Vector3.new(3062.7, 595.1, -4566.3),
        ["Withered Grove (Cursed Grove / Undead Mobs)"] = Vector3.new(6075.8, 639.3, -2013.1),
        ["Mount Thul (Snow Mountain / Frost Mobs)"] = Vector3.new(572.3, 559.5, -4156.2),
    },
    essenceBeforeCombat = -1,
    zeroGainFightCount = 0,
    wasInCombat = false,
    lastMeditateTime = 0,
    aretimPos = Vector3.new(789.8, 238.0, 2120.8),
}

local function ensureUndergroundPlatform(targetPos)
    local plat = workspace:FindFirstChild("ArcaneFarmPlatform")
    if not plat then
        plat = Instance.new("Part")
        plat.Name = "ArcaneFarmPlatform"
        plat.Size = Vector3.new(20, 2, 20)
        plat.Anchored = true
        plat.CanCollide = true
        plat.Transparency = 0.5
        plat.Material = Enum.Material.SmoothPlastic
        plat.Color = Color3.fromRGB(35, 35, 35)
        plat.Parent = workspace
    end
    plat.Position = targetPos
    LevelFarmer.undergroundPlatform = plat
    return plat
end

local function removeUndergroundPlatform()
    local plat = workspace:FindFirstChild("ArcaneFarmPlatform")
    if plat then plat:Destroy() end
    LevelFarmer.undergroundPlatform = nil
end

local function enableLevelFarmerNoclip()
    if LevelFarmer.noclipConn then return end
    LevelFarmer.noclipConn = registerConnection(RunService.Stepped:Connect(function()
        if not LevelFarmer.running then return end
        local c = LocalPlayer.Character
        if c and not isInCombat() then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end))
end

local function disableLevelFarmerNoclip()
    if LevelFarmer.noclipConn then
        LevelFarmer.noclipConn:Disconnect()
        LevelFarmer.noclipConn = nil
    end
end

local function getCurrentLevel()
    local pgui = PlayerGui
    local hud = pgui and pgui:FindFirstChild("HUD")
    if hud then
        local lvlObj = hud:FindFirstChild("CharacterLevel", true)
        local lvlText = lvlObj and lvlObj:FindFirstChild("Level")
        if lvlText and lvlText:IsA("TextLabel") then
            local num = tonumber(lvlText.Text:match("%d+"))
            if num then return num end
        end
    end
    local char = LocalPlayer.Character
    local lvlVal = char and (char:FindFirstChild("Level") or (char:FindFirstChild("Status") and char.Status:FindFirstChild("Level")))
    if lvlVal and lvlVal:IsA("ValueBase") then
        return tonumber(lvlVal.Value) or 1
    end
    return 1
end

local function getCurrentEssence()
    local pgui = PlayerGui
    local hud = pgui and pgui:FindFirstChild("HUD")
    if hud then
        local crystals = hud:FindFirstChild("Crystals", true)
        local amountObj = crystals and crystals:FindFirstChild("Amount")
        if amountObj and amountObj:IsA("TextLabel") then
            local num = tonumber(amountObj.Text:match("%d+"))
            if num then return num end
        end
    end
    return 0
end

local function getActiveFarmSpot()
    local mode = (Options and Options.FarmLevelMode and Options.FarmLevelMode.Value) or "Auto (Detect Level 1 - 50)"
    
    if mode == "Level 1 - 30 (Underground)" then
        return LevelFarmer.farmSpotLv1_30, "Level 1 - 30 (Underground)"
    elseif mode == "Level 30 - 50 (Desert Block)" then
        return LevelFarmer.farmSpotLv30_50, "Level 30 - 50 (Desert Block)"
    elseif mode:find("Auto") then
        -- Auto detect player level (Lv < 30 fly ve bai underground Caldera, Lv >= 30 fly ve khoi safely Desert)
        local currentLvl = getCurrentLevel()
        if currentLvl >= 30 then
            return LevelFarmer.farmSpotLv30_50, string.format("Auto Detect (Lv %d -> Desert Block 30-50)", currentLvl)
        else
            return LevelFarmer.farmSpotLv1_30, string.format("Auto Detect (Lv %d -> Underground 1-30)", currentLvl)
        end
    elseif LevelFarmer.farmSpots[mode] then
        return LevelFarmer.farmSpots[mode], mode
    else
        return LevelFarmer.farmSpotLv1_30, "Level 1 - 30 (Underground)"
    end
end

local function flyToFarmSpot(targetSpot)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then
        warn("[AutoFarmLevel]  HumanoidRootPart or Humanoid not found!")
        return false
    end

    local currentPos = root.Position
    local targetCF = CFrame.new(targetSpot.X, targetSpot.Y + 4.0, targetSpot.Z)
    local distance = (currentPos - targetCF.Position).Magnitude

    if distance <= 4 then
        root.CFrame = targetCF
        ensureUndergroundPlatform(targetSpot)
        return true
    end

    hubLog(string.format("[AutoFarmLevel]  Starting Safe Sky-Tween flight to farm spot at (%.1f, %.1f, %.1f) - distance: %.1f studs...", targetCF.X, targetCF.Y, targetCF.Z, distance))

    ensureUndergroundPlatform(targetSpot)
    enableLevelFarmerNoclip()

    local skyHeight = 1500
    local skyY = math.max(skyHeight, currentPos.Y + 200, targetSpot.Y + 200)

    -- Phase 1: Fly straight up to high airspace
    local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), 200, function() return LevelFarmer.running end)
    if not s1 or not LevelFarmer.running then return false end

    -- Phase 2: Fly horizontally across airspace to farm spot
    local s2 = smoothTweenTo(CFrame.new(targetSpot.X, skyY, targetSpot.Z), 240, function() return LevelFarmer.running end)
    if not s2 or not LevelFarmer.running then return false end

    -- Phase 3: landed straight dung xuong bai farm (xuyen khoi / xuyen dat safely)
    local s3 = smoothTweenTo(targetCF, 180, function() return LevelFarmer.running end)
    if s3 then
        root.CFrame = targetCF
        hubLog("[AutoFarmLevel]  Landed safely at farm spot!")
    end
    return s3
end

local function safeClickButton(btn)
    if not btn then return false end
    local clicked = false

    if getconnections then
        local conns = getconnections(btn.MouseButton1Click)
        if conns and #conns > 0 then
            for _, c in ipairs(conns) do
                if c.Function then
                    task.spawn(c.Function)
                    clicked = true
                elseif c.Fire then
                    pcall(function() c:Fire() end)
                    clicked = true
                end
            end
            if clicked then return true end
        end
    end

    if firesignal then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        return true
    end

    return false
end

local function getCurrentStats()
    local stats = { Strength = 0, Endurance = 0, Speed = 0, Arcane = 0, Luck = 0 }
    local pgui = PlayerGui
    local sm = pgui and pgui:FindFirstChild("StatMenu")
    if sm then
        local attrs = sm:FindFirstChild("Attributes", true)
        if attrs then
            for statName, _ in pairs(stats) do
                local frame = attrs:FindFirstChild(statName)
                local valObj = frame and frame:FindFirstChild("StatValue")
                if valObj and valObj:IsA("TextLabel") then
                    local num = tonumber(valObj.Text:match("^%s*(%d+)"))
                    if num then stats[statName] = num end
                end
            end
        end
    end
    return stats
end

-- =============================================================================
-- USER STATS ALLOCATION CACHE SYSTEM (PERSISTENT BY ROBLOX USERNAME)
-- =============================================================================
local STATS_CACHE_FILE = "Arcane_Hub_StatsCache.json"
local statsCacheMemory = {}

local function loadStatsCache()
    if readfile and isfile and isfile(STATS_CACHE_FILE) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(STATS_CACHE_FILE))
        end)
        if success and type(result) == "table" then
            statsCacheMemory = result
            return result
        end
    end
    return statsCacheMemory
end

local function saveStatsCache(cache)
    statsCacheMemory = cache
    if writefile then
        pcall(function()
            writefile(STATS_CACHE_FILE, HttpService:JSONEncode(cache))
        end)
    end
end

local function getUserStatsCache()
    local username = LocalPlayer.Name
    local cache = loadStatsCache()
    if not cache[username] then
        cache[username] = {
            Strength = 0,
            Endurance = 0,
            Speed = 0,
            Arcane = 0,
            Luck = 0,
        }
        saveStatsCache(cache)
    end
    return cache[username], cache, username
end

local function clearUserStatsCache()
    local userStats, allCache, username = getUserStatsCache()
    allCache[username] = {
        Strength = 0,
        Endurance = 0,
        Speed = 0,
        Arcane = 0,
        Luck = 0,
    }
    saveStatsCache(allCache)
    hubLog(string.format("[AutoStats]  has clear clean cache points stats cua tai khoan '%s'!", username))
    Library:Notify(string.format(" Cleared stats cache for '%s'!", username), 4)
end

local function allocateStats()
    if not (Toggles.AutoAllocateStats and Toggles.AutoAllocateStats.Value) then return end

    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    local lvlUpGui = pgui:FindFirstChild("LevelUp")
    
    -- 1. Wait for LevelUp UI to appear and enable (server game co do tre ~2.5s khi open dialogue Aretim)
    local waitStart = os.clock()
    while os.clock() - waitStart < 8.0 do
        lvlUpGui = pgui:FindFirstChild("LevelUp")
        if lvlUpGui and lvlUpGui.Enabled and lvlUpGui:FindFirstChild("Container") then
            break
        end
        task.wait(0.3)
    end

    if not (lvlUpGui and lvlUpGui.Enabled and lvlUpGui:FindFirstChild("Container")) then
        hubLog("[AutoFarmLevel]  LevelUp UI not detected.")
        return
    end

    local container = lvlUpGui.Container
    local header = container:FindFirstChild("Header")
    local pointsLabel = header and header:FindFirstChild("PointsLeft")
    local pointsText = pointsLabel and pointsLabel.Text or ""
    local availPoints = tonumber(pointsText:match("(%d+)")) or 0

    local userStats, allCache, username = getUserStatsCache()
    hubLog(string.format("[AutoFarmLevel]  [LevelUp GUI] Tai khoan '%s' co %d Stat Points not yet allocated.", username, availPoints))

    if availPoints <= 0 then
        local finishBtn = lvlUpGui:FindFirstChild("Finish")
        if finishBtn then
            if getconnections then
                for _, c in ipairs(getconnections(finishBtn.MouseButton1Click)) do
                    if c.Function then c.Function() break elseif c.Fire then c:Fire() break end
                end
            elseif firesignal then
                firesignal(finishBtn.MouseButton1Click)
            end
        end
        return
    end

    -- 2. Read target slider configuration
    local strSlider = Options.TargetStrength and Options.TargetStrength.Value or 20
    local arcSlider = Options.TargetArcane and Options.TargetArcane.Value or 0
    local endSlider = Options.TargetEndurance and Options.TargetEndurance.Value or 20
    local spdSlider = Options.TargetSpeed and Options.TargetSpeed.Value or 10
    local lckSlider = Options.TargetLuck and Options.TargetLuck.Value or 10

    -- Target manual stat investment = max(0, slider - 10) due to +10 free milestone points do
    local strMaxAdd = math.max(0, strSlider - 10)
    local arcMaxAdd = math.max(0, arcSlider - 10)
    local endMaxAdd = math.max(0, endSlider - 10)
    local spdMaxAdd = math.max(0, spdSlider - 10)
    local lckMaxAdd = math.max(0, lckSlider - 10)

    -- Remaining points needed compared to account allocated cache
    local strNeeded = math.max(0, strMaxAdd - (userStats.Strength or 0))
    local arcNeeded = math.max(0, arcMaxAdd - (userStats.Arcane or 0))
    local endNeeded = math.max(0, endMaxAdd - (userStats.Endurance or 0))
    local spdNeeded = math.max(0, spdMaxAdd - (userStats.Speed or 0))
    local lckNeeded = math.max(0, lckMaxAdd - (userStats.Luck or 0))

    hubLog(string.format("[AutoStats]  Cache hien tai cua '%s': Str:%d/%d, End:%d/%d, Spd:%d/%d, Arc:%d/%d, Lck:%d/%d",
        username,
        userStats.Strength or 0, strMaxAdd,
        userStats.Endurance or 0, endMaxAdd,
        userStats.Speed or 0, spdMaxAdd,
        userStats.Arcane or 0, arcMaxAdd,
        userStats.Luck or 0, lckMaxAdd
    ))

    -- Allocate points
    local strAdd = math.min(availPoints, strNeeded)
    availPoints = availPoints - strAdd

    local endAdd = math.min(availPoints, endNeeded)
    availPoints = availPoints - endAdd

    local spdAdd = math.min(availPoints, spdNeeded)
    availPoints = availPoints - spdAdd

    local arcAdd = math.min(availPoints, arcNeeded)
    availPoints = availPoints - arcAdd

    local lckAdd = math.min(availPoints, lckNeeded)
    availPoints = availPoints - lckAdd

    -- If points remain (Game requires 100% distribution before Finish):
    -- Automatically allocate into highest target stat slider
    if availPoints > 0 then
        if strSlider >= endSlider and strSlider >= arcSlider and strSlider > 0 then
            strAdd = strAdd + availPoints
        elseif endSlider >= strSlider and endSlider >= arcSlider and endSlider > 0 then
            endAdd = endAdd + availPoints
        elseif arcSlider >= strSlider and arcSlider >= endSlider and arcSlider > 0 then
            arcAdd = arcAdd + availPoints
        elseif spdSlider >= lckSlider and spdSlider > 0 then
            spdAdd = spdAdd + availPoints
        else
            lckAdd = lckAdd + availPoints
        end
        availPoints = 0
    end

    -- 3. Click stat upgrade button in PlayerGui.LevelUp
    local buttonsFrame = container:FindFirstChild("Body") and container.Body:FindFirstChild("Buttons")
    local function getStatUpButton(statName)
        if not buttonsFrame then return nil end
        local statFrame = buttonsFrame:FindFirstChild(statName)
        local frame = statFrame and statFrame:FindFirstChild("Frame")
        return frame and frame:FindFirstChild(statName .. "Up")
    end

    local function clickLevelUpButton(statName, count)
        if count <= 0 then return end
        local upBtn = getStatUpButton(statName)
        if not upBtn then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("ImageButton") and d.Name == (statName .. "Up") then
                    upBtn = d
                    break
                end
            end
        end
        if not upBtn then
            warn("[AutoStats]  Button not found:", statName .. "Up")
            return
        end

        local toAllocBox = container:FindFirstChild("ToAllocate", true)
        if toAllocBox and toAllocBox:IsA("TextBox") then
            toAllocBox.Text = tostring(count)
            task.wait(0.08)
            if getconnections then
                for _, c in ipairs(getconnections(upBtn.MouseButton1Click)) do
                    if c.Function then c.Function() break
                    elseif c.Fire then c:Fire() break end
                end
            elseif firesignal then
                firesignal(upBtn.MouseButton1Click)
            end
            task.wait(0.1)
        else
            for _ = 1, count do
                if getconnections then
                    for _, c in ipairs(getconnections(upBtn.MouseButton1Click)) do
                        if c.Function then c.Function() break
                        elseif c.Fire then c:Fire() break end
                    end
                elseif firesignal then
                    firesignal(upBtn.MouseButton1Click)
                end
                task.wait(0.05)
            end
        end
    end

    if strAdd > 0 then clickLevelUpButton("Strength", strAdd) end
    if endAdd > 0 then clickLevelUpButton("Endurance", endAdd) end
    if spdAdd > 0 then clickLevelUpButton("Speed", spdAdd) end
    if arcAdd > 0 then clickLevelUpButton("Arcane", arcAdd) end
    if lckAdd > 0 then clickLevelUpButton("Luck", lckAdd) end

    -- Update permanent cache for account
    userStats.Strength = (userStats.Strength or 0) + strAdd
    userStats.Endurance = (userStats.Endurance or 0) + endAdd
    userStats.Speed = (userStats.Speed or 0) + spdAdd
    userStats.Arcane = (userStats.Arcane or 0) + arcAdd
    userStats.Luck = (userStats.Luck or 0) + lckAdd
    saveStatsCache(allCache)

    task.wait(0.4)
    local finishBtn = lvlUpGui:FindFirstChild("Finish")
    if finishBtn then
        if getconnections then
            for _, c in ipairs(getconnections(finishBtn.MouseButton1Click)) do
                if c.Function then c.Function() break
                elseif c.Fire then c:Fire() break end
            end
        elseif firesignal then
            firesignal(finishBtn.MouseButton1Click)
        end
        hubLog(string.format("[AutoFarmLevel]  has allocated Stats cho '%s': Str+%d (total %d/%d), End+%d (total %d/%d), Spd+%d (total %d/%d), Arc+%d (total %d/%d), Luck+%d (total %d/%d) va bam Finish!", 
            username,
            strAdd, userStats.Strength, strMaxAdd,
            endAdd, userStats.Endurance, endMaxAdd,
            spdAdd, userStats.Speed, spdMaxAdd,
            arcAdd, userStats.Arcane, arcMaxAdd,
            lckAdd, userStats.Luck, lckMaxAdd
        ))
    end

    -- Wait for LevelUp GUI to close before continuing
    local closeWait = os.clock()
    while lvlUpGui.Enabled and os.clock() - closeWait < 4.0 do
        task.wait(0.3)
    end
end

local function isInSoulCorridor()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return (root.Position - LevelFarmer.aretimPos).Magnitude < 400
end

local function simulateKeyPress(keyCode, holdTime)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(holdTime or 0.15)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function humanoidMeditateAndLevelUp()
    local now = os.clock()
    if now - LevelFarmer.lastMeditateTime < 5 then
        return false
    end
    LevelFarmer.lastMeditateTime = now

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return false end

    -- 1. Find nearest Meditation Mat
    local mats = workspace:FindFirstChild("Mats")
    local nearestMat = nil
    local nearestDist = math.huge
    if mats then
        for _, mat in ipairs(mats:GetChildren()) do
            local pos = mat:GetPivot().Position
            local d = (pos - root.Position).Magnitude
            if d < nearestDist then
                nearestDist = d
                nearestMat = mat
            end
        end
    end

    if not nearestMat then
        hubLog("[AutoFarmLevel]  MeditationMat not found.")
        return false
    end

    local matPos = nearestMat:GetPivot().Position
    local targetCF = CFrame.new(matPos.X, matPos.Y + 1.2, matPos.Z)

    hubLog(string.format("[AutoFarmLevel]  Flying to Meditation Mat at (%.1f, %.1f, %.1f)...", matPos.X, matPos.Y, matPos.Z))

    hum.PlatformStand = true
    local noclipConn = RunService.Stepped:Connect(function()
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then r.AssemblyLinearVelocity = Vector3.zero end
        end
    end)

    local distance = (root.Position - targetCF.Position).Magnitude
    local speed = 180
    local duration = math.max(0.1, distance / speed)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCF })
    tween:Play()
    tween.Completed:Wait()

    noclipConn:Disconnect()
    hum.PlatformStand = false
    hum:ChangeState(Enum.HumanoidStateType.Landed)
    hum:ChangeState(Enum.HumanoidStateType.Running)
    root.CFrame = targetCF
    task.wait(0.8)

    -- 2. Press M key via VirtualInputManager (single trigger)
    hubLog("[AutoFarmLevel]  Pressing M key to meditate into Soul Corridor...")
    simulateKeyPress(Enum.KeyCode.M, 0.12)

    -- Monitor scene transition (Wait up to 8.5s for meditation animation & screen fade)
    local waited = 0
    while not isInSoulCorridor() and waited < 8.5 do
        task.wait(0.5)
        waited = waited + 0.5
    end

    if isInSoulCorridor() then
        hubLog("[AutoFarmLevel]  Entered Soul Corridor successfully!")
        task.wait(1.0)

        -- 3. Travel to NPC Aretim (Refresh character reference in Soul Corridor)
        local scChar = LocalPlayer.Character
        local scRoot = scChar and scChar:FindFirstChild("HumanoidRootPart")
        local scHum = scChar and scChar:FindFirstChildOfClass("Humanoid")
        if not scRoot or not scHum then return false end

        local aretimModel = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Aretim")
        local aretimPos = aretimModel and aretimModel:GetPivot().Position or LevelFarmer.aretimPos
        local aretimTargetCF = CFrame.lookAt(Vector3.new(aretimPos.X, aretimPos.Y + 1.5, aretimPos.Z - 4.0), aretimPos)

        hubLog(string.format("[AutoFarmLevel] 🚶 Flying to NPC Aretim at (%.1f, %.1f, %.1f)...", aretimPos.X, aretimPos.Y, aretimPos.Z))
        
        scHum.PlatformStand = true
        local noclipCorridor = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
                local r = c:FindFirstChild("HumanoidRootPart")
                if r then r.AssemblyLinearVelocity = Vector3.zero end
            end
        end)

        local dCorridor = (scRoot.Position - aretimTargetCF.Position).Magnitude
        local tCorridor = TweenService:Create(scRoot, TweenInfo.new(math.max(0.1, dCorridor / 140), Enum.EasingStyle.Linear), { CFrame = aretimTargetCF })
        tCorridor:Play()
        tCorridor.Completed:Wait()

        noclipCorridor:Disconnect()
        scHum.PlatformStand = false
        scHum:ChangeState(Enum.HumanoidStateType.Running)
        scRoot.CFrame = aretimTargetCF
        task.wait(0.6)

        -- 4. Trigger dialogue and verify NPCDialogue is visible
        local pgui = PlayerGui
        local diag = pgui:FindFirstChild("NPCDialogue")
        local diagOpened = false
        local diagStart = os.clock()

        hubLog("[AutoFarmLevel]  Triggering dialogue with Aretim...")
        while (os.clock() - diagStart < 6.0) do
            diag = pgui:FindFirstChild("NPCDialogue")
            if diag and diag.Enabled then
                diagOpened = true
                hubLog("[AutoFarmLevel]  Aretim dialogue interface opened successfully!")
                break
            end

            scRoot.CFrame = aretimTargetCF
            local aretimProx = aretimModel and aretimModel:FindFirstChildWhichIsA("ProximityPrompt", true)
            if aretimProx and fireproximityprompt then
                fireproximityprompt(aretimProx)
            end
            task.wait(0.5)
        end

        -- 5. Auto select maximum level up dialogue option
        if diagOpened and diag and diag.Enabled then
            task.wait(0.5)
            local optionsFrame = diag:FindFirstChild("Options", true)
            if optionsFrame then
                local clicked = false
                -- Priority 1: Multi-level upgrade (Show me as much light as I can handle. (+ X LVLS))
                for _, opt in ipairs(optionsFrame:GetChildren()) do
                    if opt:IsA("TextButton") and opt.Visible then
                        local txt = opt.Text:lower()
                        if (txt:find("as much light") or txt:find("lvls")) and not txt:find("+ 0 lvls") then
                            hubLog(string.format("[AutoFarmLevel]  Clicking max upgrade: '%s'", opt.Text))
                            safeClickButton(opt)
                            clicked = true
                            break
                        end
                    end
                end
                -- Priority 2: Single level upgrade (+LVL)
                if not clicked then
                    for _, opt in ipairs(optionsFrame:GetChildren()) do
                        if opt:IsA("TextButton") and opt.Visible and opt.Text:lower():find("+lvl") and not opt.Text:lower():find("+ 0") then
                            hubLog(string.format("[AutoFarmLevel]  Clicking 1 level upgrade: '%s'", opt.Text))
                            safeClickButton(opt)
                            clicked = true
                            break
                        end
                    end
                end
                -- Neu not enough Essence de increase: close dialogue bang 'Not yet.'
                if not clicked then
                    for _, opt in ipairs(optionsFrame:GetChildren()) do
                        if opt:IsA("TextButton") and opt.Visible and opt.Text:lower():find("not yet") then
                            hubLog("[AutoFarmLevel]  Insufficient Essence to level up, closing dialogue.")
                            safeClickButton(opt)
                            break
                        end
                    end
                end
            end
        else
            warn("[AutoFarmLevel]  Failed to open NPCDialogue with Aretim.")
        end
        task.wait(1.5)

        -- 5. Auto allocate Stat points per configuration and finish
        allocateStats()
        task.wait(1.0)

        -- 6. Simulate pressing M key to exit Soul Corridor back to Overworld
        hubLog("[AutoFarmLevel]  Pressing M key to exit meditation and return to Overworld...")
        simulateKeyPress(Enum.KeyCode.M, 0.12)

        local exitWaited = 0
        while isInSoulCorridor() and exitWaited < 8.5 do
            task.wait(0.5)
            exitWaited = exitWaited + 0.5
        end
    else
        hubLog("[AutoFarmLevel]  Cannot enter Soul Corridor on this cycle.")
    end

    -- 7. Return to safe farm spot via Sky-Tween
    local spot, spotDesc = getActiveFarmSpot()
    hubLog(string.format("[AutoFarmLevel]  Flying back to farm spot (%s) via Sky-Tween...", spotDesc))
    flyToFarmSpot(spot)
    enableLevelFarmerNoclip()
    hubLog("[AutoFarmLevel]  Returned safely to farm spot!")

    -- Reset Essence counter after combat
    LevelFarmer.essenceBeforeCombat = getCurrentEssence()
    LevelFarmer.zeroGainFightCount = 0
    return true
end



local function getCurrentTurnNumber()
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
    local header = actionBG and actionBG:FindFirstChild("Header")
    local title = header and header:FindFirstChild("Title")
    if title and title.Text then
        return tonumber(title.Text:match("%d+"))
    end
    return nil
end

local function isPlayerTurn()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return false end

    if not isInCombat() then return false end

    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if not combatGui or not combatGui.Enabled then return false end

    -- Check if Deciding belongs to Player OR Player's Summons (e.g. Skeletons, Minions)
    local deciding = combatGui:FindFirstChild("Deciding")
    if deciding and deciding.Visible then
        local label = deciding:FindFirstChild("TextLabel")
        local text = label and label.Text or ""
        if text ~= "" then
            local isMyTurn = text:find(LocalPlayer.Name) ~= nil
            if not isMyTurn and char:FindFirstChild("Summons") then
                for _, s in ipairs(char.Summons:GetChildren()) do
                    if text:find(s.Name) then
                        isMyTurn = true
                        break
                    end
                end
            end
            if not isMyTurn and (text:lower():find("skeleton") or text:lower():find("summon") or text:lower():find("minion")) then
                isMyTurn = true
            end
            if not isMyTurn then
                return false
            end
        end
    end

    local dodge = combatGui:FindFirstChild("DodgeQTE")
    if dodge and dodge.Visible then return false end

    local goBtn = combatGui:FindFirstChild("Go")
    if goBtn and goBtn.Visible then return true end

    local actionBG = combatGui:FindFirstChild("ActionBG")
    if not actionBG or not actionBG.Visible then return false end

    local header = actionBG:FindFirstChild("Header")
    local title = header and header:FindFirstChild("Title")
    if title and title.Text and (title.Text:find("Turn") or title.Text:find("Action")) then
        return true
    end

    local ctx = actionBG:FindFirstChild("ContextPage")
    local atk = actionBG:FindFirstChild("AttacksPage")
    if (ctx and ctx.Visible) or (atk and atk.Visible) then
        return true
    end

    return false
end

local function scanPlayerSkills()
    if not HubState.knownPlayerSkills then
        HubState.knownPlayerSkills = {
            ["Strike"] = true,
        }
    end

    local skillSet = table.clone(HubState.knownPlayerSkills)
    local pgui = PlayerGui
    local blacklist = {
        ["Skills"] = true, ["Element"] = true, ["Physical"] = true, ["Magic"] = true, ["Fire"] = true,
        ["Holy"] = true, ["Nature"] = true, ["Hex"] = true, ["Dark"] = true, ["Poison"] = true,
        ["Duration"] = true, ["Scaling"] = true, ["Strength"] = true, ["Arcane"] = true, ["Buff"] = true,
        ["Debuff"] = true, ["Heal"] = true, ["Speed"] = true, ["Luck"] = true, ["Cost"] = true,
        ["Cooldown"] = true, ["Active"] = true, ["Passive"] = true, ["ACTIVE"] = true, ["PASSIVE"] = true,
        ["UNEQUIP"] = true, ["Label"] = true, ["N/A"] = true, ["Button"] = true, ["Example"] = true,
        ["Info"] = true, ["Template"] = true, ["Return"] = true, ["Shadow Form"] = true, ["SKILL NAME"] = true,
    }

    local summonOnlyMoves = {
        ["Smack"] = true,
        ["Bone Spray"] = true,
        ["Self Destruct"] = true,
        ["Rotten Swipe"] = true,
        ["Shriek"] = true,
        ["Double Slam"] = true,
        ["Light Bolt"] = true,
        ["Gale Uplift"] = true,
        ["Sylph's Prayer"] = true,
    }

    -- 1. Scan from live SkillDisplay (Active Class/Player Skills)
    pcall(function()
        local skillDisplay = pgui and pgui:FindFirstChild("SkillDisplay")
        if skillDisplay then
            local skillsFolder = skillDisplay:FindFirstChild("Skills", true)
            if skillsFolder then
                for _, c in ipairs(skillsFolder:GetChildren()) do
                    if (c:IsA("TextButton") or c:IsA("GuiButton") or c:IsA("TextLabel")) and not blacklist[c.Name] then
                        local name = c:IsA("TextButton") and c.Text or c.Name
                        if #name > 1 and not blacklist[name] then
                            if summonOnlyMoves[name] then
                                skillSet[string.format("[Summon] %s", name)] = true
                            else
                                skillSet[name] = true
                                HubState.knownPlayerSkills[name] = true
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 2. Scan from in-combat AttacksPage
    pcall(function()
        local combatGui = pgui and pgui:FindFirstChild("Combat")
        local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
        local atkPage = actionBG and actionBG:FindFirstChild("AttacksPage")
        local attackFrame = atkPage and atkPage:FindFirstChild("Attack")
        local scrollFrame = attackFrame and attackFrame:FindFirstChild("ScrollingFrame")
        if scrollFrame then
            for _, btn in ipairs(scrollFrame:GetChildren()) do
                if (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and not blacklist[btn.Name] then
                    local label = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                    local sName = (label and label.Text ~= "" and label.Text) or btn.Name
                    if #sName > 1 and not blacklist[sName] then
                        if summonOnlyMoves[sName] then
                            skillSet[string.format("[Summon] %s", sName)] = true
                        else
                            skillSet[sName] = true
                            HubState.knownPlayerSkills[sName] = true
                        end
                    end
                end
            end
        end
    end)

    -- 3. Dynamic Summon Skills Integration (ONLY if summon spells are learned by this character)
    local summonSpells = {
        ["Call Skeleton"] = {"Smack", "Bone Spray", "Self Destruct"},
        ["Raise Dead"] = {"Rotten Swipe", "Shriek", "Double Slam", "Smack"},
        ["Call Sylph"] = {"Sylph's Prayer", "Light Bolt", "Gale Uplift"},
    }
    for spellName, moves in pairs(summonSpells) do
        if skillSet[spellName] then
            for _, move in ipairs(moves) do
                skillSet[string.format("[Summon] %s", move)] = true
            end
        end
    end

    -- Clean up any bare summon moves that might have leaked into skillSet without [Summon] prefix
    for sMove in pairs(summonOnlyMoves) do
        if skillSet[sMove] and not HubState.knownPlayerSkills[sMove] then
            skillSet[sMove] = nil
        end
    end

    -- Always include basic attack
    skillSet["Strike"] = true

    local list = {}
    for name in pairs(skillSet) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

-- =============================================================================
-- AUTO FIGHT ENGINE (STANDALONE COMBAT TURN & SKILL EXECUTOR)
-- =============================================================================

-- auto stop moi instance AutoYarthul cu is chay underground before khi khoi tao instance moi
if shared.AutoYarthulInstance then
    pcall(function() shared.AutoYarthulInstance.stop(true) end)
    shared.AutoYarthulInstance = nil
end

-- =============================================================================
-- AUTO BOSS FARM ENGINE: YAR'THUL, THE BLAZING DRAGON (MOUNT THUL)
-- =============================================================================


local LevelFarmer = {
    running = false,
    noclipConn = nil,
    undergroundPlatform = nil,
    farmSpotLv1_30 = Vector3.new(5131.5, 662.4, -3947.6),   -- The Crossing Safe Block (Lv 1 - 30)
    farmSpotLv30_50 = Vector3.new(3067.7, 623.9, -3832.3),  -- Desert Safe Block (Lv 30 - 50)
    farmSpots = {
        ["The Crossing (Caldera / Starter Mobs)"] = Vector3.new(5986.4, 616.8, -4260.2),
        ["Deeproot Canopy (Westwood / Forest Mobs)"] = Vector3.new(7595.9, 599.3, -3361.3),
        ["Waving Sands (Desert / Sand Mobs)"] = Vector3.new(3062.7, 595.1, -4566.3),
        ["Withered Grove (Cursed Grove / Undead Mobs)"] = Vector3.new(6075.8, 639.3, -2013.1),
        ["Mount Thul (Snow Mountain / Frost Mobs)"] = Vector3.new(572.3, 559.5, -4156.2),
    },
    essenceBeforeCombat = -1,
    zeroGainFightCount = 0,
    wasInCombat = false,
    lastMeditateTime = 0,
    aretimPos = Vector3.new(789.8, 238.0, 2120.8),
}

local function ensureUndergroundPlatform(targetPos)
    local plat = workspace:FindFirstChild("ArcaneFarmPlatform")
    if not plat then
        plat = Instance.new("Part")
        plat.Name = "ArcaneFarmPlatform"
        plat.Size = Vector3.new(20, 2, 20)
        plat.Anchored = true
        plat.CanCollide = true
        plat.Transparency = 0.5
        plat.Material = Enum.Material.SmoothPlastic
        plat.Color = Color3.fromRGB(35, 35, 35)
        plat.Parent = workspace
    end
    plat.Position = targetPos
    LevelFarmer.undergroundPlatform = plat
    return plat
end

local function removeUndergroundPlatform()
    local plat = workspace:FindFirstChild("ArcaneFarmPlatform")
    if plat then plat:Destroy() end
    LevelFarmer.undergroundPlatform = nil
end

local function enableLevelFarmerNoclip()
    if LevelFarmer.noclipConn then return end
    LevelFarmer.noclipConn = registerConnection(RunService.Stepped:Connect(function()
        if not LevelFarmer.running then return end
        local c = LocalPlayer.Character
        if c and not isInCombat() then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = false
                end
            end
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end))
end

local function disableLevelFarmerNoclip()
    if LevelFarmer.noclipConn then
        LevelFarmer.noclipConn:Disconnect()
        LevelFarmer.noclipConn = nil
    end
end

local function getCurrentLevel()
    local pgui = PlayerGui
    local hud = pgui and pgui:FindFirstChild("HUD")
    if hud then
        local lvlObj = hud:FindFirstChild("CharacterLevel", true)
        local lvlText = lvlObj and lvlObj:FindFirstChild("Level")
        if lvlText and lvlText:IsA("TextLabel") then
            local num = tonumber(lvlText.Text:match("%d+"))
            if num then return num end
        end
    end
    local char = LocalPlayer.Character
    local lvlVal = char and (char:FindFirstChild("Level") or (char:FindFirstChild("Status") and char.Status:FindFirstChild("Level")))
    if lvlVal and lvlVal:IsA("ValueBase") then
        return tonumber(lvlVal.Value) or 1
    end
    return 1
end

local function getCurrentEssence()
    local pgui = PlayerGui
    local hud = pgui and pgui:FindFirstChild("HUD")
    if hud then
        local crystals = hud:FindFirstChild("Crystals", true)
        local amountObj = crystals and crystals:FindFirstChild("Amount")
        if amountObj and amountObj:IsA("TextLabel") then
            local num = tonumber(amountObj.Text:match("%d+"))
            if num then return num end
        end
    end
    return 0
end

local function getActiveFarmSpot()
    local mode = (Options and Options.FarmLevelMode and Options.FarmLevelMode.Value) or "Auto (Detect Level 1 - 50)"
    
    if mode == "Level 1 - 30 (Underground)" then
        return LevelFarmer.farmSpotLv1_30, "Level 1 - 30 (Underground)"
    elseif mode == "Level 30 - 50 (Desert Block)" then
        return LevelFarmer.farmSpotLv30_50, "Level 30 - 50 (Desert Block)"
    elseif mode:find("Auto") then
        -- Auto detect player level (Lv < 30 fly ve bai underground Caldera, Lv >= 30 fly ve khoi safely Desert)
        local currentLvl = getCurrentLevel()
        if currentLvl >= 30 then
            return LevelFarmer.farmSpotLv30_50, string.format("Auto Detect (Lv %d -> Desert Block 30-50)", currentLvl)
        else
            return LevelFarmer.farmSpotLv1_30, string.format("Auto Detect (Lv %d -> Underground 1-30)", currentLvl)
        end
    elseif LevelFarmer.farmSpots[mode] then
        return LevelFarmer.farmSpots[mode], mode
    else
        return LevelFarmer.farmSpotLv1_30, "Level 1 - 30 (Underground)"
    end
end

local function flyToFarmSpot(targetSpot)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then
        warn("[AutoFarmLevel]  HumanoidRootPart or Humanoid not found!")
        return false
    end

    local currentPos = root.Position
    local targetCF = CFrame.new(targetSpot.X, targetSpot.Y + 4.0, targetSpot.Z)
    local distance = (currentPos - targetCF.Position).Magnitude

    if distance <= 4 then
        root.CFrame = targetCF
        ensureUndergroundPlatform(targetSpot)
        return true
    end

    hubLog(string.format("[AutoFarmLevel]  Starting Safe Sky-Tween flight to farm spot at (%.1f, %.1f, %.1f) - distance: %.1f studs...", targetCF.X, targetCF.Y, targetCF.Z, distance))

    ensureUndergroundPlatform(targetSpot)
    enableLevelFarmerNoclip()

    local skyHeight = 1500
    local skyY = math.max(skyHeight, currentPos.Y + 200, targetSpot.Y + 200)

    -- Phase 1: Fly straight up to high airspace
    local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), 200, function() return LevelFarmer.running end)
    if not s1 or not LevelFarmer.running then return false end

    -- Phase 2: Fly horizontally across airspace to farm spot
    local s2 = smoothTweenTo(CFrame.new(targetSpot.X, skyY, targetSpot.Z), 240, function() return LevelFarmer.running end)
    if not s2 or not LevelFarmer.running then return false end

    -- Phase 3: landed straight dung xuong bai farm (xuyen khoi / xuyen dat safely)
    local s3 = smoothTweenTo(targetCF, 180, function() return LevelFarmer.running end)
    if s3 then
        root.CFrame = targetCF
        hubLog("[AutoFarmLevel]  Landed safely at farm spot!")
    end
    return s3
end

local function safeClickButton(btn)
    if not btn then return false end
    local clicked = false

    if getconnections then
        local conns = getconnections(btn.MouseButton1Click)
        if conns and #conns > 0 then
            for _, c in ipairs(conns) do
                if c.Function then
                    task.spawn(c.Function)
                    clicked = true
                elseif c.Fire then
                    pcall(function() c:Fire() end)
                    clicked = true
                end
            end
            if clicked then return true end
        end
    end

    if firesignal then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        return true
    end

    return false
end

local function getCurrentStats()
    local stats = { Strength = 0, Endurance = 0, Speed = 0, Arcane = 0, Luck = 0 }
    local pgui = PlayerGui
    local sm = pgui and pgui:FindFirstChild("StatMenu")
    if sm then
        local attrs = sm:FindFirstChild("Attributes", true)
        if attrs then
            for statName, _ in pairs(stats) do
                local frame = attrs:FindFirstChild(statName)
                local valObj = frame and frame:FindFirstChild("StatValue")
                if valObj and valObj:IsA("TextLabel") then
                    local num = tonumber(valObj.Text:match("^%s*(%d+)"))
                    if num then stats[statName] = num end
                end
            end
        end
    end
    return stats
end

-- =============================================================================
-- USER STATS ALLOCATION CACHE SYSTEM (PERSISTENT BY ROBLOX USERNAME)
-- =============================================================================
local STATS_CACHE_FILE = "Arcane_Hub_StatsCache.json"
local statsCacheMemory = {}

local function loadStatsCache()
    if readfile and isfile and isfile(STATS_CACHE_FILE) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(STATS_CACHE_FILE))
        end)
        if success and type(result) == "table" then
            statsCacheMemory = result
            return result
        end
    end
    return statsCacheMemory
end

local function saveStatsCache(cache)
    statsCacheMemory = cache
    if writefile then
        pcall(function()
            writefile(STATS_CACHE_FILE, HttpService:JSONEncode(cache))
        end)
    end
end

local function getUserStatsCache()
    local username = LocalPlayer.Name
    local cache = loadStatsCache()
    if not cache[username] then
        cache[username] = {
            Strength = 0,
            Endurance = 0,
            Speed = 0,
            Arcane = 0,
            Luck = 0,
        }
        saveStatsCache(cache)
    end
    return cache[username], cache, username
end

local function clearUserStatsCache()
    local userStats, allCache, username = getUserStatsCache()
    allCache[username] = {
        Strength = 0,
        Endurance = 0,
        Speed = 0,
        Arcane = 0,
        Luck = 0,
    }
    saveStatsCache(allCache)
    hubLog(string.format("[AutoStats]  has clear clean cache points stats cua tai khoan '%s'!", username))
    Library:Notify(string.format(" Cleared stats cache for '%s'!", username), 4)
end

local function allocateStats()
    if not (Toggles.AutoAllocateStats and Toggles.AutoAllocateStats.Value) then return end

    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    local lvlUpGui = pgui:FindFirstChild("LevelUp")
    
    -- 1. Wait for LevelUp UI to appear and enable (server game co do tre ~2.5s khi open dialogue Aretim)
    local waitStart = os.clock()
    while os.clock() - waitStart < 8.0 do
        lvlUpGui = pgui:FindFirstChild("LevelUp")
        if lvlUpGui and lvlUpGui.Enabled and lvlUpGui:FindFirstChild("Container") then
            break
        end
        task.wait(0.3)
    end

    if not (lvlUpGui and lvlUpGui.Enabled and lvlUpGui:FindFirstChild("Container")) then
        hubLog("[AutoFarmLevel]  LevelUp UI not detected.")
        return
    end

    local container = lvlUpGui.Container
    local header = container:FindFirstChild("Header")
    local pointsLabel = header and header:FindFirstChild("PointsLeft")
    local pointsText = pointsLabel and pointsLabel.Text or ""
    local availPoints = tonumber(pointsText:match("(%d+)")) or 0

    local userStats, allCache, username = getUserStatsCache()
    hubLog(string.format("[AutoFarmLevel]  [LevelUp GUI] Tai khoan '%s' co %d Stat Points not yet allocated.", username, availPoints))

    if availPoints <= 0 then
        local finishBtn = lvlUpGui:FindFirstChild("Finish")
        if finishBtn then
            if getconnections then
                for _, c in ipairs(getconnections(finishBtn.MouseButton1Click)) do
                    if c.Function then c.Function() break elseif c.Fire then c:Fire() break end
                end
            elseif firesignal then
                firesignal(finishBtn.MouseButton1Click)
            end
        end
        return
    end

    -- 2. Read target slider configuration
    local strSlider = Options.TargetStrength and Options.TargetStrength.Value or 20
    local arcSlider = Options.TargetArcane and Options.TargetArcane.Value or 0
    local endSlider = Options.TargetEndurance and Options.TargetEndurance.Value or 20
    local spdSlider = Options.TargetSpeed and Options.TargetSpeed.Value or 10
    local lckSlider = Options.TargetLuck and Options.TargetLuck.Value or 10

    -- Target manual stat investment = max(0, slider - 10) due to +10 free milestone points do
    local strMaxAdd = math.max(0, strSlider - 10)
    local arcMaxAdd = math.max(0, arcSlider - 10)
    local endMaxAdd = math.max(0, endSlider - 10)
    local spdMaxAdd = math.max(0, spdSlider - 10)
    local lckMaxAdd = math.max(0, lckSlider - 10)

    -- Remaining points needed compared to account allocated cache
    local strNeeded = math.max(0, strMaxAdd - (userStats.Strength or 0))
    local arcNeeded = math.max(0, arcMaxAdd - (userStats.Arcane or 0))
    local endNeeded = math.max(0, endMaxAdd - (userStats.Endurance or 0))
    local spdNeeded = math.max(0, spdMaxAdd - (userStats.Speed or 0))
    local lckNeeded = math.max(0, lckMaxAdd - (userStats.Luck or 0))

    hubLog(string.format("[AutoStats]  Cache hien tai cua '%s': Str:%d/%d, End:%d/%d, Spd:%d/%d, Arc:%d/%d, Lck:%d/%d",
        username,
        userStats.Strength or 0, strMaxAdd,
        userStats.Endurance or 0, endMaxAdd,
        userStats.Speed or 0, spdMaxAdd,
        userStats.Arcane or 0, arcMaxAdd,
        userStats.Luck or 0, lckMaxAdd
    ))

    -- Allocate points
    local strAdd = math.min(availPoints, strNeeded)
    availPoints = availPoints - strAdd

    local endAdd = math.min(availPoints, endNeeded)
    availPoints = availPoints - endAdd

    local spdAdd = math.min(availPoints, spdNeeded)
    availPoints = availPoints - spdAdd

    local arcAdd = math.min(availPoints, arcNeeded)
    availPoints = availPoints - arcAdd

    local lckAdd = math.min(availPoints, lckNeeded)
    availPoints = availPoints - lckAdd

    -- If points remain (Game requires 100% distribution before Finish):
    -- Automatically allocate into highest target stat slider
    if availPoints > 0 then
        if strSlider >= endSlider and strSlider >= arcSlider and strSlider > 0 then
            strAdd = strAdd + availPoints
        elseif endSlider >= strSlider and endSlider >= arcSlider and endSlider > 0 then
            endAdd = endAdd + availPoints
        elseif arcSlider >= strSlider and arcSlider >= endSlider and arcSlider > 0 then
            arcAdd = arcAdd + availPoints
        elseif spdSlider >= lckSlider and spdSlider > 0 then
            spdAdd = spdAdd + availPoints
        else
            lckAdd = lckAdd + availPoints
        end
        availPoints = 0
    end

    -- 3. Click stat upgrade button in PlayerGui.LevelUp
    local buttonsFrame = container:FindFirstChild("Body") and container.Body:FindFirstChild("Buttons")
    local function getStatUpButton(statName)
        if not buttonsFrame then return nil end
        local statFrame = buttonsFrame:FindFirstChild(statName)
        local frame = statFrame and statFrame:FindFirstChild("Frame")
        return frame and frame:FindFirstChild(statName .. "Up")
    end

    local function clickLevelUpButton(statName, count)
        if count <= 0 then return end
        local upBtn = getStatUpButton(statName)
        if not upBtn then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("ImageButton") and d.Name == (statName .. "Up") then
                    upBtn = d
                    break
                end
            end
        end
        if not upBtn then
            warn("[AutoStats]  Button not found:", statName .. "Up")
            return
        end

        local toAllocBox = container:FindFirstChild("ToAllocate", true)
        if toAllocBox and toAllocBox:IsA("TextBox") then
            toAllocBox.Text = tostring(count)
            task.wait(0.08)
            if getconnections then
                for _, c in ipairs(getconnections(upBtn.MouseButton1Click)) do
                    if c.Function then c.Function() break
                    elseif c.Fire then c:Fire() break end
                end
            elseif firesignal then
                firesignal(upBtn.MouseButton1Click)
            end
            task.wait(0.1)
        else
            for _ = 1, count do
                if getconnections then
                    for _, c in ipairs(getconnections(upBtn.MouseButton1Click)) do
                        if c.Function then c.Function() break
                        elseif c.Fire then c:Fire() break end
                    end
                elseif firesignal then
                    firesignal(upBtn.MouseButton1Click)
                end
                task.wait(0.05)
            end
        end
    end

    if strAdd > 0 then clickLevelUpButton("Strength", strAdd) end
    if endAdd > 0 then clickLevelUpButton("Endurance", endAdd) end
    if spdAdd > 0 then clickLevelUpButton("Speed", spdAdd) end
    if arcAdd > 0 then clickLevelUpButton("Arcane", arcAdd) end
    if lckAdd > 0 then clickLevelUpButton("Luck", lckAdd) end

    -- Update permanent cache for account
    userStats.Strength = (userStats.Strength or 0) + strAdd
    userStats.Endurance = (userStats.Endurance or 0) + endAdd
    userStats.Speed = (userStats.Speed or 0) + spdAdd
    userStats.Arcane = (userStats.Arcane or 0) + arcAdd
    userStats.Luck = (userStats.Luck or 0) + lckAdd
    saveStatsCache(allCache)

    task.wait(0.4)
    local finishBtn = lvlUpGui:FindFirstChild("Finish")
    if finishBtn then
        if getconnections then
            for _, c in ipairs(getconnections(finishBtn.MouseButton1Click)) do
                if c.Function then c.Function() break
                elseif c.Fire then c:Fire() break end
            end
        elseif firesignal then
            firesignal(finishBtn.MouseButton1Click)
        end
        hubLog(string.format("[AutoFarmLevel]  has allocated Stats cho '%s': Str+%d (total %d/%d), End+%d (total %d/%d), Spd+%d (total %d/%d), Arc+%d (total %d/%d), Luck+%d (total %d/%d) va bam Finish!", 
            username,
            strAdd, userStats.Strength, strMaxAdd,
            endAdd, userStats.Endurance, endMaxAdd,
            spdAdd, userStats.Speed, spdMaxAdd,
            arcAdd, userStats.Arcane, arcMaxAdd,
            lckAdd, userStats.Luck, lckMaxAdd
        ))
    end

    -- Wait for LevelUp GUI to close before continuing
    local closeWait = os.clock()
    while lvlUpGui.Enabled and os.clock() - closeWait < 4.0 do
        task.wait(0.3)
    end
end

local function isInSoulCorridor()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return (root.Position - LevelFarmer.aretimPos).Magnitude < 400
end

local function simulateKeyPress(keyCode, holdTime)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(holdTime or 0.15)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function humanoidMeditateAndLevelUp()
    local now = os.clock()
    if now - LevelFarmer.lastMeditateTime < 5 then
        return false
    end
    LevelFarmer.lastMeditateTime = now

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return false end

    -- 1. Find nearest Meditation Mat
    local mats = workspace:FindFirstChild("Mats")
    local nearestMat = nil
    local nearestDist = math.huge
    if mats then
        for _, mat in ipairs(mats:GetChildren()) do
            local pos = mat:GetPivot().Position
            local d = (pos - root.Position).Magnitude
            if d < nearestDist then
                nearestDist = d
                nearestMat = mat
            end
        end
    end

    if not nearestMat then
        hubLog("[AutoFarmLevel]  MeditationMat not found.")
        return false
    end

    local matPos = nearestMat:GetPivot().Position
    local targetCF = CFrame.new(matPos.X, matPos.Y + 1.2, matPos.Z)

    hubLog(string.format("[AutoFarmLevel]  Flying to Meditation Mat at (%.1f, %.1f, %.1f)...", matPos.X, matPos.Y, matPos.Z))

    hum.PlatformStand = true
    local noclipConn = RunService.Stepped:Connect(function()
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then r.AssemblyLinearVelocity = Vector3.zero end
        end
    end)

    local distance = (root.Position - targetCF.Position).Magnitude
    local speed = 180
    local duration = math.max(0.1, distance / speed)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCF })
    tween:Play()
    tween.Completed:Wait()

    noclipConn:Disconnect()
    hum.PlatformStand = false
    hum:ChangeState(Enum.HumanoidStateType.Landed)
    hum:ChangeState(Enum.HumanoidStateType.Running)
    root.CFrame = targetCF
    task.wait(0.8)

    -- 2. Press M key via VirtualInputManager (single trigger)
    hubLog("[AutoFarmLevel]  Pressing M key to meditate into Soul Corridor...")
    simulateKeyPress(Enum.KeyCode.M, 0.12)

    -- Monitor scene transition (Wait up to 8.5s for meditation animation & screen fade)
    local waited = 0
    while not isInSoulCorridor() and waited < 8.5 do
        task.wait(0.5)
        waited = waited + 0.5
    end

    if isInSoulCorridor() then
        hubLog("[AutoFarmLevel]  Entered Soul Corridor successfully!")
        task.wait(1.0)

        -- 3. Travel to NPC Aretim (Refresh character reference in Soul Corridor)
        local scChar = LocalPlayer.Character
        local scRoot = scChar and scChar:FindFirstChild("HumanoidRootPart")
        local scHum = scChar and scChar:FindFirstChildOfClass("Humanoid")
        if not scRoot or not scHum then return false end

        local aretimModel = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Aretim")
        local aretimPos = aretimModel and aretimModel:GetPivot().Position or LevelFarmer.aretimPos
        local aretimTargetCF = CFrame.lookAt(Vector3.new(aretimPos.X, aretimPos.Y + 1.5, aretimPos.Z - 4.0), aretimPos)

        hubLog(string.format("[AutoFarmLevel] 🚶 Flying to NPC Aretim at (%.1f, %.1f, %.1f)...", aretimPos.X, aretimPos.Y, aretimPos.Z))
        
        scHum.PlatformStand = true
        local noclipCorridor = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
                local r = c:FindFirstChild("HumanoidRootPart")
                if r then r.AssemblyLinearVelocity = Vector3.zero end
            end
        end)

        local dCorridor = (scRoot.Position - aretimTargetCF.Position).Magnitude
        local tCorridor = TweenService:Create(scRoot, TweenInfo.new(math.max(0.1, dCorridor / 140), Enum.EasingStyle.Linear), { CFrame = aretimTargetCF })
        tCorridor:Play()
        tCorridor.Completed:Wait()

        noclipCorridor:Disconnect()
        scHum.PlatformStand = false
        scHum:ChangeState(Enum.HumanoidStateType.Running)
        scRoot.CFrame = aretimTargetCF
        task.wait(0.6)

        -- 4. Trigger dialogue and verify NPCDialogue is visible
        local pgui = PlayerGui
        local diag = pgui:FindFirstChild("NPCDialogue")
        local diagOpened = false
        local diagStart = os.clock()

        hubLog("[AutoFarmLevel]  Triggering dialogue with Aretim...")
        while (os.clock() - diagStart < 6.0) do
            diag = pgui:FindFirstChild("NPCDialogue")
            if diag and diag.Enabled then
                diagOpened = true
                hubLog("[AutoFarmLevel]  Aretim dialogue interface opened successfully!")
                break
            end

            scRoot.CFrame = aretimTargetCF
            local aretimProx = aretimModel and aretimModel:FindFirstChildWhichIsA("ProximityPrompt", true)
            if aretimProx and fireproximityprompt then
                fireproximityprompt(aretimProx)
            end
            task.wait(0.5)
        end

        -- 5. Auto select maximum level up dialogue option
        if diagOpened and diag and diag.Enabled then
            task.wait(0.5)
            local optionsFrame = diag:FindFirstChild("Options", true)
            if optionsFrame then
                local clicked = false
                -- Priority 1: Multi-level upgrade (Show me as much light as I can handle. (+ X LVLS))
                for _, opt in ipairs(optionsFrame:GetChildren()) do
                    if opt:IsA("TextButton") and opt.Visible then
                        local txt = opt.Text:lower()
                        if (txt:find("as much light") or txt:find("lvls")) and not txt:find("+ 0 lvls") then
                            hubLog(string.format("[AutoFarmLevel]  Clicking max upgrade: '%s'", opt.Text))
                            safeClickButton(opt)
                            clicked = true
                            break
                        end
                    end
                end
                -- Priority 2: Single level upgrade (+LVL)
                if not clicked then
                    for _, opt in ipairs(optionsFrame:GetChildren()) do
                        if opt:IsA("TextButton") and opt.Visible and opt.Text:lower():find("+lvl") and not opt.Text:lower():find("+ 0") then
                            hubLog(string.format("[AutoFarmLevel]  Clicking 1 level upgrade: '%s'", opt.Text))
                            safeClickButton(opt)
                            clicked = true
                            break
                        end
                    end
                end
                -- Neu not enough Essence de increase: close dialogue bang 'Not yet.'
                if not clicked then
                    for _, opt in ipairs(optionsFrame:GetChildren()) do
                        if opt:IsA("TextButton") and opt.Visible and opt.Text:lower():find("not yet") then
                            hubLog("[AutoFarmLevel]  Insufficient Essence to level up, closing dialogue.")
                            safeClickButton(opt)
                            break
                        end
                    end
                end
            end
        else
            warn("[AutoFarmLevel]  Failed to open NPCDialogue with Aretim.")
        end
        task.wait(1.5)

        -- 5. Auto allocate Stat points per configuration and finish
        allocateStats()
        task.wait(1.0)

        -- 6. Simulate pressing M key to exit Soul Corridor back to Overworld
        hubLog("[AutoFarmLevel]  Pressing M key to exit meditation and return to Overworld...")
        simulateKeyPress(Enum.KeyCode.M, 0.12)

        local exitWaited = 0
        while isInSoulCorridor() and exitWaited < 8.5 do
            task.wait(0.5)
            exitWaited = exitWaited + 0.5
        end
    else
        hubLog("[AutoFarmLevel]  Cannot enter Soul Corridor on this cycle.")
    end

    -- 7. Return to safe farm spot via Sky-Tween
    local spot, spotDesc = getActiveFarmSpot()
    hubLog(string.format("[AutoFarmLevel]  Flying back to farm spot (%s) via Sky-Tween...", spotDesc))
    flyToFarmSpot(spot)
    enableLevelFarmerNoclip()
    hubLog("[AutoFarmLevel]  Returned safely to farm spot!")

    -- Reset Essence counter after combat
    LevelFarmer.essenceBeforeCombat = getCurrentEssence()
    LevelFarmer.zeroGainFightCount = 0
    return true
end



local function getCurrentTurnNumber()
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
    local header = actionBG and actionBG:FindFirstChild("Header")
    local title = header and header:FindFirstChild("Title")
    if title and title.Text then
        return tonumber(title.Text:match("%d+"))
    end
    return nil
end

local function isPlayerTurn()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return false end

    if not isInCombat() then return false end

    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if not combatGui or not combatGui.Enabled then return false end

    -- Check if Deciding belongs to Player OR Player's Summons (e.g. Skeletons, Minions)
    local deciding = combatGui:FindFirstChild("Deciding")
    if deciding and deciding.Visible then
        local label = deciding:FindFirstChild("TextLabel")
        local text = label and label.Text or ""
        if text ~= "" then
            local isMyTurn = text:find(LocalPlayer.Name) ~= nil
            if not isMyTurn and char:FindFirstChild("Summons") then
                for _, s in ipairs(char.Summons:GetChildren()) do
                    if text:find(s.Name) then
                        isMyTurn = true
                        break
                    end
                end
            end
            if not isMyTurn and (text:lower():find("skeleton") or text:lower():find("summon") or text:lower():find("minion")) then
                isMyTurn = true
            end
            if not isMyTurn then
                return false
            end
        end
    end

    local dodge = combatGui:FindFirstChild("DodgeQTE")
    if dodge and dodge.Visible then return false end

    local goBtn = combatGui:FindFirstChild("Go")
    if goBtn and goBtn.Visible then return true end

    local actionBG = combatGui:FindFirstChild("ActionBG")
    if not actionBG or not actionBG.Visible then return false end

    local header = actionBG:FindFirstChild("Header")
    local title = header and header:FindFirstChild("Title")
    if title and title.Text and (title.Text:find("Turn") or title.Text:find("Action")) then
        return true
    end

    local ctx = actionBG:FindFirstChild("ContextPage")
    local atk = actionBG:FindFirstChild("AttacksPage")
    if (ctx and ctx.Visible) or (atk and atk.Visible) then
        return true
    end

    return false
end

local function scanPlayerSkills()
    if not HubState.knownPlayerSkills then
        HubState.knownPlayerSkills = {
            ["Strike"] = true,
        }
    end

    local skillSet = table.clone(HubState.knownPlayerSkills)
    local pgui = PlayerGui
    local blacklist = {
        ["Skills"] = true, ["Element"] = true, ["Physical"] = true, ["Magic"] = true, ["Fire"] = true,
        ["Holy"] = true, ["Nature"] = true, ["Hex"] = true, ["Dark"] = true, ["Poison"] = true,
        ["Duration"] = true, ["Scaling"] = true, ["Strength"] = true, ["Arcane"] = true, ["Buff"] = true,
        ["Debuff"] = true, ["Heal"] = true, ["Speed"] = true, ["Luck"] = true, ["Cost"] = true,
        ["Cooldown"] = true, ["Active"] = true, ["Passive"] = true, ["ACTIVE"] = true, ["PASSIVE"] = true,
        ["UNEQUIP"] = true, ["Label"] = true, ["N/A"] = true, ["Button"] = true, ["Example"] = true,
        ["Info"] = true, ["Template"] = true, ["Return"] = true, ["Shadow Form"] = true, ["SKILL NAME"] = true,
    }

    local summonOnlyMoves = {
        ["Smack"] = true,
        ["Bone Spray"] = true,
        ["Self Destruct"] = true,
        ["Rotten Swipe"] = true,
        ["Shriek"] = true,
        ["Double Slam"] = true,
        ["Light Bolt"] = true,
        ["Gale Uplift"] = true,
        ["Sylph's Prayer"] = true,
    }

    -- 1. Scan from live SkillDisplay (Active Class/Player Skills)
    pcall(function()
        local skillDisplay = pgui and pgui:FindFirstChild("SkillDisplay")
        if skillDisplay then
            local skillsFolder = skillDisplay:FindFirstChild("Skills", true)
            if skillsFolder then
                for _, c in ipairs(skillsFolder:GetChildren()) do
                    if (c:IsA("TextButton") or c:IsA("GuiButton") or c:IsA("TextLabel")) and not blacklist[c.Name] then
                        local name = c:IsA("TextButton") and c.Text or c.Name
                        if #name > 1 and not blacklist[name] then
                            if summonOnlyMoves[name] then
                                skillSet[string.format("[Summon] %s", name)] = true
                            else
                                skillSet[name] = true
                                HubState.knownPlayerSkills[name] = true
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 2. Scan from in-combat AttacksPage
    pcall(function()
        local combatGui = pgui and pgui:FindFirstChild("Combat")
        local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
        local atkPage = actionBG and actionBG:FindFirstChild("AttacksPage")
        local attackFrame = atkPage and atkPage:FindFirstChild("Attack")
        local scrollFrame = attackFrame and attackFrame:FindFirstChild("ScrollingFrame")
        if scrollFrame then
            for _, btn in ipairs(scrollFrame:GetChildren()) do
                if (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and not blacklist[btn.Name] then
                    local label = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                    local sName = (label and label.Text ~= "" and label.Text) or btn.Name
                    if #sName > 1 and not blacklist[sName] then
                        if summonOnlyMoves[sName] then
                            skillSet[string.format("[Summon] %s", sName)] = true
                        else
                            skillSet[sName] = true
                            HubState.knownPlayerSkills[sName] = true
                        end
                    end
                end
            end
        end
    end)

    -- 3. Dynamic Summon Skills Integration (ONLY if summon spells are learned by this character)
    local summonSpells = {
        ["Call Skeleton"] = {"Smack", "Bone Spray", "Self Destruct"},
        ["Raise Dead"] = {"Rotten Swipe", "Shriek", "Double Slam", "Smack"},
        ["Call Sylph"] = {"Sylph's Prayer", "Light Bolt", "Gale Uplift"},
    }
    for spellName, moves in pairs(summonSpells) do
        if skillSet[spellName] then
            for _, move in ipairs(moves) do
                skillSet[string.format("[Summon] %s", move)] = true
            end
        end
    end

    -- Clean up any bare summon moves that might have leaked into skillSet without [Summon] prefix
    for sMove in pairs(summonOnlyMoves) do
        if skillSet[sMove] and not HubState.knownPlayerSkills[sMove] then
            skillSet[sMove] = nil
        end
    end

    -- Always include basic attack
    skillSet["Strike"] = true

    local list = {}
    for name in pairs(skillSet) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

-- =============================================================================
-- AUTO FIGHT ENGINE (STANDALONE COMBAT TURN & SKILL EXECUTOR)
-- =============================================================================

-- auto stop moi instance AutoYarthul cu is chay underground before khi khoi tao instance moi
if shared.AutoYarthulInstance then
    pcall(function() shared.AutoYarthulInstance.stop(true) end)
    shared.AutoYarthulInstance = nil
end

-- =============================================================================
-- AUTO BOSS FARM ENGINE: YAR'THUL, THE BLAZING DRAGON (MOUNT THUL)
-- =============================================================================
local AutoYarthul = {
    running = false,
    thread = nil,
    lootThread = nil,
    refightConn = nil,
    state = "Idle",
    bossKillCount = 0,
    deathCount = 0,
    floatingGui = nil,
    PLACE_ID = 10595058975,                                -- Arcane Lineage Place ID
    UNIVERSE_ID = 3846592040,                              -- Arcane Lineage Universe ID
    gatePosition = Vector3.new(40.5, 581.6, -4113.5),      -- Mount Thul Boss Door (Begin Fight Gate)
    spawnPosition = Vector3.new(99.15, 572.31, -4115.89),  -- Yar'thul Instance Spawn Point
    arenaPosition = Vector3.new(-555.0, 645.6, -4235.4),   -- Yar'thul Arena Center
    sessionFile = "Arcane_Yarthul_ActiveSession.json",
    lastGateInteractTime = 0,
    wasInCombat = false,
    hasFoughtBoss = false,
    isRestoring = false,
    charAddedConn = nil,
    lastUsedSkill = "",
    turnExecutionLock = false,
    inventoryBaseline = {},
    lastDroppedSummary = "None drop moi",
}

shared.AutoYarthulInstance = AutoYarthul

-- 1. Instance & Area Detection Helper (receive biet chinh xac vi tri trong Instance Yar'thul vs Main Game qua toa do truc X)
function AutoYarthul.isInsideInstance()
    if isInCombat() then
        return true
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        -- Yar'thul Boss arena located at coordinates X < -200 (khoang X=-555, Y=645, Z=-4235)
        -- While Overworld / Main Game is located at coordinates X > 0 (cua Mount Thul X=40.5)
        if root.Position.X < -200 then
            return true
        end
    end

    return false
end

-- 2. Read exact Boss Yar'thul Health (HP & MaxHP)
function AutoYarthul.getBossHealth()
    -- A. Scan Workspace.Living
    local living = workspace:FindFirstChild("Living")
    if living then
        for _, m in ipairs(living:GetChildren()) do
            if m:IsA("Model") and (m.Name:lower():find("yar") or m.Name:lower():find("thul") or m.Name:lower():find("dragon")) then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum then
                    return hum.Health, hum.MaxHealth, m
                end
            end
        end
    end

    -- B. Scan via GetOtherTeam remote if available
    pcall(function()
        local char = LocalPlayer.Character
        local fip = char and char:FindFirstChild("FightInProgress")
        if fip and fip.Value then
            local getOtherTeam = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Data") and ReplicatedStorage.Remotes.Data:FindFirstChild("GetOtherTeam")
            if getOtherTeam then
                local otherTeam = getOtherTeam:InvokeServer(fip.Value)
                if type(otherTeam) == "table" and #otherTeam > 0 then
                    for _, enemy in ipairs(otherTeam) do
                        if enemy and enemy:IsA("Model") and (enemy.Name:lower():find("yar") or enemy.Name:lower():find("thul") or enemy.Name:lower():find("dragon")) then
                            local hum = enemy:FindFirstChildOfClass("Humanoid")
                            if hum then
                                return hum.Health, hum.MaxHealth, enemy
                            end
                        end
                    end
                end
            end
        end
    end)

    return 0, 0, nil
end

-- 3. INVENTORY SCAN & RECONCILIATION ENGINE FOR AUTO DROP DETECTION
function AutoYarthul.getInventorySnapshot()
    local snap = {}
    pcall(function()
        local pgui = PlayerGui
        local invGui = pgui and pgui:FindFirstChild("Inventory")
        local invFrame = invGui and invGui:FindFirstChild("Inventory")
        if invFrame then
            for _, desc in ipairs(invFrame:GetDescendants()) do
                if desc:IsA("TextButton") and desc.Text and #desc.Text > 0 and desc.Name ~= "Delete" and desc.Name ~= "Button" then
                    local rawName = desc.Text
                    local amtLabel = desc:FindFirstChild("AmountLabel")
                    local count = 1
                    if amtLabel and amtLabel.Text then
                        count = tonumber(amtLabel.Text:match("^(%d+)")) or 1
                    end
                    snap[rawName] = (snap[rawName] or 0) + count
                end
            end
        end
    end)
    return snap
end

function AutoYarthul.detectInventoryDrops()
    local currentSnap = AutoYarthul.getInventorySnapshot()
    local drops = {}

    for name, curCount in pairs(currentSnap) do
        local prevCount = AutoYarthul.inventoryBaseline[name] or 0
        if curCount > prevCount then
            local diff = curCount - prevCount
            table.insert(drops, { name = name, count = diff })
        end
    end

    -- Update baseline using current snapshot
    AutoYarthul.inventoryBaseline = currentSnap
    return drops
end

-- 4. 100% ACCURATE SKILL COOLDOWN VERIFICATION VIA COMBAT GUI
function AutoYarthul.isSkillReady(skillName)
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if not combatGui then return true end

    for _, desc in ipairs(combatGui:GetDescendants()) do
        if desc:IsA("GuiButton") or desc:IsA("Frame") then
            local isTargetSkill = false
            if desc.Name:lower() == skillName:lower() then
                isTargetSkill = true
            else
                local sname = desc:FindFirstChild("SkillName")
                if sname and sname:IsA("TextLabel") and sname.Text:lower() == skillName:lower() then
                    isTargetSkill = true
                end
            end

            if isTargetSkill then
                -- test CD ImageLabel
                local cdImg = desc:FindFirstChild("CD", true)
                if cdImg and cdImg:IsA("GuiObject") and cdImg.Visible then
                    return false
                end
                -- test Cooldown Frame
                local cdFrame = desc:FindFirstChild("Cooldown", true) or desc:FindFirstChild("CoolDown", true)
                if cdFrame and cdFrame:IsA("GuiObject") and cdFrame.Visible then
                    return false
                end
                -- Skill ready dung!
                return true
            end
        end
    end

    -- Fallback for Sense Expansion
    if skillName == "Sense Expansion" then
        return (AutoYarthul.lastUsedSkill ~= "Sense Expansion")
    end

    return true
end

-- 5. DISCORD WEBHOOK NOTIFIER (PREMIUM DESIGN & PRIVACY SPOILERS)
function AutoYarthul.sendWebhook(eventType, extraData)
    local webhookUrl = Options.DiscordWebhook and Options.DiscordWebhook.Value or ""
    if #webhookUrl < 10 or not HttpRequest then
        if eventType == "Test" then
            ZeroLib:Notify({ Title = "Webhook", Content = "Please enter a valid Discord Webhook URL first!", Type = "Warning" })
        end
        return
    end

    local useWebhook = (Toggles.YarthulSendWebhook == nil or Toggles.YarthulSendWebhook.Value)
    if not useWebhook and eventType ~= "Test" then return end

    task.spawn(function()
        local embed = {}
        local char = LocalPlayer.Character
        local health = char and char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").Health or 0
        local maxHealth = char and char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").MaxHealth or 100

        if eventType == "Kill" then
            local dropStr = extraData and extraData.dropStr or "• No new items added to inventory"
            embed = {
                title = "🔥 YAR'THUL BOSS SLAIN",
                description = "Character successfully defeated Boss **Yar'thul (Mount Thul)** and verified inventory!",
                color = 0xF97316, -- Fiery Amber Orange
                fields = {
                    { name = "🎁 Acquired Drops", value = dropStr, inline = false },
                    { name = "🏆 Total Kills", value = string.format("`%d` Kills", AutoYarthul.bossKillCount), inline = true },
                    { name = "❤️ Player Health", value = string.format("`%.0f / %.0f`", health, maxHealth), inline = true },
                    { name = "👤 Player", value = string.format("||%s|| (||%s||)", LocalPlayer.Name, LocalPlayer.DisplayName), inline = true }
                },
                footer = { text = "Arcane Lineage • Automated Intelligence System" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        elseif eventType == "Loot" then
            local itemName = extraData and extraData.itemName or "Rare Artifact"
            local droppedBy = extraData and extraData.droppedBy or "Yar'thul, the Blazing Dragon"
            embed = {
                title = "🎁 ITEM DROP RECEIVED",
                description = string.format("Character automatically received **%s**!", itemName),
                color = 0x06B6D4, -- Cyber Cyan
                fields = {
                    { name = "📦 Item Drop", value = string.format("**%s**", itemName), inline = true },
                    { name = "⚔️ Source", value = string.format("`%s`", droppedBy), inline = true },
                    { name = "🏆 Total Boss Kills", value = string.format("`%d` Kills", AutoYarthul.bossKillCount), inline = true },
                    { name = "👤 Player", value = string.format("||%s||", LocalPlayer.Name), inline = true }
                },
                footer = { text = "Arcane Lineage • Automated Intelligence System" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        elseif eventType == "Test" then
            local snap = AutoYarthul.getInventorySnapshot()
            local snapCount = 0
            for _ in pairs(snap) do snapCount = snapCount + 1 end
            embed = {
                title = "⚡ WEBHOOK VERIFICATION TEST",
                description = "Discord Webhook connection verified and operating flawlessly with Arcane Lineage Hub!",
                color = 0x06B6D4, -- Cyber Cyan
                fields = {
                    { name = "👤 Player", value = string.format("||%s|| (ID: ||%s||)", LocalPlayer.Name, tostring(LocalPlayer.UserId)), inline = true },
                    { name = "🟢 Status", value = "`Active & Operational`", inline = true },
                    { name = "🏆 Current Boss Kills", value = string.format("`%d` Kills", AutoYarthul.bossKillCount), inline = true },
                    { name = "📦 Inventory Item Types", value = string.format("`%d` Types", snapCount), inline = true },
                    { name = "🎮 Target Game", value = "`Arcane Lineage`", inline = true }
                },
                footer = { text = "Arcane Lineage • Automated Intelligence System" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        end

        local payload = {
            username = "Arcane Lineage • Intelligence Alert",
            avatar_url = "https://cdn-icons-png.flaticon.com/512/1415/1415438.png",
            embeds = { embed }
        }

        local ok, res = pcall(function()
            return HttpRequest({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)

        if eventType == "Test" then
            if ok then
                ZeroLib:Notify({ Title = "Webhook Sent", Content = "Test Webhook sent successfully to Discord!", Type = "Success", Duration = 4 })
            else
                ZeroLib:Notify({ Title = "Webhook Error", Content = "Failed to send Test Webhook! Check URL.", Type = "Error", Duration = 4 })
            end
        end
    end)
end

-- 6. UNIVERSAL AUTO-ACCEPT & LOOT NOTIFICATION HOOK ENGINE
local AutoAcceptEngine = {
    keywords = { "accept", "accpet", "acc", "yes", "confirm", "ok", "take", "roll", "claim", "agree", "equip", "loot" },
}

local function getAcceptOption(data)
    if type(data) ~= "table" then return nil end
    for _, btnText in ipairs({ data.Button1, data.Button2 }) do
        if type(btnText) == "string" then
            local lower = btnText:lower()
            for _, kw in ipairs(AutoAcceptEngine.keywords) do
                if lower:find(kw) then
                    return btnText
                end
            end
        end
    end
    return data.Button1 or "Accept"
end

local function handleNotification(data)
    if type(data) ~= "table" or not data.Callback then return end

    local targetButton = getAcceptOption(data)
    if not targetButton then return end

    local title = tostring(data.Title or "")
    local text = tostring(data.Text or "")

    task.defer(function()
        task.wait(0.04)
        local success = false
        pcall(function()
            if typeof(data.Callback) == "Instance" then
                if data.Callback:IsA("BindableFunction") then
                    data.Callback:Invoke(targetButton)
                    success = true
                elseif data.Callback:IsA("BindableEvent") then
                    data.Callback:Fire(targetButton)
                    success = true
                end
            elseif type(data.Callback) == "function" then
                data.Callback(targetButton)
                success = true
            end
        end)

        if success then
            local displayInfo = (title ~= "" and title ~= "Item dropped!") and title or text
            print(string.format("[AutoLoot] ✅ Successfully pressed '%s' for drop notification: '%s' (%s)!", targetButton, title, text))
            
            pcall(function()
                ZeroLib:Notify({
                    Title = "Auto Loot Success",
                    Content = string.format("Auto received: %s", displayInfo),
                    Type = "Success",
                    Duration = 4
                })
            end)

            if AutoYarthul and AutoYarthul.running then
                AutoYarthul.updateHUD(string.format("🎁 Auto Accepted: %s", displayInfo))
                pcall(function()
                    AutoYarthul.sendWebhook("Loot", { itemName = text, droppedBy = title })
                end)
            end
        end
    end)
end

shared.ArcaneHandleNotification = handleNotification

function AutoYarthul.hookLootRemote()
    -- 1. Direct Server ItemDrop Hook (ReplicatedStorage.Remotes.Information.ItemDrop)
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local info = remotes and remotes:FindFirstChild("Information")
        local itemDrop = info and info:FindFirstChild("ItemDrop")
        if itemDrop and itemDrop:IsA("RemoteFunction") then
            itemDrop.OnClientInvoke = function(mobName, itemName)
                local mobStr = tostring(mobName or "Boss")
                local itemStr = tostring(itemName or "Item")
                
                print(string.format("[AutoLoot] 🎁 Server ItemDrop: %s dropped '%s' -> Auto-Accepted successfully!", mobStr, itemStr))
                
                pcall(function()
                    ZeroLib:Notify({
                        Title = "Auto Loot Success",
                        Content = string.format("Received item: %s (%s)", itemStr, mobStr),
                        Type = "Success",
                        Duration = 4
                    })
                end)

                if AutoYarthul and AutoYarthul.running then
                    AutoYarthul.updateHUD(string.format("🎁 Auto Accepted: %s", itemStr))
                    pcall(function()
                        AutoYarthul.sendWebhook("Loot", { itemName = itemStr, droppedBy = mobStr })
                    end)
                end

                return true
            end
        end
    end)

    if shared.ArcaneSetCoreHookInstalled then return end
    shared.ArcaneSetCoreHookInstalled = true

    -- 2. Hook game __namecall on StarterGui:SetCore("SendNotification")
    pcall(function()
        if hookmetamethod then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = { ... }

                if (self == StarterGui or tostring(self) == "StarterGui") and (method == "SetCore" or method == "setCore") then
                    if args[1] == "SendNotification" and type(args[2]) == "table" then
                        if shared.ArcaneHandleNotification then
                            shared.ArcaneHandleNotification(args[2])
                        end
                    end
                end

                return oldNamecall(self, ...)
            end)
        end
    end)

    -- 3. Hook function index fallback on StarterGui.SetCore
    pcall(function()
        if hookfunction and StarterGui.SetCore then
            local oldSetCore
            oldSetCore = hookfunction(StarterGui.SetCore, function(self, coreName, data, ...)
                if (coreName == "SendNotification" or tostring(coreName) == "SendNotification") and type(data) == "table" then
                    if shared.ArcaneHandleNotification then
                        shared.ArcaneHandleNotification(data)
                    end
                end
                return oldSetCore(self, coreName, data, ...)
            end)
        end
    end)

    -- 4. Visual cleanup: Remove lingering notification card from CoreGui
    task.spawn(function()
        pcall(function()
            local coreGui = game:GetService("CoreGui")
            local robloxGui = coreGui:WaitForChild("RobloxGui", 10)
            local notificationFrame = robloxGui and robloxGui:WaitForChild("NotificationFrame", 10)
            if not notificationFrame then return end

            notificationFrame.ChildAdded:Connect(function(card)
                task.wait(0.2)
                if card and card.Parent then
                    pcall(function() card:Destroy() end)
                end
            end)
        end)
    end)
end

AutoYarthul.hookLootRemote()

-- 7. Check if Refight UI is visible and active on screen (Main.Visible == true)
function AutoYarthul.isRefightActive()
    local pgui = PlayerGui
    if not pgui then return false, nil end

    -- DO NOT TRIGGER REFIGHT IF IN OVERWORLD (X > 0)
    if not AutoYarthul.isInsideInstance() and not AutoYarthul.hasFoughtBoss then
        return false, nil
    end

    local refightGui = pgui:FindFirstChild("Refight")
    if refightGui and refightGui.Enabled then
        local mainFrame = refightGui:FindFirstChild("Main")
        if mainFrame and mainFrame:IsA("GuiObject") and mainFrame.Visible then
            local yesBtn = mainFrame:FindFirstChild("Yes", true)
            if yesBtn and (yesBtn:IsA("TextButton") or yesBtn:IsA("ImageButton")) and yesBtn.Visible then
                return true, yesBtn
            end
        end
    end

    local bossReplay = pgui:FindFirstChild("BossReplay")
    if bossReplay and bossReplay.Enabled then
        local mainFrame = bossReplay:FindFirstChild("Main") or bossReplay:FindFirstChild("Frame") or bossReplay:FindFirstChild("Choices")
        if mainFrame and mainFrame:IsA("GuiObject") and mainFrame.Visible then
            local yesBtn = bossReplay:FindFirstChild("Yes", true)
            if yesBtn and (yesBtn:IsA("TextButton") or yesBtn:IsA("ImageButton")) and yesBtn.Visible then
                return true, yesBtn
            end
        end
    end

    return false, nil
end

function AutoYarthul.isBossDeadOrDown()
    -- TUYET DOI not CHECK BOSS DEAD NEU is O MAINGAME / OVERWORLD (X > 0)
    if not AutoYarthul.isInsideInstance() and not AutoYarthul.hasFoughtBoss then
        return false, "Overworld", nil
    end

    -- 1. Uu tien so 1: Neu has co bang Refight is HIEN TREN MAN HINH (Main.Visible == true)
    local isRefight, yesBtn = AutoYarthul.isRefightActive()
    if isRefight and yesBtn then
        return true, "RefightPrompt", yesBtn
    end

    -- 2. test mau Boss = 0
    local hp, maxHp, bossModel = AutoYarthul.getBossHealth()
    if bossModel and hp <= 0 then
        return true, "ZeroHP", nil
    end

    -- 3. test Boss nga xuong (model nam rap tren floor: UpVector.Y < 0.6)
    if bossModel then
        local hrp = bossModel:FindFirstChild("HumanoidRootPart") or bossModel:FindFirstChild("Torso") or bossModel.PrimaryPart
        if hrp then
            local upY = hrp.CFrame.UpVector.Y
            if upY < 0.6 then
                return true, "BossDown", nil
            end
        end
    end

    return false, "Alive", nil
end

-- 8. On-Screen Floating HUD Engine (Hien thi status & button [STOP AUTO FARM] now tren man hinh)
function AutoYarthul.createHUD()
    if AutoYarthul.floatingGui then
        pcall(function() AutoYarthul.floatingGui:Destroy() end)
        AutoYarthul.floatingGui = nil
    end

    pcall(function()
        local parentGui = (gethui and gethui()) or (game:GetService("CoreGui"):FindFirstChild("RobloxGui")) or PlayerGui
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "Arcane_Yarthul_HUD"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local mainCard = Instance.new("Frame")
        mainCard.Name = "MainCard"
        mainCard.Size = UDim2.new(0, 300, 0, 160)
        mainCard.Position = UDim2.new(0.02, 0, 0.48, 0)
        mainCard.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
        mainCard.BackgroundTransparency = 0.08
        mainCard.BorderSizePixel = 0
        mainCard.Active = true
        mainCard.Draggable = true
        mainCard.Parent = screenGui

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = mainCard

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.fromRGB(6, 182, 212) -- Cyber Cyan Glow
        cardStroke.Thickness = 1.5
        cardStroke.Parent = mainCard

        -- Topbar Header Badge
        local headerFrame = Instance.new("Frame")
        headerFrame.Name = "Header"
        headerFrame.Size = UDim2.new(1, -16, 0, 24)
        headerFrame.Position = UDim2.new(0, 8, 0, 6)
        headerFrame.BackgroundTransparency = 1
        headerFrame.Parent = mainCard

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, 0, 1, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "ARCANE HUB • FARM CONTROLLER"
        title.TextColor3 = Color3.fromRGB(240, 245, 255)
        title.TextSize = 11.5
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = headerFrame

        local divider = Instance.new("Frame")
        divider.Name = "Div"
        divider.Size = UDim2.new(1, -16, 0, 1)
        divider.Position = UDim2.new(0, 8, 0, 32)
        divider.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
        divider.BorderSizePixel = 0
        divider.Parent = mainCard

        -- Status Indicator
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Name = "StatusLabel"
        statusLabel.Size = UDim2.new(1, -20, 0, 18)
        statusLabel.Position = UDim2.new(0, 10, 0, 38)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Font = Enum.Font.GothamMedium
        statusLabel.Text = "Status: ⚡ Initializing..."
        statusLabel.TextColor3 = Color3.fromRGB(6, 182, 212)
        statusLabel.TextSize = 11
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.Parent = mainCard

        -- Target Indicator
        local targetLabel = Instance.new("TextLabel")
        targetLabel.Name = "TargetLabel"
        targetLabel.Size = UDim2.new(1, -20, 0, 16)
        targetLabel.Position = UDim2.new(0, 10, 0, 58)
        targetLabel.BackgroundTransparency = 1
        targetLabel.Font = Enum.Font.Gotham
        targetLabel.Text = "Target: 🐉 Yar'thul, the Blazing Dragon"
        targetLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
        targetLabel.TextSize = 10.5
        targetLabel.TextXAlignment = Enum.TextXAlignment.Left
        targetLabel.Parent = mainCard

        -- Kill Counter (Clean, No Retries/Wipes)
        local killLabel = Instance.new("TextLabel")
        killLabel.Name = "KillLabel"
        killLabel.Size = UDim2.new(1, -20, 0, 18)
        killLabel.Position = UDim2.new(0, 10, 0, 76)
        killLabel.BackgroundTransparency = 1
        killLabel.Font = Enum.Font.GothamBold
        killLabel.Text = string.format("🏆 Boss Kills: %d", AutoYarthul.bossKillCount)
        killLabel.TextColor3 = Color3.fromRGB(16, 185, 129) -- Emerald Green
        killLabel.TextSize = 11.5
        killLabel.TextXAlignment = Enum.TextXAlignment.Left
        killLabel.Parent = mainCard

        -- Last Drop Info
        local dropLabel = Instance.new("TextLabel")
        dropLabel.Name = "DropLabel"
        dropLabel.Size = UDim2.new(1, -20, 0, 16)
        dropLabel.Position = UDim2.new(0, 10, 0, 96)
        dropLabel.BackgroundTransparency = 1
        dropLabel.Font = Enum.Font.GothamMedium
        dropLabel.Text = "Drops: " .. tostring(AutoYarthul.lastDroppedSummary)
        dropLabel.TextColor3 = Color3.fromRGB(245, 158, 11) -- Amber
        dropLabel.TextSize = 10.5
        dropLabel.TextXAlignment = Enum.TextXAlignment.Left
        dropLabel.Parent = mainCard

        -- STOP AUTO FARM BUTTON (Sleek Crimson Pill)
        local stopBtn = Instance.new("TextButton")
        stopBtn.Name = "StopButton"
        stopBtn.Size = UDim2.new(1, -20, 0, 28)
        stopBtn.Position = UDim2.new(0, 10, 0, 122)
        stopBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72) -- Rose / Crimson
        stopBtn.BorderSizePixel = 0
        stopBtn.Font = Enum.Font.GothamBold
        stopBtn.Text = "■ STOP AUTO FARM"
        stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        stopBtn.TextSize = 11.5
        stopBtn.AutoButtonColor = true
        stopBtn.Parent = mainCard

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = stopBtn

        stopBtn.MouseButton1Click:Connect(function()
            hubLog("[AutoYarthul] 🛑 [STOP AUTO FARM] clicked -> Stopping farm cycle!")
            AutoYarthul.stop(true)
            if Toggles.AutoFarmYarthul then
                Toggles.AutoFarmYarthul:SetValue(false)
            end
        end)

        screenGui.Parent = parentGui
        AutoYarthul.floatingGui = screenGui
    end)
end

function AutoYarthul.destroyHUD()
    if AutoYarthul.floatingGui then
        pcall(function() AutoYarthul.floatingGui:Destroy() end)
        AutoYarthul.floatingGui = nil
    end
end

function AutoYarthul.updateHUD(statusText)
    if not AutoYarthul.floatingGui then return end
    pcall(function()
        local card = AutoYarthul.floatingGui:FindFirstChild("MainCard")
        if not card then return end
        if statusText then
            local sl = card:FindFirstChild("StatusLabel")
            if sl then sl.Text = "Status: " .. tostring(statusText) end
        end
        local kl = card:FindFirstChild("KillLabel")
        if kl then
            kl.Text = string.format("🏆 Boss Kills: %d", AutoYarthul.bossKillCount)
        end
        local dl = card:FindFirstChild("DropLabel")
        if dl then
            dl.Text = "Drops: " .. tostring(AutoYarthul.lastDroppedSummary)
        end
    end)
end

function AutoYarthul.saveSession()
    pcall(function()
        if writefile then
            local payload = {
                active = true,
                placeId = game.PlaceId,
                gameId = game.GameId,
                jobId = game.JobId,
                kills = AutoYarthul.bossKillCount,
                retries = AutoYarthul.deathCount,
                timestamp = os.time(),
            }
            writefile(AutoYarthul.sessionFile, HttpService:JSONEncode(payload))
        end
    end)

    pcall(function()
        if queueTeleportScript then
            queueTeleportScript(false)
        end
    end)
end

function AutoYarthul.clearSession()
    pcall(function()
        if isfile and isfile(AutoYarthul.sessionFile) and delfile then
            delfile(AutoYarthul.sessionFile)
        end
    end)
end

function AutoYarthul.checkSessionOnBoot()
    pcall(function()
        if isfile and isfile(AutoYarthul.sessionFile) and readfile then
            local content = readfile(AutoYarthul.sessionFile)
            local data = HttpService:JSONDecode(content)
            if data and data.active == true then
                local delta = os.time() - (data.timestamp or 0)
                if delta < 3600 then
                    AutoYarthul.bossKillCount = data.kills or 0
                    AutoYarthul.deathCount = data.retries or 0
                    AutoYarthul.isRestoring = true
                    
                    local inInstance = AutoYarthul.isInsideInstance()
                    hubLog(string.format("[AutoYarthul] 🔄 Restoring Yar'thul Auto Farm session (Kills: %d, Retries: %d, InInstance: %s)!", AutoYarthul.bossKillCount, AutoYarthul.deathCount, tostring(inInstance)))
                    
                    task.spawn(function()
                        local waited = 0
                        while not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") do
                            task.wait(0.5)
                            waited = waited + 0.5
                            if waited > 15 then break end
                        end
                        task.wait(1.2)

                        -- Tat triet de cac Tab Auto Farm khac de tranh xung dot
                        if Toggles.AutoFarmLevel and Toggles.AutoFarmLevel.Value then Toggles.AutoFarmLevel:SetValue(false) end
                        if Toggles.AutoFarmCrylight and Toggles.AutoFarmCrylight.Value then Toggles.AutoFarmCrylight:SetValue(false) end
                        if Toggles.AutoMineOre and Toggles.AutoMineOre.Value then Toggles.AutoMineOre:SetValue(false) end
                        if LevelFarmer then LevelFarmer.stop() end
                        if Farmer then Farmer.stop() end
                        if Miner then Miner.stop() end

                        if Toggles.AutoFarmYarthul then
                            Toggles.AutoFarmYarthul:SetValue(true)
                        else
                            AutoYarthul.start()
                        end
                        AutoYarthul.isRestoring = false
                        Library:Notify(string.format("🔄 Auto Farm Yar'thul Resumed (Kills: %d)!", AutoYarthul.bossKillCount), 5)
                    end)
                else
                    AutoYarthul.clearSession()
                end
            end
        end
    end)
end

-- 10. HE THONG AUTO LOOT items & SKIP INTRO
function AutoYarthul.handleAutoLoot()
    -- A. auto BAM PLAY / START / LOAD SLOT / SKIP CUTSCENE KHI VAO GAME
    pcall(function()
        local pgui = PlayerGui
        if pgui then
            -- 1. Skip Intro Cutscene button
            for _, desc in ipairs(pgui:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                    local name = desc.Name:lower()
                    local text = desc:IsA("TextButton") and desc.Text:lower() or ""
                    if (name:find("skip") or text:find("skip")) and not name:find("stop") and not text:find("stop") and not name:find("restart") then
                        safeClickButton(desc)
                    end
                end
            end

            -- 2. MainMenu Play / Load Slot / Start Game
            local mainMenu = pgui:FindFirstChild("MainMenu")
            if mainMenu and mainMenu.Enabled then
                for _, btn in ipairs(mainMenu:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                        local bname = btn.Name:lower()
                        local btext = btn:IsA("TextButton") and btn.Text:lower() or ""
                        if bname:find("play") or btext:find("play") or bname:find("start") or btext:find("start") or bname:find("load") or btext:find("load") or bname:find("slot") or bname:find("spawn") then
                            hubLog(string.format("[AutoSkip] 🎮 auto bam '%s' tren MainMenu de vao game!", btn.Name))
                            safeClickButton(btn)
                        end
                    end
                end
            end

            -- 3. Title / Intro ScreenGuis
            local titleGui = pgui:FindFirstChild("Title") or pgui:FindFirstChild("Intro") or pgui:FindFirstChild("Loading")
            if titleGui and titleGui.Enabled then
                for _, btn in ipairs(titleGui:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                        safeClickButton(btn)
                    end
                end
            end
        end
    end)

    -- B. Quet & Thu hoach cac items dropped under floor (Ground Loot in SpawnedItems / Drops)
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local lootContainers = {
            workspace:FindFirstChild("SpawnedItems"),
            workspace:FindFirstChild("Drops"),
            workspace:FindFirstChild("Ores"),
            workspace:FindFirstChild("Living")
        }

        for _, container in ipairs(lootContainers) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    local itemPos = item:IsA("BasePart") and item.Position or (item:IsA("Model") and item:GetPivot().Position)
                    if itemPos then
                        local dist = (itemPos - root.Position).Magnitude
                        if dist <= 60 then
                            for _, prompt in ipairs(item:GetDescendants()) do
                                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                                    if fireproximityprompt then
                                        fireproximityprompt(prompt, 0)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- 11. test CHINH XAC 100% FLAME / MAGMA PILLAR (GEYSER) TREN SAN DAU
function AutoYarthul.hasFlamePillar()
    local foundPillar = false

    -- A. test truc tiep trong Boss.Effects (MPillar BoolValue hoac LastUsedAttack)
    pcall(function()
        local living = workspace:FindFirstChild("Living")
        if living then
            for _, m in ipairs(living:GetChildren()) do
                if m:IsA("Model") and (m.Name:lower():find("yar") or m.Name:lower():find("thul") or m.Name:lower():find("dragon")) then
                    local effects = m:FindFirstChild("Effects") or m:FindFirstChild("Status")
                    if effects then
                        local mpillar = effects:FindFirstChild("MPillar") or effects:FindFirstChild("Pillar") or effects:FindFirstChild("FlamePillar") or effects:FindFirstChild("MagmaPillar")
                        if mpillar then
                            hubLog(string.format("[AutoYarthul] 🔥 [Boss.Effects] detected Pillar '%s' tren Yar'thul -> Khoa Carnage!", mpillar.Name))
                            foundPillar = true
                            return
                        end
                        local lastAtk = effects:FindFirstChild("LastUsedAttack")
                        if lastAtk and typeof(lastAtk.Value) == "string" and lastAtk.Value:lower():find("pillar") then
                            hubLog(string.format("[AutoYarthul] 🔥 [Boss LastUsedAttack] '%s' -> Khoa Carnage!", lastAtk.Value))
                            foundPillar = true
                            return
                        end
                    end
                end
            end
        end
    end)
    if foundPillar then return true end

    -- B. test trong Workspace.Effects (Geyser Part / Model voi Sound Idle & Particle)
    pcall(function()
        local effects = workspace:FindFirstChild("Effects")
        if effects then
            for _, ef in ipairs(effects:GetChildren()) do
                local ename = ef.Name:lower()
                if ename:find("geyser") or ename:find("pillar") or ename:find("flame") or ename:find("magma") or ename:find("lava") or ename:find("fire") then
                    hubLog(string.format("[AutoYarthul] 🔥 [Workspace.Effects] detected Flame/Magma Pillar '%s' -> Khoa Carnage!", ef.Name))
                    foundPillar = true
                    return
                end
            end
        end
    end)
    if foundPillar then return true end

    -- C. test GetOtherTeam remote (neu Pillar duoc tinh la 1 entity doi thu rieng)
    pcall(function()
        local char = LocalPlayer.Character
        local fip = char and char:FindFirstChild("FightInProgress")
        if fip and fip.Value then
            local getOtherTeam = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Data") and ReplicatedStorage.Remotes.Data:FindFirstChild("GetOtherTeam")
            if getOtherTeam then
                local otherTeam = getOtherTeam:InvokeServer(fip.Value)
                if type(otherTeam) == "table" and #otherTeam > 0 then
                    for _, enemy in ipairs(otherTeam) do
                        if enemy and enemy.Name then
                            local ename = enemy.Name:lower()
                            if ename:find("pillar") or ename:find("geyser") or ename:find("flame") or ename:find("fire") or ename:find("lava") or ename:find("magma") then
                                hubLog(string.format("[AutoYarthul] 🔥 [GetOtherTeam] detected Flame Pillar: '%s' -> Khoa Carnage!", enemy.Name))
                                foundPillar = true
                                return
                            elseif not ename:find("yar") and not ename:find("thul") and not ename:find("dragon") then
                                hubLog(string.format("[AutoYarthul] 🔥 [GetOtherTeam] detected muc tieu phu: '%s' -> Khoa Carnage!", enemy.Name))
                                foundPillar = true
                                return
                            end
                        end
                    end
                end
            end
        end
    end)
    if foundPillar then return true end

    -- D. Quet toan bo cac Part/Model nearby arena
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local myPos = root and root.Position or AutoYarthul.spawnPosition
        local checkFolders = { workspace:FindFirstChild("Effects"), workspace:FindFirstChild("Debris"), workspace:FindFirstChild("Living"), workspace }
        for _, folder in ipairs(checkFolders) do
            if folder then
                for _, obj in ipairs(folder:GetChildren()) do
                    if obj ~= char then
                        local oname = obj.Name:lower()
                        if oname:find("geyser") or oname:find("flame pillar") or oname:find("flamepillar") or oname:find("magmapillar") or oname:find("magma pillar") then
                            local objPos = obj:IsA("BasePart") and obj.Position or (obj:IsA("Model") and obj:GetPivot().Position)
                            if objPos and (objPos - myPos).Magnitude <= 150 then
                                hubLog(string.format("[AutoYarthul] 🔥 [Arena Scan] detected Pillar/Geyser '%s' cach %.1f studs -> Khoa Carnage!", obj.Name, (objPos - myPos).Magnitude))
                                foundPillar = true
                                return
                            end
                        end
                    end
                end
            end
        end
    end)

    return foundPillar
end

-- 12. Trich xuat nang luong combat (Player Combat Energy)
function AutoYarthul.getPlayerEnergy()
    local char = LocalPlayer.Character
    local status = char and (char:FindFirstChild("Status") or char:FindFirstChild("Effects") or char:FindFirstChild("Values"))
    local energyVal = status and status:FindFirstChild("Energy")
    if energyVal and typeof(energyVal.Value) == "number" then
        return energyVal.Value
    end

    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if combatGui then
        local curEnergyFrame = combatGui:FindFirstChild("CurrentEnergy", true)
        local amountLabel = curEnergyFrame and curEnergyFrame:FindFirstChild("Amount")
        if amountLabel and amountLabel.Text then
            local num = tonumber(amountLabel.Text:match("^(%d+)"))
            if num then return num end
        end

        local energyContainer = combatGui:FindFirstChild("Energy", true)
        if energyContainer then
            local activeCount = 0
            for _, bar in ipairs(energyContainer:GetChildren()) do
                if bar:IsA("GuiObject") and bar.BackgroundTransparency < 0.5 then
                    activeCount = activeCount + 1
                end
            end
            if activeCount > 0 then return activeCount end
        end
    end

    return 0
end

-- 13. auto XU LY REFIGHT (BAM button YES TREN BANG REFIGHT & TUA THOAI after KHI DIET BOSS)
function AutoYarthul.interactRefight()
    local pgui = PlayerGui
    if not pgui then return end

    -- TUYET DOI not CHAY NEU is O MAINGAME / OVERWORLD (X > 0)
    if not AutoYarthul.isInsideInstance() and not AutoYarthul.hasFoughtBoss then
        return
    end

    -- A. Bam truc tiep button YES tren ScreenGui 'Refight' hoac 'BossReplay'
    pcall(function()
        local isRefight, yesBtn = AutoYarthul.isRefightActive()
        if isRefight and yesBtn then
            hubLog(string.format("[AutoYarthul]  Bam button YES tren bang Refight: '%s'!", yesBtn.Name))
            safeClickButton(yesBtn)
            task.wait(0.2)
            return
        end

        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "LinoriaGui" and gui.Name ~= "Arcane_Yarthul_HUD" then
                local gname = gui.Name:lower()
                if gname:find("refight") or gname:find("replay") or gname:find("boss") or gname:find("dialogue") then
                    local mainF = gui:FindFirstChild("Main") or gui:FindFirstChild("Frame") or gui:FindFirstChild("Choices")
                    if mainF and mainF:IsA("GuiObject") and mainF.Visible then
                        for _, btn in ipairs(mainF:GetDescendants()) do
                            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                                local txt = (btn:IsA("TextButton") and btn.Text or btn.Name):lower()
                                if txt == "yes" or txt:find("refight") or txt:find("again") or txt:find("solo") or txt:find("replay") then
                                    if not txt:find("no") and not txt:find("cancel") and not txt:find("decline") and not txt:find("leave") and not txt:find("lobby") then
                                        hubLog(string.format("[AutoYarthul]  Bam button Refight / Danh tiep: '%s' tren '%s'", btn.Name, gui.Name))
                                        safeClickButton(btn)
                                        task.wait(0.2)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- B. Tua text thoai cua Boss after tran danh
    pcall(function()
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "LinoriaGui" and gui.Name ~= "Arcane_Yarthul_HUD" then
                local gname = gui.Name:lower()
                if gname:find("dialogue") or gname:find("boss") or gname:find("prompt") or gname:find("talk") then
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if (obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("Frame")) and obj.Visible then
                            local oname = obj.Name:lower()
                            if oname:find("desc") or oname:find("main") or oname:find("textholder") or oname:find("dialoguebox") or oname:find("text") or oname:find("continue") then
                                safeClickButton(obj)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- 14. TUONG TAC gate NGOAI TRAN (CHI CHAY KHI is DUNG nearby gate arena & not yet VAO TRAN)
function AutoYarthul.interactGate()
    if tick() - AutoYarthul.lastGateInteractTime < 2.5 then return end
    AutoYarthul.lastGateInteractTime = tick()

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- A. Bam ProximityPrompt tai gate neu co
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            local part = desc.Parent:IsA("BasePart") and desc.Parent or (desc.Parent:FindFirstChildWhichIsA("BasePart", true))
            if part then
                local dist = (part.Position - root.Position).Magnitude
                if dist <= 30 then
                    hubLog(string.format("[AutoYarthul]  Tim thay gate ProximityPrompt '%s' tai distance %.1f studs -> activate vao tran!", desc.ActionText or desc.Name, dist))
                    AutoYarthul.updateHUD(" is activate gate Boss...")
                    if fireproximityprompt then
                        fireproximityprompt(desc, 0)
                    end
                    task.wait(0.5)
                    break
                end
            end
        end
    end

    -- B. Neu co bang select "Enter" / "Fight" / "Solo" khi vua bam gate -> Bam 1 lan
    pcall(function()
        local pgui = PlayerGui
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "LinoriaGui" and gui.Name ~= "Arcane_Yarthul_HUD" then
                local gname = gui.Name:lower()
                if gname:find("dialogue") or gname:find("boss") or gname:find("prompt") or gname:find("enter") or gname:find("gate") then
                    for _, btn in ipairs(gui:GetDescendants()) do
                        if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                            local txt = (btn:IsA("TextButton") and btn.Text or btn.Name):lower()
                            if txt:find("enter") or txt:find("fight") or txt:find("solo") or txt:find("begin") or txt:find("yes") or txt:find("start") then
                                if not txt:find("no") and not txt:find("cancel") and not txt:find("decline") and not txt:find("leave") then
                                    hubLog(string.format("[AutoYarthul]  Bam button vao gate: '%s' tren '%s'", btn.Name, gui.Name))
                                    safeClickButton(btn)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- 15. Vong lap chinh dieu phoi Auto Farm, Auto Retry & Auto Loot Yar'thul (Endless Loop)
function AutoYarthul.start()
    if AutoYarthul.running then return end
    AutoYarthul.running = true
    AutoYarthul.wasInCombat = false
    AutoYarthul.hasFoughtBoss = false
    AutoYarthul.lastUsedSkill = ""
    AutoYarthul.turnExecutionLock = false
    AutoYarthul.inventoryBaseline = AutoYarthul.getInventorySnapshot()

    -- Dam bao tat tat ca cac Auto Farm khac de tranh chay song song gay xung dot
    if Toggles.AutoFarmLevel and Toggles.AutoFarmLevel.Value then Toggles.AutoFarmLevel:SetValue(false) end
    if Toggles.AutoFarmCrylight and Toggles.AutoFarmCrylight.Value then Toggles.AutoFarmCrylight:SetValue(false) end
    if Toggles.AutoMineOre and Toggles.AutoMineOre.Value then Toggles.AutoMineOre:SetValue(false) end
    if LevelFarmer then LevelFarmer.stop() end
    if Farmer then Farmer.stop() end
    if Miner then Miner.stop() end

    -- Auto override settings for Auto Combat when Auto Farm Yar'thul is active
    if Toggles.AutoFight and not Toggles.AutoFight.Value then
        Toggles.AutoFight:SetValue(true)
    elseif AutoFight and not AutoFight.running then
        AutoFight.start()
    end

    if Options.SelectedCombatAction then
        Options.SelectedCombatAction:SetValue("Auto Smart (Best Skill -> Strike)")
    end
    if Options.CombatExecutionMode then
        Options.CombatExecutionMode:SetValue("Direct Remote (Fastest + Sub-actions)")
    end
    if Options.TargetPriority then
        Options.TargetPriority:SetValue("First Enemy")
    end

    -- GAN DIRECT REMOTE HOOKS now KHI BAT AUTO FARM
    AutoYarthul.hookLootRemote()

    AutoYarthul.saveSession()
    AutoYarthul.createHUD()

    if Toggles.AutoCombatQTE and not Toggles.AutoCombatQTE.Value then
        Toggles.AutoCombatQTE:SetValue(true)
    end

    -- A. THIET LAP LUONG AUTO LOOT DO under DAT & SKIP INTRO
    if AutoYarthul.lootThread then
        pcall(function() task.cancel(AutoYarthul.lootThread) end)
        AutoYarthul.lootThread = nil
    end

    AutoYarthul.lootThread = task.spawn(function()
        while AutoYarthul.running do
            pcall(function()
                AutoYarthul.handleAutoLoot()
            end)
            task.wait(0.5)
        end
    end)

    -- B. auto theo doi khi nhan vat respawn (Auto Retry on Respawn / Wipe)
    if not AutoYarthul.charAddedConn then
        AutoYarthul.charAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
            if AutoYarthul.running then
                hubLog("[AutoYarthul] 🔄 Nhan vat respawn / switch canh -> preparing auto Retry fly again gate Yar'thul!")
                AutoYarthul.deathCount = AutoYarthul.deathCount + 1
                AutoYarthul.wasInCombat = false
                AutoYarthul.hasFoughtBoss = false
                AutoYarthul.lastUsedSkill = ""
                AutoYarthul.turnExecutionLock = false
                AutoYarthul.inventoryBaseline = AutoYarthul.getInventorySnapshot()
                AutoYarthul.saveSession()
                AutoYarthul.updateHUD("🔄 Nhan vat respawn -> preparing Retry...")
                task.spawn(function()
                    task.wait(1.5)
                    local root = newChar:WaitForChild("HumanoidRootPart", 10)
                    if root and AutoYarthul.running then
                        hubLog("[AutoYarthul]  Nhan vat has ready -> activate cycle fly!")
                    end
                end)
            end
        end)
    end

    if AutoYarthul.thread then
        pcall(function() task.cancel(AutoYarthul.thread) end)
        AutoYarthul.thread = nil
    end

    AutoYarthul.thread = task.spawn(function()
        hubLog("[AutoYarthul]  start cycle Auto Farm & Auto Retry Yar'thul!")
        Library:Notify(" Auto Farm & Auto Retry Yar'thul Activated!", 4)

        while AutoYarthul.running do
            pcall(function()
                -- test status REFIGHT / BOSS has CHET HOAC NGA TREN floor before TIEN
                local isDeadOrDown, deadReason, refightYesBtn = AutoYarthul.isBossDeadOrDown()

                -- 1. TRUONG HOP 1: BOSS has BI HA GUC HOAC BANG REFIGHT is HIEN (CHI CHAY KHI is TRONG INSTANCE)
                if isDeadOrDown and AutoYarthul.isInsideInstance() then
                    AutoYarthul.wasInCombat = false
                    AutoYarthul.hasFoughtBoss = false
                    AutoYarthul.bossKillCount = AutoYarthul.bossKillCount + 1
                    AutoYarthul.lastUsedSkill = ""
                    AutoYarthul.turnExecutionLock = false
                    AutoYarthul.saveSession()

                    AutoYarthul.updateHUD(string.format(" has ha guc Yar'thul! (Kills: %d) -> wait test Drop...", AutoYarthul.bossKillCount))
                    hubLog(string.format("[AutoYarthul]  Yar'thul has bi ha guc (Ly do: %s)! total so lan ha guc: %d. is test Drop trong kho...", deadReason, AutoYarthul.bossKillCount))

                    -- Bam now lap tuc button YES tren bang Refight neu co
                    if refightYesBtn then
                        safeClickButton(refightYesBtn)
                    end

                    -- wait 1.5s de server allocated toan bo Drop / Artifact vao inventory
                    task.wait(1.5)
                    local detectedDrops = AutoYarthul.detectInventoryDrops()
                    local dropSummaryStr = ""
                    if #detectedDrops > 0 then
                        for _, item in ipairs(detectedDrops) do
                            dropSummaryStr = dropSummaryStr .. string.format("• **%s**: +%d\n", item.name, item.count)
                            hubLog(string.format("[AutoYarthul Loot Detect]  receive duoc Drop: %s (x%d)!", item.name, item.count))
                        end
                        AutoYarthul.lastDroppedSummary = string.format("%s (+%d)", detectedDrops[1].name, detectedDrops[1].count)
                        if #detectedDrops > 1 then
                            AutoYarthul.lastDroppedSummary = AutoYarthul.lastDroppedSummary .. string.format(" +%d mon khac", #detectedDrops - 1)
                        end
                        Library:Notify(string.format(" receive Drop moi: %s", detectedDrops[1].name), 6)
                    else
                        dropSummaryStr = "• not co items moi (hoac has max stack)"
                        AutoYarthul.lastDroppedSummary = "not co drop moi"
                    end

                    -- GUI DISCORD WEBHOOK CHI TIET TAT CA DROPS DUOC THEM VAO inventory
                    AutoYarthul.sendWebhook("Kill", { dropStr = dropSummaryStr, drops = detectedDrops })
                    AutoYarthul.updateHUD(string.format(" Ha guc #%d | Drop: %s", AutoYarthul.bossKillCount, AutoYarthul.lastDroppedSummary))

                    -- Bam Refight lien tuc trong 3.5s
                    local postTimer = 0
                    while postTimer < 3.5 and AutoYarthul.running and AutoYarthul.isInsideInstance() do
                        AutoYarthul.interactRefight()
                        task.wait(0.2)
                        postTimer = postTimer + 0.2
                    end

                -- 2. TRUONG HOP 2: is TRONG TRAN CHIEN (BOSS CON SONG & DUNG TREN floor)
                elseif isInCombat() then
                    if not AutoYarthul.wasInCombat then
                        -- start tran chien moi -> Chup again snapshot inventory before tran
                        AutoYarthul.inventoryBaseline = AutoYarthul.getInventorySnapshot()
                    end
                    AutoYarthul.wasInCombat = true
                    AutoYarthul.hasFoughtBoss = true

                    local bossHp, bossMaxHp, bossModel = AutoYarthul.getBossHealth()
                    if bossModel and bossMaxHp > 0 then
                        local hpPercent = math.clamp((bossHp / bossMaxHp) * 100, 0, 100)
                        AutoYarthul.updateHUD(string.format(" is danh Yar'thul [HP: %.0f/%.0f (%.0f%%)]", bossHp, bossMaxHp, hpPercent))
                    else
                        AutoYarthul.updateHUD(" is trong tran danh voi Yar'thul...")
                    end

                    if isPlayerTurn() and not combatTurnLock and not AutoYarthul.turnExecutionLock then
                        local combatDelay = (Options.CombatDelay and Options.CombatDelay.Value) or 0.05
                        if combatDelay > 0 then task.wait(combatDelay) end
                        if isPlayerTurn() and not combatTurnLock and not AutoYarthul.turnExecutionLock then
                            executeCombatTurn()
                        end
                    elseif not isPlayerTurn() then
                        AutoYarthul.turnExecutionLock = false
                        task.wait(0.1)
                    else
                        task.wait(0.1)
                    end

                -- 3. TRUONG HOP 3: NGOAI TRAN (DI switch, DUNG gate & VAO TRAN - TUYET DOI not BAM REFIGHT)
                else
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")

                    if root and hum and hum.Health > 0 then
                        local distToGate = (root.Position - AutoYarthul.gatePosition).Magnitude
                        local distToSpawn = (root.Position - AutoYarthul.spawnPosition).Magnitude

                        -- A. NEU is O SAT gate (<= 25 studs): activate gate vao tran
                        if distToGate <= 25 then
                            AutoYarthul.updateHUD(" is o gate Boss -> activate vao tran...")
                            AutoYarthul.interactGate()
                            task.wait(1.0)

                        -- B. NEU is O points SPAWN TRONG INSTANCE (<= 45 studs): Tween toi gate nearby do (~59 studs)
                        elseif distToSpawn <= 45 and root.Position.X < -200 then
                            AutoYarthul.updateHUD(string.format(" Tween tu Spawn toi gate Boss (%.0f studs)...", distToGate))
                            smoothTweenTo(CFrame.new(AutoYarthul.gatePosition), 160, function() return AutoYarthul.running and not isInCombat() end, false)
                            disableFlightState()
                            task.wait(0.3)

                        -- C. NEU is O XA NGOAI OVERWORLD (vua Respawn o lang hoac chay tu xa): Sky-Tween fly toi gate Mount Thul
                        else
                            AutoYarthul.updateHUD(string.format(" fly toi gate Mount Thul (%.0f studs)...", distToGate))
                            local speed = (Options.YarthulTweenSpeed and Options.YarthulTweenSpeed.Value) or 220
                            local height = 1500
                            local currentPos = root.Position
                            local skyY = math.max(height, currentPos.Y + 200, AutoYarthul.gatePosition.Y + 200)

                            local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), speed, function() return AutoYarthul.running and not isInCombat() end, true)
                            if s1 and AutoYarthul.running and not isInCombat() then
                                local s2 = smoothTweenTo(CFrame.new(AutoYarthul.gatePosition.X, skyY, AutoYarthul.gatePosition.Z), speed, function() return AutoYarthul.running and not isInCombat() end, true)
                                if s2 and AutoYarthul.running and not isInCombat() then
                                    smoothTweenTo(CFrame.new(AutoYarthul.gatePosition), 180, function() return AutoYarthul.running and not isInCombat() end, true)
                                end
                            end
                            disableFlightState()
                            task.wait(0.5)
                        end
                    else
                        task.wait(0.5)
                    end
                end
            end)

            task.wait(0.2)
        end

        hubLog("[AutoYarthul] ⏹️ has stop cycle Auto Farm Yar'thul.")
        AutoYarthul.destroyHUD()
    end)
end

function AutoYarthul.stop(explicit)
    AutoYarthul.running = false
    if explicit or not AutoYarthul.isRestoring then
        AutoYarthul.clearSession()
    end
    AutoYarthul.destroyHUD()
    if AutoYarthul.thread then
        pcall(function() task.cancel(AutoYarthul.thread) end)
        AutoYarthul.thread = nil
    end
    if AutoYarthul.lootThread then
        pcall(function() task.cancel(AutoYarthul.lootThread) end)
        AutoYarthul.lootThread = nil
    end
    if AutoYarthul.refightConn then
        pcall(function() AutoYarthul.refightConn:Disconnect() end)
        AutoYarthul.refightConn = nil
    end
    if AutoYarthul.charAddedConn then
        pcall(function() AutoYarthul.charAddedConn:Disconnect() end)
        AutoYarthul.charAddedConn = nil
    end
    -- Khi tat Auto Yar'thul, auto tat luon Auto Combat neu nguoi dung not tu bat toggle Auto Fight rieng
    if AutoFight and not (Toggles.AutoFight and Toggles.AutoFight.Value) then
        AutoFight.stop()
    end
    disableFlightState()
    hubLog("[AutoYarthul] Da tat Auto Farm Yar'thul!")
    Library:Notify(" Auto Farm Yar'thul Stopped!", 3)
end

HubState.isSummonTurnActive = false
HubState.currentTurnSkills = {}

pcall(function()
    local rep = game:GetService("ReplicatedStorage")
    local remotes = rep:FindFirstChild("Remotes")
    local fightRemotes = remotes and remotes:FindFirstChild("Fight")
    local infoRemotes = remotes and remotes:FindFirstChild("Information")

    if fightRemotes then
        local startSummon = fightRemotes:FindFirstChild("StartSummonedAction")
        if startSummon and startSummon:IsA("RemoteEvent") then
            startSummon.OnClientEvent:Connect(function()
                HubState.isSummonTurnActive = true
            end)
        end

        local startAction = fightRemotes:FindFirstChild("StartAction")
        if startAction and startAction:IsA("RemoteEvent") then
            startAction.OnClientEvent:Connect(function()
                HubState.isSummonTurnActive = false
            end)
        end

        local endFight = fightRemotes:FindFirstChild("EndFight")
        if endFight and endFight:IsA("RemoteEvent") then
            endFight.OnClientEvent:Connect(function()
                HubState.isSummonTurnActive = false
                table.clear(HubState.currentTurnSkills)
            end)
        end
    end

    if infoRemotes then
        local updateSkills = infoRemotes:FindFirstChild("UpdateSkills")
        if updateSkills and updateSkills:IsA("RemoteEvent") then
            updateSkills.OnClientEvent:Connect(function(skillsList)
                if type(skillsList) == "table" then
                    HubState.currentTurnSkills = skillsList
                end
            end)
        end
    end
end)

local AutoFight = {
    running = false,
    thread = nil,
}

local function executeDirectRemoteTurn()
    local pti = game.ReplicatedStorage:FindFirstChild("PlayerTurnInput")
    if not pti or not pti:IsA("RemoteFunction") then return false end

    local char = LocalPlayer.Character
    local fip = char and char:FindFirstChild("FightInProgress")
    if not fip then return false end

    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    local actionChoice = (Options.SelectedCombatAction and Options.SelectedCombatAction.Value) or (Options.CombatAction and Options.CombatAction.Value) or "Auto Smart"
    local shouldMeditateIfNoSkill = (Toggles.CombatMeditate and Toggles.CombatMeditate.Value) or false
    local targetPrio = (Options.TargetPriority and Options.TargetPriority.Value) or "First Enemy"
    local subAction = (Options.CombatSubAction and Options.CombatSubAction.Value) or "None"

    local isYarthulActive = (AutoYarthul and AutoYarthul.running) or (AutoYarthul and AutoYarthul.isInsideInstance and AutoYarthul.isInsideInstance())

    -- 1. Authoritative Summon Turn Detection
    local isSummon = HubState.isSummonTurnActive
    if not isSummon and combatGui then
        local deciding = combatGui:FindFirstChild("Deciding")
        if deciding and deciding.Visible then
            local txt = deciding:FindFirstChildWhichIsA("TextLabel", true) and deciding:FindFirstChildWhichIsA("TextLabel", true).Text:lower() or ""
            if txt ~= "" and not txt:find(LocalPlayer.Name:lower()) then
                isSummon = true
            end
        end
    end

    -- 2. Find target enemy
    local targetEnemy = nil
    if isYarthulActive and AutoYarthul.getBossHealth then
        local _, _, bossModel = AutoYarthul.getBossHealth()
        if bossModel and bossModel.Parent then
            targetEnemy = bossModel
        end
    end

    if not targetEnemy then
    pcall(function()
        local getOtherTeam = game.ReplicatedStorage:FindFirstChild("Remotes") and game.ReplicatedStorage.Remotes:FindFirstChild("Data") and game.ReplicatedStorage.Remotes.Data:FindFirstChild("GetOtherTeam")
        if getOtherTeam then
            local otherTeam = getOtherTeam:InvokeServer(fip.Value)
            if otherTeam and #otherTeam > 0 then
                local aliveEnemies = {}
                for _, e in ipairs(otherTeam) do
                    if e and e.Parent and e:FindFirstChildOfClass("Humanoid") and e:FindFirstChildOfClass("Humanoid").Health > 0 then
                        table.insert(aliveEnemies, e)
                    end
                end
                if #aliveEnemies > 0 then
                    if targetPrio == "Last Enemy" then
                        targetEnemy = aliveEnemies[#aliveEnemies]
                    elseif targetPrio == "Random Enemy" then
                        targetEnemy = aliveEnemies[math.random(1, #aliveEnemies)]
                    else
                        targetEnemy = aliveEnemies[1]
                    end
                end
            end
        end
    end)

    if not targetEnemy then
        local living = workspace:FindFirstChild("Living")
        if living then
            for _, m in ipairs(living:GetChildren()) do
                if m ~= char and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChildOfClass("Humanoid").Health > 0 then
                    local mfip = m:FindFirstChild("FightInProgress")
                    if mfip and mfip.Value == fip.Value then
                        targetEnemy = m
                        break
                    end
                end
            end
        end
    end
    end

    -- 3. Read skill availability from in-game AttacksPage ScrollingFrame if open, or from player skills
    local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
    local atkPage = actionBG and actionBG:FindFirstChild("AttacksPage")
    local scrollFrame = atkPage and atkPage:FindFirstChild("Attack") and atkPage.Attack:FindFirstChild("ScrollingFrame")

    local function isSkillAvailable(skillName)
        if not skillName or skillName == "" or skillName == "None" then return false end
        if skillName == "Strike" or skillName == "Wind Bolt" or skillName == "Smack" then return true end
        if scrollFrame then
            local btn = scrollFrame:FindFirstChild(skillName)
            if btn then
                local cd = btn:FindFirstChild("CD", true) or btn:FindFirstChild("Cooldown", true)
                if cd and cd.Visible == true then
                    if cd:IsA("TextLabel") and (cd.Text == "" or cd.Text == "0" or cd.Text == "0s") then
                    else
                        return false
                    end
                end
                local sealed = btn:FindFirstChild("Sealed", true) or btn:FindFirstChild("Disabled", true)
                if sealed and sealed.Visible == true then return false end
            end
        end
        return true
    end

    -- 3. Determine available skills for this unit
    local activeSkillNames = {}
    if #HubState.currentTurnSkills > 0 then
        for _, s in ipairs(HubState.currentTurnSkills) do
            if s ~= "Gate" and s ~= "Summon" then
                table.insert(activeSkillNames, s)
            end
        end
    end
    if #activeSkillNames == 0 and scrollFrame then
        for _, btn in ipairs(scrollFrame:GetChildren()) do
            if (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Name ~= "Frame" and btn.Name ~= "Template" and btn.Name ~= "Return" then
                table.insert(activeSkillNames, btn.Name)
            end
        end
    end

    local skillToUse = nil

    -- Override Strategy: Auto Boss Yar'thul Smart Play
    if isYarthulActive and not isSummon then
        local hasPillar = AutoYarthul.hasFlamePillar()
        local curEnergy = AutoYarthul.getPlayerEnergy()
        local isSenseReady = isSkillAvailable("Sense Expansion")
        local isCarnageReady = isSkillAvailable("Carnage")

        -- 1. Priority 1: Sense Expansion (Alternating turns - if ready & not used last turn)
        if isSenseReady and AutoYarthul.lastUsedSkill ~= "Sense Expansion" then
            skillToUse = "Sense Expansion"
            AutoYarthul.lastUsedSkill = "Sense Expansion"
            hubLog("[AutoYarthul Strat] 🩸 [Priority 1] Cast SENSE EXPANSION!")
            if AutoYarthul.updateHUD then AutoYarthul.updateHUD("Turn Action: 🩸 Sense Expansion") end

        -- 2. Priority 2: Carnage (Energy >= 3, Ready, and NO Flame Pillar)
        elseif isCarnageReady and curEnergy >= 3 and not hasPillar then
            skillToUse = "Carnage"
            AutoYarthul.lastUsedSkill = "Carnage"
            hubLog(string.format("[AutoYarthul Strat] ⚔️ [Priority 2 - Energy: %d >= 3] Cast CARNAGE!", curEnergy))
            if AutoYarthul.updateHUD then AutoYarthul.updateHUD(string.format("Turn Action: ⚔️ Carnage (Energy: %d)", curEnergy)) end

        -- 3. Priority 3: Strike + Meditate (if Carnage CD, building energy, or Flame Pillar active)
        else
            skillToUse = "Strike"
            AutoYarthul.lastUsedSkill = "Strike"
            if not isCarnageReady then
                hubLog(string.format("[AutoYarthul Strat] 🧘 [Priority 3 - Carnage CD | Energy: %d] Strike + Meditate!", curEnergy))
                if AutoYarthul.updateHUD then AutoYarthul.updateHUD("Turn Action: 🧘 Meditate + 🗡️ Strike (Carnage CD)") end
            elseif hasPillar then
                hubLog(string.format("[AutoYarthul Strat] 🔥 [Priority 3 - Flame Pillar Active | Energy: %d] Strike + Meditate!", curEnergy))
                if AutoYarthul.updateHUD then AutoYarthul.updateHUD("Turn Action: 🧘 Meditate + 🗡️ Strike (Pillar Active)") end
            else
                hubLog(string.format("[AutoYarthul Strat] ⚡ [Priority 3 - Building Energy: %d/3] Strike + Meditate!", curEnergy))
                if AutoYarthul.updateHUD then AutoYarthul.updateHUD(string.format("Turn Action: 🧘 Meditate + 🗡️ Strike (Energy: %d)", curEnergy)) end
            end
        end

    -- Mode 1: Custom Priority Skills
    elseif actionChoice == "Custom Skill" or actionChoice == "Custom Priority Skills" then
        local slots = {
            Options.CustomSkillSlot1 and Options.CustomSkillSlot1.Value,
            Options.CustomSkillSlot2 and Options.CustomSkillSlot2.Value,
            Options.CustomSkillSlot3 and Options.CustomSkillSlot3.Value,
            Options.CustomSkillSlot4 and Options.CustomSkillSlot4.Value,
        }
        for _, s in ipairs(slots) do
            if s and s ~= "" and s ~= "None" then
                local cleanS = s:gsub("%[Summon%]%s*", ""):lower()
                for _, avSkill in ipairs(activeSkillNames) do
                    if avSkill:lower() == cleanS and isSkillAvailable(avSkill) then
                        skillToUse = avSkill
                        break
                    end
                end
                if skillToUse then break end
            end
        end

        if not skillToUse and not isSummon and shouldMeditateIfNoSkill then
            hubLog("[DirectRemote] 🧘 No custom skill ready -> Direct Remote Meditate...")
            task.spawn(function()
                pcall(function() pti:InvokeServer("Meditate", false) end)
            end)
            task.wait(0.2)
            return true
        end

    -- Mode 2: Auto Smart
    elseif actionChoice:find("Auto Smart") then
        local bestSkill = nil
        local maxCost = -1
        local SkillsModule = nil
        pcall(function() SkillsModule = require(game.ReplicatedStorage.Constants.Skills) end)

        for _, avSkill in ipairs(activeSkillNames) do
            if avSkill ~= "Strike" and avSkill ~= "Magic Missile" and isSkillAvailable(avSkill) then
                local cost = 0
                if SkillsModule and SkillsModule[avSkill] then
                    cost = tonumber(SkillsModule[avSkill].Cost) or 0
                end
                if cost > maxCost then
                    maxCost = cost
                    bestSkill = avSkill
                end
            end
        end

        if bestSkill then
            skillToUse = bestSkill
        end
    end

    -- Fallback to first available skill or default
    if not skillToUse then
        for _, avSkill in ipairs(activeSkillNames) do
            if isSkillAvailable(avSkill) then
                skillToUse = avSkill
                break
            end
        end
    end

    if not skillToUse then
        skillToUse = isSummon and "Wind Bolt" or "Strike"
    end

    local actionRemoteName = isSummon and "AttackSummoned" or "Attack"
    hubLog(string.format("[DirectRemote] ⚡ Sending Direct Remote '%s': '%s' -> Target: %s", actionRemoteName, skillToUse, targetEnemy and targetEnemy.Name or "None"))

    -- 4. Send Main Attack Remote packet directly to server
    task.spawn(function()
        pcall(function()
            if targetEnemy then
                pti:InvokeServer(actionRemoteName, skillToUse, { Attacking = targetEnemy })
            else
                pti:InvokeServer(actionRemoteName, skillToUse, {})
            end
        end)
    end)

    -- 5. Sub-Actions for player in same turn (Meditate / Guard)
    if not isSummon then
        local shouldMed = (subAction == "Auto Meditate (Recover Energy)" or subAction:find("Meditate"))
        if isYarthulActive and skillToUse == "Strike" then
            shouldMed = (Toggles.YarthulMeditateSubAction == nil or Toggles.YarthulMeditateSubAction.Value ~= false)
        end

        if shouldMed then
            hubLog("[DirectRemote] 🧘 Sending same-turn Sub-Action: Meditate!")
            task.spawn(function()
                pcall(function() pti:InvokeServer("Meditate", false) end)
            end)
        elseif subAction == "Auto Guard (Defend)" or subAction:find("Guard") then
            hubLog("[DirectRemote] 🛡️ Sending same-turn Sub-Action: Guard!")
            task.spawn(function()
                pcall(function()
                    if targetEnemy then
                        pti:InvokeServer("Guard", false, { ProtectTarget = char })
                    else
                        pti:InvokeServer("Guard", false)
                    end
                end)
            end)
        end
    end

    task.wait(0.2)
    return true
end

local function executeCombatTurn()
    if combatTurnLock then return end
    combatTurnLock = true

    local ok, err = pcall(function()
        local execMode = (Options.CombatExecutionMode and Options.CombatExecutionMode.Value) or "Direct Remote (Fastest + Sub-actions)"
        
        -- IF DIRECT REMOTE MODE IS SELECTED: SEND INSTANT REMOTE PACKETS DIRECTLY WITHOUT TOUCHING UI
        if execMode:find("Direct Remote") then
            executeDirectRemoteTurn()
            local endWait = os.clock()
            while isPlayerTurn() and os.clock() - endWait < 1.2 do
                task.wait(0.05)
            end
            return
        end

        -- OTHERWISE FALLBACK TO UI EMULATION (CLASSIC)
        local pgui = PlayerGui
        local combatGui = pgui and pgui:FindFirstChild("Combat")
        if not combatGui or not combatGui.Enabled then return end

        local actionBG = combatGui:FindFirstChild("ActionBG")
        local ctxPage = actionBG and actionBG:FindFirstChild("ContextPage")
        local atkPage = actionBG and actionBG:FindFirstChild("AttacksPage")
        local goBtn = combatGui:FindFirstChild("Go")

        local actionChoice = (Options.CombatAction and Options.CombatAction.Value) or "Auto Smart"
        local shouldMeditateIfNoSkill = (Toggles.CombatMeditate and Toggles.CombatMeditate.Value) or false
        local targetPrio = (Options.TargetPriority and Options.TargetPriority.Value) or "First Enemy"

        local isSummon = false
        local deciding = combatGui:FindFirstChild("Deciding")
        if deciding and deciding.Visible then
            local txt = deciding:FindFirstChildWhichIsA("TextLabel", true) and deciding:FindFirstChildWhichIsA("TextLabel", true).Text:lower() or ""
            if txt ~= "" and not txt:find(LocalPlayer.Name:lower()) then
                isSummon = true
            end
        end

        local function doCombatMeditate()
            if isSummon then return end
            hubLog("[Combat] 🧘 Performing Combat Meditation...")
            if atkPage and atkPage.Visible then
                local retBtn = atkPage:FindFirstChild("Return", true) or (atkPage:FindFirstChild("Attack") and atkPage.Attack:FindFirstChild("Return"))
                if retBtn and retBtn.Visible then
                    safeClickButton(retBtn)
                    task.wait(0.2)
                end
            end

            local medBtn = ctxPage and ctxPage:FindFirstChild("MeditateButton")
            if medBtn and medBtn.Visible then
                safeClickButton(medBtn)
                task.wait(0.2)
            end

            pcall(function()
                local pti = game.ReplicatedStorage:FindFirstChild("PlayerTurnInput")
                if pti and pti:IsA("RemoteFunction") then
                    pti:InvokeServer("Meditate", false)
                end
            end)
            task.wait(0.5)
        end

        if ctxPage and ctxPage.Visible and not (atkPage and atkPage.Visible) then
            local atkBtn = ctxPage:FindFirstChild("AttackButton")
            if atkBtn and atkBtn.Visible then
                safeClickButton(atkBtn)
                local waitAtk = os.clock()
                while (not (atkPage and atkPage.Visible)) and os.clock() - waitAtk < 0.8 do
                    task.wait(0.05)
                end
                task.wait(0.15)
            end
        end

        local attackFrame = atkPage and atkPage:FindFirstChild("Attack")
        local scrollFrame = attackFrame and attackFrame:FindFirstChild("ScrollingFrame")

        if scrollFrame and scrollFrame.Visible then
            local selectedSkillBtn = nil

            local function isSkillReady(btn)
                if not btn or not btn.Parent then return false end
                if not btn:IsA("GuiButton") and not btn:IsA("TextButton") and not btn:IsA("ImageButton") then return false end
                if btn.Name == "Template" or btn.Name == "Return" or btn.Name == "Frame" then return false end

                local cd = btn:FindFirstChild("CD", true) or btn:FindFirstChild("Cooldown", true)
                if cd and cd.Visible == true then
                    if cd:IsA("TextLabel") and (cd.Text == "" or cd.Text == "0" or cd.Text == "0s") then
                    else
                        return false
                    end
                end

                local sealed = btn:FindFirstChild("Sealed", true) or btn:FindFirstChild("Disabled", true)
                if sealed and sealed.Visible == true then return false end

                if not isSummon then
                    local char = LocalPlayer and LocalPlayer.Character
                    local status = char and char:FindFirstChild("Status")
                    local curEnergy = status and status:FindFirstChild("Energy") and tonumber(status.Energy.Value)
                    if curEnergy ~= nil then
                        local costObj = btn:FindFirstChild("Cost", true)
                        local costLabel = costObj and (costObj:IsA("TextLabel") and costObj or costObj:FindFirstChildWhichIsA("TextLabel", true))
                        local costText = costLabel and costLabel.Text or (costObj and costObj.Name) or ""
                        local costNum = tonumber(costText:match("%d+"))
                        if costNum and costNum > curEnergy then return false end
                    end
                end
                return true
            end

            local function findBasicAttackBtn()
                local basicNames = {
                    "wind bolt", "gale pulse", "light bolt", "sylph's prayer", "gale uplift",
                    "smack", "bone spray", "rotten swipe", "shriek", "double slam",
                    "strike", "magic missile", "basic attack", "slash", "punch", "shoot", "bite", "claw"
                }
                for _, name in ipairs(basicNames) do
                    local btn = scrollFrame:FindFirstChild(name)
                    if btn and isSkillReady(btn) then return btn end
                end
                for _, btn in ipairs(scrollFrame:GetChildren()) do
                    if isSkillReady(btn) and (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Name ~= "Frame" and btn.Name ~= "Template" and btn.Name ~= "Return" then
                        local label = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                        local txt = (label and label.Text ~= "" and label.Text) or btn.Name
                        for _, bName in ipairs(basicNames) do
                            if txt:lower() == bName:lower() then return btn end
                        end
                    end
                end
                for _, btn in ipairs(scrollFrame:GetChildren()) do
                    if isSkillReady(btn) and (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Name ~= "Frame" and btn.Name ~= "Template" and btn.Name ~= "Return" then
                        return btn
                    end
                end
                return nil
            end

            local function findSkillByName(targetName)
                if not targetName or targetName == "" or targetName == "None" then return nil end
                local cleanTarget = targetName:gsub("%[Summon%]%s*", ""):gsub("^%s*(.-)%s*$", "%1"):lower()
                if cleanTarget == "" or cleanTarget == "none" then return nil end

                for _, btn in ipairs(scrollFrame:GetChildren()) do
                    if isSkillReady(btn) then
                        local nameLabel = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                        local labelText = nameLabel and nameLabel.Text and nameLabel.Text:gsub("^%s*(.-)%s*$", "%1"):lower() or ""
                        local btnName = btn.Name:gsub("^%s*(.-)%s*$", "%1"):lower()
                        if labelText == cleanTarget or btnName == cleanTarget then return btn end
                    end
                end
                for _, btn in ipairs(scrollFrame:GetChildren()) do
                    if isSkillReady(btn) then
                        local nameLabel = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                        local labelText = nameLabel and nameLabel.Text and nameLabel.Text:gsub("^%s*(.-)%s*$", "%1"):lower() or ""
                        local btnName = btn.Name:gsub("^%s*(.-)%s*$", "%1"):lower()
                        if (labelText ~= "" and (labelText:find("^" .. cleanTarget .. "%f[%s]") or labelText:find("%f[%s]" .. cleanTarget .. "$"))) or
                           (btnName:find("^" .. cleanTarget .. "%f[%s]") or btnName:find("%f[%s]" .. cleanTarget .. "$")) then
                            return btn
                        end
                    end
                end
                return nil
            end

            if actionChoice == "Custom Skill" or actionChoice == "Custom Priority Skills" then
                local slots = {
                    Options.CustomSkillSlot1 and Options.CustomSkillSlot1.Value,
                    Options.CustomSkillSlot2 and Options.CustomSkillSlot2.Value,
                    Options.CustomSkillSlot3 and Options.CustomSkillSlot3.Value,
                    Options.CustomSkillSlot4 and Options.CustomSkillSlot4.Value,
                }
                for slotIdx, slotName in ipairs(slots) do
                    if slotName and slotName ~= "" and slotName ~= "None" then
                        local foundBtn = findSkillByName(slotName)
                        if foundBtn then
                            selectedSkillBtn = foundBtn
                            hubLog(string.format("[Combat] Custom Skill Match: Slot %d ('%s')", slotIdx, slotName))
                            break
                        end
                    end
                end
                if not selectedSkillBtn then
                    if isSummon then
                        selectedSkillBtn = findBasicAttackBtn()
                    elseif shouldMeditateIfNoSkill then
                        hubLog("[Combat] 🧘 Custom Skills on cooldown/no energy -> Meditating.")
                        doCombatMeditate()
                        return
                    else
                        selectedSkillBtn = findBasicAttackBtn()
                    end
                end
            elseif actionChoice:find("Auto Smart") then
                local bestSkill = nil
                local maxCost = -1
                for _, btn in ipairs(scrollFrame:GetChildren()) do
                    if isSkillReady(btn) and (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Name ~= "Strike" and btn.Name ~= "Magic Missile" and btn.Name ~= "Frame" and btn.Name ~= "Template" and btn.Name ~= "Return" then
                        local costObj = btn:FindFirstChild("Cost", true)
                        local costLabel = costObj and (costObj:IsA("TextLabel") and costObj or costObj:FindFirstChildWhichIsA("TextLabel", true))
                        local costText = costLabel and costLabel.Text or "0"
                        local costNum = tonumber(costText:match("%d+")) or 0
                        if costNum > maxCost then
                            maxCost = costNum
                            bestSkill = btn
                        end
                    end
                end
                if bestSkill then
                    selectedSkillBtn = bestSkill
                elseif not isSummon and shouldMeditateIfNoSkill then
                    doCombatMeditate()
                    return
                else
                    selectedSkillBtn = findBasicAttackBtn()
                end
            else
                selectedSkillBtn = findBasicAttackBtn()
            end

            if not selectedSkillBtn then
                selectedSkillBtn = findBasicAttackBtn()
            end

            if selectedSkillBtn then
                local skillName = selectedSkillBtn.Name
                hubLog(string.format("[Combat] ⚔️ Executing action: '%s'", skillName))
                safeClickButton(selectedSkillBtn)
                
                local waitSkill = os.clock()
                local enemiesFrame = atkPage and atkPage:FindFirstChild("Enemies")
                while (not (enemiesFrame and enemiesFrame.Visible)) and (not (goBtn and goBtn.Visible)) and isPlayerTurn() and os.clock() - waitSkill < 0.6 do
                    task.wait(0.05)
                end
                task.wait(0.1)
            elseif not isSummon and shouldMeditateIfNoSkill then
                doCombatMeditate()
                return
            end
        end

        local enemiesFrame = atkPage and atkPage:FindFirstChild("Enemies")
        local enemiesScroll = enemiesFrame and (enemiesFrame:FindFirstChild("ScrollingFrame") or enemiesFrame)

        if enemiesFrame and enemiesFrame.Visible and enemiesScroll then
            local enemyButtons = {}
            for _, btn in ipairs(enemiesScroll:GetChildren()) do
                if (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible and btn.Name ~= "Return" and btn.Name ~= "Template" then
                    table.insert(enemyButtons, btn)
                end
            end

            if #enemyButtons > 0 then
                local chosenEnemy = enemyButtons[1]
                if targetPrio == "Last Enemy" then
                    chosenEnemy = enemyButtons[#enemyButtons]
                elseif targetPrio == "Random Enemy" then
                    chosenEnemy = enemyButtons[math.random(1, #enemyButtons)]
                end

                if chosenEnemy then
                    hubLog(string.format("[Combat] 🎯 Enemy target selected: '%s'", chosenEnemy.Name))
                    safeClickButton(chosenEnemy)
                    local waitEnemy = os.clock()
                    while (not (goBtn and goBtn.Visible)) and isPlayerTurn() and os.clock() - waitEnemy < 0.6 do
                        task.wait(0.05)
                    end
                    task.wait(0.1)
                end
            end
        end

        goBtn = combatGui:FindFirstChild("Go")
        if goBtn and goBtn.Visible then
            hubLog("[Combat] 🚀 Confirming Go button...")
            safeClickButton(goBtn)
            task.wait(0.25)
        end

        local endWait = os.clock()
        while isPlayerTurn() and os.clock() - endWait < 1.5 do
            task.wait(0.05)
        end
    end)

    if not ok then
        warn("[Combat] ⚠️ Error in executeCombatTurn:", tostring(err))
    end

    combatTurnLock = false
end
function AutoFight.start()
    if AutoFight.running then return end
    AutoFight.running = true

    if AutoFight.thread then
        pcall(function() task.cancel(AutoFight.thread) end)
    end

    AutoFight.thread = task.spawn(function()
        hubLog("[AutoFight]  has bat Auto Fight (auto danh / tung skill khi den turn trong tran)!")
        
        -- Hook phan hoi tuc thi qua PropertyChangedSignal cua ActionBG, Title.Text, Go va Remote Events
        local function onCombatStateChanged()
            if HubState.running and AutoFight.running and isInCombat() and isPlayerTurn() and not combatTurnLock then
                local combatDelay = Options.CombatDelay and Options.CombatDelay.Value or 0.05
                if combatDelay > 0 then
                    task.wait(combatDelay)
                end
                if isPlayerTurn() and not combatTurnLock then
                    executeCombatTurn()
                end
            end
        end

        local pgui = PlayerGui
        local combatGui = pgui and pgui:FindFirstChild("Combat")
        local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
        local header = actionBG and actionBG:FindFirstChild("Header")
        local title = header and header:FindFirstChild("Title")
        local goBtn = combatGui and combatGui:FindFirstChild("Go")

        local RS = game:GetService("ReplicatedStorage")
        local remotes = RS:FindFirstChild("Remotes")
        local fightRemotes = remotes and remotes:FindFirstChild("Fight")
        local updateTurnRemote = fightRemotes and fightRemotes:FindFirstChild("UpdateTurnCount")
        local startActionRemote = fightRemotes and fightRemotes:FindFirstChild("StartAction")

        local conn1, conn2, conn3, conn4, conn5
        if actionBG then
            conn1 = actionBG:GetPropertyChangedSignal("Visible"):Connect(function()
                if actionBG.Visible then
                    task.spawn(onCombatStateChanged)
                end
            end)
        end
        if title then
            conn2 = title:GetPropertyChangedSignal("Text"):Connect(function()
                task.spawn(onCombatStateChanged)
            end)
        end
        if goBtn then
            conn3 = goBtn:GetPropertyChangedSignal("Visible"):Connect(function()
                if goBtn.Visible then
                    task.spawn(onCombatStateChanged)
                end
            end)
        end
        if updateTurnRemote and updateTurnRemote:IsA("RemoteEvent") then
            conn4 = updateTurnRemote.OnClientEvent:Connect(function()
                task.spawn(onCombatStateChanged)
            end)
        end
        if startActionRemote and startActionRemote:IsA("RemoteEvent") then
            conn5 = startActionRemote.OnClientEvent:Connect(function()
                task.spawn(onCombatStateChanged)
            end)
        end

        while HubState.running and AutoFight.running do
            if isInCombat() then
                if isPlayerTurn() and not combatTurnLock then
                    local combatDelay = Options.CombatDelay and Options.CombatDelay.Value or 0.05
                    if combatDelay > 0 then
                        task.wait(combatDelay)
                    end
                    if isPlayerTurn() and not combatTurnLock then
                        executeCombatTurn()
                    end
                else
                    task.wait(0.03)
                end
            else
                task.wait(0.2)
            end
        end

        if conn1 then conn1:Disconnect() end
        if conn2 then conn2:Disconnect() end
        if conn3 then conn3:Disconnect() end
        if conn4 then conn4:Disconnect() end
        if conn5 then conn5:Disconnect() end
        hubLog("[AutoFight] ⏹️ has stop Auto Fight.")
    end)
end

function AutoFight.stop()
    AutoFight.running = false
    if AutoFight.thread then
        pcall(function() task.cancel(AutoFight.thread) end)
        AutoFight.thread = nil
    end
end

local function isNightTime()
    local ct = (Lighting and Lighting.ClockTime) or 12
    return (ct >= 17.5 or ct < 6.5)
end

local function handleDeeprootNightSafe(targetSpot, targetDesc)
    local avoidNight = Toggles.DeeprootNightFailsafe == nil or Toggles.DeeprootNightFailsafe.Value == true
    if not avoidNight then return false end

    local isDeeproot = (targetSpot - LevelFarmer.farmSpotLv30_50).Magnitude < 25 
        or (targetDesc and targetDesc:lower():find("deeproot"))
        or (Options.FarmLevelMode and Options.FarmLevelMode.Value and Options.FarmLevelMode.Value:find("Deeproot"))

    if isDeeproot and isNightTime() then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local skyPos = Vector3.new(targetSpot.X, 1200, targetSpot.Z)
            if (root.Position.Y < 1000) then
                hubLog(string.format("[AutoFarmLevel]  detected troi toi (ClockTime: %.1fh) tai Deeproot Forest -> fly len tang may (Y: 1200) dung ne Sentinel of Darkness...", Lighting.ClockTime))
                flyToFarmSpot(skyPos)
                enableLevelFarmerNoclip()
            end

            -- Dung lo lung safely tren may cho den khi troi sang hoac bi keo vao tran
            while HubState.running and LevelFarmer.running and isNightTime() and not isInCombat() do
                local curRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if curRoot and curRoot.Position.Y < 1000 then
                    curRoot.CFrame = CFrame.new(skyPos)
                end
                task.wait(1.5)
            end

            if HubState.running and LevelFarmer.running and not isNightTime() and not isInCombat() then
                hubLog(string.format("[AutoFarmLevel]  Troi has sang tro again (ClockTime: %.1fh) -> fly xuong bai farm Deeproot Forest tiep tuc combat...", Lighting.ClockTime))
                flyToFarmSpot(targetSpot)
                enableLevelFarmerNoclip()
            end
            return true
        end
    end
    return false
end

function LevelFarmer.runCycle()
    if AutoYarthul and AutoYarthul.running then AutoYarthul.stop(true) end
    if Toggles.AutoFarmYarthul and Toggles.AutoFarmYarthul.Value then
        Toggles.AutoFarmYarthul.Value = false
        if Toggles.AutoFarmYarthul.UpdateVisuals then Toggles.AutoFarmYarthul:UpdateVisuals() end
    end
    LevelFarmer.running = true

    task.spawn(function()
        local spot, spotDesc = getActiveFarmSpot()
        hubLog(string.format("[AutoFarmLevel]  start Auto Farm Level - Vi tri: %s", tostring(spotDesc)))

        -- test ne ban dem tai Deeproot Forest neu is la ban dem
        if not handleDeeprootNightSafe(spot, spotDesc) then
            -- fly toi bai farm safely bang Sky-Tween & bat Noclip lien tuc
            flyToFarmSpot(spot)
            enableLevelFarmerNoclip()
        end

        local currentAssignedSpot = spot

        while HubState.running and LevelFarmer.running do
            if isInCombat() then
                if not LevelFarmer.wasInCombat then
                    LevelFarmer.wasInCombat = true
                    LevelFarmer.essenceBeforeCombat = getCurrentEssence()
                    hubLog(string.format("[AutoFarmLevel]  has vao tran danh moi! (Essence dau tran: %d)", LevelFarmer.essenceBeforeCombat))
                end

                if isPlayerTurn() and not combatTurnLock then
                    local combatDelay = Options.CombatDelay and Options.CombatDelay.Value or 0.1
                    if combatDelay > 0 then
                        task.wait(combatDelay)
                    end
                    if isPlayerTurn() and not combatTurnLock then
                        executeCombatTurn()
                    end
                else
                    task.wait(0.05)
                end
            else
                if LevelFarmer.wasInCombat then
                    LevelFarmer.wasInCombat = false
                    hubLog("[AutoFarmLevel]  battle ket thuc! is wait server load thuong Essence...")

                    local initialEssence = LevelFarmer.essenceBeforeCombat
                    local newEssence = getCurrentEssence()
                    local startWait = os.clock()

                    -- wait thong minh maximum 4.0 giay: Neu server load Essence som thi tiep tuc now
                    while os.clock() - startWait < 4.0 do
                        newEssence = getCurrentEssence()
                        if newEssence > initialEssence then
                            break
                        end
                        task.wait(0.3)
                    end

                    hubLog(string.format("[AutoFarmLevel]  Essence before tran: %d | Essence after tran: %d", initialEssence, newEssence))

                    if newEssence > initialEssence then
                        -- has receive them Essence -> not yet cham Cap -> Tiep tuc farm
                        LevelFarmer.essenceBeforeCombat = newEssence
                        hubLog(string.format("[AutoFarmLevel]  has receive thuong (+%d Essence, total: %d) -> Tiep tuc farm tran moi...", newEssence - initialEssence, newEssence))
                    elseif newEssence == initialEssence and newEssence >= 10 then
                        -- after 4.0s polling xac receive not receive them Essence -> has cham Cap maximum!
                        if Toggles.AutoMeditate and Toggles.AutoMeditate.Value then
                            hubLog(string.format("[AutoFarmLevel]  Xac receive Essence has cham Cap maximum (%d Essence) -> start process di thien...", newEssence))
                            humanoidMeditateAndLevelUp()
                        end
                    else
                        LevelFarmer.essenceBeforeCombat = newEssence
                        task.wait(0.5)
                    end
                end

                -- auto test vi tri bai farm va level khi dung wait ngoai tran
                if not isInSoulCorridor() then
                    local targetSpot, targetDesc = getActiveFarmSpot()
                    if not handleDeeprootNightSafe(targetSpot, targetDesc) then
                        local char = LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if root then
                            local isLv1_30 = (targetSpot - LevelFarmer.farmSpotLv1_30).Magnitude < 5
                            local checkY = isLv1_30 and (targetSpot.Y + 4.0) or targetSpot.Y
                            local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetSpot.X, 0, targetSpot.Z)).Magnitude
                            local yDiff = math.abs(root.Position.Y - checkY)

                            -- Neu level thay doi khien doi bai farm hoac bi vang ra xa -> Sky-Tween fly toi bai moi
                            if targetSpot ~= currentAssignedSpot or dist > 15 or yDiff > 10 then
                                currentAssignedSpot = targetSpot
                                hubLog(string.format("[AutoFarmLevel] 🔄 Cap nhat bai farm (%s) -> Tien hanh Sky-Tween...", targetDesc))
                                flyToFarmSpot(targetSpot)
                                enableLevelFarmerNoclip()
                            end
                        end
                    end
                end
                task.wait(0.4)
            end
            task.wait(0.1)
        end
        hubLog("[AutoFarmLevel] ⏹️ has stop Auto Farm Level.")
    end)
end

function LevelFarmer.stop()
    LevelFarmer.running = false
    disableLevelFarmerNoclip()
    removeUndergroundPlatform()
    disableFlightState()
end

-- =============================================================================
-- AUTO MINE ORES (FERRUS, AESTIC, LANEUS + AUTO BUY PICKAXE)
-- =============================================================================
local Miner = {
    running = false,
    gainedOreThisNode = false,
    lastGainedOreName = "",
}

-- Lang nghe truc tiep Remote InventorySync cua Server de receive dien quang vao kho now lap tuc (0ms)
pcall(function()
    local RS = game:GetService("ReplicatedStorage")
    local invSync = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Data") and RS.Remotes.Data:FindFirstChild("InventorySync")
    if invSync then
        invSync.OnClientEvent:Connect(function(action, itemData)
            if (action == "Add" or action == "Batch") and itemData then
                local items = (action == "Batch" and itemData) or { itemData }
                for _, itm in ipairs(items) do
                    local itmName = (itm and (itm.Name or itm.Tool or ""))
                    if itmName:lower():find("ore") then
                        Miner.gainedOreThisNode = true
                        Miner.lastGainedOreName = itmName
                        hubLog(string.format("[AutoMine]  [Server Remote] has receive successfully quang: %s (So luong: %s) vao inventory!", itmName, tostring(itm.Count or 1)))
                    end
                end
            end
        end)
    end
end)

local function hasPickaxe()
    local char = LocalPlayer.Character
    if char then
        if char:FindFirstChild("Pickaxe") then return true end
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("pick") then return true end
        end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        if bp:FindFirstChild("Pickaxe") or (bp:FindFirstChild("Tools") and bp.Tools:FindFirstChild("Pickaxe")) then
            return true
        end
        for _, t in ipairs(bp:GetChildren()) do
            if t.Name:lower():find("pick") then return true end
        end
        local toolsFolder = bp:FindFirstChild("Tools")
        if toolsFolder then
            for _, t in ipairs(toolsFolder:GetChildren()) do
                if t.Name:lower():find("pick") then return true end
            end
        end
    end
    local invGui = PlayerGui and PlayerGui:FindFirstChild("Inventory")
    local toolsFrame = invGui and invGui:FindFirstChild("Tools", true)
    if toolsFrame then
        for _, desc in ipairs(toolsFrame:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text:lower():find("pickaxe") then
                return true
            end
        end
    end
    return false
end

local function hasPickaxeEquipped()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") or item.Name:lower():find("pickaxe") then
            return true
        end
    end
    return false
end

local function equipPickaxe()
    local char = LocalPlayer.Character
    if not char then return false end

    -- NEU has CAM TREN TAY ROI THI RETURN now, TRANH GUI LENH again GAY TOGGLE UNEQUIP!
    if hasPickaxeEquipped() then
        return true
    end

    -- 1. UU TIEN GOI HAM :Equip() CHINH THUC TU ENVIRONMENT CUA INVENTORY SCRIPT
    local pgui = PlayerGui
    local inv = pgui and pgui:FindFirstChild("Inventory")
    local invScript = inv and inv:FindFirstChildWhichIsA("LocalScript", true)

    if invScript and getsenv and getupvalues then
        pcall(function()
            local env = getsenv(invScript)
            if env and env.newTile then
                local uvs = getupvalues(env.newTile)
                local itemDict = uvs[6]
                if itemDict then
                    for k, v in pairs(itemDict) do
                        if (v.Tool and v.Tool:lower():find("pickaxe")) or (v.ItemData and v.ItemData.Name:lower():find("pickaxe")) then
                            v:Equip()
                            task.wait(0.3)
                            break
                        end
                    end
                end
            end
        end)
    end

    if hasPickaxeEquipped() then return true end

    -- 2. DU PHONG: Gui Remote InventoryManage Equip & Use
    local RS = game:GetService("ReplicatedStorage")
    local invManage = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Information") and RS.Remotes.Information:FindFirstChild("InventoryManage")

    if inv then
        for _, desc in ipairs(inv:GetDescendants()) do
            if desc:IsA("TextButton") and desc.Text:lower():find("pickaxe") then
                local uniqueId = tonumber(desc.Name) or desc.Name
                if invManage then
                    pcall(function() invManage:FireServer("Equip", "Pickaxe", uniqueId) end)
                    pcall(function() invManage:FireServer("Use", "Pickaxe", uniqueId) end)
                end
                if firesignal then
                    pcall(function() firesignal(desc.MouseButton1Click) end)
                end
                task.wait(0.3)
                break
            end
        end
    end

    -- 3. DU PHONG: Keo Tool tu Backpack
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if bp and hum then
        local bpPick = bp:FindFirstChild("Pickaxe") or bp:FindFirstChildWhichIsA("Tool")
        if bpPick and bpPick:IsA("Tool") then
            hum:EquipTool(bpPick)
            task.wait(0.2)
        end
    end

    return hasPickaxeEquipped()
end

local function buyPickaxe()
    hubLog("[AutoMine]  Pickaxe not found! Flying to Caldera Blacksmith to purchase Pickaxe (50 Gold)...")
    Library:Notify("No Pickaxe found! Flying to Caldera to buy Pickaxe (50g)...", 4)
    local pickaxePos = Vector3.new(4907.0, 656.7, -4154.0)
    local flew = smoothTweenTo(CFrame.new(pickaxePos.X, pickaxePos.Y + 3, pickaxePos.Z), Options.CruiseSpeed and Options.CruiseSpeed.Value or 180, function() return Miner.running end)
    if not flew or not Miner.running then return false end

    task.wait(0.5)
    local pickaxeModel = workspace:FindFirstChild("Mechanical") and workspace.Mechanical:FindFirstChild("Buyables") and workspace.Mechanical.Buyables:FindFirstChild("Pickaxe")
    if not pickaxeModel then
        pickaxeModel = workspace:FindFirstChild("Pickaxe", true)
    end

    if pickaxeModel then
        for _, desc in ipairs(pickaxeModel:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and fireproximityprompt then
                fireproximityprompt(desc)
            elseif desc:IsA("ClickDetector") and fireclickdetector then
                fireclickdetector(desc)
            end
        end
        task.wait(0.4)

        -- Bam button Confirm buy hang trong PlayerGui.Chat hoac Prompt Dialog
        local pgui = PlayerGui
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc:IsA("TextButton") and (desc.Text == "Confirm" or desc.Text == "Buy" or desc.Text == "Yes" or desc.Text == "YES") then
                if firesignal then
                    pcall(function() firesignal(desc.MouseButton1Click) end)
                    pcall(function() firesignal(desc.MouseButton1Down) end)
                end
                safeClickButton(desc)
                hubLog("[AutoMine]  has bam button Confirm buy pickaxe successfully!")
                break
            end
        end
        task.wait(0.8)
        equipPickaxe()
        Library:Notify(" Pickaxe bought and equipped!", 3)
        return true
    end
    return false
end

local function getInventoryOreCount()
    local total = 0
    pcall(function()
        local pgui = PlayerGui
        local inv = pgui and pgui:FindFirstChild("Inventory")
        local invScript = inv and inv:FindFirstChildWhichIsA("LocalScript", true)
        if invScript and getsenv and getupvalues then
            local env = getsenv(invScript)
            if env and env.newTile then
                local uvs = getupvalues(env.newTile)
                local itemDict = uvs[6]
                if itemDict then
                    for k, v in pairs(itemDict) do
                        local itemName = v.Tool or (v.ItemData and v.ItemData.Name) or ""
                        local amount = (v.ItemAmount and v.ItemAmount.Value) or (v.ItemData and tonumber(v.ItemData.Count)) or 1
                        if itemName:lower():find("ore") then
                            total = total + amount
                        end
                    end
                    return
                end
            end
        end

        if inv then
            for _, desc in ipairs(inv:GetDescendants()) do
                if desc:IsA("TextButton") and desc.Text:lower():find("ore") then
                    local amtVal = desc:FindFirstChild("ItemAmount")
                    local amtLbl = desc:FindFirstChild("AmountLabel")
                    local count = amtVal and amtVal.Value or (amtLbl and tonumber(amtLbl.Text:match("%d+")) or 1)
                    total = total + count
                end
            end
        end
    end)
    return total
end

local function mineOreNode(oreModel)
    if not oreModel or not oreModel.Parent or not oreModel:IsDescendantOf(workspace) then return false end
    local startTime = os.clock()
    local timeout = Options.MineTimeout and Options.MineTimeout.Value or 15
    local swingDelay = (Options.MineSwingDelay and Options.MineSwingDelay.Value) or 0.18

    -- 1. Reset co receive quang cua Server va luu so luong quang ban dau
    Miner.gainedOreThisNode = false
    local initialOreCount = getInventoryOreCount()

    -- 2. Dam bao pickaxe duoc gear tu Inventory
    equipPickaxe()

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local orePart = oreModel:FindFirstChild("Ore") or oreModel:FindFirstChildWhichIsA("BasePart")
    if not orePart then return false end

    hubLog(string.format("[AutoMine]  start vung pickaxe dap mo %s (Quang trong kho: %d, speed: %.2fs/hit)...", oreModel.Name, initialOreCount, swingDelay))

    while HubState.running and (os.clock() - startTime < timeout) and Miner.running do
        -- A. test DIEU KIEN 1: SERVER has BAN EVENT INVENTORYSYNC BAO QUANG VAO inventory (0ms)
        if Miner.gainedOreThisNode then
            hubLog(string.format("[AutoMine]  Server xac receive receive %s vao inventory! Dao mo %s successfully!", Miner.lastGainedOreName, oreModel.Name))
            break
        end

        -- B. test DIEU KIEN 2: inventory increase SO LUONG mineral
        local currentOreCount = getInventoryOreCount()
        if currentOreCount > initialOreCount then
            hubLog(string.format("[AutoMine]  inventory receive them %d quang (Tu %d -> %d)! Dao xong mo %s!", currentOreCount - initialOreCount, initialOreCount, currentOreCount, oreModel.Name))
            break
        end

        -- C. test DIEU KIEN 3: ore node has BI PHA HUY HOAN TOAN
        if not oreModel or not oreModel.Parent or not oreModel:IsDescendantOf(workspace) then
            hubLog(string.format("[AutoMine]  Mo %s has bi pha huy hoan toan!", oreModel and oreModel.Name or "Ore"))
            break
        end

        local currentOrePart = oreModel:FindFirstChild("Ore") or oreModel:FindFirstChildWhichIsA("BasePart")
        if not currentOrePart or not currentOrePart.Parent or not currentOrePart:IsDescendantOf(workspace) then
            hubLog(string.format("[AutoMine]  Quang trong mo %s has duoc mine xong!", oreModel.Name))
            break
        end

        -- D. Dam bao luon cam pickaxe tren tay
        if not hasPickaxeEquipped() then
            equipPickaxe()
        end

        -- E. Giu vi tri dung accurate 3.5 studs doi dien quang, triet tieu gia toc vat ly
        if root and currentOrePart then
            local orePos = currentOrePart.Position
            local flatDir = Vector3.new(root.Position.X - orePos.X, 0, root.Position.Z - orePos.Z)
            if flatDir.Magnitude < 0.1 then flatDir = Vector3.new(0, 0, 3.5) end
            local standPos = orePos + flatDir.Unit * 3.5 + Vector3.new(0, 0.8, 0)

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = CFrame.lookAt(standPos, Vector3.new(orePos.X, standPos.Y, orePos.Z))
        end

        -- F. activate Pickaxe Tool swing & Chuot vat ly
        local tool = char and (char:FindFirstChild("Pickaxe") or char:FindFirstChildWhichIsA("Tool"))
        if tool and tool:IsA("Tool") then
            pcall(function() tool:Activate() end)
        end

        if VirtualInputManager then
            VirtualInputManager:SendMouseButtonEvent(500, 500, 0, true, game, 0)
            task.wait(0.04)
            VirtualInputManager:SendMouseButtonEvent(500, 500, 0, false, game, 0)
        end

        task.wait(swingDelay)
    end
    return true
end

function Miner.runCycle()
    if Miner.running then return end
    Miner.running = true

    task.spawn(function()
        hubLog("[AutoMine]  [BUOC 1]: test gear Pickaxe...")
        handleAutoStart()

        if not hasPickaxe() then
            if Toggles.AutoBuyPickaxe and Toggles.AutoBuyPickaxe.Value then
                local bought = buyPickaxe()
                if not bought and not hasPickaxe() then
                    Library:Notify(" Failed to acquire Pickaxe! Cannot mine ores.", 4)
                    Miner.stop()
                    return
                end
            else
                Library:Notify(" Pickaxe required to mine! Please buy one or enable Auto Buy.", 4)
                Miner.stop()
                return
            end
        end

        hubLog("[AutoMine]  [BUOC 2]: is quet ore node tren map...")
        local selectedOres = (Options.MineOresWhitelist and Options.MineOresWhitelist.Value) or { ["Ferrus"] = true, ["Aestic"] = true, ["Laneus"] = true }

        local oreList = {}
        local oresFolder = workspace:FindFirstChild("Ores")
        if oresFolder then
            for _, ore in ipairs(oresFolder:GetChildren()) do
                if selectedOres[ore.Name] then
                    table.insert(oreList, { instance = ore, name = ore.Name })
                end
            end
        end

        if #oreList == 0 then
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("Model") and selectedOres[desc.Name] and desc.Parent ~= workspace.Ores then
                    table.insert(oreList, { instance = desc, name = desc.Name })
                end
            end
        end

        hubLog(string.format("[AutoMine]  Tim thay %d ore node hop le.", #oreList))

        if #oreList > 0 then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local curPos = root and root.Position or Vector3.zero

            -- Sap xep Nearest Neighbor gom ore node nearby nhau
            local sortedOreList = {}
            local remainingOres = {}
            for _, o in ipairs(oreList) do table.insert(remainingOres, o) end

            while #remainingOres > 0 do
                local nearestIdx = 1
                local nearestDist = math.huge
                for idx, oData in ipairs(remainingOres) do
                    local oInst = oData.instance
                    if oInst and oInst.Parent then
                        local d = (curPos - oInst:GetPivot().Position).Magnitude
                        if d < nearestDist then
                            nearestDist = d
                            nearestIdx = idx
                        end
                    end
                end
                local bestOre = table.remove(remainingOres, nearestIdx)
                table.insert(sortedOreList, bestOre)
                if bestOre.instance and bestOre.instance.Parent then
                    curPos = bestOre.instance:GetPivot().Position
                end
            end
            oreList = sortedOreList

            local minedCount = 0
            for i, oreData in ipairs(oreList) do
                if not Miner.running then break end
                local ore = oreData.instance
                local oreName = oreData.name
                if ore and ore.Parent then
                    local targetPos = ore:GetPivot().Position
                    hubLog(string.format("[AutoMine]  [%d/%d] is fly toi mo %s tai (%.1f, %.1f, %.1f)...", i, #oreList, oreName, targetPos.X, targetPos.Y, targetPos.Z))

                    local flew = flyToItem(targetPos, function() return Miner.running end)
                    if flew and ore and ore.Parent then
                        local done = mineOreNode(ore)
                        if done then
                            minedCount = minedCount + 1
                            hubLog(string.format("[AutoMine]  has dao xong mo %s!", oreName))
                        end
                        task.wait(0.4)
                    end
                end
            end

            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and Miner.running then
                local skyHeight = Options.SkyHeight and Options.SkyHeight.Value or 1500
                local ascendSpeed = Options.AscendSpeed and Options.AscendSpeed.Value or 150
                smoothTweenTo(CFrame.new(root.Position.X, skyHeight, root.Position.Z), ascendSpeed, function() return Miner.running end)
            end
        else
            hubLog("[AutoMine]  Server not co quang muc tieu!")
        end

        disableFlightState()

        if Toggles.AutoServerHop and Toggles.AutoServerHop.Value and Miner.running then
            task.wait(1)
            ServerHopper.hop()
        end
    end)
end

function Miner.stop()
    Miner.running = false
    if FlightController.currentTween then
        FlightController.currentTween:Cancel()
        FlightController.currentTween = nil
    end
    disableFlightState()
    hubLog("[AutoMine] has stop Auto Mine.")
end

-- =============================================================================
-- AUTO COMBAT QTE ENGINE (BLATANT REMOTE HOOK + LEGIT PIXEL SWEET SPOT)
-- =============================================================================
local originalQTEFunctions = {}
local qteHookInstalled = false

local qteTargetHandlers = {
    ["DodgeQTE"] = function(params)
        if type(params) == "table" then
            local blockWin = tonumber(params.BlockWindow) or 1
            local dodgeWin = tonumber(params.DodgeWindow) or 1
            if dodgeWin > 0 and blockWin > 0 then
                return { true, true } -- Perfect Dodge + Perfect Block
            elseif dodgeWin > 0 and blockWin <= 0 then
                return { false, true } -- Unblockable Attack -> Dodge Only
            elseif blockWin > 0 and dodgeWin <= 0 then
                return { true, false } -- Undodgeable / Block-Only Attack -> Block Only (Prevents server soft-lock)
            else
                return { true, false }
            end
        end
        return { true, true }
    end,
    ["YarthulQTE"] = function(params) return { true, 0 } end,
    ["ThorianQTE"] = function(params) return true end,
    ["SwordQTE"] = function(params) return true end,
    ["DaggerQTE"] = function(params) return true end,
    ["MagicQTE"] = function(params) return true end,
    ["SpearQTE"] = function(params) return true end,
    ["FistQTE"] = function(params) return true end,
    ["HammerQTE"] = function(params) return true end,
    ["AxeQTE"] = function(params) return true end,
    ["LockpickQTE"] = function(params) return true end,
    ["WG_GospelQTE"] = function(params) return true end,
}

local function installBlatantQTEHook()
    if qteHookInstalled then return end
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        local rf = rep:FindFirstChild("Remotes") and rep.Remotes:FindFirstChild("Information") and rep.Remotes.Information:FindFirstChild("RemoteFunction")
        if not rf or not getconnections or not getupvalues then return end

        for _, conn in ipairs(getconnections(rf.OnClientEvent)) do
            local fn = conn.Function
            if fn then
                local uvs = getupvalues(fn)
                if uvs and type(uvs[1]) == "table" and uvs[1].DodgeQTE then
                    local qteTable = uvs[1]
                    for qName, handler in pairs(qteTargetHandlers) do
                        local origFn = qteTable[qName]
                        if type(origFn) == "function" and not originalQTEFunctions[qName] then
                            originalQTEFunctions[qName] = origFn
                            
                            qteTable[qName] = function(params)
                                local masterOn = Toggles.MasterQTE and Toggles.MasterQTE.Value
                                local isBlatant = Options.QTEMode and Options.QTEMode.Value == "Blatant"

                                if masterOn and isBlatant then
                                    return handler(params)
                                end

                                return originalQTEFunctions[qName](params)
                            end
                        end
                    end
                    qteHookInstalled = true
                    break
                end
            end
        end
    end)
end

task.spawn(function()
    task.wait(1)
    installBlatantQTEHook()
end)

-- AUTO COMBAT QTE ENGINE (SINGLE-CLICK, 0.25S DEBOUNCED SWEET SPOT ENGINE)
-- =============================================================================
local DaggerArcSizes = { 20, 25, 30, 35, 40, 45, 55, 65, 75, 85, 95, 105 }

local function isQTEActive(qteName)
    if Toggles.MasterQTE and not Toggles.MasterQTE.Value then return false end
    return true
end

local AutoQTE = {
    lastDodgeHit = 0,
    lastSwordHit = 0,
    currentSwordIndex = 1,
    lastDaggerHit = 0,
    isHammerHolding = false,
    lastAxePress = 0,
    lastMagicHit = 0,
    isMagicSolving = false,
    currentTargetRuneName = nil,
    lastFistHit = 0,
    swordHitTable = {},
    hitWeakpoints = {},
    magicSlottedTable = {},
    spearSolvedTable = {},
}

-- 1. DODGE QTE (PERFECT DODGE 100% / BLOCK)
local function handleDodgeQTE(dodgeQTE)
    if not isQTEActive("Dodge") or not dodgeQTE or not dodgeQTE.Visible then return end
    local inset = dodgeQTE:FindFirstChild("Inset")
    local stopBtn = dodgeQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local indicator = inset:FindFirstChild("Indicator")
    local dodgeZone = inset:FindFirstChild("Dodge")
    local blockZone = inset:FindFirstChild("Block")
    if not indicator or not indicator.Visible then return end

    local targetZone = (Toggles.PreferPerfectDodge and Toggles.PreferPerfectDodge.Value and dodgeZone and dodgeZone.Visible) and dodgeZone or blockZone
    if not targetZone then return end

    local indLeft = indicator.AbsolutePosition.X
    local indRight = indLeft + indicator.AbsoluteSize.X
    local indCenter = indLeft + (indicator.AbsoluteSize.X / 2)
    local targetLeft = targetZone.AbsolutePosition.X
    local targetRight = targetLeft + targetZone.AbsoluteSize.X

    if (indRight >= targetLeft and indLeft <= targetRight) or (indCenter >= targetLeft and indCenter <= targetRight) then
        local now = os.clock()
        if now - AutoQTE.lastDodgeHit > 0.25 then
            AutoQTE.lastDodgeHit = now
            local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
            if delayMs > 0 then task.wait(delayMs / 1000) end
            singleClick(stopBtn)
        end
    end
end

-- 2. SWORD QTE (PERFECT MULTI-SLASH SEQUENTIAL SWEET SPOT ENGINE)
local function handleSwordQTE(swordQTE)
    if not isQTEActive("Sword") or not swordQTE or not swordQTE.Visible then
        AutoQTE.swordHitTable = {}
        AutoQTE.currentSwordIndex = 1
        return
    end

    local inset = swordQTE:FindFirstChild("Inset")
    local stopBtn = swordQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local window = inset:FindFirstChild("Window")
    if not window or not window.Visible then return end

    -- Tìm Indicator đang hoạt động theo chỉ số tuần tự của game (1, 2, 3, 4...)
    local targetInd = inset:FindFirstChild(tostring(AutoQTE.currentSwordIndex))
    if not targetInd or not targetInd.Visible or AutoQTE.swordHitTable[targetInd] then
        -- Fallback: Tìm indicator có chỉ số nhỏ nhất chưa bấm và đang hiển thị
        local lowestIdx = math.huge
        targetInd = nil
        for _, child in ipairs(inset:GetChildren()) do
            local idx = tonumber(child.Name)
            if idx and not AutoQTE.swordHitTable[child] and child:IsA("GuiObject") and child.Visible and child.BackgroundTransparency < 0.5 then
                if idx < lowestIdx then
                    lowestIdx = idx
                    targetInd = child
                    AutoQTE.currentSwordIndex = idx
                end
            end
        end
    end

    if not targetInd then return end

    local indLeft = targetInd.AbsolutePosition.X
    local indWidth = targetInd.AbsoluteSize.X
    local indRight = indLeft + indWidth
    local indCenter = indLeft + (indWidth / 2)

    local winLeft = window.AbsolutePosition.X
    local winWidth = window.AbsoluteSize.X
    local winRight = winLeft + winWidth

    -- Tính toán vùng tâm trúng chuẩn (Sweet Spot) an toàn bên trong Window
    local sweetSpotMin = winLeft + (winWidth * 0.25)
    local sweetSpotMax = winRight - (winWidth * 0.15)

    local isColliding = false
    if GuiCollisionService and GuiCollisionService.isColliding then
        pcall(function()
            isColliding = GuiCollisionService.isColliding(targetInd, window)
        end)
    end

    -- Chỉ bấm khi Indicator đã thực sự tiến vào vùng tâm của Window (Tránh bấm sớm ở các super class như Berserker)
    if (indCenter >= sweetSpotMin and indCenter <= sweetSpotMax) or (isColliding and indLeft >= winLeft and indRight <= winRight + 5) then
        AutoQTE.lastSwordHit = os.clock()
        AutoQTE.swordHitTable[targetInd] = true
        AutoQTE.currentSwordIndex = AutoQTE.currentSwordIndex + 1

        local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
        if delayMs > 0 then task.wait(delayMs / 1000) end

        singleClick(stopBtn)
    end
end

-- 3. DAGGER QTE (DYNAMIC ARC-SIZE WEAKPOINT PRECISION TRACKING)
local function handleDaggerQTE(daggerQTE)
    if not isQTEActive("Dagger") or not daggerQTE or not daggerQTE.Visible then
        AutoQTE.hitWeakpoints = {}
        return
    end
    local stopBtn = daggerQTE:FindFirstChild("Stop")
    local activeRing = daggerQTE:FindFirstChild("ActiveRing")
    if not activeRing then return end

    local targetAngle = -activeRing.Rotation % 360
    if targetAngle < 0 then targetAngle = targetAngle + 360 end

    for _, wp in ipairs(activeRing:GetChildren()) do
        if wp.Name == "Weakpoint" and wp:IsA("GuiObject") and not AutoQTE.hitWeakpoints[wp] and wp.ImageTransparency < 0.3 then
            local wpAngle = wp.Rotation % 360
            local diff = (targetAngle - wpAngle) % 360
            if diff < 0 then diff = diff + 360 end
            if diff > 180 then diff = diff - 360 end

            local arcIndex = 1
            if wp:IsA("ImageLabel") then
                local col = math.floor(wp.ImageRectOffset.X / 256)
                local row = math.floor(wp.ImageRectOffset.Y / 256)
                arcIndex = (row * 4) + col + 1
            end
            local arcSize = DaggerArcSizes[arcIndex] or 25
            local maxTolerance = (arcSize * 0.5) * 0.85

            if math.abs(diff) <= maxTolerance then
                AutoQTE.hitWeakpoints[wp] = true
                local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
                if delayMs > 0 then task.wait(delayMs / 1000) end
                if stopBtn then singleClick(stopBtn) else pressKey(Enum.KeyCode.Space) end
                break
            end
        end
    end
end

-- 4. HAMMER QTE (HOLD/RELEASE SPACE PID CONTROLLER)
local function handleHammerQTE(hammerQTE)
    if not isQTEActive("Hammer") or not hammerQTE or not hammerQTE.Visible then
        if AutoQTE.isHammerHolding then
            AutoQTE.isHammerHolding = false
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end
        return
    end

    local gauge = hammerQTE:FindFirstChild("Gauge")
    if not gauge then return end

    local fill = gauge:FindFirstChild("Fill")
    local activeZone = gauge:FindFirstChildWhichIsA("Frame", true)
    for _, child in ipairs(gauge:GetChildren()) do
        if child.Name == "Zone" or child.Name:find("Zone") or child.Name == "Window" then
            activeZone = child
            break
        end
    end
    if not fill or not activeZone then return end

    local fillPos = fill.AbsolutePosition.X + fill.AbsoluteSize.X
    local zoneMin = activeZone.AbsolutePosition.X
    local zoneMax = zoneMin + activeZone.AbsoluteSize.X
    local zoneCenter = (zoneMin + zoneMax) / 2

    if fillPos < zoneCenter then
        if not AutoQTE.isHammerHolding then
            AutoQTE.isHammerHolding = true
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        end
    else
        if AutoQTE.isHammerHolding then
            AutoQTE.isHammerHolding = false
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end
    end
end

-- 5. AXE QTE (PRECISION THRESHOLD EQUILIBRIUM TAPPER - ANTI-OVERSHOOT)
local function handleAxeQTE(axeQTE)
    if not isQTEActive("Axe") or not axeQTE or not axeQTE.Visible then return end
    local gauge = axeQTE:FindFirstChild("Gauge")
    local spaceHint = axeQTE:FindFirstChild("SpaceHint")
    if not gauge then return end

    local fill = gauge:FindFirstChild("Fill")
    local threshold = gauge:FindFirstChild("Threshold")
    if not fill or not threshold then return end

    local gaugeWidth = gauge.AbsoluteSize.X
    if gaugeWidth <= 0 then gaugeWidth = 1 end

    local targetStart = (threshold.AbsolutePosition.X - gauge.AbsolutePosition.X) / gaugeWidth
    local targetWidth = threshold.AbsoluteSize.X / gaugeWidth
    local currentFill = fill.AbsoluteSize.X / gaugeWidth

    -- Điểm kích hoạt an toàn: Chỉ bấm khi thanh tuột xuống dưới đáy hoặc rơi vào 15% phần dưới của vùng Threshold
    -- Giúp ngăn chặn tuyệt đối việc nhảy lố (overshoot) ở các độ khó cao khi vùng Threshold bị thu hẹp
    local targetBottomSafeZone = targetStart + (targetWidth * 0.15)

    if currentFill <= targetBottomSafeZone then
        local now = os.clock()
        if now - AutoQTE.lastAxePress > 0.16 then
            AutoQTE.lastAxePress = now
            local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
            if delayMs > 0 then task.wait(delayMs / 1000) end
            if spaceHint then singleClick(spaceHint) end
            pressKey(Enum.KeyCode.Space)
        end
    end
end

-- 6. STAFF / MAGIC QTE (CONTINUOUS BATCH NATIVE CLOSURE SOLVER WITH DUPLICATE TRACKING)
local function handleMagicQTE(magicQTE)
    if not isQTEActive("Magic") or not magicQTE or not magicQTE.Visible then
        AutoQTE.magicSlottedTable = {}
        return
    end

    local bag = magicQTE:FindFirstChild("Bag")
    local runeSlots = magicQTE:FindFirstChild("RuneSlots")
    if not bag or not runeSlots then return end

    local bagRunes = bag:GetChildren()
    local slotChildren = runeSlots:GetChildren()
    if #bagRunes == 0 or #slotChildren == 0 then return end

    local getconns = getconnections
    local setuv = setupvalue or (debug and debug.setupvalue)

    local usedSlots = {}
    local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0

    for _, rune in ipairs(bagRunes) do
        if rune:IsA("GuiObject") and rune.Visible and rune.Name ~= "Slotted" and rune.ImageTransparency < 0.9 and not AutoQTE.magicSlottedTable[rune] then
            local runeName = rune.Name

            -- Tìm ô Slot mục tiêu tương ứng chưa được sử dụng trong round này
            local matchingSlot = nil
            for _, slot in ipairs(slotChildren) do
                if slot:IsA("GuiObject") and slot.Name == runeName and slot.Name ~= "Slotted" and not usedSlots[slot] then
                    matchingSlot = slot
                    usedSlots[slot] = true
                    break
                end
            end

            if matchingSlot then
                AutoQTE.magicSlottedTable[rune] = true
                
                task.spawn(function()
                    if delayMs > 0 then task.wait(delayMs / 1000) end

                    local slotted = false

                    -- Phương pháp 1: Native Closure Injection trực tiếp vào closure InputEnded
                    if getconns and setuv then
                        local conns = getconns(rune.InputEnded)
                        if conns and #conns > 0 then
                            local fn = conns[1].Function
                            if fn then
                                pcall(function()
                                    setuv(fn, 2, true)  -- u11 = true (isDragging)
                                    setuv(fn, 3, rune)  -- u12 = rune (draggedRune)
                                    setuv(fn, 4, function() return matchingSlot end) -- GetHoveringOnGuiName
                                    setuv(fn, 6, function() return matchingSlot end) -- GetHoveringOnGuiNameWithOrigin
                                    setuv(fn, 8, false) -- u10 = false (clear debounce)

                                    local fakeInput = {
                                        UserInputType = Enum.UserInputType.MouseButton1,
                                        Position = Vector3.new(0, 0, 0)
                                    }
                                    fn(fakeInput)
                                    slotted = true
                                end)
                            end
                        end
                    end

                    -- Cập nhật trực quan và phát âm thanh slot
                    rune.Name = "Slotted"
                    rune.ImageTransparency = 1
                    rune.Visible = false
                    matchingSlot.Name = "Slotted"
                    matchingSlot.ImageColor3 = Color3.new(1, 1, 1)

                    if magicQTE:FindFirstChild("RuneSlotIn") then
                        pcall(function() magicQTE.RuneSlotIn:Play() end)
                    end

                    -- Phương pháp 2: Fallback chuột giả lập nếu closure không khả dụng
                    if not slotted then
                        local runePos = rune.AbsolutePosition + (rune.AbsoluteSize / 2)
                        local slotPos = matchingSlot.AbsolutePosition + (matchingSlot.AbsoluteSize / 2)

                        pcall(function()
                            VirtualInputManager:SendMouseMoveEvent(runePos.X, runePos.Y, game)
                            VirtualInputManager:SendMouseButtonEvent(runePos.X, runePos.Y, 0, true, game, 0)
                        end)
                        task.wait(0.015)
                        pcall(function()
                            VirtualInputManager:SendMouseMoveEvent(slotPos.X, slotPos.Y, game)
                            VirtualInputManager:SendMouseButtonEvent(slotPos.X, slotPos.Y, 0, false, game, 0)
                        end)
                        if firesignal then
                            local fakeEnd = {
                                UserInputType = Enum.UserInputType.MouseButton1,
                                Position = Vector3.new(slotPos.X, slotPos.Y, 0)
                            }
                            pcall(function() firesignal(rune.InputEnded, fakeEnd) end)
                        end
                    end
                end)
            end
        end
    end
end

-- 6. FIST / CESTUS QTE (SEQUENTIAL COMBO ARROWS)
local function handleFistQTE(fistQTE)
    if not isQTEActive("Fist") or not fistQTE or not fistQTE.Visible then return end
    local keyHolder = fistQTE:FindFirstChild("KeyHolder") or fistQTE:FindFirstChild("Inset")
    local otherControls = fistQTE:FindFirstChild("OtherControls")
    local keysFolder = (keyHolder and keyHolder:FindFirstChild("Keys")) or keyHolder
    if not keysFolder then return end

    local currentArrow = nil
    local lowestIndex = math.huge

    for _, child in ipairs(keysFolder:GetChildren()) do
        local num = child.Name:match("^(%d+)")
        local idx = tonumber(num)
        if idx and idx < lowestIndex and child:IsA("GuiObject") and child.Visible and child.BackgroundTransparency < 0.4 then
            lowestIndex = idx
            currentArrow = child
        end
    end

    if not currentArrow then return end

    local icon = currentArrow:FindFirstChild("Icon") or currentArrow
    local rot = icon.Rotation % 360
    local name = currentArrow.Name:lower()

    local now = os.clock()
    if now - AutoQTE.lastFistHit > 0.08 then
        AutoQTE.lastFistHit = now
        local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
        if delayMs > 0 then task.wait(delayMs / 1000) end

        if rot == 90 or name:find("up") then
            pressKey(Enum.KeyCode.Up)
            pressKey(Enum.KeyCode.W)
            if otherControls and otherControls:FindFirstChild("Up") then singleClick(otherControls.Up) end
        elseif rot == 180 or name:find("right") then
            pressKey(Enum.KeyCode.Right)
            pressKey(Enum.KeyCode.D)
            if otherControls and otherControls:FindFirstChild("Right") then singleClick(otherControls.Right) end
        elseif rot == 270 or name:find("down") then
            pressKey(Enum.KeyCode.Down)
            pressKey(Enum.KeyCode.S)
            if otherControls and otherControls:FindFirstChild("Down") then singleClick(otherControls.Down) end
        elseif rot == 0 or name:find("left") then
            pressKey(Enum.KeyCode.Left)
            pressKey(Enum.KeyCode.A)
            if otherControls and otherControls:FindFirstChild("Left") then singleClick(otherControls.Left) end
        end
    end
end

-- 7. SPEAR QTE (INSTANT NATIVE CLOSURE RESOLVER FOR TAPS, LINES & CURVES)

local function handleYarthulQTE(yarthulQTE)
    if not yarthulQTE or not yarthulQTE.Visible then return end
    pcall(function()
        local gameFrame = yarthulQTE:FindFirstChild("Game")
        local arena = gameFrame and gameFrame:FindFirstChild("Arena")
        if arena then
            local playerFrame = arena:FindFirstChild("Player")
            if playerFrame then
                playerFrame.Position = UDim2.new(-50, 0, -50, 0)
            end
            for _, obj in ipairs(arena:GetChildren()) do
                if obj ~= playerFrame and obj:IsA("GuiObject") and obj.Name ~= "UIListLayout" and obj.Name ~= "UIGridLayout" then
                    obj.Position = UDim2.new(50, 0, 50, 0)
                end
            end
        end
    end)
end

local function handleSpearQTE(spearQTE)
    if not isQTEActive("Spear") or not spearQTE or not spearQTE.Visible then
        AutoQTE.spearSolvedTable = {}
        return
    end

    local container = spearQTE:FindFirstChild("Container")
    if not container then return end

    local getconns = getconnections
    local getuvs = getupvalues or (debug and debug.getupvalues)
    local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0

    for _, targetFrame in ipairs(container:GetChildren()) do
        if targetFrame:IsA("GuiObject") and targetFrame.Visible and targetFrame.Name:match("^C%d+") and not AutoQTE.spearSolvedTable[targetFrame] then
            local btn = targetFrame:FindFirstChild("InputButton", true) or targetFrame:FindFirstChildWhichIsA("ImageButton", true) or targetFrame:FindFirstChildWhichIsA("TextButton", true)

            if btn and btn.Active == true then
                AutoQTE.spearSolvedTable[targetFrame] = true

                task.spawn(function()
                    if delayMs > 0 then task.wait(delayMs / 1000) end

                    local resolved = false

                    -- Phương pháp 1: Native Closure Resolution (Giải trực tiếp Tap, Line slider và Curve slider)
                    if getconns and getuvs then
                        local connsAct = getconns(btn.Activated)
                        local connsBeg = getconns(btn.InputBegan)

                        -- A. Tap Target (Activated connection)
                        if connsAct and #connsAct > 0 then
                            local fn = connsAct[1].Function
                            if fn then
                                pcall(fn)
                                resolved = true
                            end
                        end

                        -- B. Line / Curve Slider (InputBegan connection -> resolveFn)
                        if not resolved and connsBeg and #connsBeg > 0 then
                            local fn = connsBeg[1].Function
                            if fn then
                                local uvs = getuvs(fn)
                                local targetTable = nil
                                local resolveFn = nil

                                for _, v in pairs(uvs) do
                                    if type(v) == "table" and (v.kind == "line" or v.kind == "curve" or v.kind == "tap" or v.frame == targetFrame) then
                                        targetTable = v
                                    elseif type(v) == "function" then
                                        resolveFn = v
                                    end
                                end

                                if targetTable and resolveFn and not targetTable.resolved then
                                    pcall(function()
                                        resolveFn(targetTable, true)
                                    end)
                                    resolved = true
                                end
                            end
                        end
                    end

                    -- Phương pháp 2: Hardware & Software Signal Fallback
                    if not resolved then
                        local btnCenterX = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2
                        local btnCenterY = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
                        local startInput = {
                            UserInputType = Enum.UserInputType.MouseButton1,
                            Position = Vector3.new(btnCenterX, btnCenterY, 0)
                        }

                        if firesignal then
                            pcall(function() firesignal(btn.Activated) end)
                            pcall(function() firesignal(btn.MouseButton1Click) end)
                            pcall(function() firesignal(btn.InputBegan, startInput) end)
                        end
                        pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(btnCenterX, btnCenterY, 0, true, game, 0)
                            task.wait(0.01)
                            VirtualInputManager:SendMouseButtonEvent(btnCenterX, btnCenterY, 0, false, game, 0)
                        end)
                    end
                end)
            end
        end
    end
end

-- 8. LOCKPICK QTE (CHEST UNLOCKER)
local function handleLockpickQTE(lockpickQTE)
    if not isQTEActive("Lockpick") or not lockpickQTE or not lockpickQTE.Visible then return end
    local stopBtn = lockpickQTE:FindFirstChild("Stop", true) or lockpickQTE:FindFirstChildWhichIsA("TextButton", true)
    local pickBtn = lockpickQTE:FindFirstChild("Pick", true) or lockpickQTE:FindFirstChild("Blade", true)
    local indicator = lockpickQTE:FindFirstChild("Indicator", true)
    local target = lockpickQTE:FindFirstChild("Zone", true) or lockpickQTE:FindFirstChild("Window", true) or lockpickQTE:FindFirstChild("Target", true)

    if stopBtn and indicator and target then
        local indCenter = indicator.AbsolutePosition.X + (indicator.AbsoluteSize.X / 2)
        local tMin = target.AbsolutePosition.X
        local tMax = tMin + target.AbsoluteSize.X

        if indCenter >= tMin and indCenter <= tMax then
            singleClick(stopBtn)
        end
    elseif pickBtn and pickBtn:IsA("GuiButton") and pickBtn.Visible then
        singleClick(pickBtn)
    end
end

registerConnection(RunService.RenderStepped:Connect(function()
    local combatGui = PlayerGui and PlayerGui:FindFirstChild("Combat")
    if not combatGui or not Toggles.MasterQTE or not Toggles.MasterQTE.Value then
        AutoQTE.swordHitTable = {}
        AutoQTE.hitWeakpoints = {}
        return
    end

    local dodgeQTE = combatGui:FindFirstChild("DodgeQTE")
    local swordQTE = combatGui:FindFirstChild("SwordQTE")
    local daggerQTE = combatGui:FindFirstChild("DaggerQTE")
    local hammerQTE = combatGui:FindFirstChild("HammerQTE")
    local axeQTE = combatGui:FindFirstChild("AxeQTE")
    local magicQTE = combatGui:FindFirstChild("MagicQTE")
    local mochiiMagicQTE = combatGui:FindFirstChild("MochiiMagicQTE")
    local fistQTE = combatGui:FindFirstChild("FistQTE")
    local spearQTE = combatGui:FindFirstChild("SpearQTE")
    local lockpickQTE = combatGui:FindFirstChild("LockpickQTE")
    local yarthulQTE = combatGui:FindFirstChild("YarthulQTE")

    if dodgeQTE and dodgeQTE.Visible then handleDodgeQTE(dodgeQTE) end
    if swordQTE and swordQTE.Visible then
        handleSwordQTE(swordQTE)
    else
        AutoQTE.swordHitTable = {}
        AutoQTE.currentSwordIndex = 1
    end

    if daggerQTE and daggerQTE.Visible then
        handleDaggerQTE(daggerQTE)
    else
        AutoQTE.hitWeakpoints = {}
    end

    if hammerQTE and hammerQTE.Visible then handleHammerQTE(hammerQTE) end
    if axeQTE and axeQTE.Visible then handleAxeQTE(axeQTE) end
        if magicQTE and magicQTE.Visible then
        handleMagicQTE(magicQTE)
    elseif mochiiMagicQTE and mochiiMagicQTE.Visible then
        handleMagicQTE(mochiiMagicQTE)
    else
        AutoQTE.magicSlottedTable = {}
        AutoQTE.isMagicSolving = false
    end
    if fistQTE and fistQTE.Visible then handleFistQTE(fistQTE) end
    if spearQTE and spearQTE.Visible then
        handleSpearQTE(spearQTE)
    else
        if next(AutoQTE.spearSolvedTable) ~= nil then
            AutoQTE.spearSolvedTable = {}
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end
    end
    if lockpickQTE and lockpickQTE.Visible then handleLockpickQTE(lockpickQTE) end
    if yarthulQTE and yarthulQTE.Visible then handleYarthulQTE(yarthulQTE) end
end))


-- =============================================================================
-- MOVEMENT CONTROLLER (FLY, NOCLIP, SPEEDHACK, CFRAME SPEED, INFINITE JUMP)
-- =============================================================================

local Movement = {
    flyBodyVelocity = nil,
}

registerConnection(RunService.Stepped:Connect(function()
    if Toggles.NoClip and Toggles.NoClip.Value and not FlightController.active then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end))

registerConnection(RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera

    if Toggles.Fly and Toggles.Fly.Value and hrp and hum and cam and not FlightController.active then
        if not Movement.flyBodyVelocity or Movement.flyBodyVelocity.Parent ~= hrp then
            if Movement.flyBodyVelocity then Movement.flyBodyVelocity:Destroy() end
            local bv = Instance.new("BodyVelocity")
            bv.Name = "ArcaneFlyVelocity"
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Velocity = Vector3.zero
            bv.Parent = hrp
            Movement.flyBodyVelocity = bv
        end

        local moveVec = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + Vector3.new(1, 0, 0) end

        local flySpeed = Options.FlySpeed and Options.FlySpeed.Value or 120
        local flyUpSpeed = Options.FlyUpSpeed and Options.FlyUpSpeed.Value or 80

        local worldVelocity = Vector3.zero
        if moveVec.Magnitude > 0 then
            worldVelocity = cam.CFrame:VectorToWorldSpace(moveVec.Unit * flySpeed)
        end

        local verticalSpeed = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            verticalSpeed = verticalSpeed + flyUpSpeed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            verticalSpeed = verticalSpeed - flyUpSpeed
        end

        Movement.flyBodyVelocity.Velocity = Vector3.new(worldVelocity.X, worldVelocity.Y + verticalSpeed, worldVelocity.Z)
    else
        if Movement.flyBodyVelocity and not FlightController.active then
            Movement.flyBodyVelocity:Destroy()
            Movement.flyBodyVelocity = nil
        end
    end
end))

registerConnection(RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or FlightController.active then return end

    if Toggles.Fly and Toggles.Fly.Value then return end

    if Toggles.Speedhack and Toggles.Speedhack.Value then
        local moveDir = hum.MoveDirection
        local speed = Options.SpeedhackSpeed and Options.SpeedhackSpeed.Value or 50
        if moveDir.Magnitude > 0.001 then
            hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * speed, hrp.AssemblyLinearVelocity.Y, moveDir.Z * speed)
        end
    end

    if Toggles.CFrameSpeed and Toggles.CFrameSpeed.Value then
        local moveDir = hum.MoveDirection
        local mult = Options.CFrameSpeedMult and Options.CFrameSpeedMult.Value or 30
        if moveDir.Magnitude > 0.001 then
            hrp.CFrame = hrp.CFrame + moveDir * (mult * dt)
        end
    end

    if Toggles.InfiniteJump and Toggles.InfiniteJump.Value then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            local boost = Options.InfiniteJumpBoost and Options.InfiniteJumpBoost.Value or 50
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, boost, hrp.AssemblyLinearVelocity.Z)
        end
    end
end))

-- =============================================================================
-- TELEPORT SUITE (ALL 35+ CLASS TRAINERS, TOWNS, MERCHANTS, AND LANDMARKS)
-- =============================================================================

-- =============================================================================
-- TELEPORT SUITE (ALL 40+ ACCURATE CLASS TRAINERS, TOWNS, BOSSES & LANDMARKS)
-- =============================================================================

-- =============================================================================
-- TELEPORT SUITE: ORGANIZED TRAINERS, QUESTS (ORDER/CHAOS), NPCS & LANDMARKS
-- =============================================================================
local BaseTrainers = {
    ["Base: Doran (Warrior - Sword)"]               = Vector3.new(5627.8, 703.8, -4336.9),
    ["Base: Luther (Thief - Dagger)"]                = Vector3.new(3496.5, 632.8, -3983.3),
    ["Base: Aberon (Martial Artist - Fist / Cestus)"]= Vector3.new(2800.0, 610.7, -4018.2),
    ["Base: Arandor (Wizard - Magic / Staff)"]       = Vector3.new(5840.1, 727.0, -4790.1),
    ["Base: Tivek (Slayer - Spear / Lancer)"]        = Vector3.new(4473.3, 650.1, -5730.3),
    ["Base: Geron (Berserker / Marauder - Axe)"]     = Vector3.new(4448.3, 652.1, -3359.3),
    ["Base: Lagolt (Sentry - Greatsword)"]           = Vector3.new(4651.7, 718.7, -5574.9),
}

local SuperTrainers = {
    ["Super: Dernon (Paladin - Order Warrior)"]       = Vector3.new(2813.0, 615.7, -3866.6),
    ["Super: Leoran (Blade Dancer - Sword)"]         = Vector3.new(4995.5, 754.4, -6194.1),
    ["Super: Kayrein (Berserker - Chaos Warrior)"]    = Vector3.new(11342.1, 1500.1, -3656.7),
    ["Super: Landrum (Elementalist - Wizard)"]       = Vector3.new(2473.2, 624.7, -3540.3),
    ["Super: Ophelia (Hexer - Wizard)"]              = Vector3.new(4661.7, 651.7, -5236.5),
    ["Super: Ulys (Necromancer - Chaos Wizard)"]     = Vector3.new(10847.3, 1589.0, -4091.8),
    ["Super: Orkin (Ranger - Bow & Dagger)"]         = Vector3.new(8546.3, 822.7, -5544.1),
    ["Super: Aberon (Rogue - Thief)"]                = Vector3.new(2800.0, 610.7, -4018.2),
    ["Super: Inette (Assassin - Chaos Thief)"]       = Vector3.new(6699.0, 568.2, -3461.3),
    ["Super: Luther (Monk - Order Martial Artist)"]  = Vector3.new(3496.5, 632.8, -3983.3),
    ["Super: Gren (Brawler - Martial Artist)"]       = Vector3.new(5170.9, 660.5, -4996.0),
    ["Super: Momma Darkbeast (Darkwraith - Chaos)"]  = Vector3.new(8122.6, 581.8, -2138.1),
    ["Super: Fernain (Saint - Order Slayer)"]        = Vector3.new(2296.1, 663.3, -4392.7),
    ["Super: Relan (Lancer - Slayer)"]               = Vector3.new(5322.2, 749.4, -6324.2),
    ["Super: Orin (Impaler - Chaos Slayer)"]         = Vector3.new(8043.9, 822.6, -5599.3),
    ["Super: Ardentis (Lionheart - Order Sentry)"]   = Vector3.new(474.5, 581.5, -4816.9),
    ["Super: Nevithas (Citadel - Defensive Sentry)"] = Vector3.new(71.9, 2765.7, -3266.4),
    ["Super: Kether (Arbiter - Endgame Order)"]      = Vector3.new(7821.2, 1279.8, 8480.1),
    ["Super: Chronomancer (Time Mage)"]              = Vector3.new(10825.4, 1585.1, -3450.2),
    ["Super: Dragon Knight (Mount Thul Peak)"]       = Vector3.new(12.5, 585.4, -4120.8),
}

local SubclassTrainers = {
    ["Sub: Cantia (Bard - Melody Specialist)"]       = Vector3.new(2845.8, 624.1, -3222.9),
    ["Sub: Thorin (Beastmaster - Pet Specialist)"]   = Vector3.new(4253.1, 653.8, -3369.2),
    ["Sub: Selia (Alchemist - Potion Master)"]       = Vector3.new(8116.2, 822.5, -5456.4),
    ["Sub: Adelma (Blacksmith Subclass)"]           = Vector3.new(-425.4, 2712.7, -3388.1),
    ["Sub: Vanio (Miner - Ore Master)"]             = Vector3.new(7572.0, 593.2, -2674.0),
}

local IsClassTrainer = {}
local function buildTrainerLookup()
    for name, _ in pairs(BaseTrainers or {}) do
        local clean = name:gsub("^.-:%s*", ""):gsub("%s*%b()", ""):gsub("^%s*(.-)%s*$", "%1")
        IsClassTrainer[clean] = true
        IsClassTrainer[name] = true
    end
    for name, _ in pairs(SuperTrainers or {}) do
        local clean = name:gsub("^.-:%s*", ""):gsub("%s*%b()", ""):gsub("^%s*(.-)%s*$", "%1")
        IsClassTrainer[clean] = true
        IsClassTrainer[name] = true
    end
    for name, _ in pairs(SubclassTrainers or {}) do
        local clean = name:gsub("^.-:%s*", ""):gsub("%s*%b()", ""):gsub("^%s*(.-)%s*$", "%1")
        IsClassTrainer[clean] = true
        IsClassTrainer[name] = true
    end
end
pcall(buildTrainerLookup)


local QuestNPCs = {
    ["[Orderly] Prelate Fyran (Order Path Sanctuary)"]= Vector3.new(8459.8, 822.4, -5885.1),
    ["[Orderly] Saint Fernain (Order Path Shrine)"]   = Vector3.new(2296.1, 663.3, -4392.7),
    ["[Orderly] Heavens Point Church (Holy Blessing)"]= Vector3.new(831.6, 3436.9, -5602.3),
    ["[Orderly] Aretim Peak (Soul Meditation)"]       = Vector3.new(5075.4, 720.5, -4380.2),
    ["[Chaotic] Thuriaz (Chaos Transformation Path)"] = Vector3.new(2151.2, 519.8, -3394.1),
    ["[Chaotic] Jyphar (Cursed Enchant Quest)"]       = Vector3.new(7246.1, 619.2, -4672.5),
    ["[Chaotic] Dead King (Reaper Enchant Quest)"]    = Vector3.new(2623.8, 556.4, -4660.0),
    ["[Chaotic] Bone Man (Necromancy Crypt Quest)"]   = Vector3.new(1397.0, 610.3, -4097.6),
    ["[Chaotic] Momma Darkbeast (Darkwraith Altar)"]  = Vector3.new(8122.6, 581.8, -2138.1),
    ["[Neutral] Lodyssa (God of Wealth / Midas Deity)"]= Vector3.new(5213.0, 660.0, -4347.7),
    ["[Neutral] El'heith (Astra Starlight Enchant)"]  = Vector3.new(10883.0, 1573.4, -3489.5),
    ["[Neutral] The Soulmaster (Soul Awakening)"]     = Vector3.new(-44.9, 574.8, -5467.4),
    ["[Neutral] Spirit Domain: Staarun & Aderyn"]     = Vector3.new(789.3, 233.0, 2053.5),
}

local GeneralNPCs = {
    ["Blacksmith: Ferrum (Caldera Town)"]             = Vector3.new(4921.8, 657.9, -4162.3),
    ["Blacksmith: Borin (Westwood Canopy)"]           = Vector3.new(8465.8, 821.8, -5589.8),
    ["Blacksmith: Sanctuary Underground Forge"]      = Vector3.new(2079.6, 382.7, -2903.1),
    ["Merchant: Lyle (Caldera General Store)"]        = Vector3.new(5132.9, 658.0, -4124.2),
    ["Merchant: Corin (Westwood Provisions)"]         = Vector3.new(8473.8, 823.6, -5906.5),
    ["Doctor: Caldera Town Clinic"]                   = Vector3.new(5035.6, 658.1, -4407.9),
    ["Doctor: Westwood Forest Clinic"]                = Vector3.new(8079.1, 822.4, -5478.8),
    ["Doctor: Desert Oasis Camp Clinic"]              = Vector3.new(2790.2, 615.7, -3837.2),
    ["Banker: Caldera Town Vault"]                    = Vector3.new(5184.7, 657.7, -4266.2),
    ["Banker: Westwood Canopy Vault"]                 = Vector3.new(8470.3, 823.6, -5824.3),
    ["Apothecarian: Caldera Potions"]                = Vector3.new(5131.5, 657.8, -4355.9),
    ["Apothecarian: Westwood Potions"]               = Vector3.new(8388.3, 822.9, -5904.8),
    ["Enchanter: Caldera Arcane Forge"]              = Vector3.new(5045.7, 657.5, -4234.2),
}

local MajorBosses = {
    ["Boss: Yar'thul, the Blazing Dragon (Mount Thul Door)"] = Vector3.new(40.5, 581.6, -4113.5),
    ["Boss: Thorian, the Rotten (Remnants Gate)"]            = Vector3.new(8328.1, 645.0, -1544.1),
    ["Boss: Seraphon (Illustris Light Sanctum)"]             = Vector3.new(710.5, 3449.1, -5678.1),
    ["Boss: Arkhaia (Temple of Norn Gate)"]                  = Vector3.new(14710.9, 550.7, 7133.7),
    ["Boss: Handaconda (Desert Dungeon)"]                    = Vector3.new(3134.1, 179.1, -852.2),
    ["Boss: Metrom's Vessel (Dungeon Spawn)"]                = Vector3.new(-3369.4, 129.8, 4266.4),
}

local KeyLocations = {
    ["Caldera Town (Central Plaza)"]                = Vector3.new(5091.2, 662.6, -4293.1),
    ["Westwood Heart (Canopy Village)"]             = Vector3.new(8327.3, 825.1, -5557.4),
    ["Desert Oasis (Waving Sands Camp)"]            = Vector3.new(2815.3, 634.6, -3924.6),
    ["Sanctuary of Blades (Underground Ruins)"]     = Vector3.new(2086.0, 386.8, -2978.3),
    ["Church of Light (Heavens Point Peak)"]        = Vector3.new(831.6, 3436.9, -5602.3),
    ["Mount Thul Volcano (Dragon Peak)"]            = Vector3.new(98.9, 577.0, -4115.9),
    ["Forgotten Sanctum (Endgame Domain)"]          = Vector3.new(10831.2, 1581.7, -3463.6),
    ["Dark Place Gate (Abyss Gate)"]                = Vector3.new(7855.1, 1290.3, 7930.9),
    ["Void Rift (Interdimensional Portal)"]         = Vector3.new(991.0, 41.4, 615.6),
    ["Memori's House (Alchemist Witch Hut)"]        = Vector3.new(11851.5, 1064.9, -1776.8),
    ["Icerift Approach (Frostlands Path)"]          = Vector3.new(5328.2, 742.7, -6530.2),
}
local Teleporter = {
    active = false,
}

local function teleportToLocation(targetPos)
    if not targetPos or typeof(targetPos) ~= "Vector3" then
        Library:Notify(" Invalid destination coordinates!", 3)
        return
    end

    if Teleporter.active then
        Library:Notify("Teleport is already running! Click Cancel first.", 3)
        return
    end
    Teleporter.active = true

    task.spawn(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            Teleporter.active = false
            Library:Notify(" HumanoidRootPart not found!", 3)
            return
        end

        local safeTargetPos = getAccurateGroundPosition(targetPos)
        local height = Options.TeleportHeight and Options.TeleportHeight.Value or 1500
        local speed = Options.TeleportSpeed and Options.TeleportSpeed.Value or 200

        Library:Notify(string.format(" Starting Sky-Tween (Alt: %d, Spd: %d)...", height, speed), 3)

        local currentPos = root.Position
        local skyY = math.max(height, currentPos.Y + 200, safeTargetPos.Y + 200)

        local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), speed, function() return Teleporter.active end, true)
        if not s1 or not Teleporter.active then
            disableFlightState()
            Teleporter.active = false
            return
        end

        local s2 = smoothTweenTo(CFrame.new(safeTargetPos.X, skyY, safeTargetPos.Z), speed, function() return Teleporter.active end, true)
        if not s2 or not Teleporter.active then
            disableFlightState()
            Teleporter.active = false
            return
        end

        local s3 = smoothTweenTo(CFrame.new(safeTargetPos), speed, function() return Teleporter.active end, false)

        Teleporter.active = false
        if s3 then
            Library:Notify(" Arrived safely at destination!", 3)
        end
    end)
end

local function cancelTeleport()
    Teleporter.active = false
    if FlightController.currentTween then
        FlightController.currentTween:Cancel()
        FlightController.currentTween = nil
    end
    disableFlightState()
    Library:Notify("Teleport cancelled.", 3)
end

-- =============================================================================
-- INGREDIENT ESP ENGINE (OOP BILLBOARD ENGINE)
-- =============================================================================
local ESP_Colors = {
    ["Crylight"]              = Color3.fromRGB(0, 255, 255),
    ["Cryastem"]              = Color3.fromRGB(0, 180, 255),
    ["Hightail"]              = Color3.fromRGB(255, 140, 0),
    ["Everthistle"]           = Color3.fromRGB(180, 0, 255),
    ["7 Leafed Everthistle"]  = Color3.fromRGB(50, 255, 120),
    ["7-Leafed Everthistle"]  = Color3.fromRGB(50, 255, 120),
    ["7 Leaf Thistle"]        = Color3.fromRGB(50, 255, 120),
    ["Carnastool"]      = Color3.fromRGB(255, 60, 60),
    ["Driproot"]        = Color3.fromRGB(50, 205, 50),
    ["Cursed Shroom"]   = Color3.fromRGB(128, 0, 128),
    ["Cursed Shroom 2"] = Color3.fromRGB(148, 0, 211),
    ["Mushrooms"]       = Color3.fromRGB(220, 220, 220),
    ["Bones"]           = Color3.fromRGB(240, 240, 240),
    ["Branch Pile"]     = Color3.fromRGB(139, 69, 19),
    ["Ferrus"]          = Color3.fromRGB(192, 192, 192),
    ["Aestic"]          = Color3.fromRGB(255, 215, 0),
    ["Laneus"]          = Color3.fromRGB(144, 238, 144),
}


-- =============================================================================
-- COMPREHENSIVE VISUAL ESP SUITE (PLAYERS, NPCS, LOCATIONS & INGREDIENTS)
-- =============================================================================
local activePlayerESP = {}
local activeNpcESP = {}
local activeLocationESP = {}
local activeESP = {}

-- 1. PLAYER ESP SYSTEM
local function createPlayerESP(player)
    if player == LocalPlayer then return end
    if activePlayerESP[player] then return end

    local espObj = {
        Player = player,
        Billboard = nil,
        Label = nil,
        HealthBar = nil,
    }

    local function setupChar(char)
        if not char then return end
        local head = char:WaitForChild("Head", 5)
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if not head or not root then return end

        if espObj.Billboard then pcall(function() espObj.Billboard:Destroy() end) end

        local bb = Instance.new("BillboardGui")
        bb.Name = "PlayerESP_" .. player.Name
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 160, 0, 40)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.Adornee = head
        bb.Parent = PlayerGui

        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
        nameLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
        nameLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
        nameLabel.TextStrokeTransparency = 0.3
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 11
        nameLabel.Parent = bb

        local infoLabel = Instance.new("TextLabel")
        infoLabel.BackgroundTransparency = 1
        infoLabel.Size = UDim2.new(1, 0, 0.4, 0)
        infoLabel.Position = UDim2.new(0, 0, 0.6, 0)
        infoLabel.Text = "100% HP | 0m"
        infoLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
        infoLabel.TextStrokeTransparency = 0.4
        infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        infoLabel.Font = Enum.Font.GothamMedium
        infoLabel.TextSize = 9.5
        infoLabel.Parent = bb

        espObj.Billboard = bb
        espObj.Label = nameLabel
        espObj.InfoLabel = infoLabel
    end

    if player.Character then setupChar(player.Character) end
    player.CharacterAdded:Connect(setupChar)
    activePlayerESP[player] = espObj
end

local function removePlayerESP(player)
    local espObj = activePlayerESP[player]
    if espObj then
        if espObj.Billboard then pcall(function() espObj.Billboard:Destroy() end) end
        activePlayerESP[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do createPlayerESP(p) end
registerConnection(Players.PlayerAdded:Connect(createPlayerESP))
registerConnection(Players.PlayerRemoving:Connect(removePlayerESP))

-- 2. NPC & TRAINERS ESP SYSTEM
local function createNpcESP(model)
    if not model or not model:IsA("Model") then return end
    if activeNpcESP[model] then return end
    local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local name = model.Name
    local cleanName = name:gsub("%s*%(.*%)", ""):gsub("%d+$", ""):gsub("^%s*(.-)%s*$", "%1")
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "NpcESP_" .. name
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 160, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3.0, 0)
    bb.Adornee = head
    bb.Enabled = false
    bb.Parent = PlayerGui

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = "[NPC] " .. cleanName
    label.TextColor3 = Color3.fromRGB(255, 215, 0)
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.Parent = bb

    activeNpcESP[model] = { billboard = bb, label = label, name = cleanName, head = head }
end

local function removeNpcESP(model)
    if activeNpcESP[model] then
        pcall(function() activeNpcESP[model].billboard:Destroy() end)
        activeNpcESP[model] = nil
    end
end

-- 3. LOCATION & WAYPOINT ESP SYSTEM
local function initLocationESP()
    for locName, locPos in pairs(KeyLocations) do
        local bb = Instance.new("BillboardGui")
        bb.Name = "LocESP_" .. locName
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 180, 0, 32)
        bb.Enabled = false
        bb.Parent = PlayerGui

        local part = Instance.new("Part")
        part.Name = "LocAnchor_" .. locName
        part.Size = Vector3.new(1, 1, 1)
        part.Position = locPos
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Parent = workspace

        bb.Adornee = part

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Text = "[POI] " .. locName
        label.TextColor3 = Color3.fromRGB(160, 230, 255)
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.Parent = bb

        activeLocationESP[locName] = { billboard = bb, label = label, name = locName, pos = locPos, part = part }
    end
end
pcall(initLocationESP)

-- 4. INGREDIENT & ORE ESP
local function createESP(instance)
    if activeESP[instance] then return end
    local name = instance.Name
    local color = ESP_Colors[name] or Color3.fromRGB(255, 255, 255)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Arcane_ESP_" .. name
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 150, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Adornee = instance

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = name
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.Parent = billboard

    billboard.Parent = PlayerGui
    activeESP[instance] = { billboard = billboard, label = label, name = name, color = color }
end

local function removeESP(instance)
    if activeESP[instance] then
        pcall(function() activeESP[instance].billboard:Destroy() end)
        activeESP[instance] = nil
    end
end

-- 5. MASTER ESP UPDATE LOOP
registerConnection(RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local localRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    -- A. Player ESP Updates
    local pEspEnabled = Toggles.PlayerESP and Toggles.PlayerESP.Value
    local pMaxDist = Options.PlayerESPMaxDist and Options.PlayerESPMaxDist.Value or 3500
    local pColor = Options.PlayerESPColor and Options.PlayerESPColor.Value or Color3.fromRGB(6, 182, 212)

    for p, data in pairs(activePlayerESP) do
        if data.Billboard then
            local pChar = p.Character
            local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
            local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
            if pEspEnabled and pRoot and pHum and pHum.Health > 0 then
                local dist = (localRoot.Position - pRoot.Position).Magnitude
                if dist <= pMaxDist then
                    local hpPct = math.clamp(pHum.Health / math.max(1, pHum.MaxHealth), 0, 1)
                    local hpColor = hpPct > 0.5 and Color3.fromRGB(80, 255, 120) or (hpPct > 0.25 and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(255, 70, 70))
                    data.Label.TextColor3 = pColor
                    data.InfoLabel.Text = string.format("%d%% HP [%d/%d] • %dm", math.floor(hpPct * 100), math.floor(pHum.Health), math.floor(pHum.MaxHealth), math.floor(dist))
                    data.InfoLabel.TextColor3 = hpColor
                    data.Billboard.Enabled = true
                else
                    data.Billboard.Enabled = false
                end
            else
                data.Billboard.Enabled = false
            end
        end
    end

    -- B. NPC & Trainer ESP Updates
    local trainerEspEnabled = Toggles.Trainer_ESP and Toggles.Trainer_ESP.Value
    local npcEspEnabled = Toggles.NPC_ESP and Toggles.NPC_ESP.Value
    local npcMaxDist = Options.NPC_ESPMaxDist and Options.NPC_ESPMaxDist.Value or 2500
    local trainerMaxDist = Options.Trainer_ESPMaxDist and Options.Trainer_ESPMaxDist.Value or 3500
    local trainerColor = Options.TrainerESPColor and Options.TrainerESPColor.Value or Color3.fromRGB(168, 85, 247)
    local npcColor = Options.NPCESPColor and Options.NPCESPColor.Value or Color3.fromRGB(251, 191, 36)

    for m, data in pairs(activeNpcESP) do
        if data.billboard and data.head and data.head.Parent then
            local isTrainer = (IsClassTrainer and IsClassTrainer[data.name] ~= nil) or data.name:find("Trainer") ~= nil
            local shouldShow = false
            local curDistLimit = npcMaxDist
            local curColor = npcColor

            if isTrainer then
                if trainerEspEnabled then
                    shouldShow = true
                    curDistLimit = trainerMaxDist
                    curColor = trainerColor
                end
            else
                if npcEspEnabled then
                    shouldShow = true
                    curDistLimit = npcMaxDist
                    curColor = npcColor
                end
            end

            if shouldShow then
                local dist = (localRoot.Position - data.head.Position).Magnitude
                if dist <= curDistLimit then
                    data.label.Text = string.format("[%s] %s [%dm]", isTrainer and "TRAINER" or "NPC", data.name, math.floor(dist))
                    data.label.TextColor3 = curColor
                    data.billboard.Enabled = true
                else
                    data.billboard.Enabled = false
                end
            else
                data.billboard.Enabled = false
            end
        end
    end

    -- C. Location & Waypoint ESP Updates
    local locEspEnabled = Toggles.Location_ESP and Toggles.Location_ESP.Value
    local locMaxDist = Options.Location_ESPMaxDist and Options.Location_ESPMaxDist.Value or 6000
    local locColor = Options.LocationESPColor and Options.LocationESPColor.Value or Color3.fromRGB(34, 197, 94)

    for name, data in pairs(activeLocationESP) do
        if data.billboard then
            if locEspEnabled then
                local dist = (localRoot.Position - data.pos).Magnitude
                if dist <= locMaxDist then
                    data.label.Text = string.format("[POI] %s [%dm]", data.name, math.floor(dist))
                    data.label.TextColor3 = locColor
                    data.billboard.Enabled = true
                else
                    data.billboard.Enabled = false
                end
            else
                data.billboard.Enabled = false
            end
        end
    end

    -- D. Ingredient & Ore ESP Updates
    local espEnabled = Toggles.MasterESP and Toggles.MasterESP.Value
    local filterMode = Options.ESPFilterMode and Options.ESPFilterMode.Value or "All"
    local showDist = Toggles.ESPShowDistance and Toggles.ESPShowDistance.Value
    local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 10000
    local whitelist = (Options.ESPWhitelist and Options.ESPWhitelist.Value) or {}
    local cryColor = Options.CrylightESPColor and Options.CrylightESPColor.Value or Color3.fromRGB(56, 189, 248)
    local oreColor = Options.OreESPColor and Options.OreESPColor.Value or Color3.fromRGB(245, 158, 11)

    for inst, data in pairs(activeESP) do
        if not inst or not inst.Parent then
            removeESP(inst)
        else
            local isVisible = false
            if espEnabled then
                if not (data.name == "Crylight" and isBlacklistedCrylight(inst)) then
                    if filterMode == "All" then
                        isVisible = true
                    elseif filterMode == "CrylightOnly" and data.name == "Crylight" then
                        isVisible = true
                    elseif filterMode == "Whitelist" and whitelist[data.name] then
                        isVisible = true
                    end
                end
            end

            if isVisible then
                local pos = inst:GetPivot().Position
                local dist = (localRoot.Position - pos).Magnitude
                if dist <= maxDist then
                    local text = data.name
                    if showDist then text = string.format("%s [%dm]", data.name, math.floor(dist)) end
                    data.label.Text = text
                    if data.name == "Crylight" then
                        data.label.TextColor3 = cryColor
                    elseif data.name == "Ferrus" or data.name == "Aestic" or data.name == "Laneus" then
                        data.label.TextColor3 = oreColor
                    else
                        data.label.TextColor3 = data.color
                    end
                    data.billboard.Enabled = true
                else
                    data.billboard.Enabled = false
                end
            else
                data.billboard.Enabled = false
            end
        end
    end
end))

registerConnection(workspace.DescendantAdded:Connect(function(desc)
    if ESP_Colors[desc.Name] then createESP(desc) end
    if desc:IsA("Model") and (desc.Parent and (desc.Parent.Name == "NPCs" or desc.Parent.Name == "Living")) then
        createNpcESP(desc)
    end
end))
registerConnection(workspace.DescendantRemoving:Connect(function(desc)
    removeESP(desc)
    removeNpcESP(desc)
end))

for _, desc in ipairs(workspace:GetDescendants()) do
    if ESP_Colors[desc.Name] then createESP(desc) end
    if desc:IsA("Model") and (desc.Parent and (desc.Parent.Name == "NPCs" or desc.Parent.Name == "Living")) then
        createNpcESP(desc)
    end
end
local Window = ZeroLib:CreateWindow({
    Title = "ARCANE LINEAGE",
    Size = UDim2.new(0, 680, 0, 480),
    ToggleKey = Enum.KeyCode.End
})

ZeroLib:SetWatermark("Arcane Lineage")

local Tabs = {
    AutoFarm = Window:AddTab({ Name = "Farm", Icon = ZeroLib.Icons.Farm }),
    AutoQTE  = Window:AddTab({ Name = "Combat", Icon = ZeroLib.Icons.Combat }),
    Movement = Window:AddTab({ Name = "Movement", Icon = ZeroLib.Icons.Movement }),
    Teleport = Window:AddTab({ Name = "Teleport", Icon = ZeroLib.Icons.Teleport }),
    Visuals  = Window:AddTab({ Name = "Visuals", Icon = ZeroLib.Icons.Visuals }),
    Webhook  = Window:AddTab({ Name = "Webhook", Icon = ZeroLib.Icons.Terminal }),
    Settings = Window:AddTab({ Name = "Settings", Icon = ZeroLib.Icons.Settings }),
}
Tabs.Combat = Tabs.AutoQTE
Tabs.Teleports = Tabs.Teleport

-- -----------------------------------------------------------------------------
-- TAB 1: AUTO FARM (INGREDIENTS & ORE MINING)
-- -----------------------------------------------------------------------------
local FarmGroup  = Tabs.AutoFarm:AddLeftGroupbox("Ingredient Auto Hunter")
local MineGroup  = Tabs.AutoFarm:AddLeftGroupbox("Auto Mine Ores")
local LevelGroup = Tabs.AutoFarm:AddRightGroupbox("Auto Farm Level & Mobs")
local StatsGroup = Tabs.AutoFarm:AddRightGroupbox("Auto Stats Build & Cache")

-- -----------------------------------------------------------------------------
-- SUB-GROUP: AUTO BOSS YAR'THUL (THE BLAZING DRAGON)
-- -----------------------------------------------------------------------------
local YarthulGroup = Tabs.AutoFarm:AddRightGroupbox("🐲 Auto Boss: Yar'thul (Blazing Dragon)")

YarthulGroup:AddToggle("AutoFarmYarthul", {
    Text = "Enable Auto Farm & Retry Yar'thul",
    Default = false,
    Tooltip = "Tự động kiểm tra vị trí Spawn trong Instance -> Tween tới cửa Boss để Begin Fight -> Tự động đánh theo chiến thuật chuẩn (Ưu tiên 1: Sense Expansion xen kẽ dứt khoát không Meditate -> Ưu tiên 2: Carnage khi E>=3 & Carnage đã hồi CD & KHÔNG có Flame Pillar dứt khoát không Meditate -> Ưu tiên 3: Strike kèm Meditate Sub-Action để nạp Energy) -> Tự động nhặt đồ, Hook SetCore Callback tự động Accept vào Roll Pool (0ms) & tự động quét toàn bộ Drop mới vào túi đồ -> Tự động Retry lặp lại vô tận",
    Callback = function(Value)
        if Value then
            if Toggles.AutoFight and not Toggles.AutoFight.Value then
                Toggles.AutoFight:SetValue(true)
            end
            if Options.SelectedCombatAction then
                Options.SelectedCombatAction:SetValue("Auto Smart (Best Skill -> Strike)")
            end
            AutoYarthul.start()
        else
            if not AutoYarthul.isRestoring then
                AutoYarthul.stop(true)
            end
        end
    end
})

YarthulGroup:AddLabel("📜 Strat: Sense (Alternating) > Carnage > Strike + Med")

YarthulGroup:AddToggle("YarthulMeditateSubAction", {
    Text = "Use Meditate Sub-Action on Strike",
    Default = true,
    Tooltip = "Tự động kích hoạt Sub-Action Meditate kèm ngay sau đòn Strike để nạp nhanh Energy (Carnage và Sense Expansion được tung đòn dứt khoát không kèm Meditate để tránh kết thúc turn sớm hoặc trúng Flame Pillar)",
})

YarthulGroup:AddToggle("YarthulAutoLoot", {
    Text = "Auto Loot & Roll Pool (Direct Hook)",
    Default = true,
    Tooltip = "Tự động Hook SetCore Notification Callback để Accept tức thì vào Roll Pool khi rơi Artifact, hoàn toàn không chiếm chuột của người chơi",
})

YarthulGroup:AddSlider("YarthulTweenSpeed", {
    Text = "Flight Speed to Gate",
    Default = 220,
    Min = 120,
    Max = 350,
    Rounding = 0,
    Tooltip = "Tốc độ bay Sky-Tween tới cửa Mount Thul (mặc định 220 studs/s)",
})

YarthulGroup:AddToggle("YarthulSendWebhook", {
    Text = "Enable Discord Webhook",
    Default = true,
    Tooltip = "Gửi thông báo thống kê chi tiết vật phẩm rơi (Drops & Artifacts) sau khi diệt Boss Yar'thul",
})

YarthulGroup:AddInput("YarthulWebhook", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Custom Yar'thul Webhook URL",
    Tooltip = "Nhập Discord Webhook URL riêng cho Boss Yar'thul (để trống nếu dùng chung Webhook tổng)",
    Placeholder = "https://discord.com/api/webhooks/...",
})

YarthulGroup:AddButton({
    Text = "🔔 Test Yar'thul Webhook Now",
    Func = function()
        AutoYarthul.sendWebhook("Test")
    end
})

YarthulGroup:AddButton({
    Text = "🚀 Tween to Mount Thul Door Now",
    Func = function()
        teleportToLocation(AutoYarthul.gatePosition)
    end
})

YarthulGroup:AddButton({
    Text = "⏹️ Stop Auto Farm Yar'thul",
    Func = function()
        AutoYarthul.stop(true)
        if Toggles.AutoFarmYarthul then
            Toggles.AutoFarmYarthul:SetValue(false)
        end
    end
})

local HopGroup   = Tabs.AutoFarm:AddLeftGroupbox("Server Hop & Navigation")

FarmGroup:AddToggle("AutoFarmCrylight", {
    Text = "Enable Ingredient Auto Farm",
    Default = false,
    Tooltip = "auto quet Menu -> Vao game -> fly Sky-Tween -> Thu hoach nguyen lieu -> Doi Server",
    Callback = function(Value)
        if Value then Farmer.runCycle() else Farmer.stop() end
    end
})

FarmGroup:AddDropdown("FarmItemsWhitelist", {
    Values = {
        "Crylight", "Cryastem", "Hightail", "Everthistle",
        "7 Leafed Everthistle", "Carnastool", "Driproot", "Cursed Shroom", "Cursed Shroom 2",
        "Mushrooms", "Bones", "Branch Pile"
    },
    Default = {},
    Multi = true,
    Text = "Ingredient Target Whitelist",
})

FarmGroup:AddToggle("AutoStart", {
    Text = "Auto Start / Skip Intro",
    Default = false,
})

FarmGroup:AddToggle("AutoSkipIntro", {
    Text = "Auto Skip Cutscenes",
    Default = false,
})

FarmGroup:AddToggle("BlacklistDesert", {
    Text = "Ignore Desert Fake Crylights (Vastic Grave & Sanctum)",
    Default = false,
    Tooltip = "Types bo hoan toan toan bo Crylight gia trong area Sa mac (Vastic Grave) & Forgotten Sanctum",
})

FarmGroup:AddSlider("SkyHeight", {
    Text = "Sky Flight Altitude (Y)",
    Default = 1500,
    Min = 500,
    Max = 3000,
    Rounding = 0,
})

FarmGroup:AddSlider("AscendSpeed", {
    Text = "Ascend Speed (Studs/s)",
    Default = 150,
    Min = 50,
    Max = 300,
    Rounding = 0,
})

FarmGroup:AddSlider("CruiseSpeed", {
    Text = "Cruise Speed (Studs/s)",
    Default = 180,
    Min = 50,
    Max = 350,
    Rounding = 0,
})

FarmGroup:AddSlider("DescendSpeed", {
    Text = "Descend Speed (Studs/s)",
    Default = 150,
    Min = 50,
    Max = 300,
    Rounding = 0,
})

FarmGroup:AddSlider("PickupTimeout", {
    Text = "Pickup Timeout (Seconds)",
    Default = 5,
    Min = 2,
    Max = 10,
    Rounding = 1,
})

MineGroup:AddToggle("AutoMineOre", {
    Text = "Enable Auto Mine Ores",
    Default = false,
    Tooltip = "auto test Pickaxe -> buy neu missing -> fly toi mo -> Tu dao khoang",
    Callback = function(Value)
        if Value then Miner.runCycle() else Miner.stop() end
    end
})

MineGroup:AddDropdown("MineOresWhitelist", {
    Values = { "Ferrus", "Aestic", "Laneus" },
    Default = {},
    Multi = true,
    Text = "Target Ores to Mine",
})

MineGroup:AddToggle("AutoBuyPickaxe", {
    Text = "Auto Buy Pickaxe if Missing (50g)",
    Default = false,
    Tooltip = "Neu trong tui/balo not yet co pickaxe, se auto fly toi Caldera de buy pickaxe (50 Gold)",
})

MineGroup:AddSlider("MineTimeout", {
    Text = "Mine Node Timeout (s)",
    Default = 12,
    Min = 3,
    Max = 30,
    Rounding = 0,
})

MineGroup:AddSlider("MineSwingDelay", {
    Text = "Mining Swing Delay (s)",
    Default = 0.18,
    Min = 0.08,
    Max = 0.5,
    Rounding = 2,
    Tooltip = "time nghi giua moi lan vung pickaxe dap ore node (mac dinh 0.18s sieu nhanh)",
})

MineGroup:AddButton({
    Text = "Mine Ores Now",
    Func = function() Miner.runCycle() end,
})

LevelGroup:AddToggle("AutoFarmLevel", {
    Text = "Enable Auto Farm Level",
    Default = false,
    Tooltip = "auto tween toi bai farm (under ground voi Lv 1-20) va auto combat / giai QTE khi vao tran",
    Callback = function(Value)
        if Value then LevelFarmer.runCycle() else LevelFarmer.stop() end
    end
})

LevelGroup:AddDropdown("FarmLevelMode", {
    Values = {
        "Auto (Detect Level 1 - 50)",
        "Level 1 - 30 (Underground)",
        "Level 30 - 50 (Desert Block)",
        "The Crossing (Caldera / Starter Mobs)",
        "Deeproot Canopy (Westwood / Forest Mobs)",
        "Waving Sands (Desert / Sand Mobs)",
        "Withered Grove (Cursed Grove / Undead Mobs)",
        "Mount Thul (Snow Mountain / Frost Mobs)",
    },
    Default = 1,
    Multi = false,
    Text = "Mode",
    Tooltip = "select mode hoac area mobs de farm safely under ground (player khac not the nhin thay):\n• Auto (Detect Level 1 - 50): auto detected level (Lv < 30 fly ve bai underground Caldera, Lv >= 30 fly ve khoi safely Desert)\n• Level 1 - 30 (Underground): Bai underground safely Caldera\n• Level 30 - 50 (Desert Block): Bai safely trong khoi Desert\n• The Crossing: mobs tan thu nearby Caldera (Slime, Bandits, Goblins)\n• Deeproot Canopy: mobs rung Westwood (Plants, Wolves, Spiders)\n• Waving Sands: mobs sa mac (Desert Scorpions, Mummies, Bandits)\n• Withered Grove: mobs hac am / Cursed Undead\n• Mount Thul: mobs bang tuyet / Yeti / Golem",
})

LevelGroup:AddToggle("AutoMeditate", {
    Text = "Auto Meditate & Level Up (Auto Cap Detect)",
    Default = false,
    Tooltip = "auto detected khi Essence stop increase (dat Cap level) -> auto di thien mo phong key M meet Aretim de level up roi tro ve",
})

LevelGroup:AddToggle("DeeprootNightFailsafe", {
    Text = "Deeproot Night Safe Hover (Avoid Sentinel)",
    Default = false,
    Tooltip = "Khi farm tai Deeproot Forest / Westwood: Neu troi toi (17:30 - 06:30), auto fly len tang may (Y: 1200) dung doi troi sang de tranh meet sieu mobs Sentinel of Darkness.",
})

StatsGroup:AddToggle("AutoAllocateStats", {
    Text = "Enable Auto Stats Build",
    Default = false,
    Tooltip = "auto upgraded points StatPoints theo moc Target Stats va luu cache theo name nhan vat (+10 moi cycle)",
})

StatsGroup:AddSlider("TargetStrength", {
    Text = "Target Strength",
    Default = 20,
    Min = 0,
    Max = 200,
    Rounding = 0,
})

StatsGroup:AddSlider("TargetEndurance", {
    Text = "Target Endurance",
    Default = 20,
    Min = 0,
    Max = 200,
    Rounding = 0,
})

StatsGroup:AddSlider("TargetSpeed", {
    Text = "Target Speed",
    Default = 10,
    Min = 0,
    Max = 200,
    Rounding = 0,
})

StatsGroup:AddSlider("TargetArcane", {
    Text = "Target Arcane",
    Default = 0,
    Min = 0,
    Max = 200,
    Rounding = 0,
})

StatsGroup:AddSlider("TargetLuck", {
    Text = "Target Luck",
    Default = 10,
    Min = 0,
    Max = 200,
    Rounding = 0,
})

StatsGroup:AddButton({
    Text = "Clear Stats Build Data (Reset User Cache)",
    Func = function()
        clearUserStatsCache()
    end
})

StatsGroup:AddButton({
    Text = "View User Stats Cache",
    Func = function()
        local userStats, _, username = getUserStatsCache()
        local msg = string.format("Cache [%s]: Str:%d | End:%d | Spd:%d | Arc:%d | Lck:%d", username, userStats.Strength, userStats.Endurance, userStats.Speed, userStats.Arcane, userStats.Luck)
        Library:Notify(msg, 5)
        hubLog("[AutoStats] " .. msg)
    end
})



-- Fully automated Level Farming (No manual buttons needed)

HopGroup:AddToggle("AutoServerHop", {
    Text = "Auto Server Hop (Farm Items)",
    Default = false,
    Tooltip = "auto doi server khi lum xong hoac khi server not co nguyen lieu",
})

HopGroup:AddDivider()

HopGroup:AddToggle("HuntCorruptServer", {
    Text = "Auto Hop Hunt Corrupt Server",
    Default = false,
    Tooltip = "auto doi server lien tuc cho den khi tim thay Corrupted Server (Event Server)!",
})

Toggles.HuntCorruptServer:OnChanged(function()
    if Toggles.HuntCorruptServer.Value then
        CorruptHunter.start()
    else
        CorruptHunter.stop()
    end
end)

HopGroup:AddToggle("StayInCorruptServer", {
    Text = "Stay In Corrupt Server When Found",
    Default = false,
    Tooltip = "auto stop hop khi has tim thay Corrupt Server",
})


HopGroup:AddButton({
    Text = "Check Current Server Event",
    Func = function()
        local isCorrupt, evName = checkIsCorruptServer()
        if isCorrupt then
            Library:Notify(string.format(" is LA CORRUPT SERVER: %s!", evName), 6)
            sendCorruptServerWebhook(evName)
        else
            Library:Notify(" Server hien tai potion thuong (not co Event Corrupt).", 4)
        end
    end,
    DoubleClick = false,
})

HopGroup:AddDivider()

HopGroup:AddSlider("MaxPlayerBuffer", {
    Text = "Free Slots Required",
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 0,
})

HopGroup:AddSlider("TeleportTimeout", {
    Text = "Teleport Watchdog (Seconds)",
    Default = 8,
    Min = 5,
    Max = 15,
    Rounding = 0,
})



HopGroup:AddButton({
    Text = "Hop Server Now",
    Func = function() ServerHopper.hop() end,
    DoubleClick = false,
})

-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- TAB 2: AUTO COMBAT & AUTO FIGHT
-- -----------------------------------------------------------------------------
do
local CombatGroup = Tabs.Combat:AddLeftGroupbox("⚡ Auto Combat & Minigames QTE")
local FightGroup  = Tabs.Combat:AddRightGroupbox("⚔️ Auto Fight & Skill Priority")

CombatGroup:AddToggle("MasterQTE", {
    Text = "Enable Auto Combat QTE",
    Default = true,
    Tooltip = "Tự động giải và hoàn thành toàn bộ QTE khi chiến đấu / mở rương",
})

CombatGroup:AddDropdown("EnabledQTEList", {
    Values = {
        "Auto Dodge / Block",
        "Sword (Window Strike)",
        "Dagger (Weakpoints)",
        "Hammer (Power Bar)",
        "Axe (Equilibrium)",
        "Staff / Magic (Rune Matching)",
        "Fist / Cestus (Combos)",
        "Spear (Taps, Lines & Curves)",
        "Chest Lockpick"
    },
    Default = {
        "Auto Dodge / Block",
        "Sword (Window Strike)",
        "Dagger (Weakpoints)",
        "Hammer (Power Bar)",
        "Axe (Equilibrium)",
        "Staff / Magic (Rune Matching)",
        "Fist / Cestus (Combos)",
        "Spear (Taps, Lines & Curves)",
        "Chest Lockpick"
    },
    Multi = true,
    Text = "Active QTE Minigames",
})

CombatGroup:AddToggle("PreferPerfectDodge", {
    Text = "Prefer Perfect Dodge (100% Invuln)",
    Default = true,
    Tooltip = "Ưu tiên canh chuẩn ô Dodge (Né hoàn hảo 100% không mất máu), dự phòng Block",
})

CombatGroup:AddSlider("ReactionDelayMs", {
    Text = "Reaction Delay (ms)",
    Default = 0,
    Min = 0,
    Max = 150,
    Rounding = 0,
    Tooltip = "Độ trễ mô phỏng phản xạ người chơi (0 = chuẩn xác tức thì)",
})

FightGroup:AddToggle("AutoFight", {
    Text = "Enable Auto Fight (Auto Attack)",
    Default = false,
    Tooltip = "Tự động tung chiêu / đánh thường / thiền khi đến lượt trong trận đấu. Hoạt động độc lập (không cần bật Auto Farm Level).",
    Callback = function(Value)
        if Value then AutoFight.start() else AutoFight.stop() end
    end
})

FightGroup:AddDropdown("SelectedCombatAction", {
    Values = {
        "Strike (Basic Attack)",
        "Auto Smart (Best Skill -> Strike)",
        "Custom Skill"
    },
    Default = 1,
    Multi = false,
    Text = "Combat Attack / Skill Action",
    Tooltip = "Lựa chọn chế độ tung chiêu khi đến lượt:\n• Strike: Đánh thường\n• Auto Smart: Tự chọn chiêu mạnh nhất\n• Custom Skill: Ưu tiên theo 4 slot bên dưới",
})

local customSkillUIElements = {}
local function recordCustomSkillElement(fn)
    local before = #FightGroup.Container:GetChildren()
    local res = fn()
    local children = FightGroup.Container:GetChildren()
    for i = before + 1, #children do
        table.insert(customSkillUIElements, children[i])
    end
    return res
end

recordCustomSkillElement(function()
    return FightGroup:AddButton({
        Text = "🔄 Scan / Refresh My Skills",
        Tooltip = "Quét lại danh sách chiêu thức đang trang bị từ giao diện UI của bạn",
        Func = function()
            local skills = scanPlayerSkills()
            table.insert(skills, 1, "None")
            if Options.CustomSkillSlot1 then Options.CustomSkillSlot1:SetValues(skills) end
            if Options.CustomSkillSlot2 then Options.CustomSkillSlot2:SetValues(skills) end
            if Options.CustomSkillSlot3 then Options.CustomSkillSlot3:SetValues(skills) end
            if Options.CustomSkillSlot4 then Options.CustomSkillSlot4:SetValues(skills) end
            Library:Notify(string.format("✅ Đã quét thấy %d chiêu thức!", #skills - 1), 3)
        end
    })
end)

local initialSkills = scanPlayerSkills()
table.insert(initialSkills, 1, "None")

recordCustomSkillElement(function()
    return FightGroup:AddDropdown("CustomSkillSlot1", {
        Values = initialSkills,
        Default = #initialSkills > 1 and 2 or 1,
        Multi = false,
        Text = "Priority 1 (Ưu tiên cao nhất)",
        Tooltip = "Chiêu thức được ưu tiên tung ra đầu tiên khi sẵn sàng",
    })
end)

recordCustomSkillElement(function()
    return FightGroup:AddDropdown("CustomSkillSlot2", {
        Values = initialSkills,
        Default = 1,
        Multi = false,
        Text = "Priority 2",
        Tooltip = "Chiêu thức được sử dụng nếu Priority 1 đang hồi chiêu (CD)",
    })
end)

recordCustomSkillElement(function()
    return FightGroup:AddDropdown("CustomSkillSlot3", {
        Values = initialSkills,
        Default = 1,
        Multi = false,
        Text = "Priority 3",
        Tooltip = "Chiêu thức được sử dụng nếu Priority 1 & 2 đang hồi chiêu",
    })
end)

recordCustomSkillElement(function()
    return FightGroup:AddDropdown("CustomSkillSlot4", {
        Values = initialSkills,
        Default = 1,
        Multi = false,
        Text = "Priority 4",
        Tooltip = "Chiêu thức dự phòng cuối cùng",
    })
end)

recordCustomSkillElement(function()
    return FightGroup:AddToggle("AutoMeditateInCombat", {
        Text = "🧘 Auto Meditate if Cannot Use Skill",
        Default = false,
        Tooltip = "BẬT: Nếu toàn bộ skill ưu tiên đang hồi chiêu hoặc thiếu Energy/Stamina -> Tự động chọn Meditate để hồi thể lực / mana. TẮT: Tự động fallback về đánh thường (Strike).",
    })
end)

local function updateCustomSkillVisibility()
    local val = Options.SelectedCombatAction and Options.SelectedCombatAction.Value
    local isCustom = (val == "Custom Skill")
    for _, inst in ipairs(customSkillUIElements) do
        if inst and inst:IsA("GuiObject") then
            inst.Visible = isCustom
        end
    end
    FightGroup:Resize()
end

Options.SelectedCombatAction:OnChanged(updateCustomSkillVisibility)
updateCustomSkillVisibility()

FightGroup:AddDropdown("TargetPriority", {
    Values = {
        "First Enemy",
        "Last Enemy",
        "Random Enemy"
    },
    Default = 1,
    Multi = false,
    Text = "Enemy Target Priority",
})

FightGroup:AddDropdown("CombatExecutionMode", {
    Values = {
        "Direct Remote (Fastest + Sub-actions)",
        "UI Emulation (Classic)"
    },
    Default = 1,
    Multi = false,
    Text = "Combat Execution Method",
    Tooltip = "• Direct Remote: Bỏ qua giao diện UI, gửi trực tiếp Remote packet tới Server trong 0ms và hỗ trợ Sub-actions.\n• UI Emulation: Giả lập thao tác click chuột trên giao diện như người chơi thật.",
})

FightGroup:AddDropdown("CombatSubAction", {
    Values = {
        "None",
        "Auto Meditate (Recover Energy)",
        "Auto Guard (Defend)"
    },
    Default = 2,
    Multi = false,
    Text = "⚡ Sub-Action (Same-Turn Action)",
    Tooltip = "Gửi thêm hành động phụ (Hồi Energy hoặc Bật thủ) ngay trong cùng 1 lượt đánh chính!",
})

FightGroup:AddSlider("CombatDelay", {
    Text = "Turn Action Delay (s)",
    Default = 0.05,
    Min = 0.0,
    Max = 2.0,
    Rounding = 2,
    Tooltip = "Độ trễ phản xạ trước khi ra chiêu (0.0s = tức thì 0ms, 0.05s = mượt mà)",
})

-- -----------------------------------------------------------------------------

-- TAB 3: MOVEMENT CONTROLLER (WITH FULL KEYBIND PICKERS)
-- -----------------------------------------------------------------------------
end

local FlyGroup = Tabs.Movement:AddLeftGroupbox("Flight & NoClip")
local SpeedGroup = Tabs.Movement:AddRightGroupbox("Speed & Jump")

FlyGroup:AddToggle("Fly", {
    Text = "Enable Fly Hack",
    Default = false,
    Tooltip = "fly tu do theo huong Camera (W/A/S/D + Space / Shift)",
}):AddKeyPicker("FlyKeybind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Fly Keybind",
    NoUI = false,
})

FlyGroup:AddSlider("FlySpeed", {
    Text = "Flight Horizontal Speed",
    Default = 120,
    Min = 20,
    Max = 350,
    Rounding = 0,
})

FlyGroup:AddSlider("FlyUpSpeed", {
    Text = "Flight Vertical Speed",
    Default = 80,
    Min = 10,
    Max = 250,
    Rounding = 0,
})

FlyGroup:AddToggle("NoClip", {
    Text = "Enable NoClip (Walk Through Walls)",
    Default = false,
}):AddKeyPicker("NoClipKeybind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "NoClip Keybind",
    NoUI = false,
})

SpeedGroup:AddToggle("Speedhack", {
    Text = "Speedhack (Linear Velocity)",
    Default = false,
}):AddKeyPicker("SpeedhackKeybind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Speedhack Keybind",
    NoUI = false,
})

SpeedGroup:AddSlider("SpeedhackSpeed", {
    Text = "Speedhack Speed",
    Default = 50,
    Min = 16,
    Max = 250,
    Rounding = 0,
})

SpeedGroup:AddToggle("CFrameSpeed", {
    Text = "CFrame Speed (Direct Bypass)",
    Default = false,
}):AddKeyPicker("CFrameSpeedKeybind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "CFrame Speed Keybind",
    NoUI = false,
})

SpeedGroup:AddSlider("CFrameSpeedMult", {
    Text = "CFrame Speed Multiplier",
    Default = 30,
    Min = 5,
    Max = 150,
    Rounding = 0,
})

SpeedGroup:AddToggle("InfiniteJump", {
    Text = "Infinite Jump (Hold Space)",
    Default = false,
}):AddKeyPicker("InfJumpKeybind", {
    Default = "None",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Infinite Jump Keybind",
    NoUI = false,
})

SpeedGroup:AddSlider("InfiniteJumpBoost", {
    Text = "Jump Boost Force",
    Default = 50,
    Min = 30,
    Max = 150,
    Rounding = 0,
})

-- -----------------------------------------------------------------------------
-- TAB: TELEPORTATION SUITE (ORGANIZED TRAINERS, QUESTS, NPCS & LANDMARKS)
-- -----------------------------------------------------------------------------
local TrainerGroup = Tabs.Teleport:AddLeftGroupbox("Class Trainers (Base & Super & Sub)")
local QuestGroup   = Tabs.Teleport:AddLeftGroupbox("Quest NPCs & Alignments")
local NpcGroup     = Tabs.Teleport:AddRightGroupbox("Town Services & General NPCs")
local LandmarkGroup= Tabs.Teleport:AddRightGroupbox("Towns, Landmarks & Boss Arenas")

-- 1. Class Trainers Group
local baseNames = {}
for name in pairs(BaseTrainers) do table.insert(baseNames, name) end
table.sort(baseNames)

TrainerGroup:AddDropdown("SelectedBaseTrainer", {
    Values = baseNames,
    Default = 1,
    Multi = false,
    Text = "Base Class Trainers (7)",
})

TrainerGroup:AddButton({
    Text = "Warp to Selected Base Trainer",
    Func = function()
        local name = Options.SelectedBaseTrainer and Options.SelectedBaseTrainer.Value
        local pos = name and BaseTrainers[name]
        if pos then teleportToLocation(pos) end
    end
})

TrainerGroup:AddDivider()

local superNames = {}
for name in pairs(SuperTrainers) do table.insert(superNames, name) end
table.sort(superNames)

TrainerGroup:AddDropdown("SelectedSuperTrainer", {
    Values = superNames,
    Default = 1,
    Multi = false,
    Text = "Super Class Trainers (20+)",
})

TrainerGroup:AddButton({
    Text = "Warp to Selected Super Trainer",
    Func = function()
        local name = Options.SelectedSuperTrainer and Options.SelectedSuperTrainer.Value
        local pos = name and SuperTrainers[name]
        if pos then teleportToLocation(pos) end
    end
})

TrainerGroup:AddDivider()

local subNames = {}
for name in pairs(SubclassTrainers) do table.insert(subNames, name) end
table.sort(subNames)

TrainerGroup:AddDropdown("SelectedSubTrainer", {
    Values = subNames,
    Default = 1,
    Multi = false,
    Text = "Subclass Trainers (5)",
})

TrainerGroup:AddButton({
    Text = "Warp to Selected Sub Trainer",
    Func = function()
        local name = Options.SelectedSubTrainer and Options.SelectedSubTrainer.Value
        local pos = name and SubclassTrainers[name]
        if pos then teleportToLocation(pos) end
    end
})

-- 2. Quest NPCs & Alignments Group
local questNames = {}
for name in pairs(QuestNPCs) do table.insert(questNames, name) end
table.sort(questNames)

QuestGroup:AddDropdown("SelectedQuestNPC", {
    Values = questNames,
    Default = 1,
    Multi = false,
    Text = "Quest NPCs (Orderly / Chaotic)",
})

QuestGroup:AddButton({
    Text = "Warp to Quest NPC",
    Func = function()
        local name = Options.SelectedQuestNPC and Options.SelectedQuestNPC.Value
        local pos = name and QuestNPCs[name]
        if pos then teleportToLocation(pos) end
    end
})

-- 3. Town Services & General NPCs Group
local npcNames = {}
for name in pairs(GeneralNPCs) do table.insert(npcNames, name) end
table.sort(npcNames)

NpcGroup:AddDropdown("SelectedGeneralNPC", {
    Values = npcNames,
    Default = 1,
    Multi = false,
    Text = "Merchants, Clinics & Services",
})

NpcGroup:AddButton({
    Text = "Warp to NPC / Service",
    Func = function()
        local name = Options.SelectedGeneralNPC and Options.SelectedGeneralNPC.Value
        local pos = name and GeneralNPCs[name]
        if pos then teleportToLocation(pos) end
    end
})

-- 4. Towns, Landmarks & Boss Arenas Group
local landmarkNames = {}
for name in pairs(KeyLocations) do table.insert(landmarkNames, name) end
table.sort(landmarkNames)

LandmarkGroup:AddDropdown("SelectedTownLoc", {
    Values = landmarkNames,
    Default = 1,
    Multi = false,
    Text = "Major Towns & Landmarks",
})

LandmarkGroup:AddButton({
    Text = "Warp to Town / Landmark",
    Func = function()
        local name = Options.SelectedTownLoc and Options.SelectedTownLoc.Value
        local pos = name and KeyLocations[name]
        if pos then teleportToLocation(pos) end
    end
})

LandmarkGroup:AddDivider()

local bossNames = {}
for name in pairs(MajorBosses) do table.insert(bossNames, name) end
table.sort(bossNames)

LandmarkGroup:AddDropdown("SelectedMajorBoss", {
    Values = bossNames,
    Default = 1,
    Multi = false,
    Text = "Major Boss Arenas (6)",
})

LandmarkGroup:AddButton({
    Text = "Warp to Boss Arena Gate",
    Func = function()
        local name = Options.SelectedMajorBoss and Options.SelectedMajorBoss.Value
        local pos = name and MajorBosses[name]
        if pos then teleportToLocation(pos) end
    end
})

LandmarkGroup:AddDivider()

LandmarkGroup:AddButton({
    Text = "Cancel Current Teleport",
    Func = function()
        Teleporter.cancel()
    end
})
do
do
local PlayerESPGroup   = Tabs.Visuals:AddLeftGroupbox("Player ESP & Trackers")
local TrainerESPGroup  = Tabs.Visuals:AddLeftGroupbox("Class Trainer ESP")
local NpcESPGroup      = Tabs.Visuals:AddLeftGroupbox("General NPC & Service ESP")
local WaypointESPGroup = Tabs.Visuals:AddLeftGroupbox("Waypoint & POI ESP")
local ESPGroup         = Tabs.Visuals:AddLeftGroupbox("Ingredient & Ore ESP")
local FilterGroup      = Tabs.Visuals:AddLeftGroupbox("Filters & Categories")

-- 1. Player ESP
local pToggle = PlayerESPGroup:AddToggle("PlayerESP", {
    Text = "Enable Player ESP",
    Default = false,
    Tooltip = "Display player names, health bars, and distance to players",
})
pToggle:AddColorPicker("PlayerESPColor", {
    Default = Color3.fromRGB(6, 182, 212),
    Title = "Player Color",
})

PlayerESPGroup:AddSlider("PlayerESPMaxDist", {
    Text = "Max Player ESP Distance",
    Default = 3500,
    Min = 500,
    Max = 10000,
    Rounding = 0,
    Tooltip = "Maximum scan distance to display players",
})

-- 2. Class Trainer ESP
local tToggle = TrainerESPGroup:AddToggle("Trainer_ESP", {
    Text = "Enable Class Trainer ESP",
    Default = false,
    Tooltip = "Display all Base, Super, and Subclass trainers on the map",
})
tToggle:AddColorPicker("TrainerESPColor", {
    Default = Color3.fromRGB(168, 85, 247),
    Title = "Trainer Color",
})

TrainerESPGroup:AddSlider("Trainer_ESPMaxDist", {
    Text = "Max Trainer ESP Distance",
    Default = 4000,
    Min = 500,
    Max = 12000,
    Rounding = 0,
})

-- 3. General NPC & Services ESP
local nToggle = NpcESPGroup:AddToggle("NPC_ESP", {
    Text = "Enable General NPC ESP",
    Default = false,
    Tooltip = "Display all Quest NPCs, Blacksmiths, Doctors, Bankers, and Merchants",
})
nToggle:AddColorPicker("NPCESPColor", {
    Default = Color3.fromRGB(251, 191, 36),
    Title = "General NPC Color",
})

NpcESPGroup:AddSlider("NPC_ESPMaxDist", {
    Text = "Max NPC ESP Distance",
    Default = 2500,
    Min = 300,
    Max = 8000,
    Rounding = 0,
})

-- 4. Waypoints & POI ESP
local wToggle = WaypointESPGroup:AddToggle("Location_ESP", {
    Text = "Enable Waypoints & POI ESP",
    Default = false,
    Tooltip = "Display landmarks: Caldera, Heavens Point Church, Sanctuary of Blades, Mount Thul...",
})
wToggle:AddColorPicker("LocationESPColor", {
    Default = Color3.fromRGB(34, 197, 94),
    Title = "Waypoint Color",
})

WaypointESPGroup:AddSlider("Location_ESPMaxDist", {
    Text = "Max Location ESP Distance",
    Default = 6000,
    Min = 1000,
    Max = 15000,
    Rounding = 0,
})

-- 5. Ingredient & Ore ESP
local cToggle = ESPGroup:AddToggle("ESP_Crylight", {
    Text = "Enable Ingredient ESP (Herbs)",
    Default = false,
    Tooltip = "Display locations of herbs: Crylight, Aestic, Everthorn, etc.",
})
cToggle:AddColorPicker("CrylightESPColor", {
    Default = Color3.fromRGB(56, 189, 248),
    Title = "Ingredient Color",
})

local oToggle = ESPGroup:AddToggle("ESP_Ore", {
    Text = "Enable Ore ESP (Ores)",
    Default = false,
    Tooltip = "Display locations of ore nodes: Ferrus, Iron, Gold, Carnelian...",
})
oToggle:AddColorPicker("OreESPColor", {
    Default = Color3.fromRGB(245, 158, 11),
    Title = "Ore Color",
})

ESPGroup:AddSlider("ESP_MaxDistance", {
    Text = "Max Resource ESP Distance",
    Default = 3000,
    Min = 500,
    Max = 8000,
    Rounding = 0,
})

-- 6. Filters & Categories
FilterGroup:AddDropdown("ESPFilterMode", {
    Values = { "All", "CrylightOnly", "Whitelist" },
    Default = 1,
    Multi = false,
    Text = "Filter Mode",
})

FilterGroup:AddDropdown("ESPWhitelist", {
    Values = { "Crylight", "Aestic", "Everthorn", "Laneus", "Ferrus Ore", "Iron Ore", "Gold Ore", "Carnelian Ore" },
    Default = {},
    Multi = true,
    Text = "Custom Whitelist Items",
})

local QOLGroup = Tabs.Visuals:AddRightGroupbox("Quality of Life (QOL)")

QOLGroup:AddToggle("ShowEnemyInfo", {
    Text = "Show Enemy Info",
    Default = false,
    Tooltip = "Display clean overhead text directly above enemy HP bars showing all enemy skills, cooldowns, energy requirements, and status without boxes",
})

QOLGroup:AddSlider("EnemyInfoHeight", {
    Text = "Enemy Info Height Offset",
    Default = 8,
    Min = 3,
    Max = 25,
    Rounding = 1,
    Tooltip = "Height offset in studs above the HP bar (increase if overlapping tall monster names/health bars)",
})

QOLGroup:AddToggle("RevealRealHpMana", {
    Text = "Reveal Real HP / Mana",
    Default = false,
    Tooltip = "Reveal exact numerical HP and Mana/Energy values on all health bars instead of '???'",
})

QOLGroup:AddToggle("RevealUnidentified", {
    Text = "Reveal Unidentified Item Names",
    Default = false,
    Tooltip = "Reveal true item names of unidentified artifacts and gear in your inventory instead of generic 'Unidentified'",
})

QOLGroup:AddToggle("ShowItemStats", {
    Text = "Show Inventory Item Tiers & Stats",
    Default = false,
    Tooltip = "Display exact Tier and rolled TierStats/Enchants directly on your inventory item buttons (e.g. [T4] Shifting Hourglass (+2 Spe, +2 Arc))",
})

local FPSGroup = Tabs.Visuals:AddRightGroupbox("FPS Booster")

local FPSBooster = {
    originalFogEnd = (Lighting and Lighting.FogEnd) or 100000,
    originalFogStart = (Lighting and Lighting.FogStart) or 0,
    originalGlobalShadows = (Lighting and Lighting.GlobalShadows) or true,
    originalBrightness = (Lighting and Lighting.Brightness) or 2,
    originalAmbient = (Lighting and Lighting.Ambient) or Color3.fromRGB(0, 0, 0),
    originalOutdoorAmbient = (Lighting and Lighting.OutdoorAmbient) or Color3.fromRGB(128, 128, 128),
    originalShadowSoftness = (Lighting and Lighting.ShadowSoftness) or 0.2,
}

local OptimizationState = {
    extremeActive = false,
    extremeConnection = nil,
    lowGraphicsActive = false,
    lowGraphicsConnection = nil,
    removeTreesActive = false,
    removeTreesConnection = nil,
}

-- 1. XU LY hidden CAY COI & THAM THUC VAT (REMOVE TREES / FOLIAGE / GRASS)
function FPSBooster.applyPartTreeRemoval(obj, hideTrees)
    if not obj then return end
    local name = obj.Name:lower()
    local isTreeFoliage = name:find("tree") or name:find("bush") or name:find("leaf") or name:find("leaves")
        or name:find("foliage") or name:find("grass") or name:find("plant") or name:find("flora")
        or name:find("canopy") or name:find("trunk") or name:find("vine") or name:find("wood")

    if obj:IsA("Model") and isTreeFoliage and not obj:FindFirstChildOfClass("Humanoid") and not obj:FindFirstChild("ClickDetector") then
        for _, p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Transparency = hideTrees and 1 or 0
                p.CastShadow = not hideTrees
                p.CanCollide = not hideTrees
            end
        end
    elseif obj:IsA("BasePart") and isTreeFoliage and not (LocalPlayer.Character and obj:IsDescendantOf(LocalPlayer.Character)) then
        obj.Transparency = hideTrees and 1 or 0
        obj.CastShadow = not hideTrees
        obj.CanCollide = not hideTrees
    end
end

function FPSBooster.applyTreeRemoval()
    task.spawn(function()
        pcall(function()
            local hideTrees = Toggles.RemoveTrees and Toggles.RemoveTrees.Value or false
            OptimizationState.removeTreesActive = hideTrees

            -- Quet thu muc rac MapGarbage & toan bo workspace
            local mapGarbage = workspace:FindFirstChild("MapGarbage")
            if mapGarbage then
                local treeGarb = mapGarbage:FindFirstChild("TreeGarbage")
                if treeGarb then
                    for _, m in ipairs(treeGarb:GetDescendants()) do
                        if m:IsA("BasePart") then
                            m.Transparency = hideTrees and 1 or 0
                            m.CastShadow = not hideTrees
                        end
                    end
                end
            end

            for _, obj in ipairs(workspace:GetDescendants()) do
                FPSBooster.applyPartTreeRemoval(obj, hideTrees)
            end

            if hideTrees then
                if not OptimizationState.removeTreesConnection then
                    OptimizationState.removeTreesConnection = workspace.DescendantAdded:Connect(function(child)
                        if OptimizationState.removeTreesActive then
                            task.defer(function()
                                FPSBooster.applyPartTreeRemoval(child, true)
                            end)
                        end
                    end)
                    registerConnection(OptimizationState.removeTreesConnection)
                end
            else
                if OptimizationState.removeTreesConnection then
                    OptimizationState.removeTreesConnection:Disconnect()
                    OptimizationState.removeTreesConnection = nil
                end
            end
        end)
    end)
end

-- 2. XU LY DO HOA MUOT & TAT PARTICLE (LOW GRAPHICS)
function FPSBooster.applyPartLowGraphics(p, isLow)
    if not p then return end
    if LocalPlayer.Character and p:IsDescendantOf(LocalPlayer.Character) then return end

    if p:IsA("BasePart") then
        if isLow then
            p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0
            p.CastShadow = false
        end
    elseif p:IsA("MeshPart") then
        if isLow then
            p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0
            p.CastShadow = false
            p.TextureID = ""
        end
    elseif p:IsA("SpecialMesh") then
        if isLow then
            p.TextureId = ""
        end
    elseif p:IsA("Decal") or p:IsA("Texture") then
        if isLow then
            p.Transparency = 1
        end
    elseif p:IsA("SurfaceAppearance") then
        if isLow then
            p:Destroy()
        end
    elseif p:IsA("ParticleEmitter") or p:IsA("Smoke") or p:IsA("Fire") or p:IsA("Sparkles") or p:IsA("Trail") or p:IsA("Beam") or p:IsA("Highlight") then
        p.Enabled = not isLow
    elseif p:IsA("PointLight") or p:IsA("SpotLight") or p:IsA("SurfaceLight") then
        p.Enabled = not isLow
    end
end

function FPSBooster.applyLowGraphics()
    task.spawn(function()
        pcall(function()
            local isLow = Toggles.LowGraphics and Toggles.LowGraphics.Value or false
            OptimizationState.lowGraphicsActive = isLow

            if isLow then
                pcall(function() settings().Rendering.QualityLevel = 1 end)
                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    terrain.Decoration = false
                end
            end

            for _, p in ipairs(workspace:GetDescendants()) do
                FPSBooster.applyPartLowGraphics(p, isLow)
            end

            if isLow then
                if not OptimizationState.lowGraphicsConnection then
                    OptimizationState.lowGraphicsConnection = workspace.DescendantAdded:Connect(function(child)
                        if OptimizationState.lowGraphicsActive then
                            task.defer(function()
                                FPSBooster.applyPartLowGraphics(child, true)
                            end)
                        end
                    end)
                    registerConnection(OptimizationState.lowGraphicsConnection)
                end
            else
                if OptimizationState.lowGraphicsConnection then
                    OptimizationState.lowGraphicsConnection:Disconnect()
                    OptimizationState.lowGraphicsConnection = nil
                end
            end
        end)
    end)
end

-- 3. XU LY MASTER FPS BOOST (clear SUONG MU / HIEU UNG ANH SANG)
function FPSBooster.applyRemoveFog()
    task.spawn(function()
        pcall(function()
            local isRemove = Toggles.RemoveFog and Toggles.RemoveFog.Value or false
            if isRemove then
                local function clearFogOnce()
                    if Lighting.FogEnd < 9e8 or Lighting.FogStart < 9e8 then
                        Lighting.FogEnd = 9e9
                        Lighting.FogStart = 9e9
                    end
                    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
                    if atmosphere and (atmosphere.Density > 0 or atmosphere.Haze > 0) then
                        atmosphere.Density = 0
                        atmosphere.Haze = 0
                        atmosphere.Glare = 0
                    end
                    for _, effect in ipairs(Lighting:GetChildren()) do
                        if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("Atmosphere") or effect:IsA("Clouds") then
                            if effect.Enabled then effect.Enabled = false end
                        end
                    end
                end

                clearFogOnce()

                task.spawn(function()
                    while HubState.running and Toggles.RemoveFog and Toggles.RemoveFog.Value do
                        clearFogOnce()
                        task.wait(1)
                    end
                end)
            else
                Lighting.FogEnd = FPSBooster.originalFogEnd or 100000
                Lighting.FogStart = FPSBooster.originalFogStart or 0
                local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    atmosphere.Density = 0.3
                end
            end
        end)
    end)
end

function FPSBooster.applyFPSBoost()
    task.spawn(function()
        pcall(function()
            local isBoost = Toggles.EnableFPSBoost and Toggles.EnableFPSBoost.Value
            if isBoost then
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                Lighting.FogStart = 9e9
                Lighting.ShadowSoftness = 0

                local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    atmosphere.Density = 0
                    atmosphere.Haze = 0
                    atmosphere.Glare = 0
                end

                for _, effect in ipairs(Lighting:GetChildren()) do
                    if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("ColorCorrectionEffect") then
                        effect.Enabled = false
                    end
                end

                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    terrain.Decoration = false
                    terrain.WaterWaveSize = 0
                    terrain.WaterWaveSpeed = 0
                    terrain.WaterReflectance = 0
                end
            else
                Lighting.GlobalShadows = FPSBooster.originalGlobalShadows or true
                Lighting.FogEnd = FPSBooster.originalFogEnd or 100000
                Lighting.FogStart = FPSBooster.originalFogStart or 0
                Lighting.ShadowSoftness = FPSBooster.originalShadowSoftness or 0.2
                local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    atmosphere.Density = 0.3
                end
            end
        end)
    end)
end

-- 4. XU LY EXTREME FPS BOOSTER (POTATO MODE TOAN DIEN - not TAT 3D RENDER)
function FPSBooster.applyExtremePart(p)
    if not p then return end
    if p:IsA("BasePart") then
        p.Material = Enum.Material.SmoothPlastic
        p.Reflectance = 0
        p.CastShadow = false
    elseif p:IsA("MeshPart") then
        p.Material = Enum.Material.SmoothPlastic
        p.Reflectance = 0
        p.CastShadow = false
        p.TextureID = ""
    elseif p:IsA("SpecialMesh") then
        p.TextureId = ""
    elseif p:IsA("Decal") or p:IsA("Texture") then
        p.Transparency = 1
    elseif p:IsA("SurfaceAppearance") then
        p:Destroy()
    elseif p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") or p:IsA("Smoke") or p:IsA("Fire") or p:IsA("Sparkles") or p:IsA("Highlight") or p:IsA("Explosion") then
        p.Enabled = false
    elseif p:IsA("PointLight") or p:IsA("SpotLight") or p:IsA("SurfaceLight") then
        p.Enabled = false
    elseif p:IsA("PostEffect") or p:IsA("BloomEffect") or p:IsA("BlurEffect") or p:IsA("SunRaysEffect") or p:IsA("DepthOfFieldEffect") or p:IsA("ColorCorrectionEffect") or p:IsA("Atmosphere") or p:IsA("Clouds") then
        p.Enabled = false
    end
end

function FPSBooster.applyExtremeFPSBoost()
    task.spawn(function()
        pcall(function()
            local isExtreme = (Toggles.FPSBoost and Toggles.FPSBoost.Value) or (Toggles.ExtremeFPSBoost and Toggles.ExtremeFPSBoost.Value) or false
            OptimizationState.extremeActive = isExtreme

            if isExtreme then
                -- A. Cau hinh Engine Renderer & GPU Settings thap nhat tuyet doi
                pcall(function() settings().Rendering.QualityLevel = 1 end)
                pcall(function() sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility) end)

                -- B. Triet tieu toan bo hieu ung anh sang / suong mu / bong do
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                Lighting.FogStart = 9e9
                Lighting.Brightness = 1
                Lighting.ShadowSoftness = 0
                Lighting.ClockTime = 14
                Lighting.Ambient = Color3.fromRGB(130, 130, 130)
                Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)

                for _, effect in ipairs(Lighting:GetChildren()) do
                    if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("Atmosphere") or effect:IsA("Clouds") then
                        effect.Enabled = false
                    end
                end

                -- C. Triet tieu toan bo tham thuc vat & cay coi
                local mapGarbage = workspace:FindFirstChild("MapGarbage")
                if mapGarbage then
                    local treeGarb = mapGarbage:FindFirstChild("TreeGarbage")
                    if treeGarb then
                        for _, m in ipairs(treeGarb:GetDescendants()) do
                            if m:IsA("BasePart") then
                                m.Transparency = 1
                                m.CastShadow = false
                                m.CanCollide = false
                            end
                        end
                    end
                end

                -- D. Triet tieu Terrain Water & Decorations
                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    terrain.Decoration = false
                    terrain.WaterWaveSize = 0
                    terrain.WaterWaveSpeed = 0
                    terrain.WaterReflectance = 0
                    terrain.WaterTransparency = 0
                end

                -- E. Quet toan bo vat the trong Workspace
                for _, obj in ipairs(workspace:GetDescendants()) do
                    FPSBooster.applyExtremePart(obj)
                    FPSBooster.applyPartTreeRemoval(obj, true)
                end

                -- F. Lang nghe vat the moi sinh ra va lap tuc ep ve dang Potato
                if not OptimizationState.extremeConnection then
                    OptimizationState.extremeConnection = workspace.DescendantAdded:Connect(function(child)
                        if OptimizationState.extremeActive then
                            task.defer(function()
                                FPSBooster.applyExtremePart(child)
                                FPSBooster.applyPartTreeRemoval(child, true)
                            end)
                        end
                    end)
                    registerConnection(OptimizationState.extremeConnection)
                end

                -- G. Don dep bo nho RAM
                collectgarbage("collect")
                Library:Notify("🔥 Extreme Potato FPS Mode (Max FPS) Activated!", 3)
            else
                if OptimizationState.extremeConnection then
                    OptimizationState.extremeConnection:Disconnect()
                    OptimizationState.extremeConnection = nil
                end

                Lighting.GlobalShadows = FPSBooster.originalGlobalShadows or true
                Lighting.FogEnd = FPSBooster.originalFogEnd or 100000
                Lighting.FogStart = FPSBooster.originalFogStart or 0
                Lighting.Brightness = FPSBooster.originalBrightness or 2
                Lighting.Ambient = FPSBooster.originalAmbient or Color3.fromRGB(0, 0, 0)
                Lighting.OutdoorAmbient = FPSBooster.originalOutdoorAmbient or Color3.fromRGB(128, 128, 128)
                Lighting.ShadowSoftness = FPSBooster.originalShadowSoftness or 0.2

                FPSBooster.applyFPSBoost()
                Library:Notify("Extreme FPS Booster Deactivated.", 3)
            end
        end)
    end)
end

ESPGroup:AddToggle("MasterESP", {
    Text = "Enable Ingredient ESP",
    Default = false,
})

ESPGroup:AddToggle("ESPShowDistance", {
    Text = "Show Distance [..m]",
    Default = false,
})

ESPGroup:AddSlider("ESPMaxDistance", {
    Text = "Max Distance (Studs)",
    Default = 10000,
    Min = 500,
    Max = 20000,
    Rounding = 0,
})

FilterGroup:AddDropdown("ESPFilterMode", {
    Values = { "All", "CrylightOnly", "Whitelist" },
    Default = 1,
    Multi = false,
    Text = "Filter Mode",
})

FilterGroup:AddDropdown("ESPWhitelist", {
    Values = {
        "Crylight", "Cryastem", "Hightail", "Everthistle",
        "7 Leafed Everthistle", "Carnastool", "Driproot", "Cursed Shroom", "Cursed Shroom 2",
        "Mushrooms", "Bones", "Branch Pile", "Ferrus", "Aestic", "Laneus"
    },
    Default = {},
    Multi = true,
    Text = "Whitelist Selection",
})

FPSGroup:AddToggle("RemoveFog", {
    Text = "Remove Fog & Atmosphere",
    Default = false,
    Tooltip = "Actively check and permanently clear all fog, haze, blur, and lighting atmosphere with continuous watchdog loop",
    Callback = function(val)
        if applyRemoveFog then FPSBooster.applyRemoveFog() end
    end,
})

FPSGroup:AddToggle("FPSBoost", {
    Text = "🔥 FPS Boost (Potato Mode)",
    Default = false,
    Tooltip = "Maximum FPS Boost: Smooth Plastic, disable Decals/Textures/Lights, hide foliage, disable Particles/Shadows/Fog",
    Callback = function(val)
        FPSBooster.applyExtremeFPSBoost()
    end,
})

FPSGroup:AddSlider("FPSCap", {
    Text = "Max FPS Cap",
    Default = 60,
    Min = 30,
    Max = 360,
    Rounding = 0,
    Callback = function(val)
        if setfpscap then
            setfpscap(val)
        end
    end
})

if setfpscap then
    pcall(setfpscap, 60)
end

-- -----------------------------------------------------------------------------
-- TAB 6: SETTINGS / CONFIG
-- -----------------------------------------------------------------------------

-- =============================================================================

-- -----------------------------------------------------------------------------
-- TAB: DISCORD WEBHOOK INTEGRATION & NOTIFICATIONS
-- -----------------------------------------------------------------------------
end

do
end

do
local WebhookConfigGroup = Tabs.Webhook:AddLeftGroupbox("Webhook Configuration")
local WebhookActionsGroup = Tabs.Webhook:AddRightGroupbox("Webhook Testing & Actions")

WebhookConfigGroup:AddInput("DiscordWebhook", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Discord Webhook URL",
    Tooltip = "Unified Discord Webhook URL for all alerts: Boss Yar'thul, Herb/Ore Harvest, and Corrupt Servers",
    Placeholder = "https://discord.com/api/webhooks/...",
})

WebhookConfigGroup:AddDivider()

WebhookConfigGroup:AddToggle("YarthulSendWebhook", {
    Text = "Enable Boss & Loot Alerts",
    Default = false,
    Tooltip = "Send detailed Discord embeds when defeating bosses or looting items",
})

WebhookConfigGroup:AddToggle("NotifyOnHarvest", {
    Text = "Enable Herb & Ore Alerts",
    Default = false,
    Tooltip = "Send Discord alerts when completing resource harvesting",
})

WebhookConfigGroup:AddToggle("CorruptPingRole", {
    Text = "Ping @everyone on Corrupt Server",
    Default = false,
    Tooltip = "Ping @everyone upon discovering a Corrupted Server",
})

WebhookActionsGroup:AddButton({
    Text = "Send Test Webhook",
    Tooltip = "Send a luxury dark-tech test verification embed to your Discord Webhook",
    Func = function()
        AutoYarthul.sendWebhook("Test")
    end,
})
end

do
end

do
local ThemeGroup = Tabs.Settings:AddLeftGroupbox("Theme & Visual Appearance")

ThemeGroup:AddDropdown("ThemeSelect", {
    Text = "Select UI Color Theme",
    Values = {"Cyber-Tactical Cyan", "Crimson Bloodline", "Midnight Violet", "Emerald Glass"},
    Default = "Cyber-Tactical Cyan",
    Callback = function(themeName)
        if themeName == "Crimson Bloodline" then ZeroLib:SetTheme("Crimson")
        elseif themeName == "Cyber-Tactical Cyan" then ZeroLib:SetTheme("CyberCyan")
        elseif themeName == "Midnight Violet" then ZeroLib:SetTheme("MidnightViolet")
        elseif themeName == "Emerald Glass" then ZeroLib:SetTheme("EmeraldGlass")
        end
        ZeroLib:Notify({
            Title = "Theme Applied",
            Content = "has ap dung interface: " .. themeName,
            Type = "Success"
        })
    end
})

local MenuGroup = Tabs.Settings:AddRightGroupbox("Menu Settings")

local function unloadHub()
    hubLog("[ArcaneHub]  is tien hanh Unload toan bo script va giai phong tai nguyen...")
    HubState.running = false
    if Farmer then Farmer.running = false end
    if AutoFight then AutoFight.stop() end
    if AutoYarthul then AutoYarthul.stop(true) end
    if LevelFarmer then LevelFarmer.running = false end
    if Miner then Miner.running = false end
    if FlightController then FlightController.active = false end
    if EnemyPredictor then EnemyPredictor.stop() end
    if CorruptHunter then CorruptHunter.stop() end
    if ServerHopper then ServerHopper.isHopping = false end

    for _, conn in ipairs(HubState.connections) do
        pcall(function() conn:Disconnect() end)
    end
    HubState.connections = {}

    if AntiAFK and AntiAFK.connections then
        for _, conn in ipairs(AntiAFK.connections) do
            pcall(function() conn:Disconnect() end)
        end
        AntiAFK.connections = {}
    end

    if activeESP then
        for inst, data in pairs(activeESP) do
            pcall(function() data.billboard:Destroy() end)
        end
        activeESP = {}
    end

    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false; hum.WalkSpeed = 16 end
        end
    end)

    pcall(function() Library:Unload() end)
    shared.ArcaneHub = nil
    globalEnv._ArcaneHubRunning = nil
    globalEnv._ArcaneHubInitLock = nil
    hubLog("[ArcaneHub] Da Unload sach se 100%!")
end

MenuGroup:AddButton("Unload Script", function()
    unloadHub()
end)

MenuGroup:AddToggle("AutoLoadOnChangingServer", {
    Text = "Auto Load on Changing Server",
    Default = false,
    Callback = function(Value)
        if Value then
            local queued = queueTeleportScript()
            if queued then
                Library:Notify({ Title = "Auto Load", Content = "Teleport Queue Loaded!", Type = "Success" })
            else
                Library:Notify({ Title = "Warning", Content = "Executor does not support queue_on_teleport!", Type = "Warning" })
            end
        end
    end
})

local menuBindLabel = MenuGroup:AddLabel("Menu Keybind")
local menuKeybind = menuBindLabel:AddKeyPicker("MenuKeybind", {
    Default = "End",
    NoUI = true,
    Text = "Menu keybind",
    Callback = function(key)
        ZeroLib:SetToggleKey(key)
    end
})
if menuKeybind and menuKeybind.OnChanged then
    menuKeybind:OnChanged(function(key)
        ZeroLib:SetToggleKey(key)
    end)
end

local ConfigGroup = Tabs.Settings:AddLeftGroupbox("Configuration")
ZeroLib.SaveManager:BuildConfigSection(ConfigGroup)

local AntiAFK = {
    initialized = false,
    connections = {},
}

function AntiAFK.init()
    if AntiAFK.initialized then return end
    AntiAFK.initialized = true

    -- Lop 1: Go bo / Vo hieu hoa connect Idled mac dinh cua Roblox CoreGui (neu executor support getconnections)
    pcall(function()
        if getconnections then
            for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
                if conn.Disable then
                    conn:Disable()
                elseif conn.Disconnect then
                    conn:Disconnect()
                end
            end
        end
    end)

    -- Lop 2: Lang nghe su kien LocalPlayer.Idled va gui tuong tac ao mo phong nguoi dung (Always-on)
    local idledConn = registerConnection(LocalPlayer.Idled:Connect(function()
        if HubState.running then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end))
    table.insert(AntiAFK.connections, idledConn)

    -- Lop 3: Luong nhip tim (Heartbeat pulse) dinh ky moi 60 giay chu dong reset counter AFK (Always-on)
    task.spawn(function()
        while HubState.running do
            task.wait(60)
            if HubState.running then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end
    end)

    hubLog("[AntiAFK] Built-in Anti-AFK Engine Initialized Successfully!")
end

AntiAFK.init()

-- =============================================================================
-- QOL: REAL HP/MANA REVEAL & UNIDENTIFIED ITEMS / ITEM STATS REVEALER
-- =============================================================================
task.spawn(function()
    local blueEnergyColor = Color3.fromRGB(106, 192, 242)

    while HubState.running do
        task.wait(0.25)
        if not HubState.running then break end

        -- 1. REVEAL UNIDENTIFIED ITEM NAMES & SHOW INVENTORY ITEM STATS
        local revealUnidentified = Toggles.RevealUnidentified and Toggles.RevealUnidentified.Value
        local showStats = Toggles.ShowItemStats and Toggles.ShowItemStats.Value

        if revealUnidentified or showStats then
            pcall(function()
                local pgui = PlayerGui
                local inv = pgui and pgui:FindFirstChild("Inventory")
                if inv then
                    local invScript = inv:FindFirstChildWhichIsA("LocalScript", true)
                    local itemDict = nil
                    if invScript and getsenv and getupvalues then
                        pcall(function()
                            local env = getsenv(invScript)
                            if env and env.newTile then
                                local uvs = getupvalues(env.newTile)
                                itemDict = uvs[6]
                            end
                        end)
                    end

                    for _, btn in ipairs(inv:GetDescendants()) do
                        if btn:IsA("TextButton") and itemDict and itemDict[btn.Name] then
                            local itemObj = itemDict[btn.Name]
                            local itemData = itemObj and (itemObj.ItemData or itemObj)
                            if itemData then
                                local cfg = itemData.Config or {}
                                local rawName = itemData.Name or itemData.Tool or btn.Name:gsub("#%d+$", "")

                                if cfg.Unidentified then
                                    if revealUnidentified then
                                        btn.Text = rawName .. " [Unidentified]"
                                    end
                                else
                                    if showStats then
                                        local statList = {}
                                        if cfg.TierStats and type(cfg.TierStats) == "table" then
                                            for k, v in pairs(cfg.TierStats) do
                                                if type(v) == "number" and v ~= 0 then
                                                    local shortK = tostring(k):sub(1, 3)
                                                    table.insert(statList, string.format("+%d %s", v, shortK))
                                                end
                                            end
                                        end

                                        if cfg.Enchant and tostring(cfg.Enchant) ~= "" then
                                            table.insert(statList, tostring(cfg.Enchant))
                                        end

                                        local prefix = cfg.Tier and string.format("[T%d] ", cfg.Tier) or ""
                                        local suffix = #statList > 0 and (" (" .. table.concat(statList, ", ") .. ")") or ""
                                        btn.Text = prefix .. rawName .. suffix
                                    end
                                end
                            end
                        end
                    end

                    -- ToolTip Handlers
                    local tooltip = inv:FindFirstChild("ToolTip", true)
                    if tooltip and tooltip.Visible and revealUnidentified then
                        local textLbl = tooltip:FindFirstChildWhichIsA("TextLabel", true)
                        if textLbl and textLbl.Text:find("You have no idea what this does") then
                            textLbl.Text = "[Real Item Revealed by Arcane Hub]"
                        end
                    end

                    local advTooltip = inv:FindFirstChild("AdvancedTooltip", true)
                    if advTooltip and advTooltip.Visible and revealUnidentified then
                        local descLbl = advTooltip:FindFirstChild("Desc")
                        if descLbl and descLbl:IsA("TextLabel") and descLbl.Text:find("You have no idea what this does") then
                            local nameLbl = advTooltip:FindFirstChild("ItemName")
                            if nameLbl and nameLbl:IsA("TextLabel") then
                                descLbl.Text = "[Real Item Revealed] " .. nameLbl.Text
                            end
                        end
                    end
                end
            end)
        end

        -- 2. REVEAL REAL MANA / ENERGY IN COMBAT
        if Toggles.RevealRealHpMana and Toggles.RevealRealHpMana.Value then
            pcall(function()
                local char = LocalPlayer.Character
                local pgui = PlayerGui
                local combatGui = pgui and pgui:FindFirstChild("Combat")
                local holder = combatGui and combatGui:FindFirstChild("Holder")
                if char and holder then
                    local status = char:FindFirstChild("Status")
                    local energyVal = status and status:FindFirstChild("Energy")
                    if energyVal then
                        local curEnergy = energyVal.Value
                        local maxEnergy = energyVal.MaxValue or 6

                        local currentEnergyFrame = holder:FindFirstChild("CurrentEnergy")
                        local energyAmountLabel = currentEnergyFrame and currentEnergyFrame:FindFirstChild("Amount")
                        if energyAmountLabel and energyAmountLabel:IsA("TextLabel") then
                            if energyAmountLabel.Text == "???" or energyAmountLabel.Text:find("%?") then
                                energyAmountLabel.Text = string.format("%d/%d", curEnergy, maxEnergy)
                            end
                        end

                        local energyBarsContainer = holder:FindFirstChild("Energy")
                        if energyBarsContainer then
                            for i = 1, maxEnergy do
                                local bar = energyBarsContainer:FindFirstChild(tostring(i))
                                if bar and bar:IsA("GuiObject") then
                                    bar.BackgroundColor3 = blueEnergyColor
                                    bar.Visible = (i <= curEnergy)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- KHOI CHAY cycle auto & LUU GLOBAL STATE
-- =============================================================================
globalEnv._ArcaneHubRunning = true
shared.ArcaneHub = {
    Unload = unloadHub,
    Library = Library,
}

if Toggles.AutoFarmCrylight and Toggles.AutoFarmCrylight.Value then
    Farmer.runCycle()
end
if Toggles.AutoMineOre and Toggles.AutoMineOre.Value then
    Miner.runCycle()
end
if Toggles.AutoFarmLevel and Toggles.AutoFarmLevel.Value then
    LevelFarmer.runCycle()
end

-- LINORIA-STYLE AUTOLOAD CONFIG ON BOOT
task.spawn(function()
    task.wait(0.5)
    pcall(function()
        ZeroLib.SaveManager:LoadAutoloadConfig()
    end)
end)

if AutoYarthul then
    AutoYarthul.checkSessionOnBoot()
end-- =============================================================================
-- ENEMY STATUS & SKILL COOLDOWN MONITOR (QOL VISUAL SUITE)
-- =============================================================================
end
end

local EnemyStatusEngine = {
    running = false,
    thread = nil,
    gui = nil,
    billboards = {},
    skillsCache = {},
    npcCache = {},
    cooldowns = {},
    lastUsedAttacks = {},
    lastIndicatedSkill = nil,
    lastIndicatedTime = 0,
    currentDecidingEnemy = nil,
    currentTurn = 0,
}

function EnemyStatusEngine.initEnemyStatusData()
    local rep = game:GetService("ReplicatedStorage")
    pcall(function()
        local skillsMod = rep:FindFirstChild("Constants") and rep.Constants:FindFirstChild("Skills")
        if skillsMod and skillsMod:IsA("ModuleScript") then
            local ok, data = pcall(require, skillsMod)
            if ok and type(data) == "table" then
                EnemyStatusEngine.skillsCache = data
            end
        end
    end)

    local function scanNPCFolder(folder)
        if folder then
            for _, mod in ipairs(folder:GetChildren()) do
                if mod:IsA("ModuleScript") then
                    local ok, data = pcall(require, mod)
                    if ok and type(data) == "table" then
                        EnemyStatusEngine.npcCache[mod.Name] = data
                        local clean = mod.Name:gsub("%s*%(.*%)", ""):gsub("%d+$", ""):gsub("^%s*(.-)%s*$", "%1")
                        EnemyStatusEngine.npcCache[clean] = data
                    end
                end
            end
        end
    end

    pcall(function() scanNPCFolder(rep:FindFirstChild("NPCs")) end)
    pcall(function() scanNPCFolder(rep:FindFirstChild("NPCs_Extra")) end)
end
EnemyStatusEngine.initEnemyStatusData()

pcall(function()
    local fightRemotes = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Fight")
    if fightRemotes then
        local atkInd = fightRemotes:FindFirstChild("AttackIndicate")
        if atkInd and atkInd:IsA("RemoteEvent") then
            atkInd.OnClientEvent:Connect(function(skillName)
                if not skillName then return end
                local skStr = tostring(skillName)
                EnemyStatusEngine.lastIndicatedSkill = skStr
                EnemyStatusEngine.lastIndicatedTime = os.clock()
                EnemyStatusEngine.currentDecidingEnemy = nil
            end)
        end

        local deciding = fightRemotes:FindFirstChild("Deciding")
        if deciding and deciding:IsA("RemoteEvent") then
            deciding.OnClientEvent:Connect(function(enemyName)
                EnemyStatusEngine.currentDecidingEnemy = enemyName
            end)
        end
    end
end)

function EnemyStatusEngine.getSkillStats(skillName)
    if not skillName or skillName == "" or skillName == "None" or skillName == "Strike" then
        return 0, 0
    end
    local cost = 0
    local cd = 0
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        local SkillsModule = require(rep.Constants.Skills)
        if SkillsModule and SkillsModule[skillName] then
            local data = SkillsModule[skillName]
            cost = tonumber(data.Cost) or 0
            cd = tonumber(data.Cooldown) or tonumber(data.CD) or 0
        end
    end)
    return cost, cd
end

function EnemyStatusEngine.analyzeEnemyStatus(enemyModel)
    if not enemyModel or not enemyModel.Parent then return nil end

    local enemyName = enemyModel.Name
    local cleanName = enemyName:gsub("%s*%(.*%)", ""):gsub("%d+$", ""):gsub("^%s*(.-)%s*$", "%1")

    local hum = enemyModel:FindFirstChildOfClass("Humanoid")
    local curHp = hum and math.floor(hum.Health) or 0
    local maxHp = hum and math.floor(hum.MaxHealth) or 100

    local energyVal = enemyModel:FindFirstChild("Status") and enemyModel.Status:FindFirstChild("Energy")
    local curEnergy = energyVal and energyVal.Value or 0

    local lastAttackVal = enemyModel:FindFirstChild("Effects") and enemyModel.Effects:FindFirstChild("LastUsedAttack")
    local lastAttack = lastAttackVal and tostring(lastAttackVal.Value) or "None"

    if lastAttack ~= "None" and lastAttack ~= "" then
        if not EnemyStatusEngine.lastUsedAttacks[enemyModel] or EnemyStatusEngine.lastUsedAttacks[enemyModel] ~= lastAttack then
            EnemyStatusEngine.lastUsedAttacks[enemyModel] = lastAttack
            local _, baseCD = EnemyStatusEngine.getSkillStats(lastAttack)
            if baseCD > 0 then
                if not EnemyStatusEngine.cooldowns[enemyModel] then EnemyStatusEngine.cooldowns[enemyModel] = {} end
                EnemyStatusEngine.cooldowns[enemyModel][lastAttack] = baseCD
            end
        end
    end

    local npcData = EnemyStatusEngine.npcCache[cleanName] or EnemyStatusEngine.npcCache[enemyName]
    local maxEnergy = npcData and npcData.MaxEnergy or 6
    local attackPool = npcData and npcData.Attacks or {}

    local modelCDs = EnemyStatusEngine.cooldowns[enemyModel] or {}
    local skillBadges = {}
    local seenSkills = {}

    -- Universal Skill Extractor: Iterates through ALL attack categories (Damage, Special, Healing, NoEnergy, Stun, Buff, Utility, etc.)
    for categoryName, categoryMoves in pairs(attackPool) do
        if type(categoryMoves) == "table" then
            for _, skName in ipairs(categoryMoves) do
                if type(skName) == "string" and not seenSkills[skName] and skName ~= "BaseClass" and skName ~= "SuperClass" and skName ~= "None" then
                    seenSkills[skName] = true
                    local cost, baseCD = EnemyStatusEngine.getSkillStats(skName)
                    local remCD = modelCDs[skName] or 0
                    local statusTag = ""

                    if remCD > 0 then
                        statusTag = string.format("<font color='#FFA500'>[CD: %d]</font>", remCD)
                    elseif curEnergy >= cost then
                        statusTag = "<font color='#2ECC71'>[READY]</font>"
                    else
                        statusTag = string.format("<font color='#E74C3C'>[Need %dE]</font>", cost)
                    end

                    table.insert(skillBadges, string.format("<b>%s</b> (%dE) %s", skName, cost, statusTag))
                end
            end
        elseif type(categoryMoves) == "string" and not seenSkills[categoryMoves] and categoryMoves ~= "BaseClass" and categoryMoves ~= "SuperClass" then
            seenSkills[categoryMoves] = true
            local cost, baseCD = EnemyStatusEngine.getSkillStats(categoryMoves)
            local remCD = modelCDs[categoryMoves] or 0
            local statusTag = ""

            if remCD > 0 then
                statusTag = string.format("<font color='#FFA500'>[CD: %d]</font>", remCD)
            elseif curEnergy >= cost then
                statusTag = "<font color='#2ECC71'>[READY]</font>"
            else
                statusTag = string.format("<font color='#E74C3C'>[Need %dE]</font>", cost)
            end

            table.insert(skillBadges, string.format("<b>%s</b> (%dE) %s", categoryMoves, cost, statusTag))
        end
    end

    if #skillBadges == 0 then
        table.insert(skillBadges, "<b>Strike</b> (0E) <font color='#2ECC71'>[READY]</font>")
    end

    return {
        model = enemyModel,
        name = cleanName,
        fullName = enemyName,
        curHp = curHp,
        maxHp = maxHp,
        curEnergy = curEnergy,
        maxEnergy = maxEnergy,
        lastAttack = lastAttack,
        skills = skillBadges
    }
end

EnemyStatusEngine.analyzeEnemyStatus = analyzeEnemyStatus

function EnemyStatusEngine.start()
    _G.EnemyStatusEngine = EnemyStatusEngine
    shared.EnemyStatusEngine = EnemyStatusEngine
    if EnemyStatusEngine.running then return end
    EnemyStatusEngine.running = true

    EnemyStatusEngine.thread = task.spawn(function()
        while EnemyStatusEngine.running do
            local inCombat = isInCombat()
            local showEnemyInfo = (Toggles.ShowEnemyInfo and Toggles.ShowEnemyInfo.Value) or (Toggles.ShowEnemyStatusHead and Toggles.ShowEnemyStatusHead.Value)

            if inCombat and showEnemyInfo then
                local activeEnemies = {}
                local living = workspace:FindFirstChild("Living")
                local char = LocalPlayer.Character
                local myFightVal = char and char:FindFirstChild("FightInProgress")
                local myFightId = myFightVal and myFightVal.Value
                local myRoot = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))

                if living and myRoot then
                    for _, m in ipairs(living:GetChildren()) do
                        if m ~= char and m:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(m) then
                            local fVal = m:FindFirstChild("FightInProgress")
                            local hum = m:FindFirstChildOfClass("Humanoid")
                            local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
                            
                            local isMyEnemy = false
                            if myFightId and fVal and fVal.Value == myFightId then
                                isMyEnemy = true
                            elseif root and (root.Position - myRoot.Position).Magnitude < 45 then
                                isMyEnemy = true
                            end

                            if isMyEnemy and hum and hum.Health > 0 then
                                table.insert(activeEnemies, m)
                            end
                        end
                    end
                end

                for idx, enemyModel in ipairs(activeEnemies) do
                    local sData = EnemyStatusEngine.analyzeEnemyStatus(enemyModel)
                    if sData then
                        local head = enemyModel:FindFirstChild("Head") or enemyModel:FindFirstChild("HumanoidRootPart")
                        if head then
                            local bb = EnemyStatusEngine.billboards[enemyModel]
                            
                            -- Find existing in-game HP Bar (StatDisplay)
                            local statDisplay = nil
                            for _, d in ipairs(enemyModel:GetDescendants()) do
                                if d:IsA("BillboardGui") and d ~= bb and (d.Name == "StatDisplay" or d.Name:find("Health") or d.Name:find("Status")) then
                                    statDisplay = d
                                    break
                                end
                            end

                            -- Dynamic Height Offset Calculation (Anchored above StatDisplay with 0 overlap)
                            local adorneePart = (statDisplay and statDisplay.Parent and statDisplay.Parent:IsA("BasePart") and statDisplay.Parent) or head
                            local baseOffsetY = statDisplay and statDisplay.StudsOffset.Y or 2.5
                            local userHeight = (Options.EnemyInfoHeight and Options.EnemyInfoHeight.Value) or 8
                            local targetOffsetY = baseOffsetY + userHeight -- Significantly elevated well above the HP bar

                            local skillCount = #sData.skills
                            local rows = math.max(1, math.ceil(skillCount / 2))
                            local calculatedHeight = 26 + (rows * 15)

                            if not bb or not bb.Parent then
                                bb = Instance.new("BillboardGui")
                                bb.Name = "EnemyInfoBB"
                                bb.Size = UDim2.new(0, 420, 0, calculatedHeight)
                                bb.AlwaysOnTop = true
                                bb.Adornee = adorneePart
                                bb.StudsOffset = Vector3.new(0, targetOffsetY, 0)
                                bb.MaxDistance = 140

                                -- Clean Text Display without any bounding box or container
                                local lbl = Instance.new("TextLabel")
                                lbl.Name = "InfoText"
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.Position = UDim2.new(0, 0, 0, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                                lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                                lbl.TextStrokeTransparency = 0.15
                                lbl.Font = Enum.Font.GothamMedium
                                lbl.TextSize = 10
                                lbl.TextWrapped = true
                                lbl.RichText = true
                                lbl.TextYAlignment = Enum.TextYAlignment.Bottom
                                lbl.TextXAlignment = Enum.TextXAlignment.Center
                                lbl.Parent = bb

                                pcall(function()
                                    local parentGui = (gethui and gethui()) or (game:GetService("CoreGui"):FindFirstChild("RobloxGui")) or PlayerGui
                                    bb.Parent = parentGui
                                end)
                                EnemyStatusEngine.billboards[enemyModel] = bb
                            end

                            bb.Adornee = adorneePart
                            bb.StudsOffset = Vector3.new(0, targetOffsetY, 0)
                            bb.Size = UDim2.new(0, 420, 0, calculatedHeight)

                            local infoLbl = bb:FindFirstChild("InfoText", true)
                            if infoLbl then
                                local hpPercent = math.clamp(sData.curHp / math.max(1, sData.maxHp), 0, 1)
                                local hpColor = hpPercent > 0.5 and "#2ECC71" or (hpPercent > 0.25 and "#F39C12" or "#E74C3C")
                                
                                local formattedSkills = {}
                                local curLine = {}
                                for i, badge in ipairs(sData.skills) do
                                    table.insert(curLine, badge)
                                    if #curLine == 2 or i == #sData.skills then
                                        table.insert(formattedSkills, table.concat(curLine, "   |   "))
                                        curLine = {}
                                    end
                                end

                                local headerLine = string.format("<b><font color='#FFFFFF'>%s</font></b> (<font color='%s'>%d/%d HP</font>)  •  ⚡ <font color='#00FFFF'><b>%d/%d E</b></font>  •  <i>Last: %s</i>", sData.name, hpColor, sData.curHp, sData.maxHp, sData.curEnergy, sData.maxEnergy, sData.lastAttack)
                                local skillsLine = table.concat(formattedSkills, "\n")
                                infoLbl.Text = headerLine .. "\n" .. skillsLine
                            end
                        end
                    end
                end
            else
                for m, bb in pairs(EnemyStatusEngine.billboards) do
                    if bb and bb.Parent then bb:Destroy() end
                end
                table.clear(EnemyStatusEngine.billboards)
            end

            task.wait(0.2)
        end
    end)
end

function EnemyStatusEngine.stop()
    EnemyStatusEngine.running = false
    if EnemyStatusEngine.thread then
        task.cancel(EnemyStatusEngine.thread)
        EnemyStatusEngine.thread = nil
    end
    if EnemyStatusEngine.gui then
        EnemyStatusEngine.gui:Destroy()
        EnemyStatusEngine.gui = nil
    end
    for _, bb in pairs(EnemyStatusEngine.billboards) do
        if bb and bb.Parent then bb:Destroy() end
    end
    table.clear(EnemyStatusEngine.billboards)
end

EnemyStatusEngine.start()
_G.EnemyStatusEngine = EnemyStatusEngine
shared.EnemyStatusEngine = EnemyStatusEngine
