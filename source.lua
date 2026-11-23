
--[[
    PROJECT NOX
    COMPLETE REPLACEMENT

    U          Open/close menu
    Left Shift Toggle target tracking
    E          Player ESP
    G          Next other-team player
    Hold Tab   Temporary free mouse

    - NO upside-down camera flipping
    - NO sideways camera roll
    - Existing game Shift Lock preserved
    - Draggable UI
    - Half-speed target list scrolling
    - Hidden experimental NPC section
    - Player / NPC nearest-target selection
    - One target at a time
    - Player respawn support
    - Animated startup notification

    Roblox Studio:
    StarterPlayer > StarterPlayerScripts
    Insert as a LocalScript.
]]

-- ========================================
-- SERVICES
-- ========================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")
local playerScripts = me:WaitForChild("PlayerScripts")

-- ========================================
-- CONFIGURATION
-- ========================================

local PURPLE = Color3.fromRGB(125, 82, 235)
local CYAN = Color3.fromRGB(70, 215, 255)
local DARK = Color3.fromRGB(25, 28, 42)
local BUTTON = Color3.fromRGB(46, 50, 70)

local AIM_HEIGHT = 1.5
local DOT_DISTANCE = 150
local SCROLL_STEP = 18
local NOTICE_SECONDS = 5

local MAX_PITCH = math.rad(89.5)

-- ========================================
-- CLEAN UP PREVIOUS INSTANCE
-- ========================================

-- Prevent duplicate camera loops when the
-- script is run more than once.

if _G.ProjectNoxCleanup then
    pcall(_G.ProjectNoxCleanup)
end

local connections = {}
local espObjects = {}
local playerConnections = {}

local gui = nil
local running = true

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function cleanup()
    if not running then return end
    running = false

    pcall(function()
        RunService:UnbindFromRenderStep("ProjectNoxAim")
        RunService:UnbindFromRenderStep("ProjectNoxFreeMouse")
    end)

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    for _, group in pairs(playerConnections) do
        for _, connection in ipairs(group) do
            connection:Disconnect()
        end
    end

    for _, objects in pairs(espObjects) do
        for _, object in ipairs(objects) do
            if object then
                object:Destroy()
            end
        end
    end

    if gui then
        gui:Destroy()
    end
end

_G.ProjectNoxCleanup = cleanup

local oldGui = playerGui:FindFirstChild("ProjectNox")
if oldGui then
    oldGui:Destroy()
end

-- ========================================
-- STATE
-- ========================================

local selected = nil
local selectedKind = nil

local tracking = false
local espEnabled = false
local holdingTab = false

local currentSection = "Players"
local savedCamera = nil
local lastYaw = nil

-- ========================================
-- GUI HELPERS
-- ========================================

local function addCorner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = object
end

local function createButton(parent, text, pos, size)
    local b = Instance.new("TextButton")

    b.Position = pos
    b.Size = size
    b.BackgroundColor3 = BUTTON
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = parent

    addCorner(b, 8)

    return b
end

-- ========================================
-- MAIN GUI
-- ========================================

gui = Instance.new("ScreenGui")
gui.Name = "ProjectNox"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

local menu = Instance.new("Frame")
menu.Name = "MainMenu"
menu.Size = UDim2.fromOffset(340, 406)
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.BackgroundColor3 = DARK
menu.Visible = false
menu.Parent = gui

addCorner(menu, 12)

-- Draggable title

local title = Instance.new("TextLabel")
title.Name = "DragHandle"
title.Position = UDim2.fromOffset(9, 0)
title.Size = UDim2.new(1, -60, 0, 44)
title.BackgroundTransparency = 1
title.Text = "PROJECT NOX"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Active = true
title.Parent = menu

-- Hidden NPC section

local moreButton = createButton(
    menu,
    "...",
    UDim2.new(1, -46, 0, 8),
    UDim2.fromOffset(36, 29)
)

local sectionButton = createButton(
    menu,
    "PLAYERS",
    UDim2.fromOffset(9, 48),
    UDim2.new(1, -18, 0, 34)
)

local nearestButton = createButton(
    menu,
    "NEAREST PLAYER",
    UDim2.fromOffset(9, 91),
    UDim2.new(1, -18, 0, 37)
)

