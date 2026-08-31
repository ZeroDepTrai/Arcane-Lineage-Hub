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
    warn("[ArcaneHub] ❌ Không thể tải LinoriaLib từ GitHub! Vui lòng thử lại sau vài giây.")
    return
end

local Library = loadstring(libSource)()
local ThemeManager = themeSource and loadstring(themeSource)() or nil
local SaveManager = saveSource and loadstring(saveSource)() or nil

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

            if Toggles.AutoLoadOnChangingServer and Toggles.AutoLoadOnChangingServer.Value then
                queueTeleportScript()
            end
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

registerConnection(TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    warn(string.format("[ServerHop] ❌ Teleport thất bại: %s (%s). Đang đổi server khác ngay...", tostring(teleportResult), tostring(errorMessage)))
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

    -- 1. Ưu tiên quét cục bộ từ targetPos.Y + 25 xuống -100 studs (bắt sàn hang động / trong nhà / mặt đất gần)
    local localOrigin = Vector3.new(targetPos.X, targetPos.Y + 25, targetPos.Z)
    local localHit = workspace:Raycast(localOrigin, Vector3.new(0, -120, 0), rayParams)
    if localHit then
        return Vector3.new(targetPos.X, localHit.Position.Y + 3.0, targetPos.Z)
    end

    -- 2. Quét từ trên cao (+250 studs) xuống nếu mục tiêu ở ngoài trời
    local highOrigin = Vector3.new(targetPos.X, targetPos.Y + 250, targetPos.Z)
    local highHit = workspace:Raycast(highOrigin, Vector3.new(0, -500, 0), rayParams)
    if highHit then
        return Vector3.new(targetPos.X, highHit.Position.Y + 3.0, targetPos.Z)
    end

    -- 3. Fallback an toàn nếu chưa stream chunk
    return Vector3.new(targetPos.X, targetPos.Y + 3.0, targetPos.Z)
end

local function calculateSafeStandPosition(targetPos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local curPos = root and root.Position or (targetPos + Vector3.new(0, 0, 4))
    
    local flatDir = Vector3.new(curPos.X - targetPos.X, 0, curPos.Z - targetPos.Z)
    if flatDir.Magnitude < 0.1 then flatDir = Vector3.new(0, 0, 3.5) end
    
    -- Đứng cách tâm mỏ quặng 3.5 studs và tự động bắt sàn chuẩn xác
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

    -- Nếu đã đứng ngay sát quặng/item (< 12 studs): Xoay mặt vào mục tiêu
    if distance < 12 then
        root.CFrame = CFrame.lookAt(safeArrivalPos, Vector3.new(targetPosition.X, safeArrivalPos.Y, targetPosition.Z))
        return true
    end

    -- Bay Sky-Tween an toàn 3 pha trên tầng không
    enableFlightState()

    local cruiseSpeed = Options.CruiseSpeed and Options.CruiseSpeed.Value or 180
    local skyHeight = Options.SkyHeight and Options.SkyHeight.Value or 1500
    local ascendSpeed = Options.AscendSpeed and Options.AscendSpeed.Value or 150
    local descendSpeed = Options.DescendSpeed and Options.DescendSpeed.Value or 150

    local skyY = math.max(skyHeight, currentPos.Y + 200, targetPosition.Y + 200)

    -- Pha 1: Bay thẳng đứng lên trời cao
    local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), ascendSpeed, cancelFn, true)
    if not s1 or not cancelFn() then
        disableFlightState()
        return false
    end

    -- Pha 2: Lướt ngang trên tầng không (Giữ nguyên FlightState)
    local s2 = smoothTweenTo(CFrame.new(safeArrivalPos.X, skyY, safeArrivalPos.Z), cruiseSpeed, cancelFn, true)
    if not s2 or not cancelFn() then
        disableFlightState()
        return false
    end

    -- Pha 3: Hạ cánh xuống điểm đứng an toàn bên ngoài mỏ quặng / item
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

            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local curPos = root and root.Position or Vector3.zero

            -- Sắp xếp Nearest Neighbor để gom cụm lụm sạch các item gần nhau trước
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
                    print(string.format("[AutoFarm] 🎯 [%d/%d] Đang thu hoạch %s tại (%.1f, %.1f, %.1f)...", i, #harvestList, itemName, targetPos.X, targetPos.Y, targetPos.Z))

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
-- COMBAT STATE DETECTOR
-- =============================================================================
local function isInCombat()
    local char = LocalPlayer.Character
    if not char then return false end

    -- 1. Kiểm tra ReplicatedStorage.Fights (Nguồn chân lý chính xác 100% của server)
    local RS = game:GetService("ReplicatedStorage")
    local rsFights = RS:FindFirstChild("Fights")
    if rsFights then
        for _, fight in ipairs(rsFights:GetChildren()) do
            local t1 = fight:FindFirstChild("Team1")
            local t2 = fight:FindFirstChild("Team2")
            if (t1 and (t1:FindFirstChild(LocalPlayer.Name) or t1:FindFirstChild(char.Name))) or
               (t2 and (t2:FindFirstChild(LocalPlayer.Name) or t2:FindFirstChild(char.Name))) then
                return true
            end
        end
    end

    -- 2. Kiểm tra các thành phần giao diện Combat trong PlayerGui
    local pgui = PlayerGui
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    if combatGui and combatGui.Enabled then
        local actionBG = combatGui:FindFirstChild("ActionBG")
        local deciding = combatGui:FindFirstChild("Deciding")
        local initiative = combatGui:FindFirstChild("InitiativeBG")
        local dodge = combatGui:FindFirstChild("DodgeQTE")
        if (actionBG and actionBG.Visible) or (deciding and deciding.Visible) or (initiative and initiative.Visible) or (dodge and dodge.Visible) then
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
        -- Tự động nhận diện cấp độ người chơi (Lv < 30 bay về bãi ngầm Caldera, Lv >= 30 bay về khối an toàn Desert)
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
        warn("[AutoFarmLevel] ❌ Không tìm thấy HumanoidRootPart hoặc Humanoid!")
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

    print(string.format("[AutoFarmLevel] 🚀 Bắt đầu Sky-Tween bay tới bãi farm an toàn tại (%.1f, %.1f, %.1f) - Khoảng cách: %.1f studs...", targetCF.X, targetCF.Y, targetCF.Z, distance))

    ensureUndergroundPlatform(targetSpot)
    enableLevelFarmerNoclip()

    local skyHeight = 1500
    local skyY = math.max(skyHeight, currentPos.Y + 200, targetSpot.Y + 200)

    -- Phase 1: Bay thẳng lên trời thật cao
    local s1 = smoothTweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), 200, function() return LevelFarmer.running end)
    if not s1 or not LevelFarmer.running then return false end

    -- Phase 2: Bay ngang trên không trung tới vị trí bãi farm
    local s2 = smoothTweenTo(CFrame.new(targetSpot.X, skyY, targetSpot.Z), 240, function() return LevelFarmer.running end)
    if not s2 or not LevelFarmer.running then return false end

    -- Phase 3: Hạ cánh thẳng đứng xuống bãi farm (xuyên khối / xuyên đất an toàn)
    local s3 = smoothTweenTo(targetCF, 180, function() return LevelFarmer.running end)
    if s3 then
        root.CFrame = targetCF
        print("[AutoFarmLevel] ✅ Đã hạ cánh an toàn tại bãi farm ẩn dưới lòng đất!")
    end
    return s3
end

local function safeClickButton(btn)
    if not btn then return false end
    local clicked = false
    if firesignal then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.MouseButton1Up) end)
        pcall(function() firesignal(btn.Activated) end)
        clicked = true
    end
    if getconnections then
        pcall(function()
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                if c.Function then c.Function() clicked = true
                elseif c.Fire then c:Fire() clicked = true end
            end
        end)
        pcall(function()
            for _, c in ipairs(getconnections(btn.MouseButton1Down)) do
                if c.Function then c.Function() clicked = true
                elseif c.Fire then c:Fire() clicked = true end
            end
        end)
        pcall(function()
            for _, c in ipairs(getconnections(btn.Activated)) do
                if c.Function then c.Function() clicked = true
                elseif c.Fire then c:Fire() clicked = true end
            end
        end)
    end
    return clicked
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
    print(string.format("[AutoStats] 🗑️ Đã xóa sạch cache điểm stats của tài khoản '%s'!", username))
    Library:Notify(string.format("✅ Cleared stats cache for '%s'!", username), 4)
