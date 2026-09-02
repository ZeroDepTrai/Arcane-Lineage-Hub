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
local genv = (getgenv and getgenv()) or _G
local now = os.clock()
if genv._ArcaneHubTeleportQueuedExec and (now - genv._ArcaneHubTeleportQueuedExec < 5) then
    return
end
genv._ArcaneHubTeleportQueuedExec = now

task.spawn(function()
    local startWait = os.clock()
    if not game:IsLoaded() then
        pcall(function() game.Loaded:Wait() end)
    end
    while not game:IsLoaded() and (os.clock() - startWait < 15) do
        task.wait(0.2)
    end

    local players = game:GetService("Players")
    local playerWait = os.clock()
    while not players.LocalPlayer and (os.clock() - playerWait < 15) do
        task.wait(0.2)
    end

    task.wait(1.5)

    if genv._ArcaneHubRunning or (shared and shared.ArcaneHub) then
        return
    end

    local executed = false

    -- 1. Ưu tiên nạp từ local script của executor
    local fileCandidates = {
        "Arcane_Hub.lua",
        "Arcane_Hub.luau",
        "scripts/Arcane_Hub.lua",
        "scripts/Arcane_Hub.luau"
    }

    for _, path in ipairs(fileCandidates) do
        if not executed and loadfile then
            local ok, fn = pcall(loadfile, path)
            if ok and type(fn) == "function" then
                local runOk, err = pcall(fn)
                if runOk then
                    executed = true
                    break
                end
            end
        end
        if not executed and readfile then
            local ok, src = pcall(readfile, path)
            if ok and type(src) == "string" and #src > 100 then
                local loadOk, fn = pcall(loadstring, src)
                if loadOk and type(fn) == "function" then
                    local runOk, err = pcall(fn)
                    if runOk then
                        executed = true
                        break
                    end
                end
            end
        end
    end

    -- 2. Fallback tải trực tiếp từ GitHub / Gist
    if not executed then
        local remoteUrls = {
            "https://raw.githubusercontent.com/ZeroDepTrai/Arcane-Lineage-Hub/main/Arcane_Hub.lua",
            "https://gist.githubusercontent.com/ZeroDepTrai/c81661682d9297b3f8130a53bc900df8/raw/Arcane_Hub.lua"
        }
        for _, url in ipairs(remoteUrls) do
            local ok, code = pcall(function() return game:HttpGet(url) end)
            if ok and type(code) == "string" and #code > 100 then
                local loadOk, fn = pcall(loadstring, code)
                if loadOk and type(fn) == "function" then
                    local runOk, err = pcall(fn)
                    if runOk then
                        executed = true
                        break
                    end
                end
            end
        end
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
-- TẢI LINORIA GUI LIBRARY + THEME & SAVE MANAGERS
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
    warn("[ArcaneHub]  Không thể tải LinoriaLib từ GitHub! Vui lòng thử lại sau vài giây.")
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
    print("[ZeroLib] 🧹 Đang dọn dẹp và Unload toàn bộ GUI...")

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
    print("[ZeroLib] ✨ Đã Unload hoàn tất!")
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

    -- Popover Click-Outside Listener
    local clickConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if ZeroLib.ActivePopover and ZeroLib.ActivePopover.Close then
                local pos = input.Position
                local popInst = ZeroLib.ActivePopover.Instance
                if popInst and popInst.Parent then
                    local absPos = popInst.AbsolutePosition
                    local absSize = popInst.AbsoluteSize
                    local inBounds = (pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y)
                    if not inBounds and not ZeroLib.ActivePopover.IgnoreClick then
                        ZeroLib.ActivePopover.Close()
                    end
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
                        if os.clock() - self.LastCloseTime < 0.15 then return end

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
                            Close = function() DropObj:ToggleMenu(false) end
                        }
                    else
                        self.IsOpen = false
                        self.LastCloseTime = os.clock()

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
                    if DropObj.IsOpen then
                        DropObj:ToggleMenu(false)
                    else
                        DropObj:ToggleMenu(true)
                    end
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
-- CONFIG SYSTEM
-- =============================================================================
local ConfigManager = { Folder = "arcane_configs" }

function ConfigManager:Init()
    if makefolder and not isfolder(self.Folder) then makefolder(self.Folder) end
end

function ConfigManager:Save(name)
    self:Init()
    local data = { Toggles = {}, Options = {} }

    for k, v in pairs(ZeroLib.Toggles) do
        data.Toggles[k] = v.Value
    end

    for k, v in pairs(ZeroLib.Options) do
        if v.Type == "Slider" or v.Type == "Input" or v.Type == "Dropdown" then
            data.Options[k] = v.Value
        elseif v.Type == "Keybind" then
            data.Options[k] = v.Value.Name
        elseif v.Type == "ColorPicker" then
            data.Options[k] = v.Value:ToHex()
        end
    end

    local json = HttpService:JSONEncode(data)
    if writefile then
        writefile(self.Folder .. "/" .. name .. ".json", json)
        ZeroLib:Notify({ Title = "Config Saved", Content = "Đã lưu config: " .. name, Type = "Success" })
    end
end

function ConfigManager:Load(name)
    self:Init()
    local path = self.Folder .. "/" .. name .. ".json"
    if readfile and isfile and isfile(path) then
        local json = readfile(path)
        local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
        if ok and data then
            if data.Toggles then
                for k, v in pairs(data.Toggles) do
                    if ZeroLib.Toggles[k] then ZeroLib.Toggles[k]:SetValue(v) end
                end
            end
            if data.Options then
                for k, v in pairs(data.Options) do
                    if ZeroLib.Options[k] then
                        if ZeroLib.Options[k].Type == "Keybind" then
                            local key = Enum.KeyCode[v] or Enum.KeyCode.Unknown
                            ZeroLib.Options[k]:SetValue(key)
                        elseif ZeroLib.Options[k].Type == "ColorPicker" then
                            local col = Color3.fromHex(v)
                            if col then ZeroLib.Options[k]:SetValue(col) end
                        else
                            ZeroLib.Options[k]:SetValue(v)
                        end
                    end
                end
            end
            ZeroLib:Notify({ Title = "Config Loaded", Content = "Đã nạp config: " .. name, Type = "Success" })
        end
    else
        ZeroLib:Notify({ Title = "Config Error", Content = "Không tìm thấy file config: " .. name, Type = "Error" })
    end
end

function ConfigManager:GetConfigs()
    self:Init()
    local list = {}
    if listfiles then
        for _, p in ipairs(listfiles(self.Folder)) do
            local fName = p:match("([^/\\\\]+)%.json$")
            if fName then table.insert(list, fName) end
        end
    end
    return #list > 0 and list or {"default"}
end

ZeroLib.ConfigManager = ConfigManager

return ZeroLib

    return ZeroLib
