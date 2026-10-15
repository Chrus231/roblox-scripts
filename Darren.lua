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
