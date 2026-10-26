-- FRUIT ESP HUB v1.9.2
-- Single Return Auto Collect
-- Auto Storage + Retry Storage

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Stop previous versions
for _, key in ipairs({
    "FruitHubV4Stop",
    "FruitESPHubStop",
    "FruitHub15Stop",
    "FruitHub16Stop",
    "FruitHub17Stop",
    "FruitHub18Stop",
    "FruitHub19Stop",
    "FruitHub191Stop",
    "FruitHub192Stop"
}) do
    if type(_G[key]) == "function" then
        pcall(_G[key])
    end
    _G[key] = nil
end

for _, name in ipairs({
    "FruitESPFull",
    "FruitESPV2",
    "FruitESPV3",
    "FruitESPV4",
    "FruitHub15",
    "FruitHub16",
    "FruitHub17",
    "FruitHub18",
    "FruitHub19",
    "FruitHub191",
    "FruitHub192"
}) do
    local old = playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

-- Settings
local settings = {
    ESP = true,
    Distance = true,
    RareOnly = false,
    Notifier = true,
    Nearest = true,
    FruitList = true,
    Sound = true,
    AutoCollect = false,
    AutoStorage = false
}

local rareNames = {
    "Dragon", "Kitsune", "Leopard",
    "Dough", "T-Rex", "Spirit",
    "Venom", "Control", "Gas",
    "Yeti", "Mammoth"
}

local running = true
local tracked = {}
local known = {}
local storageAttempts = {}

local collecting = false
local storageBusy = false
local lastCollect = 0
local heartbeat

local STORAGE_COOLDOWN = 10
local COLLECT_COOLDOWN = 5
local COLLECT_WAIT = 0.8

-- Helpers
local function getRoot()
    local character = player.Character
    return character and character:FindFirstChild(
        "HumanoidRootPart"
    )
end

local function isRare(name)
    name = name:lower()

    for _, rare in ipairs(rareNames) do
        if name:find(rare:lower(), 1, true) then
            return true
        end
    end

    return false
end

local function isFruit(obj)
    if not obj:IsA("Tool") then
        return false
    end

    if not obj.Name:lower():find(
        "fruit", 1, true
    ) then
        return false
    end

    if not obj:IsDescendantOf(Workspace) then
        return false
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character
            and obj:IsDescendantOf(p.Character) then
            return false
        end
    end

    return true
end

local function getPart(obj)
    local handle = obj:FindFirstChild("Handle")

    if handle and handle:IsA("BasePart") then
        return handle
    end

    return obj:FindFirstChildWhichIsA(
        "BasePart", true
    )
end

local function notify(message)
    if not settings.Notifier then return end

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "FRUIT ESP HUB v1.9.2",
            Text = message,
            Duration = 5
        })
    end)
end

local function playAlert()
    if not settings.Sound then return end

    local sound = Instance.new("Sound")
    sound.SoundId =
        "rbxasset://sounds/electronicpingshort.wav"
    sound.Volume = 0.8
    sound.Parent = playerGui
    sound:Play()

    task.delay(5, function()
        if sound.Parent then
            sound:Destroy()
        end
    end)
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "FruitHub192"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(340, 590)
main.Position = UDim2.new(
    0.5, -170, 0.5, -295
)
main.BackgroundColor3 =
    Color3.fromRGB(23, 26, 37)
main.Active = true
main.Draggable = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius =
    UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -55, 0, 42)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "FRUIT ESP HUB v1.9.2"
title.TextColor3 =
    Color3.fromRGB(100, 255, 160)
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.Parent = main

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(36, 30)
minimize.Position = UDim2.new(
    1, -43, 0, 6
)
minimize.BackgroundColor3 =
    Color3.fromRGB(45, 50, 65)
minimize.Text = "-"
minimize.TextSize = 22
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.Parent = main

Instance.new("UICorner", minimize).CornerRadius =
    UDim.new(0, 7)

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -16, 1, -48)
content.Position = UDim2.fromOffset(8, 45)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.AutomaticCanvasSize =
    Enum.AutomaticSize.Y
content.CanvasSize = UDim2.fromOffset(0, 0)
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = content

local function label(message, height)
    local obj = Instance.new("TextLabel")
    obj.Size = UDim2.new(
        1, -8, 0, height or 30
    )
    obj.BackgroundTransparency = 1
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.Font = Enum.Font.GothamSemibold
    obj.TextSize = 14
    obj.TextWrapped = true
    obj.Text = message
    obj.Parent = content
    return obj
end

local function button(name, callback, color)
    local obj = Instance.new("TextButton")
    obj.Size = UDim2.new(1, -8, 0, 36)
    obj.BackgroundColor3 =
        color or Color3.fromRGB(45, 50, 65)
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = 14
    obj.Text = name
    obj.Parent = content

    Instance.new("UICorner", obj).CornerRadius =
        UDim.new(0, 7)

    obj.MouseButton1Click:Connect(callback)
    return obj
end

