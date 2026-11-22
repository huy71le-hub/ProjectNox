
-- PROJECT NOX
-- Put in StarterPlayer > StarterPlayerScripts as a LocalScript
-- U = Menu | Shift = Track | E = ESP | Hold Tab = Free mouse

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CAS = game:GetService("ContextActionService")

local me = Players.LocalPlayer
local playerGui = me:WaitForChild("PlayerGui")
local playerScripts = me:WaitForChild("PlayerScripts")

local PURPLE = Color3.fromRGB(111, 79, 220)
local CYAN = Color3.fromRGB(80, 213, 255)
local DOT_DISTANCE = 150
local AIM_HEIGHT = 1.5

local target = nil
local targetKind = nil
local tracking = false
local espOn = false
local currentTab = "Players"
local holdingTab = false
local savedCamera = nil
local lastRight = nil

local espObjects = {}
local playerConnections = {}

-- UI

local gui = Instance.new("ScreenGui")
gui.Name = "ProjectNox"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

local function round(object, amount)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, amount)
    corner.Parent = object
end

local function newButton(parent, text, position, size)
    local b = Instance.new("TextButton")
    b.Position = position
    b.Size = size
    b.BackgroundColor3 = Color3.fromRGB(45, 49, 67)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Text = text
    b.Parent = parent
    round(b, 7)
    return b
end

local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(340, 420)
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
menu.Visible = false
menu.Parent = gui
round(menu, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "PROJECT NOX"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.Parent = menu

local playersTab = newButton(
    menu, "PLAYERS",
    UDim2.fromOffset(9, 43),
    UDim2.new(0.5, -14, 0, 33)
)

local npcsTab = newButton(
    menu, "NPCs",
    UDim2.new(0.5, 5, 0, 43),
    UDim2.new(0.5, -14, 0, 33)
)

local nearest = newButton(
    menu, "NEAREST (ANY TEAM)",
    UDim2.fromOffset(9, 84),
    UDim2.new(1, -18, 0, 34)
)

local nearestTeam = newButton(
    menu, "NEAREST TEAMMATE",
    UDim2.fromOffset(9, 124),
    UDim2.new(1, -18, 0, 34)
)

local nearestEnemy = newButton(
    menu, "NEAREST OTHER TEAM",
    UDim2.fromOffset(9, 164),
    UDim2.new(1, -18, 0, 34)
)

local unselect = newButton(
    menu, "UNSELECT TARGET",
    UDim2.fromOffset(9, 204),
    UDim2.new(1, -18, 0, 32)
)
unselect.BackgroundColor3 = Color3.fromRGB(111, 50, 65)

-- HALF-SIZE SCROLLING LIST

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(9, 244)
list.Size = UDim2.new(1, -18, 0, 116)
list.BackgroundColor3 = Color3.fromRGB(32, 37, 51)
list.ScrollBarThickness = 4
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.fromOffset(0, 0)
list.Parent = menu
round(list, 7)

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 4)
padding.PaddingRight = UDim.new(0, 6)
padding.PaddingTop = UDim.new(0, 4)
padding.Parent = list

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = list

