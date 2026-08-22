--[[
    ========================================================================================
    🌟 ARCANE LINEAGE - ALL-IN-ONE MASTER HUB (LinoriaLib GUI + SaveManager + ThemeManager)
    ========================================================================================
    Features:
    • [Auto Farm Crylight]: Fast Menu-Scan (Hops directly from MainMenu if 0 Crylight),
      Sky-Tween 3-phase flight (avoids mobs & combat), Auto-Harvest, Auto-ServerHop (resets after 20 hops),
      Discord Webhook Notifications.
    • [Auto Combat QTE]: Perfect Dodge 100%, Sword, Dagger (all weakpoints), Hammer, Axe, Fist/Cestus,
      Spear, Chest Lockpicking.
    • [Ingredient ESP]: Custom BillboardGui OOP Engine with Distance, Persistent Mode, Whitelist filter.
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
local Lighting = game:GetService("Lighting")

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
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.02)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

-- =============================================================================
-- BLACKLIST CRYLIGHT MẶC ĐỊNH Ở DESERT (KHÔNG LỤM ĐƯỢC)
-- =============================================================================
local DESERT_CENTER = Vector3.new(1423.0, 616.7, -4468.5)
local DESERT_RADIUS = 50

local function isBlacklistedCrylight(inst)
    if not inst then return true end
    if Toggles.BlacklistDesert and Toggles.BlacklistDesert.Value and inst.Name == "Crylight" then
        local pos = inst:GetPivot().Position
        local dist = (pos - DESERT_CENTER).Magnitude
        if dist <= DESERT_RADIUS then
            return true
        end
    end
    return false
end

-- =============================================================================
-- SERVER HOPPER (CHỐNG KẸT / TỰ ĐỘNG XÓA DỮ LIỆU SAU 20 SERVER)
-- =============================================================================
local ServerHopper = {
    isHopping = false,
    lastAttemptServer = nil,
    visitedFile = "Crylight_Visited_Servers.json",
    maxVisitedLimit = 20, -- Tối đa 20 server, sau đó tự động reset dữ liệu
}

local function getVisitedServers()
    local visited = {}
    if readfile and isfile and isfile(ServerHopper.visitedFile) then
        local content = readfile(ServerHopper.visitedFile)
        local success, data = pcall(HttpService.JSONDecode, HttpService, content)
        if success and type(data) == "table" then visited = data end
    end
    return visited
end

local function saveVisitedServer(jobId)
    local visited = getVisitedServers()
    
    -- Đếm số lượng server đã lưu
    local count = 0
    for _ in pairs(visited) do count = count + 1 end

    -- NẾU ĐÃ HOP QUÁ 20 SERVER THÌ TỰ ĐỘNG XÓA TOÀN BỘ ĐỂ TRÁNH HẾT SERVER
    if count >= ServerHopper.maxVisitedLimit then
        print(string.format("[ServerHop] 🔄 Đã hop qua %d server. Đang xóa bộ nhớ đệm để tái tạo danh sách server mới!", count))
        visited = {}
    end

    visited[jobId] = os.time()
    if writefile then
        pcall(function()
            writefile(ServerHopper.visitedFile, HttpService:JSONEncode(visited))
        end)
    end
end

function ServerHopper.hop()
    if ServerHopper.isHopping then return end
    ServerHopper.isHopping = true

    print("[ServerHop] 🔍 Đang quét tìm server mới còn chỗ trống...")
    saveVisitedServer(game.JobId)

    task.spawn(function()
        local placeId = game.PlaceId
        local visited = getVisitedServers()
        local nextCursor = ""
        local candidates = {}
        local maxBuffer = Options.MaxPlayerBuffer and Options.MaxPlayerBuffer.Value or 2

        for _ = 1, 3 do
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100%s", placeId, (nextCursor ~= "" and ("&cursor=" .. nextCursor) or ""))
            local success, res = pcall(function()
                return HttpRequest({ Url = url, Method = "GET", Headers = { ["Content-Type"] = "application/json" } })
            end)
            if success and res and res.Body then
                local sDecode, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
                if sDecode and data and data.data then
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

-- Tự động bắt lỗi khi Teleport thất bại
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    warn(string.format("[ServerHop] ❌ Teleport thất bại: %s (%s). Đang đổi server khác ngay...", tostring(teleportResult), tostring(errorMessage)))
    if ServerHopper.lastAttemptServer then saveVisitedServer(ServerHopper.lastAttemptServer) end
    ServerHopper.isHopping = false
    task.wait(1)
    ServerHopper.hop()
end)

-- =============================================================================
-- DISCORD WEBHOOK NOTIFIER
-- =============================================================================
local function sendDiscordReport(harvestedCount)
    local webhookUrl = Options.DiscordWebhook and Options.DiscordWebhook.Value or ""
    if #webhookUrl < 10 or not HttpRequest then return end

    task.spawn(function()
        local payload = {
            username = "Crylight Master Hunter",
            avatar_url = "https://cdn-icons-png.flaticon.com/512/3655/3655581.png",
            embeds = {{
                title = "💎 THU HOẠCH CRYLIGHT THÀNH CÔNG! 💎",
                description = string.format("Nhân vật vừa hoàn thành lụm **%d** Crylight và đang chuyển server!", harvestedCount),
                color = 0x00FF88,
                fields = {
                    { name = "🌾 Số lượng vừa nhặt", value = string.format("**%d** Crylight", harvestedCount), inline = true },
                    { name = "👤 Nhân vật", value = string.format("`%s` (%s)", LocalPlayer.Name, LocalPlayer.DisplayName), inline = true },
                    { name = "🆔 Server Vừa Xong", value = string.format("`%s`", game.JobId), inline = false }
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
-- AUTO FARM CRYLIGHT (MENU-FIRST CYCLE + SKY TWEEN)
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

    while not completed and Farmer.running do task.wait() end
    Farmer.currentTween = nil
    return completed
end

local function flyToCrylight(targetPosition)
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

    -- Phase 2: Bay ngang trên không trung tới ngay trên đầu Crylight
    tweenTo(CFrame.new(targetPosition.X, skyY, targetPosition.Z), cruiseSpeed)
    if not Farmer.running then return false end

    -- Phase 3: Hạ cánh thẳng đứng xuống cách Crylight 3.5 studs
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
        print("[AutoFarm] 🔍 [BƯỚC 1]: Đang kiểm tra Crylight ngay tại Menu...")
        task.wait(2.5) -- Đợi 2.5s để ShroomGarbage replicate

        -- Quét danh sách Crylight thật có thể lụm
        local harvestList = {}
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc.Name == "Crylight" and desc.Parent and not isBlacklistedCrylight(desc) then
                table.insert(harvestList, desc)
            end
        end

        print(string.format("[AutoFarm] 📊 Kết quả kiểm tra tại Menu: Tìm thấy %d viên Crylight thật.", #harvestList))

        -- NẾU CÓ CRYLIGHT: TIẾN HÀNH VÀO GAME VÀ LỤM
        if #harvestList > 0 then
            print("[AutoFarm] ✨ Phát hiện Crylight! Đang tự động bấm Play để vào game thu hoạch...")
            handleAutoStart()

            local totalHarvested = 0
            for i, crylight in ipairs(harvestList) do
                if not Farmer.running then break end
                if crylight and crylight.Parent then
                    local targetPos = crylight:GetPivot().Position
                    print(string.format("[AutoFarm] 🎯 [%d/%d] Đang bay tới Crylight tại (%.1f, %.1f, %.1f)...", i, #harvestList, targetPos.X, targetPos.Y, targetPos.Z))
                    
                    local flew = flyToCrylight(targetPos)
                    if flew and crylight and crylight.Parent then
                        local picked = harvestItem(crylight)
                        if picked then totalHarvested = totalHarvested + 1 end
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
                sendDiscordReport(totalHarvested)
            end
        else
            -- NẾU KHÔNG CÓ CRYLIGHT: KHÔNG CẦN SPAWN VÀO GAME -> HOP LUÔN TỪ MENU ĐỂ TIẾT KIỆM THỜI GIAN
            print("[AutoFarm] ❌ Server không có Crylight! Đang Server Hop ngay từ Main Menu...")
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
    lastHammerHit = 0,
    lastAxePress = 0,
    lastFistHit = 0,
}

local function handleDodgeQTE(dodgeQTE)
    if not Toggles.AutoDodge or not Toggles.AutoDodge.Value or not dodgeQTE or not dodgeQTE.Visible then return end
    local inset = dodgeQTE:FindFirstChild("Inset")
    local stopBtn = dodgeQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local indicator = inset:FindFirstChild("Indicator")
    local dodgeZone = inset:FindFirstChild("Dodge")
    local blockZone = inset:FindFirstChild("Block")
    if not indicator then return end

    local targetZone = (Toggles.PreferPerfectDodge and Toggles.PreferPerfectDodge.Value and dodgeZone and dodgeZone.Visible) and dodgeZone or blockZone
    if not targetZone then return end

    local indCenter = indicator.AbsolutePosition.X + (indicator.AbsoluteSize.X / 2)
    local targetMin = targetZone.AbsolutePosition.X
    local targetMax = targetMin + targetZone.AbsoluteSize.X

    if indCenter >= targetMin and indCenter <= targetMax then
        local now = os.clock()
        if now - AutoQTE.lastDodgeHit > 0.3 then
            AutoQTE.lastDodgeHit = now
            local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
            if delayMs > 0 then task.wait(delayMs / 1000) end
            safeClick(stopBtn)
        end
    end
end

-- 2. SWORD QTE (PERFECT WINDOW STRIKE - SEQUENTIAL TARGETING)
local function handleSwordQTE(swordQTE)
    if not Toggles.AutoSword or not Toggles.AutoSword.Value or not swordQTE or not swordQTE.Visible then return end
    local inset = swordQTE:FindFirstChild("Inset")
    local stopBtn = swordQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local window = inset:FindFirstChild("Window")
    if not window or not window.Visible then return end

    -- Tìm đúng Indicator hiện tại mà game đang chờ (chỉ số nhỏ nhất chưa bị dừng)
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

    -- Chỉ kích hoạt khi chính con trỏ hiện tại này lọt vào trong ô Window
    if indCenter >= (winMin + 4) and indCenter <= (winMax - 4) then
        local now = os.clock()
        if now - AutoQTE.lastSwordHit > 0.15 then
            AutoQTE.lastSwordHit = now
            local delayMs = Options.ReactionDelayMs and Options.ReactionDelayMs.Value or 0
            if delayMs > 0 then task.wait(delayMs / 1000) end
            safeClick(stopBtn)
            pressKey(Enum.KeyCode.Space)
        end
    end
end

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
                    if stopBtn then safeClick(stopBtn) end
                    pressKey(Enum.KeyCode.Space)
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

-- 6. FIST / CESTUS QTE (DIRECTIONAL ROTATION MATCHING)
local function handleFistQTE(fistQTE)
    if not Toggles.AutoFist or not Toggles.AutoFist.Value or not fistQTE or not fistQTE.Visible then return end
    local keyHolder = fistQTE:FindFirstChild("KeyHolder") or fistQTE:FindFirstChild("Inset")
    local otherControls = fistQTE:FindFirstChild("OtherControls")

    if keyHolder then
        for _, keyImg in ipairs(keyHolder:GetDescendants()) do
            if keyImg:IsA("GuiObject") and keyImg.Visible and (keyImg.ImageTransparency == nil or keyImg.ImageTransparency < 0.6) then
                local rot = keyImg.Rotation % 360
                local now = os.clock()
                if now - AutoQTE.lastFistHit > 0.12 then
                    AutoQTE.lastFistHit = now
                    if rot == 90 or keyImg.Name:find("Up") then
                        pressKey(Enum.KeyCode.Up)
                        pressKey(Enum.KeyCode.W)
                        if otherControls and otherControls:FindFirstChild("Up") then safeClick(otherControls.Up) end
                    elseif rot == 180 or keyImg.Name:find("Right") then
                        pressKey(Enum.KeyCode.Right)
                        pressKey(Enum.KeyCode.D)
                        if otherControls and otherControls:FindFirstChild("Right") then safeClick(otherControls.Right) end
                    elseif rot == 270 or keyImg.Name:find("Down") then
                        pressKey(Enum.KeyCode.Down)
                        pressKey(Enum.KeyCode.S)
                        if otherControls and otherControls:FindFirstChild("Down") then safeClick(otherControls.Down) end
                    elseif rot == 0 or keyImg.Name:find("Left") then
                        pressKey(Enum.KeyCode.Left)
                        pressKey(Enum.KeyCode.A)
                        if otherControls and otherControls:FindFirstChild("Left") then safeClick(otherControls.Left) end
                    end
                end
            end
        end
    end
end

-- 7. SPEAR QTE
local function handleSpearQTE(spearQTE)
    if not spearQTE or not spearQTE.Visible then return end
    local container = spearQTE:FindFirstChild("Container")
    if container then
        for _, tap in ipairs(container:GetChildren()) do
            if tap:IsA("GuiObject") and tap.Visible then
                local btn = tap:FindFirstChildWhichIsA("TextButton", true) or tap:FindFirstChildWhichIsA("ImageButton", true)
                if btn then safeClick(btn) end
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
            pressKey(Enum.KeyCode.Space)
        end
    end
end

-- Hook QTE vào RenderStepped
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
-- INGREDIENT ESP ENGINE (OOP BILLBOARD ENGINE)
-- =============================================================================
local ESP_Colors = {
    ["Crylight"]        = Color3.fromRGB(0, 255, 255),
    ["Cryastem"]        = Color3.fromRGB(80, 180, 255),
    ["Hightail"]        = Color3.fromRGB(120, 255, 120),
    ["Everthistle"]     = Color3.fromRGB(255, 215, 0),
    ["Carnastool"]      = Color3.fromRGB(255, 90, 90),
    ["Driproot"]        = Color3.fromRGB(180, 110, 60),
    ["Cursed Shroom"]   = Color3.fromRGB(190, 80, 255),
    ["Cursed Shroom 2"] = Color3.fromRGB(210, 100, 255),
    ["Mushrooms"]       = Color3.fromRGB(200, 200, 200),
    ["Ferrus"]          = Color3.fromRGB(255, 140, 0),
    ["Aestic"]          = Color3.fromRGB(255, 180, 50),
    ["Laneus"]          = Color3.fromRGB(230, 230, 120),
    ["Bones"]           = Color3.fromRGB(240, 240, 240),
    ["Branch Pile"]     = Color3.fromRGB(160, 120, 80),
}

local ESPObjects = {}

local function createESP(inst)
    if not inst or isBlacklistedCrylight(inst) then return end
    local name = inst.Name
    local color = ESP_Colors[name] or Color3.new(1, 1, 1)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. name
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(1e5, 0, 1e5, 0)
    billboard.Enabled = false
    billboard.Adornee = inst
    billboard.AutoLocalize = false
    billboard.ClipsDescendants = false
    billboard.Parent = workspace

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Label"
    textLabel.BackgroundTransparency = 1.0
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.TextStrokeTransparency = 0.0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.TextColor3 = color
    textLabel.TextSize = 13
    textLabel.Font = Enum.Font.Code
    textLabel.Parent = billboard

    if inst:IsA("Model") then
        pcall(function() inst.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
    end

    ESPObjects[inst] = {
        billboard = billboard,
        label = textLabel,
        name = name,
        color = color
    }
end

local function removeESP(inst)
    local data = ESPObjects[inst]
    if data then
        if data.billboard then data.billboard:Destroy() end
        ESPObjects[inst] = nil
    end
end

local function shouldShowESP(name)
    if not Toggles.MasterESP or not Toggles.MasterESP.Value then return false end
    local mode = Options.ESPFilterMode and Options.ESPFilterMode.Value or "All"
    if mode == "CrylightOnly" then return name == "Crylight"
    elseif mode == "Whitelist" then
        return Options.ESPWhitelist and Options.ESPWhitelist.Value and Options.ESPWhitelist.Value[name] == true
    end
    return true
end

-- Update ESP Loop
RunService.RenderStepped:Connect(function()
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 5000
    local showDist = Toggles.ESPShowDistance and Toggles.ESPShowDistance.Value

    for inst, data in pairs(ESPObjects) do
        if not inst.Parent then
            removeESP(inst)
        else
            if shouldShowESP(data.name) and localRoot then
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

-- Quét toàn bộ workspace ban đầu
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
    TabPadding = 6,
    MenuFadeTime = 0.2
})

local Tabs = {
    AutoFarm = Window:AddTab("💎 Auto Farm"),
    AutoQTE  = Window:AddTab("⚔️ Combat"),
    Visuals  = Window:AddTab("👁️ Visuals & FPS"),
    Settings = Window:AddTab("⚙️ Settings"),
}

-- -----------------------------------------------------------------------------
-- TAB 1: AUTO FARM CRYLIGHT
-- -----------------------------------------------------------------------------
local FarmGroup = Tabs.AutoFarm:AddLeftGroupbox("Crylight Auto Hunter")
local HopGroup = Tabs.AutoFarm:AddRightGroupbox("Server Hop & Webhook")

FarmGroup:AddToggle("AutoFarmCrylight", {
    Text = "Enable Auto Farm Crylight",
    Default = false,
    Tooltip = "Tự động kiểm tra tại Menu -> Vào game -> Bay Sky-Tween -> Lụm -> Đổi Server",
    Callback = function(Value)
        if Value then Farmer.runCycle() else Farmer.stop() end
    end
})

FarmGroup:AddToggle("AutoStart", {
    Text = "Auto Start / Skip Intro",
    Default = false,
    Tooltip = "Tự động bấm Skip, Play, YES khi cần vào game",
})

FarmGroup:AddToggle("AutoSkipIntro", {
    Text = "Auto Skip Cutscenes",
    Default = false,
})

FarmGroup:AddToggle("BlacklistDesert", {
    Text = "Ignore Desert Fake Crylights",
    Default = false,
    Tooltip = "Bỏ qua 2 viên Crylight trang trí không lụm được ở Desert",
})

FarmGroup:AddSlider("SkyHeight", {
    Text = "Sky Flight Altitude (Y)",
    Default = 950,
    Min = 500,
    Max = 1500,
    Rounding = 0,
    Compact = false,
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
    Tooltip = "Tự động đổi server khi lụm xong hoặc khi server không có Crylight",
})

HopGroup:AddSlider("MaxPlayerBuffer", {
    Text = "Free Slots Required",
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 0,
    Tooltip = "Chỉ vào server còn trống ít nhất N chỗ (tránh bị server full)",
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
    Tooltip = "Chuyển sang server mới ngay lập tức"
})

HopGroup:AddButton({
    Text = "Clear Visited Server Cache",
    Func = function()
        if writefile then writefile(ServerHopper.visitedFile, "{}") end
        Library:Notify("Đã xóa bộ nhớ đệm server đã vào!", 3)
    end,
    DoubleClick = false,
})

-- -----------------------------------------------------------------------------
-- TAB 2: AUTO COMBAT QTE
-- -----------------------------------------------------------------------------
local DefenseGroup = Tabs.AutoQTE:AddLeftGroupbox("Defense QTE")
local WeaponGroup = Tabs.AutoQTE:AddRightGroupbox("Weapon QTEs")

DefenseGroup:AddToggle("MasterQTE", {
    Text = "Enable Master Auto QTE",
    Default = false,
    Tooltip = "Bật/Tắt toàn bộ hệ thống QTE",
})

DefenseGroup:AddToggle("AutoDodge", {
    Text = "Auto Perfect Dodge",
    Default = false,
    Tooltip = "Tự động né đòn hoàn hảo (100% né tránh sát thương)",
})

DefenseGroup:AddToggle("PreferPerfectDodge", {
    Text = "Prefer Perfect Dodge over Block",
    Default = false,
    Tooltip = "Ưu tiên bắt ô né hoàn hảo thay vì chỉ đỡ đòn",
})

DefenseGroup:AddSlider("ReactionDelayMs", {
    Text = "Reaction Delay (ms)",
    Default = 0,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Tooltip = "Để 0 để đánh chuẩn xác tuyệt đối tức thì",
})

DefenseGroup:AddToggle("AutoLockpick", {
    Text = "Auto Lockpick Chests",
    Default = false,
    Tooltip = "Tự động mở khóa rương kho báu",
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
-- TAB 3: VISUALS & FPS BOOSTER
-- -----------------------------------------------------------------------------
local ESPGroup = Tabs.Visuals:AddLeftGroupbox("👁️ Ingredient ESP")
local FilterGroup = Tabs.Visuals:AddLeftGroupbox("🎯 Filters & Categories")
local FPSGroup = Tabs.Visuals:AddRightGroupbox("⚡ FPS Booster")
local OptGroup = Tabs.Visuals:AddRightGroupbox("🛠️ Optimization & RAM")

local Lighting = game:GetService("Lighting")
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
-- TAB 4: SETTINGS / CONFIG
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

-- Tự động Load cấu hình mặc định (nếu có)
SaveManager:LoadAutoloadConfig()

-- =============================================================================
-- KHỞI CHẠY CHU TRÌNH TỰ ĐỘNG
-- =============================================================================
shared.ArcaneHub = Library

-- Kích hoạt chu trình Auto Farm Menu-Scan nếu được bật
if Toggles.AutoFarmCrylight and Toggles.AutoFarmCrylight.Value then
    Farmer.runCycle()
end

Library:Notify("✨ Arcane Lineage Master Hub đã khởi chạy thành công! (Bấm RightControl để ẩn/hiện menu)", 5)