local function toggle(name, key)
    local obj

    local function refresh()
        obj.Text = name .. ": " ..
            (settings[key] and "ON" or "OFF")

        obj.BackgroundColor3 = settings[key]
            and Color3.fromRGB(35, 115, 70)
            or Color3.fromRGB(45, 48, 62)
    end

    obj = button(name, function()
        settings[key] = not settings[key]
        refresh()
    end)

    refresh()
end

toggle("Fruit ESP", "ESP")
toggle("Show Distance", "Distance")
toggle("Rare Only", "RareOnly")
toggle("Fruit Notifier", "Notifier")
toggle("Nearest Fruit", "Nearest")
toggle("Fruit List", "FruitList")
toggle("Sound Alert", "Sound")

local section = label("AUTOMATION", 28)
section.TextColor3 =
    Color3.fromRGB(255, 205, 45)

toggle("Auto Collect [TP + Return]", "AutoCollect")
toggle("Auto Storage", "AutoStorage")

local countLabel = label("Fruits Found: 0")
local nearestLabel = label("Nearest: None", 45)
local statusLabel = label("Storage: Ready", 65)

local listTitle = label("FRUIT LIST", 28)
listTitle.TextColor3 =
    Color3.fromRGB(100, 255, 160)

local listText = label("No fruits detected", 145)
listText.TextYAlignment =
    Enum.TextYAlignment.Top

-- ESP
local function removeESP(obj)
    local data = tracked[obj]
    if not data then return end

    if data.highlight then
        data.highlight:Destroy()
    end

    if data.billboard then
        data.billboard:Destroy()
    end

    tracked[obj] = nil
end

local function addESP(obj, part)
    if tracked[obj] then return end

    local color = isRare(obj.Name)
        and Color3.fromRGB(255, 205, 45)
        or Color3.fromRGB(65, 255, 125)

    local highlight = Instance.new("Highlight")
    highlight.Name = "FruitESPHighlight"
    highlight.Adornee = obj
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.5
    highlight.DepthMode =
        Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = obj

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "FruitESPDistance"
    billboard.Adornee = part
    billboard.Size = UDim2.fromOffset(220, 65)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextColor3 = color
    text.TextStrokeTransparency = 0
    text.Font = Enum.Font.GothamBold
    text.TextSize = 16
    text.Parent = billboard

    tracked[obj] = {
        highlight = highlight,
        billboard = billboard,
        label = text,
        part = part
    }
end

-- Fruit scan
local function scan()
    local results = {}
    local current = {}
    local root = getRoot()

    for _, obj in ipairs(
        Workspace:GetDescendants()
    ) do
        if isFruit(obj) then
            local part = getPart(obj)

            if part then
                current[obj] = true

                if not known[obj] then
                    known[obj] = true
                    notify("Found: " .. obj.Name)

                    if isRare(obj.Name) then
                        playAlert()
                    end
                end

                if not settings.RareOnly
                    or isRare(obj.Name) then

                    local distance = root
                        and (
                            root.Position -
                            part.Position
                        ).Magnitude
                        or math.huge

                    table.insert(results, {
                        obj = obj,
                        part = part,
                        distance = distance
                    })

                    if settings.ESP then
                        addESP(obj, part)
                    end
                end
            end
        end
    end

    for obj in pairs(tracked) do
        if not current[obj]
            or not settings.ESP
            or (
                settings.RareOnly
                and not isRare(obj.Name)
            ) then
            removeESP(obj)
        end
    end

    for obj in pairs(known) do
        if not current[obj] then
            known[obj] = nil
        end
    end

    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)

    return results
end

-- Auto Collect v1.9.2
-- One return only, no position monitoring
local function tryCollect(item)
    if collecting or not settings.AutoCollect then
        return
    end

    if os.clock() - lastCollect <
        COLLECT_COOLDOWN then
        return
    end

    local character = player.Character
    local root = getRoot()

    if not character or not root
        or not item.part.Parent then
        return
    end

    collecting = true
    lastCollect = os.clock()

    local originalCFrame = character:GetPivot()

    local success, err = pcall(function()
        -- Teleport to fruit
        character:PivotTo(
            CFrame.new(
                item.part.Position +
                Vector3.new(0, 3, 0)
            )
        )

        -- Wait for pickup
        task.wait(COLLECT_WAIT)

        if not running
            or not settings.AutoCollect
            or player.Character ~= character then
            return
        end

        -- Return only once
        character:PivotTo(originalCFrame)
    end)

    if not success then
        warn("[Fruit Hub Auto Collect]", err)

        if running then
            statusLabel.Text =
                "Auto Collect: teleport error"
        end
    end

    collecting = false
end

-- Storage names
local specialNames = {
    ["t-rex"] = "T-Rex-T-Rex"
}