local enemyButton = createButton(
    menu,
    "NEAREST OTHER-TEAM PLAYER",
    UDim2.fromOffset(9, 135),
    UDim2.new(1, -18, 0, 37)
)

local clearButton = createButton(
    menu,
    "UNSELECT TARGET",
    UDim2.fromOffset(9, 179),
    UDim2.new(1, -18, 0, 34)
)

clearButton.BackgroundColor3 =
    Color3.fromRGB(118, 53, 66)

-- ========================================
-- TARGET LIST
-- ========================================

local list = Instance.new("ScrollingFrame")
list.Name = "TargetList"
list.Position = UDim2.fromOffset(9, 222)
list.Size = UDim2.new(1, -18, 0, 108)
list.BackgroundColor3 = Color3.fromRGB(34, 38, 54)
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = PURPLE
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.None
list.ScrollingEnabled = false
list.ClipsDescendants = true
list.Parent = menu

addCorner(list, 8)

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 4)
listPadding.PaddingLeft = UDim.new(0, 4)
listPadding.PaddingRight = UDim.new(0, 7)
listPadding.Parent = list

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function updateCanvas()
    list.CanvasSize = UDim2.fromOffset(
        0,
        layout.AbsoluteContentSize.Y + 8
    )
end

connect(
    layout:GetPropertyChangedSignal("AbsoluteContentSize"),
    updateCanvas
)

-- ========================================
-- ESP BUTTON / STATUS
-- ========================================

local espButton = createButton(
    menu,
    "PLAYER ESP: OFF [E]",
    UDim2.fromOffset(9, 340),
    UDim2.new(1, -18, 0, 34)
)

local footer = Instance.new("TextLabel")
footer.Position = UDim2.fromOffset(9, 379)
footer.Size = UDim2.new(1, -18, 0, 18)
footer.BackgroundTransparency = 1
footer.Text = "G: NEXT ENEMY | HOLD TAB: FREE MOUSE"
footer.TextColor3 = Color3.fromRGB(175, 180, 205)
footer.Font = Enum.Font.Gotham
footer.TextSize = 10
footer.Parent = menu

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(350, 30)
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.new(0.5, 0, 1, -10)
status.BackgroundColor3 = DARK
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.Parent = gui

addCorner(status, 8)

-- ========================================
-- DRAGGABLE MENU
-- ========================================

local dragging = false
local dragStart = nil
local menuStart = nil
local dragTouch = nil

connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        menuStart = menu.Position

        dragTouch =
            input.UserInputType == Enum.UserInputType.Touch
            and input or nil
    end
end)

connect(UIS.InputChanged, function(input)
    if not dragging then return end

    local mouseMove =
        input.UserInputType == Enum.UserInputType.MouseMovement

    local touchMove = input == dragTouch

    if not mouseMove and not touchMove then
        return
    end

    local delta = input.Position - dragStart

    menu.Position = UDim2.new(
        menuStart.X.Scale,
        menuStart.X.Offset + delta.X,
        menuStart.Y.Scale,
        menuStart.Y.Offset + delta.Y
    )
end)

connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input == dragTouch then

        dragging = false
        dragTouch = nil
    end
end)

-- ========================================
-- HALF-SPEED SCROLLING
-- ========================================

local function inside(object, point)
    local p = object.AbsolutePosition
    local s = object.AbsoluteSize

    return point.X >= p.X
        and point.X <= p.X + s.X
        and point.Y >= p.Y
        and point.Y <= p.Y + s.Y
end

local function scrollList(amount)
    local maxY = math.max(
        0,
        list.AbsoluteCanvasSize.Y
            - list.AbsoluteWindowSize.Y
    )

    list.CanvasPosition = Vector2.new(
        0,
        math.clamp(
            list.CanvasPosition.Y + amount,
            0,
            maxY
        )
    )
end

connect(UIS.InputChanged, function(input)
    if not menu.Visible then return end

    if input.UserInputType == Enum.UserInputType.MouseWheel then
        local pointer = UIS:GetMouseLocation()

        if inside(list, pointer) then
            scrollList(
                -input.Position.Z * SCROLL_STEP
            )
        end
    end
end)

