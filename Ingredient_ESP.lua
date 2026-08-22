-- ========================================================================================
-- ⚙️ BẢNG CÀI ĐẶT / SETTINGS ESP & CRYLIGHT HUNTER (CHỈNH SỬA TẠI ĐÂY)
-- ========================================================================================
local Config = {
    -- 1. Cấu hình ESP
    Enabled             = true,
    MaxDistance         = 10000, -- Khoảng cách tối đa vẽ ESP (studs)
    ShowDistance        = true,  -- Hiển thị số mét [..m]
    FontSize            = 13,
    Font                = Enum.Font.Code,
    Persistent          = true,   -- ModelStreamingMode.Persistent chống stream-out
    
    -- FilterMode: "All" | "CrylightOnly" | "Whitelist"
    FilterMode          = "All",
    
    FilterList = {
        ["Crylight"]        = true,
        ["Cryastem"]        = true,
        ["Hightail"]        = true,
        ["Everthistle"]     = true,
        ["Carnastool"]      = true,
        ["Driproot"]        = true,
        ["Cursed Shroom"]   = true,
        ["Cursed Shroom 2"] = true,
        ["Mushrooms"]       = true,
        ["Bones"]           = true,
        ["Branch Pile"]     = true,
        ["Ferrus"]          = true,
        ["Aestic"]          = true,
        ["Laneus"]          = true,
    },

    -- 2. Lọc Crylight trang trí ở Desert (không lụm được)
    BlacklistDesertCrylight = true,
    DesertDefaultCenter = Vector3.new(1423.0, 616.7, -4468.5),
    DesertBlacklistRadius = 50,

    -- 3. Cấu hình Discord Webhook
    DiscordWebhook      = "",       -- Dán URL Discord Webhook vào đây (để trống nếu không dùng)
    NotifyOnCrylight    = true,     -- Gửi thông báo khi phát hiện Crylight thật
    NotifyTagEveryone   = false,

    -- 4. Cấu hình Tự động Server Hop (Auto Server Hop & Anti-Stuck)
    AutoServerHop       = false,    -- Bật true nếu muốn script tự động đổi server liên tục
    HopIfNoCrylight     = true,     -- Tự động đổi server nếu sau vài giây quét không có Crylight
    HopDelay            = 6,        -- Thời gian chờ (giây) sau khi vào server
    MaxPlayerBuffer     = 2,        -- Chỉ vào server còn trống ít nhất N chỗ (tránh bị full khi kết nối)
    TeleportTimeout     = 8,        -- Thời gian tối đa (giây) chờ teleport; nếu kẹt sẽ tự đổi server khác ngay
    SaveVisitedServers  = true,     -- Lưu danh sách server đã vào trong 15 phút

    -- 5. Bảng màu sắc ESP
    Colors = {
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
        ["Default"]         = Color3.fromRGB(255, 255, 255),
    }
}
-- ========================================================================================
-- (HẾT PHẦN CÀI ĐẶT)
-- ========================================================================================

-- ĐỢI GAME VÀ ASSETS TẢI HOÀN TẤT TRƯỚC KHI CHẠY (CHỐNG LỖI EXECUTE SỚM)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

if shared.IngredientESP then
    pcall(function() shared.IngredientESP.detach() end)
    shared.IngredientESP = nil
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local HttpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({ _tasks = {} }, Maid) end
function Maid:mark(task) table.insert(self._tasks, task); return task end
function Maid:clean()
    for _, task in ipairs(self._tasks) do
        if typeof(task) == "RBXScriptConnection" then task:Disconnect()
        elseif typeof(task) == "Instance" then task:Destroy()
        elseif type(task) == "function" then pcall(task)
        elseif typeof(task) == "table" and task.detach then pcall(function() task:detach() end)
        end
    end
    self._tasks = {}
end

local function isBlacklisted(inst)
    if not inst then return true end
    if Config.BlacklistDesertCrylight and inst.Name == "Crylight" then
        local pos = inst:GetPivot().Position
        local dist = (pos - Config.DesertDefaultCenter).Magnitude
        if dist <= Config.DesertBlacklistRadius then return true end
    end
    return false
end

