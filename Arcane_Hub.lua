--[[
    ========================================================================================
    🌟 ARCANE LINEAGE - ALL-IN-ONE MASTER HUB (LinoriaLib GUI + SaveManager + ThemeManager)
    ========================================================================================
    Features:
    • [Auto Farm Whitelist]: Fast Menu-Scan (Hops directly from MainMenu if 0 targets),
      Sky-Tween 3-phase flight (avoids mobs & combat), Auto-Harvest, Auto-ServerHop (resets after 20 hops),
      Adaptable Multi-Item Discord Webhook Notifications.
    • [Auto Combat QTE]: Perfect Dodge 100%, Sword (no double-tap), Dagger (all weakpoints),
      Hammer (PID Bang-Bang), Axe (Threshold Equilibrium), Fist/Cestus (Sequential combos),
      Spear (Active Button Clicker), Chest Lockpicking.
    • [Movement Suite]: Fly Hack (BodyVelocity + WASD/Space/Shift), NoClip, Velocity Speedhack,
      CFrame Speed Bypass, Infinite Jump Boost.
    • [Teleport Suite]: Smooth 3-Phase Sky-Tween to 26+ key locations (Towns, Blacksmiths, Doctors,
      Bankers, Merchants, Class Trainers) with configurable Flight Altitude and Speed.
    • [Ingredient ESP]: Custom BillboardGui OOP Engine with Distance, Persistent Mode, Whitelist filter.
    • [FPS Booster & Optimization]: Remove Fog, Atmosphere, Shadows, Foliage, Materials, Instant Clean RAM.
    • [Config & Theme System]: SaveManager & ThemeManager (Full save/load configurations).
    ========================================================================================
--]]

-- ĐỢI GAME VÀ ASSETS TẢI HOÀN TẤT TRƯỚC KHI CHẠY (CHỐNG LỖI EXECUTE SỚM)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)

-- Dọn dẹp phiên bản cũ nếu đang chạy
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

-- Hàm HTTP request đa năng của các Executor
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
-- TỌA ĐỘ VÀ BLACKLIST VẬT PHẨM GIẢ
-- =============================================================================
local DesertBlacklist = {
    Vector3.new(10486.2, 1572.7, -3502.8),
    Vector3.new(10398.9, 1570.6, -3450.4),
    Vector3.new(10490.0, 1573.0, -3500.0),
    Vector3.new(10400.0, 1570.0, -3450.0)
}

local function isBlacklistedCrylight(obj)
    if not Toggles.BlacklistDesert or not Toggles.BlacklistDesert.Value then return false end
    if not obj:IsA("Model") and not obj:IsA("BasePart") then return false end
    local pos = obj:GetPivot().Position
    for _, bPos in ipairs(DesertBlacklist) do
        if (pos - bPos).Magnitude < 15 then return true end
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
-- AUTO FARM INGREDIENTS (MULTI-ITEM SCAN + SKY TWEEN)
-- =============================================================================
local Farmer = {
    running = false,
    noclipConn = nil,
    currentTween = nil,
}

local function enableNoClip()
    if Farmer.noclipConn then return end
    Farmer.noclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end)
end

local function disableNoClip()
    if Farmer.noclipConn then
        Farmer.noclipConn:Disconnect()
        Farmer.noclipConn = nil
    end
end

local function tweenTo(targetCFrame, speed)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local distance = (root.Position - targetCFrame.Position).Magnitude
    local duration = math.max(0.1, distance / speed)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, { CFrame = targetCFrame })
    Farmer.currentTween = tween
    tween:Play()

    local completed = false
    local conn
    conn = tween.Completed:Connect(function()
        completed = true
        if conn then conn:Disconnect() end
    end)

    while not completed and (Farmer.running or (Teleporter and Teleporter.active)) do task.wait() end
    Farmer.currentTween = nil
    return completed
end