end)()

local Library = ZeroLib
local ThemeManager = nil
local SaveManager = nil

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
local YarthulGroup = Tabs.AutoFarm:AddRightGroupbox("Auto Boss: Yar'thul (Blazing Dragon)")

YarthulGroup:AddToggle("AutoFarmYarthul", {
    Text = "Enable Auto Farm & Retry Yar'thul",
    Default = false,
    Tooltip = "Tự động kiểm tra vị trí Spawn trong Instance -> Tween tới Cổng Boss để Begin Fight -> Tự động đánh theo chiến thuật chuẩn (Ưu tiên 1: Sense Expansion xen kẽ dứt khoát không Meditate -> Ưu tiên 2: Carnage khi E>=3 & Carnage đã hồi CD & không có Flame Pillar dứt khoát không Meditate -> Ưu tiên 3: Strike kèm Meditate Sub-Action để nạp Energy) -> Tự động nhặt đồ, Hook SetCore Callback tự động Accept vào Roll Pool (0ms) & Tự động quét toàn bộ Drop mới vào kho đồ -> Tự động Retry lặp lại vô tận",
    Callback = function(Value)
        if Value then
            AutoYarthul.start()
        else
            if not AutoYarthul.isRestoring then
                AutoYarthul.stop(true)
            end
        end
    end
})

YarthulGroup:AddLabel(" Strat: Sense (Alternating) > Carnage > Strike + Med")

YarthulGroup:AddToggle("YarthulMeditateSubAction", {
    Text = "Use Meditate Sub-Action on Strike",
    Default = false,
    Tooltip = "Tự động kích hoạt Sub-Action Meditate kèm sau đòn Strike để nạp nhanh Energy (Carnage và Sense Expansion được tung đòn dứt khoát KHÔNG kèm Meditate để tránh kết thúc lượt sớm hoặc trúng Flame Pillar)",
})

YarthulGroup:AddToggle("YarthulAutoLoot", {
    Text = "Auto Loot & Roll Pool (Direct Hook)",
    Default = false,
    Tooltip = "Tự động Hook SetCore Notification Callback để Accept tức thì vào Roll Pool khi rơi Artifact, hoàn toàn không chiếm chuột của người chơi",
})

YarthulGroup:AddSlider("YarthulTweenSpeed", {
    Text = "Flight Speed to Gate",
    Default = 220,
    Min = 120,
    Max = 350,
    Rounding = 0,
    Tooltip = "Tốc độ bay Sky-Tween tới cổng Mount Thul (mặc định 220 studs/s)",
})

YarthulGroup:AddButton({
    Text = "Tween to Mount Thul Door Now",
    Func = function()
        teleportToLocation(AutoYarthul.gatePosition)
    end
})

YarthulGroup:AddButton({
    Text = "Stop Auto Farm Yar'thul",
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
    Tooltip = "Tự động quét Menu -> Vào game -> Bay Sky-Tween -> Thu hoạch nguyên liệu -> Đổi Server",
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
    Tooltip = "Loại bỏ hoàn toàn toàn bộ Crylight giả trong khu vực Sa mạc (Vastic Grave) & Forgotten Sanctum",
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
    Tooltip = "Tự động kiểm tra Pickaxe -> Mua nếu thiếu -> Bay tới mỏ -> Tự đào khoáng",
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
    Tooltip = "Nếu trong túi/balo chưa có cuốc, sẽ tự động bay tới Caldera để mua cuốc (50 Gold)",
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
    Tooltip = "Thời gian nghỉ giữa mỗi lần vung cuốc đập mỏ quặng (mặc định 0.18s siêu nhanh)",
})

MineGroup:AddButton({
    Text = "Mine Ores Now",
    Func = function() Miner.runCycle() end,
})

LevelGroup:AddToggle("AutoFarmLevel", {
    Text = "Enable Auto Farm Level",
    Default = false,
    Tooltip = "Tự động tween tới bãi farm (dưới lòng đất với Lv 1-20) và tự động chiến đấu / giải QTE khi vào trận",
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
    Tooltip = "Chọn chế độ hoặc khu vực quái để farm an toàn dưới lòng đất (người chơi khác không thể nhìn thấy):\n• Auto (Detect Level 1 - 50): Tự động phát hiện cấp độ (Lv < 30 bay về bãi ngầm Caldera, Lv >= 30 bay về khối an toàn Desert)\n• Level 1 - 30 (Underground): Bãi ngầm an toàn Caldera\n• Level 30 - 50 (Desert Block): Bãi an toàn trong khối Desert\n• The Crossing: Quái tân thủ gần Caldera (Slime, Bandits, Goblins)\n• Deeproot Canopy: Quái rừng Westwood (Plants, Wolves, Spiders)\n• Waving Sands: Quái sa mạc (Desert Scorpions, Mummies, Bandits)\n• Withered Grove: Quái hắc ám / Cursed Undead\n• Mount Thul: Quái băng tuyết / Yeti / Golem",
})

LevelGroup:AddToggle("AutoMeditate", {
    Text = "Auto Meditate & Level Up (Auto Cap Detect)",
    Default = false,
    Tooltip = "Tự động phát hiện khi Essence dừng tăng (đạt Cap level) -> Tự động đi thiền mô phỏng phím M gặp Aretim để thăng cấp rồi trở về",
})

LevelGroup:AddToggle("DeeprootNightFailsafe", {
    Text = "Deeproot Night Safe Hover (Avoid Sentinel)",
    Default = false,
    Tooltip = "Khi farm tại Deeproot Forest / Westwood: Nếu trời tối (17:30 - 06:30), tự động bay lên tầng mây (Y: 1200) đứng đợi trời sáng để tránh gặp siêu quái Sentinel of Darkness.",
})

StatsGroup:AddToggle("AutoAllocateStats", {
    Text = "Enable Auto Stats Build",
    Default = false,
    Tooltip = "Tự động nâng điểm StatPoints theo mốc Target Stats và lưu cache theo tên nhân vật (+10 mỗi đợt)",
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
    Tooltip = "Tự động đổi server khi lụm xong hoặc khi server không có nguyên liệu",
})

HopGroup:AddDivider()

HopGroup:AddToggle("HuntCorruptServer", {
    Text = "Auto Hop Hunt Corrupt Server",
    Default = false,
    Tooltip = "Tự động đổi server liên tục cho đến khi tìm thấy Corrupted Server (Event Server)!",
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
    Tooltip = "Tự động dừng hop khi đã tìm thấy Corrupt Server",
})