-- ========================================
-- CHARACTER HELPERS
-- ========================================

local function getHumanoid(model)
    if not model then return nil end
    return model:FindFirstChildOfClass("Humanoid")
end

local function getRoot(model)
    if not model then return nil end

    local humanoid = getHumanoid(model)

    if not humanoid or humanoid.Health <= 0 then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
end

local function isNPC(model)
    return model
        and model:IsA("Model")
        and model:IsDescendantOf(workspace)
        and model ~= me.Character
        and not Players:GetPlayerFromCharacter(model)
        and getHumanoid(model) ~= nil
end

local function targetModel()
    if not selected then return nil end

    if selectedKind == "Player" then
        if selected.Parent == Players then
            return selected.Character
        end
    elseif selectedKind == "NPC" then
        if isNPC(selected) then
            return selected
        end
    end

    return nil
end

local function selectedName()
    if not selected then return "None" end

    if selectedKind == "Player" then
        return selected.DisplayName
    end

    return selected.Name
end

local function updateStatus(message)
    status.Text = message or (
        "Target: " .. selectedName()
        .. " | Aim: " .. (tracking and "ON" or "OFF")
        .. " | ESP: " .. (espEnabled and "ON" or "OFF")
    )
end

-- ========================================
-- SHIFT LOCK INTEGRATION
-- ========================================

-- Your existing custom Shift Lock controller
-- can provide this BindableEvent.
-- No fake Shift Lock is created.

local function requestShiftOff()
    local event = playerScripts:FindFirstChild(
        "DisableShiftLock"
    )

    if event and event:IsA("BindableEvent") then
        event:Fire()
    end
end

-- ========================================
-- TARGET CONTROL
-- ========================================

local function stopTracking()
    tracking = false
    lastYaw = nil
    updateStatus()
end

local function selectTarget(object, kind, keepTracking)
    local previouslyTracking = tracking

    tracking = false
    lastYaw = nil

    if not keepTracking then
        requestShiftOff()
    end

    selected = object
    selectedKind = kind

    tracking = keepTracking
        and previouslyTracking
        and getRoot(targetModel()) ~= nil
        or false

    menu.Visible = false
    updateStatus()
end

local function clearTarget()
    stopTracking()
    requestShiftOff()

    selected = nil
    selectedKind = nil

    updateStatus()
end

-- ========================================
-- TEAMS
-- ========================================

local function playerTeam(p)
    if p.Neutral or not p.Team then
        return nil
    end

    return p.Team
end

local function otherTeamPlayer(p)
    if p == me then return false end

    local mine = playerTeam(me)
    local theirs = playerTeam(p)

    return mine ~= nil
        and theirs ~= nil
        and mine ~= theirs
end

-- ========================================
-- EXPERIMENTAL NPC TEAM DETECTION
-- ========================================

local COLORS = {
    "red", "blue", "green",
    "yellow", "purple", "orange",
    "pink", "cyan", "white", "black"
}

local function detectColor(value)
    if typeof(value) ~= "string" then
        return nil
    end

    local lower = value:lower()

    for _, color in ipairs(COLORS) do
        if lower:find(
            "%f[%a]" .. color .. "%f[%A]"
        ) then
            return color
        end
    end

    return nil
end

local function myTeamColor()
    local team = playerTeam(me)

    if not team then return nil end

    return detectColor(team.Name)
        or detectColor(team.TeamColor.Name)
end

local function npcTeamInfo(npc)
    local name = nil
    local color = nil

    for _, field in ipairs({
        "Team", "TeamName",
        "Faction", "TeamColor",
        "FactionName"
    }) do
        local attribute = npc:GetAttribute(field)

        if attribute ~= nil then
            local text = tostring(attribute):lower()
            name = name or text
            color = color or detectColor(text)
        end

        local value = npc:FindFirstChild(field)

        if value and value:IsA("ValueBase") then
            local text = tostring(value.Value):lower()
            name = name or text
            color = color or detectColor(text)
        end
    end

    color = color or detectColor(npc.Name)

    if npc.Parent then
        color = color or detectColor(npc.Parent.Name)
    end

    return name, color
end

