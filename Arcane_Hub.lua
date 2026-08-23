--[[
    ========================================================================================
    🌟 ARCANE LINEAGE - ALL-IN-ONE MASTER HUB (LinoriaLib GUI + SaveManager + ThemeManager)
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

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)

if shared.ArcaneHub then
    pcall(function() shared.ArcaneHub.Unload() end)
    shared.ArcaneHub = nil
end

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local GuiCollisionService = nil
pcall(function()
    GuiCollisionService = require(game.ReplicatedStorage:WaitForChild("GuiCollisionService", 5))
end)

local HttpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- =============================================================================
-- TẢI LINORIA GUI LIBRARY + THEME & SAVE MANAGERS
-- =============================================================================
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- =============================================================================
-- HÀM TIỆN ÍCH DÙNG CHUNG (UTILITIES)
-- =============================================================================
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
-- TOÀN DIỆN BLACKLIST VẬT PHẨM GIẢ (VASTIC GRAVE DESERT + FORGOTTEN SANCTUM)
-- =============================================================================
local function isBlacklistedCrylight(obj)
    if not Toggles.BlacklistDesert or not Toggles.BlacklistDesert.Value then return false end
    if not obj:IsA("Model") and not obj:IsA("BasePart") then return false end
    local pos = obj:GetPivot().Position

    -- 1. Khu vực Mộ Sa Mạc (Vastic Grave in Desert @ X: 1423, Y: 617, Z: -4468)
    if (pos - Vector3.new(1423.0, 616.8, -4468.0)).Magnitude < 150 then
        return true
    end

    -- 2. Bounding box của toàn bộ khu vực Forgotten Sanctum / Desert Pyramid
    if pos.X > 8800 and pos.Y > 1000 then
        return true
    end

    -- 3. Khoảng cách toàn bộ cụm kim tự tháp / sanctum
    if (pos - Vector3.new(10831.2, 1581.7, -3463.6)).Magnitude < 2000 then
        return true
    end
    if (pos - Vector3.new(10450.0, 1570.0, -3480.0)).Magnitude < 2000 then
        return true
    end

    -- 4. Kiểm tra đường dẫn thư mục cha
    local path = obj:GetFullName():lower()
    if path:find("vastic") or path:find("grave") or path:find("forgotten") or path:find("sanctum") or path:find("pyramid") or path:find("dungeon") or path:find("menu") then
        return true
    end

    return false
end

-- =============================================================================
-- HỆ THỐNG SERVER HOP TỰ ĐỘNG (JSON PERSISTENT - TỐI ĐA 20 SERVER RỒI RESET)
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
        print(string.format("[ServerHop] 🔄 Đã ghé qua %d server. Đang reset danh sách để tái sử dụng server cũ!", count))
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
        print("[ServerHop] 🌐 Đang tìm kiếm Server mới...")
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
            print(string.format("[ServerHop] 🚀 Đang chuyển tới server: %s (%d/%d người)...", targetServer.id, targetServer.playing, targetServer.maxPlayers))
            ServerHopper.lastAttemptServer = targetServer.id
            saveVisitedServer(targetServer.id)

            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
            end)

            local timeout = Options.TeleportTimeout and Options.TeleportTimeout.Value or 8
            task.wait(timeout)
            if ServerHopper.isHopping then
                warn("[ServerHop] ⏱️ Hết thời gian chờ teleport. Đang tự động đổi sang server khác...")
                ServerHopper.isHopping = false
                ServerHopper.hop()
            end
        else
            warn("[ServerHop] ⚠️ Không tìm thấy server nào khả dụng. Đang reset danh sách và thử lại...")
            if writefile then pcall(function() writefile(ServerHopper.visitedFile, "{}") end) end
            ServerHopper.isHopping = false
            task.wait(2)
            ServerHopper.hop()
        end
    end)
end

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    warn(string.format("[ServerHop] ❌ Teleport thất bại: %s (%s). Đang đổi server khác ngay...", tostring(teleportResult), tostring(errorMessage)))
    if ServerHopper.lastAttemptServer then saveVisitedServer(ServerHopper.lastAttemptServer) end
    ServerHopper.isHopping = false
    task.wait(1)
    ServerHopper.hop()
end)