HopGroup:AddButton({
    Text = "Check Current Server Event",
    Func = function()
        local isCorrupt, evName = checkIsCorruptServer()
        if isCorrupt then
            Library:Notify(string.format(" ĐANG LÀ CORRUPT SERVER: %s!", evName), 6)
            sendCorruptServerWebhook(evName)
        else
            Library:Notify(" Server hiện tại bình thường (Không có Event Corrupt).", 4)
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
local CombatGroup = Tabs.AutoQTE:AddLeftGroupbox("Auto Combat & Minigames QTE")
local FightGroup  = Tabs.AutoQTE:AddRightGroupbox("Auto Fight & Skill Priority")

CombatGroup:AddToggle("MasterQTE", {
    Text = "Enable Auto Combat QTE",
    Default = false,
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
    Default = {},
    Multi = true,
    Text = "Active QTE Minigames",
})

CombatGroup:AddToggle("PreferPerfectDodge", {
    Text = "Prefer Perfect Dodge (100% Invuln)",
    Default = false,
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
            Library:Notify(string.format(" Đã quét thấy %d chiêu thức!", #skills - 1), 3)
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
        Text = "Auto Meditate if Cannot Use Skill",
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
    Text = "Sub-Action (Same-Turn Action)",
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
local FlyGroup = Tabs.Movement:AddLeftGroupbox("Flight & NoClip")
local SpeedGroup = Tabs.Movement:AddRightGroupbox("Speed & Jump")

FlyGroup:AddToggle("Fly", {
    Text = "Enable Fly Hack",
    Default = false,
    Tooltip = "Bay tự do theo hướng Camera (W/A/S/D + Space / Shift)",
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
local PlayerESPGroup = Tabs.Visuals:AddLeftGroupbox("Player ESP & Trackers")
local NpcESPGroup = Tabs.Visuals:AddLeftGroupbox("NPC & Waypoint ESP")
local ESPGroup = Tabs.Visuals:AddLeftGroupbox("Ingredient & Ore ESP")
local FilterGroup = Tabs.Visuals:AddLeftGroupbox("Filters & Categories")

PlayerESPGroup:AddToggle("PlayerESP", {
    Text = "Enable Player ESP",
    Default = false,
    Tooltip = "Hiển thị tên người chơi, thanh máu, cấp độ và khoảng cách tới người chơi khác trong server",
})

PlayerESPGroup:AddSlider("PlayerESPMaxDist", {
    Text = "Max Player ESP Distance",
    Default = 3500,
    Min = 500,
    Max = 10000,
    Rounding = 0,
    Tooltip = "Khoảng cách quét tối đa để hiển thị người chơi",
})

NpcESPGroup:AddToggle("NPC_ESP", {
    Text = "Enable NPC & Trainers ESP",
    Default = false,
    Tooltip = "Hiển thị tất cả NPC làm nhiệm vụ, Thầy dạy Class, Bác sĩ và Thương nhân trong thế giới",
})

NpcESPGroup:AddSlider("NPC_ESPMaxDist", {
    Text = "Max NPC ESP Distance",
    Default = 2500,
    Min = 300,
    Max = 8000,
    Rounding = 0,
})

NpcESPGroup:AddToggle("Location_ESP", {
    Text = "Enable Waypoints & POI ESP",
    Default = false,
    Tooltip = "Hiển thị các địa danh trọng yếu: Caldera, Heavens Point Church, Sanctuary of Blades, Mount Thul...",
})

NpcESPGroup:AddSlider("Location_ESPMaxDist", {
    Text = "Max Location ESP Distance",
    Default = 6000,
    Min = 1000,
    Max = 15000,
    Rounding = 0,
})


-- =============================================================================
-- ENEMY SKILL PREDICTOR & COMBAT HUD ENGINE (QOL VISUAL SUITE)
-- =============================================================================
local EnemyPredictor = {
    running = false,
    thread = nil,
    gui = nil,
    billboards = {},
    skillsCache = {},
    npcCache = {},
    lastIndicatedSkill = nil,
    lastIndicatedTime = 0,
    currentDecidingEnemy = nil,
}

-- Khởi tạo Cache dữ liệu Kỹ năng và NPC từ ReplicatedStorage
local function initPredictorData()
    pcall(function()
        local skillsMod = ReplicatedStorage:FindFirstChild("Constants") and ReplicatedStorage.Constants:FindFirstChild("Skills")
        if skillsMod then
            local ok, data = pcall(require, skillsMod)
            if ok and type(data) == "table" then
                EnemyPredictor.skillsCache = data
            end
        end
    end)

    pcall(function()
        local npcFolder = ReplicatedStorage:FindFirstChild("NPCs")
        if npcFolder then
            for _, mod in ipairs(npcFolder:GetChildren()) do
                if mod:IsA("ModuleScript") then
                    local ok, data = pcall(require, mod)
                    if ok and type(data) == "table" then
                        EnemyPredictor.npcCache[mod.Name] = data
                    end
                end
            end
        end
    end)
end
initPredictorData()

-- Lắng nghe AttackIndicate và Deciding từ Server để bắt chiêu sớm nhất
pcall(function()
    local fightRemotes = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Fight")
    if fightRemotes then
        local atkInd = fightRemotes:FindFirstChild("AttackIndicate")
        if atkInd and atkInd:IsA("RemoteEvent") then
            atkInd.OnClientEvent:Connect(function(skillName)
                if not skillName then return end
                EnemyPredictor.lastIndicatedSkill = tostring(skillName)
                EnemyPredictor.lastIndicatedTime = os.clock()
                EnemyPredictor.currentDecidingEnemy = nil

                if Toggles.EnemyAttackPredictor and Toggles.EnemyAttackPredictor.Value then
                    local skInfo = EnemyPredictor.skillsCache[tostring(skillName)]
                    local aff = skInfo and skInfo.Affinity or "Unknown"
                    local dmg = skInfo and skInfo.Damage or "?"
                    local sType = skInfo and skInfo.Type or "Attack"

                    hubLog(string.format("[Predictor]  QUÁI TUNG CHIÊU: '%s' | Hệ: %s | Sát thương: %s | Loại: %s", tostring(skillName), aff, tostring(dmg), sType))

                    -- Cảnh báo âm thanh nếu là chiêu nguy hiểm
                    if Toggles.PredictorSoundAlert and Toggles.PredictorSoundAlert.Value then
                        local lowerS = tostring(skillName):lower()
                        if lowerS:find("pillar") or lowerS:find("inferno") or lowerS:find("armageddon") or lowerS:find("beam") or lowerS:find("eruption") or lowerS:find("crush") then
                            local sound = Instance.new("Sound")
                            sound.SoundId = "rbxassetid://6534948092" -- Warning beep
                            sound.Volume = 1.5
                            sound.Parent = game:GetService("SoundService")
                            sound:Play()
                            game:GetService("Debris"):AddItem(sound, 3)
                        end
                    end
                end
            end)
        end

        local deciding = fightRemotes:FindFirstChild("Deciding")
        if deciding and deciding:IsA("RemoteEvent") then
            deciding.OnClientEvent:Connect(function(enemyName)
                EnemyPredictor.currentDecidingEnemy = enemyName
            end)
        end
    end
end)

-- Tạo Giao diện HUD trên màn hình
local function createPredictorScreenHUD()
    if EnemyPredictor.gui then return EnemyPredictor.gui end

    local sg = Instance.new("ScreenGui")
    sg.Name = "ArcaneEnemyPredictorHUD"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 180)
    mainFrame.Position = UDim2.new(0.02, 0, 0.45, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = sg

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = mainFrame

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.fromRGB(155, 89, 182) -- Purple neon
    uiStroke.Thickness = 1.5
    uiStroke.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 26)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "ENEMY SKILL PREDICTOR"
    title.TextColor3 = Color3.fromRGB(240, 240, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    local contentLabel = Instance.new("TextLabel")
    contentLabel.Name = "Content"
    contentLabel.Size = UDim2.new(1, -20, 1, -38)
    contentLabel.Position = UDim2.new(0, 10, 0, 32)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Text = "Đang quét trận đấu..."
    contentLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextSize = 11
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextYAlignment = Enum.TextYAlignment.Top
    contentLabel.TextWrapped = true
    contentLabel.RichText = true
    contentLabel.Parent = mainFrame

    -- Hỗ trợ kéo thả HUD
    local dragging, dragInput, dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
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
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    pcall(function()
        local coreGui = game:GetService("CoreGui")
        sg.Parent = coreGui
    end)
    if not sg.Parent then
        sg.Parent = PlayerGui
    end

    EnemyPredictor.gui = sg
    return sg
end

-- Tính toán dự đoán chiêu thức cho 1 quái vật
local function predictEnemySkills(enemyModel)
    if not enemyModel or not enemyModel.Parent then return nil end

    local enemyName = enemyModel.Name
    local cleanName = enemyName:gsub("%s*%(.*%)", ""):gsub("%d+$", ""):gsub("^%s*(.-)%s*$", "%1")

    -- 1. Lấy thông tin máu
    local hum = enemyModel:FindFirstChildOfClass("Humanoid")
    local curHp = hum and math.floor(hum.Health) or 0
    local maxHp = hum and math.floor(hum.MaxHealth) or 100

    -- 2. Lấy thông tin Năng lượng (Energy)
    local energyVal = enemyModel:FindFirstChild("Status") and enemyModel.Status:FindFirstChild("Energy")
    local curEnergy = energyVal and energyVal.Value or 0

    -- 3. Lấy chiêu vừa dùng
    local lastAttackVal = enemyModel:FindFirstChild("Effects") and enemyModel.Effects:FindFirstChild("LastUsedAttack")
    local lastAttack = lastAttackVal and lastAttackVal.Value or "Chưa rõ"

    -- 4. Tìm dữ liệu NPC gốc
    local npcData = EnemyPredictor.npcCache[cleanName] or EnemyPredictor.npcCache[enemyName]
    local maxEnergy = npcData and npcData.MaxEnergy or 6
    local attackPool = npcData and npcData.Attacks or {}

    local damageSkills = attackPool.Damage or {}
    local specialSkills = attackPool.Special or {}
    local noEnergySkills = attackPool.NoEnergy or {}

    -- 5. Thuật toán dự đoán dựa trên Energy và Cooldown
    local predictedList = {}
    
    if curEnergy == 0 then
        -- Chắc chắn chỉ có thể dùng NoEnergy skills hoặc Strike
        if #noEnergySkills > 0 then
            for _, sk in ipairs(noEnergySkills) do
                table.insert(predictedList, { name = sk, chance = "Cao (100% khi hết Energy)", danger = false })
            end
        else
            table.insert(predictedList, { name = "Strike (Đánh thường)", chance = "Cao (100%)", danger = false })
        end
    else
        -- Có Energy: Lọc các chiêu có Cost <= curEnergy
        for _, sk in ipairs(damageSkills) do
            local skInfo = EnemyPredictor.skillsCache[sk]
            local cost = skInfo and skInfo.Cost or 1
            if cost <= curEnergy then
                local isRecent = (lastAttack == sk)
                local chanceStr = isRecent and "Trung bình (Vừa dùng)" or "Rất Cao"
                local isDanger = (sk:lower():find("pillar") or sk:lower():find("beam") or sk:lower():find("hellfire") or sk:lower():find("crush"))
                table.insert(predictedList, { name = sk, cost = cost, chance = chanceStr, danger = isDanger })
            end
        end

        for _, sk in ipairs(specialSkills) do
            local skInfo = EnemyPredictor.skillsCache[sk]
            local cost = skInfo and skInfo.Cost or 2
            if cost <= curEnergy then
                local isRecent = (lastAttack == sk)
                local chanceStr = isRecent and "Thấp (Cooldown)" or "Cao (Special)"
                table.insert(predictedList, { name = sk, cost = cost, chance = chanceStr, danger = true })
            end
        end

        if #predictedList == 0 then
            table.insert(predictedList, { name = "Strike (Đánh thường)", chance = "100%", danger = false })
        end
    end

    return {
        model = enemyModel,
        name = enemyName,
        curHp = curHp,
        maxHp = maxHp,
        curEnergy = curEnergy,
        maxEnergy = maxEnergy,
        lastAttack = lastAttack,
        predictions = predictedList
    }
end

-- Vòng lặp cập nhật Predictor
function EnemyPredictor.start()
    if EnemyPredictor.running then return end
    EnemyPredictor.running = true
    createPredictorScreenHUD()

    EnemyPredictor.thread = task.spawn(function()
        while EnemyPredictor.running do
            local inCombat = isInCombat()
            local hud = EnemyPredictor.gui and EnemyPredictor.gui:FindFirstChild("MainFrame")

            if inCombat and Toggles.EnemyAttackPredictor and Toggles.EnemyAttackPredictor.Value then
                if hud then hud.Visible = true end

                -- Lấy danh sách quái trong trận
                local activeEnemies = {}
                local living = workspace:FindFirstChild("Living")
                local char = LocalPlayer.Character
                local myFightVal = char and char:FindFirstChild("FightInProgress")
                local myFightId = myFightVal and myFightVal.Value

                if living then
                    for _, m in ipairs(living:GetChildren()) do
                        if m ~= char and m:FindFirstChildOfClass("Humanoid") then
                            local fVal = m:FindFirstChild("FightInProgress")
                            if not myFightId or not fVal or fVal.Value == myFightId then
                                local hum = m:FindFirstChildOfClass("Humanoid")
                                if hum and hum.Health > 0 and not Players:GetPlayerFromCharacter(m) then
                                    table.insert(activeEnemies, m)
                                end
                            end
                        end
                    end
                end

                -- Xây dựng văn bản hiển thị HUD
                local hudLines = {}

                -- Hiển thị cảnh báo thời gian thực nếu vừa có AttackIndicate (< 2.5s)
                local now = os.clock()
                if EnemyPredictor.lastIndicatedSkill and (now - EnemyPredictor.lastIndicatedTime < 2.5) then
                    local skName = EnemyPredictor.lastIndicatedSkill
                    local skInfo = EnemyPredictor.skillsCache[skName]
                    local aff = skInfo and skInfo.Affinity or "Fire/Physical"
                    table.insert(hudLines, string.format(" <b><font color='#FF5555'>ĐANG TUNG CHIÊU: %s</font></b> <font color='#F1C40F'>[%s]</font>", skName, aff))
                    table.insert(hudLines, "────────────────────────────")
                elseif EnemyPredictor.currentDecidingEnemy then
                    table.insert(hudLines, string.format("⏳ <i><font color='#F39C12'>%s đang suy nghĩ lượt...</font></i>", EnemyPredictor.currentDecidingEnemy))
                    table.insert(hudLines, "────────────────────────────")
                end

                for idx, enemyModel in ipairs(activeEnemies) do
                    local pData = predictEnemySkills(enemyModel)
                    if pData then
                        local hpPercent = math.clamp(pData.curHp / math.max(1, pData.maxHp), 0, 1)
                        local hpColor = hpPercent > 0.5 and "#2ECC71" or (hpPercent > 0.25 and "#F39C12" or "#E74C3C")
                        local energyStr = string.format(" Energy: <font color='#3498DB'><b>%d / %d</b></font>", pData.curEnergy, pData.maxEnergy)

                        table.insert(hudLines, string.format(" <b>%s</b> (<font color='%s'>%d/%d HP</font>) | %s", pData.name, hpColor, pData.curHp, pData.maxHp, energyStr))
                        table.insert(hudLines, string.format("  • <i>Chiêu vừa ra:</i> <font color='#BDC3C7'>%s</font>", pData.lastAttack))
                        
                        local predStrList = {}
                        for _, pr in ipairs(pData.predictions) do
                            local color = pr.danger and "#FF7675" or "#55EFC4"
                            table.insert(predStrList, string.format("<font color='%s'>%s</font>", color, pr.name))
                        end
                        table.insert(hudLines, "  •  <b>Dự đoán:</b> " .. table.concat(predStrList, " | "))
                        if idx < #activeEnemies then
                            table.insert(hudLines, "")
                        end

                        -- Cập nhật World Billboard trên đầu quái
                        if Toggles.PredictorWorldESP and Toggles.PredictorWorldESP.Value then
                            local head = enemyModel:FindFirstChild("Head") or enemyModel:FindFirstChild("HumanoidRootPart")
                            if head then
                                local bb = EnemyPredictor.billboards[enemyModel]
                                if not bb or not bb.Parent then
                                    bb = Instance.new("BillboardGui")
                                    bb.Name = "EnemyPredictorBB"
                                    bb.Size = UDim2.new(0, 160, 0, 45)
                                    bb.StudsOffset = Vector3.new(0, 3.2, 0)
                                    bb.AlwaysOnTop = true
                                    bb.Adornee = head
                                    
                                    local bbLabel = Instance.new("TextLabel")
                                    bbLabel.Name = "Label"
                                    bbLabel.Size = UDim2.new(1, 0, 1, 0)
                                    bbLabel.BackgroundTransparency = 0.4
                                    bbLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
                                    bbLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                                    bbLabel.Font = Enum.Font.GothamBold
                                    bbLabel.TextSize = 10
                                    bbLabel.RichText = true
                                    bbLabel.Parent = bb

                                    local crn = Instance.new("UICorner")
                                    crn.CornerRadius = UDim.new(0, 4)
                                    crn.Parent = bbLabel

                                    bb.Parent = head
                                    EnemyPredictor.billboards[enemyModel] = bb
                                end

                                if bb and bb:FindFirstChild("Label") then
                                    local topPred = pData.predictions[1] and pData.predictions[1].name or "Strike"
                                    bb.Label.Text = string.format(" <b>%d/%d Energy</b>\n <b>Next: %s</b>", pData.curEnergy, pData.maxEnergy, topPred)
                                end
                            end
                        end
                    end
                end

                if #activeEnemies == 0 then
                    table.insert(hudLines, "<i>Đang tìm mục tiêu quái trong trận...</i>")
                end

                local contentLabel = hud and hud:FindFirstChild("Content")
                if contentLabel then
                    contentLabel.Text = table.concat(hudLines, "\n")
                end
            else
                if hud then hud.Visible = false end
                -- Ẩn hoặc dọn dẹp billboards
                for model, bb in pairs(EnemyPredictor.billboards) do
                    if bb and bb.Parent then pcall(function() bb:Destroy() end) end
                end
                EnemyPredictor.billboards = {}
            end

            task.wait(0.25)
        end
    end)
end

function EnemyPredictor.stop()
    EnemyPredictor.running = false
    if EnemyPredictor.thread then
        task.cancel(EnemyPredictor.thread)
        EnemyPredictor.thread = nil
    end
    if EnemyPredictor.gui then
        pcall(function() EnemyPredictor.gui:Destroy() end)
        EnemyPredictor.gui = nil
    end
    for model, bb in pairs(EnemyPredictor.billboards) do
        if bb and bb.Parent then pcall(function() bb:Destroy() end) end
    end
    EnemyPredictor.billboards = {}
end

local QOLGroup = Tabs.Visuals:AddRightGroupbox("Quality of Life (QOL)")
local FPSGroup = Tabs.Visuals:AddRightGroupbox("FPS Booster")
local OptGroup = Tabs.Visuals:AddRightGroupbox("Optimization & RAM")

QOLGroup:AddToggle("EnemyAttackPredictor", {
    Text = "Enemy Skill Predictor & Combat HUD",
    Default = false,
    Tooltip = "Hiển thị bảng phân tích dự đoán chiêu thức tiếp theo của quái, thanh Energy thời gian thực và bắt chiêu ngay khi quái vung đòn",
})

Toggles.EnemyAttackPredictor:OnChanged(function()
    if Toggles.EnemyAttackPredictor.Value then
        EnemyPredictor.start()
    else
        EnemyPredictor.stop()
    end
end)

QOLGroup:AddToggle("PredictorWorldESP", {
    Text = "Show Predictor On Enemy Heads (ESP)",
    Default = false,
    Tooltip = "Hiển thị thanh Energy & Chiêu dự đoán trực tiếp dạng Billboard trên đầu quái vật",
})

QOLGroup:AddToggle("PredictorSoundAlert", {
    Text = "Sound Alert On Danger Skills",
    Default = false,
    Tooltip = "Phát chuông cảnh báo âm thanh khi boss/quái bắt đầu tung chiêu nguy hiểm (Magma Pillar, Inferno, v.v.)",
})

QOLGroup:AddDivider()

QOLGroup:AddToggle("BypassNoPainHP", {
    Text = "Reveal 'I Feel No Pain' HP & Mana",
    Default = false,
    Tooltip = "Reveals exact numerical Health and Mana/Energy bars when obscured by Trial I Feel No Pain",
})

QOLGroup:AddToggle("RevealUnidentified", {
    Text = "Reveal Unidentified Items",
    Default = false,
    Tooltip = "Reveals the true real names and stats of all unidentified equipment and items in your inventory",
})

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

-- 1. XỬ LÝ ẨN CÂY CỐI & THẢM THỰC VẬT (REMOVE TREES / FOLIAGE / GRASS)
local function applyPartTreeRemoval(obj, hideTrees)
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

local function applyTreeRemoval()
    task.spawn(function()
        pcall(function()
            local hideTrees = Toggles.RemoveTrees and Toggles.RemoveTrees.Value or false
            OptimizationState.removeTreesActive = hideTrees

            -- Quét thư mục rác MapGarbage & toàn bộ workspace
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
                applyPartTreeRemoval(obj, hideTrees)
            end

            if hideTrees then
                if not OptimizationState.removeTreesConnection then
                    OptimizationState.removeTreesConnection = workspace.DescendantAdded:Connect(function(child)
                        if OptimizationState.removeTreesActive then
                            task.defer(function()
                                applyPartTreeRemoval(child, true)
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

-- 2. XỬ LÝ ĐỒ HỌA MƯỢT & TẮT PARTICLE (LOW GRAPHICS)
local function applyPartLowGraphics(p, isLow)
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

local function applyLowGraphics()
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
                applyPartLowGraphics(p, isLow)
            end

            if isLow then
                if not OptimizationState.lowGraphicsConnection then
                    OptimizationState.lowGraphicsConnection = workspace.DescendantAdded:Connect(function(child)
                        if OptimizationState.lowGraphicsActive then
                            task.defer(function()
                                applyPartLowGraphics(child, true)
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

-- 3. XỬ LÝ MASTER FPS BOOST (XÓA SƯƠNG MÙ / HIỆU ỨNG ÁNH SÁNG)
local function applyFPSBoost()
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

-- 4. XỬ LÝ EXTREME FPS BOOSTER (POTATO MODE TOÀN DIỆN - KHÔNG TẮT 3D RENDER)
local function applyExtremePart(p)
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

local function applyExtremeFPSBoost()
    task.spawn(function()
        pcall(function()
            local isExtreme = (Toggles.FPSBoost and Toggles.FPSBoost.Value) or (Toggles.ExtremeFPSBoost and Toggles.ExtremeFPSBoost.Value) or false
            OptimizationState.extremeActive = isExtreme

            if isExtreme then
                -- A. Cấu hình Engine Renderer & GPU Settings thấp nhất tuyệt đối
                pcall(function() settings().Rendering.QualityLevel = 1 end)
                pcall(function() sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility) end)

                -- B. Triệt tiêu toàn bộ hiệu ứng ánh sáng / sương mù / bóng đổ
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

                -- C. Triệt tiêu toàn bộ thảm thực vật & cây cối
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

                -- D. Triệt tiêu Terrain Water & Decorations
                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    terrain.Decoration = false
                    terrain.WaterWaveSize = 0
                    terrain.WaterWaveSpeed = 0
                    terrain.WaterReflectance = 0
                    terrain.WaterTransparency = 0
                end

                -- E. Quét toàn bộ vật thể trong Workspace
                for _, obj in ipairs(workspace:GetDescendants()) do
                    applyExtremePart(obj)
                    applyPartTreeRemoval(obj, true)
                end

                -- F. Lắng nghe vật thể mới sinh ra và lập tức ép về dạng Potato
                if not OptimizationState.extremeConnection then
                    OptimizationState.extremeConnection = workspace.DescendantAdded:Connect(function(child)
                        if OptimizationState.extremeActive then
                            task.defer(function()
                                applyExtremePart(child)
                                applyPartTreeRemoval(child, true)
                            end)
                        end
                    end)
                    registerConnection(OptimizationState.extremeConnection)
                end

                -- G. Dọn dẹp bộ nhớ RAM
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

                applyFPSBoost()
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

FPSGroup:AddToggle("FPSBoost", {
    Text = "🔥 FPS Boost (Potato Mode)",
    Default = false,
    Tooltip = " Tối đa hóa FPS kịch khung: Ép Smooth Plastic, xóa Decal/Texture/Light, ẩn cây cối thảm thực vật, tắt Particles/Shadows/Fog (KHÔNG tắt 3D Render).",
    Callback = function(val)
        applyExtremeFPSBoost()
    end,
})

FPSGroup:AddSlider("FPSCap", {
    Text = "Max FPS Cap",
    Default = 360,
    Min = 30,
    Max = 360,
    Rounding = 0,
    Callback = function(val)
        if setfpscap then
            setfpscap(val)
        end
    end
})

OptGroup:AddToggle("AntiAFK", {
    Text = "Built-in Anti-AFK (20m Kick Bypass)",
    Default = false,
    Tooltip = "Tự động gửi tín hiệu chống ngắt kết nối khi treo máy AFK 24/7",
})

OptGroup:AddButton(" Instant Clean RAM / Garbage", function()
    collectgarbage("collect")
    Library:Notify("RAM / Garbage Collection executed!", 3)
end)

OptGroup:AddButton(" Remove All Fog Permanently", function()
    Lighting.FogEnd = 9e9
    Lighting.FogStart = 9e9
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then atmo.Density = 0 end
    Library:Notify("All Fog & Haze removed!", 3)
end)

-- -----------------------------------------------------------------------------
-- TAB 6: SETTINGS / CONFIG
-- -----------------------------------------------------------------------------

-- =============================================================================

-- -----------------------------------------------------------------------------
-- TAB: DISCORD WEBHOOK INTEGRATION & NOTIFICATIONS
-- -----------------------------------------------------------------------------
local WebhookConfigGroup = Tabs.Webhook:AddLeftGroupbox("Webhook Configuration")
local WebhookActionsGroup = Tabs.Webhook:AddRightGroupbox("Webhook Testing & Actions")

WebhookConfigGroup:AddInput("DiscordWebhook", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Primary Discord Webhook URL",
    Tooltip = "Nhập URL Webhook Discord để nhận thông báo tự động khi tìm thấy Server Corrupt, Boss Drops hoặc nhặt nguyên liệu",
    Placeholder = "https://discord.com/api/webhooks/...",
})

WebhookConfigGroup:AddInput("YarthulWebhook", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Yar'thul Boss Webhook (Optional)",
    Tooltip = "Link Webhook riêng cho Boss Yar'thul (để trống sẽ dùng Primary Webhook URL)",
    Placeholder = "https://discord.com/api/webhooks/...",
})

WebhookConfigGroup:AddDivider()

WebhookConfigGroup:AddToggle("YarthulSendWebhook", {
    Text = "Enable Yar'thul Boss Drop Alerts",
    Default = false,
    Tooltip = "Tự động gửi thông báo Discord Embed chi tiết danh sách tất cả vật phẩm rơi (Loot Drops) nhận được vào kho đồ sau khi diệt Boss Yar'thul",
})

WebhookConfigGroup:AddToggle("NotifyOnHarvest", {
    Text = "Send Alerts on Ingredient/Ore Harvest",
    Default = false,
    Tooltip = "Tự động gửi thông báo Discord mỗi khi nhặt được nguyên liệu / khoáng sản quý",
})

WebhookConfigGroup:AddToggle("CorruptPingRole", {
    Text = "Webhook Ping @everyone on Corrupt Server",
    Default = false,
    Tooltip = "Gắn thẻ @everyone khi gửi thông báo tìm thấy Corrupt Server qua Discord",
})

WebhookActionsGroup:AddButton({
    Text = "Send Test General Webhook",
    Tooltip = "Bấm để gửi 1 tin nhắn kiểm tra tới Webhook Discord của bạn",
    Func = function()
        local wh = Options.DiscordWebhook and Options.DiscordWebhook.Value
        if not wh or wh == "" then
            wh = Options.YarthulWebhook and Options.YarthulWebhook.Value
        end
        if not wh or wh == "" then
            Library:Notify({
                Title = "Webhook Error",
                Content = "Vui lòng nhập URL Discord Webhook trước khi kiểm tra!",
                Type = "Error"
            })
            return
        end
        sendGeneralWebhook(
            "Test Webhook Notification",
            "Webhook Discord dang hoat dong hoan hao tren Arcane Lineage Hub!",
            65280,
            {
                { name = "Nguoi choi", value = LocalPlayer.Name, inline = true },
                { name = "User ID", value = tostring(LocalPlayer.UserId), inline = true },
                { name = "Trang thai", value = "San sang hoat dong", inline = false }
            }
        )
        Library:Notify({
            Title = "Webhook Sent",
            Content = "Da gui thong bao Test Webhook thanh cong!",
            Type = "Success"
        })
    end,
})

WebhookActionsGroup:AddButton({
    Text = "Send Test Yar'thul Boss Webhook",
    Tooltip = "Gửi thử 1 thông báo Discord Webhook mô phỏng nhận Drop Boss Yar'thul",
    Func = function()
        local wh = Options.YarthulWebhook and Options.YarthulWebhook.Value
        if not wh or wh == "" then
            wh = Options.DiscordWebhook and Options.DiscordWebhook.Value
        end
        if not wh or wh == "" then
            Library:Notify({
                Title = "Webhook Error",
                Content = "Vui lòng nhập URL Discord Webhook trước!",
                Type = "Error"
            })
            return
        end
        AutoYarthul.sendWebhook("Test")
        Library:Notify({
            Title = "Webhook Sent",
            Content = "Da gui thong bao Test Yar'thul Drop!",
            Type = "Success"
        })
    end,
})

WebhookActionsGroup:AddButton({
    Text = "Send Test Corrupt Server Webhook",
    Tooltip = "Gửi thử 1 thông báo Discord Webhook mô phỏng tìm thấy Corrupt Server",
    Func = function()
        local evName = "Sandstorm (Desert)"
        if Options.CorruptEvent and Options.CorruptEvent.Value then
            evName = Options.CorruptEvent.Value
        end
        sendCorruptServerWebhook(evName)
        Library:Notify({
            Title = "Webhook Sent",
            Content = "Da gui thong bao Test Corrupt Server!",
            Type = "Success"
        })
    end,
})

-- SETTINGS & CONFIGURATION ENGINE (ZEROLIB v2.7)
-- =============================================================================
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
            Content = "Đã áp dụng giao diện: " .. themeName,
            Type = "Success"
        })
    end
})

local MenuGroup = Tabs.Settings:AddRightGroupbox("Menu Settings")

local function unloadHub()
    hubLog("[ArcaneHub]  Đang tiến hành Unload toàn bộ script và giải phóng tài nguyên...")
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
                Library:Notify({ Title = "Auto Load", Content = "Đã nạp Teleport Queue!", Type = "Success" })
            else
                Library:Notify({ Title = "Warning", Content = "Executor không hỗ trợ queue_on_teleport!", Type = "Warning" })
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

local ConfigGroup = Tabs.Settings:AddLeftGroupbox("Configuration Manager")

local configDropdown = ConfigGroup:AddDropdown("ConfigList", {
    Text = "Select Saved Config",
    Values = ZeroLib.ConfigManager:GetConfigs(),
    Default = 1,
    Callback = function(selectedName)
        if ZeroLib.Options.ConfigName then
            ZeroLib.Options.ConfigName:SetValue(selectedName)
        end
    end
})

ConfigGroup:AddInput("ConfigName", {
    Text = "Config Profile Name",
    Placeholder = "my_profile",
    Default = "default",
    Callback = function(val) end
})

ConfigGroup:AddButton({
    Text = "Save Configuration",
    Func = function()
        local name = ZeroLib.Options.ConfigName and ZeroLib.Options.ConfigName.Value or "default"
        if name == "" then name = "default" end
        ZeroLib.ConfigManager:Save(name)
        configDropdown:SetValues(ZeroLib.ConfigManager:GetConfigs())
    end
})

ConfigGroup:AddButton({
    Text = "Load Configuration",
    Func = function()
        local name = ZeroLib.Options.ConfigName and ZeroLib.Options.ConfigName.Value or "default"
        ZeroLib.ConfigManager:Load(name)
    end
})

ConfigGroup:AddButton({
    Text = "Refresh Configs List",
    Func = function()
        local fresh = ZeroLib.ConfigManager:GetConfigs()
        configDropdown:SetValues(fresh)
        ZeroLib:Notify({ Title = "Refreshed", Content = "Đã cập nhật danh sách configs (" .. #fresh .. " profiles)", Type = "Info" })
    end
})

local AntiAFK = {
    initialized = false,
    connections = {},
}

local function initAntiAFK()
    if AntiAFK.initialized then return end
    AntiAFK.initialized = true

    -- Lớp 1: Gỡ bỏ / Vô hiệu hóa kết nối Idled mặc định của Roblox CoreGui (nếu executor hỗ trợ getconnections)
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

    -- Lớp 2: Lắng nghe sự kiện LocalPlayer.Idled và gửi tương tác ảo mô phỏng người dùng
    local idledConn = registerConnection(LocalPlayer.Idled:Connect(function()
        if HubState.running and Toggles.AntiAFK and Toggles.AntiAFK.Value then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end))
    table.insert(AntiAFK.connections, idledConn)

    -- Lớp 3: Luồng nhịp tim (Heartbeat pulse) định kỳ mỗi 60 giây chủ động reset bộ đếm AFK
    task.spawn(function()
        while HubState.running do
            task.wait(60)
            if HubState.running and Toggles.AntiAFK and Toggles.AntiAFK.Value then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    if vim then
                        -- Safe virtual user click
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
                        task.wait(0.05)
                        -- Heartbeat pulse complete
                    end
                end)
            end
        end
    end)

    hubLog("[AntiAFK] Built-in Anti-AFK Engine Initialized Successfully!")
end

initAntiAFK()

-- =============================================================================
-- QOL: REAL HP/MANA REVEAL & UNIDENTIFIED ITEMS REVEALER
-- =============================================================================
task.spawn(function()
    local blueEnergyColor = Color3.fromRGB(106, 192, 242)
    local RS = game:GetService("ReplicatedStorage")
    local ItemModifiers = nil
    pcall(function() ItemModifiers = require(RS.Libraries.ItemModifiers) end)

    while HubState.running do
        task.wait(0.25)
        if not HubState.running then break end

        -- 1. GIẢI MÃ VÀ HIỆN TÊN THẬT + FULL STATS KHI GIÁM ĐỊNH (UNIDENTIFIED REVEALER WITH STATS)
        if Toggles.RevealUnidentified and Toggles.RevealUnidentified.Value then
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

                    local ItemRegistry = nil
                    pcall(function() ItemRegistry = require(RS.ItemRegistry) end)

                    for _, btn in ipairs(inv:GetDescendants()) do
                        if btn:IsA("TextButton") and itemDict and itemDict[btn.Name] then
                            local itemObj = itemDict[btn.Name]
                            local itemData = itemObj and (itemObj.ItemData or itemObj)
                            if itemData and itemData.Config and itemData.Config.Unidentified then
                                local realName = itemData.Name or itemData.Tool
                                if realName then
                                    local statList = {}
                                    local cfg = itemData.Config

                                    if cfg.Enchant and tostring(cfg.Enchant) ~= "" then
                                        table.insert(statList, "Enchant: " .. tostring(cfg.Enchant))
                                    end
                                    if cfg.Tier then
                                        table.insert(statList, "T" .. tostring(cfg.Tier))
                                    end

                                    -- Quét chỉ số rolled stats từ Config
                                    for k, v in pairs(cfg) do
                                        if type(v) == "number" and v ~= 0 and k ~= "Unidentified" and k ~= "Tier" and k ~= "Cost" and k ~= "ID" then
                                            table.insert(statList, string.format("+%d %s", v, tostring(k):sub(1, 3)))
                                        elseif type(v) == "table" and tostring(k):lower():find("stat") then
                                            for sk, sv in pairs(v) do
                                                if type(sv) == "number" and sv ~= 0 then
                                                    table.insert(statList, string.format("+%d %s", sv, tostring(sk):sub(1, 3)))
                                                end
                                            end
                                        end
                                    end

                                    -- Quét chỉ số BaseStats từ ItemRegistry nếu có
                                    if ItemRegistry and ItemRegistry.GetItem then
                                        local regData = ItemRegistry:GetItem(realName:gsub(" ", ""))
                                        if regData then
                                            if regData.Stats and type(regData.Stats) == "table" then
                                                for sk, sv in pairs(regData.Stats) do
                                                    if type(sv) == "number" and sv ~= 0 then
                                                        table.insert(statList, string.format("+%d %s", sv, tostring(sk):sub(1, 3)))
                                                    end
                                                end
                                            end
                                            if regData.Damage then table.insert(statList, string.format("%d Dmg", regData.Damage)) end
                                            if regData.Defense then table.insert(statList, string.format("%d Def", regData.Defense)) end
                                        end
                                    end

                                    local statsStr = #statList > 0 and (" [" .. table.concat(statList, ", ") .. "]") or ""
                                    btn.Text = realName .. statsStr
                                end
                            end
                        end
                    end

                    -- Giải mã luôn ToolTip khi di chuột vào món đồ chưa giám định
                    local tooltip = inv:FindFirstChild("ToolTip", true)
                    if tooltip and tooltip.Visible then
                        local textLbl = tooltip:FindFirstChildWhichIsA("TextLabel", true)
                        if textLbl and textLbl.Text:find("You have no idea what this does") then
                            textLbl.Text = "[Real Item & Stats Revealed by Arcane Hub]"
                        end
                    end

                    local advTooltip = inv:FindFirstChild("AdvancedTooltip", true)
                    if advTooltip and advTooltip.Visible then
                        local descLbl = advTooltip:FindFirstChild("Desc")
                        if descLbl and descLbl:IsA("TextLabel") and descLbl.Text:find("You have no idea what this does") then
                            local nameLbl = advTooltip:FindFirstChild("ItemName")
                            local realItemName = nameLbl and nameLbl.Text:gsub(" ", "")
                            if realItemName and ItemRegistry then
                                local regData = ItemRegistry:GetItem(realItemName)
                                if regData then
                                    local descText = (regData.GearDesc and (regData.GearDesc .. " | ") or "") .. (regData.ToolTip or "")
                                    descLbl.Text = "[Stats Revealed] " .. descText
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- 2. GIẢI MÃ VÀ HIỆN MANA/ENERGY THẬT (REAL ENERGY / MANA)
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

                    -- Cập nhật chữ CurrentEnergy.Amount (VD: 1/6 thay vì ???)
                    local currentEnergyFrame = holder:FindFirstChild("CurrentEnergy")
                    local energyAmountLabel = currentEnergyFrame and currentEnergyFrame:FindFirstChild("Amount")
                    if energyAmountLabel and energyAmountLabel:IsA("TextLabel") then
                        if energyAmountLabel.Text == "???" or energyAmountLabel.Text:find("%?") then
                            energyAmountLabel.Text = string.format("%d/%d", curEnergy, maxEnergy)
                        end
                    end

                    -- Cập nhật các ô vạch Energy xanh sáng
                    local energyBarsContainer = holder:FindFirstChild("Energy")
                    if energyBarsContainer then
                        for i = 1, maxEnergy do
                            local bar = energyBarsContainer:FindFirstChild(tostring(i))
                            if bar and bar:IsA("GuiObject") then
                                bar.BackgroundColor3 = blueEnergyColor
                                if i <= curEnergy then
                                    bar.Visible = true
                                else
                                    bar.Visible = false
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- KHỞI CHẠY CHU TRÌNH TỰ ĐỘNG & LƯU GLOBAL STATE
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
if AutoYarthul then
    AutoYarthul.checkSessionOnBoot()
end