local InstanceESP = {}
InstanceESP.__index = InstanceESP
function InstanceESP.new(instance, label, color)
    local self = setmetatable({}, InstanceESP)
    self.maid = Maid.new()
    self.instance = instance
    self.label = label
    self.color = color or Config.Colors[label] or Config.Colors["Default"]
    self:setup()
    return self
end
function InstanceESP:setup()
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. tostring(self.label)
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(1e5, 0, 1e5, 0)
    billboard.Enabled = false
    billboard.Adornee = self.instance
    billboard.AutoLocalize = false
    billboard.ClipsDescendants = false
    billboard.Parent = workspace

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Label"
    textLabel.BackgroundTransparency = 1.0
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.TextStrokeTransparency = 0.0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.TextColor3 = self.color
    textLabel.TextSize = Config.FontSize
    textLabel.Font = Config.Font
    textLabel.AutoLocalize = false
    textLabel.Parent = billboard

    self.billboard = self.maid:mark(billboard)
    self.textLabel = self.maid:mark(textLabel)
end
function InstanceESP:visible(state) if self.billboard then self.billboard.Enabled = state end end
function InstanceESP:update(position)
    if not Config.Enabled then return self:visible(false) end
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return self:visible(false) end
    local distance = (localRoot.Position - position).Magnitude
    if distance > Config.MaxDistance then return self:visible(false) end
    local displayText = self.label
    if Config.ShowDistance then displayText = string.format("%s [%dm]", self.label, math.floor(distance)) end
    self.textLabel.Text = displayText
    self.textLabel.TextColor3 = self.color
    self.textLabel.TextSize = Config.FontSize
    self.textLabel.Font = Config.Font
    self:visible(true)
end
function InstanceESP:detach() self.maid:clean() end

local ModelESP = setmetatable({}, { __index = InstanceESP })
ModelESP.__index = ModelESP
function ModelESP.new(model, label, color)
    local self = setmetatable(InstanceESP.new(model, label, color), ModelESP)
    self.model = model
    if Config.Persistent and model:IsA("Model") then pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end) end
    return self
end
function ModelESP:update()
    local model = self.model
    if not model or not model.Parent then return self:visible(false) end
    InstanceESP.update(self, model:GetPivot().Position)
end

local PartESP = setmetatable({}, { __index = InstanceESP })
PartESP.__index = PartESP
function PartESP.new(part, label, color)
    local self = setmetatable(InstanceESP.new(part, label, color), PartESP)
    self.part = part
    return self
end
function PartESP:update()
    local part = self.part
    if not part or not part.Parent then return self:visible(false) end
    InstanceESP.update(self, part.Position)
end

local Group = {}
Group.__index = Group
function Group.new() return setmetatable({ objects = {} }, Group) end
function Group:insert(inst, espObj) self.objects[inst] = espObj end
function Group:remove(inst)
    local obj = self.objects[inst]
    if obj then obj:detach(); self.objects[inst] = nil end
end
function Group:update()
    for inst, obj in pairs(self.objects) do
        if not inst.Parent then self:remove(inst) else obj:update() end
    end
end
function Group:detach() for _, obj in pairs(self.objects) do obj:detach() end; self.objects = {} end

