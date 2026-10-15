--=========================================================================
--   DARREN LWK A BITCH   ·   universal client-side suite
--   RightShift toggles  |  "X" hides  |  "-" collapses  |  re-execute safe
--   Pure client-side. No metatable hooks, no remote firing.
--=========================================================================

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local Lighting    = game:GetService("Lighting")
local StarterGui  = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local Workspace   = game:GetService("Workspace")

local lp = Players.LocalPlayer

--==========================================================
-- TEARDOWN
--==========================================================
local prev = getgenv().DarrenHub
if prev then
    prev.alive = false
    if prev.conns then
        for _, c in ipairs(prev.conns) do pcall(function() c:Disconnect() end) end
    end
    if prev.flyParts then
        for _, v in pairs(prev.flyParts) do pcall(function() v:Destroy() end) end
    end
    if prev.gui then pcall(function() prev.gui:Destroy() end) end
end

local hub = { alive = true, conns = {}, flyParts = {}, sync = {} }
getgenv().DarrenHub = hub
local function conn(c) table.insert(hub.conns, c); return c end

--==========================================================
-- CONFIG
--==========================================================
getgenv().DarrenCfg = getgenv().DarrenCfg or {
    Fly = false, FlySpeed = 60,
    Noclip = false, InfJump = false,
    WalkSpeed = 16, JumpPower = 50,
    AntiAFK = true, Fullbright = false,
    ESP = false, FOV = 70,

    -- anti-detection
    Humanize = true,
    SpeedVariance = 6,
    StealthTP = true,
    TPSpeed = 140,
    Obfuscate = true,
    HideOnStart = false,
    GhostMode = false,
}
local cfg = getgenv().DarrenCfg
getgenv().DarrenSlots = getgenv().DarrenSlots or {}

--==========================================================
-- FINGERPRINT OBFUSCATION
--==========================================================
local SALT = tostring(math.random(1000, 9999))
local function tag(n)
    if not cfg.Obfuscate then return n end
    return n .. "_" .. SALT
end

--==========================================================
-- HELPERS
--==========================================================
local function char() return lp.Character end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function root()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function cam() return Workspace.CurrentCamera end

local function jitter(base)
    return base * (0.82 + math.random() * 0.36)
end

--==========================================================
-- MOTION SHAPER
--==========================================================
task.spawn(function()
    local cur = cfg.WalkSpeed
    while hub.alive do
        local h = hum()
        if h then
            local target = cfg.WalkSpeed
            if cfg.Humanize then
                local t = os.clock()
                local v = cfg.SpeedVariance / 100
                target = target * (1 + math.sin(t * 1.7) * v
                                     + math.sin(t * 5.3) * v * 0.5)
            end

            local diff = target - cur
            if math.abs(diff) < 0.05 then
                cur = target
            else
                cur += diff * 0.25
            end

            if math.abs(h.WalkSpeed - cur) > 0.01 then h.WalkSpeed = cur end
            if h.JumpPower ~= cfg.JumpPower then
                h.UseJumpPower = true
                h.JumpPower = cfg.JumpPower
            end
        end
        task.wait(jitter(0.066))
    end
end)

local function applyStats()
    local h = hum()
    if not h then return end
    h.UseJumpPower = true
    h.JumpPower = cfg.JumpPower
end

--==========================================================
-- FLY
--==========================================================
local function clearFly()
    for k, v in pairs(hub.flyParts) do
        pcall(function() v:Destroy() end)
        hub.flyParts[k] = nil
    end
    local h = hum()
    if h then pcall(function() h.PlatformStand = false end) end
end

