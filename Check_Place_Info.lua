-- =============================================================================
-- 🔍 ARCANE LINEAGE - PLACE ID & INSTANCE INSPECTOR SCRIPT
-- =============================================================================
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local placeId = game.PlaceId
local gameId = game.GameId
local jobId = game.JobId

local placeName = "Unknown"
pcall(function()
    local info = MarketplaceService:GetProductInfo(placeId)
    if info and info.Name then placeName = info.Name end
end)

local char = LocalPlayer.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local pos = root and root.Position or Vector3.zero
local inCombat = (PlayerGui:FindFirstChild("Combat") ~= nil)

local summaryText = string.format([[
=====================================================
🔍 ARCANE LINEAGE - PLACE & INSTANCE INFO
=====================================================
• Place ID: %s
• Game ID (Universe ID): %s
• Job ID (Server GUID): %s
• Place Name: %s
• Player Position: Vector3.new(%.1f, %.1f, %.1f)
• In Combat: %s
=====================================================
]], tostring(placeId), tostring(gameId), tostring(jobId), placeName, pos.X, pos.Y, pos.Z, tostring(inCombat))

print(summaryText)

-- Tạo bảng Floating GUI trên màn hình
local parentGui = (gethui and gethui()) or (game:GetService("CoreGui"):FindFirstChild("RobloxGui")) or PlayerGui
pcall(function()
    local old = parentGui:FindFirstChild("Arcane_Place_Inspector_GUI")
    if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Arcane_Place_Inspector_GUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainCard = Instance.new("Frame")
mainCard.Name = "MainCard"
mainCard.Size = UDim2.new(0, 360, 0, 260)
mainCard.Position = UDim2.new(0.5, -180, 0.3, 0)
mainCard.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainCard.BorderSizePixel = 0
mainCard.Active = true
mainCard.Draggable = true
mainCard.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainCard

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 160, 255)
stroke.Thickness = 1.8
stroke.Parent = mainCard

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 26)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "🔍 PLACE & INSTANCE INSPECTOR"
title.TextColor3 = Color3.fromRGB(100, 200, 255)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainCard

local contentLabel = Instance.new("TextLabel")
contentLabel.Name = "Content"
contentLabel.Size = UDim2.new(1, -20, 0, 135)
contentLabel.Position = UDim2.new(0, 10, 0, 40)
contentLabel.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
contentLabel.Font = Enum.Font.Code
contentLabel.Text = string.format("Place ID: %s\nUniverse ID: %s\nPlace Name:\n%s\nJob ID: %s\nPos: (%.0f, %.0f, %.0f) | Combat: %s", tostring(placeId), tostring(gameId), placeName, tostring(jobId):sub(1, 18) .. "...", pos.X, pos.Y, pos.Z, tostring(inCombat))
contentLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
contentLabel.TextSize = 12
contentLabel.TextXAlignment = Enum.TextXAlignment.Left
contentLabel.TextYAlignment = Enum.TextYAlignment.Top
contentLabel.Parent = mainCard

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 6)
contentCorner.Parent = contentLabel

-- Nút Copy ID
local copyBtn = Instance.new("TextButton")
copyBtn.Name = "CopyBtn"
copyBtn.Size = UDim2.new(0.48, 0, 0, 32)
copyBtn.Position = UDim2.new(0, 10, 0, 185)
copyBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.Text = "📋 Copy Place ID"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.TextSize = 12
copyBtn.Parent = mainCard

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 6)
copyCorner.Parent = copyBtn

copyBtn.MouseButton1Click:Connect(function()
    local textToCopy = string.format("Place ID: %s | Universe ID: %s | Name: %s", tostring(placeId), tostring(gameId), placeName)
    if setclipboard then
        setclipboard(textToCopy)
        copyBtn.Text = "✅ Đã Copy!"
        task.wait(1.5)
        copyBtn.Text = "📋 Copy Place ID"
    end
end)

-- Nút Copy Full JSON
local copyJsonBtn = Instance.new("TextButton")
copyJsonBtn.Name = "CopyJsonBtn"
copyJsonBtn.Size = UDim2.new(0.48, 0, 0, 32)
copyJsonBtn.Position = UDim2.new(0.52, -10, 0, 185)
copyJsonBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 90)
copyJsonBtn.Font = Enum.Font.GothamBold
copyJsonBtn.Text = "📋 Copy JSON Data"
copyJsonBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyJsonBtn.TextSize = 12
copyJsonBtn.Parent = mainCard

local jsonCorner = Instance.new("UICorner")
jsonCorner.CornerRadius = UDim.new(0, 6)
jsonCorner.Parent = copyJsonBtn

copyJsonBtn.MouseButton1Click:Connect(function()
    local jsonPayload = HttpService:JSONEncode({
        placeId = placeId,
        universeId = gameId,
        jobId = jobId,
        placeName = placeName,
        position = { X = pos.X, Y = pos.Y, Z = pos.Z },
        inCombat = inCombat,
    })
    if setclipboard then
        setclipboard(jsonPayload)
        copyJsonBtn.Text = "✅ Đã Copy JSON!"
        task.wait(1.5)
        copyJsonBtn.Text = "📋 Copy JSON Data"
    end
end)

-- Nút Đóng
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(1, -20, 0, 26)
closeBtn.Position = UDim2.new(0, 10, 0, 224)
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.Text = "❌ Đóng bảng"
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
closeBtn.TextSize = 11
closeBtn.Parent = mainCard

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

screenGui.Parent = parentGui

-- Tự động copy vào clipboard ngay khi chạy
if setclipboard then
    local textToCopy = string.format("Place ID: %s | Universe ID: %s | Name: %s", tostring(placeId), tostring(gameId), placeName)
    setclipboard(textToCopy)
end

-- Thông báo
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "🔍 Place Inspector",
        Text = string.format("Place ID: %s\nUniverse ID: %s (Copied!)", tostring(placeId), tostring(gameId)),
        Duration = 6,
    })
end)