end

local function allocateStats()
    if not (Toggles.AutoAllocateStats and Toggles.AutoAllocateStats.Value) then return end

    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    local lvlUpGui = pgui:FindFirstChild("LevelUp")
    
    -- 1. Chờ bảng LevelUp xuất hiện và Enabled (server game có độ trễ ~2.5s khi mở hội thoại Aretim)
    local waitStart = os.clock()
    while os.clock() - waitStart < 8.0 do
        lvlUpGui = pgui:FindFirstChild("LevelUp")
        if lvlUpGui and lvlUpGui.Enabled and lvlUpGui:FindFirstChild("Container") then
            break
        end
        task.wait(0.3)
    end

    if not (lvlUpGui and lvlUpGui.Enabled and lvlUpGui:FindFirstChild("Container")) then
        print("[AutoFarmLevel] ℹ️ Không phát hiện bảng LevelUp xuất hiện.")
        return
    end

    local container = lvlUpGui.Container
    local header = container:FindFirstChild("Header")
    local pointsLabel = header and header:FindFirstChild("PointsLeft")
    local pointsText = pointsLabel and pointsLabel.Text or ""
    local availPoints = tonumber(pointsText:match("(%d+)")) or 0

    local userStats, allCache, username = getUserStatsCache()
    print(string.format("[AutoFarmLevel] 🌟 [LevelUp GUI] Tài khoản '%s' có %d Stat Points chưa cộng.", username, availPoints))

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

    -- 2. Đọc cấu hình Sliders mục tiêu
    local strSlider = Options.TargetStrength and Options.TargetStrength.Value or 20
    local arcSlider = Options.TargetArcane and Options.TargetArcane.Value or 0
    local endSlider = Options.TargetEndurance and Options.TargetEndurance.Value or 20
    local spdSlider = Options.TargetSpeed and Options.TargetSpeed.Value or 10
    local lckSlider = Options.TargetLuck and Options.TargetLuck.Value or 10

    -- Target điểm cần đầu tư thủ công = max(0, slider - 10) do +10 điểm free từ milestone cấp độ
    local strMaxAdd = math.max(0, strSlider - 10)
    local arcMaxAdd = math.max(0, arcSlider - 10)
    local endMaxAdd = math.max(0, endSlider - 10)
    local spdMaxAdd = math.max(0, spdSlider - 10)
    local lckMaxAdd = math.max(0, lckSlider - 10)

    -- Số điểm còn thiếu so với cache đã nâng của tài khoản này
    local strNeeded = math.max(0, strMaxAdd - (userStats.Strength or 0))
    local arcNeeded = math.max(0, arcMaxAdd - (userStats.Arcane or 0))
    local endNeeded = math.max(0, endMaxAdd - (userStats.Endurance or 0))
    local spdNeeded = math.max(0, spdMaxAdd - (userStats.Speed or 0))
    local lckNeeded = math.max(0, lckMaxAdd - (userStats.Luck or 0))

    print(string.format("[AutoStats] 📊 Cache hiện tại của '%s': Str:%d/%d, End:%d/%d, Spd:%d/%d, Arc:%d/%d, Lck:%d/%d",
        username,
        userStats.Strength or 0, strMaxAdd,
        userStats.Endurance or 0, endMaxAdd,
        userStats.Speed or 0, spdMaxAdd,
        userStats.Arcane or 0, arcMaxAdd,
        userStats.Luck or 0, lckMaxAdd
    ))

    -- Phân bổ điểm
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

    -- Nếu còn thừa điểm (Game bắt buộc phân bổ hết 100% u12 == 0 mới cho bấm Finish):
    -- Tự động dồn vào chỉ số có target slider cao nhất
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

    -- 3. Click nút tăng điểm chuẩn xác vào PlayerGui.LevelUp
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
            warn("[AutoStats] ⚠️ Không tìm thấy nút:", statName .. "Up")
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

    -- Cập nhật Cache vĩnh viễn cho tài khoản
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
        print(string.format("[AutoFarmLevel] ✅ Đã phân bổ Stats cho '%s': Str+%d (Tổng %d/%d), End+%d (Tổng %d/%d), Spd+%d (Tổng %d/%d), Arc+%d (Tổng %d/%d), Luck+%d (Tổng %d/%d) và bấm Finish!", 
            username,
            strAdd, userStats.Strength, strMaxAdd,
            endAdd, userStats.Endurance, endMaxAdd,
            spdAdd, userStats.Speed, spdMaxAdd,
            arcAdd, userStats.Arcane, arcMaxAdd,
            lckAdd, userStats.Luck, lckMaxAdd
        ))
    end

    -- Chờ bảng LevelUp đóng hoàn toàn trước khi tiếp tục
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
        print("[AutoFarmLevel] ❌ Không tìm thấy MeditationMat.")
        return false
    end

    local matPos = nearestMat:GetPivot().Position
    local targetCF = CFrame.new(matPos.X, matPos.Y + 1.2, matPos.Z)

    print(string.format("[AutoFarmLevel] 🧘 Đang bay tới Chiếu Thiền tại (%.1f, %.1f, %.1f)...", matPos.X, matPos.Y, matPos.Z))

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

    -- 2. Bấm phím M chuẩn 100% người thật qua VirtualInputManager (Duy nhất 1 lần)
    print("[AutoFarmLevel] 🧘 Bắt đầu bấm phím M ngồi thiền vào Soul Corridor...")
    simulateKeyPress(Enum.KeyCode.M, 0.12)

    -- Theo dõi trạng thái chuyển cảnh (Chờ tối đa 8.5s cho animation ngồi và fade màn hình)
    local waited = 0
    while not isInSoulCorridor() and waited < 8.5 do
        task.wait(0.5)
        waited = waited + 0.5
    end

    if isInSoulCorridor() then
        print("[AutoFarmLevel] 🌌 Đã vào Hành Lang Linh Hồn (Soul Corridor) thành công!")
        task.wait(1.0)

        -- 3. Di chuyển tới gặp NPC Aretim (Cập nhật lại tham chiếu nhân vật tại Soul Corridor)
        local scChar = LocalPlayer.Character
        local scRoot = scChar and scChar:FindFirstChild("HumanoidRootPart")
        local scHum = scChar and scChar:FindFirstChildOfClass("Humanoid")
        if not scRoot or not scHum then return false end

        local aretimModel = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Aretim")
        local aretimPos = aretimModel and aretimModel:GetPivot().Position or LevelFarmer.aretimPos
        local aretimTargetCF = CFrame.lookAt(Vector3.new(aretimPos.X, aretimPos.Y + 1.5, aretimPos.Z - 4.0), aretimPos)

        print(string.format("[AutoFarmLevel] 🚶 Đang bay tới gặp NPC Aretim tại (%.1f, %.1f, %.1f)...", aretimPos.X, aretimPos.Y, aretimPos.Z))
        
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

        -- 4. Kích hoạt hội thoại và xác nhận NPCDialogue thực sự hiển thị
        local pgui = PlayerGui
        local diag = pgui:FindFirstChild("NPCDialogue")
        local diagOpened = false
        local diagStart = os.clock()

        print("[AutoFarmLevel] 💬 Đang kích hoạt hội thoại với Aretim...")
        while (os.clock() - diagStart < 6.0) do
            diag = pgui:FindFirstChild("NPCDialogue")
            if diag and diag.Enabled then
                diagOpened = true
                print("[AutoFarmLevel] 💬 Giao diện hội thoại Aretim đã mở thành công!")
                break
            end

            scRoot.CFrame = aretimTargetCF
            local aretimProx = aretimModel and aretimModel:FindFirstChildWhichIsA("ProximityPrompt", true)
            if aretimProx and fireproximityprompt then
                fireproximityprompt(aretimProx)
            end
            task.wait(0.5)
        end

        -- 5. Tự động chọn lựa chọn thăng cấp tối đa
        if diagOpened and diag and diag.Enabled then
            task.wait(0.5)
            local optionsFrame = diag:FindFirstChild("Options", true)
            if optionsFrame then
                local clicked = false
                -- Ưu tiên 1: Tăng nhiều cấp (Show me as much light as I can handle. (+ X LVLS))
                for _, opt in ipairs(optionsFrame:GetChildren()) do
                    if opt:IsA("TextButton") and opt.Visible then
                        local txt = opt.Text:lower()
                        if (txt:find("as much light") or txt:find("lvls")) and not txt:find("+ 0 lvls") then
                            print(string.format("[AutoFarmLevel] 🆙 Đang bấm thăng tối đa: '%s'", opt.Text))
                            safeClickButton(opt)
                            clicked = true
                            break
                        end
                    end
                end
                -- Ưu tiên 2: Tăng 1 cấp (+LVL)
                if not clicked then
                    for _, opt in ipairs(optionsFrame:GetChildren()) do
                        if opt:IsA("TextButton") and opt.Visible and opt.Text:lower():find("+lvl") and not opt.Text:lower():find("+ 0") then
                            print(string.format("[AutoFarmLevel] 🆙 Đang bấm thăng 1 cấp: '%s'", opt.Text))
                            safeClickButton(opt)
                            clicked = true
                            break
                        end
                    end
                end
                -- Nếu không đủ Essence để tăng: đóng hội thoại bằng 'Not yet.'
                if not clicked then
                    for _, opt in ipairs(optionsFrame:GetChildren()) do
                        if opt:IsA("TextButton") and opt.Visible and opt.Text:lower():find("not yet") then
                            print("[AutoFarmLevel] ℹ️ Chưa đủ Essence để thăng cấp, đóng hội thoại.")
                            safeClickButton(opt)
                            break
                        end
                    end
                end
            end
        else
            warn("[AutoFarmLevel] ⚠️ Không mở được NPCDialogue với Aretim.")
        end
        task.wait(1.5)

        -- 5. Tự động phân bổ điểm Stats theo cấu hình và hoàn tất
        allocateStats()
        task.wait(1.0)

        -- 6. Giả lập bấm phím M để thoát khỏi Soul Corridor trở lại Overworld
        print("[AutoFarmLevel] 🧘 Bấm phím M thoát thiền để trở về Overworld...")
        simulateKeyPress(Enum.KeyCode.M, 0.12)

        local exitWaited = 0
        while isInSoulCorridor() and exitWaited < 8.5 do
            task.wait(0.5)
            exitWaited = exitWaited + 0.5
        end
    else
        print("[AutoFarmLevel] ⚠️ Chưa thể vào Soul Corridor trong đợt này.")
    end

    -- 7. Quay trở lại bãi farm an toàn qua Sky-Tween
    local spot, spotDesc = getActiveFarmSpot()
    print(string.format("[AutoFarmLevel] 🚀 Đang bay trở lại bãi farm (%s) qua Sky-Tween...", spotDesc))
    flyToFarmSpot(spot)
    enableLevelFarmerNoclip()
    print("[AutoFarmLevel] 🛡️ Đã trở về bãi farm an toàn!")

    -- Reset bộ đếm Essence sau trận
    LevelFarmer.essenceBeforeCombat = getCurrentEssence()
    LevelFarmer.zeroGainFightCount = 0
    return true