local function flyToItem(targetPosition)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    enableNoClip()

    local skyHeight = Options.SkyHeight and Options.SkyHeight.Value or 950
    local ascendSpeed = Options.AscendSpeed and Options.AscendSpeed.Value or 120
    local cruiseSpeed = Options.CruiseSpeed and Options.CruiseSpeed.Value or 110
    local descendSpeed = Options.DescendSpeed and Options.DescendSpeed.Value or 120

    local currentPos = root.Position
    local skyY = math.max(skyHeight, currentPos.Y + 100)

    -- Phase 1: Bay thẳng đứng lên trời cao
    tweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), ascendSpeed)
    if not Farmer.running then return false end

    -- Phase 2: Bay ngang trên không trung tới ngay trên đầu nguyên liệu
    tweenTo(CFrame.new(targetPosition.X, skyY, targetPosition.Z), cruiseSpeed)
    if not Farmer.running then return false end

    -- Phase 3: Hạ cánh thẳng đứng xuống cách nguyên liệu 3.5 studs
    tweenTo(CFrame.new(targetPosition.X, targetPosition.Y + 3.5, targetPosition.Z), descendSpeed)
    return true
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

        -- Quét danh sách nguyên liệu theo cấu hình
        local harvestList = {}
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc.Parent and selectedMap[desc.Name] and not isBlacklistedCrylight(desc) then
                table.insert(harvestList, { instance = desc, name = desc.Name })
            end
        end

        print(string.format("[AutoFarm] 📊 Kết quả kiểm tra tại Menu: Tìm thấy %d nguyên liệu hợp lệ.", #harvestList))

        -- NẾU CÓ NGUYÊN LIỆU: TIẾN HÀNH VÀO GAME VÀ LỤM
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
                        task.wait(0.5)
                    end
                end
            end

            -- Bay ngược lên trời an toàn sau khi nhặt xong
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local skyHeight = Options.SkyHeight and Options.SkyHeight.Value or 950
                local ascendSpeed = Options.AscendSpeed and Options.AscendSpeed.Value or 120
                tweenTo(CFrame.new(root.Position.X, skyHeight, root.Position.Z), ascendSpeed)
            end

            if totalHarvested > 0 and Toggles.NotifyOnHarvest and Toggles.NotifyOnHarvest.Value then
                sendDiscordReport(harvestedCounts, totalHarvested)
            end
        else
            print("[AutoFarm] ❌ Server không có nguyên liệu mục tiêu! Đang Server Hop ngay từ Main Menu...")
        end

        disableNoClip()

        if Toggles.AutoServerHop and Toggles.AutoServerHop.Value and Farmer.running then
            task.wait(1)
            ServerHopper.hop()
        end
    end)
end

function Farmer.stop()
    Farmer.running = false
    if Farmer.currentTween then
        Farmer.currentTween:Cancel()
        Farmer.currentTween = nil
    end
    disableNoClip()
    print("[AutoFarm] Đã dừng Auto Farm.")
end

-- =============================================================================
-- AUTO COMBAT QTE ENGINE
-- =============================================================================
local AutoQTE = {
    lastDodgeHit = 0,
    lastSwordHit = 0,
    lastDaggerHit = 0,
    isHammerHolding = false,
    lastAxePress = 0,
    lastFistHit = 0,
}

-- 1. DODGE QTE (PERFECT DODGE 100% / BLOCK)
local function handleDodgeQTE(dodgeQTE)
    if not Toggles.AutoDodge or not Toggles.AutoDodge.Value or not dodgeQTE or not dodgeQTE.Visible then return end
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
            safeClick(stopBtn)
        end
    end
end

-- 2. SWORD QTE (PERFECT WINDOW STRIKE - SEQUENTIAL TARGETING NO DOUBLE-TAP)
local function handleSwordQTE(swordQTE)
    if not Toggles.AutoSword or not Toggles.AutoSword.Value or not swordQTE or not swordQTE.Visible then return end
    local inset = swordQTE:FindFirstChild("Inset")
    local stopBtn = swordQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local window = inset:FindFirstChild("Window")
    if not window or not window.Visible then return end

    local currentActiveInd = nil
    local lowestIndex = math.huge

    for _, child in ipairs(inset:GetChildren()) do
        local idx = tonumber(child.Name)
        if idx and idx < lowestIndex and child:IsA("GuiObject") and child.Visible and child.BackgroundTransparency < 0.6 then
            lowestIndex = idx
            currentActiveInd = child
        end
    end

    if not currentActiveInd then return end

    local indCenter = currentActiveInd.AbsolutePosition.X + (currentActiveInd.AbsoluteSize.X / 2)
    local winMin = window.AbsolutePosition.X
    local winMax = winMin + window.AbsoluteSize.X

    local isHit = false
    if GuiCollisionService and GuiCollisionService.isColliding then
        isHit = GuiCollisionService.isColliding(currentActiveInd, window) and (indCenter >= winMin + 2 and indCenter <= winMax - 2)
    else
        isHit = (indCenter >= winMin + 2 and indCenter <= winMax - 2)
    end

    if isHit then
        local now = os.clock()
        if now - AutoQTE.lastSwordHit > 0.2 then
            AutoQTE.lastSwordHit = now
            local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
            if delayMs > 0 then task.wait(delayMs / 1000) end
            safeClick(stopBtn)
        end
    end
end

-- 3. DAGGER QTE (ALL WEAKPOINTS)
local function handleDaggerQTE(daggerQTE)
    if not Toggles.AutoDagger or not Toggles.AutoDagger.Value or not daggerQTE or not daggerQTE.Visible then return end
    local stopBtn = daggerQTE:FindFirstChild("Stop")
    local activeRing = daggerQTE:FindFirstChild("ActiveRing")
    if not activeRing then return end

    local ringRot = -activeRing.Rotation % 360
    if ringRot < 0 then ringRot = ringRot + 360 end

    for _, wp in ipairs(activeRing:GetChildren()) do
        if wp.Name == "Weakpoint" and wp:IsA("GuiObject") and wp.ImageTransparency < 0.8 then
            local wpAngle = wp.Rotation % 360
            local diff = (ringRot - wpAngle) % 360
            if diff < 0 then diff = diff + 360 end
            if diff > 180 then diff = diff - 360 end

            if math.abs(diff) <= 18 then
                local now = os.clock()
                if now - AutoQTE.lastDaggerHit > 0.04 then
                    AutoQTE.lastDaggerHit = now
                    local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
                    if delayMs > 0 then task.wait(delayMs / 1000) end
                    if stopBtn then safeClick(stopBtn) else pressKey(Enum.KeyCode.Space) end
                    break
                end
            end
        end
    end
end

-- 4. HAMMER QTE (HOLD/RELEASE SPACE PID CONTROLLER)
local function handleHammerQTE(hammerQTE)
    if not Toggles.AutoHammer or not Toggles.AutoHammer.Value or not hammerQTE or not hammerQTE.Visible then
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
    if not Toggles.AutoAxe or not Toggles.AutoAxe.Value or not axeQTE or not axeQTE.Visible then return end
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
            if spaceHint then safeClick(spaceHint) end
            pressKey(Enum.KeyCode.Space)
        end
    end
end

-- 6. FIST / CESTUS QTE (SEQUENTIAL COMBO ARROWS)
local function handleFistQTE(fistQTE)
    if not Toggles.AutoFist or not Toggles.AutoFist.Value or not fistQTE or not fistQTE.Visible then return end
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
            if otherControls and otherControls:FindFirstChild("Up") then safeClick(otherControls.Up) end
        elseif rot == 180 or name:find("right") then
            pressKey(Enum.KeyCode.Right)
            pressKey(Enum.KeyCode.D)
            if otherControls and otherControls:FindFirstChild("Right") then safeClick(otherControls.Right) end
        elseif rot == 270 or name:find("down") then
            pressKey(Enum.KeyCode.Down)
            pressKey(Enum.KeyCode.S)
            if otherControls and otherControls:FindFirstChild("Down") then safeClick(otherControls.Down) end
        elseif rot == 0 or name:find("left") then
            pressKey(Enum.KeyCode.Left)
            pressKey(Enum.KeyCode.A)
            if otherControls and otherControls:FindFirstChild("Left") then safeClick(otherControls.Left) end
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
                    safeClick(btn)
                    break
                end
            end
        end
    end
end

-- 8. LOCKPICK QTE (CHEST UNLOCKER)
local function handleLockpickQTE(lockpickQTE)
    if not Toggles.AutoLockpick or not Toggles.AutoLockpick.Value or not lockpickQTE or not lockpickQTE.Visible then return end
    local stopBtn = lockpickQTE:FindFirstChild("Stop", true) or lockpickQTE:FindFirstChildWhichIsA("TextButton", true)
    local indicator = lockpickQTE:FindFirstChild("Indicator", true)
    local target = lockpickQTE:FindFirstChild("Zone", true) or lockpickQTE:FindFirstChild("Window", true) or lockpickQTE:FindFirstChild("Target", true)

    if stopBtn and indicator and target then
        local indCenter = indicator.AbsolutePosition.X + (indicator.AbsoluteSize.X / 2)
        local tMin = target.AbsolutePosition.X
        local tMax = tMin + target.AbsoluteSize.X

        if indCenter >= tMin and indCenter <= tMax then
            safeClick(stopBtn)
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not Toggles.MasterQTE or not Toggles.MasterQTE.Value then return end
    local combatGui = PlayerGui and PlayerGui:FindFirstChild("Combat")
    if not combatGui then return end

    local dodgeQTE = combatGui:FindFirstChild("DodgeQTE")
    local swordQTE = combatGui:FindFirstChild("SwordQTE")
    local daggerQTE = combatGui:FindFirstChild("DaggerQTE")
    local hammerQTE = combatGui:FindFirstChild("HammerQTE")
    local axeQTE = combatGui:FindFirstChild("AxeQTE")
    local fistQTE = combatGui:FindFirstChild("FistQTE")
    local lockpickQTE = combatGui:FindFirstChild("LockpickQTE")

    if dodgeQTE and dodgeQTE.Visible then handleDodgeQTE(dodgeQTE) end
    if swordQTE and swordQTE.Visible then handleSwordQTE(swordQTE) end
    if daggerQTE and daggerQTE.Visible then handleDaggerQTE(daggerQTE) end
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
    if Toggles.NoClip and Toggles.NoClip.Value then
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

    if Toggles.Fly and Toggles.Fly.Value and hrp and hum and cam then
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

        local flySpeed = Options.FlySpeed and Options.FlySpeed.Value or 100
        local flyUpSpeed = Options.FlyUpSpeed and Options.FlyUpSpeed.Value or 60

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
        if Movement.flyBodyVelocity then
            Movement.flyBodyVelocity:Destroy()
            Movement.flyBodyVelocity = nil
        end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if Toggles.Fly and Toggles.Fly.Value then return end

    -- Speedhack (LinearVelocity)
    if Toggles.Speedhack and Toggles.Speedhack.Value then
        local moveDir = hum.MoveDirection
        local speed = Options.SpeedhackSpeed and Options.SpeedhackSpeed.Value or 50
        if moveDir.Magnitude > 0.001 then
            hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * speed, hrp.AssemblyLinearVelocity.Y, moveDir.Z * speed)
        end
    end

    -- CFrame Speed (Bypass)
    if Toggles.CFrameSpeed and Toggles.CFrameSpeed.Value then
        local moveDir = hum.MoveDirection
        local mult = Options.CFrameSpeedMult and Options.CFrameSpeedMult.Value or 30
        if moveDir.Magnitude > 0.001 then
            hrp.CFrame = hrp.CFrame + moveDir * (mult * dt)
        end
    end

    -- Infinite Jump
    if Toggles.InfiniteJump and Toggles.InfiniteJump.Value then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            local boost = Options.InfiniteJumpBoost and Options.InfiniteJumpBoost.Value or 50
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, boost, hrp.AssemblyLinearVelocity.Z)
        end
    end
