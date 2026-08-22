-- ========================================================================================
-- ⚙️ BẢNG CÀI ĐẶT / SETTINGS (CHỈNH SỬA TÙY CHỌN TẠI ĐÂY)
-- ========================================================================================
local Config = {
    -- 1. [TỰ ĐỘNG VÀO GAME & SKIP INTRO] (AUTO START)
    AutoStart           = true,     -- Tự động bấm Skip, Play và YES ở Main Menu khi tìm thấy Crylight
    AutoSkipIntro       = true,     -- Tự động bấm các nút Skip / Bỏ qua giới thiệu đầu game

    -- 2. [CẤU HÌNH BAY TRÁNH COMBAT] (SKY TWEEN & FLIGHT)
    SkyHeight           = 950,      -- Độ cao bay trên bầu trời (tránh mọi địa hình, quái & combat)
    AscendSpeed         = 120,      -- Tốc độ bay thẳng đứng vọt lên trời (studs/giây)
    CruiseSpeed         = 110,      -- Tốc độ bay ngang trên không trung (studs/giây)
    DescendSpeed        = 120,      -- Tốc độ hạ cánh xuống sát Crylight (studs/giây)
    PickupTimeout       = 5,        -- Thời gian tối đa (giây) cố gắng lụm 1 viên trước khi bỏ qua

    -- 3. [TỰ ĐỘNG ĐỔI SERVER] (AUTO SERVER HOP & ANTI-STUCK)
    AutoServerHop       = true,     -- Tự động đổi server khi lụm hết Crylight (hoặc khi server không có)
    MenuCheckDelay      = 2.5,      -- Thời gian đợi ở Menu (giây) để game tải tài nguyên trước khi kiểm tra
    MaxVisitedLimit     = 20,       -- Tự động xóa danh sách server đã vào sau 20 lần hop (tránh hết server)
    MaxPlayerBuffer     = 2,        -- Chỉ vào server còn trống ít nhất N chỗ (tránh bị full khi kết nối)
    TeleportTimeout     = 8,        -- Thời gian tối đa (giây) chờ teleport; nếu kẹt sẽ tự đổi server khác ngay

    -- 4. [LỌC CRYLIGHT TRANG TRÍ Ở DESERT] (BLACKLIST)
    BlacklistDesertCrylight = true, -- Bỏ qua 2 viên Crylight lỗi/trang trí mặc định ở Desert
    DesertDefaultCenter = Vector3.new(1423.0, 616.7, -4468.5),
    DesertBlacklistRadius = 50,

    -- 5. [THÔNG BÁO DISCORD] (DISCORD WEBHOOK)
    DiscordWebhook      = "",       -- Dán URL Discord Webhook vào đây (để trống nếu không dùng)
    NotifyOnHarvest     = true,     -- Bắn thông báo lên Discord khi thu hoạch thành công
}
-- ========================================================================================
-- (HẾT PHẦN CÀI ĐẶT - KHÔNG CẦN CHỈNH SỬA PHẦN DƯỚI ĐÂY)
-- ========================================================================================

-- ĐỢI GAME VÀ ASSETS TẢI HOÀN TẤT TRƯỚC KHI CHẠY (CHỐNG LỖI EXECUTE SỚM)
if not game:IsLoaded() then
    print("[GameLoader] Đang chờ game tải hoàn tất...")
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)

if shared.CrylightAutoFarm then
    pcall(function() shared.CrylightAutoFarm.stop() end)
    shared.CrylightAutoFarm = nil
end

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Hàm HTTP request đa năng của các Executor
local HttpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- =============================================================================
-- HÀM TIỆN ÍCH (UTILITIES)
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

local function isBlacklisted(inst)
    if not inst then return true end
    if Config.BlacklistDesertCrylight and inst.Name == "Crylight" then
        local pos = inst:GetPivot().Position
        local dist = (pos - Config.DesertDefaultCenter).Magnitude
        if dist <= Config.DesertBlacklistRadius then
            return true
        end
    end
    return false
end

