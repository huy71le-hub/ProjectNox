
-- ========================================
-- PROJECT NOX - NO-FLIP CAMERA TRACKING
-- ========================================

local lastYaw = nil

RunService:BindToRenderStep(
    "ProjectNoxStableCamera",
    Enum.RenderPriority.Camera.Value + 2,
    function()
        if not tracking or holdingTab then
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then return end

        local root = getRoot(getTargetModel())
        if not root then return end

        -- Preserve the game's camera position
        local cameraPos = camera.CFrame.Position

        -- Only use the target's position,
        -- never its ragdoll rotation.
        local targetPos =
            root.Position + Vector3.new(0, AIM_HEIGHT, 0)

        local direction = targetPos - cameraPos

        if direction.Magnitude < 0.05 then
            return
        end

        -- HORIZONTAL DIRECTION
        local dx = direction.X
        local dz = direction.Z

        local horizontalDistance =
            math.sqrt(dx * dx + dz * dz)

        local yaw

        if horizontalDistance > 0.2 then
            -- Turn toward target horizontally.
            -- Never flip the camera to reach it.
            yaw = math.atan2(-dx, -dz)
            lastYaw = yaw
        else
            -- Directly above or below target:
            -- preserve the previous heading.
            if lastYaw == nil then
                local look = camera.CFrame.LookVector

                lastYaw = math.atan2(
                    -look.X,
                    -look.Z
                )
            end

            yaw = lastYaw
        end

        -- VERTICAL DIRECTION
        local pitch = math.atan2(
            direction.Y,
            horizontalDistance
        )

        -- Avoid the exact vertical singularity.
        -- This keeps the camera upright.
        pitch = math.clamp(
            pitch,
            math.rad(-89.5),
            math.rad(89.5)
        )

        -- Rebuild camera using yaw + pitch only.
        -- NO roll rotation is ever applied.
        local rotation =
            CFrame.Angles(0, yaw, 0)
            * CFrame.Angles(pitch, 0, 0)

        camera.CFrame =
            CFrame.new(cameraPos) * rotation

        -- Existing Shift Lock is untouched.
        -- Camera.Focus is untouched.
        -- Camera position is unchanged.
    end
)