local function otherTeamNPC(npc)
    local team = playerTeam(me)

    if not team then return false end

    local name, color = npcTeamInfo(npc)
    local ownColor = myTeamColor()

    if name == team.Name:lower() then
        return false
    end

    if color and ownColor then
        return color ~= ownColor
    end

    if name then
        return name ~= team.Name:lower()
    end

    return false
end

-- ========================================
-- NPC SEARCH
-- ========================================

local function getNPCs()
    local results = {}
    local seen = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") then
            local model = obj.Parent

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

-- ========================================
-- TARGET LIST
-- ========================================

local function refreshList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    list.CanvasPosition = Vector2.zero

    if currentSection == "Players" then
        sectionButton.Text = "PLAYERS"
        nearestButton.Text = "NEAREST PLAYER"
        enemyButton.Text = "NEAREST OTHER-TEAM PLAYER"
        moreButton.BackgroundColor3 = BUTTON
    else
        sectionButton.Text = "NPCs (EXPERIMENTAL)"
        nearestButton.Text = "NEAREST NPC"
        enemyButton.Text =
            "NEAREST OTHER-TEAM NPC (EXPERIMENTAL)"
        moreButton.BackgroundColor3 = PURPLE
    end

    local entries = {}

    if currentSection == "Players" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me then
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
                label = npc.Name
            })
        end
    end

    table.sort(entries, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    for _, entry in ipairs(entries) do
        local b = createButton(
            list,
            entry.label,
            UDim2.new(),
            UDim2.new(1, -2, 0, 30)
        )

        if selected == entry.object then
            b.BackgroundColor3 = PURPLE
        end

        connect(b.MouseButton1Click, function()
            selectTarget(entry.object, entry.kind, false)
        end)
    end

    updateCanvas()
end

-- ========================================
-- MENU SECTION BUTTONS
-- ========================================

connect(moreButton.MouseButton1Click, function()
    currentSection =
        currentSection == "Players"
        and "NPCs" or "Players"

    refreshList()
end)

connect(sectionButton.MouseButton1Click, function()
    currentSection = "Players"
    refreshList()
end)

-- ========================================
-- NEAREST TARGET
-- ========================================

local function chooseNearest(enemyOnly)
    local ownRoot = getRoot(me.Character)

    if not ownRoot then
        updateStatus("Your character is not ready")
        return
    end

    local best = nil
    local bestDistance = math.huge

    local function consider(object, root, allowed)
        if not root or not allowed then return end

        local distance = (
            root.Position - ownRoot.Position
        ).Magnitude

        if distance < bestDistance then
            bestDistance = distance
            best = object
        end
    end

    if currentSection == "Players" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me then
                consider(
                    p,
                    getRoot(p.Character),
                    not enemyOnly or otherTeamPlayer(p)
                )
            end
        end
    else
        for _, npc in ipairs(getNPCs()) do
            consider(
                npc,
                getRoot(npc),
                not enemyOnly or otherTeamNPC(npc)
            )
        end
    end

    if best then
        selectTarget(
            best,
            currentSection == "Players"
                and "Player" or "NPC",
            false
        )
    else
        updateStatus("No matching loaded target")
    end
end

connect(nearestButton.MouseButton1Click, function()
    chooseNearest(false)
end)

connect(enemyButton.MouseButton1Click, function()
    chooseNearest(true)
end)

connect(clearButton.MouseButton1Click, function()
    clearTarget()
    refreshList()
end)

-- ========================================
-- G: CYCLE OTHER-TEAM PLAYERS
-- ========================================

local function cycleEnemy()
    local ownRoot = getRoot(me.Character)
    if not ownRoot then return end

    local available = {}

    for _, p in ipairs(Players:GetPlayers()) do
        local root = getRoot(p.Character)

        if root and otherTeamPlayer(p) then
            table.insert(available, {
                player = p,
                distance = (
                    root.Position - ownRoot.Position
                ).Magnitude
            })
        end
    end

    table.sort(available, function(a, b)
        if a.distance == b.distance then
            return a.player.UserId < b.player.UserId
        end

        return a.distance < b.distance
    end)

    if #available == 0 then
        updateStatus("No other-team players available")
        return
    end

    local index = 0

    if selectedKind == "Player" then
        for i, entry in ipairs(available) do
            if entry.player == selected then
                index = i
                break
            end
        end
    end

    local nextIndex = index % #available + 1

    selectTarget(
        available[nextIndex].player,
        "Player",
        true
    )
end

-- ========================================
-- PLAYER ESP
-- ========================================

local function removeESP(p)
    local objects = espObjects[p]
    if not objects then return end

    for _, obj in ipairs(objects) do
        if obj then obj:Destroy() end
    end

    espObjects[p] = nil
end

local function createESP(p)
    if p == me or not espEnabled then return end

    removeESP(p)

    local char = p.Character
    local head = char and char:FindFirstChild("Head")

    if not head then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "NoxHighlight"
    highlight.Adornee = char
    highlight.DepthMode =
        Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = CYAN
    highlight.OutlineColor = CYAN
    highlight.FillTransparency = 0.75
    highlight.Parent = char

    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "NoxName"
    nameGui.Adornee = head
    nameGui.Size = UDim2.fromOffset(155, 24)
    nameGui.StudsOffsetWorldSpace =
        Vector3.new(0, 1.3, 0)
    nameGui.AlwaysOnTop = true
    nameGui.MaxDistance = 0
    nameGui.Parent = head

    local nameText = Instance.new("TextLabel")
    nameText.Size = UDim2.fromScale(1, 1)
    nameText.BackgroundTransparency = 1
    nameText.Text = p.DisplayName
    nameText.TextSize = 12
    nameText.Font = Enum.Font.GothamBold
    nameText.TextColor3 = CYAN
    nameText.TextStrokeTransparency = 0.15
    nameText.Parent = nameGui

    local dotGui = Instance.new("BillboardGui")
    dotGui.Name = "NoxDot"
    dotGui.Adornee = head
    dotGui.Size = UDim2.fromOffset(9, 9)
    dotGui.AlwaysOnTop = true
    dotGui.MaxDistance = 0
    dotGui.Enabled = false
    dotGui.Parent = head

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromScale(1, 1)
    dot.BackgroundColor3 = CYAN
    dot.BorderSizePixel = 0
    dot.Parent = dotGui

    addCorner(dot, 9)

    espObjects[p] = {
        highlight,
        nameGui,
        dotGui
    }
end

local function setESP(enabled)
    espEnabled = enabled

    espButton.Text = enabled
        and "PLAYER ESP: ON [E]"
        or "PLAYER ESP: OFF [E]"

    espButton.BackgroundColor3 =
        enabled and PURPLE or BUTTON

    if enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            createESP(p)
        end
    else
        for p in pairs(espObjects) do
            removeESP(p)
        end
    end

    updateStatus()
end

connect(espButton.MouseButton1Click, function()
    setESP(not espEnabled)
end)

-- ========================================
-- HOLD TAB: FREE MOUSE
-- ========================================

-- Tab is not consumed, so the game's own
-- Tab action can continue working.

local function beginTab()
    if holdingTab then return end

    holdingTab = true

    savedCamera = {
        mode = me.CameraMode,
        min = me.CameraMinZoomDistance,
        max = me.CameraMaxZoomDistance
    }

    me.CameraMode = Enum.CameraMode.Classic

    me.CameraMaxZoomDistance = math.max(
        me.CameraMaxZoomDistance,
        8
    )

    me.CameraMinZoomDistance = 8
end

local function endTab()
    if not holdingTab then return end

    holdingTab = false

    local old = savedCamera
    savedCamera = nil

    if not old then return end

    me.CameraMaxZoomDistance = math.max(
        old.max, old.min
    )

    me.CameraMinZoomDistance = old.min
    me.CameraMaxZoomDistance = old.max
    me.CameraMode = old.mode
end

RunService:BindToRenderStep(
    "ProjectNoxFreeMouse",
    Enum.RenderPriority.Last.Value,
    function()
        if holdingTab then
            UIS.MouseBehavior = Enum.MouseBehavior.Default
            UIS.MouseIconEnabled = true
        end
    end
)

connect(UIS.InputEnded, function(input)
    if input.KeyCode == Enum.KeyCode.Tab then
        endTab()
    end
end)

connect(UIS.WindowFocusReleased, endTab)

-- ========================================
-- KEYBOARD
-- ========================================

connect(UIS.InputBegan, function(input, processed)
    if UIS:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.Tab then
        beginTab()
        return
    end

    -- Existing Shift Lock gets the Shift key.
    -- Project Nox only changes tracking state.

    if input.KeyCode == Enum.KeyCode.LeftShift then
        if menu.Visible then return end

        if tracking then
            stopTracking()

        elseif selected and getRoot(targetModel()) then
            tracking = true
            lastYaw = nil
            updateStatus()
        end

        return
    end

    if processed then return end

    if input.KeyCode == Enum.KeyCode.U then
        local opening = not menu.Visible

        if opening then
            stopTracking()
            refreshList()
        end

        menu.Visible = opening

    elseif input.KeyCode == Enum.KeyCode.E then
        setESP(not espEnabled)

    elseif input.KeyCode == Enum.KeyCode.G then
        cycleEnemy()
    end
end)

-- ========================================
-- NO-FLIP CAMERA TRACKING
-- ========================================
--
-- FIX:
-- Previously, camera roll could accumulate.
-- Now ONLY yaw and pitch are used.
--
-- Yaw   = left/right turning
-- Pitch = up/down turning
-- Roll  = always zero
--
-- Players behind you are reached by turning
-- horizontally, never by flipping the screen.
--
-- Camera position, Focus, and existing
-- Shift Lock are left unchanged.

RunService:BindToRenderStep(
    "ProjectNoxAim",
    Enum.RenderPriority.Camera.Value + 2,
    function()
        if not tracking or holdingTab then
            return
        end

        local camera = workspace.CurrentCamera

        if not camera then
            return
        end

        local root = getRoot(targetModel())

        -- Target may temporarily disappear
        -- due to respawn or streaming.
        if not root then
            return
        end

        local cameraPosition = camera.CFrame.Position

        local targetPosition =
            root.Position + Vector3.new(
                0, AIM_HEIGHT, 0
            )

        local direction =
            targetPosition - cameraPosition

        if direction.Magnitude < 0.05 then
            return
        end

        -- Left/right direction
        local dx = direction.X
        local dz = direction.Z

        local horizontalDistance =
            math.sqrt(dx * dx + dz * dz)

        local yaw

        if horizontalDistance > 0.02 then
            -- Always turn left/right toward target.
            yaw = math.atan2(-dx, -dz)
            lastYaw = yaw
        else
            -- Directly above/below the target:
            -- preserve horizontal heading.
            if lastYaw == nil then
                local look = camera.CFrame.LookVector

                local lookFlat = Vector3.new(
                    look.X, 0, look.Z
                )

                if lookFlat.Magnitude > 0.001 then
                    lastYaw = math.atan2(
                        -lookFlat.X,
                        -lookFlat.Z
                    )
                else
                    lastYaw = 0
                end
            end

            yaw = lastYaw
        end

        -- Up/down direction
        local pitch = math.atan2(
            direction.Y,
            horizontalDistance
        )

        -- Stay slightly away from exact
        -- vertical to avoid singularities.
        pitch = math.clamp(
            pitch,
            -MAX_PITCH,
            MAX_PITCH
        )

        -- No Z-axis rotation means NO roll.
        local rotation =
            CFrame.Angles(0, yaw, 0)
            * CFrame.Angles(pitch, 0, 0)

        camera.CFrame =
            CFrame.new(cameraPosition) * rotation

        -- Intentionally untouched:
        -- camera.Focus
        -- camera.CameraSubject
        -- camera.CameraType
        -- me.CameraMode
        -- UIS.MouseBehavior
        -- Humanoid.CameraOffset
    end
)

-- ========================================
-- ESP DISTANCE UPDATE
-- ========================================

local espTimer = 0

connect(RunService.Heartbeat, function(dt)
    espTimer += dt

    if espTimer < 0.15 then return end
    espTimer = 0

    if not espEnabled then return end

    local ownRoot = getRoot(me.Character)
    if not ownRoot then return end

    for p, objects in pairs(espObjects) do
        local root = getRoot(p.Character)

        if root then
            local far = (
                root.Position - ownRoot.Position
            ).Magnitude > DOT_DISTANCE

            objects[1].Enabled = not far
            objects[2].Enabled = true
            objects[3].Enabled = far
        else
            objects[1].Enabled = false
            objects[2].Enabled = false
            objects[3].Enabled = false
        end
    end

    -- Rebuild missing ESP after respawn.

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me
            and p.Character
            and p.Character:FindFirstChild("Head")
            and not espObjects[p] then

            createESP(p)
        end
    end
end)

-- ========================================
-- PLAYER JOIN / RESPAWN
-- ========================================

local function registerPlayer(p)
    if p == me or playerConnections[p] then
        return
    end

    playerConnections[p] = {
        p.CharacterAdded:Connect(function(char)
            char:WaitForChild("Head", 10)

            if espEnabled then
                createESP(p)
            end

            if menu.Visible
                and currentSection == "Players" then

                refreshList()
            end
        end),

        p.CharacterRemoving:Connect(function()
            removeESP(p)

            -- Keep selection through respawn.
        end)
    }

    if espEnabled then
        createESP(p)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    registerPlayer(p)
end

connect(Players.PlayerAdded, function(p)
    registerPlayer(p)

    if menu.Visible and currentSection == "Players" then
        refreshList()
    end
end)

connect(Players.PlayerRemoving, function(p)
    removeESP(p)

    if playerConnections[p] then
        for _, c in ipairs(playerConnections[p]) do
            c:Disconnect()
        end

        playerConnections[p] = nil
    end

    if selectedKind == "Player" and selected == p then
        clearTarget()
    end

    if menu.Visible and currentSection == "Players" then
        refreshList()
    end
end)

-- ========================================
-- NPC UPDATES
-- ========================================

local npcRefreshPending = false

local function refreshNPCsSoon()
    if npcRefreshPending then return end

    npcRefreshPending = true

    task.defer(function()
        if not running then return end

        npcRefreshPending = false

        if menu.Visible and currentSection == "NPCs" then
            refreshList()
        end
    end)
end

connect(workspace.DescendantAdded, function(obj)
    if obj:IsA("Humanoid") then
        refreshNPCsSoon()
    end
end)

connect(workspace.DescendantRemoving, function(obj)
    if obj:IsA("Humanoid") then
        if selectedKind == "NPC"
            and selected == obj.Parent then

            clearTarget()
        end

        refreshNPCsSoon()
    end
end)

connect(me.CharacterAdded, function()
    endTab()
    stopTracking()
end)

-- ========================================
-- INITIALIZE
-- ========================================

refreshList()
updateStatus()

-- ========================================
-- ANIMATED STARTUP NOTIFICATION
-- ========================================

local notice = Instance.new("Frame")
notice.Name = "NoxWelcome"
notice.Size = UDim2.fromOffset(260, 56)
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, -70)
notice.BackgroundColor3 = DARK
notice.ClipsDescendants = true
notice.Parent = gui