end



-- [isInCombat already defined above LevelFarmer]

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

local function scanPlayerSkills()
    local skillSet = {}
    local pgui = PlayerGui
    local blacklist = {
        ["Skills"] = true, ["Element"] = true, ["Physical"] = true, ["Magic"] = true, ["Fire"] = true,
        ["Holy"] = true, ["Nature"] = true, ["Hex"] = true, ["Dark"] = true, ["Poison"] = true,
        ["Duration"] = true, ["Scaling"] = true, ["Strength"] = true, ["Arcane"] = true, ["Buff"] = true,
        ["Debuff"] = true, ["Heal"] = true, ["Speed"] = true, ["Luck"] = true, ["Cost"] = true,
        ["Cooldown"] = true, ["Active"] = true, ["Passive"] = true, ["ACTIVE"] = true, ["PASSIVE"] = true,
        ["UNEQUIP"] = true, ["Label"] = true, ["N/A"] = true, ["Button"] = true, ["Example"] = true,
        ["Info"] = true, ["Template"] = true, ["Return"] = true, ["Shadow Form"] = true,
    }

    -- 1. Quét trực tiếp từ SkillDisplay GUI (Giao diện View Skills khi ấn phím B và mở danh sách kỹ năng)
    local skillDisplay = pgui and pgui:FindFirstChild("SkillDisplay")
    if skillDisplay then
        local bodyContainer = skillDisplay:FindFirstChild("Body", true)
        local skillsFolder = bodyContainer and bodyContainer:FindFirstChild("Skills", true)
        if skillsFolder then
            for _, child in ipairs(skillsFolder:GetChildren()) do
                if (child:IsA("TextButton") or child:IsA("GuiButton") or child:IsA("TextLabel")) and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    local name = child:IsA("TextButton") and child.Text or child.Name
                    if #name > 1 and not blacklist[name] then
                        skillSet[name] = true
                    end
                end
            end
        end
    end

    -- 2. Quét từ Inventory GUI (Category Skills)
    local inv = pgui and pgui:FindFirstChild("Inventory")
    if inv then
        local invSkills = inv:FindFirstChild("Skills", true)
        local toolCont = invSkills and invSkills:FindFirstChild("ToolContainer")
        if toolCont then
            for _, child in ipairs(toolCont:GetChildren()) do
                if (child:IsA("TextButton") or child:IsA("GuiButton") or child:IsA("TextLabel")) and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    local name = child:IsA("TextButton") and child.Text or child.Name
                    if #name > 1 and not blacklist[name] then
                        skillSet[name] = true
                    end
                end
            end
        end
    end

    -- 3. Quét từ Combat AttacksPage ScrollingFrame nếu đang trong trận chiến
    local combatGui = pgui and pgui:FindFirstChild("Combat")
    local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
    local atkPage = actionBG and actionBG:FindFirstChild("AttacksPage")
    local attackFrame = atkPage and atkPage:FindFirstChild("Attack")
    local scrollFrame = attackFrame and attackFrame:FindFirstChild("ScrollingFrame")
    if scrollFrame then
        for _, btn in ipairs(scrollFrame:GetChildren()) do
            if (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) and not blacklist[btn.Name] then
                local label = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                local name = (label and label.Text ~= "" and label.Text) or btn.Name
                if #name > 1 and not blacklist[name] then
                    skillSet[name] = true
                end
            end
        end
    end

    skillSet["Strike"] = true

    local list = {}
    for name, _ in pairs(skillSet) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

-- =============================================================================
-- AUTO FIGHT ENGINE (STANDALONE COMBAT TURN & SKILL EXECUTOR)
-- =============================================================================
local AutoFight = {
    running = false,
    thread = nil,
}

local combatTurnLock = false

