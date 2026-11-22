
--[[
    TARGET TRACKER
    Players + NPCs

    U = Open / close menu
    Left Shift = Camera tracking
    E = Player ESP

    Existing Shift Lock is preserved.
    No fake Shift Lock cursor.
    No camera offset changes.
    No forced Camera.Focus changes.

    Only ONE selected target at a time.
    ESP applies ONLY to real players.
]]

-- SERVICES

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- SETTINGS

local AIM_HEIGHT = 1.5
local DOT_DISTANCE = 150
local ESP_COLOR = Color3.fromRGB(0, 220, 255)
local NOTICE_SECONDS = 5

-- STATE

local selected = nil
local selectedType = nil
local tracking = false
local espEnabled = false
local tab = "Players"

local espObjects = {}
local playerConnections = {}

-- GUI HELPERS

local function round(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = object
end

local function newButton(parent, text, size, position)
    local b = Instance.new("TextButton")

    b.Size = size
    b.Position = position or UDim2.new()
    b.BackgroundColor3 = Color3.fromRGB(43, 49, 65)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.Text = text
    b.Parent = parent

    round(b, 8)

    return b
end

-- MAIN GUI

local gui = Instance.new("ScreenGui")
gui.Name = "TargetTracker"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

local menu = Instance.new("Frame")
menu.Name = "TargetMenu"
menu.Size = UDim2.fromOffset(320, 440)
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.BackgroundColor3 = Color3.fromRGB(23, 28, 40)
menu.Visible = false
menu.Parent = gui
round(menu, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 45)
title.BackgroundTransparency = 1
title.Text = "TARGET TRACKER"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = menu

-- TABS

local playerTab = newButton(
    menu,
    "PLAYERS",
    UDim2.new(0.5, -15, 0, 38),
    UDim2.fromOffset(10, 48)
)

local npcTab = newButton(
    menu,
    "NPCs",
    UDim2.new(0.5, -15, 0, 38),
    UDim2.new(0.5, 5, 0, 48)
)

-- UNSELECT

local unselectButton = newButton(
    menu,
    "UNSELECT TARGET",
    UDim2.new(1, -20, 0, 38),
    UDim2.fromOffset(10, 94)
)

unselectButton.BackgroundColor3 =
    Color3.fromRGB(120, 55, 65)

-- ESP TOGGLE

local espButton = newButton(
    menu,
    "PLAYER ESP: OFF [E]",
    UDim2.new(1, -20, 0, 38),
    UDim2.fromOffset(10, 140)
)

-- SCROLLING LIST

local list = Instance.new("ScrollingFrame")
list.Name = "TargetList"
list.Position = UDim2.fromOffset(10, 190)
list.Size = UDim2.new(1, -20, 1, -202)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = menu

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

-- STATUS BAR

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(330, 32)
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.new(0.5, 0, 1, -12)
status.BackgroundColor3 = Color3.fromRGB(23, 28, 40)
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.Parent = gui
round(status, 8)

-- CHARACTER HELPERS

local function getRoot(model)
    if not model then
        return nil
    end

    local humanoid =
        model:FindFirstChildOfClass("Humanoid")

    if not humanoid or humanoid.Health <= 0 then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
end

local function isNPC(model)
    return model ~= nil
        and model:IsA("Model")
        and model:IsDescendantOf(workspace)
        and model ~= player.Character
        and not Players:GetPlayerFromCharacter(model)
        and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function getTargetModel()
    if not selected then
        return nil
    end

    if selectedType == "Player" then
        if selected.Parent == Players then
            return selected.Character
        end

    elseif selectedType == "NPC" then
        if isNPC(selected) then
            return selected
        end
    end

    return nil
end

local function getTargetName()
    if not selected then
        return "None"
    end

    if selectedType == "Player" then
        return selected.DisplayName
    end

    return selected.Name
end

local function updateStatus()
    status.Text =
        "Target: " .. getTargetName()
        .. " | Aim: " .. (tracking and "ON" or "OFF")
        .. " | ESP: " .. (espEnabled and "ON" or "OFF")
end

-- TRACKING CONTROL

local function setTracking(value)
    if value and not getRoot(getTargetModel()) then
        tracking = false
    else
        tracking = value
    end

    updateStatus()
end

-- OPTIONAL CUSTOM SHIFT LOCK INTEGRATION
-- If your game has a BindableEvent named
-- "DisableShiftLock" inside PlayerScripts,
-- fire it when selecting a target.
-- Your game's Shift Lock script must listen
-- for that event and switch itself OFF.

local function requestShiftLockOff()
    local playerScripts = player:FindFirstChild(
        "PlayerScripts"
    )

    if not playerScripts then return end

    local event = playerScripts:FindFirstChild(
        "DisableShiftLock"
    )

    if event and event:IsA("BindableEvent") then
        event:Fire()
    end
end

local function clearSelection()
    setTracking(false)
    requestShiftLockOff()

    selected = nil
    selectedType = nil

    updateStatus()
end

-- NPC DISCOVERY

local function getNPCs()
    local results = {}
    local seen = {}

    for _, object in ipairs(
        workspace:GetDescendants()
    ) do

        if object:IsA("Humanoid") then
            local model = object.Parent

            if isNPC(model)
                and getRoot(model)
                and not seen[model] then

                seen[model] = true
                table.insert(results, model)
            end
        end
    end

    table.sort(results, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    return results
end

-- TARGET LIST

local function refreshList(excludedPlayer)

    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    playerTab.BackgroundColor3 =
        tab == "Players"
        and Color3.fromRGB(35, 115, 85)
        or Color3.fromRGB(43, 49, 65)

    npcTab.BackgroundColor3 =
        tab == "NPCs"
        and Color3.fromRGB(35, 115, 85)
        or Color3.fromRGB(43, 49, 65)

    local entries = {}

    if tab == "Players" then

        for _, p in ipairs(
            Players:GetPlayers()
        ) do

            if p ~= player and p ~= excludedPlayer then
                table.insert(entries, {
                    object = p,
                    kind = "Player",
                    label = p.DisplayName
                        .. " (@" .. p.Name .. ")"
                })
            end
        end

    else

        for _, npc in ipairs(getNPCs()) do
            table.insert(entries, {
                object = npc,
                kind = "NPC",
                label = "NPC | " .. npc.Name
            })
        end

    end

    table.sort(entries, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    for _, entry in ipairs(entries) do

        local b = newButton(
            list,
            entry.label,
            UDim2.new(1, -6, 0, 42)
        )

        if selected == entry.object then
            b.BackgroundColor3 =
                Color3.fromRGB(35, 115, 85)
        end

        b.MouseButton1Click:Connect(function()

            -- Stop tracking first
            setTracking(false)

            -- Ask existing Shift Lock to turn OFF
            requestShiftLockOff()

            -- Replace previous selection
            selected = entry.object
            selectedType = entry.kind

            menu.Visible = false
            updateStatus()
        end)
    end
end

playerTab.MouseButton1Click:Connect(function()
    tab = "Players"
    refreshList()
end)

npcTab.MouseButton1Click:Connect(function()
    tab = "NPCs"
    refreshList()
end)

unselectButton.MouseButton1Click:Connect(function()
    clearSelection()
    refreshList()
end)

-- PLAYER-ONLY ESP

local function removeESP(p)
    local objects = espObjects[p]
    if not objects then return end

    for _, object in pairs(objects) do
        if object then
            object:Destroy()
        end
    end

    espObjects[p] = nil
end

local function createESP(p)
    if p == player or not espEnabled then
        return
    end

    removeESP(p)

    local character = p.Character
    if not character then return end

    local head = character:FindFirstChild("Head")
    if not head then return end

    -- Body highlight

    local highlight = Instance.new("Highlight")
    highlight.Name = "TrackerHighlight"
    highlight.Adornee = character
    highlight.DepthMode =
        Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = ESP_COLOR
    highlight.OutlineColor = ESP_COLOR
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0
    highlight.Parent = character

    -- Name label

    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "TrackerName"
    nameGui.Adornee = head
    nameGui.Size = UDim2.fromOffset(150, 24)
    nameGui.StudsOffsetWorldSpace =
        Vector3.new(0, 1.3, 0)
    nameGui.AlwaysOnTop = true
    nameGui.MaxDistance = 0
    nameGui.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = p.DisplayName
    label.TextColor3 = ESP_COLOR
    label.TextStrokeColor3 =
        Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextScaled = false
    label.Parent = nameGui

    -- Distance dot

    local dotGui = Instance.new("BillboardGui")
    dotGui.Name = "TrackerDot"
    dotGui.Adornee = head
    dotGui.Size = UDim2.fromOffset(9, 9)
    dotGui.StudsOffsetWorldSpace =
        Vector3.new(0, 0.4, 0)
    dotGui.AlwaysOnTop = true
    dotGui.MaxDistance = 0
    dotGui.Enabled = false
    dotGui.Parent = head

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromScale(1, 1)
    dot.BackgroundColor3 = ESP_COLOR
    dot.BorderSizePixel = 0
    dot.Parent = dotGui
    round(dot, 20)

    espObjects[p] = {
        highlight = highlight,
        name = nameGui,
        dot = dotGui
    }
end

local function setESP(value)
    espEnabled = value

    espButton.Text = value
        and "PLAYER ESP: ON [E]"
        or "PLAYER ESP: OFF [E]"

    espButton.BackgroundColor3 = value
        and Color3.fromRGB(35, 115, 75)
        or Color3.fromRGB(43, 49, 65)

    if value then

        for _, p in ipairs(
            Players:GetPlayers()
        ) do
            createESP(p)
        end

    else

        for p in pairs(espObjects) do
            removeESP(p)
        end

    end

    updateStatus()
end

espButton.MouseButton1Click:Connect(function()
    setESP(not espEnabled)
end)

-- INPUT CONTROLS

UIS.InputBegan:Connect(function(input, processed)

    if UIS:GetFocusedTextBox() then
        return
    end

    -- LEFT SHIFT
    -- Don't consume the key.
    -- Existing Shift Lock still receives it.

    if input.KeyCode == Enum.KeyCode.LeftShift then

        if menu.Visible then
            return
        end

        if tracking then
            setTracking(false)
        elseif selected then
            setTracking(true)
        end

        return
    end

    if processed then
        return
    end

    -- U = MENU

    if input.KeyCode == Enum.KeyCode.U then

        local opening = not menu.Visible

        if opening then
            setTracking(false)
            refreshList()
        end

        menu.Visible = opening

    -- E = PLAYER ESP

    elseif input.KeyCode == Enum.KeyCode.E then
        setESP(not espEnabled)
    end
end)

-- CAMERA TRACKING
--
-- Runs after Roblox's camera controller.
-- Keeps current camera position.
-- Keeps Camera.Focus unchanged.
-- Allows full vertical tracking.
-- Does not override Shift Lock.

RunService:BindToRenderStep(
    "TargetTrackerCamera",
    Enum.RenderPriority.Camera.Value + 2,
    function()

        if not tracking then
            return
        end

        local camera = workspace.CurrentCamera

        if not camera then
            return
        end

        local model = getTargetModel()
        local root = getRoot(model)

        if not root then
            return
        end

        local cameraPos =
            camera.CFrame.Position

        local targetPos =
            root.Position
            + Vector3.new(0, AIM_HEIGHT, 0)

        local difference =
            targetPos - cameraPos

        if difference.Magnitude < 0.1 then
            return
        end

        -- Rotate ONLY.
        -- Do not move the camera.
        -- Do not change Camera.Focus.

        camera.CFrame = CFrame.lookAt(
            cameraPos,
            targetPos
        )
    end
)

-- PLAYER ESP DISTANCE UPDATES

local espTimer = 0

RunService.Heartbeat:Connect(function(dt)

    espTimer += dt

    if espTimer < 0.15 then
        return
    end

    espTimer = 0

    if not espEnabled then
        return
    end

    local myRoot = getRoot(player.Character)

    if not myRoot then
        return
    end

    for p, objects in pairs(espObjects) do

        local root = getRoot(p.Character)

        if root then

            local distance =
                (root.Position - myRoot.Position).Magnitude

            local far =
                distance > DOT_DISTANCE

            objects.highlight.Enabled = not far
            objects.name.Enabled = true
            objects.dot.Enabled = far

        else

            objects.highlight.Enabled = false
            objects.name.Enabled = false
            objects.dot.Enabled = false

        end
    end
end)

-- LIVE PLAYER UPDATES

local function setupPlayer(p)

    if p == player then
        return
    end

    local connections = {}
    playerConnections[p] = connections

    table.insert(
        connections,
        p.CharacterAdded:Connect(function(character)

            local head =
                character:WaitForChild("Head", 10)

            if head and espEnabled then
                createESP(p)
            end

        end)
    )

    table.insert(
        connections,
        p.CharacterRemoving:Connect(function()
            removeESP(p)
        end)
    )

    if espEnabled then
        createESP(p)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    setupPlayer(p)
end

Players.PlayerAdded:Connect(function(p)

    setupPlayer(p)

    if menu.Visible and tab == "Players" then
        refreshList()
    end
end)

Players.PlayerRemoving:Connect(function(p)

    removeESP(p)

    if playerConnections[p] then

        for _, connection in ipairs(
            playerConnections[p]
        ) do
            connection:Disconnect()
        end

        playerConnections[p] = nil
    end

    if selectedType == "Player"
        and selected == p then

        clearSelection()
    end

    if menu.Visible and tab == "Players" then
        refreshList(p)
    end
end)

-- LIVE NPC UPDATES

local npcRefreshPending = false

local function refreshNPCsSoon()

    if npcRefreshPending then
        return
    end

    npcRefreshPending = true

    task.defer(function()

        npcRefreshPending = false

        if menu.Visible and tab == "NPCs" then
            refreshList()
        end

    end)
end

workspace.DescendantAdded:Connect(function(obj)

    if obj:IsA("Humanoid") then
        refreshNPCsSoon()
    end

end)

workspace.DescendantRemoving:Connect(function(obj)

    if obj:IsA("Humanoid") then

        if selectedType == "NPC"
            and selected == obj.Parent then

            clearSelection()
        end

        refreshNPCsSoon()
    end
end)

-- RESPAWN

player.CharacterAdded:Connect(function()
    setTracking(false)
end)

-- INITIALIZE

refreshList()
updateStatus()

-- ==================================
-- STARTUP NOTIFICATION
-- ==================================

local notice = Instance.new("Frame")
notice.Name = "StartupNotification"
notice.Size = UDim2.fromOffset(260, 58)
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, -80)
notice.BackgroundColor3 =
    Color3.fromRGB(30, 40, 58)
notice.ClipsDescendants = true
notice.Parent = gui
round(notice, 10)

local noticeText = Instance.new("TextLabel")
noticeText.Size = UDim2.new(1, -20, 1, -4)
noticeText.Position = UDim2.fromOffset(10, 0)
noticeText.BackgroundTransparency = 1
noticeText.Text = "Press U to Open Menu"
noticeText.TextColor3 = Color3.new(1, 1, 1)
noticeText.Font = Enum.Font.GothamBold
noticeText.TextSize = 14
noticeText.Parent = notice

-- PROGRESS TRACK

local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.new(1, 0, 0, 4)
progressTrack.Position = UDim2.new(0, 0, 1, -4)
progressTrack.BackgroundColor3 =
    Color3.fromRGB(55, 70, 95)
progressTrack.BorderSizePixel = 0
progressTrack.Parent = notice

-- PROGRESS BAR

local progressBar = Instance.new("Frame")
progressBar.Size = UDim2.fromScale(1, 1)
progressBar.BackgroundColor3 =
    Color3.fromRGB(85, 185, 255)
progressBar.BorderSizePixel = 0
progressBar.Parent = progressTrack

-- ANIMATION

task.spawn(function()

    -- Slide down

    local appear = TweenService:Create(
        notice,
        TweenInfo.new(
            0.5,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
        {
            Position = UDim2.new(0.5, 0, 0, 22)
        }
    )

    appear:Play()
    appear.Completed:Wait()

    -- Drain progress bar over 5 seconds

    local drain = TweenService:Create(
        progressBar,
        TweenInfo.new(
            NOTICE_SECONDS,
            Enum.EasingStyle.Linear
        ),
        {
            Size = UDim2.fromScale(0, 1)
        }
    )

    drain:Play()
    drain.Completed:Wait()

    -- Slide away

    local disappear = TweenService:Create(
        notice,
        TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.In
        ),
        {
            Position = UDim2.new(0.5, 0, 0, -80)
        }
    )

    disappear:Play()
    disappear.Completed:Wait()

    notice:Destroy()
end)
