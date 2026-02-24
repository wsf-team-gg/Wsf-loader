-- w s f  l o a d e r  . g g
-- Berry Avenue RP Troll Script + Avatar Reader
-- UI: Luna Interface Suite

local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()

-- ══ Services ══
local Players          = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")
local LP               = Players.LocalPlayer

-- ══ Loop manager ══
local Loops = {}
local function startLoop(id, fn, dt)
    Loops[id] = true
    task.spawn(function()
        while Loops[id] do pcall(fn) task.wait(dt or 0.1) end
    end)
end
local function stopLoop(id) Loops[id] = false end

local function getChar()  return LP.Character end
local function getRoot()  local c=getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()   local c=getChar() return c and c:FindFirstChild("Humanoid") end
local function getMyVehicle()
    local char=getChar() if not char then return nil,nil end
    for _,v in pairs(workspace:GetDescendants()) do
        if v:IsA("VehicleSeat") and v.Occupant and v.Occupant.Parent==char then
            return v:FindFirstAncestorOfClass("Model"),v
        end
    end
    return nil,nil
end

-- ══ ID extractor from rbxassetid:// strings ══
local function extractId(str)
    if not str or str == "" then return nil end
    return str:match("%d+")
end

-- ══════════════════════════════════
--              WINDOW
-- ══════════════════════════════════
local Window = Luna:CreateWindow({
    Name = "w s f  l o a d e r  . g g",
    Subtitle = "Berry Avenue Troll",
    LogoID = nil,
    LoadingEnabled = true,
    LoadingTitle = "w s f  l o a d e r  . g g",
    LoadingSubtitle = "by wsf loader . gg",
    ConfigSettings = { RootFolder = nil, ConfigFolder = "wsf-berry" },
    KeySystem = false,
})

-- ══════════════════════════════════════════════
--           👗 AVATAR READER TAB
-- ══════════════════════════════════════════════
local AvatarTab = Window:CreateTab({
    Name = "Avatar Reader",
    Icon = "checkroom",
    ImageSource = "Material",
    ShowTitle = true,
})

AvatarTab:CreateSection("Scan Player Outfit")

local scannedPlayer = nil  -- holds the last scanned player object
local scannedDesc   = nil  -- holds the HumanoidDescription
local scannedItems  = {}   -- list of {id, name, assetType, thumbnailUrl}

-- Target input
local avatarTargetName = ""
AvatarTab:CreateInput({
    Name = "Player to Scan",
    Description = "Type a player's name then click Scan",
    PlaceholderText = "Enter player name...",
    CurrentValue = "",
    Numeric = false,
    MaxCharacters = nil,
    Enter = true,
    Callback = function(v) avatarTargetName = v end,
}, "AvatarTarget")

-- ── Core scan function ──
local function scanAvatar(targetPlayer)
    scannedItems = {}
    scannedPlayer = targetPlayer
    local char = targetPlayer.Character
    if not char then return false, "Player has no character" end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false, "No Humanoid found" end

    -- Get HumanoidDescription (contains shirt, pants, face, body colors, accessory IDs)
    local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
    if not ok or not desc then
        return false, "Could not read HumanoidDescription"
    end
    scannedDesc = desc

    -- ── Helper to add an item entry ──
    local function addItem(id, category)
        if not id or id == "" or id == "0" then return end
        local numId = tonumber(id)
        if not numId or numId == 0 then return end

        local info = {id = tostring(numId), name = "ID: "..numId, assetType = category,
                      thumbnailUrl = "rbxthumb://type=Asset&id="..numId.."&w=150&h=150"}
        -- Try to get the real name from MarketplaceService
        pcall(function()
            local prod = MarketplaceService:GetProductInfo(numId)
            if prod and prod.Name then
                info.name = prod.Name
            end
        end)
        table.insert(scannedItems, info)
    end

    -- ── Accessories from HumanoidDescription CSV fields ──
    local accFields = {
        {desc.HatAccessory,        "Hat"},
        {desc.HairAccessory,       "Hair"},
        {desc.FaceAccessory,       "Face Accessory"},
        {desc.NeckAccessory,       "Neck"},
        {desc.ShouldersAccessory,  "Shoulders"},
        {desc.BackAccessory,       "Back"},
        {desc.WaistAccessory,      "Waist"},
        {desc.FrontAccessory,      "Front"},
    }
    for _, pair in pairs(accFields) do
        local csv, typeName = pair[1], pair[2]
        if csv and csv ~= "" then
            for _, id in pairs(csv:split(",")) do
                addItem(id:match("^%s*(.-)%s*$"), typeName)
            end
        end
    end

    -- ── Shirt, Pants, T-Shirt ──
    addItem(tostring(desc.Shirt),      "Shirt")
    addItem(tostring(desc.Pants),      "Pants")
    addItem(tostring(desc.GraphicTShirt), "T-Shirt")

    -- ── Face ──
    addItem(tostring(desc.Face),       "Face")

    -- ── Also scan character directly for 3D layered clothing (AccessoryBlob workaround) ──
    -- AccessoryBlob is NotScriptable, so we scan the character's Accessory instances instead
    for _, child in pairs(char:GetDescendants()) do
        if child:IsA("Accessory") then
            -- Each Accessory has a Handle with a SpecialMesh or MeshPart
            local handle = child:FindFirstChild("Handle")
            if handle then
                -- Try SpecialMesh
                local mesh = handle:FindFirstChildOfClass("SpecialMesh")
                if mesh then
                    local meshId = extractId(mesh.MeshId)
                    -- The actual asset ID for an accessory is tracked via the handle's MeshId
                    -- but it's the ASSET id we need. We look at the Accessory's parent tags or name.
                    -- Best approach: check if the accessory name matches something we already have
                    -- If not, try to get it from the mesh texture ID
                    local texId = extractId(mesh.TextureId)
                    if texId then
                        -- Check if already captured
                        local already = false
                        for _, item in pairs(scannedItems) do
                            if item.id == texId then already = true break end
                        end
                        if not already then
                            addItem(texId, "3D Accessory ("..child.Name..")")
                        end
                    end
                end
                -- Try MeshPart (layered clothing)
                if handle:IsA("MeshPart") then
                    local texId = extractId(handle.TextureID)
                    if texId then
                        local already = false
                        for _, item in pairs(scannedItems) do
                            if item.id == texId then already = true break end
                        end
                        if not already then
                            addItem(texId, "Layered Clothing ("..child.Name..")")
                        end
                    end
                end
            end
        end
    end

    return true, "Scanned "..#scannedItems.." items from "..targetPlayer.Name
