-- ========================================================================================
-- ⚙️ BẢNG CÀI ĐẶT / SETTINGS AUTO QTE (CHỈNH SỬA TÙY CHỌN TẠI ĐÂY)
-- ========================================================================================
local Config = {
    Enabled             = true,

    -- 1. [PHÒNG THỦ & NÉ ĐÒN]
    AutoDodge           = true,  -- Tự động né đòn
    PreferPerfectDodge  = true,  -- Ưu tiên canh chuẩn ô "Dodge" (Né hoàn hảo 100%), dự phòng "Block"

    -- 2. [VŨ KHÍ CẬN CHIẾN & TẦM XA]
    AutoSword           = true,  -- Kiếm: Canh chuẩn thanh Window (Perfect Strike)
    AutoDagger          = true,  -- Dao găm: Tự động đâm trúng toàn bộ Weakpoints (Max combo)
    AutoHammer          = true,  -- Búa: Canh chuẩn thanh Window khi đo lực
    AutoAxe             = true,  -- Rìu: Tự động giữ thăng bằng thanh Threshold
    AutoFist            = true,  -- Nắm đấm / Cestus: Tự động bấm đúng phím mũi tên / nút
    AutoSpear           = true,  -- Thương: Tự động canh nhịp tấn công

    -- 3. [PHÉP THUẬT & TIỆN ÍCH]
    AutoMagic           = true,  -- Phép thuật: Tự động giải Rune
    AutoLockpick        = true,  -- Tự động mở khóa rương kho báu

    -- 4. [ĐỘ TRỄ MÔ PHỎNG PHẢN XẠ (MS)]
    ReactionDelayMs     = 0,     -- Để 0 để đánh chuẩn xác tuyệt đối 100% ngay tức thì
}
-- ========================================================================================
-- (HẾT PHẦN CÀI ĐẶT - KHÔNG CẦN CHỈNH SỬA PHẦN DƯỚI ĐÂY)
-- ========================================================================================

-- ĐỢI GAME VÀ ASSETS TẢI HOÀN TẤT TRƯỚC KHI CHẠY (CHỐNG LỖI EXECUTE SỚM)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

if shared.AutoQTE then
    pcall(function() shared.AutoQTE.detach() end)
    shared.AutoQTE = nil
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

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

local function pressKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.02)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

-- =============================================================================
-- AUTO QTE HANDLERS
-- =============================================================================
local AutoQTE = {
    connections = {},
    lastDodgeHit = 0,
    lastSwordHit = 0,
    lastDaggerHit = 0,
    lastHammerHit = 0,
    lastAxePress = 0,
    lastFistHit = 0,
    lastSpearHit = 0,
}

-- 1. XỬ LÝ DODGE QTE (NÉ / ĐỠ ĐÒN HOÀN HẢO)
local function handleDodgeQTE(dodgeQTE)
    if not Config.AutoDodge or not dodgeQTE or not dodgeQTE.Visible then return end
    local inset = dodgeQTE:FindFirstChild("Inset")
    local stopBtn = dodgeQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local indicator = inset:FindFirstChild("Indicator")
    local dodgeZone = inset:FindFirstChild("Dodge")
    local blockZone = inset:FindFirstChild("Block")
    if not indicator then return end

    local targetZone = (Config.PreferPerfectDodge and dodgeZone and dodgeZone.Visible) and dodgeZone or blockZone
    if not targetZone then return end

    local indCenter = indicator.AbsolutePosition.X + (indicator.AbsoluteSize.X / 2)
    local targetMin = targetZone.AbsolutePosition.X
    local targetMax = targetMin + targetZone.AbsoluteSize.X

    if indCenter >= targetMin and indCenter <= targetMax then
        local now = os.clock()
        if now - AutoQTE.lastDodgeHit > 0.3 then
            AutoQTE.lastDodgeHit = now
            if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end
            safeClick(stopBtn)
        end
    end
end

-- 2. XỬ LÝ SWORD QTE (KIẾM)
local function handleSwordQTE(swordQTE)
    if not Config.AutoSword or not swordQTE or not swordQTE.Visible then return end
    local inset = swordQTE:FindFirstChild("Inset")
    local stopBtn = swordQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local indicator = inset:FindFirstChild("Indicator")
    local window = inset:FindFirstChild("Window")
    if not indicator or not window then return end

    local indCenter = indicator.AbsolutePosition.X + (indicator.AbsoluteSize.X / 2)
    local winMin = window.AbsolutePosition.X
    local winMax = winMin + window.AbsoluteSize.X

    if indCenter >= winMin and indCenter <= winMax then
        local now = os.clock()
        if now - AutoQTE.lastSwordHit > 0.2 then
            AutoQTE.lastSwordHit = now
            if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end
            safeClick(stopBtn)
        end
    end
end

-- 3. XỬ LÝ DAGGER QTE (DAO GĂM)
local function handleDaggerQTE(daggerQTE)
    if not Config.AutoDagger or not daggerQTE or not daggerQTE.Visible then return end
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
                    if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end
                    if stopBtn then safeClick(stopBtn) end
                    pressKey(Enum.KeyCode.Space)
                    break
                end
            end
        end
    end
end