local function startFly()
    local r = root()
    if not r then return end
    clearFly()

    local ok = pcall(function()
        local att = Instance.new("Attachment")
        att.Name = tag("att")
        att.Parent = r

        local lv = Instance.new("LinearVelocity")
        lv.Attachment0 = att
        lv.MaxForce = 1e6
        lv.VectorVelocity = Vector3.zero
        lv.Parent = r

        local ao = Instance.new("AlignOrientation")
        ao.Attachment0 = att
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.MaxTorque = 1e6
        ao.Responsiveness = 200
        ao.Parent = r

        hub.flyParts = { att = att, lv = lv, ao = ao, mode = "lv" }
    end)

    if not ok then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = r
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.P = 1e4
        bg.D = 100
        bg.CFrame = r.CFrame
        bg.Parent = r
        hub.flyParts = { bv = bv, bg = bg, mode = "bv" }
    end

    local h = hum()
    if h then pcall(function() h.PlatformStand = true end) end
end

conn(RunService.RenderStepped:Connect(function()
    if not cfg.Fly then return end
    local r, c = root(), cam()
    if not r or not c then return end

    local f = hub.flyParts
    if f.mode == "lv" and (not f.lv or not f.lv.Parent) then startFly(); return end
    if f.mode == "bv" and (not f.bv or not f.bv.Parent) then startFly(); return end
    if not f.mode then return end

    local dir = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir += c.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= c.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= c.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir += c.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end

    local vel = dir.Magnitude > 0 and dir.Unit * cfg.FlySpeed or Vector3.zero
    local face = CFrame.new(r.Position, r.Position + c.CFrame.LookVector)

    if f.mode == "lv" then
        f.lv.VectorVelocity = vel
        f.ao.CFrame = face
    else
        f.bv.Velocity = vel
        f.bg.CFrame = face
    end
end))

--==========================================================
-- NOCLIP
--==========================================================
local noclipConn
local function setNoclip(on)
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local c = char()
    if not c then return end

    local function strip(inst)
        if inst:IsA("BasePart") then inst.CanCollide = false end
    end

    if on then
        for _, d in ipairs(c:GetDescendants()) do strip(d) end
        noclipConn = c.DescendantAdded:Connect(strip)
    else
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") then d.CanCollide = true end
        end
    end
end

--==========================================================
-- TELEPORT
--==========================================================
local tpToken = 0

local function tpTo(pos)
    local r = root()
    if not r then return end
    tpToken += 1
    local myToken = tpToken

    local landing = pos + Vector3.new(0, 3, 0)

    if not cfg.StealthTP then
        r.CFrame = CFrame.new(landing)
        r.Velocity = Vector3.zero
        return
    end

    local from = r.Position
    local dist = (pos - from).Magnitude
    if dist < 6 then
        r.CFrame = CFrame.new(landing)
        r.Velocity = Vector3.zero
        return
    end

    local dur = math.clamp(dist / cfg.TPSpeed, 0.06, 2.0)

    task.spawn(function()
        local elapsed = 0
        while elapsed < dur and hub.alive and myToken == tpToken do
            local rr = root()
            if not rr then return end
            local a = elapsed / dur
            a = a * a * (3 - 2 * a)
            rr.CFrame = CFrame.new(from:Lerp(pos, a) + Vector3.new(0, 3, 0))
            rr.Velocity = Vector3.zero
            elapsed += RunService.RenderStepped:Wait()
        end
        if myToken == tpToken then
            local rr = root()
            if rr then
                rr.CFrame = CFrame.new(landing)
                rr.Velocity = Vector3.zero
            end
        end
    end)
end

local function tpToPlayer(p)
    local c = p and p.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if r then tpTo(r.Position) end
end

local function tpToMouse()
    local m = lp:GetMouse()
    local c = cam()
    if not c or not m then return end
    local ray = c:ViewportPointToRay(m.X, m.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char() }
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    if hit then tpTo(hit.Position) end
end

--==========================================================
-- RESPAWN
--==========================================================
conn(lp.CharacterAdded:Connect(function(c)
    c:WaitForChild("Humanoid", 5)
    task.wait(0.3)
    applyStats()
    if cfg.Fly then startFly() end
    if cfg.Noclip then setNoclip(true) end
end))