local function getStorageName(toolName)
    local name = toolName
        :gsub("%s*[Ff]ruit$", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    local special = specialNames[name:lower()]
    if special then return special end

    if name:find("-", 1, true) then
        return name
    end

    return name .. "-" .. name
end

local function findHeldFruit(force)
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character

    for _, container in ipairs({
        backpack, character
    }) do
        if container then
            for _, obj in ipairs(
                container:GetChildren()
            ) do
                if obj:IsA("Tool")
                    and obj.Name:lower():find(
                        "fruit", 1, true
                    ) then

                    local last =
                        storageAttempts[obj] or 0

                    if force
                        or os.clock() - last >=
                            STORAGE_COOLDOWN then
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

-- Auto Storage + Retry Storage
local function tryStorage(force)
    if not running or storageBusy then
        if storageBusy and running then
            statusLabel.Text =
                "Storage: request already running"
        end
        return
    end

    if not force and not settings.AutoStorage then
        return
    end

    local tool = findHeldFruit(force)

    if not tool then
        if force then
            statusLabel.Text =
                "Storage: no fruit found"
        end
        return
    end

    storageBusy = true
    storageAttempts[tool] = os.clock()

    local storageName = getStorageName(tool.Name)

    statusLabel.Text =
        "Storage: trying " .. storageName

    task.spawn(function()
        local remotes =
            ReplicatedStorage:FindFirstChild("Remotes")

        local comm = remotes and
            remotes:FindFirstChild("CommF_")

        if not comm or not comm:IsA(
            "RemoteFunction"
        ) then
            if running then
                statusLabel.Text =
                    "Storage: remote unavailable"
            end
            storageBusy = false
            return
        end

        local success, result = pcall(function()
            return comm:InvokeServer(
                "StoreFruit",
                storageName,
                tool
            )
        end)

        if not running then
            storageBusy = false
            return
        end

        if not success then
            statusLabel.Text =
                "Storage ERROR: " ..
                tostring(result):sub(1, 80)
        else
            local serverReply = tostring(result)

            statusLabel.Text =
                "Server: " ..
                serverReply:sub(1, 85)

            print(
                "[Fruit Hub Storage]",
                storageName,
                serverReply
            )

            task.wait(1)

            if not running then
                storageBusy = false
                return
            end

            local backpack =
                player:FindFirstChild("Backpack")

            local stillHeld =
                tool.Parent == backpack
                or tool.Parent == player.Character

            if stillHeld then
                statusLabel.Text =
                    "Storage: fruit still held | " ..
                    serverReply:sub(1, 45)
            else
                statusLabel.Text =
                    "Storage: fruit moved, check storage"
            end
        end

        storageBusy = false
    end)
end

button(
    "RETRY STORAGE",
    function()
        tryStorage(true)
    end,
    Color3.fromRGB(55, 90, 155)
)

-- Unload Script
local function unload()
    running = false
    settings.AutoCollect = false
    settings.AutoStorage = false

    if heartbeat then
        heartbeat:Disconnect()
        heartbeat = nil
    end

    for obj in pairs(tracked) do
        removeESP(obj)
    end

    if gui then
        gui:Destroy()
    end

    _G.FruitHub192Stop = nil
    print("FRUIT ESP HUB v1.9.2 UNLOADED")
end

_G.FruitHub192Stop = unload

button(
    "UNLOAD SCRIPT",
    unload,
    Color3.fromRGB(155, 45, 50)
)

-- Main loop
task.spawn(function()
    while running and gui.Parent do
        local success, results = pcall(scan)

        if success then
            countLabel.Text =
                "Fruits Found: " .. #results

            if settings.Nearest and results[1] then
                nearestLabel.Text = string.format(
                    "Nearest: %s
Distance: %.0f studs",
                    results[1].obj.Name,
                    results[1].distance
                )
            else
                nearestLabel.Text = "Nearest: None"
            end

            if settings.FruitList then
                local lines = {}

                for i, item in ipairs(results) do
                    if i > 8 then break end

                    table.insert(lines, string.format(
                        "%d. %s - %.0f studs",
                        i,
                        item.obj.Name,
                        item.distance
                    ))
                end

                listText.Text = #lines > 0
                    and table.concat(lines, "
")
                    or "No fruits detected"
            else
                listText.Text = "Fruit List disabled"
            end

            if settings.AutoCollect and results[1] then
                tryCollect(results[1])
            end
        else
            warn("[Fruit Hub Scan]", results)
        end

        if settings.AutoStorage then
            tryStorage(false)
        end

        task.wait(2)
    end
end)

-- Update ESP distance
heartbeat = RunService.Heartbeat:Connect(function()
    if not running or not gui.Parent then
        return
    end

    local root = getRoot()
    if not root then return end

    for obj, data in pairs(tracked) do
        if data.part and data.part.Parent then
            local distance = (
                root.Position - data.part.Position
            ).Magnitude

            data.billboard.Enabled =
                settings.ESP and settings.Distance

            data.label.Text = string.format(
                "%s
%.0f studs",
                obj.Name,
                distance
            )
        end
    end
end)

-- Minimize
local minimized = false

minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized

    main.Size = minimized
        and UDim2.fromOffset(340, 42)
        or UDim2.fromOffset(340, 590)

    minimize.Text =
        minimized and "+" or "-"
end)

notify("Fruit ESP HUB v1.9.2 loaded!")
print("FRUIT ESP HUB v1.9.2 LOADED")