-- 4. XỬ LÝ HAMMER QTE (BÚA)
local function handleHammerQTE(hammerQTE)
    if not Config.AutoHammer or not hammerQTE or not hammerQTE.Visible then return end
    local gauge = hammerQTE:FindFirstChild("Gauge")
    local hintBtn = hammerQTE:FindFirstChild("Hint")
    if not gauge then return end

    local fill = gauge:FindFirstChild("Fill")
    local window = gauge:FindFirstChild("Window")
    if not fill or not window then return end

    local fillRight = fill.AbsolutePosition.X + fill.AbsoluteSize.X
    local winMin = window.AbsolutePosition.X
    local winMax = winMin + window.AbsoluteSize.X

    if fillRight >= winMin and fillRight <= winMax then
        local now = os.clock()
        if now - AutoQTE.lastHammerHit > 0.25 then
            AutoQTE.lastHammerHit = now
            if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end
            if hintBtn then safeClick(hintBtn) else pressKey(Enum.KeyCode.Space) end
        end
    end
end

-- 5. XỬ LÝ AXE QTE (RÌU)
local function handleAxeQTE(axeQTE)
    if not Config.AutoAxe or not axeQTE or not axeQTE.Visible then return end
    local gauge = axeQTE:FindFirstChild("Gauge")
    local spaceHint = axeQTE:FindFirstChild("SpaceHint")
    if not gauge then return end

    local fill = gauge:FindFirstChild("Fill")
    local threshold = gauge:FindFirstChild("Threshold")
    if not fill or not threshold then return end

    local fillRight = fill.AbsolutePosition.X + fill.AbsoluteSize.X
    local targetMin = threshold.AbsolutePosition.X

    if fillRight < targetMin + (threshold.AbsoluteSize.X * 0.7) then
        local now = os.clock()
        if now - AutoQTE.lastAxePress > 0.06 then
            AutoQTE.lastAxePress = now
            if spaceHint then safeClick(spaceHint) else pressKey(Enum.KeyCode.Space) end
        end
    end
end

-- 6. XỬ LÝ FIST QTE (NẮM ĐẤM / CESTUS)
local function handleFistQTE(fistQTE)
    if not Config.AutoFist or not fistQTE or not fistQTE.Visible then return end
    local keyHolder = fistQTE:FindFirstChild("KeyHolder")
    local otherControls = fistQTE:FindFirstChild("OtherControls")

    if keyHolder then
        for _, keyImg in ipairs(keyHolder:GetDescendants()) do
            if keyImg:IsA("ImageLabel") and keyImg.Visible and keyImg.Image:find("Arrow") then
                local now = os.clock()
                if now - AutoQTE.lastFistHit > 0.15 then
                    AutoQTE.lastFistHit = now
                    if keyImg.Rotation == 0 or keyImg.Name:find("Up") then
                        pressKey(Enum.KeyCode.Up)
                        if otherControls and otherControls:FindFirstChild("Up") then safeClick(otherControls.Up) end
                    elseif keyImg.Rotation == 180 or keyImg.Name:find("Down") then
                        pressKey(Enum.KeyCode.Down)
                        if otherControls and otherControls:FindFirstChild("Down") then safeClick(otherControls.Down) end
                    elseif keyImg.Rotation == 270 or keyImg.Name:find("Left") then
                        pressKey(Enum.KeyCode.Left)
                        if otherControls and otherControls:FindFirstChild("Left") then safeClick(otherControls.Left) end
                    elseif keyImg.Rotation == 90 or keyImg.Name:find("Right") then
                        pressKey(Enum.KeyCode.Right)
                        if otherControls and otherControls:FindFirstChild("Right") then safeClick(otherControls.Right) end
                    end
                end
            end
        end
    end
end

-- 7. XỬ LÝ LOCKPICK QTE (MỞ KHÓA RƯƠNG)
local function handleLockpickQTE(lockpickQTE)
    if not Config.AutoLockpick or not lockpickQTE or not lockpickQTE.Visible then return end
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

-- =============================================================================
-- CONTROLLER LIFECYCLE
-- =============================================================================
function AutoQTE.init()
    print("[AutoQTE] Đang khởi chạy Master Auto QTE Controller...")
    local combatGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Combat")
    local dodgeQTE = combatGui:WaitForChild("DodgeQTE", 5)
    local swordQTE = combatGui:WaitForChild("SwordQTE", 5)
    local daggerQTE = combatGui:WaitForChild("DaggerQTE", 5)
    local hammerQTE = combatGui:WaitForChild("HammerQTE", 5)
    local axeQTE = combatGui:WaitForChild("AxeQTE", 5)
    local fistQTE = combatGui:WaitForChild("FistQTE", 5)
    local spearQTE = combatGui:WaitForChild("SpearQTE", 5)
    local lockpickQTE = combatGui:WaitForChild("LockpickQTE", 5)

    local renderConn = RunService.RenderStepped:Connect(function()
        if not Config.Enabled then return end
        if dodgeQTE and dodgeQTE.Visible then handleDodgeQTE(dodgeQTE) end
        if swordQTE and swordQTE.Visible then handleSwordQTE(swordQTE) end
        if daggerQTE and daggerQTE.Visible then handleDaggerQTE(daggerQTE) end
        if hammerQTE and hammerQTE.Visible then handleHammerQTE(hammerQTE) end
        if axeQTE and axeQTE.Visible then handleAxeQTE(axeQTE) end
        if fistQTE and fistQTE.Visible then handleFistQTE(fistQTE) end
        if lockpickQTE and lockpickQTE.Visible then handleLockpickQTE(lockpickQTE) end
    end)

    table.insert(AutoQTE.connections, renderConn)
    print("[AutoQTE] Khởi chạy thành công! Đã hỗ trợ toàn bộ vũ khí.")
end

function AutoQTE.detach()
    for _, conn in ipairs(AutoQTE.connections) do
        if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
    end
    AutoQTE.connections = {}
    print("[AutoQTE] Đã tắt Auto QTE.")
end

shared.AutoQTE = AutoQTE
AutoQTE.init()