end

-- ── Build the viewer window ──
local function openAvatarViewer(targetPlayer)
    local success, msg = scanAvatar(targetPlayer)
    if not success then
        Luna:Notification({
            Title = "Avatar Reader",
            Icon = "error",
            ImageSource = "Material",
            Content = msg,
            Duration = 4,
        })
        return
    end

    -- ══ Create a popup ScreenGui ══
    local playerGui = LP.PlayerGui

    -- Remove old viewer if exists
    local old = playerGui:FindFirstChild("WSFAvatarViewer")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "WSFAvatarViewer"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    -- ── Dark backdrop ──
    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.5
    backdrop.BorderSizePixel = 0
    backdrop.Parent = gui

    -- ── Main window ──
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 700, 0, 520)
    mainFrame.Position = UDim2.new(0.5, -350, 0.5, -260)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    -- Shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageColor3 = Color3.fromRGB(0,0,0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49,49,450,450)
    shadow.ZIndex = 0
    shadow.Parent = mainFrame

    -- ── Title bar ──
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

    -- Fix bottom corners of title bar
    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0.5, 0)
    titleFix.Position = UDim2.new(0, 0, 0.5, 0)
    titleFix.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.new(0, 14, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "👗  Avatar of  " .. targetPlayer.Name
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -38, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- ── LEFT PANEL: ViewportFrame of player model ──
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 200, 1, -44)
    leftPanel.Position = UDim2.new(0, 0, 0, 44)
    leftPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = mainFrame

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1, -16, 0, 240)
    viewport.Position = UDim2.new(0, 8, 0, 10)
    viewport.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    viewport.BorderSizePixel = 0
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -2, -1)
    viewport.Ambient = Color3.fromRGB(200, 200, 200)
    viewport.Parent = leftPanel
    Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 8)

    -- Clone the target's character into the viewport
    task.spawn(function()
        local char = targetPlayer.Character
        if char then
            local clone = char:Clone()
            -- Remove scripts from clone
            for _, s in pairs(clone:GetDescendants()) do
                if s:IsA("Script") or s:IsA("LocalScript") then s:Destroy() end
            end
            -- Remove tools
            for _, t in pairs(clone:GetChildren()) do
                if t:IsA("Tool") then t:Destroy() end
            end
            clone.Parent = viewport

            -- Position camera to see the model
            local vpCamera = Instance.new("Camera")
            vpCamera.Parent = viewport
            viewport.CurrentCamera = vpCamera

            local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChild("Torso")
            if root then
                vpCamera.CFrame = CFrame.new(
                    root.Position + Vector3.new(0, 1.5, 5),
                    root.Position + Vector3.new(0, 0.5, 0)
                )
            end

            -- Slowly rotate the model
            task.spawn(function()
                local angle = 0
                while viewport and viewport.Parent do
                    angle += 0.01
                    if root and root.Parent then
                        clone:SetPrimaryPartCFrame(
                            CFrame.new(root.Position) * CFrame.Angles(0, angle, 0)
                        )
                    end
                    task.wait(0.03)
                end
            end)
        end
    end)

    -- Player name under viewport
    local vpName = Instance.new("TextLabel")
    vpName.Size = UDim2.new(1, -8, 0, 24)
    vpName.Position = UDim2.new(0, 4, 0, 256)
    vpName.BackgroundTransparency = 1
    vpName.Text = targetPlayer.Name
    vpName.TextColor3 = Color3.fromRGB(200, 200, 220)
    vpName.Font = Enum.Font.GothamBold
    vpName.TextSize = 13
    vpName.Parent = leftPanel

    -- User ID
    local vpUID = Instance.new("TextLabel")
    vpUID.Size = UDim2.new(1, -8, 0, 20)
    vpUID.Position = UDim2.new(0, 4, 0, 276)
    vpUID.BackgroundTransparency = 1
    vpUID.Text = "UserID: " .. targetPlayer.UserId
    vpUID.TextColor3 = Color3.fromRGB(140, 140, 160)
    vpUID.Font = Enum.Font.Gotham
    vpUID.TextSize = 11
    vpUID.Parent = leftPanel

    -- Item count
    local vpCount = Instance.new("TextLabel")
    vpCount.Size = UDim2.new(1, -8, 0, 20)
    vpCount.Position = UDim2.new(0, 4, 0, 296)
    vpCount.BackgroundTransparency = 1
    vpCount.Text = #scannedItems .. " items found"
    vpCount.TextColor3 = Color3.fromRGB(100, 220, 130)
    vpCount.Font = Enum.Font.Gotham
    vpCount.TextSize = 11
    vpCount.Parent = leftPanel

    -- ── LEFT PANEL BUTTONS ──
    local btnY = 326

    local function makeBtn(labelText, color, yPos, clickFn)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 32)
        btn.Position = UDim2.new(0, 8, 0, yPos)
        btn.BackgroundColor3 = color
        btn.Text = labelText
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = leftPanel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(clickFn)
        return btn
    end

    -- Copy All IDs to Clipboard
    makeBtn("📋 Copy All IDs", Color3.fromRGB(60, 120, 200), btnY, function()
        local lines = {}
        for _, item in pairs(scannedItems) do
            table.insert(lines, "[" .. item.assetType .. "] " .. item.name .. " | ID: " .. item.id)
        end
        if #lines > 0 then
            if setclipboard then
                setclipboard(table.concat(lines, "\n"))
                Luna:Notification({Title="Copied!", Icon="content_copy", ImageSource="Material",
                    Content="Copied "..#lines.." item IDs to clipboard.", Duration=3})
            end
        end
    end)

    -- Copy as Roblox Catalog Links
    makeBtn("🔗 Copy Catalog Links", Color3.fromRGB(80, 60, 180), btnY + 38, function()
        local lines = {}
        for _, item in pairs(scannedItems) do
            table.insert(lines, "https://www.roblox.com/catalog/"..item.id.." ("..item.name..")")
        end
        if setclipboard then
            setclipboard(table.concat(lines, "\n"))
            Luna:Notification({Title="Copied!", Icon="link", ImageSource="Material",
                Content="Catalog links copied!", Duration=3})
        end
    end)

    -- Try Equip Outfit (applies HumanoidDescription to YOUR character)
    makeBtn("✨ Try Equip Outfit", Color3.fromRGB(40, 160, 80), btnY + 76, function()
        local myChar = getChar()
        local myHum  = getHum()
        if not myChar or not myHum or not scannedDesc then return end
        task.spawn(function()
            local ok2, err2 = pcall(function()
                myHum:ApplyDescription(scannedDesc)
            end)
            if ok2 then
                Luna:Notification({Title="Outfit Applied!", Icon="checkroom", ImageSource="Material",
                    Content="Now wearing "..targetPlayer.Name.."'s outfit!", Duration=4})
            else
                -- Fallback: apply individual items
                local myDesc = myHum:GetAppliedDescription()
                if myDesc then
                    myDesc.HatAccessory       = scannedDesc.HatAccessory
                    myDesc.HairAccessory      = scannedDesc.HairAccessory
                    myDesc.FaceAccessory      = scannedDesc.FaceAccessory
                    myDesc.NeckAccessory      = scannedDesc.NeckAccessory
                    myDesc.BackAccessory      = scannedDesc.BackAccessory
                    myDesc.ShouldersAccessory = scannedDesc.ShouldersAccessory
                    myDesc.WaistAccessory     = scannedDesc.WaistAccessory
                    myDesc.FrontAccessory     = scannedDesc.FrontAccessory
                    myDesc.Face               = scannedDesc.Face
                    myDesc.Shirt              = scannedDesc.Shirt
                    myDesc.Pants              = scannedDesc.Pants
                    myDesc.GraphicTShirt      = scannedDesc.GraphicTShirt
                    pcall(function() myHum:ApplyDescription(myDesc) end)
                    Luna:Notification({Title="Outfit Applied!", Icon="checkroom", ImageSource="Material",
                        Content="Partial outfit applied from "..targetPlayer.Name, Duration=4})
                end
            end
        end)
    end)

    -- Rescan button
    makeBtn("🔄 Rescan", Color3.fromRGB(100, 80, 30), btnY + 114, function()
        gui:Destroy()
        openAvatarViewer(targetPlayer)
    end)

    -- ── RIGHT PANEL: Scrollable item list ──
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(1, -200, 1, -44)
    rightPanel.Position = UDim2.new(0, 200, 0, 44)
    rightPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = mainFrame

    -- Divider line
    local divLine = Instance.new("Frame")
    divLine.Size = UDim2.new(0, 1, 1, 0)
    divLine.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    divLine.BorderSizePixel = 0
    divLine.Parent = rightPanel

    local searchBar = Instance.new("TextBox")
    searchBar.Size = UDim2.new(1, -16, 0, 30)
    searchBar.Position = UDim2.new(0, 8, 0, 8)
    searchBar.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    searchBar.BorderSizePixel = 0
    searchBar.PlaceholderText = "🔍  Search items..."
    searchBar.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    searchBar.Text = ""
    searchBar.TextColor3 = Color3.fromRGB(220, 220, 240)
    searchBar.Font = Enum.Font.Gotham
    searchBar.TextSize = 13
    searchBar.ClearTextOnFocus = false
    searchBar.Parent = rightPanel
    Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 6)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -8, 1, -50)
    scroll.Position = UDim2.new(0, 4, 0, 46)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 120)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.BorderSizePixel = 0
    scroll.Parent = rightPanel

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = scroll

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 4)
    listPad.PaddingLeft = UDim.new(0, 4)
    listPad.PaddingRight = UDim.new(0, 4)
    listPad.Parent = scroll

    -- ── Build item cards ──
    local allCards = {}

    local typeColors = {
        ["Hat"]               = Color3.fromRGB(200, 100, 50),
        ["Hair"]              = Color3.fromRGB(180, 80, 180),
        ["Face"]              = Color3.fromRGB(80, 160, 220),
        ["Face Accessory"]    = Color3.fromRGB(60, 180, 200),
        ["Shirt"]             = Color3.fromRGB(60, 160, 100),
        ["Pants"]             = Color3.fromRGB(60, 100, 200),
        ["T-Shirt"]           = Color3.fromRGB(100, 180, 80),
        ["Back"]              = Color3.fromRGB(200, 150, 50),
        ["Neck"]              = Color3.fromRGB(160, 100, 200),
        ["Shoulders"]         = Color3.fromRGB(200, 80, 100),
        ["Waist"]             = Color3.fromRGB(100, 200, 160),
        ["Front"]             = Color3.fromRGB(200, 200, 60),
    }

    local function buildCards(filter)
        -- Clear existing
        for _, card in pairs(allCards) do
            card:Destroy()
        end
        allCards = {}

        for _, item in pairs(scannedItems) do
            local filterLower = filter and filter:lower() or ""
            if filterLower == "" or item.name:lower():find(filterLower) or
               item.assetType:lower():find(filterLower) or item.id:find(filterLower) then

                local card = Instance.new("Frame")
                card.Size = UDim2.new(1, 0, 0, 58)
                card.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
                card.BorderSizePixel = 0
                card.Parent = scroll
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
                table.insert(allCards, card)

                -- Type color bar
                local colorBar = Instance.new("Frame")
                colorBar.Size = UDim2.new(0, 4, 1, -8)
                colorBar.Position = UDim2.new(0, 4, 0, 4)
                colorBar.BackgroundColor3 = typeColors[item.assetType] or Color3.fromRGB(140,140,140)
                colorBar.BorderSizePixel = 0
                colorBar.Parent = card
                Instance.new("UICorner", colorBar).CornerRadius = UDim.new(0, 2)

                -- Thumbnail image
                local thumb = Instance.new("ImageLabel")
                thumb.Size = UDim2.new(0, 46, 0, 46)
                thumb.Position = UDim2.new(0, 12, 0, 6)
                thumb.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
                thumb.BorderSizePixel = 0
                thumb.Image = item.thumbnailUrl
                thumb.ScaleType = Enum.ScaleType.Fit
                thumb.Parent = card
                Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 6)

                -- Item name
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -180, 0, 22)
                nameLabel.Position = UDim2.new(0, 64, 0, 6)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = item.name
                nameLabel.TextColor3 = Color3.fromRGB(230, 230, 255)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 12
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                nameLabel.Parent = card

                -- Type badge
                local typeBadge = Instance.new("TextLabel")
                typeBadge.Size = UDim2.new(0, 0, 0, 18)
                typeBadge.AutomaticSize = Enum.AutomaticSize.X
                typeBadge.Position = UDim2.new(0, 64, 0, 30)
                typeBadge.BackgroundColor3 = typeColors[item.assetType] or Color3.fromRGB(80,80,80)
                typeBadge.BackgroundTransparency = 0.6
                typeBadge.Text = "  " .. item.assetType .. "  "
                typeBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
                typeBadge.Font = Enum.Font.Gotham
                typeBadge.TextSize = 10
                typeBadge.BorderSizePixel = 0
                typeBadge.Parent = card
                Instance.new("UICorner", typeBadge).CornerRadius = UDim.new(0, 4)

                -- ID label
                local idLabel = Instance.new("TextLabel")
                idLabel.Size = UDim2.new(1, -200, 0, 16)
                idLabel.Position = UDim2.new(0, 64, 1, -20)
                idLabel.BackgroundTransparency = 1
                idLabel.Text = "ID: " .. item.id
                idLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
                idLabel.Font = Enum.Font.Gotham
                idLabel.TextSize = 10
                idLabel.TextXAlignment = Enum.TextXAlignment.Left
                idLabel.Parent = card

                -- ── Per-item buttons ──
                -- Copy ID button
                local copyIdBtn = Instance.new("TextButton")
                copyIdBtn.Size = UDim2.new(0, 48, 0, 22)
                copyIdBtn.Position = UDim2.new(1, -122, 0.5, -11)
                copyIdBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
                copyIdBtn.Text = "Copy ID"
                copyIdBtn.TextColor3 = Color3.fromRGB(255,255,255)
                copyIdBtn.Font = Enum.Font.GothamBold
                copyIdBtn.TextSize = 9
                copyIdBtn.BorderSizePixel = 0
                copyIdBtn.Parent = card
                Instance.new("UICorner", copyIdBtn).CornerRadius = UDim.new(0, 4)
                copyIdBtn.MouseButton1Click:Connect(function()
                    if setclipboard then
                        setclipboard(item.id)
                        copyIdBtn.Text = "✓"
                        task.delay(1.5, function() copyIdBtn.Text = "Copy ID" end)
                    end
                end)

                -- Open Catalog button
                local catBtn = Instance.new("TextButton")
                catBtn.Size = UDim2.new(0, 56, 0, 22)
                catBtn.Position = UDim2.new(1, -66, 0.5, -11)
                catBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                catBtn.Text = "Catalog 🔗"
                catBtn.TextColor3 = Color3.fromRGB(255,255,255)
                catBtn.Font = Enum.Font.GothamBold
                catBtn.TextSize = 9
                catBtn.BorderSizePixel = 0
                catBtn.Parent = card
                Instance.new("UICorner", catBtn).CornerRadius = UDim.new(0, 4)
                catBtn.MouseButton1Click:Connect(function()
                    -- Copy the catalog link (can't open browser from executor)
                    if setclipboard then
                        setclipboard("https://www.roblox.com/catalog/"..item.id)
                        catBtn.Text = "Copied!"
                        task.delay(1.5, function() catBtn.Text = "Catalog 🔗" end)
                    end
                end)

                -- Equip THIS item only
                local equipBtn = Instance.new("TextButton")
                equipBtn.Size = UDim2.new(0, 0, 0, 22)
                equipBtn.AutomaticSize = Enum.AutomaticSize.X
                equipBtn.Position = UDim2.new(1, -130, 1, -26)
                equipBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
                equipBtn.Text = "  Try On  "
                equipBtn.TextColor3 = Color3.fromRGB(255,255,255)
                equipBtn.Font = Enum.Font.GothamBold
                equipBtn.TextSize = 9
                equipBtn.BorderSizePixel = 0
                equipBtn.Parent = card
                Instance.new("UICorner", equipBtn).CornerRadius = UDim.new(0, 4)
                equipBtn.MouseButton1Click:Connect(function()
                    local myHum = getHum()
                    local myDesc = myHum and myHum:GetAppliedDescription()
                    if not myDesc or not myHum then return end
                    task.spawn(function()
                        local numId = tonumber(item.id)
                        -- Try to equip based on category
                        local cat = item.assetType
                        if cat == "Shirt" then
                            myDesc.Shirt = numId
                        elseif cat == "Pants" then
                            myDesc.Pants = numId
                        elseif cat == "T-Shirt" then
                            myDesc.GraphicTShirt = numId
                        elseif cat == "Face" then
                            myDesc.Face = numId
                        elseif cat:find("Hat") or cat:find("Hair") or cat:find("Accessory") or
                               cat:find("3D") or cat:find("Layered") or cat:find("Back") or
                               cat:find("Neck") or cat:find("Shoulders") or cat:find("Waist") or
                               cat:find("Front") or cat:find("Face Accessory") then
                            -- Append to HatAccessory CSV as generic workaround
                            local existing = myDesc.HatAccessory
                            if existing and existing ~= "" then
                                myDesc.HatAccessory = existing .. "," .. item.id
                            else
                                myDesc.HatAccessory = item.id
                            end
                        end
                        pcall(function() myHum:ApplyDescription(myDesc) end)
                        equipBtn.Text = "  ✓ On!  "
                        task.delay(2, function() equipBtn.Text = "  Try On  " end)
                    end)
                end)
            end
        end
    end

    buildCards("")

    -- Search filter
    searchBar:GetPropertyChangedSignal("Text"):Connect(function()
        buildCards(searchBar.Text)
    end)

    -- Make window draggable
    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    Luna:Notification({
        Title = "Avatar Reader",
        Icon = "checkroom",
        ImageSource = "Material",
        Content = "Scanned "..#scannedItems.." items from "..targetPlayer.Name,
        Duration = 4,
    })
end

-- ── Scan button in main UI ──
AvatarTab:CreateButton({
    Name = "Scan & Open Viewer",
    Description = "Opens the full avatar viewer window",
    Callback = function()
        local target = Players:FindFirstChild(avatarTargetName)
        if not target then
            Luna:Notification({Title="Not Found", Icon="error", ImageSource="Material",
                Content="Player '"..avatarTargetName.."' not in this server.", Duration=3})
            return
        end
        openAvatarViewer(target)
    end,
})

AvatarTab:CreateDivider()
AvatarTab:CreateSection("Quick Scan Nearby")

-- List all players as quick-scan buttons
AvatarTab:CreateButton({
    Name = "Show All Players (Click to Scan)",
    Description = "Lists every player — type their name above and click Scan",
    Callback = function()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP then table.insert(names, p.Name) end
        end
        if #names == 0 then
            print("[wsf] No other players in server")
        else
            print("[wsf] Players in server: " .. table.concat(names, ", "))
        end
        Luna:Notification({Title="Players Online", Icon="people", ImageSource="Material",
            Content=table.concat(names, ", "), Duration=6})
    end,
})

-- Scan your own avatar
AvatarTab:CreateButton({
    Name = "Scan MY Avatar",
    Description = "Opens the viewer showing your own outfit",
    Callback = function()
        openAvatarViewer(LP)
    end,
})

-- ══════════════════════════════════════════════
--               🎯 FLING TAB
-- ══════════════════════════════════════════════
local FlingTab = Window:CreateTab({
    Name = "Fling",
    Icon = "whatshot",
    ImageSource = "Material",
    ShowTitle = true,
})

FlingTab:CreateSection("Target")

local targetName = ""
FlingTab:CreateInput({
    Name = "Target Name",
    Description = "Exact Roblox username",
    PlaceholderText = "Enter player name...",
    CurrentValue = "",
    Numeric = false,
    MaxCharacters = nil,
    Enter = true,
    Callback = function(v) targetName = v end,
}, "TargetInput")

local function getTarget()
    return Players:FindFirstChild(targetName)
end

local flingActive = false
FlingTab:CreateToggle({
    Name = "FE Fling Target",
    Description = "Visible to all players",
    CurrentValue = false,
    Callback = function(Value)
        flingActive = Value
        if not Value then
            local h = getHum()
            if h then h.PlatformStand = false end
            local r = getRoot()
            if r then
                local bav = r:FindFirstChild("FlingBAV")
                local bv  = r:FindFirstChild("FlingBV")
                if bav then bav:Destroy() end
                if bv  then bv:Destroy() end
            end
            return
        end
        task.spawn(function()
            while flingActive do
                local t=getTarget() local myRoot=getRoot() local myHum=getHum()
                if t and t.Character and myRoot and myHum then
                    local tRoot=t.Character:FindFirstChild("HumanoidRootPart")
                    if tRoot then
                        myHum.PlatformStand=true
                        myRoot.CFrame=tRoot.CFrame*CFrame.new(0,0,0.5)
                        local bav=Instance.new("BodyAngularVelocity")
                        bav.Name="FlingBAV" bav.AngularVelocity=Vector3.new(9999,9999,9999)
                        bav.MaxTorque=Vector3.new(9e9,9e9,9e9) bav.P=9e9 bav.Parent=myRoot
                        local bv=Instance.new("BodyVelocity")
                        bv.Name="FlingBV" bv.Velocity=Vector3.new(math.random(-200,200),math.random(150,300),math.random(-200,200))
                        bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.P=9e9 bv.Parent=myRoot
                        task.wait(0.15)
                        bav:Destroy() bv:Destroy()
                        myHum.PlatformStand=false task.wait(0.1)
                    end
                end
                task.wait(0.05)
            end
        end)
    end,
}, "FEFling")

local flingAllActive = false
FlingTab:CreateToggle({
    Name = "Fling ALL Players",
    Description = "Cycles and flings every player",
    CurrentValue = false,
    Callback = function(Value)
        flingAllActive = Value
        if Value then
            task.spawn(function()
                while flingAllActive do
                    local myRoot=getRoot() local myHum=getHum()
                    if myRoot and myHum then
                        for _,plr in pairs(Players:GetPlayers()) do
                            if plr~=LP and plr.Character then
                                local tRoot=plr.Character:FindFirstChild("HumanoidRootPart")
                                if tRoot then
                                    myHum.PlatformStand=true
                                    myRoot.CFrame=tRoot.CFrame*CFrame.new(0,0,0.5)
                                    local bav=Instance.new("BodyAngularVelocity")
                                    bav.AngularVelocity=Vector3.new(9999,9999,9999) bav.MaxTorque=Vector3.new(9e9,9e9,9e9) bav.P=9e9 bav.Parent=myRoot
                                    local bv=Instance.new("BodyVelocity")
                                    bv.Velocity=Vector3.new(math.random(-300,300),math.random(200,500),math.random(-300,300)) bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.P=9e9 bv.Parent=myRoot
                                    task.wait(0.12) bav:Destroy() bv:Destroy() myHum.PlatformStand=false task.wait(0.05)
                                end
                            end
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
}, "FlingAll")

FlingTab:CreateDivider()
FlingTab:CreateSection("Follow")

FlingTab:CreateToggle({
    Name = "Follow Target",
    Description = "Walk to target using Humanoid:MoveTo",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("Follow", function()
                local t=getTarget() local hum=getHum()
                if t and t.Character and hum then
                    local tRoot=t.Character:FindFirstChild("HumanoidRootPart")
                    if tRoot then hum:MoveTo(tRoot.Position) end
                end
            end, 0.1)
        else stopLoop("Follow") end
    end,
}, "Follow")

FlingTab:CreateToggle({
    Name = "Sit On Target Head",
    Description = "Teleport and sit on their head constantly",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("SitHead", function()
                local t=getTarget() local myRoot=getRoot()
                if t and t.Character and myRoot then
                    local head=t.Character:FindFirstChild("Head")
                    if head then myRoot.CFrame=CFrame.new(head.Position+Vector3.new(0,3.5,0)) end
                end
            end, 0.05)
        else stopLoop("SitHead") end
    end,
}, "SitHead")

-- ══════════════════════════════════════════════
--               🚗 CARS TAB
-- ══════════════════════════════════════════════
local CarTab = Window:CreateTab({
    Name = "Cars",
    Icon = "directions_car",
    ImageSource = "Material",
    ShowTitle = true,
})

CarTab:CreateSection("Your Car (Visible to All)")

CarTab:CreateButton({
    Name = "Flip Car",
    Description = "Flips your car upside-down",
    Callback = function()
        local model=getMyVehicle()
        if model and model.PrimaryPart then
            model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame*CFrame.new(0,3,0)*CFrame.Angles(math.pi,0,0))
        end
    end,
})

CarTab:CreateButton({
    Name = "Launch Car Into Sky",
    Description = "Blasts your car straight up",
    Callback = function()
        local model=getMyVehicle()
        if model then
            for _,p in pairs(model:GetDescendants()) do
                if p:IsA("BasePart") and not p.Anchored then
                    local bv=Instance.new("BodyVelocity")
                    bv.Velocity=Vector3.new(math.random(-60,60),600,math.random(-60,60))
                    bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.Parent=p Debris:AddItem(bv,0.4)
                end
            end
        end
    end,
})

CarTab:CreateToggle({
    Name = "Spin Car",
    Description = "Spins your car wildly in place",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("CarSpin", function()
                local model=getMyVehicle()
                if model and model.PrimaryPart then
                    local bav=model.PrimaryPart:FindFirstChild("CarBAV") or Instance.new("BodyAngularVelocity")
                    bav.Name="CarBAV" bav.AngularVelocity=Vector3.new(0,80,0)
                    bav.MaxTorque=Vector3.new(0,9e9,0) bav.Parent=model.PrimaryPart
                end
            end, 0.1)
        else
            stopLoop("CarSpin")
            local model=getMyVehicle()
            if model and model.PrimaryPart then
                local b=model.PrimaryPart:FindFirstChild("CarBAV") if b then b:Destroy() end
            end
        end
    end,
}, "CarSpin")

CarTab:CreateToggle({
    Name = "Rainbow Car",
    Description = "Cycles your car through rainbow colors",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local hue=0
            startLoop("RainbowCar", function()
                hue=(hue+0.01)%1
                local model=getMyVehicle()
                if model then
                    for _,p in pairs(model:GetDescendants()) do
                        if p:IsA("BasePart") then pcall(function() p.Color=Color3.fromHSV(hue,1,1) end) end
                    end
                end
            end, 0.05)
        else stopLoop("RainbowCar") end
    end,
}, "RainbowCar")

CarTab:CreateSlider({
    Name = "Car Max Speed",
    Description = "Override your seat MaxSpeed",
    Range = {0, 500}, Increment = 10, CurrentValue = 100,
    Callback = function(v)
        local _,seat=getMyVehicle()
        if seat then pcall(function() seat.MaxSpeed=v end) end
    end,
}, "CarSpeed")

CarTab:CreateDivider()
CarTab:CreateSection("Other Cars")

CarTab:CreateButton({
    Name = "Delete Nearest Car",
    Description = "Destroys the closest car to you",
    Callback = function()
        local root=getRoot() if not root then return end
        local closest,dist=nil,math.huge
        for _,v in pairs(workspace:GetDescendants()) do
            if v:IsA("VehicleSeat") then
                local m=v:FindFirstAncestorOfClass("Model")
                if m and m.PrimaryPart then
                    local d=(m.PrimaryPart.Position-root.Position).Magnitude
                    if d<dist then dist=d; closest=m end
                end
            end
        end
        if closest and dist<120 then closest:Destroy() end
    end,
})

-- ══════════════════════════════════════════════
--               🌍 GRIEF TAB
-- ══════════════════════════════════════════════
local GriefTab = Window:CreateTab({
    Name = "Grief",
    Icon = "public",
    ImageSource = "Material",
    ShowTitle = true,
})

GriefTab:CreateSection("Physical Grief (Visible to All)")

GriefTab:CreateButton({
    Name = "Brick Bomb",
    Description = "Drops 30 bricks from the sky",
    Callback = function()
        local root=getRoot() if not root then return end
        task.spawn(function()
            for i=1,30 do
                local p=Instance.new("Part")
                p.Size=Vector3.new(math.random(2,5),math.random(2,5),math.random(2,5))
                p.BrickColor=BrickColor.Random() p.Material=Enum.Material.SmoothPlastic
                p.CFrame=CFrame.new(root.Position+Vector3.new(math.random(-20,20),math.random(30,70),math.random(-20,20)))
                p.Velocity=Vector3.new(math.random(-20,20),math.random(-30,-5),math.random(-20,20))
                p.Parent=workspace Debris:AddItem(p,20) task.wait(0.05)
            end
        end)
    end,
})

GriefTab:CreateButton({
    Name = "Spawn Invisible Trap Box",
    Description = "Invisible cage around your position",
    Callback = function()
        local root=getRoot() if not root then return end
        local c=root.Position
        local walls={
            {Vector3.new(0.5,12,12),Vector3.new(6,6,0)},{Vector3.new(0.5,12,12),Vector3.new(-6,6,0)},
            {Vector3.new(12,12,0.5),Vector3.new(0,6,6)},{Vector3.new(12,12,0.5),Vector3.new(0,6,-6)},
            {Vector3.new(12,0.5,12),Vector3.new(0,12,0)},
        }
        for _,w in pairs(walls) do
            local p=Instance.new("Part")
            p.Size=w[1] p.CFrame=CFrame.new(c+w[2])
            p.Anchored=true p.Transparency=1 p.CanCollide=true p.Parent=workspace Debris:AddItem(p,30)
        end
    end,
})

local floodPart=nil
GriefTab:CreateToggle({
    Name = "Rising Flood",
    Description = "A giant water plane rises across the map",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            floodPart=Instance.new("Part")
            floodPart.Size=Vector3.new(2000,1,2000) floodPart.CFrame=CFrame.new(0,-60,0)
            floodPart.Anchored=true floodPart.CanCollide=true
            floodPart.BrickColor=BrickColor.new("Bright blue") floodPart.Material=Enum.Material.Neon
            floodPart.Transparency=0.4 floodPart.Parent=workspace
            startLoop("Flood", function()
                if floodPart and floodPart.Parent then
                    floodPart.CFrame=floodPart.CFrame+Vector3.new(0,0.4,0)
                    if floodPart.Position.Y>200 then floodPart.CFrame=CFrame.new(0,-60,0) end
                end
            end, 0.05)
        else
            stopLoop("Flood")
            if floodPart then floodPart:Destroy(); floodPart=nil end
        end
    end,
}, "Flood")

local platformPart=nil
GriefTab:CreateToggle({
    Name = "Neon Platform Follow",
    Description = "Glowing platform follows you everywhere",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            platformPart=Instance.new("Part")
            platformPart.Size=Vector3.new(20,1,20) platformPart.Anchored=true
            platformPart.BrickColor=BrickColor.new("Bright red") platformPart.Material=Enum.Material.Neon
            platformPart.Transparency=0.2 platformPart.CanCollide=true platformPart.Parent=workspace
            startLoop("Platform", function()
                local r=getRoot()
                if r and platformPart and platformPart.Parent then
                    platformPart.CFrame=CFrame.new(r.Position.X,r.Position.Y-3,r.Position.Z)
                end
            end, 0.05)
        else
            stopLoop("Platform")
            if platformPart then platformPart:Destroy(); platformPart=nil end
        end
    end,
}, "Platform")

GriefTab:CreateToggle({
    Name = "Rave Lights",
    Description = "Flickers all map lights on and off",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local on=true
            startLoop("RaveLights", function()
                on=not on
                for _,l in pairs(workspace:GetDescendants()) do
                    if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then
                        pcall(function() l.Enabled=on end)
                    end
                end
            end, 0.1)
        else
            stopLoop("RaveLights")
            for _,l in pairs(workspace:GetDescendants()) do
                if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then
                    pcall(function() l.Enabled=true end)
                end
            end
        end
    end,
}, "RaveLights")

GriefTab:CreateButton({
    Name = "Launch Neon Ball",
    Description = "Fires a huge rolling ball in your camera direction",
    Callback = function()
        local root=getRoot() if not root then return end
        local ball=Instance.new("Part")
        ball.Shape=Enum.PartType.Ball ball.Size=Vector3.new(8,8,8)
        ball.BrickColor=BrickColor.new("Bright orange") ball.Material=Enum.Material.Neon
        ball.CFrame=CFrame.new(root.Position+Vector3.new(0,4,0))
        ball.Velocity=workspace.CurrentCamera.CFrame.LookVector*250
        ball.Parent=workspace Debris:AddItem(ball,15)
    end,
})

GriefTab:CreateDivider()
GriefTab:CreateSection("Chat Spam")

local chatMsg="w s f  l o a d e r  . g g"
GriefTab:CreateInput({
    Name = "Chat Message",
    Description = "Message to spam in chat",
    PlaceholderText = "Type message...",
    CurrentValue = "", Numeric = false, MaxCharacters = nil, Enter = true,
    Callback = function(v) if v~="" then chatMsg=v end end,
}, "ChatMsg")

GriefTab:CreateToggle({
    Name = "Chat Spam",
    Description = "Spams your message in chat for all to see",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("ChatSpam", function()
                pcall(function()
                    local tcs=game:GetService("TextChatService")
                    local ch=tcs.TextChannels:FindFirstChildOfClass("TextChannel")
                    if ch then ch:SendAsync(chatMsg) end
                end)
            end, 0.6)
        else stopLoop("ChatSpam") end
    end,
}, "ChatSpam")

-- ══════════════════════════════════════════════
--             🏃 MOVEMENT TAB
-- ══════════════════════════════════════════════
local MoveTab = Window:CreateTab({
    Name = "Movement",
    Icon = "directions_run",
    ImageSource = "Material",
    ShowTitle = true,
})

MoveTab:CreateSection("Speed & Jump")

MoveTab:CreateSlider({
    Name = "Walk Speed", Description = nil,
    Range = {16, 500}, Increment = 1, CurrentValue = 16,
    Callback = function(v) local h=getHum() if h then h.WalkSpeed=v end end,
}, "WalkSpeed")

MoveTab:CreateSlider({
    Name = "Jump Power", Description = nil,
    Range = {50, 500}, Increment = 1, CurrentValue = 50,
    Callback = function(v) local h=getHum() if h then h.JumpPower=v end end,
}, "JumpPower")

MoveTab:CreateToggle({
    Name = "Infinite Jump", Description = nil, CurrentValue = false,
    Callback = function(Value)
        _G.InfJump=Value
        if Value then
            UserInputService.JumpRequest:Connect(function()
                if _G.InfJump then local h=getHum() if h then h:ChangeState("Jumping") end end
            end)
        end
    end,
}, "InfJump")

MoveTab:CreateDivider()
MoveTab:CreateSection("Fly  (WASD + Space / Shift)")

MoveTab:CreateToggle({
    Name = "Fly", Description = nil, CurrentValue = false,
    Callback = function(Value)
        local root=getRoot() local hum=getHum()
        if not root or not hum then return end
        _G.Flying=Value
        if Value then
            hum.PlatformStand=true
            local bv=Instance.new("BodyVelocity")
            bv.Name="FlyBV" bv.Velocity=Vector3.zero bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.Parent=root
            local bg=Instance.new("BodyGyro")
            bg.Name="FlyBG" bg.MaxTorque=Vector3.new(9e9,9e9,9e9) bg.P=1e4 bg.CFrame=root.CFrame bg.Parent=root
            task.spawn(function()
                while _G.Flying and root and root.Parent do
                    local spd=_G.FlySpeed or 60
                    local cam=workspace.CurrentCamera
                    local mv=Vector3.zero
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv+=cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv-=cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv-=cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv+=cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv+=Vector3.new(0,1,0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv-=Vector3.new(0,1,0) end
                    bv.Velocity=mv.Magnitude>0 and mv.Unit*spd or Vector3.zero
                    bg.CFrame=cam.CFrame task.wait()
                end
            end)
        else
            hum.PlatformStand=false
            local bv=root:FindFirstChild("FlyBV") if bv then bv:Destroy() end
            local bg=root:FindFirstChild("FlyBG") if bg then bg:Destroy() end
        end
    end,
}, "Fly")

MoveTab:CreateSlider({
    Name = "Fly Speed", Description = nil,
    Range = {10, 500}, Increment = 10, CurrentValue = 60,
    Callback = function(v) _G.FlySpeed=v end,
}, "FlySpeed")

MoveTab:CreateDivider()
MoveTab:CreateSection("Utility")

MoveTab:CreateToggle({
    Name = "Noclip", Description = "Walk through walls", CurrentValue = false,
    Callback = function(Value)
        _G.Noclip=Value
        if Value then
            RunService.Stepped:Connect(function()
                if _G.Noclip then
                    local c=getChar()
                    if c then for _,p in pairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide=false end
                    end end
                end
            end)
        end
    end,
}, "Noclip")

MoveTab:CreateToggle({
    Name = "Anti AFK", Description = nil, CurrentValue = false,
    Callback = function(Value)
        if Value then
            local VU=game:GetService("VirtualUser")
            LP.Idled:Connect(function()
                VU:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
                task.wait(1)
                VU:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
            end)
        end
    end,
}, "AntiAFK")

-- ══════════════════════════════════════════════
--                CONFIG TAB
-- ══════════════════════════════════════════════
local ConfigTab = Window:CreateTab({
    Name = "Config",
    Icon = "save",
    ImageSource = "Material",
    ShowTitle = true,
})
ConfigTab:BuildConfigSection()

Luna:Notification({
    Title = "w s f  l o a d e r  . g g",
    Icon = "check_circle",
    ImageSource = "Material",
    Content = "Loaded! Go to Avatar Reader to scan any player's outfit.",
    Duration = 5,
})