addCorner(notice, 10)

local noticeText = Instance.new("TextLabel")
noticeText.Size = UDim2.new(1, -20, 1, -4)
noticeText.Position = UDim2.fromOffset(10, 0)
noticeText.BackgroundTransparency = 1
noticeText.Text = "Press U to Open Menu"
noticeText.TextColor3 = Color3.new(1, 1, 1)
noticeText.Font = Enum.Font.GothamBold
noticeText.TextSize = 14
noticeText.Parent = notice

local barTrack = Instance.new("Frame")
barTrack.Size = UDim2.new(1, 0, 0, 4)
barTrack.Position = UDim2.new(0, 0, 1, -4)
barTrack.BackgroundColor3 = Color3.fromRGB(62, 64, 78)
barTrack.BorderSizePixel = 0
barTrack.Parent = notice

local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(1, 1)
bar.BackgroundColor3 = PURPLE
bar.BorderSizePixel = 0
bar.Parent = barTrack

task.spawn(function()
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

    if not running then return end

    local drain = TweenService:Create(
        bar,
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

    if not running then return end

    local disappear = TweenService:Create(
        notice,
        TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.In
        ),
        {
            Position = UDim2.new(0.5, 0, 0, -70)
        }
    )

    disappear:Play()
    disappear.Completed:Wait()

    if notice.Parent then
        notice:Destroy()
    end
end)