-- =============================================================================
-- DISCORD WEBHOOK NOTIFIER (MULTI-ITEM ADAPTABLE)
-- =============================================================================
local function sendDiscordReport(harvestedMap, totalHarvested)
    local webhookUrl = Options.DiscordWebhook and Options.DiscordWebhook.Value or ""
    if #webhookUrl < 10 or not HttpRequest then return end

    task.spawn(function()
        local itemListStr = ""
        for name, count in pairs(harvestedMap) do
            itemListStr = itemListStr .. string.format("• **%s**: x%d\n", name, count)
        end
        if #itemListStr == 0 then itemListStr = string.format("• **Item**: x%d\n", totalHarvested) end

        local payload = {
            username = "Arcane Lineage Master Farmer",
            avatar_url = "https://cdn-icons-png.flaticon.com/512/3655/3655581.png",
            embeds = {{
                title = "🌿 THU HOẠCH NGUYÊN LIỆU THÀNH CÔNG! 🌿",
                description = string.format("Nhân vật vừa hoàn thành thu hoạch **%d** nguyên liệu và đang chuyển server!", totalHarvested),
                color = 0x00FF88,
                fields = {
                    { name = "🎒 Danh Sách Thu Hoạch", value = itemListStr, inline = false },
                    { name = "👤 Nhân vật", value = string.format("`%s` (%s)", LocalPlayer.Name, LocalPlayer.DisplayName), inline = true },
                    { name = "🆔 Server JobId", value = string.format("`%s`", game.JobId), inline = false }
                },
                footer = { text = "Arcane Lineage • Master Hub" },
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
-- AUTO START & MENU-SKIP
-- =============================================================================
local function handleAutoStart()
    print("[AutoStart] Đang kiểm tra Skip Intro và Start Menu đầu game...")
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
            print("[AutoStart] ✨ Đã vào thế giới thành công!")
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
        FlightController.noclipConn = RunService.Stepped:Connect(function()
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
        end)
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

local function smoothTweenTo(targetCFrame, speed, cancelCheckFn)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    enableFlightState()

    local distance = (root.Position - targetCFrame.Position).Magnitude
    local duration = math.max(0.1, distance / speed)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, { CFrame = targetCFrame })
    FlightController.currentTween = tween
    tween:Play()

    local completed = false
    local conn
    conn = tween.Completed:Connect(function()
        completed = true
        if conn then conn:Disconnect() end
    end)

    while not completed do
        if cancelCheckFn and not cancelCheckFn() then
            tween:Cancel()
            FlightController.currentTween = nil
            disableFlightState()
            return false
        end
        task.wait()
    end

    FlightController.currentTween = nil
    return completed
end

-- =============================================================================
-- AUTO FARM INGREDIENTS (MULTI-ITEM SCAN + SKY TWEEN 1500 Y)
-- =============================================================================
local Farmer = {
    running = false,
}

local function flyToItem(targetPosition)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local skyHeight = Options.SkyHeight and Options.SkyHeight.Value or 1500
    local ascendSpeed = Options.AscendSpeed and Options.AscendSpeed.Value or 150
    local cruiseSpeed = Options.CruiseSpeed and Options.CruiseSpeed.Value or 180
    local descendSpeed = Options.DescendSpeed and Options.DescendSpeed.Value or 150

    local currentPos = root.Position
    local skyY = math.max(skyHeight, currentPos.Y + 200, targetPosition.Y + 200)

    local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), ascendSpeed, function() return Farmer.running end)
    if not s1 or not Farmer.running then return false end

    local s2 = smoothTweenTo(CFrame.new(targetPosition.X, skyY, targetPosition.Z), cruiseSpeed, function() return Farmer.running end)
    if not s2 or not Farmer.running then return false end

    local s3 = smoothTweenTo(CFrame.new(targetPosition.X, targetPosition.Y + 3.5, targetPosition.Z), descendSpeed, function() return Farmer.running end)
    return s3
end

local function harvestItem(model)
    if not model or not model.Parent then return false end
    local startTime = os.clock()
    local timeout = Options.PickupTimeout and Options.PickupTimeout.Value or 5

    while model and model.Parent and (os.clock() - startTime < timeout) and Farmer.running do
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
        print("[AutoFarm] 🔍 [BƯỚC 1]: Đang quét nguyên liệu được chọn ngay tại Menu...")
        task.wait(2.5)

        local selectedMap = (Options.FarmItemsWhitelist and Options.FarmItemsWhitelist.Value) or { ["Crylight"] = true }

        local harvestList = {}
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc.Parent and selectedMap[desc.Name] and not isBlacklistedCrylight(desc) then
                table.insert(harvestList, { instance = desc, name = desc.Name })
            end
        end

        print(string.format("[AutoFarm] 📊 Kết quả kiểm tra tại Menu: Tìm thấy %d nguyên liệu hợp lệ.", #harvestList))

        if #harvestList > 0 then
            print("[AutoFarm] ✨ Phát hiện nguyên liệu mục tiêu! Đang tự động bấm Play để vào game thu hoạch...")
            handleAutoStart()

            local harvestedCounts = {}
            local totalHarvested = 0
            for i, itemData in ipairs(harvestList) do
                if not Farmer.running then break end
                local item = itemData.instance
                local itemName = itemData.name
                if item and item.Parent then
                    local targetPos = item:GetPivot().Position
                    print(string.format("[AutoFarm] 🎯 [%d/%d] Đang bay tới %s tại (%.1f, %.1f, %.1f)...", i, #harvestList, itemName, targetPos.X, targetPos.Y, targetPos.Z))

                    local flew = flyToItem(targetPos)
                    if flew and item and item.Parent then
                        local picked = harvestItem(item)
                        if picked then
                            totalHarvested = totalHarvested + 1
                            harvestedCounts[itemName] = (harvestedCounts[itemName] or 0) + 1
                        end
                        task.wait(0.4)
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
            print("[AutoFarm] ❌ Server không có nguyên liệu mục tiêu! Đang Server Hop ngay từ Main Menu...")
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
    print("[AutoFarm] Đã dừng Auto Farm.")
end

-- =============================================================================
-- AUTO FARM LEVEL & COMBAT HELPER (LEVEL 1-20 UNDERGROUND & LEVEL 20-50 ENGINE)
-- =============================================================================
local LevelFarmer = {
    running = false,
    undergroundPlatform = nil,
    farmSpotLv1_20 = Vector3.new(5035.2, 595.0, -3969.5),
}

local function ensureUndergroundPlatform(targetPos)
    local plat = workspace:FindFirstChild("ArcaneFarmPlatform")
    if not plat then
        plat = Instance.new("Part")
        plat.Name = "ArcaneFarmPlatform"
        plat.Size = Vector3.new(16, 2, 16)
        plat.Anchored = true
        plat.CanCollide = true
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

local function teleportToUndergroundSpot(targetSpot)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return false end

    -- Ensure platform exists
    ensureUndergroundPlatform(targetSpot)

    local targetCF = CFrame.new(targetSpot.X, targetSpot.Y + 4.0, targetSpot.Z)
    local distance = (root.Position - targetCF.Position).Magnitude

    if distance > 5 then
        print(string.format("[AutoFarmLevel] 🚀 Đang tween xuống vị trí ngầm tại (%.1f, %.1f, %.1f)...", targetCF.X, targetCF.Y, targetCF.Z))
        local speed = Options.CruiseSpeed and Options.CruiseSpeed.Value or 150
        local tweenSuccess = smoothTweenTo(targetCF, speed, function() return LevelFarmer.running end)
        if not tweenSuccess then return false end
    end

    -- Settle firmly on platform
    disableFlightState()
    hum.PlatformStand = false
    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    task.wait(0.2)
    return true
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
    return 1
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

local function allocateStats()
    if not (Toggles.AutoAllocateStats and Toggles.AutoAllocateStats.Value) then return end

    local currentStats = getCurrentStats()
    local targets = {
        Strength = Options.TargetStrength and Options.TargetStrength.Value or 20,
        Endurance = Options.TargetEndurance and Options.TargetEndurance.Value or 20,
        Speed = Options.TargetSpeed and Options.TargetSpeed.Value or 10,
        Arcane = Options.TargetArcane and Options.TargetArcane.Value or 0,
        Luck = Options.TargetLuck and Options.TargetLuck.Value or 10,
    }

    local RS = game:GetService("ReplicatedStorage")
    local remotes = RS:FindFirstChild("Remotes")
    local info = remotes and remotes:FindFirstChild("Information")
    local statRemote = info and info:FindFirstChild("StatAllocation")
    if not statRemote then return end

    local statOrder = { "Strength", "Endurance", "Speed", "Arcane", "Luck" }
    for _, stat in ipairs(statOrder) do
        local cur = currentStats[stat] or 0
        local tgt = targets[stat] or 0
        while cur < tgt do
            pcall(function()
                statRemote:FireServer(stat)
            end)
            cur = cur + 1
            task.wait(0.08)
        end
    end
    print("[AutoFarmLevel] 📊 Đã hoàn tất phân bổ chỉ số theo Target Stats.")
end

local function performMeditationAndLevelUp()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    -- 1. Tìm Chiếu Thiền gần nhất
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
        print("[AutoFarmLevel] ❌ Không tìm thấy MeditationMat trên bản đồ.")
        return false
    end

    local matPos = nearestMat:GetPivot().Position
    local targetCF = CFrame.new(matPos.X, matPos.Y + 2.5, matPos.Z)

    print(string.format("[AutoFarmLevel] 🧘 Đang bay chớp nhoáng tới Chiếu Thiền tại (%.1f, %.1f, %.1f)...", matPos.X, matPos.Y, matPos.Z))
    local tweenSuccess = smoothTweenTo(targetCF, 220, function() return LevelFarmer.running end)
    if not tweenSuccess then return false end

    task.wait(0.2)

    -- 2. Kích hoạt ProximityPrompt
    local prox = nearestMat:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prox and fireproximityprompt then
        fireproximityprompt(prox)
        print("[AutoFarmLevel] ✨ Đã kích hoạt Chiếu Thiền!")
    end

    task.wait(1.5)

    -- 3. Đổi cấp qua Aretim / Remote
    local RS = game:GetService("ReplicatedStorage")
    local remotes = RS:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local lvlRemote = dataRemotes and dataRemotes:FindFirstChild("LevelUp")
    if lvlRemote then
        pcall(function()
            lvlRemote:FireServer()
            print("[AutoFarmLevel] 🆙 Đã gửi yêu cầu đổi cấp qua Aretim.")
        end)
    end

    task.wait(0.8)

    -- 4. Tự động cộng điểm stats
    allocateStats()
    task.wait(0.5)

    -- 5. Quay lại bãi ngầm an toàn
    local mode = Options.FarmLevelMode and Options.FarmLevelMode.Value or "Level 1 - 20 (Underground)"
    if mode:find("Level 1 - 20") then
        local spot = LevelFarmer.farmSpotLv1_20
        ensureUndergroundPlatform(spot)
        teleportToUndergroundSpot(spot)
        print("[AutoFarmLevel] 🛡️ Đã quay lại bãi farm ngầm an toàn.")
    end

    return true
end

local function safeClickButton(btn)
    if not btn or not btn:IsA("GuiButton") then return false end
    local clicked = false
    pcall(function()
        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
            if c.Function then
                c.Function()
                clicked = true
            elseif c.Fire then
                c:Fire()
                clicked = true
            end
        end
    end)
    pcall(function()
        for _, c in ipairs(getconnections(btn.MouseButton1Down)) do
            if c.Function then
                c.Function()
                clicked = true
            elseif c.Fire then
                c:Fire()
                clicked = true
            end
        end
    end)
    return clicked
end

local function isInCombat()
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if combatGui and combatGui.Enabled then
        return true
    end
    local fFolder = workspace:FindFirstChild("Fights")
    if fFolder and LocalPlayer.Character then
        for _, fight in ipairs(fFolder:GetChildren()) do
            if fight:FindFirstChild(LocalPlayer.Name) or fight:FindFirstChild(LocalPlayer.Character.Name) then
                return true
            end
        end
    end
    return false
end

local function isPlayerTurn()
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if not combatGui or not combatGui.Enabled then return false end

    local actionBG = combatGui:FindFirstChild("ActionBG")
    if not actionBG then return false end

    if actionBG.Position.X.Scale < 0.95 then
        return true
    end

    local ctx = actionBG:FindFirstChild("ContextPage")
    if ctx and ctx.Visible then return true end

    local atk = actionBG:FindFirstChild("AttacksPage")
    if atk and atk.Visible then return true end

    local goBtn = combatGui:FindFirstChild("Go")
    if goBtn and goBtn.Visible then return true end

    return false
end

local function executeCombatTurn()
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if not combatGui or not combatGui.Enabled then return end

    local actionBG = combatGui:FindFirstChild("ActionBG")
    if not actionBG then return end

    local actionChoice = Options.SelectedCombatAction and Options.SelectedCombatAction.Value or "Strike (Basic Attack)"
    local customSkill = Options.CustomSkillName and Options.CustomSkillName.Value or ""
    local targetPrio = Options.TargetPriority and Options.TargetPriority.Value or "First Enemy"

    -- 1. Click ContextPage AttackButton if visible
    local ctxPage = actionBG:FindFirstChild("ContextPage")
    if ctxPage and ctxPage.Visible then
        local atkBtn = ctxPage:FindFirstChild("AttackButton")
        if atkBtn then
            safeClickButton(atkBtn)
            task.wait(0.2)
        end
    end

    -- 2. Select Skill or Strike in AttacksPage.Attack.ScrollingFrame
    local atkPage = actionBG:FindFirstChild("AttacksPage")
    local attackFrame = atkPage and atkPage:FindFirstChild("Attack")
    local scrollFrame = attackFrame and attackFrame:FindFirstChild("ScrollingFrame")

    if scrollFrame then
        local selectedSkillBtn = nil

        if actionChoice == "Custom Skill Name" and customSkill ~= "" then
            for _, btn in ipairs(scrollFrame:GetChildren()) do
                if btn:IsA("GuiButton") and btn.Name ~= "Return" then
                    local nameLabel = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                    local textToMatch = nameLabel and nameLabel.Text or btn.Name
                    if textToMatch:lower():find(customSkill:lower()) then
                        local cdFrame = btn:FindFirstChild("Cooldown", true) or btn:FindFirstChild("CoolDown", true)
                        if not (cdFrame and cdFrame.Visible) then
                            selectedSkillBtn = btn
                            break
                        end
                    end
                end
            end
        elseif actionChoice == "Auto Smart (Best Skill -> Strike)" or actionChoice == "First Available Skill (Fallback Strike)" then
            for _, btn in ipairs(scrollFrame:GetChildren()) do
                if btn:IsA("GuiButton") and btn.Name ~= "Strike" and btn.Name ~= "Template" and btn.Name ~= "Return" then
                    local cdFrame = btn:FindFirstChild("Cooldown", true) or btn:FindFirstChild("CoolDown", true)
                    if not (cdFrame and cdFrame.Visible) then
                        selectedSkillBtn = btn
                        break
                    end
                end
            end
        end

        -- Fallback to Strike
        if not selectedSkillBtn then
            selectedSkillBtn = scrollFrame:FindFirstChild("Strike") or scrollFrame:FindFirstChildWhichIsA("GuiButton")
        end

        if selectedSkillBtn then
            safeClickButton(selectedSkillBtn)
            task.wait(0.2)
        end
    end

    -- 3. Select Target Enemy in AttacksPage.Enemies.ScrollingFrame
    local enemiesFrame = atkPage and atkPage:FindFirstChild("Enemies")
    local enemiesScroll = enemiesFrame and (enemiesFrame:FindFirstChild("ScrollingFrame") or enemiesFrame)

    if enemiesScroll then
        local enemyButtons = {}
        for _, btn in ipairs(enemiesScroll:GetChildren()) do
            if btn:IsA("GuiButton") and btn.Visible and btn.Name ~= "Return" then
                table.insert(enemyButtons, btn)
            end
        end
        if #enemyButtons == 0 then
            for _, btn in ipairs(enemiesScroll:GetDescendants()) do
                if btn:IsA("GuiButton") and btn.Visible and btn.Name ~= "Return" then
                    table.insert(enemyButtons, btn)
                end
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
                safeClickButton(chosenEnemy)
                task.wait(0.15)
            end
        end
    end

    -- 4. Click Go confirmation button if visible
    local goBtn = combatGui:FindFirstChild("Go")
    if goBtn and goBtn.Visible then
        safeClickButton(goBtn)
    end
end

function LevelFarmer.runCycle()
    if LevelFarmer.running then return end
    LevelFarmer.running = true

    task.spawn(function()
        local mode = Options.FarmLevelMode and Options.FarmLevelMode.Value or "Level 1 - 20 (Underground)"
        print(string.format("[AutoFarmLevel] ⚔️ Bắt đầu Auto Farm Level - Chế độ: %s", mode))

        -- If Level 1 - 20, ensure we are at the underground spot first
        if mode:find("Level 1 - 20") then
            local spot = LevelFarmer.farmSpotLv1_20
            ensureUndergroundPlatform(spot)
            teleportToUndergroundSpot(spot)
        end

        while LevelFarmer.running do
            if isInCombat() then
                if isPlayerTurn() then
                    executeCombatTurn()
                    local combatDelay = Options.CombatDelay and Options.CombatDelay.Value or 0.4
                    task.wait(combatDelay)
                else
                    task.wait(0.2)
                end
            else
                -- Tự động kiểm tra Essence và đi thiền đổi cấp nếu đầy
                if Toggles.AutoMeditate and Toggles.AutoMeditate.Value then
                    local curEssence = getCurrentEssence()
                    local threshold = Options.EssenceThreshold and Options.EssenceThreshold.Value or 40
                    if curEssence >= threshold then
                        print(string.format("[AutoFarmLevel] 🔮 Essence đạt mốc (%d >= %d) -> Bắt đầu chu trình đổi cấp...", curEssence, threshold))
                        performMeditationAndLevelUp()
                    end
                end

                -- If out of combat and in Level 1 - 20 mode, check if we drifted or need repositioning
                local currentMode = Options.FarmLevelMode and Options.FarmLevelMode.Value or "Level 1 - 20 (Underground)"
                if currentMode:find("Level 1 - 20") then
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local spot = LevelFarmer.farmSpotLv1_20
                        ensureUndergroundPlatform(spot)
                        local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude
                        local yDiff = math.abs(root.Position.Y - (spot.Y + 4.0))
                        if dist > 8 or yDiff > 6 then
                            teleportToUndergroundSpot(spot)
                        end
                    end
                end
                task.wait(0.4)
            end
            task.wait(0.1)
        end
        print("[AutoFarmLevel] ⏹️ Đã dừng Auto Farm Level.")
    end)
end

function LevelFarmer.stop()
    LevelFarmer.running = false
    disableFlightState()
end

-- =============================================================================
-- AUTO MINE ORES (FERRUS, AESTIC, LANEUS + AUTO BUY PICKAXE)
-- =============================================================================
local Miner = {
    running = false,
}

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

local function equipPickaxe()
    local char = LocalPlayer.Character
    if not char then return false end
    if char:FindFirstChild("Pickaxe") then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and hum then
        local pick = bp:FindFirstChild("Pickaxe") or bp:FindFirstChildWhichIsA("Tool")
        if pick and pick:IsA("Tool") then
            hum:EquipTool(pick)
            task.wait(0.3)
            return true
        end
    end
    return false
end

local function buyPickaxe()
    print("[AutoMine] 🛒 Không tìm thấy Pickaxe! Đang bay tới Caldera Blacksmith để mua Pickaxe (50 Gold)...")
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
        task.wait(1)
        Library:Notify("✅ Pickaxe interaction dispatched!", 3)
        return true
    end
    return false
end

local function mineOreNode(oreModel)
    if not oreModel or not oreModel.Parent then return false end
    local startTime = os.clock()
    local timeout = Options.MineTimeout and Options.MineTimeout.Value or 12
    equipPickaxe()

    while oreModel and oreModel.Parent and (os.clock() - startTime < timeout) and Miner.running do
        -- 1. Trigger ProximityPrompt / ClickDetector if present
        for _, desc in ipairs(oreModel:GetDescendants()) do
            if desc:IsA("ClickDetector") and fireclickdetector then
                fireclickdetector(desc)
            elseif desc:IsA("ProximityPrompt") and fireproximityprompt then
                fireproximityprompt(desc)
            end
        end

        -- 2. Activate tool and simulate hit
        local char = LocalPlayer.Character
        local tool = char and (char:FindFirstChild("Pickaxe") or char:FindFirstChildWhichIsA("Tool"))
        if tool and tool:IsA("Tool") then
            tool:Activate()
        end
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)

        task.wait(0.35)
    end
    return (oreModel.Parent == nil)
end

function Miner.runCycle()
    if Miner.running then return end
    Miner.running = true

    task.spawn(function()
        print("[AutoMine] ⛏️ [BƯỚC 1]: Kiểm tra trang bị Pickaxe...")
        handleAutoStart()

        if not hasPickaxe() then
            if Toggles.AutoBuyPickaxe and Toggles.AutoBuyPickaxe.Value then
                local bought = buyPickaxe()
                if not bought and not hasPickaxe() then
                    Library:Notify("⚠️ Failed to acquire Pickaxe! Cannot mine ores.", 4)
                    Miner.stop()
                    return
                end
            else
                Library:Notify("⚠️ Pickaxe required to mine! Please buy one or enable Auto Buy.", 4)
                Miner.stop()
                return
            end
        end

        print("[AutoMine] 🔍 [BƯỚC 2]: Đang quét mỏ quặng trên bản đồ...")
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

        print(string.format("[AutoMine] 📊 Tìm thấy %d mỏ quặng hợp lệ.", #oreList))

        if #oreList > 0 then
            local minedCount = 0
            for i, oreData in ipairs(oreList) do
                if not Miner.running then break end
                local ore = oreData.instance
                local oreName = oreData.name
                if ore and ore.Parent then
                    local targetPos = ore:GetPivot().Position
                    print(string.format("[AutoMine] 🎯 [%d/%d] Đang bay tới mỏ %s tại (%.1f, %.1f, %.1f)...", i, #oreList, oreName, targetPos.X, targetPos.Y, targetPos.Z))

                    local flew = flyToItem(targetPos)
                    if flew and ore and ore.Parent then
                        local done = mineOreNode(ore)
                        if done then
                            minedCount = minedCount + 1
                            print(string.format("[AutoMine] ✅ Đã đào xong mỏ %s!", oreName))
                        end
                        task.wait(0.5)
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
            print("[AutoMine] ❌ Server không có quặng mục tiêu!")
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
    print("[AutoMine] Đã dừng Auto Mine.")
end

-- =============================================================================
-- AUTO COMBAT QTE ENGINE (SINGLE-CLICK, 0.25S DEBOUNCED SWEET SPOT ENGINE)
-- =============================================================================
local DaggerArcSizes = { 20, 25, 30, 35, 40, 45, 55, 65, 75, 85, 95, 105 }

local function isQTEActive(qteName)
    if Toggles.MasterQTE and not Toggles.MasterQTE.Value then return false end
    local qteMap = Options.EnabledQTEList and Options.EnabledQTEList.Value
    if qteMap then
        if qteName == "Dodge" then return qteMap["Auto Dodge / Block"] == true end
        if qteName == "Sword" then return qteMap["Sword (Window Strike)"] == true end
        if qteName == "Dagger" then return qteMap["Dagger (Weakpoints)"] == true end
        if qteName == "Hammer" then return qteMap["Hammer (Power Bar)"] == true end
        if qteName == "Axe" then return qteMap["Axe (Equilibrium)"] == true end
        if qteName == "Fist" then return qteMap["Fist / Cestus (Combos)"] == true end
        if qteName == "Lockpick" then return qteMap["Chest Lockpick"] == true end
    end
    return true
end

local AutoQTE = {
    lastDodgeHit = 0,
    lastSwordHit = 0,
    lastDaggerHit = 0,
    isHammerHolding = false,
    lastAxePress = 0,
    lastFistHit = 0,
    swordHitTable = {},
    hitWeakpoints = {},
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

-- 2. SWORD QTE (SINGLE-CLICK, 0.25S DEBOUNCED SWEET SPOT ENGINE)
local function handleSwordQTE(swordQTE)
    if not isQTEActive("Sword") or not swordQTE or not swordQTE.Visible then
        AutoQTE.swordHitTable = {}
        return
    end

    local now = os.clock()
    if now - AutoQTE.lastSwordHit < 0.25 then return end

    local inset = swordQTE:FindFirstChild("Inset")
    local stopBtn = swordQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local window = inset:FindFirstChild("Window")
    if not window or not window.Visible then return end

    local winLeft = window.AbsolutePosition.X
    local winWidth = window.AbsoluteSize.X

    local candidate = nil
    local lowestIdx = math.huge

    for _, child in ipairs(inset:GetChildren()) do
        local idx = tonumber(child.Name)
        if idx and not AutoQTE.swordHitTable[child] and child:IsA("GuiObject") and child.Visible and child.BackgroundTransparency < 0.4 then
            if idx < lowestIdx then
                lowestIdx = idx
                candidate = child
            end
        end
    end

    if not candidate then return end

    local indLeft = candidate.AbsolutePosition.X
    local indWidth = candidate.AbsoluteSize.X
    local indCenter = indLeft + (indWidth / 2)

    local sweetSpotMin = winLeft + (winWidth * 0.40)
    local sweetSpotMax = winLeft + (winWidth * 0.70)

    if indCenter >= sweetSpotMin and indCenter <= sweetSpotMax then
        AutoQTE.lastSwordHit = now
        AutoQTE.swordHitTable[candidate] = true
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

-- 5. AXE QTE (THRESHOLD EQUILIBRIUM TAPPER)
local function handleAxeQTE(axeQTE)
    if not isQTEActive("Axe") or not axeQTE or not axeQTE.Visible then return end
    local gauge = axeQTE:FindFirstChild("Gauge")
    local spaceHint = axeQTE:FindFirstChild("SpaceHint")
    if not gauge then return end

    local fill = gauge:FindFirstChild("Fill")
    local threshold = gauge:FindFirstChild("Threshold")
    if not fill or not threshold then return end

    local fillRight = fill.AbsolutePosition.X + fill.AbsoluteSize.X
    local targetMin = threshold.AbsolutePosition.X
    local targetMax = targetMin + threshold.AbsoluteSize.X
    local targetCenter = (targetMin + targetMax) / 2

    if fillRight < targetCenter then
        local now = os.clock()
        if now - AutoQTE.lastAxePress > 0.05 then
            AutoQTE.lastAxePress = now
            if spaceHint then singleClick(spaceHint) end
            pressKey(Enum.KeyCode.Space)
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

-- 7. SPEAR QTE (ACTIVE TAP AUTOCLICKER)
local function handleSpearQTE(spearQTE)
    if not spearQTE or not spearQTE.Visible then return end
    local container = spearQTE:FindFirstChild("Container")
    if container then
        for _, tap in ipairs(container:GetChildren()) do
            if tap:IsA("GuiObject") and tap.Visible then
                local btn = tap:FindFirstChild("InputButton") or tap:FindFirstChildWhichIsA("TextButton", true) or tap:FindFirstChildWhichIsA("ImageButton", true)
                if btn and (btn.Active == nil or btn.Active == true) then
                    singleClick(btn)
                    break
                end
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

RunService.RenderStepped:Connect(function()
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
    local fistQTE = combatGui:FindFirstChild("FistQTE")
    local lockpickQTE = combatGui:FindFirstChild("LockpickQTE")

    if dodgeQTE and dodgeQTE.Visible then handleDodgeQTE(dodgeQTE) end
    if swordQTE and swordQTE.Visible then
        handleSwordQTE(swordQTE)
    else
        AutoQTE.swordHitTable = {}
    end

    if daggerQTE and daggerQTE.Visible then
        handleDaggerQTE(daggerQTE)
    else
        AutoQTE.hitWeakpoints = {}
    end

    if hammerQTE and hammerQTE.Visible then handleHammerQTE(hammerQTE) end
    if axeQTE and axeQTE.Visible then handleAxeQTE(axeQTE) end
    if fistQTE and fistQTE.Visible then handleFistQTE(fistQTE) end
    if lockpickQTE and lockpickQTE.Visible then handleLockpickQTE(lockpickQTE) end
end)


-- =============================================================================
-- MOVEMENT CONTROLLER (FLY, NOCLIP, SPEEDHACK, CFRAME SPEED, INFINITE JUMP)
-- =============================================================================
local Movement = {
    flyBodyVelocity = nil,
}

RunService.Stepped:Connect(function()
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
end)

RunService.RenderStepped:Connect(function()
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
end)

RunService.Heartbeat:Connect(function(dt)
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
end)

-- =============================================================================
-- TELEPORT SUITE (ALL 35+ CLASS TRAINERS, TOWNS, MERCHANTS, AND LANDMARKS)
-- =============================================================================
local KeyLocations = {
    -- 🏛️ Towns & Major Hubs
    ["🏛️ Westwood Heart"] = Vector3.new(8327.3, 825.1, -5557.4),
    ["🌋 Caldera Town"] = Vector3.new(5091.2, 662.6, -4293.1),
    ["🏜️ Desert (Waving Sands)"] = Vector3.new(2815.3, 634.6, -3924.6),
    ["⚔️ Sanctuary of Blades"] = Vector3.new(2086.0, 386.8, -2978.3),
    ["⛪ Church (Heavens Point)"] = Vector3.new(831.6, 3436.9, -5602.3),
    ["🏛️ Forgotten Sanctum (Endgame)"] = Vector3.new(10831.2, 1581.7, -3463.6),
    ["🌑 Dark Place Gate"] = Vector3.new(7855.1, 1290.3, 7930.9),
    ["🌌 Void Rift"] = Vector3.new(991.0, 41.4, 615.6),
    ["🏠 Memori's House"] = Vector3.new(11851.5, 1064.9, -1776.8),
    ["❄️ Icerift Approach"] = Vector3.new(5328.2, 742.7, -6530.2),
    ["🌋 Volcano (Mount Thul)"] = Vector3.new(98.9, 577.0, -4115.9),

    -- ⚔️ Base Class Trainers (7)
    ["⚔️ Base: Ysa (Warrior - Sword)"] = Vector3.new(5100.6, 658.2, -4072.0),
    ["🔮 Base: Arandor (Wizard - Magic / Staff)"] = Vector3.new(5840.1, 727.0, -4790.1),
    ["🗡️ Base: Boots (Thief - Dagger)"] = Vector3.new(4945.6, 658.6, -4121.4),
    ["🥊 Base: Doran (Martial Artist - Fist / Cestus)"] = Vector3.new(5627.8, 703.8, -4336.9),
    ["🛡️ Base: Tivek (Slayer - Spear)"] = Vector3.new(4473.3, 650.1, -5730.3),
    ["🪓 Base: Geron (Marauder - Axe)"] = Vector3.new(4448.3, 652.1, -3359.3),
    ["🛡️ Base: Lagolt (Sentry - Greatsword)"] = Vector3.new(4651.7, 718.7, -5574.9),

    -- 🌟 Super Class Trainers (18)
    ["✨ Super: Dernon (Paladin - Warrior)"] = Vector3.new(2813.0, 615.7, -3866.6),
    ["⚔️ Super: Leoran (Blade Dancer - Warrior)"] = Vector3.new(4995.5, 754.4, -6194.1),
    ["⚡ Super: Kayrein (Berserker - Warrior)"] = Vector3.new(11342.1, 1500.1, -3656.7),
    ["🌪️ Super: Landrum (Elementalist - Wizard)"] = Vector3.new(2473.2, 624.7, -3540.3),
    ["🔥 Super: Ophelia (Hexer - Wizard)"] = Vector3.new(4661.7, 651.7, -5236.5),
    ["💀 Super: Ulys (Necromancer - Wizard)"] = Vector3.new(10847.3, 1589.0, -4091.8),
    ["🏹 Super: Orkin (Ranger - Thief)"] = Vector3.new(8546.3, 822.7, -5544.1),
    ["🗡️ Super: Aberon (Rogue - Thief)"] = Vector3.new(2800.0, 610.7, -4018.2),
    ["🥷 Super: Inette (Assassin - Thief)"] = Vector3.new(6699.0, 568.2, -3461.3),
    ["🥋 Super: Luther (Monk - Martial Artist)"] = Vector3.new(3496.5, 632.8, -3983.3),
    ["🥊 Super: Gren (Brawler - Martial Artist)"] = Vector3.new(5170.9, 660.5, -4996.0),
    ["🌑 Super: Momma Darkbeast (Darkwraith - Martial Artist)"] = Vector3.new(8122.6, 581.8, -2138.1),
    ["🕊️ Super: Fernain (Saint - Slayer)"] = Vector3.new(2296.1, 663.3, -4392.7),
    ["🚩 Super: Relan (Lancer - Slayer)"] = Vector3.new(5322.2, 749.4, -6324.2),
    ["🔱 Super: Orin (Impaler - Slayer)"] = Vector3.new(8043.9, 822.6, -5599.3),
    ["🦁 Super: Ardentis (Lionheart - Sentry/Marauder)"] = Vector3.new(474.5, 581.5, -4816.9),
    ["🏰 Super: Nevithas (Citadel - Sentry/Marauder)"] = Vector3.new(71.9, 2765.7, -3266.4),
    ["⚖️ Super: Kether (Arbiter - Sentry/Marauder)"] = Vector3.new(7821.2, 1279.8, 8480.1),

    -- 📜 Sub Class Trainers (5)
    ["🎶 Sub: Cantia (Bard)"] = Vector3.new(2845.8, 624.1, -3222.9),
    ["🐾 Sub: Thorin (Beastmaster)"] = Vector3.new(4253.1, 653.8, -3369.2),
    ["🧪 Sub: Selia (Alchemist)"] = Vector3.new(8116.2, 822.5, -5456.4),
    ["⚒️ Sub: Adelma (Blacksmith Subclass)"] = Vector3.new(-425.4, 2712.7, -3388.1),
    ["⛏️ Sub: Vanio (Miner)"] = Vector3.new(7572.0, 593.2, -2674.0),

    -- 🌟 Deities, Enchants & Quests (10)
    ["💰 Deity: Lodyssa (God of Wealth / Midas)"] = Vector3.new(5213.0, 660.0, -4347.7),
    ["💀 Quest: Dead King (Reaper Enchant)"] = Vector3.new(2623.8, 556.4, -4660.0),
    ["🩸 Quest: Jyphar (Cursed Enchant)"] = Vector3.new(7246.1, 619.2, -4672.5),
    ["🌌 Quest: El'heith (Astra)"] = Vector3.new(10883.0, 1573.4, -3489.5),
    ["🔮 Master: The Soulmaster (Soul Awakening)"] = Vector3.new(-44.9, 574.8, -5467.4),
    ["🏺 Spirit: Staarun & Aderyn (Spirit Domain)"] = Vector3.new(789.3, 233.0, 2053.5),
    ["💀 Quest: Bone Man (Necromancy)"] = Vector3.new(1397.0, 610.3, -4097.6),
    ["🌟 Peak: Seraphon (Heavens Point)"] = Vector3.new(13.9, 4741.6, -2113.1),
    ["🔥 Chaos: Thuriaz (Chaos Path)"] = Vector3.new(2151.2, 519.8, -3394.1),
    ["🕊️ Order: Prelate Fyran (Order Path)"] = Vector3.new(8459.8, 822.4, -5885.1),

    -- ⚒️ Town Merchants & Services
    ["⚒️ Blacksmith (Westwood)"] = Vector3.new(8465.8, 821.8, -5589.8),
    ["⚒️ Blacksmith (Caldera)"] = Vector3.new(4921.8, 657.9, -4162.3),
    ["⚒️ Blacksmith (Sanctuary)"] = Vector3.new(2079.6, 382.7, -2903.1),
    ["💊 Doctor (Westwood)"] = Vector3.new(8079.1, 822.4, -5478.8),
    ["💊 Doctor (Caldera)"] = Vector3.new(5035.6, 658.1, -4407.9),
    ["💊 Doctor (Desert)"] = Vector3.new(2790.2, 615.7, -3837.2),
    ["💰 Banker (Westwood)"] = Vector3.new(8470.3, 823.6, -5824.3),
    ["💰 Banker (Caldera)"] = Vector3.new(5184.7, 657.7, -4266.2),
    ["🛒 Merchant (Westwood)"] = Vector3.new(8473.8, 823.6, -5906.5),
    ["🛒 Merchant (Caldera)"] = Vector3.new(5132.9, 658.0, -4124.2),
    ["🌿 Apothecarian (Caldera)"] = Vector3.new(5131.5, 657.8, -4355.9),
    ["🌿 Apothecarian (Westwood)"] = Vector3.new(8388.3, 822.9, -5904.8),
    ["✨ Enchanter (Caldera)"] = Vector3.new(5045.7, 657.5, -4234.2),
}

local Teleporter = {
    active = false,
}

local function teleportToLocation(targetPos)
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
            return
        end

        local height = Options.TeleportHeight and Options.TeleportHeight.Value or 1500
        local speed = Options.TeleportSpeed and Options.TeleportSpeed.Value or 200

        Library:Notify(string.format("🚀 Starting Sky-Tween (Alt: %d, Spd: %d)...", height, speed), 3)

        local currentPos = root.Position
        local skyY = math.max(height, currentPos.Y + 200, targetPos.Y + 200)

        local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), speed, function() return Teleporter.active end)
        if not s1 or not Teleporter.active then
            disableFlightState()
            Teleporter.active = false
            return
        end

        local s2 = smoothTweenTo(CFrame.new(targetPos.X, skyY, targetPos.Z), speed, function() return Teleporter.active end)
        if not s2 or not Teleporter.active then
            disableFlightState()
            Teleporter.active = false
            return
        end

        local s3 = smoothTweenTo(CFrame.new(targetPos.X, targetPos.Y + 4, targetPos.Z), speed, function() return Teleporter.active end)

        disableFlightState()
        Teleporter.active = false
        if s3 then
            Library:Notify("✅ Arrived safely at destination!", 3)
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
    ["Crylight"]        = Color3.fromRGB(0, 255, 255),
    ["Cryastem"]        = Color3.fromRGB(0, 180, 255),
    ["Hightail"]        = Color3.fromRGB(255, 140, 0),
    ["Everthistle"]     = Color3.fromRGB(180, 0, 255),
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

local activeESP = {}

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
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
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

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local localRoot = char and char:FindFirstChild("HumanoidRootPart")
    local espEnabled = Toggles.MasterESP and Toggles.MasterESP.Value
    local filterMode = Options.ESPFilterMode and Options.ESPFilterMode.Value or "All"
    local showDist = Toggles.ESPShowDistance and Toggles.ESPShowDistance.Value
    local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 10000
    local whitelist = (Options.ESPWhitelist and Options.ESPWhitelist.Value) or {}

    for inst, data in pairs(activeESP) do
        if not inst or not inst.Parent then
            removeESP(inst)
        else
            local isVisible = false
            if espEnabled and localRoot then
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
                    data.label.TextColor3 = data.color
                    data.billboard.Enabled = true
                else
                    data.billboard.Enabled = false
                end
            else
                data.billboard.Enabled = false
            end
        end
    end
end)

workspace.DescendantAdded:Connect(function(desc)
    if ESP_Colors[desc.Name] then createESP(desc) end
end)
workspace.DescendantRemoving:Connect(removeESP)

for _, desc in ipairs(workspace:GetDescendants()) do
    if ESP_Colors[desc.Name] then createESP(desc) end
end

-- =============================================================================
-- XÂY DỰNG GIAO DIỆN LINORIALIB (TABS & GROUPBOXES)
-- =============================================================================
local Window = Library:CreateWindow({
    Title = "Arcane Lineage • Master Hub",
    Center = true,
    AutoShow = true,
    TabPadding = 4,
    MenuFadeTime = 0.2
})

local Tabs = {
    AutoFarm = Window:AddTab("💎 Farm"),
    AutoQTE  = Window:AddTab("⚔️ Combat"),
    Movement = Window:AddTab("🏃 Move"),
    Teleport = Window:AddTab("🌐 Teleport"),
    Visuals  = Window:AddTab("👁️ Visuals"),
    Settings = Window:AddTab("⚙️ Settings"),
}

-- -----------------------------------------------------------------------------
-- TAB 1: AUTO FARM (INGREDIENTS & ORE MINING)
-- -----------------------------------------------------------------------------
local FarmGroup  = Tabs.AutoFarm:AddLeftGroupbox("🌿 Ingredient Auto Hunter")
local MineGroup  = Tabs.AutoFarm:AddLeftGroupbox("⛏️ Auto Mine Ores")
local LevelGroup = Tabs.AutoFarm:AddRightGroupbox("⚔️ Auto Farm Level & Mobs")
local HopGroup   = Tabs.AutoFarm:AddRightGroupbox("🌐 Server Hop & Webhook")

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
        "Carnastool", "Driproot", "Cursed Shroom", "Cursed Shroom 2",
        "Mushrooms", "Bones", "Branch Pile"
    },
    Default = { "Crylight" },
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
    Default = { "Ferrus", "Aestic", "Laneus" },
    Multi = true,
    Text = "Target Ores to Mine",
})

MineGroup:AddToggle("AutoBuyPickaxe", {
    Text = "Auto Buy Pickaxe if Missing (50g)",
    Default = true,
    Tooltip = "Nếu trong túi/balo chưa có cuốc, sẽ tự động bay tới Caldera để mua cuốc (50 Gold)",
})

MineGroup:AddSlider("MineTimeout", {
    Text = "Mine Node Timeout (s)",
    Default = 12,
    Min = 3,
    Max = 30,
    Rounding = 0,
})

MineGroup:AddButton({
    Text = "⛏️ Mine Ores Now",
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
        "Level 1 - 20 (Underground)",
        "Level 20 - 50 (Coming Soon)"
    },
    Default = 1,
    Multi = false,
    Text = "Farm Level Mode",
    Tooltip = "Level 1-20: Tween xuống lòng đất an toàn, tránh người chơi khác nhìn thấy\nLevel 20-50: Tùy chọn nâng cao tiếp theo",
})

LevelGroup:AddToggle("AutoMeditate", {
    Text = "Auto Meditate & Level Up (Essence Cap)",
    Default = true,
    Tooltip = "Khi tích lũy đủ Essence (Cap), tự động bay chớp nhoáng tới chiếu thiền đổi cấp qua Aretim rồi quay lại bãi ngầm",
})

LevelGroup:AddSlider("EssenceThreshold", {
    Text = "Essence Meditate Threshold",
    Default = 40,
    Min = 10,
    Max = 300,
    Rounding = 0,
    Tooltip = "Số lượng Essence tích lũy để kích hoạt đi thiền đổi cấp",
})

LevelGroup:AddToggle("AutoAllocateStats", {
    Text = "Auto Allocate Stats",
    Default = true,
    Tooltip = "Tự động phân bổ StatPoints theo các mốc Target Stats bên dưới",
})

LevelGroup:AddSlider("TargetStrength", {
    Text = "Target Strength",
    Default = 20,
    Min = 0,
    Max = 60,
    Rounding = 0,
})

LevelGroup:AddSlider("TargetEndurance", {
    Text = "Target Endurance",
    Default = 20,
    Min = 0,
    Max = 60,
    Rounding = 0,
})

LevelGroup:AddSlider("TargetSpeed", {
    Text = "Target Speed",
    Default = 10,
    Min = 0,
    Max = 60,
    Rounding = 0,
})

LevelGroup:AddSlider("TargetArcane", {
    Text = "Target Arcane",
    Default = 0,
    Min = 0,
    Max = 60,
    Rounding = 0,
})

LevelGroup:AddSlider("TargetLuck", {
    Text = "Target Luck",
    Default = 10,
    Min = 0,
    Max = 60,
    Rounding = 0,
})

LevelGroup:AddDropdown("SelectedCombatAction", {
    Values = {
        "Strike (Basic Attack)",
        "Auto Smart (Best Skill -> Strike)",
        "First Available Skill (Fallback Strike)",
        "Custom Skill Name"
    },
    Default = 1,
    Multi = false,
    Text = "Combat Attack / Skill Action",
})

LevelGroup:AddInput("CustomSkillName", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Custom Skill Name",
    Placeholder = "Ví dụ: Poison Fan, Slash, Fireball...",
})

LevelGroup:AddDropdown("TargetPriority", {
    Values = {
        "First Enemy",
        "Last Enemy",
        "Random Enemy"
    },
    Default = 1,
    Multi = false,
    Text = "Enemy Target Priority",
})

LevelGroup:AddSlider("CombatDelay", {
    Text = "Turn Action Delay (s)",
    Default = 0.4,
    Min = 0.1,
    Max = 2.0,
    Rounding = 1,
})

LevelGroup:AddButton({
    Text = "🚀 Tween to Underground Spot Now",
    Func = function()
        LevelFarmer.running = true
        teleportToUndergroundSpot(LevelFarmer.farmSpotLv1_20)
    end,
})

LevelGroup:AddButton({
    Text = "🧘 Meditate & Level Up Now",
    Func = function()
        task.spawn(function()
            performMeditationAndLevelUp()
        end)
    end,
})

HopGroup:AddToggle("AutoServerHop", {
    Text = "Auto Server Hop",
    Default = false,
    Tooltip = "Tự động đổi server khi lụm xong hoặc khi server không có nguyên liệu",
})

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

HopGroup:AddInput("DiscordWebhook", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Discord Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
})

HopGroup:AddToggle("NotifyOnHarvest", {
    Text = "Notify On Harvest Success",
    Default = false,
})

HopGroup:AddButton({
    Text = "Hop Server Now",
    Func = function() ServerHopper.hop() end,
    DoubleClick = false,
})

-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- TAB 2: AUTO COMBAT QTE
-- -----------------------------------------------------------------------------
local CombatGroup = Tabs.AutoQTE:AddLeftGroupbox("⚡ Auto Combat & Minigames QTE")

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
        "Fist / Cestus (Combos)",
        "Chest Lockpick"
    },
    Default = {
        "Auto Dodge / Block",
        "Sword (Window Strike)",
        "Dagger (Weakpoints)",
        "Hammer (Power Bar)",
        "Axe (Equilibrium)",
        "Fist / Cestus (Combos)",
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

-- -----------------------------------------------------------------------------
-- TAB 3: MOVEMENT CONTROLLER (WITH FULL KEYBIND PICKERS)
-- -----------------------------------------------------------------------------
local FlyGroup = Tabs.Movement:AddLeftGroupbox("✈️ Flight & NoClip")
local SpeedGroup = Tabs.Movement:AddRightGroupbox("⚡ Speed & Jump")

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
-- TAB 4: TELEPORT SUITE (ALL TRAINERS, TOWNS, CHURCH, DESERT, MERCHANTS)
-- -----------------------------------------------------------------------------
local TeleportGroup = Tabs.Teleport:AddLeftGroupbox("🌐 Sky-Tween Teleport")
local QuickWarpGroup = Tabs.Teleport:AddRightGroupbox("📍 Quick Warps")

local locationNames = {}
for name, _ in pairs(KeyLocations) do table.insert(locationNames, name) end
table.sort(locationNames)

TeleportGroup:AddDropdown("SelectedTeleportLoc", {
    Values = locationNames,
    Default = 1,
    Multi = false,
    Text = "Select Destination",
})

TeleportGroup:AddSlider("TeleportHeight", {
    Text = "Flight Altitude / Height (Y)",
    Default = 1500,
    Min = 500,
    Max = 3000,
    Rounding = 0,
})

TeleportGroup:AddSlider("TeleportSpeed", {
    Text = "Flight Speed (Studs/s)",
    Default = 200,
    Min = 50,
    Max = 500,
    Rounding = 0,
})

TeleportGroup:AddButton({
    Text = "🚀 Start Teleport",
    Func = function()
        local locName = Options.SelectedTeleportLoc and Options.SelectedTeleportLoc.Value
        local pos = locName and KeyLocations[locName]
        if pos then
            teleportToLocation(pos)
        else
            Library:Notify("Please select a valid destination!", 3)
        end
    end
})

TeleportGroup:AddButton({
    Text = "🛑 Cancel Teleport",
    Func = cancelTeleport
})

QuickWarpGroup:AddButton("🏛️ Westwood Heart", function() teleportToLocation(KeyLocations["🏛️ Westwood Heart"]) end)
QuickWarpGroup:AddButton("🌋 Caldera Town", function() teleportToLocation(KeyLocations["🌋 Caldera Town"]) end)
QuickWarpGroup:AddButton("🏜️ Desert", function() teleportToLocation(KeyLocations["🏜️ Desert"]) end)
QuickWarpGroup:AddButton("⛪ Church", function() teleportToLocation(KeyLocations["⛪ Church (Heavens Point)"]) end)
QuickWarpGroup:AddButton("⚔️ Sanctuary of Blades", function() teleportToLocation(KeyLocations["⚔️ Sanctuary of Blades"]) end)

-- -----------------------------------------------------------------------------
-- TAB 5: VISUALS & FPS BOOSTER
-- -----------------------------------------------------------------------------
local ESPGroup = Tabs.Visuals:AddLeftGroupbox("👁️ Ingredient ESP")
local FilterGroup = Tabs.Visuals:AddLeftGroupbox("🎯 Filters & Categories")
local FPSGroup = Tabs.Visuals:AddRightGroupbox("⚡ FPS Booster")
local OptGroup = Tabs.Visuals:AddRightGroupbox("🛠️ Optimization & RAM")

local FPSBooster = {
    originalFogEnd = (Lighting and Lighting.FogEnd) or 100000,
    originalFogStart = (Lighting and Lighting.FogStart) or 0,
    originalGlobalShadows = (Lighting and Lighting.GlobalShadows) or true,
}

local function applyFPSBoost()
    task.spawn(function()
        pcall(function()
            local isBoost = Toggles.EnableFPSBoost and Toggles.EnableFPSBoost.Value
            if isBoost then
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                Lighting.FogStart = 9e9

                local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    atmosphere.Density = 0
                    atmosphere.Haze = 0
                    atmosphere.Glare = 0
                end

                for _, effect in ipairs(Lighting:GetChildren()) do
                    if effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("ColorCorrectionEffect") then
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
                local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    atmosphere.Density = 0.3
                end
            end
        end)
    end)
end

local function applyTreeRemoval()
    task.spawn(function()
        pcall(function()
            local hideTrees = Toggles.RemoveTrees and Toggles.RemoveTrees.Value
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and not obj:FindFirstChildOfClass("Humanoid") and not obj:FindFirstChild("ClickDetector") then
                    local name = obj.Name:lower()
                    if name:find("tree") or name:find("bush") or name:find("leaf") or name:find("foliage") or name:find("grass") or name:find("plant") then
                        for _, p in ipairs(obj:GetDescendants()) do
                            if p:IsA("BasePart") then
                                p.Transparency = hideTrees and 1 or 0
                                p.CastShadow = not hideTrees
                            end
                        end
                    end
                end
            end
        end)
    end)
end

local function applyLowGraphics()
    task.spawn(function()
        pcall(function()
            local isLow = Toggles.LowGraphics and Toggles.LowGraphics.Value
            for _, p in ipairs(workspace:GetDescendants()) do
                if p:IsA("BasePart") and not (LocalPlayer.Character and p:IsDescendantOf(LocalPlayer.Character)) then
                    if isLow then
                        p.Material = Enum.Material.SmoothPlastic
                        p.Reflectance = 0
                        p.CastShadow = false
                    end
                elseif p:IsA("ParticleEmitter") or p:IsA("Smoke") or p:IsA("Fire") or p:IsA("Sparkles") or p:IsA("Trail") then
                    if not (LocalPlayer.Character and p:IsDescendantOf(LocalPlayer.Character)) then
                        p.Enabled = not isLow
                    end
                end
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
        "Carnastool", "Driproot", "Cursed Shroom", "Cursed Shroom 2",
        "Mushrooms", "Bones", "Branch Pile", "Ferrus", "Aestic", "Laneus"
    },
    Default = { "Crylight", "Cryastem", "Everthistle", "Hightail" },
    Multi = true,
    Text = "Whitelist Selection",
})