--==========================================================
-- INFINITE JUMP
--==========================================================
conn(UIS.JumpRequest:Connect(function()
    if not cfg.InfJump then return end
    local h = hum()
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

--==========================================================
-- ANTI-AFK
--==========================================================
conn(lp.Idled:Connect(function()
    if not cfg.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    if math.random() < 0.35 then
        local h = hum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

--==========================================================
-- FULLBRIGHT
--==========================================================
local lightOrig
local function setFullbright(on)
    if on then
        if not lightOrig then
            lightOrig = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
            }
        end
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e5
        Lighting.GlobalShadows = false
    elseif lightOrig then
        for k, v in pairs(lightOrig) do Lighting[k] = v end
        lightOrig = nil
    end
end

--==========================================================
-- FOV
--==========================================================
task.spawn(function()
    while hub.alive do
        local c = cam()
        if c and c.FieldOfView ~= cfg.FOV then c.FieldOfView = cfg.FOV end
        task.wait(jitter(0.4))
    end
end)

--==========================================================
-- ESP
--==========================================================
task.spawn(function()
    while hub.alive do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local c = p.Character
                local head = c and c:FindFirstChild("Head")
                if head then
                    local existing = head:FindFirstChild(tag("esp"))
                    if cfg.ESP and not existing then
                        local b = Instance.new("BillboardGui")
                        b.Name = tag("esp")
                        b.Size = UDim2.fromOffset(190, 34)
                        b.StudsOffset = Vector3.new(0, 2.6, 0)
                        b.AlwaysOnTop = true
                        b.Adornee = head
                        b.Parent = head
                        local l = Instance.new("TextLabel")
                        l.Size = UDim2.fromScale(1, 1)
                        l.BackgroundTransparency = 1
                        l.TextScaled = true
                        l.TextStrokeTransparency = 0
                        l.TextColor3 = Color3.fromRGB(255, 90, 90)
                        l.Text = p.Name
                        l.Parent = b
                    elseif not cfg.ESP then
                        for _, d in ipairs(head:GetChildren()) do
                            if d:IsA("BillboardGui") and d.Name:match("^esp_") then
                                d:Destroy()
                            end
                        end
                    end
                end
            end
        end
        task.wait(jitter(0.4))
    end
end)

--==========================================================
-- UI
--==========================================================
local function uiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    return lp:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = tag("ui")
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = uiParent()
hub.gui = gui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(320, 452)
main.Position = UDim2.new(0, 24, 0.18, 0)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 38)
bar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
bar.BorderSizePixel = 0
bar.Parent = main
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -80, 0, 20)
title.Position = UDim2.new(0, 14, 0, 4)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(245, 245, 250)
title.Text = "Darren lwk a bitch"
title.Parent = bar

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Size = UDim2.new(1, -80, 0, 12)
sub.Position = UDim2.new(0, 14, 0, 22)
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Font = Enum.Font.Gotham
sub.TextSize = 10
sub.TextColor3 = Color3.fromRGB(140, 140, 155)
sub.Text = "universal  ·  RightShift toggles"
sub.Parent = bar

local function barBtn(text, xoff)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(24, 24)
    b.Position = UDim2.new(1, xoff, 0, 7)
    b.BackgroundColor3 = Color3.fromRGB(48, 48, 60)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.TextColor3 = Color3.fromRGB(230, 230, 240)
    b.Text = text
    b.Parent = bar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local minBtn = barBtn("-", -62)
local clsBtn = barBtn("X", -34)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 28)
tabBar.Position = UDim2.new(0, 10, 0, 44)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

local tabs = {}
local currentTab

local function newTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(72, 26)
    btn.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.Text = name
    btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1, -20, 1, -124)
    frame.Position = UDim2.new(0, 10, 0, 80)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 108)
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.Visible = false
    frame.Parent = main

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = frame

    tabs[name] = { btn = btn, frame = frame, ord = 0 }

    btn.MouseButton1Click:Connect(function()
        for n, t in pairs(tabs) do
            t.frame.Visible = (n == name)
            t.btn.BackgroundColor3 = (n == name)
                and Color3.fromRGB(70, 110, 190)
                or Color3.fromRGB(36, 36, 46)
        end
        currentTab = tabs[name]
    end)
    return tabs[name]
end