end)

-- =============================================================================
-- TELEPORT SUITE (26+ LOCATIONS & 3-PHASE SKY TWEEN)
-- =============================================================================
local KeyLocations = {
    -- Towns & Hubs
    ["Westwood Heart"] = Vector3.new(8421.9, 822.5, -5864.5),
    ["Caldera Town"] = Vector3.new(5035.6, 658.1, -4407.9),
    ["Deeproot Town"] = Vector3.new(2079.6, 382.7, -2903.1),
    ["Desert Oasis"] = Vector3.new(10810.7, 1576.1, -3449.6),
    ["Soulmaster (Purgatory)"] = Vector3.new(-44.9, 574.8, -5467.4),
    ["Astraea Riddle (Peak)"] = Vector3.new(-177.6, 2767.7, -2868.4),

    -- Town Merchants & Services
    ["Blacksmith (Westwood)"] = Vector3.new(8465.8, 821.8, -5589.8),
    ["Blacksmith (Caldera)"] = Vector3.new(4921.8, 657.9, -4162.3),
    ["Blacksmith (Deeproot)"] = Vector3.new(2079.6, 382.7, -2903.1),
    ["Doctor (Westwood)"] = Vector3.new(8079.1, 822.4, -5478.8),
    ["Doctor (Caldera)"] = Vector3.new(5035.6, 658.1, -4407.9),
    ["Doctor (Deeproot)"] = Vector3.new(2084.0, 382.7, -2946.7),
    ["Banker (Westwood)"] = Vector3.new(8470.3, 823.6, -5824.3),
    ["Banker (Caldera)"] = Vector3.new(5184.7, 657.7, -4266.2),
    ["Merchant (Westwood)"] = Vector3.new(8473.8, 823.6, -5906.5),
    ["Merchant (Caldera)"] = Vector3.new(5132.9, 658.0, -4124.2),

    -- Class & Skill Trainers
    ["Trainer: Thorin (Berserker)"] = Vector3.new(4253.1, 653.8, -3369.2),
    ["Trainer: June (Elementalist)"] = Vector3.new(4903.8, 624.7, -4423.1),
    ["Trainer: Arandor (Paladin)"] = Vector3.new(5840.1, 727.0, -4790.1),
    ["Trainer: Dusk (Rogue)"] = Vector3.new(5451.4, 660.9, -4309.0),
    ["Trainer: Orin (Slayer)"] = Vector3.new(8043.9, 822.6, -5599.3),
    ["Trainer: Diiz (Thief)"] = Vector3.new(8066.4, 831.2, -5648.9),
    ["Trainer: Prelate Fyran (Cleric)"] = Vector3.new(8459.8, 822.4, -5885.1),
    ["Trainer: Ryzar Infelio (Necro)"] = Vector3.new(2134.9, 382.7, -2922.0),
    ["Trainer: Geron (Warrior)"] = Vector3.new(4448.3, 652.1, -3359.3),
    ["Trainer: Luther (Martial)"] = Vector3.new(3496.5, 632.8, -3983.3),
}