FPSGroup:AddToggle("EnableFPSBoost", {
    Text = "Master FPS Boost (No Fog/Shadows)",
    Default = false,
    Callback = function(val)
        applyFPSBoost()
    end
})

FPSGroup:AddToggle("RemoveTrees", {
    Text = "Remove Trees / Foliage / Grass",
    Default = false,
    Callback = function(val)
        applyTreeRemoval()
    end
})

FPSGroup:AddToggle("LowGraphics", {
    Text = "Smooth Plastic / No Particles",
    Default = false,
    Callback = function(val)
        applyLowGraphics()
    end
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

OptGroup:AddButton("⚡ Instant Clean RAM / Garbage", function()
    collectgarbage("collect")
    Library:Notify("RAM / Garbage Collection executed!", 3)
end)

OptGroup:AddButton("🌫️ Remove All Fog Permanently", function()
    Lighting.FogEnd = 9e9
    Lighting.FogStart = 9e9
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then atmo.Density = 0 end
    Library:Notify("All Fog & Haze removed!", 3)
end)

-- -----------------------------------------------------------------------------
-- TAB 6: SETTINGS / CONFIG
-- -----------------------------------------------------------------------------
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

ThemeManager:SetFolder("ArcaneHub")
SaveManager:SetFolder("ArcaneHub/Configs")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

local MenuGroup = Tabs.Settings:AddRightGroupbox("Menu Settings")

MenuGroup:AddButton("Unload Script", function()
    pcall(function() removeUndergroundPlatform() end)
    Library:Unload()
end)

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "None",
    NoUI = true,
    Text = "Menu keybind"
})

Library.ToggleKeybind = Options.MenuKeybind

SaveManager:LoadAutoloadConfig()

-- =============================================================================
-- KHỞI CHẠY CHU TRÌNH TỰ ĐỘNG
-- =============================================================================
shared.ArcaneHub = Library

if Toggles.AutoFarmCrylight and Toggles.AutoFarmCrylight.Value then
    Farmer.runCycle()
end
if Toggles.AutoMineOre and Toggles.AutoMineOre.Value then
    Miner.runCycle()
end
if Toggles.AutoFarmLevel and Toggles.AutoFarmLevel.Value then
    LevelFarmer.runCycle()
end