local function executeCombatTurn()
    if combatTurnLock then return end
    combatTurnLock = true

    local ok, err = pcall(function()
        local pgui = PlayerGui
        local combatGui = pgui and pgui:FindFirstChild("Combat")
        if not combatGui or not combatGui.Enabled then return end

        local actionBG = combatGui and combatGui:FindFirstChild("ActionBG")
        if not actionBG then return end

        local actionChoice = Options.SelectedCombatAction and Options.SelectedCombatAction.Value or "Auto Smart (Best Skill -> Strike)"
        local targetPrio = Options.TargetPriority and Options.TargetPriority.Value or "First Enemy"
        local shouldMeditateIfNoSkill = Toggles.AutoMeditateInCombat and Toggles.AutoMeditateInCombat.Value

        local ctxPage = actionBG:FindFirstChild("ContextPage")
        local atkPage = actionBG:FindFirstChild("AttacksPage")
        local header = actionBG:FindFirstChild("Header")

        -- Hàm kích hoạt Meditate trong trận (hồi phục Energy / Mana / Stamina)
        local function doCombatMeditate()
            print("[Combat] 🧘 Không có skill khả dụng -> Đang kích hoạt Meditate trong trận để hồi phục Energy / Stamina...")

            -- 1. Nếu đang ở AttacksPage hoặc bảng phụ, bấm Return về ContextPage
            local returnBtn = header and header:FindFirstChild("Return")
            if returnBtn and returnBtn.Visible then
                safeClickButton(returnBtn)
                task.wait(0.35) -- Đợi vượt qua 0.3s internal debounce của game
            end

            local medBtn = ctxPage and ctxPage:FindFirstChild("MeditateButton")
            if medBtn then
                safeClickButton(medBtn)
                task.wait(0.1)
                if firesignal then
                    pcall(function() firesignal(medBtn.MouseButton1Click) end)
                end
            end

            -- 2. Dự phòng remote trực tiếp của game
            pcall(function()
                local pti = game.ReplicatedStorage:FindFirstChild("PlayerTurnInput")
                if pti and pti:IsA("RemoteFunction") then
                    pti:InvokeServer("Meditate", false)
                end
            end)
        end

        -- 1. Chuyển sang AttacksPage nếu đang ở ContextPage để đọc danh sách skill
        if ctxPage and ctxPage.Visible then
            local atkBtn = ctxPage:FindFirstChild("AttackButton")
            if atkBtn then
                safeClickButton(atkBtn)
                task.wait(0.2)
            end
        end

        -- 2. Lựa chọn chiêu thức trong AttacksPage
        local attackFrame = atkPage and atkPage:FindFirstChild("Attack")
        local scrollFrame = attackFrame and attackFrame:FindFirstChild("ScrollingFrame")

        if scrollFrame and scrollFrame.Visible then
            local selectedSkillBtn = nil

            local function isSkillReady(btn)
                if not btn or not btn.Parent then return false end
                local cd = btn:FindFirstChild("CD", true)
                if cd and cd.Visible == true then return false end
                local sealed = btn:FindFirstChild("Sealed", true)
                if sealed and sealed.Visible == true then return false end
                return true
            end

            local function findSkillByName(targetName)
                if not targetName or targetName == "" or targetName == "None" then return nil end
                local lowerTarget = targetName:lower()
                for _, btn in ipairs(scrollFrame:GetChildren()) do
                    if isSkillReady(btn) then
                        local nameLabel = btn:FindFirstChild("SkillName", true) or btn:FindFirstChildWhichIsA("TextLabel", true)
                        local textToMatch = nameLabel and nameLabel.Text or btn.Name
                        if textToMatch:lower():find(lowerTarget) then
                            return btn
                        end
                    end
                end
                return nil
            end

            -- A. Cơ chế 1: Custom Skill Priority (Ưu tiên theo thứ tự Slot 1 -> 2 -> 3 -> 4)
            if actionChoice == "Custom Skill" or actionChoice == "Custom Priority Skills" then
                local slots = {
                    Options.CustomSkillSlot1 and Options.CustomSkillSlot1.Value,
                    Options.CustomSkillSlot2 and Options.CustomSkillSlot2.Value,
                    Options.CustomSkillSlot3 and Options.CustomSkillSlot3.Value,
                    Options.CustomSkillSlot4 and Options.CustomSkillSlot4.Value,
                }

                for _, slotName in ipairs(slots) do
                    local foundBtn = findSkillByName(slotName)
                    if foundBtn then
                        selectedSkillBtn = foundBtn
                        break
                    end
                end

                -- Nếu toàn bộ skill ưu tiên không khả dụng (đang CD, thiếu Energy, sealed...)
                if not selectedSkillBtn then
                    if shouldMeditateIfNoSkill then
                        doCombatMeditate()
                        return
                    else
                        -- Fallback về Strike đánh thường
                        selectedSkillBtn = scrollFrame:FindFirstChild("Strike") or scrollFrame:FindFirstChild("Magic Missile")
                    end
                end
            end

            -- B. Cơ chế 2: Auto Smart (Chọn skill mạnh nhất / tốn Energy cao nhất đang SẴN SÀNG)
            if not selectedSkillBtn and actionChoice:find("Auto Smart") then
                local bestSkill = nil
                local maxCost = -1
                for _, btn in ipairs(scrollFrame:GetChildren()) do
                    if isSkillReady(btn) and btn.Name ~= "Strike" and btn.Name ~= "Magic Missile" and btn.Name ~= "Frame" then
                        local costText = btn:FindFirstChild("Cost") and btn.Cost:FindFirstChild("TextLabel") and btn.Cost.TextLabel.Text or "0"
                        local costNum = tonumber(costText:match("%d+")) or 0
                        if costNum > maxCost then
                            maxCost = costNum
                            bestSkill = btn
                        end
                    end
                end

                if bestSkill then
                    selectedSkillBtn = bestSkill
                else
                    -- Không có skill đặc biệt nào sẵn sàng
                    if shouldMeditateIfNoSkill then
                        doCombatMeditate()
                        return
                    else
                        selectedSkillBtn = scrollFrame:FindFirstChild("Strike") or scrollFrame:FindFirstChild("Magic Missile")
                    end
                end
            end

            -- C. Cơ chế 3 / Fallback mặc định: Strike (Basic Attack)
            if not selectedSkillBtn or not isSkillReady(selectedSkillBtn) then
                selectedSkillBtn = scrollFrame:FindFirstChild("Strike") or scrollFrame:FindFirstChild("Magic Missile")
                if not selectedSkillBtn or not isSkillReady(selectedSkillBtn) then
                    for _, btn in ipairs(scrollFrame:GetChildren()) do
                        if isSkillReady(btn) and btn.Name ~= "Frame" and btn:IsA("GuiButton") then
                            selectedSkillBtn = btn
                            break
                        end
                    end
                end
            end

            if selectedSkillBtn then
                local skillName = selectedSkillBtn.Name
                print(string.format("[Combat] ⚔️ Đang kích hoạt đòn đánh: '%s'", skillName))
                safeClickButton(selectedSkillBtn)
                task.wait(0.25)
            elseif shouldMeditateIfNoSkill then
                doCombatMeditate()
                return
            end
        end

        -- 3. Chọn mục tiêu quái (nếu là skill đánh quái mở bảng Enemies)
        local enemiesFrame = atkPage and atkPage:FindFirstChild("Enemies")
        local enemiesScroll = enemiesFrame and (enemiesFrame:FindFirstChild("ScrollingFrame") or enemiesFrame)

        if enemiesFrame and enemiesFrame.Visible and enemiesScroll then
            local enemyButtons = {}
            for _, btn in ipairs(enemiesScroll:GetChildren()) do
                if btn:IsA("GuiButton") and btn.Visible and btn.Name ~= "Return" and btn.Name ~= "Template" then
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
                    safeClickButton(chosenEnemy)
                    task.wait(0.15)
                end
            end
        end

        -- 4. Click Go confirmation button nếu xuất hiện
        local goBtn = combatGui:FindFirstChild("Go")
        if goBtn and goBtn.Visible then
            safeClickButton(goBtn)
        end
    end)

    combatTurnLock = false
end