local espButton = newButton(
    menu, "PLAYER ESP: OFF [E]",
    UDim2.fromOffset(9, 374),
    UDim2.new(1, -18, 0, 35)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(340, 30)
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.new(0.5, 0, 1, -12)
status.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.GothamMedium
status.TextSize = 11
status.Parent = gui
round(status, 8)

-- CHARACTER HELPERS

local function getRoot(model)
    if not model then return nil end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
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
        and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function targetModel()
    if targetKind == "Player" then
        if target and target.Parent == Players then
            return target.Character
        end
    elseif targetKind == "NPC" then
        if isNPC(target) then
            return target
        end
    end
    return nil
end

local function targetName()
    if not target then return "None" end
    if targetKind == "Player" then
        return target.DisplayName
    end
    return target.Name
end

local function updateStatus(message)
    status.Text = message or (
        "Target: " .. targetName()
        .. " | Aim: " .. (tracking and "ON" or "OFF")
        .. " | ESP: " .. (espOn and "ON" or "OFF")
    )
end

-- SHIFT LOCK INTEGRATION
-- The game's existing Shift Lock must listen for this
-- event if you want selecting a target to turn it off.

local function requestShiftOff()
    local event = playerScripts:FindFirstChild("DisableShiftLock")
    if event and event:IsA("BindableEvent") then
        event:Fire()
    end
end

local function stopTracking()
    tracking = false
    lastRight = nil
    updateStatus()
end

local function selectTarget(object, kind)
    stopTracking()
    requestShiftOff()

    -- Only ONE target at a time
    target = object
    targetKind = kind

    menu.Visible = false
    updateStatus()
end

local function clearTarget()
    stopTracking()
    requestShiftOff()
    target = nil
    targetKind = nil
    updateStatus()
end

-- NPC SEARCH

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

-- TARGET LIST

local function refreshList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    playersTab.BackgroundColor3 =
        currentTab == "Players"
        and PURPLE or Color3.fromRGB(45, 49, 67)

    npcsTab.BackgroundColor3 =
        currentTab == "NPCs"
        and PURPLE or Color3.fromRGB(45, 49, 67)

    local noun = currentTab == "Players" and "PLAYER" or "NPC"
    nearest.Text = "NEAREST " .. noun .. " (ANY TEAM)"
    nearestTeam.Text = "NEAREST TEAMMATE " .. noun
    nearestEnemy.Text = "NEAREST OTHER-TEAM " .. noun

    local entries = {}

    if currentTab == "Players" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me then
                table.insert(entries, {
                    object = p,
                    kind = "Player",
                    label = p.DisplayName .. " (@" .. p.Name .. ")"
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
            list, entry.label, UDim2.new(),
            UDim2.new(1, -2, 0, 31)
        )

        if target == entry.object then
            b.BackgroundColor3 = PURPLE
        end

        b.MouseButton1Click:Connect(function()
            selectTarget(entry.object, entry.kind)
        end)
    end
end

-- TEAM DETECTION

local function teamKey(value)
    if typeof(value) == "Instance" and value:IsA("Team") then
        return value.Name:lower()
    end

    if typeof(value) == "string" then
        local cleaned = value:match("^%s*(.-)%s*$")
        if cleaned ~= "" then
            return cleaned:lower()
        end
    end

    if typeof(value) == "BrickColor" then
        local teamsService = game:GetService("Teams")
        for _, team in ipairs(teamsService:GetTeams()) do
            if team.TeamColor == value then
                return team.Name:lower()
            end
        end
    end

    return nil
end

local function npcTeam(npc)
    for _, key in ipairs({
        "Team", "TeamName", "Faction", "TeamColor"
    }) do
        local attribute = npc:GetAttribute(key)
        local result = teamKey(attribute)
        if result then return result end

        local value = npc:FindFirstChild(key)
        if value and value:IsA("ValueBase") then
            result = teamKey(value.Value)
            if result then return result end
        end
    end

    return nil
end

local function playerTeam(p)
    if p.Neutral or not p.Team then return nil end
    return p.Team.Name:lower()
end

-- NEAREST TARGETS

local function chooseNearest(filter)
    local ownRoot = getRoot(me.Character)

    if not ownRoot then
        updateStatus("Your character is not ready")
        return
    end

    local myTeam = playerTeam(me)

    if filter ~= "any" and not myTeam then
        updateStatus("You are not assigned to a team")
        return
    end

    local closest = nil
    local closestDistance = math.huge
    local kind = currentTab == "Players" and "Player" or "NPC"

    local function consider(object, root, candidateTeam)
        if not root then return end

        if filter == "same" then
            if not candidateTeam or candidateTeam ~= myTeam then
                return
            end
        elseif filter == "other" then
            if not candidateTeam or candidateTeam == myTeam then
                return
            end
        end

        local distance =
            (root.Position - ownRoot.Position).Magnitude

        if distance < closestDistance then
            closestDistance = distance
            closest = object
        end
    end

    if kind == "Player" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me then
                consider(p, getRoot(p.Character), playerTeam(p))
            end
        end
    else
        for _, npc in ipairs(getNPCs()) do
            consider(npc, getRoot(npc), npcTeam(npc))
        end
    end

    if closest then
        selectTarget(closest, kind)
    else
        updateStatus("No matching loaded target found")
    end
end

playersTab.MouseButton1Click:Connect(function()
    currentTab = "Players"
    refreshList()
end)

npcsTab.MouseButton1Click:Connect(function()
    currentTab = "NPCs"
    refreshList()
end)

nearest.MouseButton1Click:Connect(function()
    chooseNearest("any")
end)

nearestTeam.MouseButton1Click:Connect(function()
    chooseNearest("same")
end)

nearestEnemy.MouseButton1Click:Connect(function()
    chooseNearest("other")
end)

unselect.MouseButton1Click:Connect(function()
    clearTarget()
    refreshList()
end)

-- PLAYER-ONLY ESP

local function removeESP(p)
    local objects = espObjects[p]
    if not objects then return end

    for _, obj in ipairs(objects) do
        if obj then obj:Destroy() end
    end

    espObjects[p] = nil
end

local function createESP(p)
    if not espOn or p == me then return end

    removeESP(p)

    local char = p.Character
    local head = char and char:FindFirstChild("Head")
    if not head then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = char
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = CYAN
    highlight.OutlineColor = CYAN
    highlight.FillTransparency = 0.75
    highlight.Parent = char

    local nameGui = Instance.new("BillboardGui")
    nameGui.Adornee = head
    nameGui.Size = UDim2.fromOffset(155, 23)
    nameGui.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0)
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
    round(dot, 9)

    espObjects[p] = {highlight, nameGui, dotGui}
end

local function setESP(enabled)
    espOn = enabled

    espButton.Text =
        enabled and "PLAYER ESP: ON [E]"
        or "PLAYER ESP: OFF [E]"

    espButton.BackgroundColor3 =
        enabled and PURPLE or Color3.fromRGB(45, 49, 67)

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

espButton.MouseButton1Click:Connect(function()
    setESP(not espOn)
end)

-- HOLD TAB: TEMPORARILY FREE MOUSE

local function startFreeMode()
    if holdingTab then return end
    holdingTab = true

    savedCamera = {
        mode = me.CameraMode,
        min = me.CameraMinZoomDistance,
        max = me.CameraMaxZoomDistance,
        mouse = UIS.MouseBehavior,
        icon = UIS.MouseIconEnabled
    }

    me.CameraMode = Enum.CameraMode.Classic
    me.CameraMaxZoomDistance =
        math.max(me.CameraMaxZoomDistance, 8)
    me.CameraMinZoomDistance = 8

    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
end

local function endFreeMode()
    if not holdingTab then return end
    holdingTab = false

    local saved = savedCamera
    savedCamera = nil
    if not saved then return end

    me.CameraMinZoomDistance =
        math.min(saved.min, me.CameraMaxZoomDistance)

    me.CameraMaxZoomDistance =
        math.max(saved.max, saved.min)

    me.CameraMinZoomDistance = saved.min
    me.CameraMode = saved.mode

    UIS.MouseBehavior = saved.mouse
    UIS.MouseIconEnabled = saved.icon
end

CAS:BindActionAtPriority(
    "ProjectNoxTab",
    function(_, state)
        if state == Enum.UserInputState.Begin then
            if UIS:GetFocusedTextBox() then
                return Enum.ContextActionResult.Pass
            end
            startFreeMode()
        elseif state == Enum.UserInputState.End
            or state == Enum.UserInputState.Cancel then
            endFreeMode()
        end

        return Enum.ContextActionResult.Sink
    end,
    false,
    3000,
    Enum.KeyCode.Tab
)

RunService:BindToRenderStep(
    "ProjectNoxFreeCursor",
    Enum.RenderPriority.Last.Value,
    function()
        if holdingTab then
            UIS.MouseBehavior = Enum.MouseBehavior.Default
            UIS.MouseIconEnabled = true
        end
    end
)

UIS.WindowFocusReleased:Connect(endFreeMode)

-- KEYBOARD CONTROLS

UIS.InputBegan:Connect(function(input, processed)
    if UIS:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.LeftShift then
        -- Do not consume Shift. Existing Shift Lock
        -- continues to handle its own input.

        if menu.Visible then return end

        if tracking then
            stopTracking()
        elseif target and getRoot(targetModel()) then
            tracking = true

            local camera = workspace.CurrentCamera
            lastRight = camera and camera.CFrame.RightVector
                or Vector3.xAxis

            updateStatus()
        end

        return
    end

    if processed then return end

    if input.KeyCode == Enum.KeyCode.U then
        if not menu.Visible then
            stopTracking()
            refreshList()
        end

        menu.Visible = not menu.Visible

    elseif input.KeyCode == Enum.KeyCode.E then
        setESP(not espOn)
    end
end)

-- STABLE CAMERA AIM
-- Keeps the camera at its original position.
-- Supports vertical aiming without sudden flips.

RunService:BindToRenderStep(
    "ProjectNoxAim",
    Enum.RenderPriority.Camera.Value + 2,
    function()
        if not tracking or holdingTab then return end

        local camera = workspace.CurrentCamera
        local root = getRoot(targetModel())

        if not camera or not root then return end

        local pos = camera.CFrame.Position
        local aim = root.Position
            + Vector3.new(0, AIM_HEIGHT, 0)

        local difference = aim - pos

        if difference.Magnitude < 0.05 then
            return
        end

        local forward = difference.Unit

        local right = lastRight
            or camera.CFrame.RightVector

        right = right - forward * right:Dot(forward)

        if right.Magnitude < 0.001 then
            right = camera.CFrame.RightVector
            right = right - forward * right:Dot(forward)
        end

        if right.Magnitude < 0.001 then
            local reference =
                math.abs(forward.Y) < 0.99
                and Vector3.yAxis or Vector3.xAxis

            right = forward:Cross(reference)
        end

        right = right.Unit

        local up = right:Cross(forward).Unit

        camera.CFrame = CFrame.fromMatrix(
            pos,
            right,
            up,
            -forward
        )

        lastRight = right

        -- Camera.Focus is not modified.
        -- No custom Shift Lock is created.
    end
)

-- ESP DISTANCE UPDATES

local espTimer = 0

RunService.Heartbeat:Connect(function(dt)
    espTimer += dt

    if espTimer < 0.15 then return end
    espTimer = 0

    if not espOn then return end

    local ownRoot = getRoot(me.Character)
    if not ownRoot then return end

    for p, objects in pairs(espObjects) do
        local root = getRoot(p.Character)
        local visible = root ~= nil

        local far = visible and
            (root.Position - ownRoot.Position).Magnitude
            > DOT_DISTANCE

        objects[1].Enabled = visible and not far
        objects[2].Enabled = visible
        objects[3].Enabled = visible and far
    end
end)

-- LIVE PLAYER UPDATES

local function registerPlayer(p)
    if p == me then return end

    playerConnections[p] = {
        p.CharacterAdded:Connect(function(char)
            char:WaitForChild("Head", 10)
            if espOn then createESP(p) end
        end),

        p.CharacterRemoving:Connect(function()
            removeESP(p)
        end)
    }

    if espOn then createESP(p) end
end

for _, p in ipairs(Players:GetPlayers()) do
    registerPlayer(p)
end

Players.PlayerAdded:Connect(function(p)
    registerPlayer(p)

    if menu.Visible and currentTab == "Players" then
        refreshList()
    end
end)

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)

    if playerConnections[p] then
        for _, connection in ipairs(playerConnections[p]) do
            connection:Disconnect()
        end
        playerConnections[p] = nil
    end

    if targetKind == "Player" and target == p then
        clearTarget()
    end

    if menu.Visible and currentTab == "Players" then
        refreshList()
    end