-- =============================================================================
-- AUTO START MENU / SKIP INTRO / CHARACTER LOADER
-- =============================================================================
local function handleAutoStart()
    if not Config.AutoStart then return end
    print("[AutoStart] Đang kiểm tra Skip Intro và Start Menu đầu game...")

    local startTime = os.clock()
    while os.clock() - startTime < 15 do
        if Config.AutoSkipIntro and PlayerGui then
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
-- SERVER HOPPER (CHỐNG KẸT / TỰ ĐỘNG XÓA DỮ LIỆU SAU 20 SERVER)
-- =============================================================================
local ServerHopper = {
    isHopping = false,
    lastAttemptServer = nil,
    visitedFile = "Crylight_Visited_Servers.json"
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
    local count = 0
    for _ in pairs(visited) do count = count + 1 end

    -- NẾU ĐÃ HOP QUÁ 20 SERVER THÌ TỰ ĐỘNG XÓA TOÀN BỘ ĐỂ TRÁNH HẾT SERVER
    if count >= Config.MaxVisitedLimit then
        print(string.format("[ServerHop] 🔄 Đã hop qua %d server. Đang xóa bộ nhớ đệm để tìm lại toàn bộ server mới!", count))
        visited = {}
    end

    visited[jobId] = os.time()
    if writefile then pcall(function() writefile(ServerHopper.visitedFile, HttpService:JSONEncode(visited)) end) end
end

function ServerHopper.hop()
    if ServerHopper.isHopping then return end
    ServerHopper.isHopping = true

    print("[ServerHop] 🔍 Đang quét tìm danh sách server mới...")
    saveVisitedServer(game.JobId)

    task.spawn(function()
        local placeId = game.PlaceId
        local visited = getVisitedServers()
        local nextCursor = ""
        local candidates = {}

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
                        if s.id ~= game.JobId and playing <= (maxP - Config.MaxPlayerBuffer) and not visited[s.id] then
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
            print(string.format("[ServerHop] 🚀 Đang kết nối tới server: %s (%d/%d người)...", targetServer.id, targetServer.playing, targetServer.maxPlayers))
            ServerHopper.lastAttemptServer = targetServer.id
            saveVisitedServer(targetServer.id)

            pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
            end)

            task.wait(Config.TeleportTimeout)
            if ServerHopper.isHopping then
                warn("[ServerHop] ⏱️ Quá thời gian chờ teleport. Đang tự động đổi sang server khác...")
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
-- DISCORD WEBHOOK
-- =============================================================================
local function sendDiscordReport(harvestedCount)
    if not Config.DiscordWebhook or #Config.DiscordWebhook < 10 or not HttpRequest then return end

    task.spawn(function()
        local payload = {
            username = "Crylight Auto Farmer",
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
                footer = { text = "Arcane Lineage • Auto Farmer" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        pcall(function()
            HttpRequest({
                Url = Config.DiscordWebhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

-- =============================================================================
-- SKY TWEEN ENGINE
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

    local currentPos = root.Position
    local skyY = math.max(Config.SkyHeight, currentPos.Y + 100)

    -- Phase 1: Bay thẳng đứng lên trời cao
    tweenTo(CFrame.new(currentPos.X, skyY, currentPos.Z), Config.AscendSpeed)
    if not Farmer.running then return false end

    -- Phase 2: Bay ngang trên không trung tới ngay trên đầu Crylight
    tweenTo(CFrame.new(targetPosition.X, skyY, targetPosition.Z), Config.CruiseSpeed)
    if not Farmer.running then return false end

    -- Phase 3: Hạ cánh thẳng đứng xuống cách Crylight 3.5 studs
    tweenTo(CFrame.new(targetPosition.X, targetPosition.Y + 3.5, targetPosition.Z), Config.DescendSpeed)
    return true
end

local function harvestItem(model)
    if not model or not model.Parent then return false end
    local startTime = os.clock()

    while model and model.Parent and (os.clock() - startTime < Config.PickupTimeout) and Farmer.running do
        local cd = model:FindFirstChildWhichIsA("ClickDetector", true)
        if cd and fireclickdetector then fireclickdetector(cd) end
        task.wait(0.2)
    end
    return (model.Parent == nil)
end

-- =============================================================================
-- MAIN FARMING ROUTINE (KIỂM TRA NGAY TẠI MENU -> TIẾT KIỆM THỜI GIAN)
-- =============================================================================
function Farmer.start()
    if Farmer.running then return end
    Farmer.running = true

    task.spawn(function()
        print(string.format("[AutoFarm] 🔍 [BƯỚC 1]: Đang quét Crylight ngay tại Menu (chờ %.1fs)...", Config.MenuCheckDelay))
        task.wait(Config.MenuCheckDelay)

        -- Quét danh sách Crylight thật có thể lụm
        local harvestList = {}
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc.Name == "Crylight" and desc.Parent and not isBlacklisted(desc) then
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
                    print(string.format("[AutoFarm] 🎯 [%d/%d] Đang di chuyển đến Crylight tại: (%.1f, %.1f, %.1f)", i, #harvestList, targetPos.X, targetPos.Y, targetPos.Z))

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
                tweenTo(CFrame.new(root.Position.X, Config.SkyHeight, root.Position.Z), Config.AscendSpeed)
            end

            if totalHarvested > 0 and Config.NotifyOnHarvest then
                sendDiscordReport(totalHarvested)
            end
        else
            -- NẾU KHÔNG CÓ CRYLIGHT: KHÔNG CẦN SPAWN VÀO GAME -> HOP LUÔN TỪ MENU ĐỂ TIẾT KIỆM THỜI GIAN
            print("[AutoFarm] ❌ Server này không có Crylight thật! Đang Server Hop ngay từ Main Menu...")
        end

        disableNoClip()

        -- Tự động Server Hop sau khi hoàn thành
        if Config.AutoServerHop and Farmer.running then
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

shared.CrylightAutoFarm = Farmer
Farmer.start()