local Teleporter = {
    active = false,
}

local function teleportToLocation(targetPos)
    if Teleporter.active then
        Library:Notify("Teleport is already running!", 3)
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

        enableNoClip()
        Library:Notify("🚀 Starting Sky-Tween Teleport...", 3)

        local height = Options.TeleportHeight and Options.TeleportHeight.Value or 250
        local speed = Options.TeleportSpeed and Options.TeleportSpeed.Value or 180

        local currentPos = root.Position
        local skyY = math.max(currentPos.Y + height, targetPos.Y + height)

        -- Phase 1: Ascend
        tweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), speed)
        if not Teleporter.active then disableNoClip() return end

        -- Phase 2: Cruise
        tweenTo(CFrame.new(targetPos.X, skyY, targetPos.Z), speed)
        if not Teleporter.active then disableNoClip() return end

        -- Phase 3: Descend safely
        tweenTo(CFrame.new(targetPos.X, targetPos.Y + 4, targetPos.Z), speed)

        disableNoClip()
        Teleporter.active = false
        Library:Notify("✅ Arrived at destination!", 3)
    end)
end

local function cancelTeleport()
    Teleporter.active = false
    if Farmer.currentTween then
        Farmer.currentTween:Cancel()
        Farmer.currentTween = nil
    end
    disableNoClip()
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
                if filterMode == "All" then
                    isVisible = true
                elseif filterMode == "CrylightOnly" and data.name == "Crylight" then
                    isVisible = true
                elseif filterMode == "Whitelist" and whitelist[data.name] then
                    isVisible = true
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
-- TAB 1: AUTO FARM (CUSTOM WHITELIST & ADAPTABLE WEBHOOK)
-- -----------------------------------------------------------------------------
local FarmGroup = Tabs.AutoFarm:AddLeftGroupbox("Ingredient Auto Hunter")
local HopGroup = Tabs.AutoFarm:AddRightGroupbox("Server Hop & Webhook")

