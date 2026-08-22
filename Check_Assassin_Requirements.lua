-- =============================================================================
-- ARCANE LINEAGE — ASSASSIN CLASS & CHAOTIC ALIGNMENT AUDITOR
-- =============================================================================
-- Description: Run this script on ANY client (e.g. nauttyclone2) to instantly audit:
-- 1. Level & Potential Man Trial Multiplier
-- 2. Chaotic Alignment & Reputation Status
-- 3. Base Class (Thief) completion
-- 4. Gold & Requirements Checklist
-- =============================================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

local Remotes = RS:WaitForChild("Remotes", 5)

-- 1. Query Player Data
local charName = "Unknown"
local playerLevel = 1
local playerGold = 0
local playerRace = LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Race") or "Unknown"

-- Read from HUD
local hud = PlayerGui:FindFirstChild("HUD")
if hud then
    local lvlObj = hud:FindFirstChild("Level", true)
    if lvlObj and lvlObj:IsA("TextLabel") then
        local num = lvlObj.Text:match("%d+")
        if num then playerLevel = tonumber(num) end
    end
    
    local nameObj = hud:FindFirstChild("PlrName", true)
    if nameObj and nameObj:IsA("TextLabel") and nameObj.Text ~= "" then
        charName = nameObj.Text
    end

    local goldObj = hud:FindFirstChild("Amount", true)
    if goldObj and goldObj:IsA("TextLabel") then
        local gNum = goldObj.Text:match("%d+")
        if gNum then playerGold = tonumber(gNum) end
    end
end

-- 2. Query Trials Data (Check Potential Man)
local isPotentialManActive = false
local activeTrialsList = {}
if Remotes and Remotes:FindFirstChild("Data") and Remotes.Data:FindFirstChild("GetTrialData") then
    local s, trialData = pcall(function()
        return Remotes.Data.GetTrialData:InvokeServer()
    end)
    if s and type(trialData) == "table" and trialData.ActiveTrials then
        for _, t in ipairs(trialData.ActiveTrials) do
            table.insert(activeTrialsList, tostring(t))
            if tostring(t):lower():find("potential") then
                isPotentialManActive = true
            end
        end
    end
end

-- 3. Check Base Class (Thief)
local hasThief = false
local skillsCount = 0
local skillGui = PlayerGui:FindFirstChild("SkillDisplay") or PlayerGui:FindFirstChild("ClassMastery")
if skillGui then
    for _, desc in ipairs(skillGui:GetDescendants()) do
        if desc:IsA("TextLabel") and (desc.Text:lower():find("thief") or desc.Text:lower():find("surprise package") or desc.Text:lower():find("shadow") or desc.Text:lower():find("dagger")) then
            hasThief = true
            skillsCount = skillsCount + 1
        end
    end
end

-- 4. Calculate Assassin Requirements
local reqLevel = isPotentialManActive and 30 or 15
local reqAlignmentPoints = isPotentialManActive and 20 or 10
local levelPass = playerLevel >= reqLevel
local goldPass = playerGold >= 400