local WebhookNotifier = { alreadyNotified = false }
function WebhookNotifier.sendCrylightAlert(crylightItems)
    if WebhookNotifier.alreadyNotified then return end
    if not Config.DiscordWebhook or #Config.DiscordWebhook < 10 or not HttpRequest then return end
    WebhookNotifier.alreadyNotified = true

    task.spawn(function()
        local count = #crylightItems
        local fields = {
            { name = "📍 Số lượng Crylight Thật", value = string.format("**%d** viên", count), inline = true },
            { name = "👤 Nhân vật", value = string.format("`%s` (%s)", LocalPlayer.Name, LocalPlayer.DisplayName), inline = true },
            { name = "🆔 Server JobId", value = string.format("`%s`", game.JobId), inline = false },
        }
        for i, item in ipairs(crylightItems) do
            if i <= 6 then
                local pos = item:GetPivot().Position
                fields[#fields + 1] = {
                    name = string.format("💎 Tọa độ Crylight #%d", i),
                    value = string.format("X: `%.1f` | Y: `%.1f` | Z: `%.1f`", pos.X, pos.Y, pos.Z),
                    inline = true
                }
            end
        end
        fields[#fields + 1] = {
            name = "⚡ Mã Teleport Rejoin Server Này",
            value = string.format("```lua\ngame:GetService('TeleportService'):TeleportToPlaceInstance(%d, '%s', game.Players.LocalPlayer)\n```", game.PlaceId, game.JobId),
            inline = false
        }
        local payload = {
            content = Config.NotifyTagEveryone and "@everyone" or nil,
            username = "Crylight Hunter",
            avatar_url = "https://cdn-icons-png.flaticon.com/512/3655/3655581.png",
            embeds = {{
                title = "✨ ĐÃ TÌM THẤY CRYLIGHT (REAL) TRONG SERVER! ✨",
                description = string.format("Hệ thống phát hiện **%d** Crylight có thể lụm được tại server hiện tại!", count),
                color = 0x00FFFF,
                fields = fields,
                footer = { text = "Arcane Lineage • Crylight Auto Hunter" },
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
    local now = os.time()
    for id, timestamp in pairs(visited) do if now - timestamp > 900 then visited[id] = nil end end
    return visited
end

local function saveVisitedServer(jobId)
    local visited = getVisitedServers()
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
            print(string.format("[ServerHop] 🚀 Tìm thấy %d server khả dụng! Đang kết nối tới: %s (%d/%d người)...", #candidates, targetServer.id, targetServer.playing, targetServer.maxPlayers))
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
            warn("[ServerHop] ⚠️ Không tìm thấy server nào khả dụng. Đang thử lại sau 3 giây...")
            ServerHopper.isHopping = false
            task.wait(3)
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

local IngredientESP = { group = Group.new(), maid = Maid.new() }
local function shouldTrack(name)
    if Config.FilterMode == "CrylightOnly" then return name == "Crylight"
    elseif Config.FilterMode == "Whitelist" then return Config.FilterList[name] == true
    elseif Config.FilterMode == "All" then return Config.FilterList[name] == true or Config.Colors[name] ~= nil
    end
    return false
end
local function checkAndAdd(child)
    if not child then return end
    if isBlacklisted(child) then return end
    local name = child.Name
    if shouldTrack(name) then
        if child:IsA("Model") then
            IngredientESP.group:insert(child, ModelESP.new(child, name, Config.Colors[name]))
        elseif child:IsA("BasePart") then
            IngredientESP.group:insert(child, PartESP.new(child, name, Config.Colors[name]))
        end
    end
end

function IngredientESP.init()
    print("[IngredientESP] Đang quét workspace...")
    for _, desc in ipairs(workspace:GetDescendants()) do checkAndAdd(desc) end
    IngredientESP.maid:mark(workspace.DescendantAdded:Connect(checkAndAdd))
    IngredientESP.maid:mark(workspace.DescendantRemoving:Connect(function(desc) IngredientESP.group:remove(desc) end))
    IngredientESP.maid:mark(RunService.RenderStepped:Connect(function() IngredientESP.group:update() end))
    
    local count = 0
    for _ in pairs(IngredientESP.group.objects) do count = count + 1 end
    print(string.format("[IngredientESP] Khởi chạy thành công! Đang theo dõi %d nguyên liệu.", count))

    task.spawn(function()
        task.wait(Config.HopDelay)
        local validCrylights = {}
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc.Name == "Crylight" and desc.Parent and not isBlacklisted(desc) then table.insert(validCrylights, desc) end
        end
        if #validCrylights > 0 then
            print(string.format("[Hunter] 🌟 PHÁT HIỆN %d VIÊN CRYLIGHT THẬT TRONG SERVER!", #validCrylights))
            if Config.NotifyOnCrylight then WebhookNotifier.sendCrylightAlert(validCrylights) end
        else
            print("[Hunter] ❌ Không có Crylight thật trong server này.")
            if Config.AutoServerHop or Config.HopIfNoCrylight then
                print("[Hunter] Đang Server Hop...")
                ServerHopper.hop()
            end
        end
    end)
end

function IngredientESP.detach()
    IngredientESP.maid:clean()
    IngredientESP.group:detach()
    print("[IngredientESP] Đã tắt ESP.")
end

shared.IngredientESP = IngredientESP
IngredientESP.init()