FarmGroup:AddToggle("AutoFarmCrylight", {
    Text = "Enable Auto Farm",
    Default = false,
    Tooltip = "Tự động quét Menu -> Vào game -> Bay Sky-Tween -> Lụm -> Đổi Server",
    Callback = function(Value)
        if Value then Farmer.runCycle() else Farmer.stop() end
    end
})

FarmGroup:AddDropdown("FarmItemsWhitelist", {
    Values = {
        "Crylight", "Cryastem", "Hightail", "Everthistle",
        "Carnastool", "Driproot", "Cursed Shroom", "Cursed Shroom 2",
        "Mushrooms", "Bones", "Branch Pile", "Ferrus", "Aestic", "Laneus"
    },
    Default = { "Crylight" },
    Multi = true,
    Text = "Farm Target Whitelist",
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
    Text = "Ignore Desert Fake Crylights",
    Default = false,
})

FarmGroup:AddSlider("SkyHeight", {
    Text = "Sky Flight Altitude (Y)",
    Default = 950,
    Min = 500,
    Max = 1500,
    Rounding = 0,
})

FarmGroup:AddSlider("AscendSpeed", {
    Text = "Ascend Speed (Studs/s)",
    Default = 120,
    Min = 50,
    Max = 250,
    Rounding = 0,
})