-- 5. Print to Console
print("\n" .. string.rep("=", 60))
print("       ARCANE LINEAGE — ASSASSIN REQUIREMENT REPORT")
print(string.rep("=", 60))
print(string.format("Player Account : %s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name))
print(string.format("Character Name : %s | Race: %s", charName, playerRace))
print(string.format("Current Level  : Level %d", playerLevel))
print(string.format("Current Gold   : %d Gold", playerGold))
print(string.format("Trial Active   : %s", isPotentialManActive and "⚠️ POTENTIAL MAN (x2 REQS ACTIVE!)" or "None"))
print(string.rep("-", 60))
print("REQUIREMENTS AUDIT:")
print(string.format("1. Level Check        : [%s] (Current: Lv %d / Required: Lv %d)", levelPass and "PASS" or "FAIL", playerLevel, reqLevel))
print(string.format("2. Base Class (Thief) : [%s] (Must learn all 4 skills from Boots)", hasThief and "PASS" or "NEED VERIFY"))
print(string.format("3. Alignment (Chaotic): [NEED ~%d CHAOTIC POINTS] -> Uống %d bình Heartbreaking Elixir", reqAlignmentPoints, math.ceil(reqAlignmentPoints / 2)))
print(string.format("4. Gold Check (400g+) : [%s] (Current: %d Gold / Skill Cost: 400g)", goldPass and "PASS" or "FAIL", playerGold))
print(string.rep("=", 60) .. "\n")

-- 6. Render Floating Diagnostic GUI on Screen
pcall(function()
    local oldGui = PlayerGui:FindFirstChild("AssassinAuditorGui")
    if oldGui then oldGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AssassinAuditorGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 420, 0, 310)
    mainFrame.Position = UDim2.new(0.5, -210, 0.25, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = isPotentialManActive and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(150, 0, 255)
    stroke.Thickness = 2
    stroke.Parent = mainFrame

    -- Header
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 35)
    title.Position = UDim2.new(0, 15, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🗡️ ASSASSIN REQUIREMENT AUDITOR"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -32, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 14
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)
    closeBtn.Parent = mainFrame

    -- Content Box
    local contentText = Instance.new("TextLabel")
    contentText.Size = UDim2.new(1, -30, 0, 210)
    contentText.Position = UDim2.new(0, 15, 0, 45)
    contentText.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    contentText.TextColor3 = Color3.fromRGB(220, 220, 220)
    contentText.Font = Enum.Font.Code
    contentText.TextSize = 12
    contentText.TextXAlignment = Enum.TextXAlignment.Left
    contentText.TextYAlignment = Enum.TextYAlignment.Top
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = contentText

    local pCornerPad = Instance.new("UIPadding")
    pCornerPad.PaddingTop = UDim.new(0, 10)
    pCornerPad.PaddingLeft = UDim.new(0, 10)
    pCornerPad.PaddingRight = UDim.new(0, 10)
    pCornerPad.PaddingBottom = UDim.new(0, 10)
    pCornerPad.Parent = contentText

    local report = string.format(
        "• Nhân vật : %s (@%s)\n" ..
        "• Trial     : %s\n" ..
        "--------------------------------------\n" ..
        "1. Cấp độ  : %s (Lv %d / Cần Lv %d)\n" ..
        "2. Vàng    : %s (%d Gold / Cần 400g)\n" ..
        "3. Tiền đề : Base Class Thief (NPC Boots)\n" ..
        "4. Alignment: Cần ~%d điểm Chaotic\n" ..
        "   👉 Uống ngay %d lọ Heartbreaking Elixir\n" ..
        "--------------------------------------\n" ..
        "📍 Vị trí Trainer Inette: (6698.9, 568.2, -3461.3)\n" ..
        "   (Trong hang lối vào rừng Deeproot Canopy)",
        charName, LocalPlayer.Name,
        isPotentialManActive and "POTENTIAL MAN (x2 REQ!)" or "Bình thường",
        levelPass and "✅ ĐẠT" or "❌ THIẾU", playerLevel, reqLevel,
        goldPass and "✅ ĐẠT" or "❌ THIẾU", playerGold,
        reqAlignmentPoints,
        math.ceil(reqAlignmentPoints / 2)
    )
    contentText.Text = report
    contentText.Parent = mainFrame

    -- Teleport button to Inette
    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(1, -30, 0, 32)
    tpBtn.Position = UDim2.new(0, 15, 1, -42)
    tpBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 200)
    tpBtn.Text = "🚀 Bay Đến Hang NPC Inette (Assassin Trainer)"
    tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpBtn.Font = Enum.Font.SourceSansBold
    tpBtn.TextSize = 13
    local tpCorner = Instance.new("UICorner")
    tpCorner.CornerRadius = UDim.new(0, 6)
    tpCorner.Parent = tpBtn
    tpBtn.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(6688.8, 568.1, -3499.0)
            print("[Auditor] Đã dịch chuyển đến trước mặt NPC Inette!")
        end
    end)
    tpBtn.Parent = mainFrame

    screenGui.Parent = PlayerGui
end)
