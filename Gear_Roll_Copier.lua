--[[
    ========================================================================================
    🌟 ARCANE LINEAGE - STANDALONE GEAR ROLL & STAT COPIER TOOL
    ========================================================================================
    Features:
    • 🔍 Scan & List all Gears, Artifacts, and Weapons in your inventory with current stats & seeds.
    • 🔄 Gear Roll Copy: Select Source Gear -> Select Target Gear -> Copy Seed, Tier & Stats 100%!
    • 👑 God-Roll Presets: Apply Tier 6 Max Stats (+6 Strength, +6 Arcane, +6 Speed, +6 Endurance, etc.).
    • ⚡ Instant Live Memory Modification: Realtime sync with PlayerGui.Inventory and StatMenu.
    ========================================================================================
--]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Clean up any existing UI instance
if shared.ArcaneGearCopierUI then
    pcall(function() shared.ArcaneGearCopierUI:Destroy() end)
    shared.ArcaneGearCopierUI = nil
end

local GearCopier = {
    gears = {},
    sourceGear = nil,
    targetGear = nil,
}

-- 1. Helper: Scan and extract all modifiable gear tile objects from memory
function GearCopier.scanGears()
    local found = {}
    local invSync = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Data") and ReplicatedStorage.Remotes.Data:FindFirstChild("InventorySync")
    
    if invSync and getconnections then
        for _, conn in ipairs(getconnections(invSync.OnClientEvent)) do
            local fn = conn.Function
            if fn and debug and debug.getupvalues then
                local uvs = debug.getupvalues(fn)
                for _, uv in pairs(uvs) do
                    if type(uv) == "table" then
                        for k, v in pairs(uv) do
                            if type(v) == "table" and v.ItemData and v.ItemData.Config then
                                local item = v.ItemData
                                local cfg = item.Config
                                local statSummary = ""
                                if cfg.TierStats and type(cfg.TierStats) == "table" then
                                    local statList = {}
                                    for sn, sv in pairs(cfg.TierStats) do
                                        table.insert(statList, string.format("%s: +%s", sn, tostring(sv)))
                                    end
                                    statSummary = table.concat(statList, ", ")
                                end
                                if #statSummary == 0 then
                                    statSummary = (cfg.Unidentified and "Unidentified" or "No Stats")
                                end

                                table.insert(found, {
                                    TileObj = v,
                                    Key = k,
                                    Name = item.Name or "Unknown",
                                    Unique_Id = item.Unique_Id or (item.Name .. "#" .. tostring(cfg.Seed or math.random(100000, 999999))),
                                    Config = cfg,
                                    Tier = cfg.Tier or 0,
                                    Seed = cfg.Seed or 0,
                                    Rarity = cfg.Rarity or "Common",
                                    Kind = cfg.Kind or "Gear",
                                    StatSummary = statSummary,
                                    DisplayName = string.format("%s [%s] (%s)", item.Name, cfg.Rarity or "Common", statSummary)
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    GearCopier.gears = found
    print(string.format("[GearCopier] 🔍 Quét thấy %d trang bị trong kho đồ!", #found))
    return found
end

-- 2. Helper: Clone Table deeply
local function deepClone(tbl)
    if type(tbl) ~= "table" then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = deepClone(v)
    end
    return copy
end

-- 3. Core Engine: Copy Stats & Seed from Source to Target
function GearCopier.copyStats(sourceItem, targetItem)
    if not sourceItem or not targetItem then
        return false, "Vui lòng chọn cả Source Gear và Target Gear!"
    end

    if sourceItem == targetItem then
        return false, "Source Gear và Target Gear không được trùng nhau!"
    end

    local srcCfg = sourceItem.Config
    local tgtCfg = targetItem.Config

    if not srcCfg or not tgtCfg then
        return false, "Không tìm thấy cấu hình Config của trang bị!"
    end

    -- Sao chép toàn bộ thuộc tính cốt lõi (Seed, Tier, TierStats, Traits, Rarity)
    tgtCfg.Seed = srcCfg.Seed
    tgtCfg.Tier = srcCfg.Tier
    tgtCfg.Rarity = srcCfg.Rarity
    tgtCfg.Unidentified = false

    if srcCfg.TierStats then
        tgtCfg.TierStats = deepClone(srcCfg.TierStats)
    else
        tgtCfg.TierStats = {}
    end

    if srcCfg.Traits then
        tgtCfg.Traits = deepClone(srcCfg.Traits)
    end

    -- Cập nhật lại đối tượng Tile trong bộ nhớ
    if targetItem.TileObj and targetItem.TileObj.ItemData then
        targetItem.TileObj.ItemData.Config = tgtCfg
    end

    local statsSummary = ""
    if tgtCfg.TierStats then
        for sn, sv in pairs(tgtCfg.TierStats) do
            statsSummary = statsSummary .. string.format("%s: +%d ", sn, sv)
        end
    end

    print("==================================================================")
    print("✨ [GEAR ROLL COPY SUCCESSFUL] SAO CHÉP STATS THÀNH CÔNG!")
    print(string.format("   -> Source: %s (UID: %s)", sourceItem.Name, tostring(sourceItem.Unique_Id)))
    print(string.format("   -> Target: %s (UID: %s)", targetItem.Name, tostring(targetItem.Unique_Id)))
    print(string.format("   -> Copied Seed: %s | Tier: %s | Rarity: %s", tostring(tgtCfg.Seed), tostring(tgtCfg.Tier), tostring(tgtCfg.Rarity)))
    print(string.format("   -> New Stats: %s", statsSummary))
    print("==================================================================")

    return true, string.format("Đã sao chép Stats sang %s! (%s)", targetItem.Name, statsSummary)
end

-- 4. Core Engine: Apply Custom God-Roll Stats
function GearCopier.applyGodRoll(targetItem, tier, rarity, statsTable)
    if not targetItem or not targetItem.Config then
        return false, "Vui lòng chọn Target Gear trước!"
    end

    local cfg = targetItem.Config
    cfg.Tier = tier or 6
    cfg.Rarity = rarity or "Legendary"
    cfg.Unidentified = false
    cfg.Seed = math.random(100000000, 999999999)
    cfg.TierStats = deepClone(statsTable)

    if targetItem.TileObj and targetItem.TileObj.ItemData then
        targetItem.TileObj.ItemData.Config = cfg
    end

    local statsSummary = ""
    for sn, sv in pairs(statsTable) do
        statsSummary = statsSummary .. string.format("%s: +%d ", sn, sv)
    end

    print(string.format("[GearCopier] 👑 Đã áp dụng God-Roll (Tier %d) cho %s: %s", cfg.Tier, targetItem.Name, statsSummary))
    return true, string.format("Đã áp dụng God-Roll cho %s! (%s)", targetItem.Name, statsSummary)
end

-- 5. GUI Construction (Standalone Modern Dark-Tech Draggable UI)
function GearCopier.createUI()
    local parentGui = (gethui and gethui()) or game:GetService("CoreGui") or PlayerGui

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Arcane_Gear_Copier_UI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 420, 0, 480)
    mainFrame.Position = UDim2.new(0.5, -210, 0.5, -240)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = mainFrame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(70, 200, 120) -- Emerald Glow
    frameStroke.Thickness = 1.5
    frameStroke.Parent = mainFrame

    -- Header Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -60, 0, 32)
    title.Position = UDim2.new(0, 14, 0, 10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "✨ ARCANE LINEAGE • GEAR ROLL COPIER"
    title.TextColor3 = Color3.fromRGB(80, 255, 140)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0, 12)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 13
    closeBtn.Parent = mainFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        shared.ArcaneGearCopierUI = nil
    end)

    -- Status Notification Banner
    local statusBanner = Instance.new("TextLabel")
    statusBanner.Name = "StatusBanner"
    statusBanner.Size = UDim2.new(1, -28, 0, 26)
    statusBanner.Position = UDim2.new(0, 14, 0, 46)
    statusBanner.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
    statusBanner.BorderSizePixel = 0
    statusBanner.Font = Enum.Font.GothamMedium
    statusBanner.Text = "💡 Chọn Source Gear và Target Gear để sao chép Stats"
    statusBanner.TextColor3 = Color3.fromRGB(200, 220, 240)
    statusBanner.TextSize = 11
    statusBanner.Parent = mainFrame

    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 6)
    bannerCorner.Parent = statusBanner

    local function notifyUser(text, isError)
        statusBanner.Text = text
        statusBanner.TextColor3 = isError and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 160)
        task.delay(4.0, function()
            if statusBanner and statusBanner.Parent then
                statusBanner.Text = "💡 Chọn Source Gear và Target Gear để sao chép Stats"
                statusBanner.TextColor3 = Color3.fromRGB(200, 220, 240)
            end
        end)
    end

    -- Scrollable Container for Gear List & Actions
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -28, 1, -86)
    contentFrame.Position = UDim2.new(0, 14, 0, 78)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 4
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 520)
    contentFrame.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = contentFrame

    -- Section 1: Scan & Refresh Button
    local scanBtn = Instance.new("TextButton")
    scanBtn.Name = "ScanBtn"
    scanBtn.Size = UDim2.new(1, 0, 0, 32)
    scanBtn.BackgroundColor3 = Color3.fromRGB(35, 90, 160)
    scanBtn.BorderSizePixel = 0
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.Text = "🔄 QUÉT LẠI KHO ĐỒ (REFRESH INVENTORY)"
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.TextSize = 12
    scanBtn.Parent = contentFrame

    local scanCorner = Instance.new("UICorner")
    scanCorner.CornerRadius = UDim.new(0, 6)
    scanCorner.Parent = scanBtn

    -- Source Label & Value
    local srcLabel = Instance.new("TextLabel")
    srcLabel.Name = "SrcLabel"
    srcLabel.Size = UDim2.new(1, 0, 0, 18)
    srcLabel.BackgroundTransparency = 1
    srcLabel.Font = Enum.Font.GothamBold
    srcLabel.Text = "📥 1. SOURCE GEAR (MẪU CẦN COPY STATS):"
    srcLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
    srcLabel.TextSize = 12
    srcLabel.TextXAlignment = Enum.TextXAlignment.Left
    srcLabel.Parent = contentFrame

    local srcDisplay = Instance.new("TextLabel")
    srcDisplay.Name = "SrcDisplay"
    srcDisplay.Size = UDim2.new(1, 0, 0, 28)
    srcDisplay.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    srcDisplay.BorderSizePixel = 0
    srcDisplay.Font = Enum.Font.GothamMedium
    srcDisplay.Text = "  [Chưa chọn Source Gear]"
    srcDisplay.TextColor3 = Color3.fromRGB(180, 180, 190)
    srcDisplay.TextSize = 11
    srcDisplay.TextXAlignment = Enum.TextXAlignment.Left
    srcDisplay.Parent = contentFrame

    local srcCorner = Instance.new("UICorner")
    srcCorner.CornerRadius = UDim.new(0, 6)
    srcCorner.Parent = srcDisplay

    -- Target Label & Value
    local tgtLabel = Instance.new("TextLabel")
    tgtLabel.Name = "TgtLabel"
    tgtLabel.Size = UDim2.new(1, 0, 0, 18)
    tgtLabel.BackgroundTransparency = 1
    tgtLabel.Font = Enum.Font.GothamBold
    tgtLabel.Text = "🎯 2. TARGET GEAR (MÓN NHẬN STATS MỚI):"
    tgtLabel.TextColor3 = Color3.fromRGB(80, 220, 255)
    tgtLabel.TextSize = 12
    tgtLabel.TextXAlignment = Enum.TextXAlignment.Left
    tgtLabel.Parent = contentFrame

    local tgtDisplay = Instance.new("TextLabel")
    tgtDisplay.Name = "TgtDisplay"
    tgtDisplay.Size = UDim2.new(1, 0, 0, 28)
    tgtDisplay.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    tgtDisplay.BorderSizePixel = 0
    tgtDisplay.Font = Enum.Font.GothamMedium
    tgtDisplay.Text = "  [Chưa chọn Target Gear]"
    tgtDisplay.TextColor3 = Color3.fromRGB(180, 180, 190)
    tgtDisplay.TextSize = 11
    tgtDisplay.TextXAlignment = Enum.TextXAlignment.Left
    tgtDisplay.Parent = contentFrame

    local tgtCorner = Instance.new("UICorner")
    tgtCorner.CornerRadius = UDim.new(0, 6)
    tgtCorner.Parent = tgtDisplay

    -- Action Button: COPY STATS NOW
    local copyBtn = Instance.new("TextButton")
    copyBtn.Name = "CopyBtn"
    copyBtn.Size = UDim2.new(1, 0, 0, 36)
    copyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    copyBtn.BorderSizePixel = 0
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.Text = "✨ SAO CHÉP STATS (COPY STATS & SEED) ✨"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.TextSize = 13
    copyBtn.Parent = contentFrame

    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 6)
    copyCorner.Parent = copyBtn

    copyBtn.MouseButton1Click:Connect(function()
        local ok, msg = GearCopier.copyStats(GearCopier.sourceGear, GearCopier.targetGear)
        notifyUser(msg, not ok)
    end)

    -- God-Roll Presets Header
    local godLabel = Instance.new("TextLabel")
    godLabel.Name = "GodLabel"
    godLabel.Size = UDim2.new(1, 0, 0, 18)
    godLabel.BackgroundTransparency = 1
    godLabel.Font = Enum.Font.GothamBold
    godLabel.Text = "👑 GOD-ROLL PRESETS (ÁP DỤNG TRỰC TIẾP CHO TARGET):"
    godLabel.TextColor3 = Color3.fromRGB(255, 120, 220)
    godLabel.TextSize = 12
    godLabel.TextXAlignment = Enum.TextXAlignment.Left
    godLabel.Parent = contentFrame

    -- Preset 1: Max Damage God-Roll
    local p1Btn = Instance.new("TextButton")
    p1Btn.Name = "P1Btn"
    p1Btn.Size = UDim2.new(1, 0, 0, 30)
    p1Btn.BackgroundColor3 = Color3.fromRGB(140, 40, 60)
    p1Btn.BorderSizePixel = 0
    p1Btn.Font = Enum.Font.GothamBold
    p1Btn.Text = "💥 Max Dmg: +6 Strength | +6 Arcane (Tier 6)"
    p1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    p1Btn.TextSize = 11
    p1Btn.Parent = contentFrame

    local p1Corner = Instance.new("UICorner")
    p1Corner.CornerRadius = UDim.new(0, 6)
    p1Corner.Parent = p1Btn

    p1Btn.MouseButton1Click:Connect(function()
        local ok, msg = GearCopier.applyGodRoll(GearCopier.targetGear, 6, "Epic", { Strength = 6, Arcane = 6 })
        notifyUser(msg, not ok)
    end)

    -- Preset 2: Speed & Luck God-Roll
    local p2Btn = Instance.new("TextButton")
    p2Btn.Name = "P2Btn"
    p2Btn.Size = UDim2.new(1, 0, 0, 30)
    p2Btn.BackgroundColor3 = Color3.fromRGB(40, 110, 140)
    p2Btn.BorderSizePixel = 0
    p2Btn.Font = Enum.Font.GothamBold
    p2Btn.Text = "⚡ Speed & Luck: +6 Speed | +6 Luck (Tier 6)"
    p2Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    p2Btn.TextSize = 11
    p2Btn.Parent = contentFrame

    local p2Corner = Instance.new("UICorner")
    p2Corner.CornerRadius = UDim.new(0, 6)
    p2Corner.Parent = p2Btn

    p2Btn.MouseButton1Click:Connect(function()
        local ok, msg = GearCopier.applyGodRoll(GearCopier.targetGear, 6, "Epic", { Speed = 6, Luck = 6 })
        notifyUser(msg, not ok)
    end)

    -- Preset 3: Tank & HP God-Roll
    local p3Btn = Instance.new("TextButton")
    p3Btn.Name = "P3Btn"
    p3Btn.Size = UDim2.new(1, 0, 0, 30)
    p3Btn.BackgroundColor3 = Color3.fromRGB(90, 40, 130)
    p3Btn.BorderSizePixel = 0
    p3Btn.Font = Enum.Font.GothamBold
    p3Btn.Text = "🛡️ Tank: +6 Endurance | +6 Strength (Tier 6)"
    p3Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    p3Btn.TextSize = 11
    p3Btn.Parent = contentFrame

    local p3Corner = Instance.new("UICorner")
    p3Corner.CornerRadius = UDim.new(0, 6)
    p3Corner.Parent = p3Btn

    p3Btn.MouseButton1Click:Connect(function()
        local ok, msg = GearCopier.applyGodRoll(GearCopier.targetGear, 6, "Epic", { Endurance = 6, Strength = 6 })
        notifyUser(msg, not ok)
    end)

    -- Section: Gear List Selector
    local listHeader = Instance.new("TextLabel")
    listHeader.Name = "ListHeader"
    listHeader.Size = UDim2.new(1, 0, 0, 18)
    listHeader.BackgroundTransparency = 1
    listHeader.Font = Enum.Font.GothamBold
    listHeader.Text = "🎒 DANH SÁCH TRANG BỊ TRONG KHO (CLICK ĐỂ CHỌN):"
    listHeader.TextColor3 = Color3.fromRGB(220, 220, 230)
    listHeader.TextSize = 12
    listHeader.TextXAlignment = Enum.TextXAlignment.Left
    listHeader.Parent = contentFrame

    local itemsContainer = Instance.new("Frame")
    itemsContainer.Name = "ItemsContainer"
    itemsContainer.Size = UDim2.new(1, 0, 0, 200)
    itemsContainer.BackgroundTransparency = 1
    itemsContainer.Parent = contentFrame

    local itemsLayout = Instance.new("UIListLayout")
    itemsLayout.Padding = UDim.new(0, 6)
    itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    itemsLayout.Parent = itemsContainer

    local function refreshList()
        for _, c in ipairs(itemsContainer:GetChildren()) do
            if c:IsA("Frame") or c:IsA("TextButton") then
                c:Destroy()
            end
        end

        local gears = GearCopier.scanGears()
        itemsContainer.Size = UDim2.new(1, 0, 0, #gears * 42)
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, 360 + (#gears * 42))

        if #gears == 0 then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Size = UDim2.new(1, 0, 0, 30)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.Text = "Không tìm thấy trang bị nào trong kho đồ (Hãy mở kho đồ lên trước)"
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
            emptyLabel.TextSize = 11
            emptyLabel.Parent = itemsContainer
            return
        end

        for i, g in ipairs(gears) do
            local row = Instance.new("Frame")
            row.Name = "Row_" .. i
            row.Size = UDim2.new(1, 0, 0, 36)
            row.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
            row.BorderSizePixel = 0
            row.Parent = itemsContainer

            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 6)
            rowCorner.Parent = row

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -150, 1, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.GothamMedium
            nameLabel.Text = string.format("%s (%s)", g.Name, g.StatSummary)
            nameLabel.TextColor3 = (g.Rarity == "Legendary" and Color3.fromRGB(255, 190, 80) or (g.Rarity == "Epic" and Color3.fromRGB(200, 120, 255) or Color3.fromRGB(200, 200, 210)))
            nameLabel.TextSize = 11
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = row

            -- Set as Source Button
            local setSrcBtn = Instance.new("TextButton")
            setSrcBtn.Size = UDim2.new(0, 65, 0, 24)
            setSrcBtn.Position = UDim2.new(1, -140, 0.5, -12)
            setSrcBtn.BackgroundColor3 = Color3.fromRGB(180, 130, 30)
            setSrcBtn.BorderSizePixel = 0
            setSrcBtn.Font = Enum.Font.GothamBold
            setSrcBtn.Text = "SOURCE"
            setSrcBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            setSrcBtn.TextSize = 10
            setSrcBtn.Parent = row

            local btnCorner1 = Instance.new("UICorner")
            btnCorner1.CornerRadius = UDim.new(0, 4)
            btnCorner1.Parent = setSrcBtn

            setSrcBtn.MouseButton1Click:Connect(function()
                GearCopier.sourceGear = g
                srcDisplay.Text = string.format("  📥 %s (%s)", g.Name, g.StatSummary)
                srcDisplay.TextColor3 = Color3.fromRGB(255, 220, 120)
                notifyUser("Đã chọn Source: " .. g.Name, false)
            end)

            -- Set as Target Button
            local setTgtBtn = Instance.new("TextButton")
            setTgtBtn.Size = UDim2.new(0, 65, 0, 24)
            setTgtBtn.Position = UDim2.new(1, -70, 0.5, -12)
            setTgtBtn.BackgroundColor3 = Color3.fromRGB(30, 130, 180)
            setTgtBtn.BorderSizePixel = 0
            setTgtBtn.Font = Enum.Font.GothamBold
            setTgtBtn.Text = "TARGET"
            setTgtBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            setTgtBtn.TextSize = 10
            setTgtBtn.Parent = row

            local btnCorner2 = Instance.new("UICorner")
            btnCorner2.CornerRadius = UDim.new(0, 4)
            btnCorner2.Parent = setTgtBtn

            setTgtBtn.MouseButton1Click:Connect(function()
                GearCopier.targetGear = g
                tgtDisplay.Text = string.format("  🎯 %s (%s)", g.Name, g.StatSummary)
                tgtDisplay.TextColor3 = Color3.fromRGB(120, 220, 255)
                notifyUser("Đã chọn Target: " .. g.Name, false)
            end)
        end
    end

    scanBtn.MouseButton1Click:Connect(function()
        refreshList()
        notifyUser("Đã làm mới danh sách trang bị!", false)
    end)

    -- Initial load
    refreshList()

    screenGui.Parent = parentGui
    shared.ArcaneGearCopierUI = screenGui
    print("[GearCopier] 🚀 Giao diện Gear Roll Copier đã được mở thành công!")
end

-- Initialize UI
GearCopier.createUI()
return GearCopier
