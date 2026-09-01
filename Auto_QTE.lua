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
    lastMagicHit = 0,
    isMagicSolving = false,
    lastFistHit = 0,
    lastSpearHit = 0,
    swordHitIndices = {},
    hitWeakpoints = {},
    spearSolvedTable = {},
}

-- 1. XỬ LÝ DODGE QTE (NÉ TRÁNH HOÀN HẢO)
local function handleDodgeQTE(dodgeQTE)
    if not Config.AutoDodge or not dodgeQTE or not dodgeQTE.Visible then return end
    local inset = dodgeQTE:FindFirstChild("Inset")
    local stopBtn = dodgeQTE:FindFirstChild("Stop")
    if not inset or not stopBtn then return end

    local indicator = inset:FindFirstChild("Indicator")
    local dodgeZone = inset:FindFirstChild("Dodge")
    local blockZone = inset:FindFirstChild("Block")
    if not indicator or not indicator.Visible then return end

    local targetZone = (Config.PreferPerfectDodge and dodgeZone and dodgeZone.Visible) and dodgeZone or blockZone
    if not targetZone then return end

    local indLeft = indicator.AbsolutePosition.X
    local indRight = indLeft + indicator.AbsoluteSize.X
    local indCenter = indLeft + (indicator.AbsoluteSize.X / 2)
    local targetLeft = targetZone.AbsolutePosition.X
    local targetRight = targetLeft + targetZone.AbsoluteSize.X

    -- Collision occurs if indicator overlaps target zone
    if (indRight >= targetLeft and indLeft <= targetRight) or (indCenter >= targetLeft and indCenter <= targetRight) then
        local now = os.clock()
        if now - AutoQTE.lastDodgeHit > 0.25 then
            AutoQTE.lastDodgeHit = now
            if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end
            safeClick(stopBtn)
            pressKey(Enum.KeyCode.Space)
        end
    end
end

-- 2. XỬ LÝ SWORD QTE (KIẾM - SINGLE-CLICK, 0.25S DEBOUNCED SWEET SPOT ENGINE)
local function handleSwordQTE(swordQTE)
    if not Config.AutoSword or not swordQTE or not swordQTE.Visible then
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
        if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end
        singleClick(stopBtn)
    end
end

local DaggerArcSizes = { 20, 25, 30, 35, 40, 45, 55, 65, 75, 85, 95, 105 }

-- 3. XỬ LÝ DAGGER QTE (DAO GĂM - DYNAMIC ARC-SIZE WEAKPOINT PRECISION TRACKING)
local function handleDaggerQTE(daggerQTE)
    if not Config.AutoDagger or not daggerQTE or not daggerQTE.Visible then
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
                if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end
                if stopBtn then safeClick(stopBtn) else pressKey(Enum.KeyCode.Space) end
                break
            end
        end
    end
end

-- 4. XỬ LÝ HAMMER QTE (BÚA)
-- 4. HAMMER QTE (HOLD/RELEASE SPACE PID CONTROLLER)
local function handleHammerQTE(hammerQTE)
    if not Config.AutoHammer or not hammerQTE or not hammerQTE.Visible then
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
    if not Config.AutoAxe or not axeQTE or not axeQTE.Visible then return end
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

-- 6. XỬ LÝ STAFF / MAGIC QTE (CONTINUOUS BATCH NATIVE CLOSURE SOLVER WITH DUPLICATE TRACKING)
local function handleMagicQTE(magicQTE)
    if not Config.AutoMagic or not magicQTE or not magicQTE.Visible then
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
    local delayMs = Config.ReactionDelayMs or 0

    for _, rune in ipairs(bagRunes) do
        if rune:IsA("GuiObject") and rune.Visible and rune.Name ~= "Slotted" and rune.ImageTransparency < 0.9 and not AutoQTE.magicSlottedTable[rune] then
            local runeName = rune.Name

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

                    rune.Name = "Slotted"
                    rune.ImageTransparency = 1
                    rune.Visible = false
                    matchingSlot.Name = "Slotted"
                    matchingSlot.ImageColor3 = Color3.new(1, 1, 1)

                    if magicQTE:FindFirstChild("RuneSlotIn") then
                        pcall(function() magicQTE.RuneSlotIn:Play() end)
                    end

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
    if not Config.AutoFist or not fistQTE or not fistQTE.Visible then return end
    local keyHolder = fistQTE:FindFirstChild("KeyHolder") or fistQTE:FindFirstChild("Inset")
    local otherControls = fistQTE:FindFirstChild("OtherControls")
    local keysFolder = (keyHolder and keyHolder:FindFirstChild("Keys")) or keyHolder
    if not keysFolder then return end

    -- Tìm đúng Arrow hiện tại có số thứ tự nhỏ nhất (1_arrow, 2_arrow, ...)
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
        if Config.ReactionDelayMs > 0 then task.wait(Config.ReactionDelayMs / 1000) end

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
    if not Config.AutoSpear or not spearQTE or not spearQTE.Visible then
        AutoQTE.spearSolvedTable = {}
        return
    end

    local container = spearQTE:FindFirstChild("Container")
    if not container then return end

    local getconns = getconnections
    local getuvs = getupvalues or (debug and debug.getupvalues)
    local delayMs = Config.ReactionDelayMs or 0

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
            pressKey(Enum.KeyCode.Space)
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
    local magicQTE = combatGui:WaitForChild("MagicQTE", 5)
    local mochiiMagicQTE = combatGui:WaitForChild("MochiiMagicQTE", 5)
    local fistQTE = combatGui:WaitForChild("FistQTE", 5)
    local spearQTE = combatGui:WaitForChild("SpearQTE", 5)
    local lockpickQTE = combatGui:WaitForChild("LockpickQTE", 5)
    local yarthulQTE = combatGui:WaitForChild("YarthulQTE", 5)

    local renderConn = RunService.RenderStepped:Connect(function()
        if not Config.Enabled then return end
        if dodgeQTE and dodgeQTE.Visible then handleDodgeQTE(dodgeQTE) end
        if swordQTE and swordQTE.Visible then handleSwordQTE(swordQTE) end
        if daggerQTE and daggerQTE.Visible then handleDaggerQTE(daggerQTE) end
        if hammerQTE and hammerQTE.Visible then handleHammerQTE(hammerQTE) end
        if axeQTE and axeQTE.Visible then handleAxeQTE(axeQTE) end
        if magicQTE and magicQTE.Visible then handleMagicQTE(magicQTE) elseif mochiiMagicQTE and mochiiMagicQTE.Visible then handleMagicQTE(mochiiMagicQTE) else AutoQTE.isMagicSolving = false end
        if fistQTE and fistQTE.Visible then handleFistQTE(fistQTE) end
        if spearQTE and spearQTE.Visible then handleSpearQTE(spearQTE) end
        if lockpickQTE and lockpickQTE.Visible then handleLockpickQTE(lockpickQTE) end
        if yarthulQTE and yarthulQTE.Visible then handleYarthulQTE(yarthulQTE) end
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