FarmGroup:AddSlider("CruiseSpeed", {
    Text = "Cruise Speed (Studs/s)",
    Default = 110,
    Min = 50,
    Max = 250,
    Rounding = 0,
})

FarmGroup:AddSlider("DescendSpeed", {
    Text = "Descend Speed (Studs/s)",
    Default = 120,
    Min = 50,
    Max = 250,
    Rounding = 0,
})

FarmGroup:AddSlider("PickupTimeout", {
    Text = "Pickup Timeout (Seconds)",
    Default = 5,
    Min = 2,
    Max = 10,
    Rounding = 1,
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
-- TAB 2: AUTO COMBAT QTE
-- -----------------------------------------------------------------------------
local MainQTEGroup = Tabs.AutoQTE:AddLeftGroupbox("General Combat")
local WeaponGroup = Tabs.AutoQTE:AddRightGroupbox("Weapon Specials")

MainQTEGroup:AddToggle("MasterQTE", {
    Text = "Enable Master Auto QTE",
    Default = false,
})

MainQTEGroup:AddToggle("AutoDodge", {
    Text = "Auto Dodge / Block",
    Default = false,
})

MainQTEGroup:AddToggle("PreferPerfectDodge", {
    Text = "Prefer Perfect Dodge (Yellow Zone)",
    Default = false,
})

MainQTEGroup:AddSlider("ReactionDelayMs", {
    Text = "Human Reaction Delay (ms)",
    Default = 0,
    Min = 0,
    Max = 200,
    Rounding = 0,
})

MainQTEGroup:AddToggle("AutoLockpick", {
    Text = "Auto Chest Lockpick",
    Default = false,
})

WeaponGroup:AddToggle("AutoSword", {
    Text = "Auto Sword (Window Strike)",
    Default = false,
})

WeaponGroup:AddToggle("AutoDagger", {
    Text = "Auto Dagger (All Weakpoints)",
    Default = false,
})

WeaponGroup:AddToggle("AutoHammer", {
    Text = "Auto Hammer (Gauge Timing)",
    Default = false,
})

WeaponGroup:AddToggle("AutoAxe", {
    Text = "Auto Axe (Threshold Balance)",
    Default = false,
})

WeaponGroup:AddToggle("AutoFist", {
    Text = "Auto Fist / Cestus (Arrows)",
    Default = false,
})

-- -----------------------------------------------------------------------------
-- TAB 3: MOVEMENT CONTROLLER
-- -----------------------------------------------------------------------------
local FlyGroup = Tabs.Movement:AddLeftGroupbox("✈️ Flight & NoClip")
local SpeedGroup = Tabs.Movement:AddRightGroupbox("⚡ Speed & Jump")

FlyGroup:AddToggle("Fly", {
    Text = "Enable Fly Hack",
    Default = false,
    Tooltip = "Bay tự do theo hướng Camera (W/A/S/D + Space / Shift)",
})

FlyGroup:AddSlider("FlySpeed", {
    Text = "Flight Horizontal Speed",
    Default = 100,
    Min = 20,
    Max = 300,
    Rounding = 0,
})

FlyGroup:AddSlider("FlyUpSpeed", {
    Text = "Flight Vertical Speed",
    Default = 60,
    Min = 10,
    Max = 200,
    Rounding = 0,
})

FlyGroup:AddToggle("NoClip", {
    Text = "Enable NoClip (Walk Through Walls)",
    Default = false,
})

SpeedGroup:AddToggle("Speedhack", {
    Text = "Speedhack (Linear Velocity)",
    Default = false,
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
})

SpeedGroup:AddSlider("InfiniteJumpBoost", {
    Text = "Jump Boost Force",
    Default = 50,
    Min = 30,
    Max = 150,
    Rounding = 0,
})

-- -----------------------------------------------------------------------------
-- TAB 4: TELEPORT SUITE
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
    Text = "Destination",
})