end)

-- LIVE NPC UPDATES

local refreshQueued = false

local function scheduleNPCRefresh()
    if refreshQueued then return end
    refreshQueued = true

    task.defer(function()
        refreshQueued = false

        if menu.Visible and currentTab == "NPCs" then
            refreshList()
        end
    end)
end

workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Humanoid") then
        scheduleNPCRefresh()
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Humanoid") then
        if targetKind == "NPC"
            and target == obj.Parent then
            clearTarget()
        end

        scheduleNPCRefresh()
    end
end)

me.CharacterAdded:Connect(function()
    endFreeMode()
    stopTracking()
end)

refreshList()
updateStatus()

-- ANIMATED STARTUP NOTIFICATION

local notice = Instance.new("Frame")
notice.Size = UDim2.fromOffset(260, 56)
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, -70)
notice.BackgroundColor3 = Color3.fromRGB(29, 34, 51)
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

local barTrack = Instance.new("Frame")
barTrack.Size = UDim2.new(1, 0, 0, 4)
barTrack.Position = UDim2.new(0, 0, 1, -4)
barTrack.BackgroundColor3 = Color3.fromRGB(62, 64, 78)
barTrack.BorderSizePixel = 0
barTrack.Parent = notice

local progress = Instance.new("Frame")
progress.Size = UDim2.fromScale(1, 1)
progress.BackgroundColor3 = PURPLE
progress.BorderSizePixel = 0
progress.Parent = barTrack

task.spawn(function()
    local appear = TweenService:Create(
        notice,
        TweenInfo.new(0.5, Enum.EasingStyle.Quint),
        {Position = UDim2.new(0.5, 0, 0, 22)}
    )

    appear:Play()
    appear.Completed:Wait()

    local drain = TweenService:Create(
        progress,
        TweenInfo.new(5, Enum.EasingStyle.Linear),
        {Size = UDim2.fromScale(0, 1)}
    )

    drain:Play()
    drain.Completed:Wait()

    local disappear = TweenService:Create(
        notice,
        TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.In
        ),
        {Position = UDim2.new(0.5, 0, 0, -70)}
    )

    disappear:Play()
    disappear.Completed:Wait()

    notice:Destroy()
end)