function AutoFight.start()
    if AutoFight.running then return end
    AutoFight.running = true

    if AutoFight.thread then
        pcall(function() task.cancel(AutoFight.thread) end)
    end

    AutoFight.thread = task.spawn(function()
        print("[AutoFight] ⚔️ Đã bật Auto Fight (Tự động đánh / tung chiêu khi đến lượt trong trận)!")
        while HubState.running and AutoFight.running do
            if isInCombat() then
                if isPlayerTurn() then
                    executeCombatTurn()
                    local combatDelay = Options.CombatDelay and Options.CombatDelay.Value or 0.4
                    task.wait(combatDelay)
                else
                    task.wait(0.2)
                end
            else
                task.wait(0.3)
            end
        end
        print("[AutoFight] ⏹️ Đã dừng Auto Fight.")
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
                print(string.format("[AutoFarmLevel] 🌙 Phát hiện trời tối (ClockTime: %.1fh) tại Deeproot Forest -> Bay lên tầng mây (Y: 1200) đứng né Sentinel of Darkness...", Lighting.ClockTime))
                flyToFarmSpot(skyPos)
                enableLevelFarmerNoclip()
            end

            -- Đứng lơ lửng an toàn trên mây cho đến khi trời sáng hoặc bị kéo vào trận
            while HubState.running and LevelFarmer.running and isNightTime() and not isInCombat() do
                local curRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if curRoot and curRoot.Position.Y < 1000 then
                    curRoot.CFrame = CFrame.new(skyPos)
                end
                task.wait(1.5)
            end

            if HubState.running and LevelFarmer.running and not isNightTime() and not isInCombat() then
                print(string.format("[AutoFarmLevel] ☀️ Trời đã sáng trở lại (ClockTime: %.1fh) -> Bay xuống bãi farm Deeproot Forest tiếp tục chiến đấu...", Lighting.ClockTime))
                flyToFarmSpot(targetSpot)
                enableLevelFarmerNoclip()
            end
            return true
        end
    end
    return false
end

function LevelFarmer.runCycle()
    LevelFarmer.running = true

    task.spawn(function()
        local spot, spotDesc = getActiveFarmSpot()
        print(string.format("[AutoFarmLevel] ⚔️ Bắt đầu Auto Farm Level - Vị trí: %s", tostring(spotDesc)))

        -- Kiểm tra né ban đêm tại Deeproot Forest nếu đang là ban đêm
        if not handleDeeprootNightSafe(spot, spotDesc) then
            -- Bay tới bãi farm an toàn bằng Sky-Tween & bật Noclip liên tục
            flyToFarmSpot(spot)
            enableLevelFarmerNoclip()
        end

        local currentAssignedSpot = spot

        while HubState.running and LevelFarmer.running do
            if isInCombat() then
                if not LevelFarmer.wasInCombat then
                    LevelFarmer.wasInCombat = true
                    LevelFarmer.essenceBeforeCombat = getCurrentEssence()
                    print(string.format("[AutoFarmLevel] ⚔️ Đã vào trận đánh mới! (Essence đầu trận: %d)", LevelFarmer.essenceBeforeCombat))
                end

                if isPlayerTurn() then
                    executeCombatTurn()
                    local combatDelay = Options.CombatDelay and Options.CombatDelay.Value or 0.4
                    task.wait(combatDelay)
                else
                    task.wait(0.25)
                end
            else
                if LevelFarmer.wasInCombat then
                    LevelFarmer.wasInCombat = false
                    print("[AutoFarmLevel] 🏆 Trận đấu kết thúc! Đang chờ server nạp thưởng Essence...")

                    local initialEssence = LevelFarmer.essenceBeforeCombat
                    local newEssence = getCurrentEssence()
                    local startWait = os.clock()

                    -- Chờ thông minh tối đa 4.0 giây: Nếu server nạp Essence sớm thì tiếp tục ngay
                    while os.clock() - startWait < 4.0 do
                        newEssence = getCurrentEssence()
                        if newEssence > initialEssence then
                            break
                        end
                        task.wait(0.3)
                    end

                    print(string.format("[AutoFarmLevel] 📊 Essence trước trận: %d | Essence sau trận: %d", initialEssence, newEssence))

                    if newEssence > initialEssence then
                        -- Đã nhận thêm Essence -> Chưa chạm Cap -> Tiếp tục farm
                        LevelFarmer.essenceBeforeCombat = newEssence
                        print(string.format("[AutoFarmLevel] 📈 Đã nhận thưởng (+%d Essence, Tổng: %d) -> Tiếp tục farm trận mới...", newEssence - initialEssence, newEssence))
                    elseif newEssence == initialEssence and newEssence >= 10 then
                        -- Sau 4.0s polling xác nhận không nhận thêm Essence -> Đã chạm Cap tối đa!
                        if Toggles.AutoMeditate and Toggles.AutoMeditate.Value then
                            print(string.format("[AutoFarmLevel] 🔮 Xác nhận Essence đã chạm Cap tối đa (%d Essence) -> Bắt đầu quy trình đi thiền...", newEssence))
                            humanoidMeditateAndLevelUp()
                        end
                    else
                        LevelFarmer.essenceBeforeCombat = newEssence
                        task.wait(0.5)
                    end
                end

                -- Tự động kiểm tra vị trí bãi farm và level khi đứng chờ ngoài trận
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

                            -- Nếu cấp độ thay đổi khiến đổi bãi farm hoặc bị văng ra xa -> Sky-Tween bay tới bãi mới
                            if targetSpot ~= currentAssignedSpot or dist > 15 or yDiff > 10 then
                                currentAssignedSpot = targetSpot
                                print(string.format("[AutoFarmLevel] 🔄 Cập nhật bãi farm (%s) -> Tiến hành Sky-Tween...", targetDesc))
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
        print("[AutoFarmLevel] ⏹️ Đã dừng Auto Farm Level.")
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

-- Lắng nghe trực tiếp Remote InventorySync của Server để nhận diện quặng vào kho ngay lập tức (0ms)
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
                        print(string.format("[AutoMine] 💎 [Server Remote] Đã nhận thành công quặng: %s (Số lượng: %s) vào túi đồ!", itmName, tostring(itm.Count or 1)))
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

    -- NẾU ĐÃ CẦM TRÊN TAY RỒI THÌ RETURN NGAY, TRÁNH GỬI LỆNH LẠI GÂY TOGGLE UNEQUIP!
    if hasPickaxeEquipped() then
        return true
    end

    -- 1. ƯU TIÊN GỌI HÀM :Equip() CHÍNH THỨC TỪ ENVIRONMENT CỦA INVENTORY SCRIPT
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

    -- 2. DỰ PHÒNG: Gửi Remote InventoryManage Equip & Use
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

    -- 3. DỰ PHÒNG: Kéo Tool từ Backpack
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
        task.wait(0.4)

        -- Bấm nút Confirm mua hàng trong PlayerGui.Chat hoặc Prompt Dialog
        local pgui = PlayerGui
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc:IsA("TextButton") and (desc.Text == "Confirm" or desc.Text == "Buy" or desc.Text == "Yes" or desc.Text == "YES") then
                if firesignal then
                    pcall(function() firesignal(desc.MouseButton1Click) end)
                    pcall(function() firesignal(desc.MouseButton1Down) end)
                end
                safeClickButton(desc)
                print("[AutoMine] ✅ Đã bấm nút Confirm mua Cuốc thành công!")
                break
            end
        end
        task.wait(0.8)
        equipPickaxe()
        Library:Notify("✅ Pickaxe bought and equipped!", 3)
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

    -- 1. Reset cờ nhận quặng của Server và lưu số lượng quặng ban đầu
    Miner.gainedOreThisNode = false
    local initialOreCount = getInventoryOreCount()

    -- 2. Đảm bảo cuốc được trang bị từ Inventory
    equipPickaxe()

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local orePart = oreModel:FindFirstChild("Ore") or oreModel:FindFirstChildWhichIsA("BasePart")
    if not orePart then return false end

    print(string.format("[AutoMine] ⛏️ Bắt đầu vung cuốc đập mỏ %s (Quặng trong kho: %d, Tốc độ: %.2fs/hit)...", oreModel.Name, initialOreCount, swingDelay))

    while HubState.running and (os.clock() - startTime < timeout) and Miner.running do
        -- A. KIỂM TRA ĐIỀU KIỆN 1: SERVER ĐÃ BẮN EVENT INVENTORYSYNC BÁO QUẶNG VÀO TÚI ĐỒ (0ms)
        if Miner.gainedOreThisNode then
            print(string.format("[AutoMine] 💎 Server xác nhận nhận %s vào túi đồ! Đào mỏ %s thành công!", Miner.lastGainedOreName, oreModel.Name))
            break
        end

        -- B. KIỂM TRA ĐIỀU KIỆN 2: TÚI ĐỒ TĂNG SỐ LƯỢNG KHOÁNG SẢN
        local currentOreCount = getInventoryOreCount()
        if currentOreCount > initialOreCount then
            print(string.format("[AutoMine] 💎 Kho đồ nhận thêm %d quặng (Từ %d -> %d)! Đào xong mỏ %s!", currentOreCount - initialOreCount, initialOreCount, currentOreCount, oreModel.Name))
            break
        end

        -- C. KIỂM TRA ĐIỀU KIỆN 3: MỎ QUẶNG ĐÃ BỊ PHÁ HỦY HOÀN TOÀN
        if not oreModel or not oreModel.Parent or not oreModel:IsDescendantOf(workspace) then
            print(string.format("[AutoMine] ✅ Mỏ %s đã bị phá hủy hoàn toàn!", oreModel and oreModel.Name or "Ore"))
            break
        end

        local currentOrePart = oreModel:FindFirstChild("Ore") or oreModel:FindFirstChildWhichIsA("BasePart")
        if not currentOrePart or not currentOrePart.Parent or not currentOrePart:IsDescendantOf(workspace) then
            print(string.format("[AutoMine] ✅ Quặng trong mỏ %s đã được khai thác xong!", oreModel.Name))
            break
        end

        -- D. Đảm bảo luôn cầm Cuốc trên tay
        if not hasPickaxeEquipped() then
            equipPickaxe()
        end

        -- E. Giữ vị trí đứng chuẩn xác 3.5 studs đối diện quặng, triệt tiêu gia tốc vật lý
        if root and currentOrePart then
            local orePos = currentOrePart.Position
            local flatDir = Vector3.new(root.Position.X - orePos.X, 0, root.Position.Z - orePos.Z)
            if flatDir.Magnitude < 0.1 then flatDir = Vector3.new(0, 0, 3.5) end
            local standPos = orePos + flatDir.Unit * 3.5 + Vector3.new(0, 0.8, 0)

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = CFrame.lookAt(standPos, Vector3.new(orePos.X, standPos.Y, orePos.Z))
        end

        -- F. Kích hoạt Pickaxe Tool swing & Chuột vật lý
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
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local curPos = root and root.Position or Vector3.zero

            -- Sắp xếp Nearest Neighbor gom mỏ quặng gần nhau
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
                    print(string.format("[AutoMine] 🎯 [%d/%d] Đang bay tới mỏ %s tại (%.1f, %.1f, %.1f)...", i, #oreList, oreName, targetPos.X, targetPos.Y, targetPos.Z))

                    local flew = flyToItem(targetPos, function() return Miner.running end)
                    if flew and ore and ore.Parent then
                        local done = mineOreNode(ore)
                        if done then
                            minedCount = minedCount + 1
                            print(string.format("[AutoMine] ✅ Đã đào xong mỏ %s!", oreName))
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
        if qteName == "Magic" or qteName == "Staff" then return qteMap["Staff / Magic (Rune Matching)"] == true end
        if qteName == "Fist" then return qteMap["Fist / Cestus (Combos)"] == true end
        if qteName == "Spear" then return qteMap["Spear (Taps, Lines & Curves)"] == true end
        if qteName == "Lockpick" then return qteMap["Chest Lockpick"] == true end
    end
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
local BaseTrainers = {
    ["⚔️ Base: Doran (Warrior - Sword)"] = Vector3.new(5627.8, 703.8, -4336.9),
    ["🗡️ Base: Luther (Thief - Dagger)"] = Vector3.new(3496.5, 632.8, -3983.3),
    ["🥊 Base: Aberon (Martial Artist - Fist / Cestus)"] = Vector3.new(2800.0, 610.7, -4018.2),
    ["🔮 Base: Arandor (Wizard - Magic / Staff)"] = Vector3.new(5840.1, 727.0, -4790.1),
    ["🚩 Base: Tivek (Slayer - Spear / Lancer)"] = Vector3.new(4473.3, 650.1, -5730.3),
    ["🪓 Base: Geron (Berserker / Marauder - Axe)"] = Vector3.new(4448.3, 652.1, -3359.3),
    ["🛡️ Base: Lagolt (Sentry - Greatsword)"] = Vector3.new(4651.7, 718.7, -5574.9),
}

local SuperTrainers = {
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
}

local MajorBosses = {
    ["🐉 Boss: Yar'thul, the Blazing Dragon (Mount Thul Door)"] = Vector3.new(40.5, 581.6, -4113.5),
    ["💀 Boss: Thorian, the Rotten (Remnants Entrance Gate)"]    = Vector3.new(8328.1, 645.0, -1544.1),
    ["✨ Boss: Seraphon (Light Boss / Illustris Door)"]          = Vector3.new(710.5, 3449.1, -5678.1),
    ["🦅 Boss: Arkhaia (Temple of Norn Door)"]                 = Vector3.new(14710.9, 550.7, 7133.7),
    ["🐍 Boss: Handaconda (Desert Room Entrance)"]              = Vector3.new(3134.1, 179.1, -852.2),
    ["👁️ Boss: Metrom's Vessel (Dungeon Entrance Spawn)"]      = Vector3.new(-3369.4, 129.8, 4266.4),
}

local KeyLocations = {
    -- 🏛️ Towns & Major Hubs
    ["🏛️ Westwood Heart"] = Vector3.new(8327.3, 825.1, -5557.4),
    ["🏛️ Westwood"] = Vector3.new(8327.3, 825.1, -5557.4),
    ["🌋 Caldera Town"] = Vector3.new(5091.2, 662.6, -4293.1),
    ["🌋 Caldera"] = Vector3.new(5091.2, 662.6, -4293.1),
    ["🏜️ Desert (Waving Sands)"] = Vector3.new(2815.3, 634.6, -3924.6),
    ["🏜️ Desert"] = Vector3.new(2815.3, 634.6, -3924.6),
    ["⚔️ Sanctuary of Blades"] = Vector3.new(2086.0, 386.8, -2978.3),
    ["⚔️ Sanctuary"] = Vector3.new(2086.0, 386.8, -2978.3),
    ["⛪ Church (Heavens Point)"] = Vector3.new(831.6, 3436.9, -5602.3),
    ["⛪ Church"] = Vector3.new(831.6, 3436.9, -5602.3),
    ["🏛️ Forgotten Sanctum (Endgame)"] = Vector3.new(10831.2, 1581.7, -3463.6),
    ["🌑 Dark Place Gate"] = Vector3.new(7855.1, 1290.3, 7930.9),
    ["🌌 Void Rift"] = Vector3.new(991.0, 41.4, 615.6),
    ["🏠 Memori's House"] = Vector3.new(11851.5, 1064.9, -1776.8),
    ["❄️ Icerift Approach"] = Vector3.new(5328.2, 742.7, -6530.2),
    ["🌋 Volcano (Mount Thul)"] = Vector3.new(98.9, 577.0, -4115.9),

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
    if not targetPos or typeof(targetPos) ~= "Vector3" then
        Library:Notify("❌ Invalid destination coordinates!", 3)
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
            Library:Notify("❌ HumanoidRootPart not found!", 3)
            return
        end

        local safeTargetPos = getAccurateGroundPosition(targetPos)
        local height = Options.TeleportHeight and Options.TeleportHeight.Value or 1500
        local speed = Options.TeleportSpeed and Options.TeleportSpeed.Value or 200

        Library:Notify(string.format("🚀 Starting Sky-Tween (Alt: %d, Spd: %d)...", height, speed), 3)

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

registerConnection(RunService.RenderStepped:Connect(function()
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
end))

registerConnection(workspace.DescendantAdded:Connect(function(desc)
    if ESP_Colors[desc.Name] then createESP(desc) end
end))
registerConnection(workspace.DescendantRemoving:Connect(removeESP))

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
local StatsGroup = Tabs.AutoFarm:AddRightGroupbox("📊 Auto Stats Build & Cache")
local HopGroup   = Tabs.AutoFarm:AddLeftGroupbox("🌐 Server Hop & Webhook")

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

MineGroup:AddSlider("MineSwingDelay", {
    Text = "Mining Swing Delay (s)",
    Default = 0.18,
    Min = 0.08,
    Max = 0.5,
    Rounding = 2,
    Tooltip = "Thời gian nghỉ giữa mỗi lần vung cuốc đập mỏ quặng (mặc định 0.18s siêu nhanh)",
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
    Default = true,
    Tooltip = "Tự động phát hiện khi Essence dừng tăng (đạt Cap level) -> Tự động đi thiền mô phỏng phím M gặp Aretim để thăng cấp rồi trở về",
})

LevelGroup:AddToggle("DeeprootNightFailsafe", {
    Text = "🌙 Deeproot Night Safe Hover (Avoid Sentinel)",
    Default = true,
    Tooltip = "Khi farm tại Deeproot Forest / Westwood: Nếu trời tối (17:30 - 06:30), tự động bay lên tầng mây (Y: 1200) đứng đợi trời sáng để tránh gặp siêu quái Sentinel of Darkness.",
})

StatsGroup:AddToggle("AutoAllocateStats", {
    Text = "Enable Auto Stats Build",
    Default = true,
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
    Text = "🗑️ Clear Stats Build Data (Reset User Cache)",
    Func = function()
        clearUserStatsCache()
    end
})

StatsGroup:AddButton({
    Text = "📋 View User Stats Cache",
    Func = function()
        local userStats, _, username = getUserStatsCache()
        local msg = string.format("Cache [%s]: Str:%d | End:%d | Spd:%d | Arc:%d | Lck:%d", username, userStats.Strength, userStats.Endurance, userStats.Speed, userStats.Arcane, userStats.Luck)
        Library:Notify(msg, 5)
        print("[AutoStats] " .. msg)
    end
})



-- Fully automated Level Farming (No manual buttons needed)

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
-- TAB 2: AUTO COMBAT & AUTO FIGHT
-- -----------------------------------------------------------------------------
local CombatGroup = Tabs.AutoQTE:AddLeftGroupbox("⚡ Auto Combat & Minigames QTE")
local FightGroup  = Tabs.AutoQTE:AddRightGroupbox("⚔️ Auto Fight & Skill Priority")

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

FightGroup:AddSlider("CombatDelay", {
    Text = "Turn Action Delay (s)",
    Default = 0.4,
    Min = 0.1,
    Max = 2.0,
    Rounding = 1,
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
-- TAB 4: TELEPORT SUITE (BASE TRAINERS, SUPER TRAINERS, MAJOR BOSSES, TOWNS & WARPS)
-- -----------------------------------------------------------------------------
local BaseGroup = Tabs.Teleport:AddLeftGroupbox("⚔️ Base Class Trainers (7)")
local BossGroup = Tabs.Teleport:AddLeftGroupbox("🐉 Major Bosses & Arenas (6)")
local SuperGroup = Tabs.Teleport:AddRightGroupbox("🌟 Super Class Trainers (18)")
local TownWarpGroup = Tabs.Teleport:AddRightGroupbox("🏛️ Towns, Quests & Quick Warps")

-- 1. BASE CLASS TRAINERS (7)
local baseNames = {}
for name, _ in pairs(BaseTrainers) do table.insert(baseNames, name) end
table.sort(baseNames)

BaseGroup:AddDropdown("SelectedBaseTrainer", {
    Values = baseNames,
    Default = 1,
    Multi = false,
    Text = "Select Base Trainer",
})

BaseGroup:AddButton({
    Text = "🚀 Teleport to Base Trainer",
    Func = function()
        local name = Options.SelectedBaseTrainer and Options.SelectedBaseTrainer.Value
        local pos = name and BaseTrainers[name]
        if pos then teleportToLocation(pos) else Library:Notify("Select valid trainer!", 3) end
    end
})

-- 2. MAJOR BOSSES & ARENAS (7)
local bossNames = {}
for name, _ in pairs(MajorBosses) do table.insert(bossNames, name) end
table.sort(bossNames)

BossGroup:AddDropdown("SelectedMajorBoss", {
    Values = bossNames,
    Default = 1,
    Multi = false,
    Text = "Select Major Boss",
})

BossGroup:AddButton({
    Text = "🐉 Teleport to Boss Arena",
    Func = function()
        local name = Options.SelectedMajorBoss and Options.SelectedMajorBoss.Value
        local pos = name and MajorBosses[name]
        if pos then teleportToLocation(pos) else Library:Notify("Select valid boss!", 3) end
    end
})

BossGroup:AddButton({
    Text = "🛑 Cancel Teleport",
    Func = cancelTeleport
})

-- 3. SUPER CLASS TRAINERS (18)
local superNames = {}
for name, _ in pairs(SuperTrainers) do table.insert(superNames, name) end
table.sort(superNames)

SuperGroup:AddDropdown("SelectedSuperTrainer", {
    Values = superNames,
    Default = 1,
    Multi = false,
    Text = "Select Super Trainer",
})

SuperGroup:AddButton({
    Text = "🚀 Teleport to Super Trainer",
    Func = function()
        local name = Options.SelectedSuperTrainer and Options.SelectedSuperTrainer.Value
        local pos = name and SuperTrainers[name]
        if pos then teleportToLocation(pos) else Library:Notify("Select valid trainer!", 3) end
    end
})

-- 4. TOWNS, SERVICES & QUICK WARPS
local townLocNames = {}
for name, _ in pairs(KeyLocations) do table.insert(townLocNames, name) end
table.sort(townLocNames)

TownWarpGroup:AddDropdown("SelectedTownLoc", {
    Values = townLocNames,
    Default = 1,
    Multi = false,
    Text = "Towns & Landmarks",
})

TownWarpGroup:AddButton({
    Text = "🚀 Teleport to Location",
    Func = function()
        local name = Options.SelectedTownLoc and Options.SelectedTownLoc.Value
        local pos = name and KeyLocations[name]
        if pos then teleportToLocation(pos) else Library:Notify("Select valid location!", 3) end
    end
})

TownWarpGroup:AddLabel("--- Town Quick Warps ---")
TownWarpGroup:AddButton("🏛️ Westwood", function() teleportToLocation(KeyLocations["🏛️ Westwood Heart"] or KeyLocations["🏛️ Westwood"]) end)
TownWarpGroup:AddButton("🌋 Caldera", function() teleportToLocation(KeyLocations["🌋 Caldera Town"] or KeyLocations["🌋 Caldera"]) end)
TownWarpGroup:AddButton("🏜️ Desert", function() teleportToLocation(KeyLocations["🏜️ Desert (Waving Sands)"] or KeyLocations["🏜️ Desert"]) end)
TownWarpGroup:AddButton("⛪ Church", function() teleportToLocation(KeyLocations["⛪ Church (Heavens Point)"] or KeyLocations["⛪ Church"]) end)
TownWarpGroup:AddButton("⚔️ Sanctuary", function() teleportToLocation(KeyLocations["⚔️ Sanctuary of Blades"] or KeyLocations["⚔️ Sanctuary"]) end)
TownWarpGroup:AddLabel("--- Boss Quick Warps ---")
TownWarpGroup:AddButton("🐉 Yar'thul (Mount Thul Door)", function() teleportToLocation(MajorBosses["🐉 Boss: Yar'thul, the Blazing Dragon (Mount Thul Door)"]) end)
TownWarpGroup:AddButton("💀 Thorian (Remnants Gate)", function() teleportToLocation(MajorBosses["💀 Boss: Thorian, the Rotten (Remnants Entrance Gate)"]) end)
TownWarpGroup:AddButton("✨ Seraphon (Illustris Door)", function() teleportToLocation(MajorBosses["✨ Boss: Seraphon (Light Boss / Illustris Door)"]) end)
TownWarpGroup:AddButton("🦅 Arkhaia (Temple of Norn Door)", function() teleportToLocation(MajorBosses["🦅 Boss: Arkhaia (Temple of Norn Door)"]) end)
TownWarpGroup:AddButton("🐍 Handaconda (Desert Room)", function() teleportToLocation(MajorBosses["🐍 Boss: Handaconda (Desert Room Entrance)"]) end)
TownWarpGroup:AddButton("👁️ Metrom (Dungeon Entrance)", function() teleportToLocation(MajorBosses["👁️ Boss: Metrom's Vessel (Dungeon Entrance Spawn)"]) end)

-- -----------------------------------------------------------------------------
-- TAB 5: VISUALS & FPS BOOSTER
-- -----------------------------------------------------------------------------
local ESPGroup = Tabs.Visuals:AddLeftGroupbox("👁️ Ingredient ESP")
local FilterGroup = Tabs.Visuals:AddLeftGroupbox("🎯 Filters & Categories")
local QOLGroup = Tabs.Visuals:AddRightGroupbox("✨ Quality of Life (QOL)")
local FPSGroup = Tabs.Visuals:AddRightGroupbox("⚡ FPS Booster")
local OptGroup = Tabs.Visuals:AddRightGroupbox("🛠️ Optimization & RAM")

QOLGroup:AddToggle("BypassNoPainHP", {
    Text = "Reveal 'I Feel No Pain' HP & Mana",
    Default = true,
    Tooltip = "Reveals exact numerical Health and Mana/Energy bars when obscured by Trial I Feel No Pain",
})

QOLGroup:AddToggle("RevealUnidentified", {
    Text = "Reveal Unidentified Items",
    Default = true,
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
    Default = { "Crylight", "Cryastem", "Everthistle", "Hightail" },
    Multi = true,
    Text = "Whitelist Selection",
})

FPSGroup:AddToggle("FPSBoost", {
    Text = "🔥 FPS Boost (Potato Mode)",
    Default = false,
    Tooltip = "⚡ Tối đa hóa FPS kịch khung: Ép Smooth Plastic, xóa Decal/Texture/Light, ẩn cây cối thảm thực vật, tắt Particles/Shadows/Fog (KHÔNG tắt 3D Render).",
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
    Default = true,
    Tooltip = "Tự động gửi tín hiệu chống ngắt kết nối khi treo máy AFK 24/7",
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

-- =============================================================================
-- UNLOAD MANAGER & CLEANUP CONTROLLER (100% COMPLETE RESOURCE & THREAD RELEASE)
-- =============================================================================
local function unloadHub()
    print("[ArcaneHub] 🛑 Đang tiến hành Unload toàn bộ script và vô hiệu hóa tất cả chức năng...")
    
    -- 1. Đánh dấu dừng toàn bộ vòng lặp vĩnh viễn
    HubState.running = false
    
    -- 2. Dừng các module tự động
    if Farmer then Farmer.running = false end
    if AutoFight then AutoFight.stop() end
    if LevelFarmer then 
        LevelFarmer.running = false 
        if LevelFarmer.noclipConn then 
            pcall(function() LevelFarmer.noclipConn:Disconnect() end)
            LevelFarmer.noclipConn = nil
        end
    end
    if Miner then Miner.running = false end
    if FlightController then
        FlightController.active = false
        if FlightController.noclipConn then
            pcall(function() FlightController.noclipConn:Disconnect() end)
            FlightController.noclipConn = nil
        end
    end
    if ServerHopper then
        ServerHopper.isHopping = false
    end

    -- 3. Ngắt toàn bộ kết nối RunService và sự kiện
    for _, conn in ipairs(HubState.connections) do
        pcall(function() conn:Disconnect() end)
    end
    HubState.connections = {}

    -- 4. Ngắt kết nối Anti-AFK
    if AntiAFK and AntiAFK.connections then
        for _, conn in ipairs(AntiAFK.connections) do
            pcall(function() conn:Disconnect() end)
        end
        AntiAFK.connections = {}
    end

    -- 5. Xóa sạch toàn bộ Billboard GUI của ESP
    if activeESP then
        for inst, data in pairs(activeESP) do
            pcall(function() data.billboard:Destroy() end)
        end
        activeESP = {}
    end

    -- 6. Xóa các BodyMovers (Fly / Noclip / BodyVelocity) và khôi phục nhân vật về trạng thái gốc
    pcall(function()
        if Movement and Movement.flyBodyVelocity then
            Movement.flyBodyVelocity:Destroy()
            Movement.flyBodyVelocity = nil
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, mover in ipairs(hrp:GetChildren()) do
                    if mover:IsA("BodyVelocity") or mover:IsA("BodyPosition") or mover:IsA("BodyGyro") or mover:IsA("LinearVelocity") or mover:IsA("AlignPosition") then
                        if mover.Name:find("Arcane") or mover.Name:find("Flight") or mover.Name:find("Farm") then
                            mover:Destroy()
                        end
                    end
                end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
        end
    end)

    -- 7. Xóa bệ đỡ / nền phụ
    pcall(function() removeUndergroundPlatform() end)

    -- 8. Khôi phục ánh sáng / đồ họa mặc định
    pcall(function()
        if FPSBooster then
            Lighting.GlobalShadows = FPSBooster.originalGlobalShadows or true
            Lighting.FogEnd = FPSBooster.originalFogEnd or 100000
            Lighting.FogStart = FPSBooster.originalFogStart or 0
        end
    end)

    -- 9. Dọn dẹp Linoria UI
    pcall(function() Library:Unload() end)
    
    shared.ArcaneHub = nil
    globalEnv._ArcaneHubRunning = nil
    globalEnv._ArcaneHubInitLock = nil
    print("[ArcaneHub] ✅ Đã Unload sạch sẽ 100% tất cả chức năng và giải phóng tài nguyên!")
end

local MenuGroup = Tabs.Settings:AddRightGroupbox("Menu Settings")

MenuGroup:AddButton("Unload Script", function()
    unloadHub()
end)

MenuGroup:AddToggle("AutoLoadOnChangingServer", {
    Text = "Auto Load on Changing Server",
    Default = false,
    Tooltip = "Tự động nạp lại Arcane Hub ngay khi chuyển server, server hop hoặc teleport trong game",
    Callback = function(Value)
        if Value then
            local queued = queueTeleportScript()
            if queued then
                Library:Notify("✅ Đã bật Auto Load on Changing Server (Đã nạp Teleport Queue)!", 3)
            else
                Library:Notify("⚠️ Executor không hỗ trợ queue_on_teleport!", 3)
            end
        else
            Library:Notify("❌ Đã tắt tự động nạp Hub khi đổi Server!", 3)
        end
    end
})

pcall(function()
    if LocalPlayer and LocalPlayer.OnTeleport then
        registerConnection(LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Started or state == nil or state == 0 then
                if Toggles and Toggles.AutoLoadOnChangingServer and Toggles.AutoLoadOnChangingServer.Value then
                    queueTeleportScript()
                end
            end
        end))
    end
end)

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "None",
    NoUI = true,
    Text = "Menu keybind"
})

Library.ToggleKeybind = Options.MenuKeybind

pcall(function()
    if SaveManager then
        SaveManager:LoadAutoloadConfig()
    end
end)

task.defer(function()
    pcall(function()
        if Toggles and Toggles.AutoLoadOnChangingServer and Toggles.AutoLoadOnChangingServer.Value then
            queueTeleportScript()
        end
    end)
end)

-- =============================================================================
-- BUILT-IN ANTI-AFK SYSTEM (BULLETPROOF TRIPLE-LAYER KICK BYPASS)
-- =============================================================================
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
                        vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
                        task.wait(0.05)
                        vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
                    end
                end)
            end
        end
    end)

    print("[AntiAFK] 🛡️ Built-in Anti-AFK Engine Initialized Successfully!")
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

        -- 1. GIẢI MÃ VÀ HIỆN TÊN THẬT CHO TẤT CẢ ITEM CHƯA GIÁM ĐỊNH (UNIDENTIFIED REVEALER)
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
                                    local fakeConfig = {}
                                    for ck, cv in pairs(itemData.Config) do
                                        if ck ~= "Unidentified" then fakeConfig[ck] = cv end
                                    end
                                    local fullLabel = realName
                                    if ItemModifiers then
                                        pcall(function()
                                            fullLabel = ItemModifiers.LabelFor(realName, fakeConfig)
                                        end)
                                    end
                                    btn.Text = "✨ " .. fullLabel
                                end
                            end
                        end
                    end

                    -- Giải mã luôn ToolTip khi di chuột vào món đồ chưa giám định
                    local tooltip = inv:FindFirstChild("ToolTip", true)
                    if tooltip and tooltip.Visible then
                        local textLbl = tooltip:FindFirstChildWhichIsA("TextLabel", true)
                        if textLbl and textLbl.Text:find("You have no idea what this does") then
                            textLbl.Text = "✨ [Real Item Revealed by Arcane Hub]"
                        end
                    end

                    local advTooltip = inv:FindFirstChild("AdvancedTooltip", true)
                    if advTooltip and advTooltip.Visible then
                        local descLbl = advTooltip:FindFirstChild("Desc")
                        if descLbl and descLbl:IsA("TextLabel") and descLbl.Text:find("You have no idea what this does") then
                            local nameLbl = advTooltip:FindFirstChild("ItemName")
                            local realItemName = nameLbl and nameLbl.Text:gsub("✨ ", "")
                            if realItemName and ItemRegistry then
                                local regData = ItemRegistry:GetItem(realItemName)
                                if regData then
                                    local descText = (regData.GearDesc and (regData.GearDesc .. " | ") or "") .. (regData.ToolTip or "")
                                    descLbl.Text = "✨ " .. descText
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- 2. HIỂN THỊ MÁU & MANA/ENERGY THẬT KHI CHỊU TRIAL 'I FEEL NO PAIN!'
        if Toggles.BypassNoPainHP and Toggles.BypassNoPainHP.Value then
            pcall(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local pgui = PlayerGui
                local hud = pgui and pgui:FindFirstChild("HUD")
                local holder = hud and (hud:FindFirstChild("Holder") or hud:FindFirstChild("HolderOLD"))

                -- 1. GIẢI MÃ VÀ HIỆN MÁU THẬT (REAL HP)
                if hum and holder then
                    local hpOutline = holder:FindFirstChild("HPOutline", true)
                    if hpOutline then
                        local countLabel = hpOutline:FindFirstChild("Count", true)
                        if countLabel and countLabel:IsA("TextLabel") then
                            if countLabel.Text == "???" or countLabel.Text:find("%?") then
                                countLabel.Text = string.format("%.1f/%.1f", hum.Health, hum.MaxHealth)
                            end
                        end
                        local healthBar = hpOutline:FindFirstChild("Health", true)
                        if healthBar and healthBar:IsA("GuiObject") then
                            if healthBar.ImageColor3 == Color3.fromRGB(150, 0, 255) or healthBar.Size.X.Scale < 0.05 then
                                local ratio = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                                healthBar.Size = UDim2.new(ratio, 0, 0.7, 0)
                            end
                        end
                    end
                end

                -- 2. GIẢI MÃ VÀ HIỆN MANA/ENERGY THẬT (REAL ENERGY / MANA)
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
    end
end)

-- =============================================================================
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