TeleportGroup:AddSlider("TeleportHeight", {
    Text = "Flight Altitude / Height (Y)",
    Default = 250,
    Min = 50,
    Max = 600,
    Rounding = 0,
})

TeleportGroup:AddSlider("TeleportSpeed", {
    Text = "Flight Speed (Studs/s)",
    Default = 180,
    Min = 50,
    Max = 400,
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

QuickWarpGroup:AddButton("🏛️ Westwood Heart", function() teleportToLocation(KeyLocations["Westwood Heart"]) end)
QuickWarpGroup:AddButton("🌋 Caldera Town", function() teleportToLocation(KeyLocations["Caldera Town"]) end)
QuickWarpGroup:AddButton("🌲 Deeproot Town", function() teleportToLocation(KeyLocations["Deeproot Town"]) end)
QuickWarpGroup:AddButton("🏜️ Desert Oasis", function() teleportToLocation(KeyLocations["Desert Oasis"]) end)
QuickWarpGroup:AddButton("👻 Soulmaster (Purgatory)", function() teleportToLocation(KeyLocations["Soulmaster (Purgatory)"]) end)
QuickWarpGroup:AddButton("⛰️ Astraea Riddle (Peak)", function() teleportToLocation(KeyLocations["Astraea Riddle (Peak)"]) end)

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
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("ArcaneHub")
SaveManager:SetFolder("ArcaneHub/Configs")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

local MenuGroup = Tabs.Settings:AddRightGroupbox("Menu Settings")

MenuGroup:AddButton("Unload Script", function()
    Library:Unload()
end)

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightControl",
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