local function add(inst)
    inst.LayoutOrder = currentTab.ord
    currentTab.ord += 1
    inst.Parent = currentTab.frame
    return inst
end

local function section(text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -4, 0, 18)
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextColor3 = Color3.fromRGB(120, 160, 255)
    l.Text = string.upper(text)
    return add(l)
end

local function makeToggle(text, key, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 30)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextColor3 = Color3.fromRGB(235, 235, 242)
    add(b)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    local function refresh()
        b.BackgroundColor3 = cfg[key] and Color3.fromRGB(34, 100, 64)
            or Color3.fromRGB(40, 40, 50)
        b.Text = "   " .. text .. "  —  " .. (cfg[key] and "ON" or "OFF")
    end

    b.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        refresh()
        if cb then pcall(cb, cfg[key]) end
    end)
    refresh()
    hub.sync[key] = refresh
end

local function makeSlider(text, key, min, max, step, cb)
    local dec = step < 1 and 2 or 0
    local fmt = "%." .. dec .. "f"

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 42)
    row.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    row.BorderSizePixel = 0
    add(row)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -16, 0, 16)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(235, 235, 242)
    label.Parent = row

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -20, 0, 9)
    track.Position = UDim2.new(0, 10, 0, 25)
    track.BackgroundColor3 = Color3.fromRGB(66, 66, 78)
    track.BorderSizePixel = 0
    track.Text = ""
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(88, 155, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local dragging = false

    local function set(alpha)
        alpha = math.clamp(alpha, 0, 1)
        local raw = min + (max - min) * alpha
        local v = tonumber(string.format(fmt, math.floor(raw / step + 0.5) * step))
        v = math.clamp(v, min, max)
        cfg[key] = v
        label.Text = text .. ": " .. string.format(fmt, v)
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        if cb then pcall(cb, v) end
    end

    local function fromMouse()
        local rel = (UIS:GetMouseLocation().X - track.AbsolutePosition.X) / track.AbsoluteSize.X
        set(rel)
    end

    track.MouseButton1Down:Connect(function() dragging = true; fromMouse() end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromMouse() end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    set((cfg[key] - min) / (max - min))
    hub.sync[key] = function() set((cfg[key] - min) / (max - min)) end
end

local function makeButton(text, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(48, 52, 68)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(235, 235, 242)
    b.Text = text
    add(b)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

local function syncAll()
    for _, f in pairs(hub.sync) do pcall(f) end
end

--==========================================================
-- TAB: MOVE
--==========================================================
newTab("Move")
currentTab = tabs["Move"]

section("Flight")
makeToggle("Fly", "Fly", function(on) if on then startFly() else clearFly() end end)
makeSlider("Fly Speed", "FlySpeed", 10, 400, 5)

section("Ground")
makeToggle("Noclip", "Noclip", setNoclip)
makeToggle("Infinite Jump", "InfJump")
makeSlider("Walk Speed", "WalkSpeed", 8, 250, 1)
makeSlider("Jump Power", "JumpPower", 50, 400, 5)

section("Utility")
makeToggle("Anti-AFK", "AntiAFK")
makeButton("Re-apply Stats", applyStats)

--==========================================================
-- TAB: VISUAL
--==========================================================
newTab("Visual")
currentTab = tabs["Visual"]

section("Lighting")
makeToggle("Fullbright", "Fullbright", setFullbright)

section("Camera")
makeSlider("Field of View", "FOV", 40, 140, 1)

section("Players")
makeToggle("Player ESP", "ESP")

--==========================================================
-- TAB: TELEPORT
--==========================================================
newTab("Tp")
currentTab = tabs["Tp"]

section("Options")
makeButton("TP to Mouse Cursor", tpToMouse)

section("Players")
local plist = Instance.new("ScrollingFrame")
plist.Size = UDim2.new(1, -4, 0, 140)
plist.BackgroundColor3 = Color3.fromRGB(26, 26, 33)
plist.BorderSizePixel = 0
plist.ScrollBarThickness = 4
plist.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 108)
plist.CanvasSize = UDim2.new(0, 0, 0, 0)
plist.AutomaticCanvasSize = Enum.AutomaticSize.Y
add(plist)
Instance.new("UICorner", plist).CornerRadius = UDim.new(0, 6)

local plistLayout = Instance.new("UIListLayout")
plistLayout.Padding = UDim.new(0, 4)
plistLayout.SortOrder = Enum.SortOrder.LayoutOrder
plistLayout.Parent = plist

local function rebuildPlayerList()
    for _, c in ipairs(plist:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            n += 1
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 26)
            b.LayoutOrder = n
            b.BackgroundColor3 = Color3.fromRGB(44, 44, 56)
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 12
            b.TextColor3 = Color3.fromRGB(235, 235, 242)
            b.Text = p.Name
            b.Parent = plist
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            b.MouseButton1Click:Connect(function() tpToPlayer(p) end)
        end
    end
end

conn(Players.PlayerAdded:Connect(function() task.wait(0.2); rebuildPlayerList() end))
conn(Players.PlayerRemoving:Connect(function() task.wait(0.2); rebuildPlayerList() end))

section("Saved Positions")
for i = 1, 3 do
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 30)
    holder.BackgroundTransparency = 1
    add(holder)

    local lay = Instance.new("UIListLayout")
    lay.FillDirection = Enum.FillDirection.Horizontal
    lay.Padding = UDim.new(0, 6)
    lay.Parent = holder

    local function half(text, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.5, -3, 1, 0)
        b.BackgroundColor3 = Color3.fromRGB(48, 52, 68)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(235, 235, 242)
        b.Text = text
        b.Parent = holder
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
    end

    half("Save " .. i, function()
        local r = root()
        if r then getgenv().DarrenSlots[i] = r.Position end
    end)
    half("Load " .. i, function()
        local p = getgenv().DarrenSlots[i]
        if p then tpTo(p) end
    end)
end

--==========================================================
-- TAB: GHOST
--==========================================================
newTab("Ghost")
currentTab = tabs["Ghost"]

local function setGhost(on)
    if on then
        cfg.Humanize = true
        cfg.StealthTP = true
        cfg.Obfuscate = true
        cfg.ESP = false
        cfg.WalkSpeed = math.min(cfg.WalkSpeed, 32)
        cfg.JumpPower = math.min(cfg.JumpPower, 100)
        cfg.FlySpeed = math.min(cfg.FlySpeed, 60)
    end
    syncAll()
end

section("Master")
makeToggle("Ghost Mode", "GhostMode", setGhost)

section("Motion")
makeToggle("Humanized Motion", "Humanize")
makeSlider("Speed Variance %", "SpeedVariance", 0, 20, 1)

section("Teleport")
makeToggle("Stealth Teleport", "StealthTP")
makeSlider("Plausible Speed", "TPSpeed", 40, 500, 10)

section("Footprint")
makeToggle("Obfuscate Names", "Obfuscate")
makeToggle("Hide Menu On Start", "HideOnStart")

--==========================================================
-- BINDINGS + INIT
--==========================================================
minBtn.MouseButton1Click:Connect(function()
    local shown = false
    for _, t in pairs(tabs) do
        if t.frame.Visible then shown = true end
    end
    for _, t in pairs(tabs) do t.frame.Visible = false end
    if not shown then
        currentTab.frame.Visible = true
        main.Size = UDim2.fromOffset(320, 452)
    else
        main.Size = UDim2.fromOffset(320, 118)
    end
end)

clsBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

conn(UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        gui.Enabled = not gui.Enabled
    end
end))

do
    local dragging, dragStart, startPos
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

tabs["Move"].btn:Fire("MouseButton1Click")
currentTab = tabs["Move"]
tabs["Move"].frame.Visible = true
tabs["Move"].btn.BackgroundColor3 = Color3.fromRGB(70, 110, 190)

rebuildPlayerList()
applyStats()
if cfg.Fly then startFly() end
if cfg.Fullbright then setFullbright(true) end
if cfg.HideOnStart then gui.Enabled = false end
