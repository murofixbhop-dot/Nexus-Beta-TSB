--// TSB Phantasm Dodge v6
--// Фикс: камера не инвертирована, сенса как дефолт, репликация через несколько методов

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local GameSettings = UserSettings():GetService("UserGameSettings")

local DODGE_ACTIVE = false
local HEIGHT = 999999999
local SPEED = 26
local Connections = {}
local CloneModel = nil

local ClonePos = Vector3.zero
local CloneRot = 0
local CloneVelY = 0 -- вертикальная скорость клона
local CloneGrounded = false
local GRAVITY = 196.2 -- стандартная гравитация Roblox
local JUMP_POWER = 50
local SavedWalkSpeed = 26
local DashActive = false

-- Камера
local CamYaw = 0
local CamPitch = 0.3
local CamDist = 12
local RMBHeld = false
local ShiftLock = false
local SavedCFrame = nil
local FocusYOffset = 2 -- реальный оффсет фокуса камеры

-- Сохранённые объекты для очистки
local BodyObjs = {}
local SavedOffsets = {} -- оффсеты частей тела ДО удаления RootJoint
local SavedAccOffsets = {} -- оффсеты аксессуаров
local RootJointData = nil

-- ===================== GUI =====================
local gui = Instance.new("ScreenGui")
gui.Name = "PhantasmV6"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 200, 0, 110)
frame.Position = UDim2.new(0, 15, 0.5, -55)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", frame).Color = Color3.fromRGB(110, 60, 230)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 24)
title.BackgroundTransparency = 1
title.Text = "⚡ Nexus BETA v6"
title.TextColor3 = Color3.fromRGB(170, 120, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold

local statusLbl = Instance.new("TextLabel", frame)
statusLbl.Size = UDim2.new(1, -14, 0, 16)
statusLbl.Position = UDim2.new(0, 7, 0, 26)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "ВЫКЛ"
statusLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local btn = Instance.new("TextButton", frame)
btn.Size = UDim2.new(1, -14, 0, 34)
btn.Position = UDim2.new(0, 7, 0, 46)
btn.BackgroundColor3 = Color3.fromRGB(110, 60, 230)
btn.Text = "ВКЛЮЧИТЬ [V]"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.TextSize = 13
btn.Font = Enum.Font.GothamBold
btn.BorderSizePixel = 0
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local hint = Instance.new("TextLabel", frame)
hint.Size = UDim2.new(1, -14, 0, 14)
hint.Position = UDim2.new(0, 7, 0, 86)
hint.BackgroundTransparency = 1
hint.Text = "ПКМ — камера | Скролл — зум"
hint.TextColor3 = Color3.fromRGB(70, 70, 90)
hint.TextSize = 10
hint.Font = Enum.Font.Gotham
hint.TextXAlignment = Enum.TextXAlignment.Left

-- ===================== УТИЛИТЫ =====================
local function clearConn()
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
end

local function cleanBodyObjs()
    for _, obj in ipairs(BodyObjs) do
        pcall(function() obj:Destroy() end)
    end
    BodyObjs = {}
end

local function getChar() return LP.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ===================== КЛОН =====================
local function buildClone()
    local char = getChar()
    if not char then return nil end

    local m = Instance.new("Model")
    m.Name = "Ghost"

    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("BasePart") then
            local p = obj:Clone()
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
            p.CastShadow = false
            -- Полупрозрачный (кроме HRP который и так невидим)
            if p.Name ~= "HumanoidRootPart" then
                p.Transparency = math.max(p.Transparency, 0.5)
            end
            for _, ch in ipairs(p:GetChildren()) do
                if ch:IsA("JointInstance") then ch:Destroy() end
            end
            p.Parent = m
        elseif obj:IsA("Accessory") then
            local a = obj:Clone()
            for _, ch in ipairs(a:GetDescendants()) do
                if ch:IsA("BasePart") then
                    ch.Anchored = true
                    ch.CanCollide = false
                    ch.CanQuery = false
                    ch.CanTouch = false
                    ch.Transparency = math.max(ch.Transparency, 0.5)
                end
                if ch:IsA("JointInstance") then ch:Destroy() end
            end
            a.Parent = m
        elseif obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("BodyColors") or obj:IsA("ShirtGraphic") or obj:IsA("CharacterMesh") then
            obj:Clone().Parent = m
        end
    end

    local head = m:FindFirstChild("Head")
    if head then
        local origHead = char:FindFirstChild("Head")
        if origHead then
            for _, d in ipairs(origHead:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then
                    local dc = d:Clone()
                    dc.Transparency = math.max(dc.Transparency, 0.5)
                    dc.Parent = head
                end
            end
        end
    end

    if m:FindFirstChild("HumanoidRootPart") then
        m.PrimaryPart = m.HumanoidRootPart
        m.PrimaryPart.Transparency = 1
    end

    -- Humanoid нужен чтобы Shirt/Pants/BodyColors рендерились
    local cloneHum = Instance.new("Humanoid")
    cloneHum.MaxHealth = 100
    cloneHum.Health = 100
    cloneHum.Parent = m

    -- Убираем хелсбар
    local nameTag = m:FindFirstChild("Head")
    if nameTag then
        -- скрываем имя/хелсбар над клоном
        cloneHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        cloneHum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        cloneHum.NameDisplayDistance = 0
        cloneHum.HealthDisplayDistance = 0
    end

    m.Parent = Camera
    return m
end

local function syncPose(clone, char, rootCF)
    -- Ищем Torso/UpperTorso как референс для живых анимаций
    -- (RootJoint удалён, но Motor6D между Torso и конечностями остались = анимации играют)
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")

    if torso then
        local torsoOffset = SavedOffsets[torso.Name]
        if torsoOffset then
            -- Живые анимации: читаем позы частей относительно Torso
            local torsoCF = torso.CFrame

            for _, cp in ipairs(clone:GetChildren()) do
                if cp:IsA("BasePart") and cp.Name ~= "HumanoidRootPart" then
                    local origPart = char:FindFirstChild(cp.Name)
                    if origPart and origPart:IsA("BasePart") then
                        local liveOffset = torsoCF:ToObjectSpace(origPart.CFrame)
                        cp.CFrame = rootCF * torsoOffset * liveOffset
                    end
                elseif cp:IsA("Accessory") then
                    local origAcc = char:FindFirstChild(cp.Name)
                    if origAcc then
                        local oh = origAcc:FindFirstChild("Handle")
                        local ch = cp:FindFirstChild("Handle")
                        if oh and ch then
                            local liveOffset = torsoCF:ToObjectSpace(oh.CFrame)
                            ch.CFrame = rootCF * torsoOffset * liveOffset
                        end
                    end
                end
            end
            return
        end
    end

    -- Фоллбэк: сохранённые оффсеты (статичная поза)
    for partName, offset in pairs(SavedOffsets) do
        local cp = clone:FindFirstChild(partName)
        if cp and cp:IsA("BasePart") then
            cp.CFrame = rootCF * offset
        end
    end
    for accName, offset in pairs(SavedAccOffsets) do
        local ca = clone:FindFirstChild(accName)
        if ca then
            local ch = ca:FindFirstChild("Handle")
            if ch then
                ch.CFrame = rootCF * offset
            end
        end
    end
end

-- ===================== АКТИВАЦИЯ =====================
local function activate()
    if DODGE_ACTIVE then return end
    local hrp = getHRP()
    local hum = getHum()
    if not hrp or not hum then return end

    DODGE_ACTIVE = true
    SavedCFrame = hrp.CFrame
    ClonePos = hrp.CFrame.Position
    CloneRot = select(2, hrp.CFrame:ToEulerAnglesYXZ())
    CloneVelY = 0
    CloneGrounded = true

    -- Камера: берём точные углы из текущей позиции камеры
    -- Фокус: X/Z от клона (= HRP), Y от Camera.Focus (реальная высота фокуса Roblox)
    local camPos = Camera.CFrame.Position
    local focusY = Camera.Focus and Camera.Focus.Position.Y or (ClonePos.Y + 2)
    FocusYOffset = focusY - ClonePos.Y
    local focusPos = Vector3.new(ClonePos.X, focusY, ClonePos.Z)
    local diff = camPos - focusPos
    local horizDist = math.sqrt(diff.X * diff.X + diff.Z * diff.Z)
    CamYaw = math.atan2(diff.X, diff.Z)
    CamPitch = math.atan2(diff.Y, horizDist)
    CamDist = diff.Magnitude
    CamDist = math.clamp(CamDist, 4, 30)

    -- Подхватываем текущее состояние shift lock / RMB
    if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
        ShiftLock = true
    end
    RMBHeld = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

    -- Клон
    CloneModel = buildClone()

    -- === Сохраняем оффсеты СЕЙЧАС (пока RootJoint ещё есть и всё на месте) ===
    SavedOffsets = {}
    SavedAccOffsets = {}
    local char = getChar()
    if char and hrp then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("BasePart") and obj ~= hrp then
                SavedOffsets[obj.Name] = hrp.CFrame:ToObjectSpace(obj.CFrame)
            elseif obj:IsA("Accessory") then
                local handle = obj:FindFirstChild("Handle")
                if handle then
                    SavedAccOffsets[obj.Name] = hrp.CFrame:ToObjectSpace(handle.CFrame)
                end
            end
        end
    end

    -- === РЕПЛИКАЦИЯ: множественные методы ===

    -- 1) Humanoid полностью отключаем
    SavedWalkSpeed = hum.WalkSpeed -- сохраняем для клона
    hum.PlatformStand = true
    hum.AutoRotate = false
    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.JumpHeight = 0

    -- 2) Удаляем RootJoint чтобы humanoid не мог двигать HRP
    --    (сохраняем данные для восстановления)
    local rootJoint = hrp:FindFirstChild("RootJoint")
    RootJointData = nil
    if rootJoint then
        RootJointData = {
            C0 = rootJoint.C0,
            C1 = rootJoint.C1,
            Part0 = rootJoint.Part0,
            Part1 = rootJoint.Part1,
            ClassName = rootJoint.ClassName,
            Parent = rootJoint.Parent
        }
        rootJoint:Destroy()
    end

    -- 3) BodyVelocity вверх (мгновенная скорость, реплицируется)
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 9999, 0)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.P = 1e5
    bv.Parent = hrp
    BodyObjs[#BodyObjs + 1] = bv

    -- Ждём чуть чтобы перс начал лететь
    task.delay(0.15, function()
        if not DODGE_ACTIVE then return end
        if bv and bv.Parent then
            bv.Velocity = Vector3.zero
        end
    end)

    -- Камера ручная
    Camera.CameraType = Enum.CameraType.Scriptable

    -- Если шифт лок или ПКМ уже зажаты — ставим нужный MouseBehavior
    if ShiftLock then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
    elseif RMBHeld then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    end

    -- === Мышь для камеры ===
    local function getSens()
        -- Сенса x3
        return 0.018 * GameSettings.MouseSensitivity
    end

    Connections[#Connections + 1] = UIS.InputChanged:Connect(function(input)
        if not DODGE_ACTIVE then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if RMBHeld or ShiftLock then
                local sens = getSens()
                CamYaw = CamYaw - input.Delta.X * sens
                CamPitch = math.clamp(CamPitch + input.Delta.Y * sens, -1.2, 1.2)
            end
        end
    end)

    Connections[#Connections + 1] = UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            RMBHeld = true
            UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end
    end)

    Connections[#Connections + 1] = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            RMBHeld = false
            if not ShiftLock then
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            end
        end
    end)

    Connections[#Connections + 1] = UIS.InputChanged:Connect(function(input)
        if not DODGE_ACTIVE then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            CamDist = math.clamp(CamDist - input.Position.Z * 2, 4, 30)
        end
    end)

    -- Shift Lock тоггл (без gpe — игра может поглощать Shift)
    Connections[#Connections + 1] = UIS.InputBegan:Connect(function(input)
        if not DODGE_ACTIVE then return end
        if input.KeyCode == Enum.KeyCode.LeftShift then
            ShiftLock = not ShiftLock
            if ShiftLock then
                UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
            else
                if not RMBHeld then
                    UIS.MouseBehavior = Enum.MouseBehavior.Default
                end
            end
        end
    end)

    -- === ДЭШИ: Q = дэш клавиша, отслеживаем нажатие + анимацию ===
    local qPressedTime = 0

    Connections[#Connections + 1] = UIS.InputBegan:Connect(function(input)
        if not DODGE_ACTIVE then return end
        if input.KeyCode == Enum.KeyCode.Q then
            qPressedTime = tick()
        end
    end)

    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        Connections[#Connections + 1] = animator.AnimationPlayed:Connect(function(track)
            if not DODGE_ACTIVE then return end
            if DashActive then return end

            -- Дэш: Q нажата недавно (в пределах 0.3 сек) + анимация началась
            local timeSinceQ = tick() - qPressedTime
            if timeSinceQ > 0.3 then return end

            DashActive = true

            local camCF = Camera.CFrame
            local dashFwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            if dashFwd.Magnitude > 0.001 then dashFwd = dashFwd.Unit else dashFwd = Vector3.new(0, 0, -1) end
            local dashRgt = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
            if dashRgt.Magnitude > 0.001 then dashRgt = dashRgt.Unit else dashRgt = Vector3.new(1, 0, 0) end

            local wDown = UIS:IsKeyDown(Enum.KeyCode.W)
            local sDown = UIS:IsKeyDown(Enum.KeyCode.S)
            local aDown = UIS:IsKeyDown(Enum.KeyCode.A)
            local dDown = UIS:IsKeyDown(Enum.KeyCode.D)

            local dashDir = dashFwd
            local dashDist = 100

            if sDown and not wDown then
                dashDir = -dashFwd
                dashDist = 120
            elseif aDown and not dDown then
                dashDir = -dashRgt
                dashDist = 50
            elseif dDown and not aDown then
                dashDir = dashRgt
                dashDist = 50
            end

            if dashDir.Magnitude > 0.01 then
                dashDir = dashDir.Unit
                ClonePos = ClonePos + dashDir * dashDist
            end

            task.delay(track.Length > 0 and track.Length or 0.4, function()
                DashActive = false
            end)
        end)
    end

    -- === STEPPED: перед физикой - CFrame наверх ===
    Connections[#Connections + 1] = RunService.Stepped:Connect(function()
        if not DODGE_ACTIVE then return end
        local myHRP = getHRP()
        local myHum = getHum()
        if not myHRP then return end

        myHRP.CFrame = CFrame.new(SavedCFrame.Position.X, HEIGHT, SavedCFrame.Position.Z)
        myHRP.AssemblyLinearVelocity = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero

        if myHum then
            myHum.PlatformStand = true
            myHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)

    -- === HEARTBEAT: после физики - повтор ===
    Connections[#Connections + 1] = RunService.Heartbeat:Connect(function()
        if not DODGE_ACTIVE then return end
        local myHRP = getHRP()
        if not myHRP then return end

        myHRP.CFrame = CFrame.new(SavedCFrame.Position.X, HEIGHT, SavedCFrame.Position.Z)
        myHRP.AssemblyLinearVelocity = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero
    end)

    -- === RENDERSTEPPED: визуал ===
    Connections[#Connections + 1] = RunService.RenderStepped:Connect(function(dt)
        if not DODGE_ACTIVE then return end
        local char = getChar()
        if not char then return end

        -- Скрыть оригинал локально
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 1
            end
        end

        -- WASD от камеры
        local camCF = Camera.CFrame
        local fwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
        if fwd.Magnitude > 0.001 then fwd = fwd.Unit else fwd = Vector3.new(0, 0, -1) end
        local rgt = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
        if rgt.Magnitude > 0.001 then rgt = rgt.Unit else rgt = Vector3.new(1, 0, 0) end

        local dir = Vector3.zero
        local wPressed = UIS:IsKeyDown(Enum.KeyCode.W)
        local sPressed = UIS:IsKeyDown(Enum.KeyCode.S)
        local aPressed = UIS:IsKeyDown(Enum.KeyCode.A)
        local dPressed = UIS:IsKeyDown(Enum.KeyCode.D)

        if wPressed then dir = dir + fwd end
        if sPressed then dir = dir - fwd end
        if dPressed then dir = dir + rgt end
        if aPressed then dir = dir - rgt end

        -- Скорость: W = 30, остальные = 16
        local currentSpeed = 16
        if wPressed and not sPressed and not aPressed and not dPressed then
            currentSpeed = 30
        elseif wPressed then
            currentSpeed = 30 -- W + любая другая тоже 30
        end

        if dir.Magnitude > 0.01 and not DashActive then
            dir = dir.Unit
            ClonePos = ClonePos + Vector3.new(dir.X * currentSpeed * dt, 0, dir.Z * currentSpeed * dt)
            if not ShiftLock then
                CloneRot = math.atan2(-dir.X, -dir.Z)
            end
        end

        -- Гравитация
        CloneVelY = CloneVelY - GRAVITY * dt

        -- Прыжок
        if CloneGrounded and UIS:IsKeyDown(Enum.KeyCode.Space) then
            CloneVelY = JUMP_POWER
            CloneGrounded = false
        end

        -- Применяем вертикальную скорость
        ClonePos = ClonePos + Vector3.new(0, CloneVelY * dt, 0)

        -- Рейкаст вниз для поиска земли
        local rayOrigin = ClonePos + Vector3.new(0, 2, 0)
        local rayDir = Vector3.new(0, -100, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local filterList = {Camera}
        local myChar = getChar()
        if myChar then table.insert(filterList, myChar) end
        rayParams.FilterDescendantsInstances = filterList

        local rayResult = Workspace:Raycast(rayOrigin, rayDir, rayParams)
        if rayResult then
            local groundY = rayResult.Position.Y + 3 -- HRP ~3 стада над землёй
            if ClonePos.Y <= groundY then
                ClonePos = Vector3.new(ClonePos.X, groundY, ClonePos.Z)
                CloneVelY = 0
                CloneGrounded = true
            else
                CloneGrounded = false
            end
        end

        -- В shift lock клон всегда смотрит куда камера
        if ShiftLock then
            CloneRot = CamYaw
        end

        -- Клон
        local rootCF = CFrame.new(ClonePos) * CFrame.Angles(0, CloneRot, 0)
        if CloneModel and CloneModel.PrimaryPart then
            CloneModel.PrimaryPart.CFrame = rootCF
            syncPose(CloneModel, char, rootCF)
        end

        -- Камера: орбита вокруг клона
        local focus = ClonePos + Vector3.new(0, FocusYOffset, 0)
        local rot = CFrame.Angles(0, CamYaw, 0) * CFrame.Angles(-CamPitch, 0, 0)
        local pos = focus + rot:VectorToWorldSpace(Vector3.new(0, 0, CamDist))

        -- Shift lock: сдвиг камеры вправо
        if ShiftLock then
            UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
            local rightShift = CFrame.new(pos, focus).RightVector * 2
            Camera.CFrame = CFrame.new(pos + rightShift, focus + rightShift)
        else
            Camera.CFrame = CFrame.new(pos, focus)
        end
    end)

    -- GUI
    statusLbl.Text = "ВКЛ ✅"
    statusLbl.TextColor3 = Color3.fromRGB(80, 255, 80)
    btn.Text = "ВЫКЛЮЧИТЬ [V]"
    btn.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
end

-- ===================== ДЕАКТИВАЦИЯ =====================
local function deactivate()
    if not DODGE_ACTIVE then return end
    DODGE_ACTIVE = false

    DashActive = false

    -- НЕ сбрасываем ShiftLock/RMBHeld — сохраняем состояние
    -- Сначала останавливаем ВСЁ
    clearConn()
    cleanBodyObjs()

    local hrp = getHRP()
    local hum = getHum()
    local char = getChar()

    -- Перемещаем ВСЕ части персонажа на позицию клона ДО восстановления RootJoint
    -- (части тела отсоединены и разбросаны — нужно собрать)
    local targetCF = CFrame.new(ClonePos) * CFrame.Angles(0, CloneRot, 0)

    if char and hrp then
        -- Сначала двигаем HRP
        hrp.CFrame = targetCF
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        -- Двигаем все отсоединённые части тела используя сохранённые оффсеты
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("BasePart") and obj ~= hrp then
                local offset = SavedOffsets[obj.Name]
                if offset then
                    obj.CFrame = targetCF * offset
                end
            elseif obj:IsA("Accessory") then
                local handle = obj:FindFirstChild("Handle")
                local offset = SavedAccOffsets[obj.Name]
                if handle and offset then
                    handle.CFrame = targetCF * offset
                end
            end
        end
    end

    -- ТЕПЕРЬ восстанавливаем RootJoint (части уже на месте)
    if RootJointData and hrp then
        local joint = Instance.new("Motor6D")
        joint.Name = "RootJoint"
        joint.C0 = RootJointData.C0
        joint.C1 = RootJointData.C1
        joint.Part0 = RootJointData.Part0
        joint.Part1 = RootJointData.Part1
        joint.Parent = hrp
    end
    RootJointData = nil

    -- Повторно ставим CFrame после RootJoint (на всякий)
    if hrp then
        hrp.CFrame = targetCF
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    if hum then
        hum.PlatformStand = false
        hum.AutoRotate = true
        hum.WalkSpeed = SavedWalkSpeed
        hum.JumpPower = 50
        hum.JumpHeight = 7.2
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end

    -- Прозрачность
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 0
            end
        end
    end

    if CloneModel then CloneModel:Destroy() CloneModel = nil end

    Camera.CameraType = Enum.CameraType.Custom
    if hum then Camera.CameraSubject = hum end

    statusLbl.Text = "ВЫКЛ"
    statusLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
    btn.Text = "ВКЛЮЧИТЬ [V]"
    btn.BackgroundColor3 = Color3.fromRGB(110, 60, 230)
end

-- ===================== ТОГГЛ =====================
local function toggle()
    if DODGE_ACTIVE then deactivate() else activate() end
end

btn.MouseButton1Click:Connect(toggle)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.V then toggle() end
end)

LP.CharacterAdded:Connect(function()
    if DODGE_ACTIVE then
        DODGE_ACTIVE = false
        clearConn()
        cleanBodyObjs()
        RootJointData = nil
        SavedOffsets = {}
        SavedAccOffsets = {}
        RMBHeld = false
        ShiftLock = false
        DashActive = false
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        if CloneModel then CloneModel:Destroy() CloneModel = nil end
        Camera.CameraType = Enum.CameraType.Custom
        statusLbl.Text = "ВЫКЛ"
        statusLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
        btn.Text = "ВКЛЮЧИТЬ [V]"
        btn.BackgroundColor3 = Color3.fromRGB(110, 60, 230)
    end
end)

-- ===================== АВТОДОДЖ: только Normal Punch =====================
local autoDodgeDebounce = false

local function isOwnSkill(obj)
    -- Проверяем по иерархии: если в предках есть наш персонаж или наше имя
    local char = getChar()
    if not char then return false end
    local myName = LP.Name
    local myDisplayName = LP.DisplayName

    local p = obj
    while p and p ~= Workspace do
        if p == char then return true end
        if p == Camera then return true end
        -- Многие скиллы в TSB создаются в папке с именем игрока
        if p.Name == myName or p.Name == myDisplayName then return true end
        -- Проверяем атрибуты владельца
        local owner = p:GetAttribute("Owner") or p:GetAttribute("owner") or p:GetAttribute("Player")
        if owner == myName or owner == myDisplayName then return true end
        p = p.Parent
    end

    -- Проверяем имя самого объекта на наше имя
    local objName = obj.Name
    if objName:find(myName) or objName:find(myDisplayName) then return true end

    return false
end

Workspace.DescendantAdded:Connect(function(obj)
    if DODGE_ACTIVE then return end
    if autoDodgeDebounce then return end

    task.defer(function()
        if not obj or not obj.Parent then return end

        -- Ищем "Normal Punch"
        local name = obj.Name
        local parentName = obj.Parent and obj.Parent.Name or ""

        local isNormalPunch = false
        if name:find("Normal Punch") or name:find("NormalPunch") or name:find("Normal_Punch") then
            isNormalPunch = true
        elseif parentName:find("Normal Punch") or parentName:find("NormalPunch") or parentName:find("Normal_Punch") then
            isNormalPunch = true
        end

        if not isNormalPunch then return end

        -- Проверяем что это НЕ наш скилл
        if isOwnSkill(obj) then return end

        -- Проверяем радиус 10 стадов
        local char = getChar()
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Находим позицию объекта (может быть Part, Model, или что угодно)
        local objPos = nil
        if obj:IsA("BasePart") then
            objPos = obj.Position
        elseif obj:IsA("Model") and obj.PrimaryPart then
            objPos = obj.PrimaryPart.Position
        else
            -- Ищем любой BasePart внутри
            local found = obj:FindFirstChildWhichIsA("BasePart", true)
            if found then objPos = found.Position end
        end

        if not objPos then return end
        if (objPos - hrp.Position).Magnitude > 10 then return end

        autoDodgeDebounce = true
        activate()
        statusLbl.Text = "АВТО ⚡"
        statusLbl.TextColor3 = Color3.fromRGB(255, 200, 50)

        -- Ждём 1 сек (длительность урона Normal Punch)
        local elapsed = 0
        while elapsed < 1.0 and DODGE_ACTIVE do
            task.wait(0.1)
            elapsed = elapsed + 0.1
        end

        if DODGE_ACTIVE then
            deactivate()
        end
        task.wait(0.3)
        autoDodgeDebounce = false
    end)
end)

print("[Phantasm v6] V=вкл/выкл | ПКМ=камера | Скролл=зум | Авто: Normal Punch")

-- ===================== АНТИВОИД =====================
-- Убираем воид полностью
Workspace.FallenPartsDestroyHeight = -1e9

-- Платформа на -1000 стадов которая следует за игроком (X/Z)
local VoidPlatform = Instance.new("Part")
VoidPlatform.Name = "AntiVoidPlatform"
VoidPlatform.Size = Vector3.new(500, 5, 500)
VoidPlatform.Position = Vector3.new(0, -1000, 0)
VoidPlatform.Anchored = true
VoidPlatform.CanCollide = true
VoidPlatform.Transparency = 1
VoidPlatform.CastShadow = false
VoidPlatform.Material = Enum.Material.SmoothPlastic
VoidPlatform.Parent = Workspace

-- Следит за позицией игрока по X/Z, Y всегда -1000
RunService.Heartbeat:Connect(function()
    local hrp = getHRP()
    if hrp then
        -- Следуем за игроком по X/Z, если в уклонении — за клоном
        local posX, posZ
        if DODGE_ACTIVE then
            posX = ClonePos.X
            posZ = ClonePos.Z
        else
            posX = hrp.Position.X
            posZ = hrp.Position.Z
        end
        VoidPlatform.CFrame = CFrame.new(posX, -1000, posZ)
    end
end)