local clix
local okLocal, localCode = pcall(function()
    if isfile and isfile("C:/Users/Admin/Desktop/library.luau") then
        return readfile("C:/Users/Admin/Desktop/library.luau")
    elseif isfile and isfile("library.luau") then
        return readfile("library.luau")
    end
end)

if okLocal and localCode and #localCode > 0 then
    clix = assert(loadstring(localCode))()
else
    local body = nil
    if request then
        local res = request({ Url = "https://clixs.netlify.app/.netlify/functions/library", Method = "GET" })
        body = res and (res.Body or res.body)
    elseif game and game.HttpGet then
        body = game:HttpGet("https://clixs.netlify.app/.netlify/functions/library")
    end
    assert(body, "Failed to download Clix UI from server")
    clix = assert(loadstring(body))()
end
assert(type(clix) == "table" and type(clix.CreateWindow) == "function", "Invalid Clix UI module")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")
local function currentCharacter()
    return LocalPlayer.Character
end

local function currentHumanoid()
    local char = currentCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end


local HAS_DRAWING = (typeof(Drawing) == "table" and type(Drawing.new) == "function")

local ClixEsp = {
    on = false,
    lines = false,
    skeleton = false,
    selfEsp = false,
    chinaHat = false,
    boxGlow = false,
    boxFill = false,
    names = false,
    wallFade = false,
    teamCheck = true,
    mode = "box",
    maxDistance = 500,
    key = "NONE",
    espColor = Color3.fromRGB(0, 255, 0),
    boxColor = Color3.fromRGB(245, 245, 250),
    boxGlowColor = Color3.fromRGB(255, 64, 82),
    boxFillColor = Color3.fromRGB(70, 205, 255),
    boxFillFx1 = Color3.fromRGB(45, 175, 255),
    boxFillFx2 = Color3.fromRGB(220, 246, 255),
    boxFillFx3 = Color3.fromRGB(75, 125, 255),
}

local safeParent = nil
pcall(function() safeParent = (gethui and gethui()) or CoreGui end)
if not safeParent then safeParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") end

local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "ClixEspOverlay"
overlayGui.ResetOnSpawn = false
overlayGui.DisplayOrder = 9999
overlayGui.IgnoreGuiInset = true
overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() overlayGui.Parent = safeParent end)

local function WaveSeq(c1, c2, c3, phase, n, boost)
    n = n or 12
    phase = phase or 0
    local function pal(t)
        t = t % 1
        local x = t * 3
        local i = math.floor(x)
        local f = x - i
        f = f * f * (3 - 2 * f)
        if i == 0 then return c1:Lerp(c2, f)
        elseif i == 1 then return c2:Lerp(c3, f) end
        return c3:Lerp(c1, f)
    end
    local kps = {}
    for k = 0, n do
        local x = k / n
        local c = pal(x - phase)
        if boost then
            local w = 0.5 + 0.5 * math.cos((x - phase) * math.pi * 2)
            c = c:Lerp(Color3.new(1, 1, 1), 0.38 * w * w)
        end
        kps[#kps + 1] = ColorSequenceKeypoint.new(x, c)
    end
    return ColorSequence.new(kps)
end

local function asColor3(value, fallback)
    if typeof(value) == "Color3" then return value end
    if type(value) == "table" then
        if typeof(value.Value) == "Color3" then return value.Value end
        if typeof(value.Rgb) == "Color3" then return value.Rgb end
        local r = tonumber(value.R or value.r)
        local g = tonumber(value.G or value.g)
        local b = tonumber(value.B or value.b)
        if r and g and b then
            if r > 1 or g > 1 or b > 1 then return Color3.fromRGB(r, g, b) end
            return Color3.new(r, g, b)
        end
    end
    return fallback
end

local function newGuiLine()
    local frame = Instance.new("Frame")
    frame.Name = "EspLine"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BorderSizePixel = 0
    frame.ZIndex = 2
    frame.Visible = false
    frame.Parent = overlayGui

    local proxy = {
        _frame = frame,
        _from = Vector2.zero,
        _to = Vector2.zero,
        _thickness = 1.5,
        _color = Color3.new(1, 1, 1),
        _transparency = 1
    }

    local function redraw(self)
        local a, b = self._from, self._to
        if not a or not b then return end
        local dx = b.X - a.X
        local dy = b.Y - a.Y
        local dist = math.sqrt(dx * dx + dy * dy)
        frame.Size = UDim2.fromOffset(math.max(dist, 1), math.max(self._thickness, 1))
        frame.Position = UDim2.fromOffset((a.X + b.X) * 0.5, (a.Y + b.Y) * 0.5)
        frame.Rotation = math.deg(math.atan2(dy, dx))
    end

    return setmetatable(proxy, {
        __index = function(self, k)
            if k == "Visible" then return frame.Visible end
            if k == "Color" then return self._color end
            if k == "Thickness" then return self._thickness end
            if k == "Transparency" then return self._transparency end
            if k == "From" then return self._from end
            if k == "To" then return self._to end
            if k == "Remove" or k == "Destroy" then
                return function() if frame.Parent then frame:Destroy() end end
            end
            return nil
        end,
        __newindex = function(self, k, v)
            if k == "Visible" then frame.Visible = v
            elseif k == "Color" then self._color = v; frame.BackgroundColor3 = v
            elseif k == "Thickness" then self._thickness = v; redraw(self)
            elseif k == "From" then self._from = v; redraw(self)
            elseif k == "To" then self._to = v; redraw(self)
            elseif k == "Transparency" then
                self._transparency = tonumber(v) or 1
                frame.BackgroundTransparency = 1 - math.clamp(self._transparency, 0, 1)
            else rawset(self, k, v) end
        end
    })
end

local function newLine()
    if HAS_DRAWING then
        local ok, l = pcall(function()
            local d = Drawing.new("Line")
            d.Visible = false
            d.Thickness = 1.5
            d.Color = Color3.new(1, 1, 1)
            d.Transparency = 1
            return d
        end)
        if ok and l then return l end
    end
    return newGuiLine()
end

local function newText()
    local label = Instance.new("TextLabel")
    label.Name = "EspText"
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.ZIndex = 3
    label.Visible = false
    label.Parent = overlayGui

    local proxy = {
        _label = label,
        _pos = Vector2.zero,
        _color = Color3.new(1, 1, 1)
    }

    return setmetatable(proxy, {
        __index = function(self, k)
            if k == "Visible" then return label.Visible end
            if k == "Text" then return label.Text end
            if k == "Color" then return self._color end
            if k == "Position" then return self._pos end
            if k == "Remove" or k == "Destroy" then
                return function() if label.Parent then label:Destroy() end end
            end
            return nil
        end,
        __newindex = function(self, k, v)
            if k == "Visible" then label.Visible = v
            elseif k == "Text" then label.Text = v
            elseif k == "Color" then self._color = v; label.TextColor3 = v
            elseif k == "Position" then
                self._pos = v
                label.Position = UDim2.fromOffset(v.X, v.Y)
            else rawset(self, k, v) end
        end
    })
end

local SKEL_BONES_R15, SKEL_BONES_R6
local localChinaHat, makeChinaBundle, hideChina, removeChina, drawChinaHat
do
SKEL_BONES_R15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

SKEL_BONES_R6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local CH_SEGS = 12
local CH_RADIUS = 1.48
local CH_HEIGHT = 0.82
local CH_BASE_Y = 0.14
local CH_ANCHOR_Y = 0.48
local CH_PANEL_ALPHA = 0.54
local CH_PANEL_THICKNESS = 0.022
local CH_RIM_ALPHA = 0.25
local CH_COLORS = {
    Color3.fromRGB(255, 62, 208),
    Color3.fromRGB(207, 76, 255),
    Color3.fromRGB(123, 94, 255),
    Color3.fromRGB(65, 165, 255),
    Color3.fromRGB(48, 218, 255),
    Color3.fromRGB(55, 242, 220),
    Color3.fromRGB(91, 255, 178),
    Color3.fromRGB(151, 255, 112),
    Color3.fromRGB(220, 255, 91),
    Color3.fromRGB(255, 229, 91),
    Color3.fromRGB(255, 159, 91),
    Color3.fromRGB(255, 103, 147),
}

local SkelFx = (function()
    local cache = { base = nil, keys = nil }
    local POS = { 0, 0.20, 0.42, 0.60, 0.82, 1 }
    local fx = {}
    function fx.at(base, t)
        if cache.base ~= base or not cache.keys then
            cache.base = base
            local hue = select(1, base:ToHSV())
            local function cc(o, sa, v) return Color3.fromHSV((hue + o) % 1, sa, v) end
            cache.keys = {
                cc(-0.075, 0.88, 0.98), cc(-0.035, 0.62, 1), Color3.fromRGB(238, 253, 255),
                cc(0.035, 0.52, 1), cc(0.085, 0.86, 0.96), cc(-0.075, 0.88, 0.98),
            }
        end
        t = t % 1
        local keys = cache.keys
        for i = 1, #POS - 1 do
            if t <= POS[i + 1] then
                return keys[i]:Lerp(keys[i + 1], (t - POS[i]) / (POS[i + 1] - POS[i]))
            end
        end
        return keys[#keys]
    end
    function fx.phase()
        local now = os.clock()
        if now - (cache.phaseT or 0) >= 0.05 then
            cache.phaseT = now
            cache.phaseV = ((tick() * 54) % 360) / 360
        end
        return cache.phaseV or 0
    end
    return fx
end)()

makeChinaBundle = function()
    return {
        beams = {}, rim = {}, spokes = {}, detail = {}, panels = {},
        anchor = nil, apex = nil, model = nil, wallHighlight = nil,
        _ready = false, _failed = false, _retryAt = 0, _fxT = 0,
    }
end

hideChina = function(ch)
    if not ch then return end
    if ch.wallHighlight then pcall(function() ch.wallHighlight.Enabled = false end) end
    for _, key in ipairs({"beams", "rim", "spokes", "detail"}) do
        for _, beam in ipairs(ch[key] or {}) do
            pcall(function() beam.Enabled = false end)
        end
    end
    for _, pane in ipairs(ch.panels or {}) do
        pcall(function() pane.LocalTransparencyModifier = 1 end)
    end
end

removeChina = function(ch)
    if not ch then return end
    for _, key in ipairs({"beams", "rim", "spokes", "detail", "panels"}) do
        for _, obj in ipairs(ch[key] or {}) do
            pcall(function() if obj and obj.Parent then obj:Destroy() end end)
        end
    end
    if ch.wallHighlight then
        pcall(function() ch.wallHighlight.Enabled = false end)
        pcall(function() ch.wallHighlight:Destroy() end)
        ch.wallHighlight = nil
    end
    if ch.model then pcall(function() ch.model:Destroy() end); ch.model = nil end
    if ch.anchor then pcall(function() ch.anchor:Destroy() end); ch.anchor = nil end
    ch.beams, ch.rim, ch.spokes, ch.detail, ch.panels = {}, {}, {}, {}, {}
    ch.apex = nil
    ch._ready = false
    ch._failed = false
    ch._retryAt = 0
end

local function buildChinaHat(ch)
    if not ch or ch._ready then return ch and ch._ready end
    if ch._failed and os.clock() < (tonumber(ch._retryAt) or 0) then return false end
    local ok, err = pcall(function()
        local model = Instance.new("Model")
        model.Name = "ClixChinaHatCrystalModel"
        ch.model = model

        local anchor = Instance.new("Part")
        anchor.Name = "ClixChinaHatAnchor"
        anchor.Size = Vector3.new(0.08, 0.08, 0.08)
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor.CastShadow = false
        anchor.CFrame = CFrame.new()
        anchor.Parent = model
        model.PrimaryPart = anchor
        ch.anchor = anchor

        local apexPosition = Vector3.new(0, CH_HEIGHT, 0)
        local apex = Instance.new("Attachment")
        apex.Name = "ClixChinaHatApex"
        apex.Position = apexPosition
        apex.Parent = anchor
        ch.apex = apex

        local ringAttachments = {}
        local ringPositions = {}
        for i = 1, CH_SEGS do
            local angle = ((i - 1) / CH_SEGS) * math.pi * 2
            local point = Vector3.new(math.cos(angle) * CH_RADIUS, CH_BASE_Y, math.sin(angle) * CH_RADIUS)
            ringPositions[i] = point
            local ring = Instance.new("Attachment")
            ring.Name = "ClixChinaHatRimPoint" .. tostring(i)
            ring.Position = point
            ring.Parent = anchor
            ringAttachments[i] = ring
        end

        local function makePane(midPoint, edgePoint, color, suffix)
            local edge = edgePoint - midPoint
            local rise = apexPosition - midPoint
            local width = edge.Magnitude
            local height = rise.Magnitude
            if width < 0.001 or height < 0.001 then return end
            local rightAxis = edge.Unit
            local upAxis = rise.Unit
            local normalAxis = rightAxis:Cross(upAxis).Unit
            local center = midPoint + rightAxis * (width * 0.5) + upAxis * (height * 0.5)

            local pane = Instance.new("WedgePart")
            pane.Name = "ClixChinaHatGlassPane" .. suffix
            pane.Size = Vector3.new(CH_PANEL_THICKNESS, height, width)
            pane.CFrame = CFrame.fromMatrix(center, normalAxis, upAxis, -rightAxis)
            pane.Anchored = true
            pane.CanCollide = false
            pane.CanTouch = false
            pane.CanQuery = false
            pane.CastShadow = false
            pane.Material = Enum.Material.Glass
            pane.Color = color
            pane.Transparency = CH_PANEL_ALPHA
            pane.Reflectance = 0.06
            pane.TopSurface = Enum.SurfaceType.Smooth
            pane.BottomSurface = Enum.SurfaceType.Smooth
            pane.Parent = model
            table.insert(ch.panels, pane)
        end

        for i = 1, CH_SEGS do
            local nextIndex = (i % CH_SEGS) + 1
            local p0 = ringPositions[i]
            local p1 = ringPositions[nextIndex]
            local mid = (p0 + p1) * 0.5
            makePane(mid, p0, CH_COLORS[i], tostring(i) .. "A")
            makePane(mid, p1, CH_COLORS[i], tostring(i) .. "B")
        end

        for i = 1, CH_SEGS do
            local spoke = Instance.new("Beam")
            spoke.Name = "ClixChinaHatCrystalSeam" .. tostring(i)
            spoke.Attachment0 = apex
            spoke.Attachment1 = ringAttachments[i]
            spoke.FaceCamera = true
            spoke.Width0 = 0.0035
            spoke.Width1 = 0.008
            spoke.Segments = 1
            spoke.Color = ColorSequence.new(CH_COLORS[i])
            spoke.Transparency = NumberSequence.new(0.48)
            spoke.LightEmission = 0.015
            spoke.LightInfluence = 0.35
            spoke.Enabled = true
            spoke.Parent = anchor
            table.insert(ch.spokes, spoke)
        end

        for i = 1, CH_SEGS do
            local nextIndex = (i % CH_SEGS) + 1
            local rim = Instance.new("Beam")
            rim.Name = "ClixChinaHatCrystalRim" .. tostring(i)
            rim.Attachment0 = ringAttachments[i]
            rim.Attachment1 = ringAttachments[nextIndex]
            rim.FaceCamera = true
            rim.Width0 = 0.018
            rim.Width1 = 0.018
            rim.Segments = 4
            rim.Color = ColorSequence.new(CH_COLORS[i], CH_COLORS[nextIndex])
            rim.Transparency = NumberSequence.new(CH_RIM_ALPHA)
            rim.LightEmission = 0.045
            rim.LightInfluence = 0.22
            rim.Enabled = true
            rim.Parent = anchor
            table.insert(ch.rim, rim)
        end

        local innerAttachments = {}
        local innerRadius = CH_RADIUS * 0.82
        local innerY = CH_BASE_Y + (CH_HEIGHT - CH_BASE_Y) * 0.16
        for i = 1, CH_SEGS do
            local angle = ((i - 1) / CH_SEGS) * math.pi * 2
            local att = Instance.new("Attachment")
            att.Name = "ClixChinaHatInnerRingPoint" .. tostring(i)
            att.Position = Vector3.new(math.cos(angle) * innerRadius, innerY, math.sin(angle) * innerRadius)
            att.Parent = anchor
            innerAttachments[i] = att
        end

        for i = 1, CH_SEGS do
            local nextIndex = (i % CH_SEGS) + 1
            local line = Instance.new("Beam")
            line.Name = "ClixChinaHatInnerCut" .. tostring(i)
            line.Attachment0 = innerAttachments[i]
            line.Attachment1 = innerAttachments[nextIndex]
            line.FaceCamera = true
            line.Width0 = 0.007
            line.Width1 = 0.007
            line.Segments = 3
            line.Color = ColorSequence.new(CH_COLORS[i], CH_COLORS[nextIndex])
            line.Transparency = NumberSequence.new(0.62)
            line.LightEmission = 0.015
            line.LightInfluence = 0.3
            line.Enabled = true
            line.Parent = anchor
            table.insert(ch.detail, line)
        end

        local core = Instance.new("Part")
        core.Name = "ClixChinaHatCrystalCore"
        core.Shape = Enum.PartType.Ball
        core.Size = Vector3.new(0.075, 0.075, 0.075)
        core.CFrame = CFrame.new(0, CH_HEIGHT - 0.012, 0)
        core.Anchored = true
        core.CanCollide = false
        core.CanTouch = false
        core.CanQuery = false
        core.CastShadow = false
        core.Material = Enum.Material.Glass
        core.Color = Color3.fromRGB(218, 255, 255)
        core.Transparency = 0.52
        core.Reflectance = 0.1
        core.Parent = model
        table.insert(ch.panels, core)

        model.Parent = workspace

        local h = Instance.new("Highlight")
        h.Name = "ClixChinaHatWallHighlight"
        h.Adornee = model
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillColor = Color3.fromRGB(255, 82, 112)
        h.OutlineColor = Color3.fromRGB(255, 64, 98)
        h.FillTransparency = 0.84
        h.OutlineTransparency = 0.06
        h.Enabled = false
        h.Parent = workspace
        ch.wallHighlight = h
    end)

    if not ok then
        ch._failed = true
        ch._retryAt = os.clock() + 3
        pcall(function() if ch.model then ch.model:Destroy() end end)
        ch.model, ch.anchor, ch.apex, ch.wallHighlight = nil, nil, nil, nil
        ch.beams, ch.rim, ch.spokes, ch.detail, ch.panels = {}, {}, {}, {}, {}
        return false
    end

    ch._failed = false
    ch._retryAt = 0
    ch._ready = true
    return true
end

drawChinaHat = function(ch, head, col)
    if not ch or not head or not head.Parent then return end
    if not ch._ready and not buildChinaHat(ch) then
        hideChina(ch)
        return
    end
    if not ch.anchor or not ch.model then return end

    local anchorPosition = head.Position + Vector3.new(0, CH_ANCHOR_Y, 0)
    ch.model:PivotTo(CFrame.new(anchorPosition))

    if ch.wallHighlight then
        pcall(function()
            ch.wallHighlight.Adornee = ch.model
            local tint = (typeof(col) == "Color3") and col or Color3.fromRGB(255, 82, 112)
            local phz = SkelFx.phase()
            ch.wallHighlight.FillColor = SkelFx.at(tint, phz)
            ch.wallHighlight.OutlineColor = SkelFx.at(tint, phz + 0.5)
            ch.wallHighlight.FillTransparency = 0.84
            ch.wallHighlight.OutlineTransparency = 0.06
            ch.wallHighlight.Enabled = true
        end)
    end

    for _, pane in ipairs(ch.panels or {}) do pcall(function() pane.LocalTransparencyModifier = 0 end) end
    for _, key in ipairs({"beams", "rim", "spokes", "detail"}) do
        for _, beam in ipairs(ch[key] or {}) do pcall(function() beam.Enabled = true end) end
    end

    local fxNow = os.clock()
    if fxNow - (ch._fxT or 0) >= 0.04 then
        ch._fxT = fxNow
        local baseC = (typeof(col) == "Color3") and col or Color3.fromRGB(0, 205, 255)
        local ph = SkelFx.phase()
        for i, pane in ipairs(ch.panels or {}) do
            local seg = math.ceil(i / 2)
            pcall(function() pane.Color = SkelFx.at(baseC, (seg - 1) / CH_SEGS + ph) end)
        end
        for i, beam in ipairs(ch.spokes or {}) do
            pcall(function() beam.Color = ColorSequence.new(SkelFx.at(baseC, (i - 1) / CH_SEGS + ph)) end)
        end
        for i, beam in ipairs(ch.rim or {}) do
            pcall(function() beam.Color = ColorSequence.new(SkelFx.at(baseC, (i - 1) / math.max(#ch.rim, 1) + ph)) end)
        end
    end
end

localChinaHat = makeChinaBundle()
end


local EspObjects = {}

local function createPlayerEsp(plr)
    local esp = {
        player = plr,
        tracer = newLine(),
        nameText = newText(),
        highlight = nil,
        boxEdges = {},
        boxGlow = {},
        boxFill = nil,
        skelBones = {},
        china = makeChinaBundle(),
    }

    for i = 1, 8 do esp.boxEdges[i] = newLine() end
    for i = 1, 8 do esp.boxGlow[i] = newLine() end
    for i = 1, 14 do esp.skelBones[i] = newLine() end

    local fill = Instance.new("Frame")
    fill.Name = "ClixEspBoxFill"
    fill.BackgroundColor3 = ClixEsp.boxFillColor
    fill.BackgroundTransparency = 0.40
    fill.BorderSizePixel = 0
    fill.ZIndex = 1
    fill.Visible = false

    local grad = Instance.new("UIGradient")
    grad.Name = "BoxCrystalFillGradient"
    grad.Rotation = 28
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.10),
        NumberSequenceKeypoint.new(0.20, 0.22),
        NumberSequenceKeypoint.new(0.43, 0.30),
        NumberSequenceKeypoint.new(0.62, 0.20),
        NumberSequenceKeypoint.new(0.82, 0.08),
        NumberSequenceKeypoint.new(1, 0.10),
    })
    grad.Parent = fill
    fill.Parent = overlayGui
    esp.boxFill = fill

    local hl = Instance.new("Highlight")
    hl.Name = "ClixHighlight_" .. plr.Name
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = ClixEsp.espColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Enabled = false
    pcall(function() hl.Parent = workspace end)
    esp.highlight = hl

    EspObjects[plr] = esp
    return esp
end

local function removePlayerEsp(plr)
    local esp = EspObjects[plr]
    if not esp then return end

    pcall(function() esp.tracer:Remove() end)
    pcall(function() esp.nameText:Remove() end)
    pcall(function() if esp.boxFill then esp.boxFill:Destroy() end end)
    pcall(function() if esp.highlight then esp.highlight:Destroy() end end)
    removeChina(esp.china)

    for _, l in ipairs(esp.boxEdges) do pcall(function() l:Remove() end) end
    for _, l in ipairs(esp.boxGlow) do pcall(function() l:Remove() end) end
    for _, l in ipairs(esp.skelBones) do pcall(function() l:Remove() end) end

    EspObjects[plr] = nil
end

local function hidePlayerEsp(esp)
    esp.tracer.Visible = false
    esp.nameText.Visible = false
    if esp.boxFill then esp.boxFill.Visible = false end
    if esp.highlight then esp.highlight.Enabled = false end
    hideChina(esp.china)
    for _, l in ipairs(esp.boxEdges) do l.Visible = false end
    for _, l in ipairs(esp.boxGlow) do l.Visible = false end
    for _, l in ipairs(esp.skelBones) do l.Visible = false end
end

local WallFadeState = { original = {}, lastUpdate = 0 }

local function restoreWallFade()
    for part, original in pairs(WallFadeState.original) do
        pcall(function()
            if part and part.Parent then part.LocalTransparencyModifier = original end
        end)
        WallFadeState.original[part] = nil
    end
end

local function updateWallFade()
    if not ClixEsp.wallFade then
        restoreWallFade()
        return
    end

    local now = os.clock()
    if now - WallFadeState.lastUpdate < 0.18 then return end
    WallFadeState.lastUpdate = now

    local myChar = LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if not myChar or not myRoot or not Camera then
        restoreWallFade()
        return
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true

    local seen = {}
    local camPos = Camera.CFrame.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Torso")
            if root and (root.Position - myRoot.Position).Magnitude <= ClixEsp.maxDistance then
                local dir = root.Position - camPos
                local dist = dir.Magnitude
                if dist > 1.5 then
                    rayParams.FilterDescendantsInstances = { myChar, p.Character }
                    local hitResult = workspace:Raycast(camPos, dir.Unit * (dist - 0.5), rayParams)
                    if hitResult and hitResult.Instance and hitResult.Instance:IsA("BasePart") then
                        local hit = hitResult.Instance
                        seen[hit] = true
                        if WallFadeState.original[hit] == nil then
                            WallFadeState.original[hit] = hit.LocalTransparencyModifier
                        end
                        pcall(function() hit.LocalTransparencyModifier = 0.78 end)
                    end
                end
            end
        end
    end

    for part, original in pairs(WallFadeState.original) do
        if not part or not part.Parent or not seen[part] then
            pcall(function() if part and part.Parent then part.LocalTransparencyModifier = original end end)
            WallFadeState.original[part] = nil
        end
    end
end

local function isAlive(hum)
    return hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead
end

local function sameTeam(a, b)
    if not a or not b then return false end
    local r1, r2 = a:GetAttribute("Role"), b:GetAttribute("Role")
    if r1 ~= nil and r2 ~= nil then
        local s1, s2 = tostring(r1), tostring(r2)
        if s1 ~= "FFA" and s2 ~= "FFA" and s1 ~= "" and s2 ~= "" and s1 ~= "none" and s2 ~= "none" then
            return s1 == s2
        end
    end
    local t1, t2 = a:GetAttribute("Team"), b:GetAttribute("Team")
    if t1 ~= nil and t2 ~= nil then
        local s1, s2 = tostring(t1), tostring(t2)
        if s1 ~= "" and s2 ~= "" then return s1 == s2 end
    end
    return a.Team ~= nil and b.Team ~= nil and a.Team == b.Team
end

local _matchCache, _matchCacheAt = false, 0
local _playCache, _playCacheAt = false, 0

local function isPlayVisible()
    local now = tick()
    if now - _playCacheAt < 0.4 then
        return _playCache
    end
    _playCacheAt = now
    local ok, vis = pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return false end
        local main = pg:FindFirstChild("Main")
        if not main then return false end
        local function scan(parent, depth)
            if depth > 4 then return false end
            for _, d in ipairs(parent:GetChildren()) do
                if d:IsA("TextButton") or d:IsA("TextLabel") then
                    if d.Visible then
                        local txt = string.upper(tostring(d.Text or ""):gsub("%s+", ""))
                        if (txt == "PLAY" or txt == "JUGAR") and d.AbsoluteSize.X >= 40 then
                            return true
                        end
                    end
                elseif d:IsA("GuiObject") and d.Visible then
                    if scan(d, depth + 1) then return true end
                end
            end
            return false
        end
        return scan(main, 0)
    end)
    _playCache = (ok and vis == true)
    return _playCache
end

local function isMatchActive()
    local now = tick()
    if now - _matchCacheAt < 0.35 then
        return _matchCache
    end
    _matchCacheAt = now

    if isPlayVisible() then
        _matchCache = false
        return false
    end

    local okGame, gameId = pcall(function() return LocalPlayer:GetAttribute("Game") end)
    if okGame and typeof(gameId) == "string" and gameId ~= "" then
        _matchCache = true
        return true
    end

    local okRole, role = pcall(function() return LocalPlayer:GetAttribute("Role") end)
    if okRole and role ~= nil then
        local s = string.lower(tostring(role))
        if s ~= "" and s ~= "none" and s ~= "lobby" and s ~= "nil" then
            _matchCache = true
            return true
        end
    end

    local okFrame, inGame = pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local m = pg and pg:FindFirstChild("Main")
        if not m then return false end
        local mgf = m:FindFirstChild("MainGameFrame")
        local spec = m:FindFirstChild("MainSpectateFrame")
        local ks = mgf and mgf:FindFirstChild("KillStats", true)
        return (mgf and mgf.Visible == true) or (spec and spec.Visible == true) or (ks and ks:IsA("GuiObject") and ks.Visible == true)
    end)
    if okFrame and inGame then
        _matchCache = true
        return true
    end

    _matchCache = false
    return false
end

local function updateEsp()
    if not ClixEsp.on or not isMatchActive() then
        for _, esp in pairs(EspObjects) do hidePlayerEsp(esp) end
        hideChina(localChinaHat)
        if ClixEsp.wallFade then restoreWallFade() end
        return
    end

    if ClixEsp.wallFade then updateWallFade() end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    local myHead = myChar and myChar:FindFirstChild("Head")
    local vpSize = Camera.ViewportSize
    local isBoxMode = (ClixEsp.mode == "box")
    local camPos = Camera.CFrame.Position

    if ClixEsp.chinaHat and myHead and myHead.Parent then
        drawChinaHat(localChinaHat, myHead, ClixEsp.espColor)
    else
        hideChina(localChinaHat)
    end

    local origin2D = Vector2.new(vpSize.X * 0.5, vpSize.Y * 0.65)
    if myRoot and myRoot.Parent then
        local o3D, _ = Camera:WorldToViewportPoint(myRoot.Position + Vector3.new(0, 0.2, 0))
        if o3D.Z > 0.3 then
            origin2D = Vector2.new(o3D.X, o3D.Y)
        end
    end

    for plr, esp in pairs(EspObjects) do
        local ok = pcall(function()
            if not plr or plr.Parent ~= Players then
                removePlayerEsp(plr)
                return
            end

            if plr == LocalPlayer and not ClixEsp.selfEsp then
                hidePlayerEsp(esp)
                return
            end

            if plr ~= LocalPlayer and ClixEsp.teamCheck and sameTeam(LocalPlayer, plr) then
                hidePlayerEsp(esp)
                return
            end

            local char = plr.Character
            if not char then
                hidePlayerEsp(esp)
                return
            end

            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            local head = char:FindFirstChild("Head")

            if not hum or not root or not head or not isAlive(hum) then
                hidePlayerEsp(esp)
                return
            end

            local dist = (root.Position - camPos).Magnitude
            if dist > ClixEsp.maxDistance then
                hidePlayerEsp(esp)
                return
            end

            local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if not onScreen or rootPos.Z <= 0.3 then
                hidePlayerEsp(esp)
                return
            end

            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

            local headScreen = Vector2.new(headPos.X, headPos.Y)
            local legScreen = Vector2.new(legPos.X, legPos.Y)
            local height = (headScreen - legScreen).Magnitude
            local fovRad = math.rad(tonumber(Camera.FieldOfView) or 70)
            local distScale = vpSize.Y / (2 * math.tan(fovRad * 0.5))
            local minHeight = (5.8 / math.max(dist, 1.5)) * distScale
            if height < minHeight then height = minHeight end
            local width = height * 0.62
            local centerX = (headScreen.X + legScreen.X) * 0.5
            local centerY = (headScreen.Y + legScreen.Y) * 0.5
            local minX = math.floor(centerX - width * 0.5)
            local maxX = math.floor(centerX + width * 0.5)
            local minY = math.floor(centerY - height * 0.5)
            local maxY = math.floor(centerY + height * 0.5)
            local cornerW = math.clamp(math.floor(width * 0.25), 4, 18)
            local cornerH = math.clamp(math.floor(height * 0.20), 5, 22)
            local tooSmall = height < 6

            if isBoxMode and tooSmall then
                if esp.highlight then esp.highlight.Enabled = false end
                for i = 1, 8 do
                    esp.boxEdges[i].Visible = false
                    esp.boxGlow[i].Visible = false
                end
                if esp.boxFill then esp.boxFill.Visible = false end
            elseif isBoxMode then
                if esp.highlight then esp.highlight.Enabled = false end

                local e = esp.boxEdges
                local col = ClixEsp.boxColor

                e[1].From = Vector2.new(minX, minY); e[1].To = Vector2.new(minX + cornerW, minY); e[1].Color = col; e[1].Visible = true
                e[2].From = Vector2.new(minX, minY); e[2].To = Vector2.new(minX, minY + cornerH); e[2].Color = col; e[2].Visible = true

                e[3].From = Vector2.new(maxX - cornerW, minY); e[3].To = Vector2.new(maxX, minY); e[3].Color = col; e[3].Visible = true
                e[4].From = Vector2.new(maxX, minY); e[4].To = Vector2.new(maxX, minY + cornerH); e[4].Color = col; e[4].Visible = true

                e[5].From = Vector2.new(minX, maxY); e[5].To = Vector2.new(minX + cornerW, maxY); e[5].Color = col; e[5].Visible = true
                e[6].From = Vector2.new(minX, maxY - cornerH); e[6].To = Vector2.new(minX, maxY); e[6].Color = col; e[6].Visible = true

                e[7].From = Vector2.new(maxX - cornerW, maxY); e[7].To = Vector2.new(maxX, maxY); e[7].Color = col; e[7].Visible = true
                e[8].From = Vector2.new(maxX, maxY - cornerH); e[8].To = Vector2.new(maxX, maxY); e[8].Color = col; e[8].Visible = true

                if ClixEsp.boxGlow then
                    local gCol = ClixEsp.boxGlowColor
                    for i = 1, 8 do
                        local g = esp.boxGlow[i]
                        g.From = e[i].From
                        g.To = e[i].To
                        g.Color = gCol
                        g.Thickness = 5.5
                        g.Transparency = 0.24
                        g.Visible = true
                    end
                else
                    for i = 1, 8 do esp.boxGlow[i].Visible = false end
                end

                if ClixEsp.boxFill and esp.boxFill then
                    esp.boxFill.Position = UDim2.fromOffset(minX + 1, minY + 1)
                    esp.boxFill.Size = UDim2.fromOffset(math.max(maxX - minX - 2, 1), math.max(maxY - minY - 2, 1))
                    esp.boxFill.BackgroundColor3 = Color3.new(1, 1, 1)
                    esp.boxFill.BackgroundTransparency = math.clamp(tonumber(ClixEsp.boxFillAlpha) or 0.40, 0, 1)
                    esp.boxFill.Visible = true

                    local cg = esp.boxFill:FindFirstChild("BoxCrystalFillGradient")
                    if cg then
                        if ClixEsp.boxFillStops and #ClixEsp.boxFillStops >= 2 then
                            local kps = {}
                            for _, s in ipairs(ClixEsp.boxFillStops) do
                                local stopColor = asColor3(s.Value, ClixEsp.boxFillFx2)
                                if stopColor then
                                    kps[#kps + 1] = ColorSequenceKeypoint.new(math.clamp(tonumber(s.Time) or 0, 0, 1), stopColor)
                                end
                            end
                            if #kps >= 2 then
                                table.sort(kps, function(a, b) return a.Time < b.Time end)
                                pcall(function() cg.Color = ColorSequence.new(kps) end)
                            end
                        else
                            local wavePhase = (tick() * 0.15) % 1
                            pcall(function()
                                cg.Color = WaveSeq(asColor3(ClixEsp.boxFillFx1, ClixEsp.boxFillColor), asColor3(ClixEsp.boxFillFx2, ClixEsp.boxFillColor), asColor3(ClixEsp.boxFillFx3, ClixEsp.boxFillColor), wavePhase, 19, true)
                            end)
                        end
                    end
                else
                    if esp.boxFill then esp.boxFill.Visible = false end
                end
            else
                for i = 1, 8 do
                    esp.boxEdges[i].Visible = false
                    esp.boxGlow[i].Visible = false
                end
                if esp.boxFill then esp.boxFill.Visible = false end
                if esp.highlight then
                    esp.highlight.Adornee = char
                    esp.highlight.FillColor = ClixEsp.espColor
                    esp.highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    esp.highlight.Enabled = true
                end
            end

            if ClixEsp.lines then
                esp.tracer.From = origin2D
                esp.tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                esp.tracer.Color = ClixEsp.espColor
                esp.tracer.Thickness = 1.5
                esp.tracer.Visible = true
            else
                esp.tracer.Visible = false
            end

            if ClixEsp.names then
                esp.nameText.Text = (plr.DisplayName or plr.Name) .. string.format(" [%dm]", math.floor(dist * 0.28))
                esp.nameText.Position = Vector2.new(rootPos.X, minY - 16)
                esp.nameText.Color = Color3.fromRGB(255, 255, 255)
                esp.nameText.Visible = true
            else
                esp.nameText.Visible = false
            end

            if ClixEsp.skeleton then
                local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
                local bonePairs = isR15 and SKEL_BONES_R15 or SKEL_BONES_R6
                local skelLines = esp.skelBones
                local skelCol = isBoxMode and ClixEsp.boxColor or ClixEsp.espColor

                for i, pair in ipairs(bonePairs) do
                    local partA = char:FindFirstChild(pair[1])
                    local partB = char:FindFirstChild(pair[2])
                    local line = skelLines[i]

                    if partA and partB and line then
                        local pA = Camera:WorldToViewportPoint(partA.Position)
                        local pB = Camera:WorldToViewportPoint(partB.Position)
                        if pA.Z > 0.3 and pB.Z > 0.3 then
                            line.From = Vector2.new(pA.X, pA.Y)
                            line.To = Vector2.new(pB.X, pB.Y)
                            line.Color = skelCol
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    elseif line then
                        line.Visible = false
                    end
                end

                for i = #bonePairs + 1, #skelLines do
                    skelLines[i].Visible = false
                end
            else
                for _, b in ipairs(esp.skelBones) do b.Visible = false end
            end

            if ClixEsp.chinaHat then
                drawChinaHat(esp.china, head, ClixEsp.espColor)
            else
                hideChina(esp.china)
            end
        end)

        if not ok then hidePlayerEsp(esp) end
    end
end

local PlayerState = {
    fly = false,
    flySpeed = 60,
    flyMini = UserInputService.TouchEnabled,
    speedSlide = false,
    speedVal = 16,
    freecam = false,
    freecamSpeed = 70,
    desync = false,
    invisible = false,
    autoInvis = false,
    spin = false,
    spinSpeed = 720,
    wallpass = false,
    clickTp = false,
}
local featureBinds = {}

local function syncFeatureBind(name, enabled)
    local bind = featureBinds[name]
    if bind and bind.Active ~= (enabled == true) then bind:SetActive(enabled == true, true) end
end

local _connections = {}
local scriptKeybinds = {}
local win
local unloaded = false
local env = (getgenv and getgenv()) or _G
local flyConnection
local speedConnection
local spinConnection
local wallPassConnection
local clickTpConnection
local freecamConnection
local freecamInputBeganConn
local freecamInputEndedConn
local freecamInputChangedConn
local freecamSaved
local freecamKeys = {}
local freecamLookHeld = false
local freecamYaw, freecamPitch = 0, 0
local desyncConnection
local desyncJumpConn
local desyncRoot, desyncHum
local desyncVelY, desyncGrounded, desyncRay = 0, true, nil
local flyMiniGui
local flyAttachment
local flyForce
local flyRoot
local flyHumanoid
local flyPlatformStand
local flyUpHeld = false
local flyDownHeld = false
local flyMobileJumpUntil = 0
local movementSnapshots = {}
local wallPassChanged = {}
local flyToggle
local speedToggle
local freecamToggle
local freecamSpeedSlider
local desyncToggle
local invisibleToggle
local autoInvisToggle
local spinToggle
local wallPassToggle

local enableFEInvis, disableFEInvis, stopInvLoop, cleanupFake, cleanupVoid, invApplied, realChar
do
local WEAPON_FOLDERS = { "KnifePartsFolder", "GunPartsFolder" }
local DISPLAY_PARTS  = { KnifePartsFolder = "KnifeDisplay", GunPartsFolder = "GunDisplay" }
local WELD_NAMES     = { KnifePartsFolder = "KnifeWeld",   GunPartsFolder = "GunWeld" }

invApplied = false
local invisGeneration   = 0
local invisDisabling    = false
local invisRespawnPending = false
local fakeChar          = nil
realChar = nil
local voidPart          = nil
local invConn           = nil
local diedConn          = nil
local savedWelds        = {}
local savedInvisParts   = {}
local savedInvisHumanoid = nil
local savedInvisTools   = {}

stopInvLoop = function()
    if invConn  then pcall(function() invConn:Disconnect()  end); invConn  = nil end
    if diedConn then pcall(function() diedConn:Disconnect() end); diedConn = nil end
end

cleanupVoid = function()
    if voidPart then pcall(function() voidPart:Destroy() end); voidPart = nil end
end

cleanupFake = function()
    if fakeChar then pcall(function() fakeChar:Destroy() end); fakeChar = nil end
end

local function ensureVoid(nearPos)
    local base = nearPos or Vector3.new(0, 50, 0)
    local y = base.Y - 500
    if voidPart and voidPart.Parent then
        voidPart.CFrame = CFrame.new(base.X, y, base.Z)
        return voidPart
    end
    cleanupVoid()
    local p = Instance.new("Part")
    p.Name         = "ClixInvisVoid"
    p.Anchored     = true
    p.CanCollide   = true
    p.Transparency = 1
    p.Size         = Vector3.new(200, 2, 200)
    p.CFrame       = CFrame.new(base.X, y, base.Z)
    p.Parent       = workspace
    voidPart = p
    return p
end

local function isWeaponDesc(obj)
    local p = obj
    while p do
        if p.Name == "KnifePartsFolder" or p.Name == "GunPartsFolder" then return true end
        if p.Name == "KnifeDisplay"     or p.Name == "GunDisplay"     then return true end
        p = p.Parent
    end
    return false
end

local function saveWelds(char)
    savedWelds = {}
    if not char then return end
    for _, folderName in ipairs(WEAPON_FOLDERS) do
        local folder = char:FindFirstChild(folderName)
        if not folder then continue end
        local displayName = DISPLAY_PARTS[folderName]
        local display = folder:FindFirstChild(displayName)
        if not display then continue end
        for _, v in ipairs(folder:GetDescendants()) do
            if v:IsA("Weld") and v.Part0 and v.Part0.Name == "UpperTorso" then
                savedWelds[folderName] = { weld = v, part0 = v.Part0, part1 = v.Part1, c0 = v.C0, c1 = v.C1 }
                break
            end
        end
    end
end

local function restoreWelds(char)
    if not char then return end
    for _, folderName in ipairs(WEAPON_FOLDERS) do
        local info = savedWelds[folderName]
        if not info then continue end
        local folder = char:FindFirstChild(folderName)
        if not folder then continue end
        local display = folder:FindFirstChild(DISPLAY_PARTS[folderName])
        local upperTorso = char:FindFirstChild("UpperTorso")
        if not display or not upperTorso then continue end
        pcall(function()
            local weld = info.weld
            if weld and weld.Parent then
                weld.Part0 = upperTorso; weld.Part1 = display; weld.C0 = info.c0; weld.C1 = info.c1
            else
                local nw = Instance.new("Weld")
                nw.Name = WELD_NAMES[folderName] or "ClixWeaponWeld"
                nw.Part0 = upperTorso; nw.Part1 = display; nw.C0 = info.c0; nw.C1 = info.c1
                nw.Parent = display
            end
        end)
    end
end

local function restoreCharVisual(rc)
    if not rc or not rc.Parent then return end
    for part, original in pairs(savedInvisParts) do
        if part and part.Parent and part:IsDescendantOf(rc) then
            pcall(function()
                part.Anchored     = original.Anchored
                part.CanCollide   = original.CanCollide
                part.Massless     = original.Massless
                part.Transparency = original.Transparency
                part.LocalTransparencyModifier = original.LocalTransparencyModifier
                part.AssemblyLinearVelocity  = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

local function makeFake(char)
    cleanupFake()
    if not char then return nil end
    char.Archivable = true
    local ok, clone = pcall(function() return char:Clone() end)
    if not ok or not clone then return nil end
    clone.Name = "ClixFakeChar"
    for _, folderName in ipairs(WEAPON_FOLDERS) do
        local folder = clone:FindFirstChild(folderName)
        if folder then pcall(function() folder:Destroy() end) end
    end
    for _, name in ipairs({"KnifeDisplay","GunDisplay","Knife-Root","Gun-Root"}) do
        local o = clone:FindFirstChild(name, true)
        if o then pcall(function() o:Destroy() end) end
    end
    for _, obj in ipairs(clone:GetDescendants()) do
        if obj:IsA("LocalScript") or obj:IsA("Script") then
            pcall(function() obj.Disabled = (obj.Name ~= "Animate") end)
        end
    end
    local fHum = clone:FindFirstChildOfClass("Humanoid")
    if fHum then
        fHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        fHum.HealthDisplayType   = Enum.HumanoidHealthDisplayType.AlwaysOff
        if not fHum:FindFirstChildOfClass("Animator") then
            Instance.new("Animator").Parent = fHum
        end
    end
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Anchored    = false
            v.CanCollide  = (v.Name ~= "HumanoidRootPart")
            v.LocalTransparencyModifier = 0
            if v.Name ~= "HumanoidRootPart" then
                v.Transparency = math.clamp(v.Transparency + 0.4, 0.4, 0.85)
            else
                v.Transparency = 1
            end
        end
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then clone:PivotTo(hrp.CFrame) end
    clone.Parent = workspace
    return clone
end

local function forceRespawnNear(cf)
    if invisRespawnPending then return end
    invisRespawnPending = true
    local conn
    conn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        if newChar.Name == "ClixFakeChar" then return end
        if conn then conn:Disconnect(); conn = nil end
        invisRespawnPending = false
        task.defer(function()
            if LocalPlayer.Character ~= newChar or not newChar.Parent then return end
            local h    = newChar:FindFirstChildOfClass("Humanoid") or newChar:WaitForChild("Humanoid", 3)
            local root = newChar:FindFirstChild("HumanoidRootPart") or newChar:WaitForChild("HumanoidRootPart", 3)
            if LocalPlayer.Character ~= newChar or not newChar.Parent then return end
            if cf and root then pcall(function() newChar:PivotTo(cf * CFrame.new(0, 3, 0)) end) end
            if h then
                h.PlatformStand = false; h.WalkSpeed = 16; h.JumpPower = 50
                local camera = workspace.CurrentCamera
                if camera then camera.CameraSubject = h; camera.CameraType = Enum.CameraType.Custom end
                h:ChangeState(Enum.HumanoidStateType.Running)
            end
            pcall(function() restoreCharVisual(newChar) end)
        end)
    end)
    task.delay(6, function()
        if conn then pcall(function() conn:Disconnect() end); conn = nil end
        invisRespawnPending = false
    end)
    local ok = pcall(function() LocalPlayer:LoadCharacter() end)
    if not ok then
        if conn then pcall(function() conn:Disconnect() end); conn = nil end
        invisRespawnPending = false
    end
end

  


disableFEInvis = function()
    if invisDisabling then return end
    local activeChar = LocalPlayer.Character
    if not invApplied and not fakeChar and not realChar
        and (not activeChar or activeChar.Name ~= "ClixFakeChar") then return end
    invisDisabling = true
    invisGeneration += 1
    local generation = invisGeneration
    stopInvLoop()

    local returnCF
    if fakeChar and fakeChar.Parent then
        local fr = fakeChar:FindFirstChild("HumanoidRootPart")
        if fr then returnCF = fr.CFrame end
    end
    if not returnCF and workspace.CurrentCamera then
        returnCF = workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -8)
    end

    local restoreHumanoidSettings = savedInvisHumanoid or {}
    local staleRealChar = realChar
    local currentChar   = LocalPlayer.Character
    local currentIsValidRespawn = currentChar and currentChar.Name ~= "ClixFakeChar" and currentChar ~= staleRealChar
    local rc = currentIsValidRespawn and currentChar or staleRealChar
    if (not rc or not rc.Parent) and currentChar and currentChar.Name ~= "ClixFakeChar" then rc = currentChar end
    if currentIsValidRespawn and staleRealChar and staleRealChar ~= rc and staleRealChar.Parent then
        pcall(function() restoreCharVisual(staleRealChar) end)
    end

    if rc and rc.Parent then
        pcall(function()
            restoreCharVisual(rc)
            restoreWelds(rc)
            local hum = rc:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                hum.PlatformStand = false
                local hs = restoreHumanoidSettings
                hum.AutoRotate   = hs.AutoRotate   ~= nil and hs.AutoRotate   or true
                hum.WalkSpeed    = tonumber(hs.WalkSpeed)  or 16
                hum.UseJumpPower = hs.UseJumpPower ~= nil and hs.UseJumpPower or true
                if hum.UseJumpPower then hum.JumpPower  = tonumber(hs.JumpPower)  or 50
                else                     hum.JumpHeight = tonumber(hs.JumpHeight) or 7.2 end
                hum.HipHeight = tonumber(hs.HipHeight) or hum.HipHeight
                if returnCF then rc:PivotTo(returnCF * CFrame.new(0, 3, 0)) end
                local root = rc:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Anchored = false
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    pcall(function() root:SetNetworkOwner(LocalPlayer) end)
                end
                if LocalPlayer.Character ~= rc then LocalPlayer.Character = rc end
                local camera = workspace.CurrentCamera
                if camera then camera.CameraSubject = hum; camera.CameraType = Enum.CameraType.Custom end
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
            for _, entry in ipairs(savedInvisTools) do
                local tool = entry.tool
                if tool and tool.Parent and tool.Parent ~= rc then pcall(function() tool.Parent = rc end) end
                if tool and tool.Parent == rc then pcall(function() tool.Enabled = entry.enabled ~= false end) end
            end
        end)
    end

    cleanupFake()
    cleanupVoid()
    invApplied        = false
    realChar          = nil
    savedWelds        = {}
    savedInvisParts   = {}
    savedInvisHumanoid = nil
    savedInvisTools   = {}

    if not currentIsValidRespawn and (not LocalPlayer.Character or LocalPlayer.Character.Name == "ClixFakeChar") then
        forceRespawnNear(returnCF)
    end

    if rc and rc.Parent then
        task.delay(0.25, function()
            if generation ~= invisGeneration or not rc or not rc.Parent or LocalPlayer.Character ~= rc then return end
            pcall(function()
                restoreCharVisual(rc)
                local hum = rc:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    hum.PlatformStand = false
                    local hs = restoreHumanoidSettings
                    if hum.UseJumpPower then hum.JumpPower  = tonumber(hs.JumpPower)  or 50
                    else                     hum.JumpHeight = tonumber(hs.JumpHeight) or 7.2 end
                    hum.WalkSpeed = tonumber(hs.WalkSpeed) or 16
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end)
    end
    invisDisabling = false
end

enableFEInvis = function(char)
    char = char or LocalPlayer.Character
    if not char or char ~= LocalPlayer.Character or char.Name == "ClixFakeChar" then return end
    if invApplied and realChar == char and fakeChar and fakeChar.Parent then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    stopInvLoop()
    invisGeneration += 1
    local generation = invisGeneration
    realChar = char
    local groundCF = hrp.CFrame

    savedInvisHumanoid = {
        WalkSpeed  = hum.WalkSpeed,  JumpPower   = hum.JumpPower,
        JumpHeight = hum.JumpHeight, UseJumpPower = hum.UseJumpPower,
        HipHeight  = hum.HipHeight,  AutoRotate  = hum.AutoRotate,
    }
    savedInvisTools = {}
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            table.insert(savedInvisTools, { tool = child, enabled = child.Enabled })
        end
    end
    savedInvisParts = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and not isWeaponDesc(part) then
            savedInvisParts[part] = {
                Anchored = part.Anchored, CanCollide = part.CanCollide,
                Massless = part.Massless, Transparency = part.Transparency,
                LocalTransparencyModifier = part.LocalTransparencyModifier,
            }
        end
    end
    saveWelds(char)

    local fake = makeFake(char)
    if not fake then
        realChar = nil; savedWelds = {}; savedInvisParts = {}; return
    end
    local fHum = fake:FindFirstChildOfClass("Humanoid")
    local fHRP = fake:FindFirstChild("HumanoidRootPart")
    if not fHum or not fHRP then
        cleanupFake(); realChar = nil; savedWelds = {}; savedInvisParts = {}; return
    end
    fakeChar = fake

    local movedOK = pcall(function()
        local void = ensureVoid(hrp.Position)
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") and not isWeaponDesc(v) then
                v.CanCollide = false; v.Massless = true
                v.AssemblyLinearVelocity  = Vector3.zero
                v.AssemblyAngularVelocity = Vector3.zero
            end
        end
        hum.PlatformStand = true
        hum.WalkSpeed     = 0
        hum.JumpPower     = 0
        char:PivotTo(void.CFrame * CFrame.new(0, 5, 0))
        fake:PivotTo(groundCF)
        LocalPlayer.Character = fake
        local camera = workspace.CurrentCamera
        if camera then camera.CameraSubject = fHum; camera.CameraType = Enum.CameraType.Custom end
        fHum.PlatformStand = false
        fHum.WalkSpeed     = 16
        fHum.JumpPower     = 50
        fHum:ChangeState(Enum.HumanoidStateType.Running)
    end)

    if not movedOK then
        pcall(function() restoreCharVisual(char) end)
        cleanupFake(); cleanupVoid()
        realChar = nil; savedWelds = {}; savedInvisParts = {}; return
    end
    invApplied = true

    local lastUpdate = 0
    invConn = RunService.Heartbeat:Connect(function()
        if generation ~= invisGeneration or not invApplied then return end
        if not realChar or not realChar.Parent or not fakeChar or not fakeChar.Parent then return end
        if LocalPlayer.Character ~= fakeChar then return end
        local now = os.clock()
        if now - lastUpdate < 0.10 then return end
        lastUpdate = now
        local r    = realChar:FindFirstChild("HumanoidRootPart")
        local rHum = realChar:FindFirstChildOfClass("Humanoid")
        local fRoot = fakeChar:FindFirstChild("HumanoidRootPart")
        if not r then return end
        pcall(function()
            local base = (fRoot and fRoot.Position) or r.Position
            local void = ensureVoid(base)
            local targetCF = void.CFrame * CFrame.new(0, 5, 0)
            if (r.Position - targetCF.Position).Magnitude > 3 then r.CFrame = targetCF end
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            if rHum and rHum.Health > 0 then
                rHum.PlatformStand = true
                rHum.WalkSpeed     = 0
                rHum.JumpPower     = 0
            end
        end)
    end)

    diedConn = fHum.Died:Connect(function()
        if generation ~= invisGeneration then return end
        PlayerState.invisible = false
        syncToggleControl(invisibleToggle, false)
        disableFEInvis()
    end)
end

end

local function syncToggleControl(toggle, enabled)
    enabled = enabled == true
    if toggle and toggle.Value ~= enabled then toggle:Set(enabled) end
end

local function trackConnection(connection)
    _connections[#_connections + 1] = connection
    return connection
end

local ClixSoundState = { killId = "", killEnabled = true, gunId = "", gunEnabled = true, killValid = false, gunValid = false }
local soundConnections = {}
local soundConfigPath = "clix-config/sounds.json"
local lastKillSound = 0
local function soundUrl(id)
    local n = tostring(id or ""):match("%d+")
    return n and "rbxassetid://" .. n or ""
end
local function saveSoundConfig()
    if not writefile then return end
    pcall(function()
        if makefolder and isfolder and not isfolder("clix-config") then makefolder("clix-config") end
        writefile(soundConfigPath, HttpService:JSONEncode(ClixSoundState))
    end)
end
pcall(function()
    if isfile and readfile and isfile(soundConfigPath) then
        local d = HttpService:JSONDecode(readfile(soundConfigPath))
        if type(d) == "table" then
            ClixSoundState.killId = tostring(d.killId or "")
            ClixSoundState.killEnabled = d.killEnabled ~= false
            ClixSoundState.gunId = tostring(d.gunId or "")
            ClixSoundState.gunEnabled = d.gunEnabled ~= false
        end
    end
end)
local function validateSound(id, callback)
    local n = tostring(id or ""):match("%d+")
    if not n then callback(false); return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = soundUrl(n); s.Volume = 0; s.Parent = workspace
        local ok = pcall(function() ContentProvider:PreloadAsync({s}) end)
        local valid = ok and s.IsLoaded and s.TimeLength > 0
        pcall(function() s:Destroy() end)
        callback(valid)
    end)
end
local function playClixKillSound()
    if not ClixSoundState.killEnabled or not ClixSoundState.killValid or os.clock() - lastKillSound < 0.25 then return end
    local id = soundUrl(ClixSoundState.killId)
    if id == "" then return end
    lastKillSound = os.clock()
    local s = Instance.new("Sound")
    s.Name = "ClixKillSoundPlay"; s.SoundId = id; s.Volume = 1; s.Parent = SoundService; s:Play()
    Debris:AddItem(s, 15)
end
local function localKillCredit(humanoid)
    for _, name in ipairs({"creator", "Creator", "KillCredit", "LastHit", "attacker", "Attacker", "LastHitBy"}) do
        local tag = humanoid and humanoid:FindFirstChild(name)
        if tag then
            local v = tag.Value
            if v == LocalPlayer or v == LocalPlayer.Name or tostring(v) == tostring(LocalPlayer.UserId) then return true end
            if typeof(v) == "Instance" and v:IsA("Model") and Players:GetPlayerFromCharacter(v) == LocalPlayer then return true end
        end
    end
    return false
end
local function bindKillCharacter(character)
    if not character or Players:GetPlayerFromCharacter(character) == LocalPlayer then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local fired = false
    local function check()
        if not fired and hum.Health <= 0 and localKillCredit(hum) then fired = true; playClixKillSound() end
    end
    soundConnections[#soundConnections + 1] = hum.Died:Connect(check)
    soundConnections[#soundConnections + 1] = hum.HealthChanged:Connect(function(h) if h <= 0 then check() end end)
end
local function gunSoundTargets(tool)
    local out = {}
    if not tool or not tool:IsA("Tool") or not tool:FindFirstChild("Handle") or not tool:FindFirstChild("fire") or not tool:FindFirstChild("showBeam") then return out end
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("Sound") then
            local n = d.Name:lower()
            if (n:find("gunshot") or n:find("shoot") or n:find("shot")) and not n:find("kill") and not n:find("reload") then out[#out + 1] = d end
        end
    end
    return out
end
local function applyGunSound(tool)
    if not tool then return end
    for _, s in ipairs(gunSoundTargets(tool)) do
        pcall(function()
            if s:GetAttribute("ClixOriginalSoundId") == nil then s:SetAttribute("ClixOriginalSoundId", s.SoundId) end
            if ClixSoundState.gunEnabled and ClixSoundState.gunValid and ClixSoundState.gunId ~= "" then s.SoundId = soundUrl(ClixSoundState.gunId)
            else local original = s:GetAttribute("ClixOriginalSoundId"); if original then s.SoundId = original end end
        end)
    end
end
local function watchGunContainer(container)
    if not container then return end
    for _, d in ipairs(container:GetChildren()) do applyGunSound(d) end
    soundConnections[#soundConnections + 1] = container.ChildAdded:Connect(function(d) task.delay(0.2, function() if d.Parent then applyGunSound(d) end end) end)
end
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        if p.Character then bindKillCharacter(p.Character) end
        soundConnections[#soundConnections + 1] = p.CharacterAdded:Connect(bindKillCharacter)
    end
end
soundConnections[#soundConnections + 1] = Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then soundConnections[#soundConnections + 1] = p.CharacterAdded:Connect(bindKillCharacter) end end)
watchGunContainer(LocalPlayer.Character)
watchGunContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
soundConnections[#soundConnections + 1] = LocalPlayer.CharacterAdded:Connect(function(c) watchGunContainer(c) end)
if ClixSoundState.killId ~= "" then validateSound(ClixSoundState.killId, function(ok) ClixSoundState.killValid = ok end) end
if ClixSoundState.gunId ~= "" then validateSound(ClixSoundState.gunId, function(ok) ClixSoundState.gunValid = ok; if ok then applyGunSound(LocalPlayer.Character) end end) end

local function matchesKeyInput(input, key)
    if typeof(key) ~= "EnumItem" then return false end
    if key.EnumType == Enum.KeyCode then
        return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key
    end
    return input.UserInputType == key
end

local function attachKeybindFallback(bind)
    if not bind or bind._HasInputDispatch then return end
    scriptKeybinds[#scriptKeybinds + 1] = bind
    local downKey
    trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() then return end
        for _, candidate in ipairs(scriptKeybinds) do
            if candidate.Capturing then return end
        end
        local key = bind.Value and bind.Value.Key
        if not bind.FeatureEnabled or key == nil or downKey ~= nil or not matchesKeyInput(input, key) then return end
        downKey = key
        if bind.Value.Mode == "Hold" then
            bind:SetActive(true)
        elseif bind.Value.Mode == "Toggle" or bind.Value.Mode == "Tap" then
            bind:SetActive(not bind.Active)
        end
    end))
    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if downKey == nil or not matchesKeyInput(input, downKey) then return end
        downKey = nil
        if bind.Value.Mode == "Hold" then bind:SetActive(false) end
    end))
end

local function snapshotHumanoid(humanoid)
    if humanoid and not movementSnapshots[humanoid] then
        movementSnapshots[humanoid] = {
            PlatformStand = humanoid.PlatformStand,
            AutoRotate = humanoid.AutoRotate,
        }
    end
    return humanoid and movementSnapshots[humanoid]
end

local function restoreMovement()
    for humanoid, values in pairs(movementSnapshots) do
        if humanoid and humanoid.Parent then
            pcall(function()
                humanoid.PlatformStand = values.PlatformStand
                humanoid.AutoRotate = values.AutoRotate
            end)
        end
    end
    table.clear(movementSnapshots)
end

local unloadCombat = nil
local unloadTeleport = nil
local unloadEvento = nil
local unloadVfx = nil
local unloadAnimations = nil

local stopFreecam, stopDesync, stopClickTp
local function unload()
    if unloaded then return end
    unloaded = true
    if env.__ClixEspUnload == unload then env.__ClixEspUnload = nil end
    ClixEsp.on = false

    pcall(function() RunService:UnbindFromRenderStep("ClixEspRender") end)

    for _, c in ipairs(_connections) do
        pcall(function() c:Disconnect() end)
    end
    _connections = {}

    for _, connection in ipairs({ flyConnection, speedConnection, spinConnection, wallPassConnection, freecamConnection, freecamInputBeganConn, freecamInputEndedConn, freecamInputChangedConn, desyncConnection, desyncJumpConn, clickTpConnection }) do
        if connection then pcall(function() connection:Disconnect() end) end
    end
    flyConnection = nil
    speedConnection = nil
    spinConnection = nil
    wallPassConnection = nil
    freecamConnection = nil
    freecamInputBeganConn = nil
    freecamInputEndedConn = nil
    freecamInputChangedConn = nil
    desyncConnection = nil
    desyncJumpConn = nil
    clickTpConnection = nil
    if stopFreecam then stopFreecam() end
    if stopDesync then stopDesync() end
    if stopClickTp then stopClickTp() end
    stopInvLoop()
    cleanupFake()
    cleanupVoid()
    invApplied = false
    realChar = nil
    if unloadCombat then pcall(unloadCombat) end
    ClixSoundState.killEnabled = false
    ClixSoundState.gunEnabled = false
    applyGunSound(LocalPlayer.Character)
    applyGunSound(LocalPlayer:FindFirstChildOfClass("Backpack"))
    for _, connection in ipairs(soundConnections) do pcall(function() connection:Disconnect() end) end
    soundConnections = {}
    if unloadTeleport then pcall(unloadTeleport) end
    if unloadEvento then pcall(unloadEvento) end
    if unloadVfx then pcall(unloadVfx) end
    if unloadAnimations then pcall(unloadAnimations) end
    clixWearEnv = (getgenv and getgenv()) or _G
    clixWearCleanup = clixWearEnv.MytersWearCleanup or rawget(_G, "MytersWearCleanup")
    if type(clixWearCleanup) == "function" then pcall(clixWearCleanup) end
    flyUpHeld = false
    flyDownHeld = false
    if flyForce then pcall(function() flyForce:Destroy() end) end
    if flyAttachment then pcall(function() flyAttachment:Destroy() end) end
    flyForce = nil
    flyAttachment = nil
    flyRoot = nil
    for part, canCollide in pairs(wallPassChanged) do
        if part and part.Parent then pcall(function() part.CanCollide = canCollide end) end
        wallPassChanged[part] = nil
    end
    if flyMiniGui then pcall(function() flyMiniGui:Destroy() end) end
    flyMiniGui = nil
    local unloadCharacter = LocalPlayer.Character
    if unloadCharacter then
        for _, object in ipairs(unloadCharacter:GetDescendants()) do
            if object:IsA("BasePart") then object.LocalTransparencyModifier = 0 elseif object:IsA("Decal") or object:IsA("Texture") then object.Transparency = 0 end
        end
    end
    restoreMovement()

    removeChina(localChinaHat)

    for plr, esp in pairs(EspObjects) do
        pcall(function()
            esp.tracer.Visible = false
            esp.nameText.Visible = false
            if esp.boxFill then esp.boxFill.Visible = false end
            if esp.highlight then
                esp.highlight.Enabled = false
                esp.highlight:Destroy()
            end
            for _, l in ipairs(esp.boxEdges) do l.Visible = false; pcall(function() l:Remove() end) end
            for _, l in ipairs(esp.boxGlow) do l.Visible = false; pcall(function() l:Remove() end) end
            for _, l in ipairs(esp.skelBones) do l.Visible = false; pcall(function() l:Remove() end) end
            pcall(function() esp.tracer:Remove() end)
            pcall(function() esp.nameText:Remove() end)
            pcall(function() if esp.boxFill then esp.boxFill:Destroy() end end)
            removeChina(esp.china)
        end)
        EspObjects[plr] = nil
    end

    restoreWallFade()

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "ClixChinaHatCrystalModel" or obj.Name == "ClixChinaHatWallHighlight" or obj.Name == "ClixChinaHat" then
            pcall(function() obj:Destroy() end)
        end
    end

    pcall(function() overlayGui:Destroy() end)
    pcall(function() if win then win:Destroy() end end)
end

if env.__ClixEspUnload then
    pcall(env.__ClixEspUnload)
end
env.__ClixEspUnload = unload

for _, plr in ipairs(Players:GetPlayers()) do
    createPlayerEsp(plr)
end

_connections[#_connections + 1] = Players.PlayerAdded:Connect(function(plr)
    createPlayerEsp(plr)
end)

_connections[#_connections + 1] = Players.PlayerRemoving:Connect(function(plr)
    removePlayerEsp(plr)
end)

pcall(function() RunService:UnbindFromRenderStep("ClixEspRender") end)
RunService:BindToRenderStep("ClixEspRender", Enum.RenderPriority.Camera.Value + 1, updateEsp)

win = clix:CreateWindow({
    Title = "Clix",
    Dir = "clix",
    OnUnload = unload
})

local function getClixScreenGui()
    local g = nil
    pcall(function()
        if win and type(win.GetGui) == "function" then
            g = win:GetGui()
        end
        if not g and win and win._menu and win._menu._gui then
            g = win._menu._gui
        end
    end)
    return g or safeParent or game:GetService("CoreGui")
end

local function centerOverMainWindow(guiFrame)
    pcall(function()
        local winFrame = nil
        if win and type(win.GetFrame) == "function" then
            winFrame = win:GetFrame()
        end
        if not winFrame and win and win._menu and win._menu._chrome then
            winFrame = win._menu._chrome.Window and win._menu._chrome.Window.MenuFrame
        end
        if winFrame and winFrame.Parent then
            local absPos = winFrame.AbsolutePosition
            local absSize = winFrame.AbsoluteSize
            guiFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            guiFrame.Position = UDim2.fromOffset(absPos.X + absSize.X * 0.5, absPos.Y + absSize.Y * 0.5)
        else
            guiFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            guiFrame.Position = UDim2.fromScale(0.5, 0.5)
        end
    end)
end

do
local espTab = win:CreateTab("ESP")
local espSubTab = espTab:CreateSubTab("ESP")
local settingsSubTab = espTab:CreateSubTab("Settings")
local espCols = espSubTab:CreateColumns("Toggles", "Display")
local leftSec = espCols.left
local leftSec2 = espCols.right
local settingsCols = settingsSubTab:CreateColumns("Config", "Colors")
local rightSec = settingsCols.left
local rightSecColors = settingsCols.right

local enableToggle
local espKeyBind

enableToggle = leftSec:AddToggle({
    Label = "Enable ESP",
    Config = { "EnableESP" },
    Default = ClixEsp.on,
    Callback = function(val)
        ClixEsp.on = val
        if espKeyBind and espKeyBind.Active ~= (val == true) then espKeyBind:SetActive(val == true, true) end
    end
})
if enableToggle then
    ClixEsp.on = enableToggle.Value == true
end

local linesToggle = leftSec:AddToggle({
    Label = "ESP Lines",
    Config = { "ESPLines" },
    Default = ClixEsp.lines,
    Callback = function(val)
        ClixEsp.lines = val
    end
})
if linesToggle then ClixEsp.lines = linesToggle.Value == true end

local skeletonToggle = leftSec:AddToggle({
    Label = "Skeleton ESP",
    Config = { "SkeletonESP" },
    Default = ClixEsp.skeleton,
    Callback = function(val)
        ClixEsp.skeleton = val
    end
})
if skeletonToggle then ClixEsp.skeleton = skeletonToggle.Value == true end

local localPlayerToggle = leftSec:AddToggle({
    Label = "Local Player",
    Config = { "LocalPlayerESP" },
    Default = ClixEsp.selfEsp,
    Callback = function(val)
        ClixEsp.selfEsp = val
    end
})
if localPlayerToggle then ClixEsp.selfEsp = localPlayerToggle.Value == true end

local chinaHatToggle = leftSec:AddToggle({
    Label = "China Hat",
    Config = { "ChinaHat" },
    Default = ClixEsp.chinaHat,
    Callback = function(val)
        ClixEsp.chinaHat = val
        if not val then
            hideChina(localChinaHat)
            for _, o in pairs(EspObjects) do hideChina(o.china) end
        end
    end
})
if chinaHatToggle then ClixEsp.chinaHat = chinaHatToggle.Value == true end

local boxGlowToggle = leftSec2:AddToggle({
    Label = "box glow",
    Config = { "BoxGlow" },
    Default = ClixEsp.boxGlow,
    Callback = function(val)
        ClixEsp.boxGlow = val
    end
})
if boxGlowToggle then ClixEsp.boxGlow = boxGlowToggle.Value == true end

local boxFillToggle = leftSec2:AddToggle({
    Label = "box fill",
    Config = { "BoxFill" },
    Default = ClixEsp.boxFill,
    Tooltip = "Visible when ESP Mode is Box.",
    Callback = function(val)
        ClixEsp.boxFill = val
    end
})
if boxFillToggle then ClixEsp.boxFill = boxFillToggle.Value == true end

local namesToggle = leftSec2:AddToggle({
    Label = "Show Name",
    Config = { "ShowName" },
    Default = ClixEsp.names,
    Callback = function(val)
        ClixEsp.names = val
    end
})
if namesToggle then ClixEsp.names = namesToggle.Value == true end

local wallFadeToggle = leftSec2:AddToggle({
    Label = "Wall Fade",
    Config = { "WallFade" },
    Default = ClixEsp.wallFade,
    Callback = function(val)
        ClixEsp.wallFade = val
        if not val then restoreWallFade() end
    end
})
if wallFadeToggle then ClixEsp.wallFade = wallFadeToggle.Value == true end

local teamCheckToggle = leftSec2:AddToggle({
    Label = "Team Check",
    Config = { "TeamCheck" },
    Default = ClixEsp.teamCheck,
    Callback = function(val)
        ClixEsp.teamCheck = val
    end
})
if teamCheckToggle then ClixEsp.teamCheck = teamCheckToggle.Value == true end

local modeDropdown = rightSec:AddDropdown({
    Label = "ESP Mode",
    Config = { "ESPMode" },
    Options = { "Box", "Highlight" },
    Default = (ClixEsp.mode == "box" and "Box" or "Highlight"),
    Callback = function(val)
        ClixEsp.mode = (tostring(val):lower() == "box") and "box" or "highlight"
        win:Notify("ESP Mode: " .. tostring(val), 2)
    end
})
if modeDropdown and modeDropdown.ValueChanged then
    modeDropdown.ValueChanged:Connect(function(val)
        ClixEsp.mode = (tostring(val):lower() == "box") and "box" or "highlight"
    end)
end
if modeDropdown then
    ClixEsp.mode = (tostring(modeDropdown.Value):lower() == "box") and "box" or "highlight"
end

local distSlider = rightSec:AddSlider({
    Label = "ESP Distance",
    Config = { "ESPDistance" },
    Min = 50,
    Max = 10000,
    Step = 25,
    Default = ClixEsp.maxDistance,
    Suffix = " studs",
    Callback = function(val)
        ClixEsp.maxDistance = tonumber(val) or 500
    end
})
if distSlider and distSlider.ValueChanged then
    distSlider.ValueChanged:Connect(function(val)
        ClixEsp.maxDistance = tonumber(val) or 500
    end)
end
if distSlider and tonumber(distSlider.Value) then
    ClixEsp.maxDistance = tonumber(distSlider.Value)
end

espKeyBind = rightSec._raw:AddKeybind({
    Label = "ESP Key",
    RegistrationKey = "ESP",
    Default = { Mode = "Toggle" },
    ConfigMap = { Key = { "ESPKey" }, Mode = { "ESPKeyMode" } },
    Callback = function(val)
        if type(val) == "table" then ClixEsp.key = val.Key end
    end
})
if espKeyBind then
    espKeyBind:SetFeatureEnabled(true)
    attachKeybindFallback(espKeyBind)
    trackConnection(espKeyBind.ActiveChanged:Connect(function(active)
        ClixEsp.on = active == true
        if enableToggle and type(enableToggle.Set) == "function" then enableToggle:Set(ClixEsp.on) end
    end))
    if espKeyBind.Value and espKeyBind.Value.Key then ClixEsp.key = espKeyBind.Value.Key end
    espKeyBind:SetActive(ClixEsp.on, true)
end

rightSec:AddDivider()

local espColPicker = rightSecColors:AddColorPicker({
    Label = "ESP Color",
    Config = { "ESPColor" },
    Default = ClixEsp.espColor,
    Callback = function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(0, 255, 0)
        ClixEsp.espColor = c
    end
})
if espColPicker and espColPicker.ValueChanged then
    espColPicker.ValueChanged:Connect(function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(0, 255, 0)
        ClixEsp.espColor = c
    end)
end
if espColPicker and espColPicker.Value ~= nil then
    local val = espColPicker.Value
    ClixEsp.espColor = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or ClixEsp.espColor
end

local boxColPicker = rightSecColors:AddColorPicker({
    Label = "Box Color",
    Config = { "BoxColor" },
    Default = ClixEsp.boxColor,
    Callback = function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(245, 245, 250)
        ClixEsp.boxColor = c
    end
})
if boxColPicker and boxColPicker.ValueChanged then
    boxColPicker.ValueChanged:Connect(function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(245, 245, 250)
        ClixEsp.boxColor = c
    end)
end
if boxColPicker and boxColPicker.Value ~= nil then
    local val = boxColPicker.Value
    ClixEsp.boxColor = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or ClixEsp.boxColor
end

local boxGlowColPicker = rightSecColors:AddColorPicker({
    Label = "Box Glow Color",
    Config = { "BoxGlowColor" },
    Default = ClixEsp.boxGlowColor,
    Callback = function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(255, 64, 82)
        ClixEsp.boxGlowColor = c
    end
})
if boxGlowColPicker and boxGlowColPicker.ValueChanged then
    boxGlowColPicker.ValueChanged:Connect(function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(255, 64, 82)
        ClixEsp.boxGlowColor = c
    end)
end
if boxGlowColPicker and boxGlowColPicker.Value ~= nil then
    local val = boxGlowColPicker.Value
    ClixEsp.boxGlowColor = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or ClixEsp.boxGlowColor
end

local function applyBoxFillColor(val)
    if type(val) ~= "table" then return end
    if val.Alpha ~= nil then
        ClixEsp.boxFillAlpha = math.clamp(1 - (tonumber(val.Alpha) or 1), 0, 1)
    end
    local stops = val.Stops
    if stops and #stops >= 1 then
        local normalized = {}
        for _, stop in ipairs(stops) do
            if type(stop) == "table" then
                local color = asColor3(stop.Value, ClixEsp.boxFillColor)
                if color then normalized[#normalized + 1] = { Time = tonumber(stop.Time) or 0, Value = color } end
            end
        end
        ClixEsp.boxFillStops = #normalized > 0 and normalized or nil
        local n = #normalized
        if n == 0 then return end
        ClixEsp.boxFillFx1 = normalized[1].Value
        ClixEsp.boxFillFx3 = normalized[n].Value
        if n >= 3 then
            ClixEsp.boxFillFx2 = normalized[math.ceil(n / 2)].Value
        elseif n == 2 then
            ClixEsp.boxFillFx2 = normalized[1].Value:Lerp(normalized[2].Value, 0.5)
        else
            ClixEsp.boxFillFx2 = normalized[1].Value
        end
    elseif val.Rgb then
        local color = asColor3(val.Rgb, ClixEsp.boxFillColor)
        ClixEsp.boxFillStops = nil
        ClixEsp.boxFillColor = color
        ClixEsp.boxFillFx1 = color
        ClixEsp.boxFillFx2 = color
        ClixEsp.boxFillFx3 = color
    end
end

local boxFillColorPicker = rightSecColors._raw:AddColor({
    Label = "Box Fill Color",
    Config = { "BoxFillColor" },
    Transparency = { "BoxFillAlpha" },
    Gradient = "editable",
    Alpha = true,
    Default = {
        Rgb = ClixEsp.boxFillFx1,
        Alpha = 0.60,
        Stops = {
            { Time = 0, Value = ClixEsp.boxFillFx1 },
            { Time = 0.5, Value = ClixEsp.boxFillFx2 },
            { Time = 1, Value = ClixEsp.boxFillFx3 },
        }
    },
    OnChanged = applyBoxFillColor
})
if boxFillColorPicker and boxFillColorPicker.ValueChanged then
    boxFillColorPicker.ValueChanged:Connect(applyBoxFillColor)
end
if boxFillColorPicker then
    applyBoxFillColor(boxFillColorPicker.Value)
end

rightSecColors:AddDivider()

rightSecColors:AddButton({
    Label = "Reset ESP Objects",
    Callback = function()
        for p in pairs(EspObjects) do removePlayerEsp(p) end
        removeChina(localChinaHat)
        for _, p in ipairs(Players:GetPlayers()) do createPlayerEsp(p) end
        win:Notify("ESP objects reset", 2)
    end
})
end


do
local bodyPartIds = {
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftFoot", "RightFoot"
}

local bodyPartR6 = {
    Torso = "UpperTorso",
    ["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm",
    ["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg"
}

local defaultBodyParts = {
    Head = true, UpperTorso = true, LowerTorso = true,
    LeftUpperArm = false, RightUpperArm = false,
    LeftLowerArm = false, RightLowerArm = false,
    LeftHand = false, RightHand = false,
    LeftUpperLeg = false, RightUpperLeg = false,
    LeftLowerLeg = false, RightLowerLeg = false,
    LeftFoot = false, RightFoot = false
}

local ClixAim = {
    silent = false,
    key = "NONE",
    bodyParts = {
        Head = true, UpperTorso = true, LowerTorso = true,
        LeftUpperArm = false, RightUpperArm = false,
        LeftLowerArm = false, RightLowerArm = false,
        LeftHand = false, RightHand = false,
        LeftUpperLeg = false, RightUpperLeg = false,
        LeftLowerLeg = false, RightLowerLeg = false,
        LeftFoot = false, RightFoot = false
    },
    bodyChance = {
        Head = 100, UpperTorso = 100, LowerTorso = 100,
        LeftUpperArm = 100, RightUpperArm = 100,
        LeftLowerArm = 100, RightLowerArm = 100,
        LeftHand = 100, RightHand = 100,
        LeftUpperLeg = 100, RightUpperLeg = 100,
        LeftLowerLeg = 100, RightLowerLeg = 100,
        LeftFoot = 100, RightFoot = 100
    },
    visCheck = true,
    teamCheck = true,
    killCheck = true,
    fov = false,
    fovShow = false,
    fovFill = true,
    fovCursor = false,
    fovText = false,
    fovRadius = 200,
    fovThickness = 2,
    fovColor = Color3.fromRGB(0, 205, 255),
    fovFillColor = Color3.fromRGB(0, 205, 255),
    fovFillAlpha = 0.85,
    fovFillStops = nil,
    fovFillFx1 = Color3.fromRGB(0, 205, 255),
    fovFillFx2 = Color3.fromRGB(0, 160, 255),
    fovFillFx3 = Color3.fromRGB(0, 100, 255),
    targetPos = nil,
    targetPlr = nil
}

local ClixAuto = {
    autoShoot = false,
    autoShootKey = "NONE",
    triggerLegit = false,
    triggerHand = false,
    triggerHandKey = "NONE",
    autoEquip = false,
    autoEquipKey = "NONE",
    macro = false,
    macroKey = "NONE",
    macroSilent = false,
    delay = 20,
    visCheck = true,
    teamCheck = true
}

local fovOverlayGui = nil
local function getFovOverlay()
    if fovOverlayGui and fovOverlayGui.Parent then return fovOverlayGui end
    local sg = Instance.new("ScreenGui")
    sg.Name = "ClixFovOverlay"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 1000001
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = safeParent end)
    fovOverlayGui = sg
    return sg
end

local fovCircleObj = nil
local fovFillObj = nil
local fovTextLabel = nil

local function removeFovDrawings()
    if fovCircleObj then
        pcall(function()
            if fovCircleObj.Remove then fovCircleObj:Remove()
            elseif fovCircleObj.Destroy then fovCircleObj:Destroy() end
        end)
        fovCircleObj = nil
    end
    if fovFillObj then
        pcall(function()
            if fovFillObj.Remove then fovFillObj:Remove()
            elseif fovFillObj.Destroy then fovFillObj:Destroy() end
        end)
        fovFillObj = nil
    end
    if fovTextLabel then
        pcall(function()
            if fovTextLabel.Remove then fovTextLabel:Remove()
            elseif fovTextLabel.Destroy then fovTextLabel:Destroy() end
        end)
        fovTextLabel = nil
    end
end

local function createFovCircleGui(objectName, zIndex)
    local overlay = getFovOverlay()
    if not overlay then return nil end
    local isFill = (objectName == "ClixFovFill")
    local frame = Instance.new("Frame")
    frame.Name = objectName or "ClixFovCircle"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromOffset(0, 0)
    frame.Size = UDim2.fromOffset(1, 1)
    frame.BackgroundTransparency = 1
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = zIndex or (isFill and 6 or 7)
    frame.Parent = overlay

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame

    local stroke = nil
    if not isFill then
        stroke = Instance.new("UIStroke")
        stroke.Name = "FovStroke"
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1.5
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Transparency = 0
        stroke.Parent = frame
    end

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Name = "FovFillGrad"
    fillGrad.Rotation = 45
    fillGrad.Enabled = false
    fillGrad.Parent = frame

    local proxy = {
        _frame = frame,
        _stroke = stroke,
        _grad = fillGrad,
        _radius = 0,
        _pos = Vector2.zero,
        _visible = false,
        _thickness = 1.5,
        _color = Color3.fromRGB(0, 205, 255),
        _filled = isFill,
        _transparency = 0.85,
        _gradientColor = nil,
        _rotation = 45
    }

    local function redraw(self)
        if not frame.Parent then return end
        local d = math.max(self._radius * 2, 1)
        frame.Position = UDim2.fromOffset(self._pos.X, self._pos.Y)
        frame.Size = UDim2.fromOffset(d, d)
        frame.Visible = self._visible and self._radius > 0
        if self._filled then
            frame.BackgroundTransparency = math.clamp(self._transparency or 0.85, 0, 1)
            if self._gradientColor then
                fillGrad.Color = self._gradientColor
                fillGrad.Rotation = self._rotation or 45
                fillGrad.Enabled = true
                frame.BackgroundColor3 = Color3.new(1, 1, 1)
            else
                fillGrad.Enabled = false
                frame.BackgroundColor3 = self._color
            end
        else
            frame.BackgroundTransparency = 1
            if stroke then
                stroke.Thickness = self._thickness
                stroke.Color = self._color
                stroke.Transparency = math.clamp(self._transparency or 0, 0, 1)
                stroke.Enabled = true
            end
        end
    end

    return setmetatable(proxy, {
        __index = function(self, k)
            if k == "Visible" then return self._visible
            elseif k == "Radius" then return self._radius
            elseif k == "Position" then return self._pos
            elseif k == "Color" then return self._color
            elseif k == "Thickness" then return self._thickness
            elseif k == "Filled" then return self._filled
            elseif k == "Transparency" then return self._transparency
            elseif k == "GradientColor" then return self._gradientColor
            elseif k == "Rotation" then return self._rotation
            elseif k == "Remove" or k == "Destroy" then
                return function() if frame.Parent then frame:Destroy() end end
            end
            return nil
        end,
        __newindex = function(self, k, v)
            if k == "Visible" then self._visible = v; redraw(self)
            elseif k == "Radius" then self._radius = v; redraw(self)
            elseif k == "Position" then self._pos = v; redraw(self)
            elseif k == "Color" then self._color = v; redraw(self)
            elseif k == "Thickness" then self._thickness = v; redraw(self)
            elseif k == "Filled" then self._filled = v; redraw(self)
            elseif k == "Transparency" then self._transparency = v; redraw(self)
            elseif k == "GradientColor" then self._gradientColor = v; redraw(self)
            elseif k == "Rotation" then self._rotation = v; redraw(self)
            else rawset(self, k, v) end
        end
    })
end

local function initFovCircle()
    removeFovDrawings()
    if HAS_DRAWING then
        local ok1, c1 = pcall(function()
            local d = Drawing.new("Circle")
            d.Visible = false
            d.Radius = ClixAim.fovRadius
            d.Thickness = ClixAim.fovThickness
            d.Color = ClixAim.fovColor
            d.Transparency = 1
            d.Filled = false
            return d
        end)
        if ok1 and c1 then fovCircleObj = c1 end
    end
    if not fovCircleObj then
        fovCircleObj = createFovCircleGui("ClixFovCircle", 7)
    end
    fovFillObj = createFovCircleGui("ClixFovFill", 6)
end

initFovCircle()

local aimRaycastParams = RaycastParams.new()
aimRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
aimRaycastParams.IgnoreWater = true

local function checkAimVisible(part, myChar)
    if not part or not myChar or not Camera then return false end
    local camPos = Camera.CFrame.Position
    local targetPos = part.Position
    local dir = targetPos - camPos
    local dist = dir.Magnitude
    if dist < 1 then return true end
    aimRaycastParams.FilterDescendantsInstances = { myChar, part.Parent }
    local result = workspace:Raycast(camPos, dir.Unit * (dist - 0.2), aimRaycastParams)
    return result == nil
end

local function getTargetPart(char, bodyParts)
    if not char then return nil end
    local enabled = {}
    for id, on in pairs(bodyParts or defaultBodyParts) do
        if on then
            local chance = tonumber(ClixAim.bodyChance and ClixAim.bodyChance[id]) or 100
            if chance >= 100 or math.random(1, 100) <= chance then
                local part = char:FindFirstChild(id)
                if not part then
                    for r6name, r15id in pairs(bodyPartR6) do
                        if r15id == id then part = char:FindFirstChild(r6name) break end
                    end
                end
                if part and part:IsA("BasePart") then
                    enabled[#enabled + 1] = part
                end
            end
        end
    end
    if #enabled > 0 then return enabled[math.random(1, #enabled)] end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end

local aimRenderConnection = nil
local lastAimTargetPos = nil
local lastAimTargetPlr = nil

local function updateAimEngine()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)

    if ClixAim.fovCursor and not UserInputService.TouchEnabled then
        local mp = UserInputService:GetMouseLocation()
        if mp then center = Vector2.new(mp.X, mp.Y) end
    end

    local showFov = ClixAim.fov and ClixAim.fovShow
    if fovCircleObj then
        fovCircleObj.Visible = showFov
        fovCircleObj.Radius = ClixAim.fovRadius
        fovCircleObj.Position = center
        fovCircleObj.Color = ClixAim.fovColor
        fovCircleObj.Thickness = ClixAim.fovThickness
    end

    if fovFillObj then
        local fillVisible = showFov and ClixAim.fovFill
        fovFillObj.Visible = fillVisible
        if fillVisible then
            fovFillObj.Radius = ClixAim.fovRadius
            fovFillObj.Position = center
            fovFillObj.Color = ClixAim.fovFillColor
            fovFillObj.Transparency = ClixAim.fovFillAlpha
            fovFillObj.Filled = true

            local now = tick()
            local fillRot = (45 - now * 90) % 360
            fovFillObj.Rotation = fillRot

            local stops = ClixAim.fovFillStops
            local seq = nil
            if stops and #stops >= 2 then
                local kps = {}
                local nStops = #stops
                for i, s in ipairs(stops) do
                    local t = (i == 1) and 0 or ((i == nStops) and 1 or math.clamp(s.Time, 0.001, 0.999))
                    local c = asColor3(s.Value, ClixAim.fovFillColor)
                    if i > 1 and t <= kps[#kps].Time then
                        t = math.min(kps[#kps].Time + 0.001, 0.999)
                    end
                    kps[#kps + 1] = ColorSequenceKeypoint.new(t, c)
                end
                if #kps >= 2 then
                    kps[#kps] = ColorSequenceKeypoint.new(1, kps[#kps].Value)
                    local okSeq, resSeq = pcall(ColorSequence.new, kps)
                    if okSeq then seq = resSeq end
                end
            end
            if not seq then
                local c1 = asColor3(ClixAim.fovFillFx1, ClixAim.fovFillColor)
                local c2 = asColor3(ClixAim.fovFillFx2, ClixAim.fovFillColor)
                local c3 = asColor3(ClixAim.fovFillFx3, ClixAim.fovFillColor)
                local wp = (tick() * 0.15) % 1
                seq = WaveSeq(c1, c2, c3, wp, 19, true)
            end
            fovFillObj.GradientColor = seq
        end
    end

    if not isMatchActive() then
        if not ClixAim.silent then
            ClixAim.targetPos = nil
            ClixAim.targetPlr = nil
        end
        return
    end

    if not ClixAim.silent and not ClixAuto.autoEquip and not ClixAuto.autoShoot and not ClixAuto.triggerHand and not ClixAuto.triggerLegit then
        ClixAim.targetPos = nil
        ClixAim.targetPlr = nil
        return
    end

    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))
    if not myChar or not myHum or myHum.Health <= 0 or not myRoot then
        ClixAim.targetPos = nil
        ClixAim.targetPlr = nil
        return
    end

    local bestDist = math.huge
    local bestPos = nil
    local bestPlr = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            if not sameTeam(LocalPlayer, p) then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local root = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Torso")
                if hum and isAlive(hum) and root then
                    local part = getTargetPart(p.Character, ClixAim.bodyParts)
                    if part then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen and screenPos.Z > 0.3 then
                            local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                            local inFov = (not ClixAim.fov) or (mouseDist <= ClixAim.fovRadius)
                            if inFov then
                                local isVis = checkAimVisible(part, myChar)
                                if isVis and mouseDist < bestDist then
                                    bestDist = mouseDist
                                    bestPos = part.Position
                                    bestPlr = p
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if bestPos and bestPlr then
        ClixAim.targetPos = bestPos
        ClixAim.targetPlr = bestPlr
        lastAimTargetPos = bestPos
        lastAimTargetPlr = bestPlr
    else
        ClixAim.targetPos = nil
        ClixAim.targetPlr = nil
    end
end

aimRenderConnection = trackConnection(RunService.RenderStepped:Connect(updateAimEngine))

local function isGunTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool:FindFirstChild("Slash") or tool:FindFirstChild("Throw") or tool:FindFirstChild("FlingKnifeEvent") or tool:FindFirstChild("SlashStart") or tool:FindFirstChild("SetKnifeGoneTime") then
        return false
    end
    local n = tool.Name:lower()
    local knifeKeywords = {
        "knife", "cuchillo", "blade", "sword", "melee", "bat", "fist",
        "hand", "swatter", "fly", "slap", "sai", "dagger", "axe",
        "karambit", "katana", "scythe", "hammer", "wrench", "kunai"
    }
    for _, k in ipairs(knifeKeywords) do
        if n:find(k, 1, true) then return false end
    end
    for _, s in ipairs(tool:GetChildren()) do
        local sn = string.lower(s.Name)
        if sn == "fire" or sn == "showbeam" or sn == "kill" then return true end
    end
    local gunKeywords = {
        "gun", "pistol", "rifle", "shotgun", "ak", "m4", "glock",
        "revolver", "sniper", "arma", "weapon", "awp", "uzi", "smg",
        "burst", "paintball", "flamethrower", "grenade", "rpg", "rocket"
    }
    for _, k in ipairs(gunKeywords) do
        if n:find(k, 1, true) then return true end
    end
    for _, s in ipairs(tool:GetDescendants()) do
        if s:IsA("Sound") then
            local sn = s.Name:lower()
            if sn:find("gun") or sn:find("shot") or sn:find("fire") or sn:find("bang") then
                return true
            end
        end
    end
    return false
end

local function getEquippedGun(char)
    if not char then return nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") and isGunTool(item) then return item end
    end
    return nil
end

local function getBackpackGun()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    for _, item in ipairs(bp:GetChildren()) do
        if item:IsA("Tool") and isGunTool(item) then return item end
    end
    return nil
end

local function findCurrentGun()
    local char = LocalPlayer.Character
    if char then
        local g = getEquippedGun(char)
        if g then return g, true end
    end
    local bg = getBackpackGun()
    if bg then return bg, false end
    return nil, false
end

local function isGunDebounceActive(tool)
    if not tool then return false end
    if type(getconnections) == "function" and type(debug) == "table" and type(debug.getupvalues) == "function" then
        local ok, conns = pcall(getconnections, tool.Activated)
        if ok and type(conns) == "table" then
            for _, c in ipairs(conns) do
                if c.Function then
                    local okU, uvs = pcall(debug.getupvalues, c.Function)
                    if okU and type(uvs) == "table" then
                        for _, val in pairs(uvs) do
                            if val == true then return true end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function gunIsReloading(tool)
    if not tool then return false end
    local ok, res = pcall(function()
        if isGunDebounceActive(tool) then return true end
        if tool:GetAttribute("Reloading") == true or tool:GetAttribute("IsReloading") == true then return true end
        local a = tool:GetAttribute("Ammo")
        if typeof(a) == "number" and a <= 0 then return true end
        for _, name in ipairs({"Reloading", "IsReloading", "Reload"}) do
            local v = tool:FindFirstChild(name)
            if v and v:IsA("BoolValue") and v.Value then return true end
        end
        for _, name in ipairs({"Ammo", "Bullets", "Clip", "AmmoInClip", "CurrentAmmo"}) do
            local v = tool:FindFirstChild(name, true)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) and v.Value <= 0 then
                return true
            end
        end
        local hum0 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local animator = hum0 and hum0:FindFirstChildOfClass("Animator")
        if animator then
            for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                local n = string.lower(tostring(tr.Name or "") .. tostring(tr.Animation and tr.Animation.AnimationId or ""))
                if n:find("reload", 1, true) or n:find("recarg", 1, true) then
                    return true
                end
            end
        end
        for _, s in ipairs(tool:GetChildren()) do
            if s:IsA("Sound") and s.IsPlaying then
                local sn = string.lower(s.Name)
                if sn:find("reload", 1, true) or sn:find("recarg", 1, true) then
                    return true
                end
            end
        end
        return false
    end)
    return ok and res == true
end

local _gunReadyAt = 0
local function isGunReady(tool)
    if os.clock() < _gunReadyAt then return false end
    if gunIsReloading(tool) then return false end
    return true
end

local triggerRayParams = RaycastParams.new()
triggerRayParams.FilterType = Enum.RaycastFilterType.Exclude
triggerRayParams.IgnoreWater = true

local autoHeartbeatConnection = nil
local lastAutoShotTime = 0
local autoBusy = false

local function runAutoShootOnce()
    if autoBusy then return end
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myChar or not myHum or myHum.Health <= 0 then return end

    local gun, inHand = findCurrentGun()
    if not gun or not isGunReady(gun) then return end

    autoBusy = true
    task.spawn(function()
        pcall(function()
            if gun.Parent ~= myChar then
                myHum:EquipTool(gun)
                local t0 = os.clock()
                while gun.Parent ~= myChar and (os.clock() - t0) < 0.25 do
                    task.wait(0.015)
                end
            end
            if gun.Parent == myChar and isGunReady(gun) then
                task.wait(math.clamp((ClixAuto.delay or 20) / 1000, 0, 0.5))
                if isGunReady(gun) then
                    gun:Activate()
                    _gunReadyAt = os.clock() + 0.35
                    task.wait(0.05)
                end
                if not inHand and gun.Parent == myChar then
                    myHum:UnequipTools()
                end
            end
        end)
        autoBusy = false
    end)
end

local function runAutoEngine()
    local now = os.clock()
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myChar or not myHum or myHum.Health <= 0 then return end

    if (ClixAuto.autoShoot or ClixAuto.triggerLegit or ClixAuto.triggerHand) and (now - lastAutoShotTime >= ((ClixAuto.delay or 20) / 1000)) then
        local gun = getEquippedGun(myChar)
        if gun and isGunReady(gun) then
            local vp = Camera.ViewportSize
            local ray = Camera:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5)
            triggerRayParams.FilterDescendantsInstances = { myChar }
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, triggerRayParams)
            if hit and hit.Instance and hit.Instance.Parent then
                local model = hit.Instance:FindFirstAncestorOfClass("Model")
                local targetPlr = model and Players:GetPlayerFromCharacter(model)
                if targetPlr and targetPlr ~= LocalPlayer then
                    if not sameTeam(LocalPlayer, targetPlr) then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        if hum and isAlive(hum) then
                            lastAutoShotTime = now
                            pcall(function() gun:Activate() end)
                            _gunReadyAt = os.clock() + 0.35
                        end
                    end
                end
            end
        end
    end

    if ClixAuto.autoEquip and not autoBusy and (now - lastAutoShotTime >= ((ClixAuto.delay or 20) / 1000)) then
        if ClixAim.targetPlr and ClixAim.targetPos then
            local gun = findCurrentGun()
            if gun and isGunReady(gun) then
                lastAutoShotTime = now
                runAutoShootOnce()
            end
        end
    end
end

autoHeartbeatConnection = trackConnection(RunService.Heartbeat:Connect(runAutoEngine))

local silentHookInstalled = false
local oldNamecall = nil
local oldRaycast = nil

pcall(function()
    if hookmetamethod and type(hookmetamethod) == "function" then
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }
            if ClixAim.silent and ClixAim.targetPos and (method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") then
                if args[1] and typeof(args[1]) == "Vector3" and args[2] and typeof(args[2]) == "Vector3" then
                    local targetDir = (ClixAim.targetPos - args[1]).Unit * args[2].Magnitude
                    args[2] = targetDir
                    return oldNamecall(self, table.unpack(args))
                end
            end
            return oldNamecall(self, ...)
        end)
        silentHookInstalled = true
    end
end)

local settingsTab = win:CreateTab("Settings")
local soundsTab = win:CreateTab("Sounds")
local soundsSubTab = soundsTab:CreateSubTab("Sounds")
local soundsCols = soundsSubTab:CreateColumns("Sounds", "Sounds")
local killSoundSection = soundsCols.left
local gunSoundSection = soundsCols.right
local function setKillSoundId(value)
    local id = tostring(value or ""):match("%d+") or ""
    ClixSoundState.killId = id; ClixSoundState.killValid = false; saveSoundConfig()
    if id ~= "" then validateSound(id, function(ok) ClixSoundState.killValid = ok end) end
end
local function setGunSoundId(value)
    local id = tostring(value or ""):match("%d+") or ""
    ClixSoundState.gunId = id; ClixSoundState.gunValid = false; saveSoundConfig()
    if id ~= "" then validateSound(id, function(ok) ClixSoundState.gunValid = ok; if ok then applyGunSound(LocalPlayer.Character) end end)
    else applyGunSound(LocalPlayer.Character); applyGunSound(LocalPlayer:FindFirstChildOfClass("Backpack")) end
end
killSoundSection:AddTextBox({Label = "Kill Sound ID", Config = {"KillSoundId"}, Default = ClixSoundState.killId, Placeholder = "Roblox audio ID", FocusLostOnly = true, Callback = setKillSoundId})
killSoundSection:AddToggle({Label = "Enable Kill Sound", Config = {"KillSoundEnabled"}, Default = ClixSoundState.killEnabled, Callback = function(v) ClixSoundState.killEnabled = v == true; saveSoundConfig() end})
killSoundSection:AddButton({Label = "Test Kill Sound", Callback = playClixKillSound})
gunSoundSection:AddTextBox({Label = "Gun Sound ID", Config = {"GunSoundId"}, Default = ClixSoundState.gunId, Placeholder = "Roblox audio ID", FocusLostOnly = true, Callback = setGunSoundId})
gunSoundSection:AddToggle({Label = "Enable Gun Sound", Config = {"GunSoundEnabled"}, Default = ClixSoundState.gunEnabled, Callback = function(v) ClixSoundState.gunEnabled = v == true; saveSoundConfig(); applyGunSound(LocalPlayer.Character); applyGunSound(LocalPlayer:FindFirstChildOfClass("Backpack")) end})
gunSoundSection:AddButton({Label = "Reset Gun Sound", Callback = function() ClixSoundState.gunId = ""; ClixSoundState.gunValid = false; saveSoundConfig(); applyGunSound(LocalPlayer.Character); applyGunSound(LocalPlayer:FindFirstChildOfClass("Backpack")) end})

ClixSoundPresetIds = {
    iridmy = "82779297837185", HeadShot = "117532807673617", Push = "86241928686610",
    OverWatch = "83413293458796", AnimeMagic = "90154356004719", Mamboo = "127222471423488",
    Pluh = "121128869975748", ["Among us"] = "106384965642747", ShiningAnime = "81301370954029",
    PoyoTime = "131427477776313",
}
ClixSoundPresetNames = { "Off", "iridmy", "HeadShot", "Push", "OverWatch", "AnimeMagic", "Mamboo", "Pluh", "Among us", "ShiningAnime", "PoyoTime", "Custom" }
killSoundPresetDropdown = killSoundSection:AddDropdown({
    Label = "Kill Sound Preset",
    Config = { "KillSoundPreset" },
    Options = ClixSoundPresetNames,
    Default = "Custom",
    Callback = function(name)
        local value = ClixSoundPresetIds[tostring(name)] or ""
        setKillSoundId(value)
        if tostring(name) == "Off" then ClixSoundState.killEnabled = false end
        saveSoundConfig()
    end
})
gunSoundPresetDropdown = gunSoundSection:AddDropdown({
    Label = "Gun Sound Preset",
    Config = { "GunSoundPreset" },
    Options = ClixSoundPresetNames,
    Default = "Custom",
    Callback = function(name)
        local value = ClixSoundPresetIds[tostring(name)] or ""
        setGunSoundId(value)
        if tostring(name) == "Off" then ClixSoundState.gunEnabled = false end
        saveSoundConfig()
    end
})

local combatTab = win:CreateTab("Combat")
local aimSubTab = combatTab:CreateSubTab("Aim")
local autoSubTab = combatTab:CreateSubTab("Auto")

local aimCols = aimSubTab:CreateColumns("Silent Aim", "Field of View")
local aimLeft = aimCols.left
local aimRight = aimCols.right

local autoCols = autoSubTab:CreateColumns("Triggerbot & Shooting", "Macro & Delays")
local autoLeft = autoCols.left
local autoRight = autoCols.right

local silentToggle = aimLeft:AddToggle({
    Label = "Enable Silent Aim",
    Config = { "Combat_SilentAim" },
    Default = ClixAim.silent,
    Callback = function(val)
        ClixAim.silent = val
        syncFeatureBind("SilentAim", val)
    end
})
if silentToggle then ClixAim.silent = silentToggle.Value == true end

local silentKeyBind = aimLeft:AddKeybind({
    Label = "Silent Aim Key",
    Config = { "Combat_SilentAimKey" },
    Default = ClixAim.key,
    Callback = function(val)
        if type(val) == "table" and val.Key then ClixAim.key = val.Key
        elseif typeof(val) == "EnumItem" then ClixAim.key = val end
    end
})
featureBinds["SilentAim"] = silentKeyBind
attachKeybindFallback(silentKeyBind)

local BT_LAYOUT = {
    {id="Head",         label="H",   x=100, y=8,   w=40, h=36},
    {id="UpperTorso",   label="UT",  x=80,  y=52,  w=80, h=44},
    {id="LowerTorso",   label="LT",  x=90,  y=100, w=60, h=28},
    {id="LeftUpperArm", label="LUA", x=28,  y=52,  w=40, h=36},
    {id="RightUpperArm",label="RUA", x=172, y=52,  w=40, h=36},
    {id="LeftLowerArm", label="LLA", x=28,  y=92,  w=36, h=32},
    {id="RightLowerArm",label="RLA", x=176, y=92,  w=36, h=32},
    {id="LeftHand",     label="LH",  x=28,  y=128, w=32, h=24},
    {id="RightHand",    label="RH",  x=180, y=128, w=32, h=24},
    {id="LeftUpperLeg", label="LUL", x=78,  y=136, w=36, h=48},
    {id="RightUpperLeg",label="RUL", x=126, y=136, w=36, h=48},
    {id="LeftLowerLeg", label="LLL", x=78,  y=190, w=32, h=40},
    {id="RightLowerLeg",label="RLL", x=130, y=190, w=32, h=40},
    {id="LeftFoot",     label="LF",  x=78,  y=236, w=30, h=24},
    {id="RightFoot",    label="RF",  x=132, y=236, w=30, h=24},
}
local BT_LABELS = {
    Head="Head", UpperTorso="Upper Torso", LowerTorso="Lower Torso",
    LeftUpperArm="L Upper Arm", RightUpperArm="R Upper Arm",
    LeftLowerArm="L Lower Arm", RightLowerArm="R Lower Arm",
    LeftHand="L Hand", RightHand="R Hand",
    LeftUpperLeg="L Upper Leg", RightUpperLeg="R Upper Leg",
    LeftLowerLeg="L Lower Leg", RightLowerLeg="R Lower Leg",
    LeftFoot="L Foot", RightFoot="R Foot",
}
local BT_ON  = Color3.fromRGB(80, 180, 255)
local BT_OFF = Color3.fromRGB(45, 48, 55)

local btEditor = Instance.new("CanvasGroup")
btEditor.Name = "BTFrame"
btEditor.AnchorPoint = Vector2.new(0.5, 0.5)
btEditor.Position = UDim2.fromScale(0.5, 0.5)
btEditor.Size = UDim2.fromOffset(300, 420)
btEditor.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
btEditor.BackgroundTransparency = 0.05
btEditor.GroupTransparency = 0
btEditor.Visible = false
btEditor.ZIndex = 5000
btEditor.Active = true
pcall(function() btEditor.Parent = getClixScreenGui() end)
local btScale = Instance.new("UIScale", btEditor)
btScale.Scale = 1
Instance.new("UICorner", btEditor).CornerRadius = UDim.new(0, 14)
local btStroke = Instance.new("UIStroke", btEditor)
btStroke.Color = Color3.fromRGB(60, 60, 70)
btStroke.Transparency = 0.4

local btTitleL = Instance.new("TextLabel", btEditor)
btTitleL.BackgroundTransparency = 1
btTitleL.Position = UDim2.fromOffset(16, 12)
btTitleL.Size = UDim2.fromOffset(240, 22)
btTitleL.Text = "Body Target Parts"
btTitleL.TextColor3 = Color3.fromRGB(245, 245, 245)
btTitleL.Font = Enum.Font.GothamBold
btTitleL.TextSize = 14
btTitleL.TextXAlignment = Enum.TextXAlignment.Left
btTitleL.ZIndex = 202

local btClose = Instance.new("TextButton", btEditor)
btClose.AutoButtonColor = false
btClose.Position = UDim2.new(1, -36, 0, 10)
btClose.Size = UDim2.fromOffset(24, 24)
btClose.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
btClose.Text = "X"
btClose.TextColor3 = Color3.fromRGB(220, 220, 225)
btClose.Font = Enum.Font.GothamBold
btClose.TextSize = 12
btClose.ZIndex = 203
Instance.new("UICorner", btClose).CornerRadius = UDim.new(0, 6)

local btDrag = Instance.new("TextButton", btEditor)
btDrag.AutoButtonColor = false
btDrag.BackgroundTransparency = 1
btDrag.Position = UDim2.fromOffset(0, 0)
btDrag.Size = UDim2.new(1, -40, 0, 40)
btDrag.Text = ""
btDrag.ZIndex = 201
local btDragging, btDragStart, btDragPos = false, nil, nil
btDrag.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        btDragging = true
        btDragStart = inp.Position
        btDragPos = btEditor.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then btDragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not btDragging then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
        local d = inp.Position - btDragStart
        btEditor.Position = UDim2.new(btDragPos.X.Scale, btDragPos.X.Offset + d.X, btDragPos.Y.Scale, btDragPos.Y.Offset + d.Y)
    end
end)

local btStage = Instance.new("Frame", btEditor)
btStage.BackgroundTransparency = 1
btStage.Position = UDim2.fromOffset(20, 48)
btStage.Size = UDim2.fromOffset(240, 290)
btStage.ZIndex = 201

local btChancePanel = Instance.new("Frame", btEditor)
btChancePanel.Name = "BTChancePanel"
btChancePanel.BackgroundTransparency = 1
btChancePanel.Position = UDim2.fromOffset(16, 348)
btChancePanel.Size = UDim2.new(1, -32, 0, 56)
btChancePanel.Visible = false
btChancePanel.ZIndex = 201

local btChanceTitle = Instance.new("TextLabel", btChancePanel)
btChanceTitle.BackgroundTransparency = 1
btChanceTitle.Size = UDim2.new(1, -48, 0, 16)
btChanceTitle.Text = "Hit Chance"
btChanceTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
btChanceTitle.TextSize = 12
btChanceTitle.Font = Enum.Font.GothamBold
btChanceTitle.TextXAlignment = Enum.TextXAlignment.Left
btChanceTitle.ZIndex = 202

local btChancePct = Instance.new("TextLabel", btChancePanel)
btChancePct.BackgroundTransparency = 1
btChancePct.AnchorPoint = Vector2.new(1, 0)
btChancePct.Position = UDim2.new(1, 0, 0, 0)
btChancePct.Size = UDim2.fromOffset(44, 16)
btChancePct.Text = "100%"
btChancePct.TextColor3 = Color3.fromRGB(180, 180, 190)
btChancePct.TextSize = 12
btChancePct.Font = Enum.Font.GothamBold
btChancePct.TextXAlignment = Enum.TextXAlignment.Right
btChancePct.ZIndex = 202

local btChanceTrack = Instance.new("Frame", btChancePanel)
btChanceTrack.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
btChanceTrack.Position = UDim2.fromOffset(0, 24)
btChanceTrack.Size = UDim2.new(1, 0, 0, 10)
btChanceTrack.ZIndex = 202
Instance.new("UICorner", btChanceTrack).CornerRadius = UDim.new(1, 0)

local btChanceFill = Instance.new("Frame", btChanceTrack)
btChanceFill.BackgroundColor3 = Color3.fromRGB(64, 156, 255)
btChanceFill.Size = UDim2.new(1, 0, 1, 0)
btChanceFill.ZIndex = 203
Instance.new("UICorner", btChanceFill).CornerRadius = UDim.new(1, 0)

local btChanceKnob = Instance.new("Frame", btChanceTrack)
btChanceKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
btChanceKnob.Size = UDim2.fromOffset(14, 14)
btChanceKnob.AnchorPoint = Vector2.new(0.5, 0.5)
btChanceKnob.Position = UDim2.new(1, 0, 0.5, 0)
btChanceKnob.ZIndex = 204
Instance.new("UICorner", btChanceKnob).CornerRadius = UDim.new(1, 0)

local btSelectedPart = nil
local btDraggingChance = false

local function btSetChance(alpha)
    if not btSelectedPart then return end
    alpha = math.clamp(alpha, 0, 1)
    local v = math.max(1, math.floor(alpha * 100 + 0.5))
    ClixAim.bodyChance[btSelectedPart] = v
    btChanceFill.Size = UDim2.new(alpha, 0, 1, 0)
    btChanceKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
    btChancePct.Text = tostring(v) .. "%"
end

local function btChanceFromX(x)
    local abs = btChanceTrack.AbsolutePosition.X
    local w = btChanceTrack.AbsoluteSize.X
    if w <= 0 then return end
    btSetChance((x - abs) / w)
end

btChanceTrack.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        btDraggingChance = true
        btChanceFromX(inp.Position.X)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not btDraggingChance then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
        btChanceFromX(inp.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        btDraggingChance = false
    end
end)

local function btUpdateChanceUI()
    if not btSelectedPart then btChancePanel.Visible = false return end
    local v = math.clamp(tonumber(ClixAim.bodyChance[btSelectedPart]) or 100, 1, 100)
    btChanceTitle.Text = "Hit Chance - " .. (BT_LABELS[btSelectedPart] or btSelectedPart)
    btChancePct.Text = tostring(math.floor(v)) .. "%"
    local alpha = v / 100
    btChanceFill.Size = UDim2.new(alpha, 0, 1, 0)
    btChanceKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
    btChancePanel.Visible = true
end

local btPaintFns = {}
for _, info in ipairs(BT_LAYOUT) do
    local b = Instance.new("TextButton", btStage)
    b.AutoButtonColor = false
    b.Active = true
    b.Position = UDim2.fromOffset(info.x, info.y)
    b.Size = UDim2.fromOffset(info.w, info.h)
    b.Text = info.label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.ZIndex = 202
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local function btPaint()
        local on = ClixAim.bodyParts[info.id] == true
        b.BackgroundColor3 = on and BT_ON or BT_OFF
        b.TextColor3 = on and Color3.fromRGB(10, 20, 30) or Color3.fromRGB(180, 180, 185)
    end
    btPaint()
    table.insert(btPaintFns, btPaint)
    local btPressed = false
    b.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            btPressed = true
        end
    end)
    b.InputEnded:Connect(function(inp)
        if not btPressed then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            btPressed = false
            ClixAim.bodyParts[info.id] = not (ClixAim.bodyParts[info.id] == true)
            btPaint()
            btSelectedPart = info.id
            btUpdateChanceUI()
        end
    end)
    b.MouseLeave:Connect(function() btPressed = false end)
end

local btTweenToken = 0
local function btOpen()
    btTweenToken = btTweenToken + 1
    local myToken = btTweenToken
    pcall(function() btEditor.Parent = getClixScreenGui() end)
    btEditor.ZIndex = 5000
    centerOverMainWindow(btEditor)
    btEditor.Visible = true
    btScale.Scale = 0.88
    btEditor.GroupTransparency = 1
    for _, fn in ipairs(btPaintFns) do fn() end
    TweenService:Create(btScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    TweenService:Create(btEditor, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
end

local function btCloseEditor()
    btTweenToken = btTweenToken + 1
    local myToken = btTweenToken
    local t1 = TweenService:Create(btScale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.86 })
    local t2 = TweenService:Create(btEditor, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
    t1:Play()
    t2:Play()
    task.spawn(function()
        t1.Completed:Wait()
        if btTweenToken == myToken then
            btEditor.Visible = false
            btScale.Scale = 1
            btEditor.GroupTransparency = 0
        end
    end)
end
btClose.MouseButton1Click:Connect(btCloseEditor)

aimLeft:AddDivider()
aimLeft:AddButton({
    Label = "Body Target",
    Callback = function()
        if btEditor.Visible then btCloseEditor() else btOpen() end
    end
})

local enableFovToggle = aimRight:AddToggle({
    Label = "Enable FOV",
    Config = { "Combat_EnableFOV" },
    Default = ClixAim.fov,
    Callback = function(val)
        ClixAim.fov = val
    end
})
if enableFovToggle then ClixAim.fov = enableFovToggle.Value == true end

local showFovToggle = aimRight:AddToggle({
    Label = "Show FOV Circle",
    Config = { "Combat_ShowFOV" },
    Default = ClixAim.fovShow,
    Callback = function(val)
        ClixAim.fovShow = val
    end
})
if showFovToggle then ClixAim.fovShow = showFovToggle.Value == true end

local fovFillToggle = aimRight:AddToggle({
    Label = "FOV Fill",
    Config = { "Combat_FOVFill" },
    Default = ClixAim.fovFill,
    Callback = function(val)
        ClixAim.fovFill = val
    end
})
if fovFillToggle then ClixAim.fovFill = fovFillToggle.Value == true end

local fovCursorToggle = aimRight:AddToggle({
    Label = "FOV Follows Cursor",
    Config = { "Combat_FOVFollowsCursor" },
    Default = ClixAim.fovCursor,
    Callback = function(val)
        ClixAim.fovCursor = val
    end
})
if fovCursorToggle then ClixAim.fovCursor = fovCursorToggle.Value == true end

local fovRadiusSlider = aimRight:AddSlider({
    Label = "FOV Radius",
    Config = { "Combat_FOVRadius" },
    Min = 20,
    Max = 1000,
    Step = 10,
    Default = ClixAim.fovRadius,
    Suffix = " px",
    Callback = function(val)
        ClixAim.fovRadius = tonumber(val) or 200
    end
})
if fovRadiusSlider then ClixAim.fovRadius = tonumber(fovRadiusSlider.Value) or 200 end

local fovThicknessSlider = aimRight:AddSlider({
    Label = "FOV Thickness",
    Config = { "Combat_FOVThickness" },
    Min = 1,
    Max = 8,
    Step = 1,
    Default = ClixAim.fovThickness,
    Suffix = " px",
    Callback = function(val)
        ClixAim.fovThickness = tonumber(val) or 2
    end
})
if fovThicknessSlider then ClixAim.fovThickness = tonumber(fovThicknessSlider.Value) or 2 end

aimRight:AddDivider()

local fovColorPicker = aimRight:AddColorPicker({
    Label = "FOV Color",
    Config = { "Combat_FOVColor" },
    Default = ClixAim.fovColor,
    Callback = function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(0, 205, 255)
        ClixAim.fovColor = c
    end
})
if fovColorPicker and fovColorPicker.ValueChanged then
    fovColorPicker.ValueChanged:Connect(function(val)
        local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color)) or Color3.fromRGB(0, 205, 255)
        ClixAim.fovColor = c
    end)
end

local function applyFovFillColor(val)
    if type(val) ~= "table" then return end
    if val.Alpha ~= nil then
        ClixAim.fovFillAlpha = math.clamp(1 - (tonumber(val.Alpha) or 0.15), 0, 1)
    end
    local stops = val.Stops
    if stops and #stops >= 1 then
        local normalized = {}
        for _, stop in ipairs(stops) do
            if type(stop) == "table" then
                local color = asColor3(stop.Value, ClixAim.fovFillColor)
                if color then
                    local t = tonumber(stop.Time) or 0
                    normalized[#normalized + 1] = { Time = math.clamp(t, 0, 1), Value = color }
                end
            end
        end
        table.sort(normalized, function(a, b) return a.Time < b.Time end)
        ClixAim.fovFillStops = #normalized > 0 and normalized or nil
        local n = #normalized
        if n == 0 then return end
        ClixAim.fovFillFx1 = normalized[1].Value
        ClixAim.fovFillFx3 = normalized[n].Value
        if n >= 3 then
            ClixAim.fovFillFx2 = normalized[math.ceil(n / 2)].Value
        elseif n == 2 then
            ClixAim.fovFillFx2 = normalized[1].Value:Lerp(normalized[2].Value, 0.5)
        else
            ClixAim.fovFillFx2 = normalized[1].Value
        end
    elseif val.Rgb then
        local c = asColor3(val.Rgb, ClixAim.fovFillColor)
        ClixAim.fovFillColor = c
        ClixAim.fovFillFx1 = c
        ClixAim.fovFillFx2 = c
        ClixAim.fovFillFx3 = c
        ClixAim.fovFillStops = nil
    end
end

local fovFillColorPicker = aimRight._raw:AddColor({
    Label = "FOV Fill Color",
    Config = { "Combat_FOVFillColor" },
    Gradient = "editable",
    Alpha = true,
    Default = {
        Rgb = ClixAim.fovFillColor,
        Alpha = 0.15,
        Stops = {
            { Time = 0, Value = ClixAim.fovFillFx1 },
            { Time = 0.5, Value = ClixAim.fovFillFx2 },
            { Time = 1, Value = ClixAim.fovFillFx3 },
        }
    },
    OnChanged = applyFovFillColor
})
if fovFillColorPicker and fovFillColorPicker.ValueChanged then
    fovFillColorPicker.ValueChanged:Connect(applyFovFillColor)
end
if fovFillColorPicker then
    applyFovFillColor(fovFillColorPicker.Value)
end

local autoShootToggle = autoLeft:AddToggle({
    Label = "AutoShoot (Legit)",
    Config = { "Combat_AutoShoot" },
    Default = ClixAuto.autoShoot,
    Callback = function(val)
        ClixAuto.autoShoot = val
        syncFeatureBind("AutoShoot", val)
    end
})
if autoShootToggle then ClixAuto.autoShoot = autoShootToggle.Value == true end

local autoShootKeyBind = autoLeft:AddKeybind({
    Label = "AutoShoot Key",
    Config = { "Combat_AutoShootKey" },
    Default = ClixAuto.autoShootKey,
    Callback = function(val)
        if type(val) == "table" and val.Key then ClixAuto.autoShootKey = val.Key
        elseif typeof(val) == "EnumItem" then ClixAuto.autoShootKey = val end
    end
})
featureBinds["AutoShoot"] = autoShootKeyBind
attachKeybindFallback(autoShootKeyBind)

local triggerLegitToggle = autoLeft:AddToggle({
    Label = "Triggerbot Legit Hand",
    Config = { "Combat_TriggerLegitHand" },
    Default = ClixAuto.triggerLegit,
    Callback = function(val)
        ClixAuto.triggerLegit = val
    end
})
if triggerLegitToggle then ClixAuto.triggerLegit = triggerLegitToggle.Value == true end

local triggerHandToggle = autoLeft:AddToggle({
    Label = "Triggerbot Hand",
    Config = { "Combat_TriggerHand" },
    Default = ClixAuto.triggerHand,
    Callback = function(val)
        ClixAuto.triggerHand = val
        syncFeatureBind("TriggerHand", val)
    end
})
if triggerHandToggle then ClixAuto.triggerHand = triggerHandToggle.Value == true end

local triggerHandKeyBind = autoLeft:AddKeybind({
    Label = "Triggerbot Hand Key",
    Config = { "Combat_TriggerHandKey" },
    Default = ClixAuto.triggerHandKey,
    Callback = function(val)
        if type(val) == "table" and val.Key then ClixAuto.triggerHandKey = val.Key
        elseif typeof(val) == "EnumItem" then ClixAuto.triggerHandKey = val end
    end
})
featureBinds["TriggerHand"] = triggerHandKeyBind
attachKeybindFallback(triggerHandKeyBind)

local autoEquipToggle = autoLeft:AddToggle({
    Label = "Auto-Equip",
    Config = { "Combat_AutoEquip" },
    Default = ClixAuto.autoEquip,
    Callback = function(val)
        ClixAuto.autoEquip = val
        syncFeatureBind("AutoEquip", val)
    end
})
if autoEquipToggle then ClixAuto.autoEquip = autoEquipToggle.Value == true end

local autoEquipKeyBind = autoLeft:AddKeybind({
    Label = "Auto-Equip Key",
    Config = { "Combat_AutoEquipKey" },
    Default = ClixAuto.autoEquipKey,
    Callback = function(val)
        if type(val) == "table" and val.Key then ClixAuto.autoEquipKey = val.Key
        elseif typeof(val) == "EnumItem" then ClixAuto.autoEquipKey = val end
    end
})
featureBinds["AutoEquip"] = autoEquipKeyBind
attachKeybindFallback(autoEquipKeyBind)

local macroToggle = autoRight:AddToggle({
    Label = "Macro: Equip/Unequip",
    Config = { "Combat_MacroEquip" },
    Default = ClixAuto.macro,
    Callback = function(val)
        ClixAuto.macro = val
        syncFeatureBind("MacroEquip", val)
    end
})
if macroToggle then ClixAuto.macro = macroToggle.Value == true end

local macroKeyBind = autoRight:AddKeybind({
    Label = "Macro Key",
    Config = { "Combat_MacroKey" },
    Default = ClixAuto.macroKey,
    Callback = function(val)
        if type(val) == "table" and val.Key then ClixAuto.macroKey = val.Key
        elseif typeof(val) == "EnumItem" then ClixAuto.macroKey = val end
    end
})
featureBinds["MacroEquip"] = macroKeyBind
attachKeybindFallback(macroKeyBind)

local macroSilentToggle = autoRight:AddToggle({
    Label = "Macro Silent",
    Config = { "Combat_MacroSilent" },
    Default = ClixAuto.macroSilent,
    Callback = function(val)
        ClixAuto.macroSilent = val
    end
})
if macroSilentToggle then ClixAuto.macroSilent = macroSilentToggle.Value == true end

autoRight:AddDivider()

local shootDelaySlider = autoRight:AddSlider({
    Label = "Shoot Delay",
    Config = { "Combat_ShootDelay" },
    Min = 10,
    Max = 250,
    Step = 5,
    Default = ClixAuto.delay,
    Suffix = " ms",
    Callback = function(val)
        ClixAuto.delay = tonumber(val) or 20
    end
})
if shootDelaySlider then ClixAuto.delay = tonumber(shootDelaySlider.Value) or 20 end

unloadCombat = function()
    ClixAim.silent = false
    ClixAuto.autoShoot = false
    ClixAuto.triggerLegit = false
    ClixAuto.triggerHand = false
    ClixAuto.autoEquip = false
    if aimRenderConnection then pcall(function() aimRenderConnection:Disconnect() end); aimRenderConnection = nil end
    if autoHeartbeatConnection then pcall(function() autoHeartbeatConnection:Disconnect() end); autoHeartbeatConnection = nil end
    removeFovDrawings()
    if fovOverlayGui then pcall(function() fovOverlayGui:Destroy() end); fovOverlayGui = nil end
    if btEditor then pcall(function() btEditor:Destroy() end); btEditor = nil end
end
end


do
local playerTab = win:CreateTab("Player")
local movementTab = playerTab:CreateSubTab("Movement")
local characterTab = playerTab:CreateSubTab("Character")
local movCols = movementTab:CreateColumns("Fly", "Freecam / Speed")
local movementSection = movCols.left
local movSpeedSection = movCols.right
local charCols = characterTab:CreateColumns("Stealth", "Misc")
local characterSection = charCols.left
local charMiscSection = charCols.right
local flySpeedSlider
local spinSpeedSlider
local spinAngle = 0
local spinHumanoid
local flyRayParams = RaycastParams.new()
flyRayParams.FilterType = Enum.RaycastFilterType.Exclude
local wallPassOverlap = OverlapParams.new()
wallPassOverlap.FilterType = Enum.RaycastFilterType.Exclude










local function applyMovementValues()
    local humanoid = currentHumanoid()
    if not humanoid or humanoid.Health <= 0 then return end
    snapshotHumanoid(humanoid)
end

local refreshWallPass

local function destroyFlyForce()
    if flyForce then pcall(function() flyForce:Destroy() end) end
    if flyAttachment then pcall(function() flyAttachment:Destroy() end) end
    flyForce = nil
    flyAttachment = nil
    flyRoot = nil
end

local function ensureFlyForce(root)
    destroyFlyForce()
    flyRoot = root
end

local function stopFly()
    if flyConnection then pcall(function() flyConnection:Disconnect() end) end
    flyConnection = nil
    flyUpHeld = false
    flyDownHeld = false
    destroyFlyForce()
    if flyHumanoid and flyHumanoid.Parent then
        local original = movementSnapshots[flyHumanoid]
        pcall(function()
            flyHumanoid.PlatformStand = original and original.PlatformStand or false
            if not flyHumanoid.PlatformStand then
                flyHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
    flyHumanoid = nil
    flyPlatformStand = nil
    local character = currentCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if refreshWallPass then refreshWallPass() end
end

local function startFly()
    if flyConnection then return end
    flyConnection = trackConnection(RunService.Heartbeat:Connect(function(dt)
        if unloaded or not PlayerState.fly then return end
        local character = currentCharacter()
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then return end
        if humanoid ~= flyHumanoid then
            flyHumanoid = humanoid
            local original = snapshotHumanoid(humanoid)
            flyPlatformStand = original.PlatformStand
        end
        humanoid.PlatformStand = true
        destroyFlyForce()
        local camera = workspace.CurrentCamera
        local direction = Vector3.zero
        local forward = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
        local side = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
        if camera then
            if forward ~= 0 then direction += camera.CFrame.LookVector * forward end
            if side ~= 0 then direction += camera.CFrame.RightVector * side end
        else
            if forward ~= 0 then direction += root.CFrame.LookVector * forward end
            if side ~= 0 then direction += root.CFrame.RightVector * side end
        end
        if UserInputService.TouchEnabled and forward == 0 and side == 0 and humanoid.MoveDirection.Magnitude > 0.05 then
            local moveDirection = humanoid.MoveDirection
            if camera then
                local look = camera.CFrame.LookVector
                local flatForward = Vector3.new(look.X, 0, look.Z)
                local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
                if flatForward.Magnitude > 0.001 and flatRight.Magnitude > 0.001 then
                    local moveForward = math.clamp(moveDirection:Dot(flatForward.Unit), -1, 1)
                    local moveSide = math.clamp(moveDirection:Dot(flatRight.Unit), -1, 1)
                    direction += flatForward.Unit * moveForward + flatRight.Unit * moveSide
                    if math.abs(moveForward) > 0.05 then direction += Vector3.new(0, look.Y * moveForward, 0) end
                else
                    direction += moveDirection
                end
            else
                direction += moveDirection
            end
        end
        local jumpUp = UserInputService.TouchEnabled and os.clock() < flyMobileJumpUntil
        local rise = flyUpHeld or jumpUp or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA)
        local fall = flyDownHeld or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonB)
        if rise then direction += Vector3.new(0, 1, 0) end
        if fall then direction -= Vector3.new(0, 1, 0) end
        local speed = math.clamp(math.floor(tonumber(PlayerState.flySpeed) or 60), 1, 500)
        local delta = direction.Magnitude > 0.001 and direction.Unit * speed * math.max(tonumber(dt) or 0, 0) or Vector3.zero
        if delta.Magnitude > 0 then root.CFrame = CFrame.new(root.Position + delta) * root.CFrame.Rotation end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if dt and root.Anchored then pcall(function() root.Anchored = false end) end
    end))
    if refreshWallPass then refreshWallPass() end
end

local function setFlyState(on)
    PlayerState.fly = on == true
    syncToggleControl(flyToggle, PlayerState.fly)
    syncFeatureBind("Fly", PlayerState.fly)
    if PlayerState.fly then startFly() else stopFly() end
end

local flyMiniTweenToken = 0
local function setFlyMini(on)
    PlayerState.flyMini = on == true
    if not flyMiniGui then return end
    local panel = flyMiniGui:FindFirstChild("FlyControls")
    local flyScale = panel and panel:FindFirstChildOfClass("UIScale")
    if not panel or not flyScale then
        flyMiniGui.Enabled = PlayerState.flyMini
        return
    end
    flyMiniTweenToken = flyMiniTweenToken + 1
    local myToken = flyMiniTweenToken
    if PlayerState.flyMini then
        flyMiniGui.Enabled = true
        flyScale.Scale = 0.88
        panel.GroupTransparency = 1
        TweenService:Create(flyScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
    else
        local t1 = TweenService:Create(flyScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.86 })
        local t2 = TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
        t1:Play()
        t2:Play()
        task.spawn(function()
            t1.Completed:Wait()
            if flyMiniTweenToken == myToken then
                flyMiniGui.Enabled = false
                flyScale.Scale = 1
                panel.GroupTransparency = 0
            end
        end)
    end
end

local function setSpinState(on)
    PlayerState.spin = on == true
    syncToggleControl(spinToggle, PlayerState.spin)
    syncFeatureBind("Spinbot", PlayerState.spin)
    if PlayerState.spin and not spinConnection then
        spinConnection = trackConnection(RunService.Heartbeat:Connect(function(dt)
            if unloaded or not PlayerState.spin then return end
            local character = currentCharacter()
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not humanoid or not root or humanoid.Health <= 0 then return end
            local original = snapshotHumanoid(humanoid)
            humanoid.AutoRotate = false
            spinAngle = (spinAngle + (tonumber(dt) or 0) * math.clamp(PlayerState.spinSpeed, 180, 7200)) % 360
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(spinAngle), 0)
            root.AssemblyAngularVelocity = Vector3.zero
            spinHumanoid = humanoid
        end))
    elseif not PlayerState.spin and spinConnection then
        pcall(function() spinConnection:Disconnect() end)
        spinConnection = nil
        if spinHumanoid and spinHumanoid.Parent then
            local original = movementSnapshots[spinHumanoid]
            pcall(function()
                spinHumanoid.AutoRotate = original and original.AutoRotate or true
                local root = spinHumanoid.Parent:FindFirstChild("HumanoidRootPart")
                if root then root.AssemblyAngularVelocity = Vector3.zero end
            end)
        end
        spinHumanoid = nil
    end
end

local function setWallPassState(on)
    PlayerState.wallpass = on == true
    syncToggleControl(wallPassToggle, PlayerState.wallpass)
    syncFeatureBind("Wallpass", PlayerState.wallpass)
    if refreshWallPass then refreshWallPass() end
end

local function setSpeedState(on)
    PlayerState.speedSlide = on == true
    syncToggleControl(speedToggle, PlayerState.speedSlide)
    syncFeatureBind("SpeedLV", PlayerState.speedSlide)
    if PlayerState.speedSlide and not speedConnection then
        speedConnection = trackConnection(RunService.Heartbeat:Connect(function(dt)
            if unloaded or not PlayerState.speedSlide then return end
            local character = currentCharacter()
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if humanoid and root and humanoid.Health > 0 and humanoid.MoveDirection.Magnitude > 0 then
                root.CFrame = root.CFrame + humanoid.MoveDirection * math.clamp(tonumber(PlayerState.speedVal) or 16, 1, 100) * math.max(tonumber(dt) or 0, 0)
            end
        end))
    elseif not PlayerState.speedSlide and speedConnection then
        pcall(function() speedConnection:Disconnect() end)
        speedConnection = nil
    end
end

local function setInvisibleState(on)
    PlayerState.invisible = on == true
    syncToggleControl(invisibleToggle, PlayerState.invisible)
    syncFeatureBind("Invisible", PlayerState.invisible)
    if PlayerState.invisible then
        enableFEInvis(currentCharacter())
    else
        disableFEInvis()
    end
end

local function setAutoInvisState(on)
    PlayerState.autoInvis = on == true
    syncToggleControl(autoInvisToggle, PlayerState.autoInvis)
    if on and not PlayerState.invisible then
        setInvisibleState(true)
    end
end

stopFreecam = function()
    if freecamConnection then pcall(function() freecamConnection:Disconnect() end); freecamConnection = nil end
    if freecamInputBeganConn then pcall(function() freecamInputBeganConn:Disconnect() end); freecamInputBeganConn = nil end
    if freecamInputEndedConn then pcall(function() freecamInputEndedConn:Disconnect() end); freecamInputEndedConn = nil end
    if freecamInputChangedConn then pcall(function() freecamInputChangedConn:Disconnect() end); freecamInputChangedConn = nil end
    freecamKeys = {}
    freecamLookHeld = false
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
    pcall(function() UserInputService.MouseIconEnabled = true end)
    local saved = freecamSaved
    freecamSaved = nil
    if saved then
        local frozenRoot = saved.CharacterRoot
        if frozenRoot and frozenRoot.Parent then
            pcall(function()
                if saved.CharacterRootCFrame then frozenRoot.CFrame = saved.CharacterRootCFrame end
                frozenRoot.AssemblyLinearVelocity = Vector3.zero
                frozenRoot.AssemblyAngularVelocity = Vector3.zero
                frozenRoot.Anchored = saved.RootAnchored == true
            end)
        end
        local cam = workspace.CurrentCamera
        if cam then
            pcall(function() cam.CameraType = saved.CameraType end)
            pcall(function()
                local character = currentCharacter()
                local subject = saved.CameraSubject
                if saved.Character ~= character or not subject or not subject.Parent then
                    subject = character and character:FindFirstChildOfClass("Humanoid")
                end
                if subject then cam.CameraSubject = subject end
            end)
            pcall(function() cam.FieldOfView = saved.FieldOfView end)
            pcall(function() cam.CFrame = saved.CFrame end)
        end
    end
end

local function startFreecam()
    if freecamConnection then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local character = currentCharacter()
    local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
    freecamSaved = {
        CameraType = cam.CameraType,
        CameraSubject = cam.CameraSubject,
        FieldOfView = cam.FieldOfView,
        CFrame = cam.CFrame,
        Character = character,
        CharacterRoot = characterRoot,
        CharacterRootCFrame = characterRoot and characterRoot.CFrame,
        RootAnchored = characterRoot and characterRoot.Anchored,
    }
    if characterRoot then
        pcall(function()
            characterRoot.AssemblyLinearVelocity = Vector3.zero
            characterRoot.AssemblyAngularVelocity = Vector3.zero
            characterRoot.Anchored = true
        end)
    end
    local look = cam.CFrame.LookVector
    freecamYaw = math.atan2(-look.X, -look.Z)
    freecamPitch = math.asin(math.clamp(look.Y, -1, 1))
    freecamKeys = {}
    freecamLookHeld = false
    cam.CameraType = Enum.CameraType.Scriptable

    freecamInputBeganConn = trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freecamLookHeld = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            return
        end
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            freecamKeys[input.KeyCode] = true
        end
    end))
    freecamInputEndedConn = trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            freecamLookHeld = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            freecamKeys[input.KeyCode] = nil
        end
    end))
    freecamInputChangedConn = trackConnection(UserInputService.InputChanged:Connect(function(input)
        if freecamLookHeld and input.UserInputType == Enum.UserInputType.MouseMovement then
            freecamYaw = freecamYaw - input.Delta.X * 0.0025
            freecamPitch = math.clamp(freecamPitch - input.Delta.Y * 0.0025, math.rad(-85), math.rad(85))
        end
    end))
    freecamConnection = trackConnection(RunService.RenderStepped:Connect(function(dt)
        if unloaded or not PlayerState.freecam then return end
        local currentCam = workspace.CurrentCamera
        if not currentCam then return end
        currentCam.CameraType = Enum.CameraType.Scriptable
        local rotation = CFrame.fromOrientation(freecamPitch, freecamYaw, 0)
        local move = Vector3.zero
        if freecamKeys[Enum.KeyCode.W] then move += Vector3.new(0, 0, -1) end
        if freecamKeys[Enum.KeyCode.S] then move += Vector3.new(0, 0, 1) end
        if freecamKeys[Enum.KeyCode.A] then move += Vector3.new(-1, 0, 0) end
        if freecamKeys[Enum.KeyCode.D] then move += Vector3.new(1, 0, 0) end
        if freecamKeys[Enum.KeyCode.E] or freecamKeys[Enum.KeyCode.Space] then move += Vector3.new(0, 1, 0) end
        if freecamKeys[Enum.KeyCode.Q] or freecamKeys[Enum.KeyCode.LeftControl] then move += Vector3.new(0, -1, 0) end
        local position = currentCam.CFrame.Position
        local speed = math.clamp(tonumber(PlayerState.freecamSpeed) or 70, 1, 500)
        if move.Magnitude > 0 then
            position += rotation:VectorToWorldSpace(move.Unit) * speed * math.max(tonumber(dt) or 0, 0)
        end
        currentCam.CFrame = CFrame.new(position) * rotation
    end))
end

local function setFreecamState(on)
    PlayerState.freecam = on == true
    syncToggleControl(freecamToggle, PlayerState.freecam)
    syncFeatureBind("Freecam", PlayerState.freecam)
    if PlayerState.freecam then
        startFreecam()
    else
        stopFreecam()
    end
end

stopDesync = function()
    if desyncConnection then pcall(function() desyncConnection:Disconnect() end); desyncConnection = nil end
    if desyncJumpConn then pcall(function() desyncJumpConn:Disconnect() end); desyncJumpConn = nil end
    local hrp = desyncRoot
    desyncRoot, desyncHum = nil, nil
    desyncVelY, desyncGrounded = 0, true
    if hrp and hrp.Parent then
        pcall(function()
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function startDesync()
    if desyncConnection then return end
    local character = currentCharacter()
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    desyncRoot = hrp
    desyncHum = hum
    desyncVelY, desyncGrounded = 0, true
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Anchored = true
    end)
    desyncConnection = trackConnection(RunService.RenderStepped:Connect(function(dt)
        if unloaded or not PlayerState.desync then return end
        local root = desyncRoot
        if not (root and root.Parent) then
            setDesyncState(false)
            return
        end
        if not root.Anchored then pcall(function() root.Anchored = true end) end
        dt = tonumber(dt) or 0
        local moveDir = desyncHum and desyncHum.MoveDirection or Vector3.zero
        local speed = desyncHum and tonumber(desyncHum.WalkSpeed) or 16
        if not speed or speed <= 0 then speed = 16 end
        local cf = root.CFrame
        local pos = cf.Position
        if moveDir.Magnitude > 0.01 then
            local np = pos + (moveDir * speed * dt)
            cf = CFrame.lookAt(np, np + moveDir)
            pos = cf.Position
        end
        desyncVelY = desyncVelY - (workspace.Gravity * dt)
        local newY = pos.Y + (desyncVelY * dt)
        if not desyncRay then
            desyncRay = RaycastParams.new()
            desyncRay.FilterType = Enum.RaycastFilterType.Exclude
            desyncRay.IgnoreWater = true
        end
        local currentC = currentCharacter()
        desyncRay.FilterDescendantsInstances = currentC and { currentC } or {}
        local hit = workspace:Raycast(pos, Vector3.new(0, -200, 0), desyncRay)
        local floorY = hit and (hit.Position.Y + (desyncHum and desyncHum.HipHeight or 2) + (root.Size.Y / 2)) or nil
        if floorY and newY <= floorY then
            newY = floorY
            desyncVelY = 0
            desyncGrounded = true
        else
            desyncGrounded = false
        end
        cf = CFrame.new(pos.X, newY, pos.Z) * (cf - cf.Position)
        pcall(function() root.CFrame = cf end)
    end))
    desyncJumpConn = trackConnection(UserInputService.JumpRequest:Connect(function()
        if not (PlayerState.desync and desyncGrounded) then return end
        local h = desyncHum
        if h then
            local jp = 50
            if h.UseJumpPower then
                jp = tonumber(h.JumpPower) or jp
            else
                jp = math.sqrt(2 * workspace.Gravity * (tonumber(h.JumpHeight) or 7))
            end
            desyncVelY = jp
            desyncGrounded = false
        end
    end))
end

local function setDesyncState(on)
    PlayerState.desync = on == true
    syncToggleControl(desyncToggle, PlayerState.desync)
    syncFeatureBind("Desync", PlayerState.desync)
    if PlayerState.desync then
        startDesync()
    else
        stopDesync()
    end
end

refreshWallPass = function()
    local active = PlayerState.wallpass or PlayerState.fly
    if active and not wallPassConnection then
        wallPassConnection = trackConnection(RunService.Stepped:Connect(function()
            if unloaded then return end
            local character = currentCharacter()
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            wallPassOverlap.FilterDescendantsInstances = { character }
            for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, 6, wallPassOverlap)) do
                if part:IsA("BasePart") and part.CanCollide and not wallPassChanged[part] then
                    wallPassChanged[part] = part.CanCollide
                    part.CanCollide = false
                end
            end
            for part, originalCanCollide in pairs(wallPassChanged) do
                if not part.Parent then
                    wallPassChanged[part] = nil
                elseif not active or (part.Position - root.Position).Magnitude > 8 + part.Size.Magnitude / 2 then
                    pcall(function() part.CanCollide = originalCanCollide end)
                    wallPassChanged[part] = nil
                end
            end
        end))
    elseif not active then
        if wallPassConnection then pcall(function() wallPassConnection:Disconnect() end) end
        wallPassConnection = nil
        for part, originalCanCollide in pairs(wallPassChanged) do
            if part and part.Parent then pcall(function() part.CanCollide = originalCanCollide end) end
            wallPassChanged[part] = nil
        end
    end
end

local clickTpToggle

stopClickTp = function()
    if clickTpConnection then
        pcall(function() clickTpConnection:Disconnect() end)
        clickTpConnection = nil
    end
end

local function startClickTp()
    stopClickTp()
    clickTpConnection = trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or unloaded or not PlayerState.clickTp then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local char = currentCharacter()
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local currentCam = workspace.CurrentCamera
        if not currentCam then return end

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { char }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local unitRay = currentCam:ScreenPointToRay(input.Position.X, input.Position.Y)
        local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 10000, rayParams)
        if result then
            root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
            pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
        end
    end))
end

local function setClickTpState(on)
    PlayerState.clickTp = on == true
    syncToggleControl(clickTpToggle, PlayerState.clickTp)
    syncFeatureBind("ClickTP", PlayerState.clickTp)
    if PlayerState.clickTp then
        startClickTp()
    else
        stopClickTp()
    end
end

local function giveTpTool()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then return end
    local char = currentCharacter()
    local oldTool = backpack:FindFirstChild("Click TP Tool") or (char and char:FindFirstChild("Click TP Tool"))
    if oldTool then pcall(function() oldTool:Destroy() end) end

    local tool = Instance.new("Tool")
    tool.Name = "Click TP Tool"
    tool.RequiresHandle = false
    tool.CanBeDropped = false

    trackConnection(tool.Activated:Connect(function()
        local mouse = LocalPlayer:GetMouse()
        if not mouse then return end
        local c = currentCharacter()
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if r and mouse.Hit then
            r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
            pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)
        end
    end))

    tool.Parent = backpack
    win:Notify("Click TP Tool added to inventory", 2)
end

local function createFlyMiniGui()
    if flyMiniGui and flyMiniGui.Parent then
        flyMiniGui.Enabled = PlayerState.flyMini
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ClixFlyMiniGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10001
    gui.IgnoreGuiInset = true
    gui.Parent = safeParent or LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
    local panel = Instance.new("CanvasGroup")
    panel.Name = "FlyControls"
    panel.AnchorPoint = Vector2.new(1, 1)
    panel.Position = UDim2.new(1, -22, 1, -118)
    panel.Size = UDim2.fromOffset(216, 166)
    panel.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
    panel.BackgroundTransparency = 0.04
    panel.GroupTransparency = 0
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = gui
    local flyScale = Instance.new("UIScale", panel)
    flyScale.Scale = 1
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
    local panelStroke = Instance.new("UIStroke", panel)
    panelStroke.Color = Color3.fromRGB(92, 104, 150)
    panelStroke.Transparency = 0.35
    panelStroke.Thickness = 1
    local panelGradient = Instance.new("UIGradient", panel)
    panelGradient.Color = ColorSequence.new(Color3.fromRGB(29, 31, 43), Color3.fromRGB(14, 15, 20))
    panelGradient.Rotation = 90
    local header = Instance.new("TextButton")
    header.Name = "DragHandle"
    header.BackgroundTransparency = 1
    header.Position = UDim2.fromOffset(12, 8)
    header.Size = UDim2.new(1, -24, 0, 25)
    header.Text = ""
    header.AutoButtonColor = false
    header.ZIndex = 3
    header.Parent = panel
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.new(1, -72, 0, 20)
    title.Text = "FLY  /  CONTROLS"
    title.TextColor3 = Color3.fromRGB(240, 240, 248)
    title.TextSize = 11
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
    status.BackgroundTransparency = 0.1
    status.Position = UDim2.new(1, -58, 0, 9)
    status.Size = UDim2.fromOffset(46, 18)
    status.TextColor3 = Color3.fromRGB(180, 185, 205)
    status.TextSize = 9
    status.Font = Enum.Font.GothamBold
    status.Text = "OFF"
    status.ZIndex = 4
    status.Parent = panel
    Instance.new("UICorner", status).CornerRadius = UDim.new(1, 0)
    local function makeButton(name, label, position, size)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Position = position
        button.Size = size
        button.BackgroundColor3 = Color3.fromRGB(35, 38, 51)
        button.BackgroundTransparency = 0.05
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Text = label
        button.TextColor3 = Color3.fromRGB(245, 245, 250)
        button.TextSize = 12
        button.Font = Enum.Font.GothamBold
        button.Parent = panel
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", button)
        stroke.Color = Color3.fromRGB(72, 76, 98)
        stroke.Transparency = 0.5
        stroke.Thickness = 1
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(54, 61, 86)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.16), {Transparency = 0.15}):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(35, 38, 51)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
        end)
        return button
    end
    local toggleButton = makeButton("ToggleFly", "FLY OFF", UDim2.fromOffset(12, 39), UDim2.fromOffset(192, 30))
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "Speed"
    speedLabel.BackgroundTransparency = 1
    speedLabel.Position = UDim2.fromOffset(74, 76)
    speedLabel.Size = UDim2.fromOffset(68, 20)
    speedLabel.TextColor3 = Color3.fromRGB(230, 230, 238)
    speedLabel.TextSize = 11
    speedLabel.Font = Enum.Font.GothamMedium
    speedLabel.Parent = panel
    local slower = makeButton("Slower", "−", UDim2.fromOffset(12, 73), UDim2.fromOffset(48, 26))
    local faster = makeButton("Faster", "+", UDim2.fromOffset(160, 73), UDim2.fromOffset(44, 26))
    local upButton = makeButton("FlyUp", "▲  RISE", UDim2.fromOffset(12, 111), UDim2.fromOffset(92, 32))
    local downButton = makeButton("FlyDown", "▼  DESCEND", UDim2.fromOffset(112, 111), UDim2.fromOffset(92, 32))
    local function refresh()
        toggleButton.Text = PlayerState.fly and "FLY ON" or "FLY OFF"
        speedLabel.Text = "Speed " .. tostring(math.floor(PlayerState.flySpeed))
        status.Text = PlayerState.fly and "ON" or "OFF"
        status.BackgroundColor3 = PlayerState.fly and Color3.fromRGB(46, 132, 96) or Color3.fromRGB(45, 48, 62)
        status.TextColor3 = PlayerState.fly and Color3.fromRGB(220, 255, 235) or Color3.fromRGB(180, 185, 205)
        toggleButton.BackgroundColor3 = PlayerState.fly and Color3.fromRGB(48, 96, 82) or Color3.fromRGB(35, 38, 51)
    end
    toggleButton.Activated:Connect(function()
        if flyToggle then flyToggle:Set(not PlayerState.fly) else setFlyState(not PlayerState.fly) end
        refresh()
    end)
    slower.Activated:Connect(function()
        if flySpeedSlider then flySpeedSlider:Set(math.max(1, PlayerState.flySpeed - 1)) end
    end)
    faster.Activated:Connect(function()
        if flySpeedSlider then flySpeedSlider:Set(math.min(500, PlayerState.flySpeed + 1)) end
    end)
    upButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then flyUpHeld = true end
    end)
    upButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then flyUpHeld = false end
    end)
    downButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then flyDownHeld = true end
    end)
    downButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then flyDownHeld = false end
    end)
    trackConnection(UserInputService.JumpRequest:Connect(function()
        if PlayerState.fly and UserInputService.TouchEnabled then flyMobileJumpUntil = os.clock() + 0.25 end
    end))
    local dragging, dragStart, dragPosition = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragStart = input.Position
        dragPosition = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end)
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging or not dragStart or not dragPosition then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(dragPosition.X.Scale, dragPosition.X.Offset + delta.X, dragPosition.Y.Scale, dragPosition.Y.Offset + delta.Y)
    end))
    flyMiniGui = gui
    gui.Enabled = PlayerState.flyMini
    refresh()
end

local function addFeatureKeybind(section, label, registrationKey, keyConfig, setter)
    local bind = section._raw:AddKeybind({
        Label = label .. " Key",
        RegistrationKey = registrationKey,
        Default = { Mode = "Toggle" },
        ConfigMap = { Key = { keyConfig .. "Key" }, Mode = { keyConfig .. "KeyMode" } },
        Modes = { "Toggle" },
        InKeybindList = true,
        ListLabel = label
    })
    if bind then
        featureBinds[registrationKey] = bind
        bind:SetFeatureEnabled(true)
        attachKeybindFallback(bind)
        trackConnection(bind.ActiveChanged:Connect(function(active)
            setter(active == true)
        end))
    end
    return bind
end

local characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(character)
    task.defer(function()
        if unloaded then return end
        if PlayerState.freecam then stopFreecam(); setFreecamState(false) end
        if PlayerState.desync then stopDesync(); setDesyncState(false) end
        local humanoid = character:WaitForChild("Humanoid", 8)
        if not humanoid or unloaded then return end
        snapshotHumanoid(humanoid)
        applyMovementValues()
        if PlayerState.autoInvis then
            task.delay(2.6, function()
                if unloaded then return end
                local ch = LocalPlayer.Character
                if ch == character and ch.Parent and character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").Health > 0 then
                    setInvisibleState(true)
                end
            end)
        elseif PlayerState.invisible then
            setInvisibleState(true)
        end
        if PlayerState.fly then startFly() end
        if refreshWallPass then refreshWallPass() end
    end)
end)
trackConnection(characterAddedConnection)

flyToggle = movementSection:AddToggle({
    Label = "Fly",
    Config = { "Fly" },
    Default = PlayerState.fly,
    Tooltip = "Fly with WASD and Space or use the mobile joystick and fly controls.",
    Callback = setFlyState
})
addFeatureKeybind(movementSection, "Fly", "Fly", "Fly", setFlyState)
local flyMiniToggle = movementSection:AddToggle({
    Label = "Fly Mini Controls",
    Config = { "FlyMiniControls" },
    Default = PlayerState.flyMini,
    Tooltip = "Show the floating mobile flight controls.",
    Callback = setFlyMini
})
flySpeedSlider = movementSection:AddSlider({
    Label = "Fly Speed",
    Config = { "FlySpeed" },
    Min = 1,
    Max = 500,
    Step = 1,
    Default = PlayerState.flySpeed,
    Callback = function(value)
        PlayerState.flySpeed = math.clamp(math.floor(tonumber(value) or 60), 1, 500)
        if flyMiniGui then
            local speedLabel = flyMiniGui:FindFirstChild("FlyControls") and flyMiniGui.FlyControls:FindFirstChild("Speed")
            if speedLabel then speedLabel.Text = "Speed " .. tostring(PlayerState.flySpeed) end
        end
    end
})

freecamToggle = movSpeedSection:AddToggle({
    Label = "Freecam",
    Config = { "Freecam" },
    Default = PlayerState.freecam,
    Tooltip = "Freecam moves only the camera while keeping character in place. Hold RMB to look around.",
    Callback = setFreecamState
})
addFeatureKeybind(movSpeedSection, "Freecam", "Freecam", "Freecam", setFreecamState)
freecamSpeedSlider = movSpeedSection:AddSlider({
    Label = "Freecam Speed",
    Config = { "FreecamSpeed" },
    Min = 10,
    Max = 300,
    Step = 5,
    Default = PlayerState.freecamSpeed,
    Callback = function(value)
        PlayerState.freecamSpeed = math.clamp(math.floor(tonumber(value) or 70), 10, 300)
    end
})

speedToggle = movSpeedSection:AddToggle({
    Label = "Speed (LV)",
    Config = { "SpeedLV" },
    Default = PlayerState.speedSlide,
    Callback = setSpeedState
})
addFeatureKeybind(movSpeedSection, "Speed (LV)", "SpeedLV", "SpeedLV", setSpeedState)
local speedSlider = movSpeedSection:AddSlider({
    Label = "Speed",
    Config = { "SpeedValue" },
    Min = 1,
    Max = 100,
    Step = 1,
    Default = PlayerState.speedVal,
    Suffix = " studs",
    Callback = function(value)
        PlayerState.speedVal = math.clamp(math.floor(tonumber(value) or 16), 1, 100)
    end
})

invisibleToggle = characterSection:AddToggle({
    Label = "Invisible",
    Config = { "Invisible" },
    Default = PlayerState.invisible,
    Callback = setInvisibleState
})
addFeatureKeybind(characterSection, "Invisible", "Invisible", "Invisible", setInvisibleState)

autoInvisToggle = characterSection:AddToggle({
    Label = "Auto Invisible",
    Config = { "AutoInvisible" },
    Default = PlayerState.autoInvis,
    Tooltip = "Automatically enables invisibility whenever you respawn.",
    Callback = setAutoInvisState
})

desyncToggle = characterSection:AddToggle({
    Label = "Desync",
    Config = { "Desync" },
    Default = PlayerState.desync,
    Tooltip = "Simulates movement client-side while anchoring root part.",
    Callback = setDesyncState
})
addFeatureKeybind(characterSection, "Desync", "Desync", "Desync", setDesyncState)

spinToggle = charMiscSection:AddToggle({
    Label = "Spinbot",
    Config = { "Spinbot" },
    Default = PlayerState.spin,
    Callback = setSpinState
})
addFeatureKeybind(charMiscSection, "Spinbot", "Spinbot", "Spinbot", setSpinState)
spinSpeedSlider = charMiscSection:AddSlider({
    Label = "Spin Speed",
    Config = { "SpinSpeed" },
    Min = 180,
    Max = 7200,
    Step = 180,
    Default = PlayerState.spinSpeed,
    Suffix = " deg/s",
    Callback = function(value)
        PlayerState.spinSpeed = math.clamp(math.floor(tonumber(value) or 720), 180, 7200)
    end
})
wallPassToggle = charMiscSection:AddToggle({
    Label = "WALLPASS",
    Config = { "Wallpass" },
    Default = PlayerState.wallpass,
    Tooltip = "Temporarily disables collision on nearby walls and obstacles.",
    Callback = setWallPassState
})
addFeatureKeybind(charMiscSection, "WALLPASS", "Wallpass", "Wallpass", setWallPassState)

clickTpToggle = charMiscSection:AddToggle({
    Label = "Click TP",
    Config = { "ClickTP" },
    Default = PlayerState.clickTp,
    Tooltip = "Teleports your character to the clicked location in the world.",
    Callback = setClickTpState
})
addFeatureKeybind(charMiscSection, "Click TP", "ClickTP", "ClickTP", setClickTpState)

charMiscSection:AddButton({
    Label = "Give TP Tool",
    Tooltip = "Adds a teleport tool to your inventory.",
    Callback = giveTpTool
})

if flyToggle then PlayerState.fly = flyToggle.Value == true end
if flyMiniToggle then PlayerState.flyMini = flyMiniToggle.Value == true end
if flySpeedSlider then PlayerState.flySpeed = math.clamp(math.floor(tonumber(flySpeedSlider.Value) or 60), 1, 500) end
if freecamToggle then PlayerState.freecam = freecamToggle.Value == true end
if freecamSpeedSlider then PlayerState.freecamSpeed = math.clamp(math.floor(tonumber(freecamSpeedSlider.Value) or 70), 10, 300) end
if speedToggle then PlayerState.speedSlide = speedToggle.Value == true end
if speedSlider then PlayerState.speedVal = math.clamp(math.floor(tonumber(speedSlider.Value) or 16), 1, 100) end
if invisibleToggle then PlayerState.invisible = invisibleToggle.Value == true end
if autoInvisToggle then PlayerState.autoInvis = autoInvisToggle.Value == true end
if desyncToggle then PlayerState.desync = desyncToggle.Value == true end
if spinToggle then PlayerState.spin = spinToggle.Value == true end
if spinSpeedSlider then PlayerState.spinSpeed = math.clamp(math.floor(tonumber(spinSpeedSlider.Value) or 720), 180, 7200) end
if wallPassToggle then PlayerState.wallpass = wallPassToggle.Value == true end
if clickTpToggle then PlayerState.clickTp = clickTpToggle.Value == true end

syncFeatureBind("Fly", PlayerState.fly)
syncFeatureBind("Freecam", PlayerState.freecam)
syncFeatureBind("SpeedLV", PlayerState.speedSlide)
syncFeatureBind("Invisible", PlayerState.invisible)
syncFeatureBind("Desync", PlayerState.desync)
syncFeatureBind("Spinbot", PlayerState.spin)
syncFeatureBind("Wallpass", PlayerState.wallpass)
syncFeatureBind("ClickTP", PlayerState.clickTp)

createFlyMiniGui()
applyMovementValues()
if PlayerState.fly then startFly() end
if PlayerState.freecam then startFreecam() end
if PlayerState.desync then startDesync() end
if PlayerState.spin then setSpinState(true) end
if PlayerState.speedSlide then setSpeedState(true) end
if PlayerState.invisible then setInvisibleState(true) end
if PlayerState.clickTp then startClickTp() end
refreshWallPass()

trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not PlayerState.fly then return end
    if input.KeyCode == Enum.KeyCode.Space and UserInputService.TouchEnabled then flyUpHeld = true end
end))
trackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then flyUpHeld = false end
end))

end

updateEsp()
win:Notify("Clix loaded", 3)

do
local teleportTab = win:CreateTab("Teleport")
local padsSubTab = teleportTab:CreateSubTab("Duel Pads")
local resultsSubTab = teleportTab:CreateSubTab("Results")
local padCols = padsSubTab:CreateColumns("Auto Walk", "Pad Selector")
local tpLeft = padCols.left
local tpRight = padCols.right
local resultCols = resultsSubTab:CreateColumns("Auto Close", "Close Config")
local tpResultLeft = resultCols.left
local tpResultRight = resultCols.right

local TeleportState = {
    main = false,
    alt = false,
    closeResults = false,
    closeRanked = true,
    closeDelay = 0.5,
    duelType = "1v1",
    row = "Left",
    speedLv = 40
}
local syncTeleportMonitor
local syncCloseResults
local tpCloseRunning = false
local tpCloseToken = 0
local tpCloseHooks = {}
local tpLastClose = 0
local tpHookedStats = false
local tpHookedRanked = false

do
local tpToken = 0
local tpWalking = false
local tpSavedSpeed = nil
local tpSavedHum = nil
local tpPadCache = { key = nil, pad = nil, at = 0 }
local tpMonitorRunning = false
local tpMonitorToken = 0

local tpMainToggle, tpAltToggle, tpCloseToggle
local tpDuelDropdown, tpRowDropdown

local function tpEnabled()
    return TeleportState.main == true or TeleportState.alt == true
end



local function stopTeleportWalk()
    tpToken = tpToken + 1
    tpWalking = false
    tpSavedHum = nil
    tpSavedSpeed = nil
end

local function getSelectedTeleportPad()
    local duelNumber = tonumber(string.match(tostring(TeleportState.duelType or "1v1"), "%d+")) or 1
    local wantedZ = (TeleportState.row == "Left") and 0 or 32
    local padName = TeleportState.main and "Pad2" or (TeleportState.alt and "Pad1" or nil)
    if not padName then return nil end
    local cacheKey = tostring(padName) .. "|" .. tostring(duelNumber) .. "|" .. tostring(wantedZ)
    local now = os.clock()
    if tpPadCache.key == cacheKey and now - tpPadCache.at < 1.0 then
        if tpPadCache.pad and tpPadCache.pad.Parent then return tpPadCache.pad end
    end
    local char = currentCharacter()
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local bestPad, bestDistance = nil, math.huge

    local function considerPad(pad)
        if not pad or not pad:IsA("BasePart") then return end
        local zOk = math.abs(pad.Position.Z - wantedZ) <= 12
        if not zOk and wantedZ == 32 and pad.Position.Z > 16 then zOk = true end
        if not zOk and wantedZ == 0 and pad.Position.Z < 16 then zOk = true end
        if not zOk then return end
        local distance = root and (root.Position - pad.Position).Magnitude or 0
        if distance < bestDistance then
            bestDistance = distance
            bestPad = pad
        end
    end

    local zones = workspace:FindFirstChild("PadZones")
        or workspace:FindFirstChild("Pads")
        or workspace:FindFirstChild("DuelPads")
    if zones then
        for _, zone in ipairs(zones:GetChildren()) do
            local cfg = zone:FindFirstChild("cfg") or zone:FindFirstChild("Config")
            local maxPlayers = cfg and (cfg:FindFirstChild("MaxPlayersEachPad") or cfg:FindFirstChild("MaxPlayers"))
            local maxVal = maxPlayers and tonumber(maxPlayers.Value)
            local duelOk = (not maxVal) or (maxVal == duelNumber)
            if duelOk then
                local selectedModel = zone:FindFirstChild(padName)
                if selectedModel then
                    considerPad(selectedModel:FindFirstChild("Pad") or (selectedModel:IsA("BasePart") and selectedModel))
                end
                for _, d in ipairs(zone:GetDescendants()) do
                    if d.Name == "Pad" and d:IsA("BasePart") then
                        local parent = d.Parent
                        if parent and (parent.Name == padName or parent.Name:find(padName)) then
                            considerPad(d)
                        end
                    end
                end
            end
        end
    end

    if not bestPad then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and (d.Name == "Pad" or d.Name == padName) then
                considerPad(d)
            end
        end
    end

    tpPadCache.key = cacheKey
    tpPadCache.pad = bestPad
    tpPadCache.at = os.clock()
    return bestPad
end

local function startTeleportWalk()
    if tpWalking then return end
    if isMatchActive() then return end
    local char = currentCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local targetPad = getSelectedTeleportPad()
    if not char or not hum or not root or hum.Health <= 0 or not targetPad then return end
    tpToken = tpToken + 1
    local token = tpToken
    tpWalking = true
    tpSavedHum = hum
    task.spawn(function()
        local stuck = 0
        local lastPos = root.Position
        while token == tpToken and tpEnabled()
            and not isMatchActive() and hum.Parent and hum.Health > 0 do
            char = currentCharacter()
            hum = char and char:FindFirstChildOfClass("Humanoid")
            root = char and char:FindFirstChild("HumanoidRootPart")
            targetPad = getSelectedTeleportPad()
            if not targetPad or not root or not hum then break end
            local targetPosition = targetPad.Position + Vector3.new(0, 3, 0)
            local dist = (root.Position - targetPosition).Magnitude
            if dist <= 5 then break end
            local speed = math.clamp(tonumber(TeleportState.speedLv) or 40, 1, 100)
            local direction = targetPosition - root.Position
            local step = math.min(speed * 0.08, dist)
            if direction.Magnitude > 0.001 then root.CFrame = CFrame.new(root.Position + direction.Unit * step) * root.CFrame.Rotation end
            task.wait(0.08)
            if root and (root.Position - lastPos).Magnitude < 0.35 then
                stuck = stuck + 1
                if stuck >= 6 then
                    pcall(function()
                        local dir = Vector3.new(targetPosition.X - root.Position.X, 0, targetPosition.Z - root.Position.Z)
                        if dir.Magnitude > 0.1 then
                            root.CFrame = root.CFrame + dir.Unit * 3
                        end
                    end)
                    stuck = 0
                end
            else
                stuck = 0
            end
            lastPos = root and root.Position or lastPos
        end
        if token == tpToken then
            tpWalking = false
            tpSavedHum = nil
            tpSavedSpeed = nil
        end
    end)
end

syncTeleportMonitor = function()
    local want = tpEnabled() and not unloaded
    if want and not tpMonitorRunning then
        tpMonitorRunning = true
        tpMonitorToken = tpMonitorToken + 1
        local token = tpMonitorToken
        if not isMatchActive() and not tpWalking then startTeleportWalk() end
        task.spawn(function()
            while token == tpMonitorToken and tpMonitorRunning and tpEnabled() and not unloaded do
                if isMatchActive() then
                    if tpWalking then stopTeleportWalk() end
                elseif not tpWalking then
                    startTeleportWalk()
                end
                task.wait(0.2)
            end
            if token == tpMonitorToken then tpMonitorRunning = false end
        end)
    elseif not want and tpMonitorRunning then
        tpMonitorRunning = false
        tpMonitorToken = tpMonitorToken + 1
        stopTeleportWalk()
    elseif not want and tpWalking then
        stopTeleportWalk()
    end
end


end

do
local function fireCloseButton(closeBtn)
    if not closeBtn then return false end
    local fired = false
    pcall(function()
        if getconnections then
            for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
                local sig = closeBtn[sigName]
                if sig then
                    local conns = getconnections(sig)
                    if conns then
                        for _, c in ipairs(conns) do
                            if c and c.Function then
                                task.spawn(c.Function)
                                fired = true
                            elseif c and c.Fire then
                                pcall(function() c:Fire() end)
                                fired = true
                            end
                        end
                    end
                end
                if fired then break end
            end
        end
        if not fired then
            pcall(function() closeBtn:Activate() end)
            if firesignal then
                pcall(function() firesignal(closeBtn.Activated) end)
                pcall(function() firesignal(closeBtn.MouseButton1Click) end)
            end
            fired = true
        end
    end)
    return fired
end

local function getGameStats()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local mg = main and main:FindFirstChild("MainGameFrame")
    return mg and mg:FindFirstChild("GameStats") or nil
end

local function getRankedResults()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local newGui = pg and pg:FindFirstChild("NewGui")
    local results = newGui and newGui:FindFirstChild("MatchResults")
    if results and results:IsA("GuiObject") then return results end
    return nil
end

local function clickGameStatsClose()
    local ok, fired = pcall(function()
        local stats = getGameStats()
        if not stats then return false end
        local header = stats:FindFirstChild("Header")
        local closeBtn = header and header:FindFirstChild("CloseButton")
        if not closeBtn then closeBtn = stats:FindFirstChild("CloseButton", true) end
        return fireCloseButton(closeBtn)
    end)
    return ok and fired == true
end

local function clickRankedResultsClose()
    local ok, fired = pcall(function()
        local results = getRankedResults()
        if not results or not results.Visible then return false end
        local header = results:FindFirstChild("Header")
        local closeBtn = header and header:FindFirstChild("Close")
        if not closeBtn then closeBtn = results:FindFirstChild("Close", true) end
        return fireCloseButton(closeBtn)
    end)
    return ok and fired == true
end

local function scheduleClose(kind, target)
    if not TeleportState.closeResults or not target or not target.Visible then return end
    local now = os.clock()
    if now - tpLastClose <= 0.4 then return end
    tpLastClose = now
    task.delay(0.1, function()
        if not TeleportState.closeResults or not target.Parent or not target.Visible then return end
        if kind == "ranked" then
            clickRankedResultsClose()
        else
            clickGameStatsClose()
        end
    end)
end

local function tryHookVisible()
    pcall(function()
        local stats = getGameStats()
        if stats and not tpHookedStats then
            tpHookedStats = true
            tpCloseHooks[#tpCloseHooks + 1] = stats:GetPropertyChangedSignal("Visible"):Connect(function()
                scheduleClose("legacy", stats)
            end)
        end
        local ranked = getRankedResults()
        if ranked and not tpHookedRanked then
            tpHookedRanked = true
            tpCloseHooks[#tpCloseHooks + 1] = ranked:GetPropertyChangedSignal("Visible"):Connect(function()
                scheduleClose("ranked", ranked)
            end)
        end
    end)
end

local function checkVisibleResults()
    tryHookVisible()
    local stats = getGameStats()
    if stats and stats.Visible and os.clock() - tpLastClose > 0.5 then
        scheduleClose("legacy", stats)
    end
    local ranked = getRankedResults()
    if ranked and ranked.Visible and os.clock() - tpLastClose > 0.5 then
        scheduleClose("ranked", ranked)
    end
end

syncCloseResults = function()
    local want = TeleportState.closeResults == true and not unloaded
    if want and not tpCloseRunning then
        tpCloseRunning = true
        tpCloseToken = tpCloseToken + 1
        local token = tpCloseToken
        checkVisibleResults()
        task.spawn(function()
            while token == tpCloseToken and tpCloseRunning and TeleportState.closeResults and not unloaded do
                task.wait(0.35)
                if token == tpCloseToken and TeleportState.closeResults then
                    checkVisibleResults()
                end
            end
            if token == tpCloseToken then tpCloseRunning = false end
        end)
    elseif not want and tpCloseRunning then
        tpCloseRunning = false
        tpCloseToken = tpCloseToken + 1
        for i = #tpCloseHooks, 1, -1 do
            pcall(function() tpCloseHooks[i]:Disconnect() end)
            tpCloseHooks[i] = nil
        end
        tpHookedStats, tpHookedRanked = false, false
    end
end

tpMainToggle = tpLeft:AddToggle({
    Label = "Auto Teleport Main",
    Config = { "TPAutoMain" },
    Default = TeleportState.main,
    Tooltip = "Moves to the blue platform with private CFrame speed when no match is running.",
    Callback = function(on)
        on = on == true
        TeleportState.main = on
        if on and TeleportState.alt then
            TeleportState.alt = false
            if tpAltToggle and type(tpAltToggle.Set) == "function" then tpAltToggle:Set(false) end
        end
        syncTeleportMonitor()
        if not tpEnabled() then stopTeleportWalk() end
    end
})

tpAltToggle = tpLeft:AddToggle({
    Label = "Auto Teleport Alt",
    Config = { "TPAutoAlt" },
    Default = TeleportState.alt,
    Tooltip = "Moves to the red platform with private CFrame speed when no match is running.",
    Callback = function(on)
        on = on == true
        TeleportState.alt = on
        if on and TeleportState.main then
            TeleportState.main = false
            if tpMainToggle and type(tpMainToggle.Set) == "function" then tpMainToggle:Set(false) end
        end
        syncTeleportMonitor()
        if not tpEnabled() then stopTeleportWalk() end
    end
})

tpLeft:AddDivider()

tpLeft:AddButton({
    Label = "Walk To Pad Now",
    Tooltip = "Starts walking to the selected pad immediately.",
    Callback = function()
        if isMatchActive() then
            win:Notify("Match in progress - pad walk skipped", 2)
            return
        end
        stopTeleportWalk()
        startTeleportWalk()
    end
})

tpLeft:AddButton({
    Label = "Stop Walking",
    Callback = function()
        stopTeleportWalk()
        win:Notify("Pad walk stopped", 2)
    end
})

tpDuelDropdown = tpRight:AddDropdown({
    Label = "Duel Type",
    Config = { "TPDuelType" },
    Options = { "1v1", "2v2", "3v3", "4v4" },
    Default = TeleportState.duelType,
    Tooltip = "Selects which pad set to walk to.",
    Callback = function(val)
        TeleportState.duelType = tostring(val or "1v1")
        if tpWalking then stopTeleportWalk() end
        if tpEnabled() and not isMatchActive() then task.defer(startTeleportWalk) end
    end
})

tpRowDropdown = tpRight:AddDropdown({
    Label = "Platform Row",
    Config = { "TPPlatformRow" },
    Options = { "Right", "Left" },
    Default = TeleportState.row,
    Tooltip = "Chooses the right or left platform row.",
    Callback = function(val)
        TeleportState.row = tostring(val or "Right")
        if tpWalking then stopTeleportWalk() end
        if tpEnabled() and not isMatchActive() then task.defer(startTeleportWalk) end
    end
})

local tpSpeedSlider = tpRight:AddSlider({
    Label = "Teleport Speed (LV)",
    Config = { "TPSpeedLV" },
    Min = 1,
    Max = 100,
    Step = 1,
    Default = TeleportState.speedLv,
    Suffix = " LV",
    Tooltip = "Private CFrame movement speed. WalkSpeed is not changed.",
    Callback = function(value) TeleportState.speedLv = math.clamp(math.floor(tonumber(value) or 40), 1, 100) end
})
if tpSpeedSlider then TeleportState.speedLv = math.clamp(math.floor(tonumber(tpSpeedSlider.Value) or 40), 1, 100) end

tpRight:AddDivider()

tpRight:AddButton({
    Label = "Reset Pad Cache",
    Callback = function()
        tpPadCache.key = nil
        tpPadCache.pad = nil
        win:Notify("Pad cache cleared", 2)
    end
})

tpCloseToggle = tpResultLeft:AddToggle({
    Label = "Auto Close Results",
    Config = { "TPCloseResults" },
    Default = TeleportState.closeResults,
    Tooltip = "Closes the match results window when it appears.",
    Callback = function(on)
        TeleportState.closeResults = on == true
        syncCloseResults()
    end
})

tpResultRight:AddButton({
    Label = "Close Game Stats",
    Callback = function()
        local ok = clickGameStatsClose()
        win:Notify(ok and "Game stats closed" or "Game stats not found", 2)
    end
})

tpResultRight:AddButton({
    Label = "Close Ranked Results",
    Callback = function()
        local ok = clickRankedResultsClose()
        win:Notify(ok and "Ranked results closed" or "Ranked results not found", 2)
    end
})

if tpMainToggle then TeleportState.main = tpMainToggle.Value == true end
if tpAltToggle then TeleportState.alt = tpAltToggle.Value == true end
if tpCloseToggle then TeleportState.closeResults = tpCloseToggle.Value == true end
if tpDuelDropdown and tpDuelDropdown.Value ~= nil then TeleportState.duelType = tostring(tpDuelDropdown.Value) end
if tpRowDropdown and tpRowDropdown.Value ~= nil then TeleportState.row = tostring(tpRowDropdown.Value) end

if TeleportState.main and TeleportState.alt then
    TeleportState.alt = false
    if tpAltToggle and type(tpAltToggle.Set) == "function" then tpAltToggle:Set(false) end
end

trackConnection(LocalPlayer.CharacterAdded:Connect(function()
    stopTeleportWalk()
end))

unloadTeleport = function()
    tpToken = tpToken + 1
    tpWalking = false
    tpMonitorRunning = false
    tpMonitorToken = tpMonitorToken + 1
    tpCloseRunning = false
    tpCloseToken = tpCloseToken + 1
    for i = #tpCloseHooks, 1, -1 do
        pcall(function() tpCloseHooks[i]:Disconnect() end)
        tpCloseHooks[i] = nil
    end
    if tpSavedHum and tpSavedHum.Parent and tpSavedSpeed then
        pcall(function() tpSavedHum.WalkSpeed = tpSavedSpeed end)
    end
    tpSavedHum = nil
    tpSavedSpeed = nil
end


end

syncTeleportMonitor()
syncCloseResults()
end

do
local eventoTab = win:CreateTab("Event")
local cofreSubTab   = eventoTab:CreateSubTab("Crate")
local eventoSubTab  = eventoTab:CreateSubTab("Event")
local cofreCols  = cofreSubTab:CreateColumns("Crate", "Inventory")
local cofreLeft  = cofreCols.left
local cofreRight = cofreCols.right
local eventoCols = eventoSubTab:CreateColumns("Auto-Collect", "Information")
local eventoLeft  = eventoCols.left
local eventoRight = eventoCols.right

local EventoState = {
    cofreAutoBuy      = false,
    cofreAutoOpen     = false,
    cofreSelectedBox  = "Knife Box #1",
    autoCollect       = false,
}

local BOX_NAMES = {
    "Knife Box #1", "Knife Box #2",
    "Gun Box #1",   "Gun Box #2",
    "Mythic Box #1","Mythic Box #2","Mythic Box #3","Mythic Box #4",
}

local crateWorkers = {}
local function stopCrateWorker(key)
    local t = crateWorkers[key]; crateWorkers[key] = nil
    if t then pcall(task.cancel, t) end
end

local function buySelectedBox()
    local ok, status = pcall(function()
        local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
        return Remotes.BuyCase:InvokeServer(EventoState.cofreSelectedBox)
    end)
    pcall(function()
        local gui = LocalPlayer.PlayerGui:FindFirstChild("Main")
        local frame = gui and gui:FindFirstChild("OpeningItemFrame")
        if frame then frame.Visible = false end
    end)
    return ok and status == "BOUGHT"
end

local function openOneCrate()
    pcall(function()
        local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
        local ClientGlobals = require(game:GetService("ReplicatedStorage").Client.Modules.ClientGlobals)
        local inventory = ClientGlobals.PlayerData:TryIndex({"Inventory", "Crate"})
        if type(inventory) ~= "table" then return end
        for guid, entry in pairs(inventory) do
            if type(entry) == "table" and type(entry.name) == "string" then
                local opened = Remotes.OpenCrate:InvokeServer(guid)
                if opened then
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("Main")
                    local frame = gui and gui:FindFirstChild("OpeningItemFrame")
                    if frame then frame.Visible = false end
                    return
                end
            end
        end
    end)
end

local function startCrateWorker(key)
    stopCrateWorker(key)
    crateWorkers[key] = task.spawn(function()
        while EventoState[key] and not unloaded do
            task.wait(1.0)
            if not EventoState[key] or unloaded then break end
            if key == "cofreAutoBuy" then
                local bought = buySelectedBox()
                if not bought then EventoState.cofreAutoBuy = false; break end
            else
                openOneCrate()
            end
        end
        crateWorkers[key] = nil
    end)
end

local COLLECT_FOLDER = "SpawnablesClient"
local collectRemote, lastRemoteTry = nil, 0
local collectQueue, collectQHead = {}, 1
local collectQueued = setmetatable({}, {__mode = "k"})
local collectCollected = setmetatable({}, {__mode = "k"})
local collectWorking = false
local collectWorkerGen = 0
local collectFolderConn, collectWsConn, collectWatchedFolder

local function getCollectRemote()
    if collectRemote and collectRemote.Parent and collectRemote:IsA("RemoteEvent") then return collectRemote end
    local now = os.clock()
    if now - lastRemoteTry < 2 then return nil end
    lastRemoteTry = now
    collectRemote = nil
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local net = rs:FindFirstChild("Packages") and rs.Packages:FindFirstChild("Networking")
        local c = net and (net:FindFirstChild("RE/Events/CollectEventSpawnable") or net:FindFirstChild("CollectEventSpawnable"))
        if c and c:IsA("RemoteEvent") then collectRemote = c end
    end)
    return collectRemote
end

local function collectClearQueue()
    for i = collectQHead, #collectQueue do
        local item = collectQueue[i]; if item then collectQueued[item] = nil end
    end
    collectQueue, collectQHead = {}, 1
end

local function collectProcess(token)
    while not unloaded and token == collectWorkerGen do
        if not EventoState.autoCollect then collectClearQueue(); break end
        local spawn = collectQueue[collectQHead]
        if not spawn then collectClearQueue(); break end
        collectQHead = collectQHead + 1
        collectQueued[spawn] = nil
        if spawn.Parent and not collectCollected[spawn] then
            local r = getCollectRemote()
            if r then
                local ok = pcall(function() r:FireServer() end)
                if ok then
                    collectCollected[spawn] = true
                    pcall(function() if spawn.Parent then spawn:Destroy() end end)
                end
            else
                collectQHead = collectQHead - 1
                collectQueue[collectQHead] = spawn
                collectQueued[spawn] = true
                task.wait(0.25)
            end
        end
        task.wait(0.18)
    end
    if token == collectWorkerGen then collectWorking = false end
end

local function collectEnqueue(spawn)
    if unloaded or not EventoState.autoCollect or not spawn then return end
    if collectCollected[spawn] or collectQueued[spawn] or not spawn.Parent then return end
    if (#collectQueue - collectQHead + 1) >= 96 then return end
    collectQueue[#collectQueue + 1] = spawn
    collectQueued[spawn] = true
    if not collectWorking then
        collectWorking = true
        collectWorkerGen = collectWorkerGen + 1
        local token = collectWorkerGen
        task.spawn(function() collectProcess(token) end)
    end
end

local function collectAttach(folder)
    if not folder or not folder.Parent then return end
    if collectWatchedFolder ~= folder then
        if collectFolderConn then pcall(function() collectFolderConn:Disconnect() end) end
        collectWatchedFolder = folder
        collectFolderConn = trackConnection(folder.ChildAdded:Connect(collectEnqueue))
    end
    for _, spawn in ipairs(folder:GetChildren()) do collectEnqueue(spawn) end
end

local function startAutoCollect()
    if not EventoState.autoCollect or unloaded then return end
    local folder = workspace:FindFirstChild(COLLECT_FOLDER)
    if folder then collectAttach(folder) end
end

collectWsConn = trackConnection(workspace.ChildAdded:Connect(function(ch)
    if ch.Name == COLLECT_FOLDER and EventoState.autoCollect and not unloaded then collectAttach(ch) end
end))



local cofreBoxDropdown = cofreLeft:AddDropdown({
    Label   = "Box to Buy",
    Config  = { "CofreBox" },
    Options = BOX_NAMES,
    Default = EventoState.cofreSelectedBox,
    Callback = function(val) EventoState.cofreSelectedBox = tostring(val) end
})

cofreLeft:AddToggle({
    Label    = "Auto-Buy Box",
    Config   = { "CofreAutoBuy" },
    Default  = false,
    Tooltip  = "Automatically buys the selected box every second.",
    Callback = function(on)
        EventoState.cofreAutoBuy = on
        if on then startCrateWorker("cofreAutoBuy") else stopCrateWorker("cofreAutoBuy") end
    end
})

cofreLeft:AddButton({
    Label    = "Buy Box Now",
    Callback = function()
        local bought = buySelectedBox()
        win:Notify(bought and "Box purchased!" or "Could not purchase.", 2)
    end
})

cofreRight:AddToggle({
    Label    = "Auto-Open Crates",
    Config   = { "CofreAutoOpen" },
    Default  = false,
    Tooltip  = "Automatically opens crates in your inventory.",
    Callback = function(on)
        EventoState.cofreAutoOpen = on
        if on then startCrateWorker("cofreAutoOpen") else stopCrateWorker("cofreAutoOpen") end
    end
})

cofreRight:AddButton({
    Label    = "Open Crate Now",
    Callback = function() openOneCrate() end
})

eventoLeft:AddToggle({
    Label    = "Auto-Collect",
    Config   = { "AutoCollect" },
    Default  = false,
    Tooltip  = "Automatically collects event drops.",
    Callback = function(on)
        EventoState.autoCollect = on
        if on then
            lastRemoteTry = 0
            task.spawn(startAutoCollect)
        else
            collectWorkerGen = collectWorkerGen + 1
            collectWorking = false
            collectClearQueue()
        end
    end
})

eventoRight:AddLabel({
    Label = "Event Auto-Collect automatically collects candies, coins, and seasonal event drops."
})

unloadEvento = function()
    for key in pairs(crateWorkers) do stopCrateWorker(key) end
    collectWorkerGen = collectWorkerGen + 1
    collectWorking = false
    collectClearQueue()
    if collectFolderConn then pcall(function() collectFolderConn:Disconnect() end); collectFolderConn = nil end
end

end

do
    local vfxTab = win:CreateTab("VFX")
    local effectsSubTab = vfxTab:CreateSubTab("Effects")
    local skySubTab     = vfxTab:CreateSubTab("Skybox")
    local wrapSubTab    = vfxTab:CreateSubTab("Gun Wrap")

    local fxCols = effectsSubTab:CreateColumns("Death & Streak FX", "Kill Effects")
    local fxLeft = fxCols.left
    local fxRight = fxCols.right

    local skyCols = skySubTab:CreateColumns("Custom Sky", "Information")
    local skyLeft = skyCols.left
    local skyRight = skyCols.right

    local wrapCols = wrapSubTab:CreateColumns("Weapon Skins", "Wrap Status")
    local wrapLeft = wrapCols.left
    local wrapRight = wrapCols.right

    local wrapState = {}
    local wrapAssets = {}
    local wrapMeshes = setmetatable({}, { __mode = "k" })
    local wrapConnections = {}
    local wrapCharConnections = {}
    local wrapSyncQueued = false
    local wrapStarted = false
    local wrapDesigns = {
        { key = "Katana", file = "Katana.png", label = "Katana" },
        { key = "FlareGun", file = "FlareGun.png", label = "Flare Gun" },
        { key = "karambit", file = "karambit.jpg", label = "Karambit" },
        { key = "RevolverDefault", file = "RevolverDefault.png", label = "Revolver" },
        { key = "FlySwatter", file = "FlySwatter.png", label = "Fly Swatter" },
        { key = "BasicSai", file = "BasicSai.png", label = "Basic Sai" },
        { key = "BasicSai2", file = "BasicSai2.png", label = "Basic Sai 2" },
    }
    local function wrapNorm(value)
        return string.lower(string.gsub(tostring(value or ""), "[^%w]", ""))
    end
    local function wrapEnabled(key)
        return wrapState[key] == true
    end
    local function wrapAsset(design)
        if wrapAssets[design.file] then return wrapAssets[design.file] end
        local gc = getcustomasset or getsynasset
        local rq = request or http_request or (syn and syn.request)
        if type(gc) ~= "function" or type(rq) ~= "function" or type(writefile) ~= "function" then return nil end
        local folder = "clix-config/wraps"
        local path = folder .. "/" .. design.file
        pcall(function()
            if makefolder and isfolder then
                if not isfolder("clix-config") then makefolder("clix-config") end
                if not isfolder(folder) then makefolder(folder) end
            end
        end)
        local present = false
        pcall(function() present = isfile(path) and #readfile(path) > 500 end)
        if not present then
            local ok, response = pcall(rq, { Url = "https://raw.githubusercontent.com/BabyyClix/texture/main/" .. design.file, Method = "GET" })
            if ok and type(response) == "table" then
                local statusCode = tonumber(response.StatusCode or response.status_code) or 0
                local body = response.Body or response.body
                if statusCode == 200 and type(body) == "string" and #body > 500 then pcall(writefile, path, body) end
            end
        end
        pcall(function() present = isfile(path) end)
        if not present then return nil end
        local ok, asset = pcall(gc, path)
        if ok and type(asset) == "string" and asset ~= "" then wrapAssets[design.file] = asset; return asset end
        return nil
    end
    local function wrapDesignForName(name)
        local normalized = wrapNorm(name)
        if normalized == "" then return nil end
        for _, design in ipairs(wrapDesigns) do
            if wrapEnabled(design.key) and wrapNorm(design.key) == normalized then return design end
        end
        for _, design in ipairs(wrapDesigns) do
            if wrapEnabled(design.key) then
                local dn = wrapNorm(design.key)
                if string.find(normalized, dn, 1, true) or string.find(dn, normalized, 1, true) then return design end
            end
        end
        return nil
    end
    local function wrapWanted(mesh)
        local node = mesh
        while node and node ~= workspace do
            if node:IsA("Tool") then return wrapDesignForName(node.Name) end
            node = node.Parent
        end
        if LocalPlayer.Character and mesh:IsDescendantOf(LocalPlayer.Character) then return wrapDesignForName(mesh.Name) end
        return nil
    end
    local function wrapMesh(mesh, design)
        if wrapMeshes[mesh] or not mesh.Parent then return end
        local asset = wrapAsset(design)
        if not asset then return end
        local entry = { design = design.key, texture = mesh.TextureID, color = mesh.Color, surface = mesh:FindFirstChildOfClass("SurfaceAppearance") }
        wrapMeshes[mesh] = entry
        if entry.surface then pcall(function() entry.surface.Parent = nil end) end
        pcall(function() mesh.TextureID = asset; mesh.Color = Color3.new(1, 1, 1) end)
    end
    local function unwrapMesh(mesh)
        local entry = wrapMeshes[mesh]
        wrapMeshes[mesh] = nil
        if not entry then return end
        pcall(function() mesh.TextureID = entry.texture or ""; mesh.Color = entry.color or mesh.Color end)
        if entry.surface then pcall(function() if entry.surface.Parent == nil and mesh.Parent then entry.surface.Parent = mesh end end) end
    end
    local function wrapRoots()
        local roots = {}
        if LocalPlayer.Character then table.insert(roots, LocalPlayer.Character) end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then table.insert(roots, backpack) end
        return roots
    end
    local function syncWraps()
        for mesh, entry in pairs(wrapMeshes) do
            if not mesh.Parent then wrapMeshes[mesh] = nil else
                local wanted = wrapWanted(mesh)
                if not wanted or wanted.key ~= entry.design then unwrapMesh(mesh) end
            end
        end
        for _, root in ipairs(wrapRoots()) do
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("MeshPart") and not wrapMeshes[obj] then
                    local wanted = wrapWanted(obj)
                    if wanted then wrapMesh(obj, wanted) end
                end
            end
        end
    end
    local function queueWrapSync()
        if wrapSyncQueued then return end
        wrapSyncQueued = true
        task.defer(function() wrapSyncQueued = false; if not unloaded then syncWraps() end end)
    end
    local function bindWrapCharacter(char)
        for _, connection in ipairs(wrapCharConnections) do pcall(function() connection:Disconnect() end) end
        table.clear(wrapCharConnections)
        if not char then return end
        table.insert(wrapCharConnections, char.ChildAdded:Connect(queueWrapSync))
        table.insert(wrapCharConnections, char.ChildRemoved:Connect(queueWrapSync))
        table.insert(wrapCharConnections, char.DescendantAdded:Connect(function(obj) if obj:IsA("MeshPart") then queueWrapSync() end end))
    end
    local function startWraps()
        if wrapStarted then return end
        wrapStarted = true
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then table.insert(wrapConnections, backpack.ChildAdded:Connect(queueWrapSync)) end
        table.insert(wrapConnections, LocalPlayer.CharacterAdded:Connect(function(char) task.delay(.15, function() if LocalPlayer.Character == char then bindWrapCharacter(char); queueWrapSync() end end) end))
        bindWrapCharacter(LocalPlayer.Character)
        queueWrapSync()
    end
    local function setWrap(design, enabled)
        for _, other in ipairs(wrapDesigns) do
            if other.key ~= design.key and wrapNorm(other.key) == wrapNorm(design.key) then wrapState[other.key] = false end
        end
        wrapState[design.key] = enabled == true
        queueWrapSync()
    end
    for _, design in ipairs(wrapDesigns) do
        wrapLeft:AddToggle({ Label = design.label, Config = { "GunWrap_" .. design.key }, Default = false, Callback = function(on) setWrap(design, on) end })
    end
    wrapRight:AddLabel({ Label = "Local weapon skins from the Clix wrap collection." })
    wrapRight:AddLabel({ Label = "Skins apply automatically to equipped and stored weapons." })
    wrapRight:AddButton({ Label = "Refresh Weapon Wraps", Callback = queueWrapSync })
    startWraps()

    local VfxState = {
        deathVfx           = false,
        deathColor         = Color3.fromRGB(255, 100, 50),
        streakColorEnabled = false,
        streakColor        = Color3.fromRGB(255, 130, 20),
        frostbite          = false,
        customSky          = false,
        skyPreset          = "GreenHaze",
    }

    local deathVfxOriginalProps = setmetatable({}, { __mode = "k" })
    local deathVfxDescendantConn = nil

    local function isDeathVfxTarget(inst)
        if not inst or not inst.Parent then return false end
        local model = inst:FindFirstAncestorOfClass("Model")
        if model and Players:GetPlayerFromCharacter(model) then return false end
        if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail")
            or inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
            return true
        end
        if inst:IsA("BasePart") or inst:IsA("MeshPart") or inst:IsA("UnionOperation") then
            local n = inst.Name:lower()
            local pn = inst.Parent and inst.Parent.Name:lower() or ""
            local an = model and model.Name:lower() or ""
            for _, k in ipairs({"jelly","death","kill","ragdoll","corpse","blood","particle","effect","debris"}) do
                if n:find(k) or pn:find(k) or an:find(k) then return true end
            end
        end
        return false
    end

    local function rememberDeathVfxColor(inst)
        if not inst or deathVfxOriginalProps[inst] then return end
        local ok, originalColor = pcall(function() return inst.Color end)
        if ok and originalColor ~= nil then deathVfxOriginalProps[inst] = { Color = originalColor } end
    end

    local function applyDeathVfxColor(inst)
        if not VfxState.deathVfx or not inst or not inst.Parent then return end
        local supported = inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail")
            or inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight")
            or ((inst:IsA("BasePart") or inst:IsA("MeshPart") or inst:IsA("UnionOperation")) and isDeathVfxTarget(inst))
        if not supported then return end
        rememberDeathVfxColor(inst)
        local col = VfxState.deathColor
        pcall(function()
            if inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
                inst.Color = ColorSequence.new(col)
            else
                inst.Color = col
            end
        end)
    end

    local function restoreDeathVfxColors()
        for inst, props in pairs(deathVfxOriginalProps) do
            pcall(function()
                if inst and inst.Parent and props.Color ~= nil then inst.Color = props.Color end
            end)
        end
        table.clear(deathVfxOriginalProps)
    end

    local function scanExistingDeathVfx()
        task.spawn(function()
            local queue = workspace:GetChildren()
            local index = 1
            while index <= #queue do
                if not VfxState.deathVfx or unloaded then return end
                local inst = queue[index]
                index = index + 1
                if inst and inst.Parent then
                    if isDeathVfxTarget(inst) or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
                        applyDeathVfxColor(inst)
                    end
                    for _, child in ipairs(inst:GetChildren()) do queue[#queue + 1] = child end
                end
                if index % 100 == 0 then task.wait() end
            end
        end)
    end

    local function bindDeathVfxListener()
        if deathVfxDescendantConn or not VfxState.deathVfx or unloaded then return end
        deathVfxDescendantConn = workspace.DescendantAdded:Connect(function(desc)
            if not VfxState.deathVfx or unloaded then return end
            if isDeathVfxTarget(desc) or desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
                task.defer(function()
                    if VfxState.deathVfx and not unloaded then applyDeathVfxColor(desc) end
                end)
            end
        end)
    end

    local function unbindDeathVfxListener()
        if deathVfxDescendantConn then
            pcall(function() deathVfxDescendantConn:Disconnect() end)
            deathVfxDescendantConn = nil
        end
    end

    local streakOriginalProps = setmetatable({}, { __mode = "k" })
    local streakCandidateWatches = setmetatable({}, { __mode = "k" })
    local streakDescendantConn = nil
    local fireGlyph = utf8.char(0x1F525)
    local streakFireAsset = "rbxassetid://106103326681913"

    local function isStreakVisual(inst)
        if not inst or not inst.Parent then return false end
        if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return false end
        local full = string.lower(inst:GetFullName())
        if full:find("leaderboard", 1, true) or full:find("partystreak", 1, true) or full:find("crate", 1, true) then return false end
        local text = tostring(inst.Text or "")
        return full:find("headtag", 1, true) ~= nil
            and full:find("streaks", 1, true) ~= nil
            and (text:find(fireGlyph, 1, true) ~= nil or inst:GetAttribute("MytersStreakNumber") == true)
    end

    local function applyStreakVisual(inst, color)
        if not isStreakVisual(inst) then return end
        pcall(function()
            local props = streakOriginalProps[inst]
            if not props then
                props = {
                    text = inst.Text,
                    richText = inst.RichText,
                    textColor = inst.TextColor3,
                    textXAlignment = inst.TextXAlignment,
                    size = inst.Size,
                    layoutOrder = inst.LayoutOrder,
                    textScaled = inst.TextScaled,
                    automaticSize = inst.AutomaticSize,
                    textTransparency = inst.TextTransparency,
                    textStrokeTransparency = inst.TextStrokeTransparency,
                    textStrokeColor = inst.TextStrokeColor3,
                    parent = inst.Parent,
                    hadStreakNumberAttribute = inst:GetAttributes().MytersStreakNumber ~= nil,
                    originalStreakNumberAttribute = inst:GetAttribute("MytersStreakNumber"),
                    layout = inst.Parent and inst.Parent:FindFirstChildOfClass("UIListLayout"),
                    layoutVerticalAlignment = nil,
                }
                if props.layout then props.layoutVerticalAlignment = props.layout.VerticalAlignment end
                streakOriginalProps[inst] = props
            end
            local rawText = tostring(inst.Text or "")
            local count = string.match(rawText, "(%d+)%s*</font>%s*$") or string.match(rawText, "(%d+)%s*$") or "0"
            local parent = inst.Parent
            local icon = parent and parent:FindFirstChild("MytersStreakFireIcon")
            if props then props.parent = props.parent or parent; props.icon = icon end
            if not icon and parent then
                icon = Instance.new("ImageLabel")
                icon.Name = "MytersStreakFireIcon"
                icon.BackgroundTransparency = 1
                icon.ScaleType = Enum.ScaleType.Fit
                icon.Position = UDim2.fromOffset(0, 0)
                icon.LayoutOrder = 0
                icon.ZIndex = inst.ZIndex + 1
                icon.Parent = parent
            end
            if props then props.icon = icon end
            if icon then
                icon.Image = streakFireAsset
                icon.ImageColor3 = color
                icon.Size = UDim2.new(1, 0, 1, 0)
                local arc = icon:FindFirstChildOfClass("UIAspectRatioConstraint")
                if not arc then
                    arc = Instance.new("UIAspectRatioConstraint")
                    arc.Name = "MytersStreakAspect"
                    arc.AspectRatio = 1
                    arc.AspectType = Enum.AspectType.FitWithinMaxSize
                    arc.DominantAxis = Enum.DominantAxis.Height
                    arc.Parent = icon
                end
            end
            local layout = parent and parent:FindFirstChildOfClass("UIListLayout")
            if layout then
                layout.VerticalAlignment = Enum.VerticalAlignment.Center
            end
            inst:SetAttribute("MytersStreakNumber", true)
            inst.RichText = false
            inst.Text = count
            inst.TextColor3 = color
            inst.TextXAlignment = Enum.TextXAlignment.Left
            inst.Size = UDim2.new(0, 0, 1, 0)
            inst.AutomaticSize = Enum.AutomaticSize.X
            inst.TextScaled = true
            inst.LayoutOrder = 1
        end)
    end

    local function applyWorkspaceStreaks()
        local color = VfxState.streakColor
        for _, model in ipairs(workspace:GetChildren()) do
            local root = model:FindFirstChild("HumanoidRootPart")
            local headTag = root and root:FindFirstChild("HeadTag")
            local streak = headTag and headTag:FindFirstChild("Streak")
            local streaks = streak and streak:FindFirstChild("Streaks")
            local textLabel = streaks and streaks:FindFirstChild("TextLabel")
            if textLabel then
                applyStreakVisual(textLabel, color)
            end
        end
    end

    local function restoreStreakColors()
        for inst, props in pairs(streakOriginalProps) do
            pcall(function()
                if inst and inst.Parent then
                    inst.Text = props.text
                    inst.RichText = props.richText
                    inst.TextColor3 = props.textColor
                    inst.TextXAlignment = props.textXAlignment
                    inst.Size = props.size
                    inst.LayoutOrder = props.layoutOrder
                    inst.TextScaled = props.textScaled or false
                    inst.AutomaticSize = props.automaticSize or Enum.AutomaticSize.None
                    inst.TextTransparency = props.textTransparency or 0
                    inst.TextStrokeTransparency = props.textStrokeTransparency or 1
                    if props.textStrokeColor then inst.TextStrokeColor3 = props.textStrokeColor end
                    if props.hadStreakNumberAttribute then
                        inst:SetAttribute("MytersStreakNumber", props.originalStreakNumberAttribute)
                    else
                        inst:SetAttribute("MytersStreakNumber", nil)
                    end
                end
                if props.layout and props.layout.Parent and props.layoutVerticalAlignment then
                    props.layout.VerticalAlignment = props.layoutVerticalAlignment
                end
                local parent = props.parent or (inst and inst.Parent)
                local icon = props.icon or (parent and parent:FindFirstChild("MytersStreakFireIcon"))
                if icon and icon.Parent then icon:Destroy() end
            end)
        end
        table.clear(streakOriginalProps)
    end

    local function watchStreakCandidate(desc)
        if unloaded or not VfxState.streakColorEnabled or not desc or desc.Name ~= "TextLabel" or not desc:IsA("TextLabel") then return end
        local parent = desc.Parent
        if not parent or parent.Name ~= "Streaks" or not parent.Parent or parent.Parent.Name ~= "Streak" then return end
        if isStreakVisual(desc) then
            applyStreakVisual(desc, VfxState.streakColor)
            return
        end
        if streakCandidateWatches[desc] then return end
        local changedConn, ancestryConn
        local function clearCandidateWatch()
            if changedConn then changedConn:Disconnect(); changedConn = nil end
            if ancestryConn then ancestryConn:Disconnect(); ancestryConn = nil end
            streakCandidateWatches[desc] = nil
        end
        changedConn = desc:GetPropertyChangedSignal("Text"):Connect(function()
            if unloaded or not VfxState.streakColorEnabled or not desc.Parent then
                clearCandidateWatch()
                return
            end
            if isStreakVisual(desc) then
                clearCandidateWatch()
                applyStreakVisual(desc, VfxState.streakColor)
            end
        end)
        ancestryConn = desc.AncestryChanged:Connect(function(_, p)
            if p == nil then clearCandidateWatch() end
        end)
        streakCandidateWatches[desc] = { changed = changedConn, ancestry = ancestryConn }
    end

    local function bindStreakListener()
        if streakDescendantConn or not VfxState.streakColorEnabled or unloaded then return end
        streakDescendantConn = workspace.DescendantAdded:Connect(function(desc)
            if not VfxState.streakColorEnabled or unloaded then return end
            task.defer(function() watchStreakCandidate(desc) end)
        end)
    end

    local function unbindStreakListener()
        if streakDescendantConn then
            pcall(function() streakDescendantConn:Disconnect() end)
            streakDescendantConn = nil
        end
        for desc, data in pairs(streakCandidateWatches) do
            if type(data) == "table" then
                if data.changed then pcall(function() data.changed:Disconnect() end) end
                if data.ancestry then pcall(function() data.ancestry:Disconnect() end) end
            end
        end
        table.clear(streakCandidateWatches)
    end

    local FrostFx = {}
    do
        local FPlayers = game:GetService("Players")
        local FDebris = game:GetService("Debris")
        local flp = LocalPlayer
        local CFG = {
            BodyColor    = Color3.fromRGB(53, 124, 133),
            BodyMaterial = Enum.Material.Ice,
            BodyDuration = 6,
            Sounds       = true,
            Lifetime     = 5,
            StatNames    = {"Kills", "Kill", "Eliminations", "Elims", "Takedowns"},
        }
        local conns, played, deaths = {}, {}, {}
        local running = false

        local TEMPLATE_URL = "https://raw.githubusercontent.com/BabyyClix/frosbite/main/frostbite-template.json"
        local frostbiteTemplate
        local templateLoading = false
        local templateRetryAfter = 0
        local lastSnapshotSweep = 0

        local function loadTemplate()
            if frostbiteTemplate then return frostbiteTemplate end
            if templateLoading then return nil end
            templateLoading = true
            local ok, result = pcall(function()
                local http = game:GetService("HttpService")
                local body
                if type(request) == "function" then
                    local response = request({ Url = TEMPLATE_URL, Method = "GET" })
                    assert(response and response.Success ~= false and type(response.Body) == "string", "fallo")
                    body = response.Body
                else
                    body = game:HttpGet(TEMPLATE_URL)
                end
                local decoded = http:JSONDecode(body)
                assert(type(decoded) == "table" and type(decoded.root) == "table", "JSON invalid")
                local root = decoded.root
                for _, child in ipairs(root.children or {}) do
                    if child.name == "Effect" then return child end
                end
                if root.name == "Effect" then return root end
                error("no Effect")
            end)
            templateLoading = false
            if ok then
                frostbiteTemplate = result
            end
            return frostbiteTemplate
        end

        task.spawn(function() pcall(loadTemplate) end)

        local function decodeTemplateValue(v)
            if type(v) ~= "table" or v.__type == nil then return v end
            local kind = v.__type
            if kind == "Vector3" then
                return Vector3.new(v.x, v.y, v.z)
            elseif kind == "Vector2" then
                return Vector2.new(v.x, v.y)
            elseif kind == "Color3" then
                return Color3.new(v.r, v.g, v.b)
            elseif kind == "CFrame" then
                return CFrame.new(v.x, v.y, v.z, v.r00, v.r01, v.r02, v.r10, v.r11, v.r12, v.r20, v.r21, v.r22)
            elseif kind == "NumberRange" then
                return NumberRange.new(v.min, v.max)
            elseif kind == "NumberSequence" then
                local keys = {}
                for _, k in ipairs(v.keypoints or {}) do table.insert(keys, NumberSequenceKeypoint.new(k.time, k.value, k.envelope or 0)) end
                return NumberSequence.new(keys)
            elseif kind == "ColorSequence" then
                local keys = {}
                for _, k in ipairs(v.keypoints or {}) do table.insert(keys, ColorSequenceKeypoint.new(k.time, Color3.new(k.r, k.g, k.b))) end
                return ColorSequence.new(keys)
            elseif kind == "Enum" then
                local enumType = Enum[v.enum]
                return enumType and enumType[v.name] or nil
            elseif kind == "Content" then
                return v.source or v.text
            end
            return nil
        end

        local function buildTemplateNode(node, parent)
            local inst = Instance.new(node.className)
            inst.Name = node.name or node.className
            for prop, value in pairs(node.properties or {}) do
                if prop ~= "CFrame" and prop ~= "Playing" then
                    local decoded = decodeTemplateValue(value)
                    if decoded ~= nil then pcall(function() inst[prop] = decoded end) end
                end
            end
            for key, value in pairs(node.attributes or {}) do
                local decoded = decodeTemplateValue(value)
                if type(key) == "string" and decoded ~= nil then pcall(function() inst:SetAttribute(key, decoded) end) end
            end
            inst.Parent = parent
            for _, child in ipairs(node.children or {}) do buildTemplateNode(child, inst) end
            return inst
        end

        local FS = {snaps = setmetatable({}, {__mode = "k"}), tracked = setmetatable({}, {__mode = "k"}), pathCache = setmetatable({}, {__mode = "k"}), snapAt = setmetatable({}, {__mode = "k"}), statues = {}, list = {}, MAX = 40}
        function FS.relPath(inst, root)
            local parts = {}
            while inst and inst ~= root do table.insert(parts, 1, inst.Name); inst = inst.Parent end
            return table.concat(parts, "/")
        end
        function FS.takeSnap(char)
            if not char or not char.Parent then return end
            local now = os.clock()
            local last = FS.snapAt[char]
            if last and (now - last) < 0.10 then return end
            FS.snapAt[char] = now
            local s = FS.snaps[char]
            if not s then s = {}; FS.snaps[char] = s end
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then
                    local pc = FS.pathCache[d]
                    if not pc then pc = FS.relPath(d, char); FS.pathCache[d] = pc end
                    s[pc] = d.CFrame
                end
            end
        end
        function FS.removeStatue(key)
            local m = FS.statues[key]
            if m then pcall(function() m:Destroy() end); FS.statues[key] = nil end
        end
        function FS.clearStatues()
            for _, m in pairs(FS.statues) do pcall(function() m:Destroy() end) end
            FS.statues, FS.list = {}, {}
        end
        function FS.paint(part)
            if part.Name ~= "HumanoidRootPart" then
                part.Color = CFG.BodyColor
                part.Material = CFG.BodyMaterial
                part.MaterialVariant = ""
            end
        end
        function FS.freezeBody(char)
            local snap = FS.snaps[char]
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.Anchored = true
                        part.CanCollide = false
                        local cf = snap and snap[FS.pathCache[part] or FS.relPath(part, char)]
                        if cf then part.CFrame = cf end
                        FS.paint(part)
                    end)
                end
            end
        end
        function FS.hideOriginal(char)
            task.spawn(function()
                local t0 = os.clock()
                while os.clock() - t0 < 2 do
                    pcall(function()
                        for _, d in ipairs(char:GetDescendants()) do
                            if d:IsA("BasePart") then d.LocalTransparencyModifier = 1
                            elseif d:IsA("Decal") then d.Transparency = 1 end
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end
        function FS.buildStatue(char)
            local key = FPlayers:GetPlayerFromCharacter(char) or char
            local wasArch = char.Archivable
            pcall(function() char.Archivable = true end)
            local ok, clone = pcall(function() return char:Clone() end)
            pcall(function() char.Archivable = wasArch end)
            if not ok or not clone then return nil end
            local snap = FS.snaps[char]
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("BillboardGui") or d:IsA("Sound") or d:IsA("Highlight") or d:IsA("ForceField") then
                    pcall(function() d:Destroy() end)
                elseif d:IsA("Humanoid") then
                    pcall(function()
                        d.BreakJointsOnDeath = false
                        d.RequiresNeck = false
                        d.MaxHealth = 100
                        d.Health = 100
                        d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                        d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                        d.NameDisplayDistance = 0
                        d.HealthDisplayDistance = 0
                    end)
                end
            end
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") then
                    pcall(function()
                        d.Anchored = true
                        d.CanCollide = false
                        d.CanQuery = false
                        d.CanTouch = false
                        d.Massless = true
                        local cf = snap and snap[FS.relPath(d, clone)]
                        if cf then d.CFrame = cf end
                        FS.paint(d)
                    end)
                end
            end
            clone.Name = "MytersFrostStatue"
            clone.Parent = workspace
            FS.removeStatue(key)
            FS.statues[key] = clone
            table.insert(FS.list, {key = key, model = clone})
            while #FS.list > FS.MAX do
                local e = table.remove(FS.list, 1)
                if FS.statues[e.key] == e.model then FS.removeStatue(e.key) else pcall(function() e.model:Destroy() end) end
            end
            return clone
        end

        local function frozenBodyCF(char, statue, anchor)
            if statue then
                local okB, cf = pcall(function() return (statue:GetBoundingBox()) end)
                if okB and cf then return CFrame.new(cf.Position) end
            end
            local snap = FS.snaps[char]
            if snap then
                for _, nm in ipairs({"LowerTorso", "UpperTorso", "HumanoidRootPart", "Torso"}) do
                    if snap[nm] then return CFrame.new(snap[nm].Position) end
                end
            end
            return anchor.CFrame * CFrame.new(0, 0.3, 0)
        end

        local function playFallbackVFX(char, statue)
            local src = statue or char
            local anchor = src and (src:FindFirstChild("LowerTorso") or src:FindFirstChild("UpperTorso") or src:FindFirstChild("HumanoidRootPart") or src:FindFirstChild("Torso") or src:FindFirstChild("Head"))
            if not anchor then return false end
            local ok = pcall(function()
                local holder = Instance.new("Part")
                holder.Name = "MytersFrostbiteFallback"
                holder.Size = Vector3.new(0.2, 0.2, 0.2)
                holder.Transparency = 1
                holder.Anchored = true
                holder.CanCollide = false
                holder.CanQuery = false
                holder.CanTouch = false
                holder.CFrame = frozenBodyCF(char, statue, anchor)
                holder.Parent = workspace
                local attachment = Instance.new("Attachment")
                attachment.Parent = holder
                local emitter = Instance.new("ParticleEmitter")
                emitter.Name = "FrostbiteFallbackBurst"
                emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                emitter.Color = ColorSequence.new(Color3.fromRGB(174, 235, 255), Color3.fromRGB(245, 252, 255))
                emitter.LightEmission = 0.75
                emitter.LightInfluence = 0
                emitter.Rate = 0
                emitter.Lifetime = NumberRange.new(0.45, 1.15)
                emitter.Speed = NumberRange.new(3, 8)
                emitter.SpreadAngle = Vector2.new(180, 180)
                emitter.Rotation = NumberRange.new(0, 360)
                emitter.RotSpeed = NumberRange.new(-120, 120)
                emitter.Acceleration = Vector3.new(0, 2, 0)
                emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(0.7, 0.18), NumberSequenceKeypoint.new(1, 0)})
                emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1)})
                emitter.Parent = attachment
                emitter:Emit(48)
                FDebris:AddItem(holder, 1.5)
            end)
            return ok
        end

        local function playVFX(char, statue)
            local effectNode = frostbiteTemplate
            if not effectNode then
                pcall(playFallbackVFX, char, statue)
                if not templateLoading and os.clock() >= templateRetryAfter then
                    templateRetryAfter = os.clock() + 15
                    task.spawn(function() pcall(loadTemplate) end)
                end
                return
            end
            local src = statue or char
            local anchor = src:FindFirstChild("LowerTorso") or src:FindFirstChild("UpperTorso") or src:FindFirstChild("HumanoidRootPart") or src:FindFirstChild("Torso") or src:FindFirstChild("Head")
            if not anchor then return end
            local built, fx = pcall(buildTemplateNode, effectNode, nil)
            if not built or not fx then
                pcall(playFallbackVFX, char, statue)
                return
            end
            fx.Name = "MytersFrostbite"
            if fx:IsA("BasePart") then
                fx.Anchored = true
                fx.CanCollide = false; fx.CanQuery = false; fx.CanTouch = false; fx.Massless = true
                fx.CFrame = frozenBodyCF(char, statue, anchor)
            end
            fx.Parent = workspace
            if fx:IsA("Model") then
                pcall(function() fx:PivotTo(frozenBodyCF(char, statue, anchor)) end)
            end
            local ground = fx:FindFirstChild("Ground")
            if ground and ground:IsA("Attachment") then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = {char, fx, statue}
                local bodyPos = frozenBodyCF(char, statue, anchor).Position
                local hit = workspace:Raycast(bodyPos + Vector3.new(0, 2, 0), Vector3.new(0, -16, 0), rp)
                ground.WorldPosition = hit and hit.Position or (bodyPos - Vector3.new(0, 3, 0))
            end
            for _, d in ipairs(fx:GetDescendants()) do
                if d:IsA("ParticleEmitter") then
                    d.Enabled = false
                    local count = d:GetAttribute("EmitCount") or 1
                    local duration = d:GetAttribute("EmitDuration")
                    if type(duration) == "number" and duration > 0 then
                        d.Enabled = true
                        task.delay(duration, function() if d.Parent then d.Enabled = false end end)
                    end
                    local burstCount = math.clamp(math.floor((tonumber(count) or 1) * 2), 1, 250)
                    d:Emit(burstCount)
                elseif d:IsA("Sound") and CFG.Sounds then
                    d.Looped = false
                    d:Play()
                end
            end
            FDebris:AddItem(fx, CFG.Lifetime)
        end

        local function play(char, withBody)
            if not char or played[char] then return end
            played[char] = true
            task.delay(10, function() played[char] = nil end)
            local statue
            if withBody ~= false and char.Parent then
                local okS, st = pcall(FS.buildStatue, char)
                if okS then statue = st end
            end
            playVFX(char, statue)
            if withBody ~= false and char.Parent then
                if statue then FS.hideOriginal(char) else FS.freezeBody(char) end
            end
        end

        local function isLocalKillCredit(hum, char)
            local names = {"creator", "Creator", "KillCredit", "LastHit", "LastHitBy", "attacker", "Attacker", "Killer", "killer"}
            for _, container in ipairs({hum, char}) do
                if container then
                    for _, name in ipairs(names) do
                        local tag = container:FindFirstChild(name)
                        if tag then
                            local value
                            pcall(function() value = tag.Value end)
                            if value == flp or (typeof(value) == "Instance" and value:IsA("Player") and value.UserId == flp.UserId) then return true end
                            if typeof(value) == "Instance" and value:IsA("Model") and FPlayers:GetPlayerFromCharacter(value) == flp then return true end
                            if value ~= nil and tostring(value) ~= "" and (tostring(value) == tostring(flp.UserId) or tostring(value) == flp.Name) then return true end
                        end
                        local attr
                        pcall(function() attr = container:GetAttribute(name) end)
                        if attr ~= nil and (tostring(attr) == tostring(flp.UserId) or tostring(attr) == flp.Name) then return true end
                    end
                end
            end
            return false
        end

        local function watchChar(p, char)
            if not running or not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
            if not hum or not running then return end
            FS.tracked[char] = hum
            pcall(FS.takeSnap, char)
            local deadSeen, credited, alreadyPlayed = false, false, false
            local deathRecord
            local function checkCredit()
                if isLocalKillCredit(hum, char) then credited = true end
                if deadSeen then
                    if not deathRecord then
                        deathRecord = {char = char, t = os.clock(), used = false}
                        deaths[#deaths + 1] = deathRecord
                    end
                    if credited and not alreadyPlayed then
                        alreadyPlayed = true
                        play(char)
                    end
                end
            end
            local function onDeath()
                if not deadSeen then
                    deadSeen = true
                    FS.tracked[char] = nil
                end
                checkCredit()
                for _, delayTime in ipairs({0.12, 0.35, 0.75}) do
                    task.delay(delayTime, function()
                        if running and char.Parent and not alreadyPlayed then checkCredit() end
                    end)
                end
            end
            local function watchCreditValue(child)
                if child and child:IsA("ValueBase") then
                    table.insert(conns, child.Changed:Connect(checkCredit))
                end
                checkCredit()
            end
            for _, container in ipairs({hum, char}) do
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("ValueBase") then table.insert(conns, child.Changed:Connect(checkCredit)) end
                end
                table.insert(conns, container.ChildAdded:Connect(watchCreditValue))
            end
            for _, attrName in ipairs({"creator", "Creator", "KillCredit", "LastHit", "LastHitBy", "attacker", "Attacker", "Killer", "killer"}) do
                table.insert(conns, hum:GetAttributeChangedSignal(attrName):Connect(checkCredit))
                table.insert(conns, char:GetAttributeChangedSignal(attrName):Connect(checkCredit))
            end
            table.insert(conns, hum.Died:Connect(onDeath))
            table.insert(conns, hum.HealthChanged:Connect(function(hp) if hp <= 0 then onDeath() end end))
            checkCredit()
            if hum.Health <= 0 then onDeath() end
        end

        local function watchPlayer(p)
            if p == flp then return end
            if p.Character then task.spawn(watchChar, p, p.Character) end
            table.insert(conns, p.CharacterAdded:Connect(function(c)
                FS.removeStatue(p)
                watchChar(p, c)
            end))
        end

        function FrostFx.start()
            if running then return end
            running = true
            table.insert(conns, game:GetService("RunService").Heartbeat:Connect(function()
                local now = os.clock()
                if now - lastSnapshotSweep < 0.10 then return end
                lastSnapshotSweep = now
                for c, h in pairs(FS.tracked) do
                    if c.Parent and h.Parent and h.Health > 0 then pcall(FS.takeSnap, c) else FS.tracked[c] = nil end
                end
            end))
            if not frostbiteTemplate and not templateLoading and os.clock() >= templateRetryAfter then
                templateRetryAfter = os.clock() + 15
                task.spawn(function() pcall(loadTemplate) end)
            end
            for _, p in ipairs(FPlayers:GetPlayers()) do watchPlayer(p) end
            table.insert(conns, FPlayers.PlayerAdded:Connect(watchPlayer))
            local watchedLeaderstats = setmetatable({}, {__mode = "k"})
            local activeKillStat
            local function bindKillStat(st)
                if activeKillStat or not st or not (st:IsA("IntValue") or st:IsA("NumberValue")) then return end
                activeKillStat = st
                local prev = st.Value
                table.insert(conns, st:GetPropertyChangedSignal("Value"):Connect(function()
                    local current = st.Value
                    if current > prev then
                        for i = #deaths, 1, -1 do
                            local d = deaths[i]
                            if not d.used and os.clock() - d.t <= 2 and d.char and d.char.Parent then
                                d.used = true
                                play(d.char)
                                break
                            end
                        end
                    end
                    prev = current
                end))
            end
            local function isKillStatName(name)
                for _, candidate in ipairs(CFG.StatNames) do if candidate == name then return true end end
                return false
            end
            local function attachLeaderstats(ls)
                if not ls or watchedLeaderstats[ls] then return end
                watchedLeaderstats[ls] = true
                for _, name in ipairs(CFG.StatNames) do
                    local candidate = ls:FindFirstChild(name)
                    if candidate then bindKillStat(candidate); if activeKillStat then break end end
                end
                if not activeKillStat then
                    table.insert(conns, ls.ChildAdded:Connect(function(child)
                        if isKillStatName(child.Name) then bindKillStat(child) end
                    end))
                end
            end
            local existingStats = flp:FindFirstChild("leaderstats")
            if existingStats then
                attachLeaderstats(existingStats)
            else
                table.insert(conns, flp.ChildAdded:Connect(function(child)
                    if child.Name == "leaderstats" then attachLeaderstats(child) end
                end))
            end
        end

        function FrostFx.stop()
            running = false
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            conns, deaths = {}, {}
            FS.clearStatues()
            for c in pairs(FS.tracked) do FS.tracked[c] = nil end
        end

                FrostFx.play = play
    end

    local function getFrostbiteImage()
        local img = nil
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local item = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Item")
            if item then
                local fx = item:FindFirstChild("Effects")
                if fx and fx:IsA("ModuleScript") then
                    local t = require(fx)
                    if t and t.Frostbite and t.Frostbite.Image then img = t.Frostbite.Image end
                end
            end
        end)
        return (type(img) == "string" and img ~= "") and img or "rbxassetid://96237284722724"
    end

    local openFrostbiteEditor, closeFrostbiteEditor, updateFrostbiteEditorUI
    local vfxFxEd, fxBadge, fxCardStroke, fxImgStroke
    do
        local FX_W = 340
        local FX_H = 175

        vfxFxEd = Instance.new("Frame")
        vfxFxEd.Name = "ClixVisualFxEditor"
        vfxFxEd.AnchorPoint = Vector2.new(0.5, 0.5)
        vfxFxEd.Position = UDim2.fromScale(0.5, 0.5)
        vfxFxEd.Size = UDim2.fromOffset(FX_W, FX_H)
        vfxFxEd.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        vfxFxEd.BorderSizePixel = 0
        vfxFxEd.Visible = false
        vfxFxEd.ZIndex = 5000
        vfxFxEd.Active = true

        local edCorn = Instance.new("UICorner", vfxFxEd)
        edCorn.CornerRadius = UDim.new(0, 12)

        local edStroke = Instance.new("UIStroke", vfxFxEd)
        edStroke.Color = Color3.fromRGB(45, 45, 55)
        edStroke.Thickness = 1.2

        local edScale = Instance.new("UIScale", vfxFxEd)
        edScale.Scale = 1

        local fxTitle = Instance.new("TextLabel", vfxFxEd)
        fxTitle.Name = "Title"
        fxTitle.BackgroundTransparency = 1
        fxTitle.Position = UDim2.fromOffset(16, 10)
        fxTitle.Size = UDim2.new(1, -60, 0, 20)
        fxTitle.Text = "VISUAL EFFECT"
        fxTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
        fxTitle.Font = Enum.Font.GothamBold
        fxTitle.TextSize = 13
        fxTitle.TextXAlignment = Enum.TextXAlignment.Left
        fxTitle.ZIndex = 5001

        local fxDragBar = Instance.new("TextButton", vfxFxEd)
        fxDragBar.Name = "DragBar"
        fxDragBar.AutoButtonColor = false
        fxDragBar.BackgroundTransparency = 1
        fxDragBar.Size = UDim2.new(1, -40, 0, 36)
        fxDragBar.Text = ""
        fxDragBar.ZIndex = 5001

        local fxDragging, fxDragStart, fxStartPos = false, nil, nil
        fxDragBar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                fxDragging = true
                fxDragStart = inp.Position
                fxStartPos = vfxFxEd.Position
                inp.Changed:Connect(function()
                    if inp.UserInputState == Enum.UserInputState.End then fxDragging = false end
                end)
            end
        end)
        trackConnection(UserInputService.InputChanged:Connect(function(inp)
            if fxDragging and fxDragStart and fxStartPos then
                if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                    local d = inp.Position - fxDragStart
                    vfxFxEd.Position = UDim2.new(fxStartPos.X.Scale, fxStartPos.X.Offset + d.X, fxStartPos.Y.Scale, fxStartPos.Y.Offset + d.Y)
                end
            end
        end))

        local fxCloseBtn = Instance.new("TextButton", vfxFxEd)
        fxCloseBtn.Name = "CloseButton"
        fxCloseBtn.AutoButtonColor = false
        fxCloseBtn.Position = UDim2.new(1, -32, 0, 8)
        fxCloseBtn.Size = UDim2.fromOffset(24, 24)
        fxCloseBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
        fxCloseBtn.Text = "X"
        fxCloseBtn.TextColor3 = Color3.fromRGB(190, 190, 200)
        fxCloseBtn.Font = Enum.Font.GothamBold
        fxCloseBtn.TextSize = 12
        fxCloseBtn.ZIndex = 5002
        local closeCorn = Instance.new("UICorner", fxCloseBtn)
        closeCorn.CornerRadius = UDim.new(0, 6)

        local fxCard = Instance.new("TextButton", vfxFxEd)
        fxCard.Name = "FrostbiteCard"
        fxCard.AutoButtonColor = false
        fxCard.Position = UDim2.fromOffset(14, 40)
        fxCard.Size = UDim2.new(1, -28, 0, 120)
        fxCard.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
        fxCard.BorderSizePixel = 0
        fxCard.Text = ""
        fxCard.ZIndex = 5002
        local cardCorn = Instance.new("UICorner", fxCard)
        cardCorn.CornerRadius = UDim.new(0, 10)
        fxCardStroke = Instance.new("UIStroke", fxCard)
        fxCardStroke.Color = Color3.fromRGB(50, 50, 60)
        fxCardStroke.Thickness = 1.2

        local fxImgBox = Instance.new("Frame", fxCard)
        fxImgBox.Name = "ImageBox"
        fxImgBox.Position = UDim2.fromOffset(12, 14)
        fxImgBox.Size = UDim2.fromOffset(92, 92)
        fxImgBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
        fxImgBox.BorderSizePixel = 0
        fxImgBox.ZIndex = 5003
        local imgBoxCorn = Instance.new("UICorner", fxImgBox)
        imgBoxCorn.CornerRadius = UDim.new(0, 8)
        fxImgStroke = Instance.new("UIStroke", fxImgBox)
        fxImgStroke.Color = Color3.fromRGB(53, 124, 133)
        fxImgStroke.Thickness = 1

        local fxImgBtn = Instance.new("ImageButton", fxImgBox)
        fxImgBtn.Name = "FrostbiteButton"
        fxImgBtn.AutoButtonColor = false
        fxImgBtn.BackgroundTransparency = 1
        fxImgBtn.Size = UDim2.fromScale(1, 1)
        fxImgBtn.Image = getFrostbiteImage()
        fxImgBtn.ScaleType = Enum.ScaleType.Fit
        fxImgBtn.ZIndex = 5004

        local fxName = Instance.new("TextLabel", fxCard)
        fxName.BackgroundTransparency = 1
        fxName.Position = UDim2.fromOffset(116, 16)
        fxName.Size = UDim2.new(1, -124, 0, 22)
        fxName.Text = "Frostbite"
        fxName.TextColor3 = Color3.fromRGB(245, 245, 245)
        fxName.Font = Enum.Font.GothamBold
        fxName.TextSize = 16
        fxName.TextXAlignment = Enum.TextXAlignment.Left
        fxName.ZIndex = 5003

        fxBadge = Instance.new("TextLabel", fxCard)
        fxBadge.BackgroundTransparency = 1
        fxBadge.Position = UDim2.fromOffset(116, 40)
        fxBadge.Size = UDim2.new(1, -124, 0, 18)
        fxBadge.Text = "Efecto Mítico  •  INACTIVO"
        fxBadge.TextColor3 = Color3.fromRGB(150, 150, 160)
        fxBadge.Font = Enum.Font.GothamBold
        fxBadge.TextSize = 11
        fxBadge.TextXAlignment = Enum.TextXAlignment.Left
        fxBadge.ZIndex = 5003

        local fxDesc = Instance.new("TextLabel", fxCard)
        fxDesc.BackgroundTransparency = 1
        fxDesc.Position = UDim2.fromOffset(116, 62)
        fxDesc.Size = UDim2.new(1, -124, 0, 44)
        fxDesc.Text = "Toca la foto para activar. Se reproduce en la persona eliminada."
        fxDesc.TextColor3 = Color3.fromRGB(160, 160, 168)
        fxDesc.Font = Enum.Font.Gotham
        fxDesc.TextSize = 11
        fxDesc.TextWrapped = true
        fxDesc.TextXAlignment = Enum.TextXAlignment.Left
        fxDesc.TextYAlignment = Enum.TextYAlignment.Top
        fxDesc.ZIndex = 5003

        updateFrostbiteEditorUI = function()
            local on = VfxState.frostbite == true
            if fxBadge and fxBadge.Parent then
                fxBadge.Text = on and "Efecto Mítico  •  ACTIVO" or "Efecto Mítico  •  INACTIVO"
                fxBadge.TextColor3 = on and Color3.fromRGB(90, 220, 235) or Color3.fromRGB(150, 150, 160)
            end
            if fxCardStroke and fxCardStroke.Parent then
                fxCardStroke.Color = on and Color3.fromRGB(53, 124, 133) or Color3.fromRGB(50, 50, 60)
            end
            if fxImgStroke and fxImgStroke.Parent then
                fxImgStroke.Color = on and Color3.fromRGB(90, 220, 235) or Color3.fromRGB(53, 124, 133)
                fxImgStroke.Thickness = on and 1.8 or 1
            end
        end

        local function toggleFrostbiteAction()
            VfxState.frostbite = not VfxState.frostbite
            if VfxState.frostbite then
                FrostFx.start()
                win:Notify("Frostbite activado", 2)
            else
                FrostFx.stop()
                win:Notify("Frostbite desactivado", 2)
            end
            updateFrostbiteEditorUI()
        end

        fxCard.MouseButton1Click:Connect(toggleFrostbiteAction)
        fxImgBtn.MouseButton1Click:Connect(toggleFrostbiteAction)

        local fxTweenToken = 0
        closeFrostbiteEditor = function()
            fxTweenToken = fxTweenToken + 1
            local myTok = fxTweenToken
            TweenService:Create(edScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 }):Play()
            task.delay(0.18, function()
                if fxTweenToken == myTok and vfxFxEd and vfxFxEd.Parent then
                    vfxFxEd.Visible = false
                end
            end)
        end
        fxCloseBtn.MouseButton1Click:Connect(closeFrostbiteEditor)

        openFrostbiteEditor = function()
            fxTweenToken = fxTweenToken + 1
            pcall(function() vfxFxEd.Parent = getClixScreenGui() end)
            vfxFxEd.ZIndex = 5000
            centerOverMainWindow(vfxFxEd)
            vfxFxEd.Visible = true
            edScale.Scale = 0.88
            fxImgBtn.Image = getFrostbiteImage()
            updateFrostbiteEditorUI()
            TweenService:Create(edScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end
    end

    local MYTERS_SKYBOXES = {GreenHaze={SkyboxUp="rbxassetid://160193458",SkyboxBk="rbxassetid://160193404",SkyboxFt="rbxassetid://160193461",SunAngularSize=0,SkyboxLf="rbxassetid://160193469",SkyboxRt="rbxassetid://160193463",SkyboxDn="rbxassetid://160193466"},Space2={StarCount=3000,SkyboxUp="rbxassetid://11844053742",MoonTextureId="rbxassetid://11844121592",SkyboxBk="rbxassetid://11844076072",SkyboxDn="rbxassetid://11844069700",SkyboxFt="rbxassetid://11844067209",SunAngularSize=11,SkyboxLf="rbxassetid://11844063543",SkyboxRt="rbxassetid://11844058446",MoonAngularSize=20},PinkMountains={StarCount=3000,SkyboxUp="rbxassetid://160188588",SkyboxFt="rbxassetid://160188609",SkyboxLf="rbxassetid://160188589",SkyboxDn="rbxassetid://160188614",SunAngularSize=21,SkyboxBk="rbxassetid://160188495",SkyboxRt="rbxassetid://160188597",MoonAngularSize=0},Valentines={StarCount=3000,SkyboxUp="rbxassetid://11427771954",SkyboxFt="rbxassetid://11427769401",SkyboxLf="rbxassetid://11427769401",SkyboxDn="rbxassetid://11427770685",SunAngularSize=21,SkyboxBk="rbxassetid://11427769401",SkyboxRt="rbxassetid://11427769401",MoonAngularSize=0},PinkArt={StarCount=3000,SkyboxUp="rbxassetid://79190209626172",SkyboxFt="rbxassetid://104560113223878",SkyboxLf="rbxassetid://80395333901607",SkyboxDn="rbxassetid://78865378050055",SunAngularSize=21,SkyboxBk="rbxassetid://71607054149497",SkyboxRt="rbxassetid://87570388049514",MoonAngularSize=0},PurplePlanet={StarCount=3000,SkyboxUp="rbxassetid://16262366016",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://16262360469",SkyboxLf="rbxassetid://16262362003",SkyboxDn="rbxassetid://16262358026",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxBk="rbxassetid://16262356578",SkyboxRt="rbxassetid://16262363873",MoonAngularSize=0},Blizzard={StarCount=3000,SkyboxUp="rbxassetid://16653228333",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://16653221738",SkyboxFt="rbxassetid://16653224051",SkyboxDn="rbxassetid://16653222701",SunTextureId="rbxassetid://6196665106",SunAngularSize=21,SkyboxLf="rbxassetid://16653225849",SkyboxRt="rbxassetid://16653227200",MoonAngularSize=0},Winter={StarCount=3000,SkyboxUp="rbxassetid://155674931",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://155657655",SkyboxFt="rbxassetid://155657609",SkyboxLf="rbxassetid://155657671",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxDn="rbxassetid://155674246",SkyboxRt="rbxassetid://155657619",MoonAngularSize=11},FlamingSunset={StarCount=3000,SkyboxUp="rbxassetid://415688354",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://415688378",SkyboxFt="rbxassetid://415688242",SkyboxDn="rbxassetid://415688193",SunTextureId="rbxassetid://6196665106",SunAngularSize=0,SkyboxLf="rbxassetid://415688310",SkyboxRt="rbxassetid://415688274",MoonAngularSize=0},Mountains={StarCount=3000,SkyboxUp="rbxassetid://15359412677",SkyboxLf="rbxassetid://15359411633",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://15359411132",SkyboxBk="rbxassetid://15359410490",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://15359412131",SkyboxRt="rbxassetid://15359417656",MoonAngularSize=0},FPSBoost={StarCount=3000,SkyboxUp="rbxassetid://11457548274",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://11457548274",SkyboxLf="rbxassetid://11457548274",SkyboxDn="rbxassetid://11457548274",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxBk="rbxassetid://11457548274",SkyboxRt="rbxassetid://11457548274",MoonAngularSize=0},AestheticMountains={StarCount=3000,SkyboxUp="rbxassetid://15470207755",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://15470202648",SkyboxBk="rbxassetid://15470198023",SkyboxFt="rbxassetid://15470200128",SunTextureId="rbxassetid://6196665106",SunAngularSize=21,SkyboxDn="rbxassetid://15470151245",SkyboxRt="rbxassetid://15470204862",MoonAngularSize=11},BetterNight3={StarCount=500,SkyboxUp="rbxassetid://2670644331",MoonTextureId="rbxassetid://1075087760",SkyboxLf="rbxassetid://2670643070",SkyboxBk="rbxassetid://2670643994",SkyboxFt="rbxassetid://2670643214",SunTextureId="rbxassetid://6196665106",SunAngularSize=21,SkyboxDn="rbxassetid://2670643365",SkyboxRt="rbxassetid://2670644173",MoonAngularSize=1.5},Galaxy2={StarCount=500,SkyboxUp="rbxassetid://14164405298",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://14164398493",SkyboxBk="rbxassetid://14164368678",SkyboxFt="rbxassetid://14164389230",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://14164386126",SkyboxRt="rbxassetid://14164402782",MoonAngularSize=0},Aesthetic3={StarCount=500,SkyboxUp="rbxassetid://151165227",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://151165191",SkyboxBk="rbxassetid://151165214",SkyboxFt="rbxassetid://151165224",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://151165197",SkyboxRt="rbxassetid://151165206",MoonAngularSize=0},PurpleSpace={StarCount=3000,SkyboxUp="rbxassetid://15983964246",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://15983967420",SkyboxBk="rbxassetid://15983968922",SkyboxFt="rbxassetid://5260817288",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://15983966825",SkyboxRt="rbxassetid://15983966246",MoonAngularSize=0},Pink={StarCount=3000,SkyboxUp="rbxassetid://271077958",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://271042310",SkyboxBk="rbxassetid://271042516",SkyboxFt="rbxassetid://271042556",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://271077243",SkyboxRt="rbxassetid://271042467",MoonAngularSize=0},PurpleNight={StarCount=3000,SkyboxUp="rbxassetid://5084576400",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://5260817288",SkyboxBk="rbxassetid://5260808177",SkyboxDn="rbxassetid://5260653793",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://5260800833",SkyboxRt="rbxassetid://5260800833",MoonAngularSize=0},Flame={StarCount=3000,SkyboxUp="rbxassetid://6286790025",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://6286785801",SkyboxBk="rbxassetid://6286780109",SkyboxFt="rbxassetid://6286784186",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxDn="rbxassetid://6286782353",SkyboxRt="rbxassetid://6286788245",MoonAngularSize=0},Galaxy3={StarCount=3000,SkyboxUp="rbxassetid://14543371676",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://14543257810",SkyboxBk="rbxassetid://14543264135",SkyboxDn="rbxassetid://14543358958",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://14543275895",SkyboxRt="rbxassetid://14543280890",MoonAngularSize=0},Storm={SkyboxUp="rbxassetid://1618913654",MoonTextureId="rbxassetid://1075087760",SkyboxFt="rbxassetid://1618913244",SkyboxBk="rbxassetid://1618912481",SkyboxDn="rbxassetid://1618913943",SunTextureId="rbxassetid://1084351190",SunAngularSize=0,SkyboxLf="rbxassetid://1618912849",SkyboxRt="rbxassetid://1618911568",MoonAngularSize=0},Milkyway={StarCount=3000,SkyboxUp="rbxassetid://137817405681365",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://104400530594543",SkyboxBk="rbxassetid://129876530632297",SkyboxDn="rbxassetid://108406529909981",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://73372229972523",SkyboxRt="rbxassetid://87408857415924",MoonAngularSize=0},PurpleClouds={StarCount=3000,SkyboxUp="rbxassetid://570557727",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://570557775",SkyboxLf="rbxassetid://570557620",SkyboxBk="rbxassetid://570557514",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://570557559",SkyboxRt="rbxassetid://570557672",MoonAngularSize=0},BlueClouds={StarCount=3000,SkyboxUp="rbxassetid://591059642",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://591057861",SkyboxBk="rbxassetid://591058823",SkyboxFt="rbxassetid://591058104",SunTextureId="rbxassetid://6196665106",SunAngularSize=0,SkyboxDn="rbxassetid://591059876",SkyboxRt="rbxassetid://591057625",MoonAngularSize=0},BetterNight={StarCount=3000,SkyboxUp="rbxassetid://15470303050",SkyboxFt="rbxassetid://15470294431",SkyboxBk="rbxassetid://15470289121",SkyboxDn="rbxassetid://15470291746",SkyboxLf="rbxassetid://15470297162",SkyboxRt="rbxassetid://15470299887"},Cloudy={StarCount=3000,SkyboxUp="rbxassetid://4495867486",SkyboxFt="rbxassetid://4495865458",SkyboxBk="rbxassetid://4495864450",SkyboxDn="rbxassetid://4495864887",SkyboxLf="rbxassetid://4495866035",SkyboxRt="rbxassetid://4495866584"},NetherWorld={StarCount=3000,SkyboxUp="rbxassetid://14365019327",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://14365018399",SkyboxLf="rbxassetid://14365018705",SkyboxDn="rbxassetid://14365023350",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxBk="rbxassetid://14365019002",SkyboxRt="rbxassetid://14365018143",MoonAngularSize=0},NewYork={StarCount=3000,SkyboxUp="rbxassetid://11333967970",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://11333973069",SkyboxFt="rbxassetid://11333964303",SkyboxDn="rbxassetid://11333969768",SunTextureId="rbxassetid://6196665106",SunAngularSize=0,SkyboxLf="rbxassetid://11333971332",SkyboxRt="rbxassetid://11333982864",MoonAngularSize=0},Purple2={StarCount=3000,SkyboxUp="rbxassetid://8107849791",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://8107841671",SkyboxFt="rbxassetid://8107841671",SkyboxDn="rbxassetid://6444884785",SunTextureId="rbxassetid://6196665106",SunAngularSize=11,SkyboxLf="rbxassetid://8107841671",SkyboxRt="rbxassetid://8107841671",MoonAngularSize=0},FunnyStorm={StarCount=3000,SkyboxUp="rbxassetid://6280942402",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://6280935347",SkyboxLf="rbxassetid://6280938749",SkyboxBk="rbxassetid://6280934001",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://6280936575",SkyboxRt="rbxassetid://6280940989",MoonAngularSize=0},Galaxy={StarCount=3000,SkyboxUp="rbxassetid://159454288",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://159454293",SkyboxLf="rbxassetid://159454293",SkyboxDn="rbxassetid://159454296",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxBk="rbxassetid://159454299",SkyboxRt="rbxassetid://159454293",MoonAngularSize=0},BlueSpace={StarCount=3000,SkyboxUp="rbxassetid://16876552681",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://16876548320",SkyboxBk="rbxassetid://16876541778",SkyboxFt="rbxassetid://16876546384",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxDn="rbxassetid://16876543880",SkyboxRt="rbxassetid://16876550345",MoonAngularSize=0},Purple3={StarCount=3000,SkyboxUp="rbxassetid://433274285",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://433274131",SkyboxLf="rbxassetid://433274370",SkyboxDn="rbxassetid://433274194",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxBk="rbxassetid://433274085",SkyboxRt="rbxassetid://433274429",MoonAngularSize=0},Nebula2={StarCount=3000,SkyboxUp="rbxassetid://16932810138",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://16932800523",SkyboxLf="rbxassetid://16932803722",SkyboxDn="rbxassetid://16932797813",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxBk="rbxassetid://16932794531",SkyboxRt="rbxassetid://16932806825",MoonAngularSize=0},Nebula={StarCount=3000,SkyboxUp="rbxassetid://5260824661",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://5260800833",SkyboxDn="rbxassetid://5260653793",SkyboxBk="rbxassetid://5260808177",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxFt="rbxassetid://5260817288",SkyboxRt="rbxassetid://5260811073",MoonAngularSize=0},LunarNight={StarCount=0,SkyboxUp="rbxassetid://187712111",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://187713366",SkyboxFt="rbxassetid://187712836",SkyboxLf="rbxassetid://187713755",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://187712428",SkyboxRt="rbxassetid://187714525",MoonAngularSize=0},Purple={StarCount=3000,SkyboxUp="rbxassetid://8539981085",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://8539982183",SkyboxFt="rbxassetid://8539981721",SkyboxLf="rbxassetid://8539981424",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://8539981943",SkyboxRt="rbxassetid://8539980766",MoonAngularSize=0},Hell={StarCount=3000,SkyboxUp="rbxassetid://11730857150",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://11730840088",SkyboxFt="rbxassetid://11730849615",SkyboxLf="rbxassetid://11730852920",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://11730842997",SkyboxRt="rbxassetid://11730855491",MoonAngularSize=11},Nebula6={StarCount=3000,SkyboxUp="rbxassetid://16694204069",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://16694197080",SkyboxDn="rbxassetid://16694190947",SkyboxBk="rbxassetid://16694187412",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://16694194795",SkyboxRt="rbxassetid://16694200892",MoonAngularSize=11},DarkishPink={StarCount=3000,SkyboxUp="rbxassetid://570555929",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://570555840",SkyboxDn="rbxassetid://570555964",SkyboxBk="rbxassetid://570555736",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://570555800",SkyboxRt="rbxassetid://570555882",MoonAngularSize=11},RedNight={StarCount=3000,SkyboxUp="rbxassetid://401664936",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://401664839",SkyboxFt="rbxassetid://401664960",SkyboxLf="rbxassetid://401664881",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://401664862",SkyboxRt="rbxassetid://401664901",MoonAngularSize=0},Space={StarCount=3000,SkyboxUp="rbxassetid://166510114",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://166510057",SkyboxBk="rbxassetid://166509999",SkyboxFt="rbxassetid://166510116",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://166510092",SkyboxRt="rbxassetid://166510131",MoonAngularSize=0},OverPlanet={StarCount=3000,SkyboxUp="rbxassetid://165052345",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://165052365",SkyboxDn="rbxassetid://165052286",SkyboxBk="rbxassetid://165052268",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://165052328",SkyboxRt="rbxassetid://165052306",MoonAngularSize=11},Orange={StarCount=3000,SkyboxUp="rbxassetid://150939082",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://150939038",SkyboxBk="rbxassetid://150939022",SkyboxFt="rbxassetid://150939047",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://150939056",SkyboxRt="rbxassetid://150939063",MoonAngularSize=0},Pastel={StarCount=3000,SkyboxUp="rbxassetid://2128462236",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://2128462480",SkyboxBk="rbxassetid://2128458653",SkyboxFt="rbxassetid://2128458653",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://2128462027",SkyboxRt="rbxassetid://2128462027",MoonAngularSize=0},Beach={StarCount=0,SkyboxUp="rbxassetid://173380790",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://173380627",SkyboxBk="rbxassetid://173380597",SkyboxFt="rbxassetid://173380642",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxLf="rbxassetid://173380671",SkyboxRt="rbxassetid://173380774",MoonAngularSize=11},FakeClouds={StarCount=3000,SkyboxUp="rbxassetid://8496897504",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://8496896250",SkyboxBk="rbxassetid://8496892810",SkyboxFt="rbxassetid://8496892810",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://8496892810",SkyboxRt="rbxassetid://8496892810",MoonAngularSize=0},Aesthetic2={StarCount=3000,SkyboxUp="rbxassetid://600835177",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://600830446",SkyboxFt="rbxassetid://600832720",SkyboxLf="rbxassetid://600886090",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://600831635",SkyboxRt="rbxassetid://600833862",MoonAngularSize=0},Nebula4={StarCount=3000,SkyboxUp="rbxassetid://17103639457",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://17103622190",SkyboxBk="rbxassetid://17103618635",SkyboxFt="rbxassetid://17103624898",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://17103628153",SkyboxRt="rbxassetid://17103636666",MoonAngularSize=0},BluePlanet={StarCount=3000,SkyboxUp="rbxassetid://16889004122",SkyboxLf="rbxassetid://16888998994",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://16888991855",SkyboxBk="rbxassetid://16888989874",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://16888995219",SkyboxRt="rbxassetid://16889000916",MoonAngularSize=0},Nebula5={StarCount=3000,SkyboxUp="rbxassetid://17124369657",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://17124359797",SkyboxBk="rbxassetid://17124357467",SkyboxFt="rbxassetid://17124362093",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://17124365127",SkyboxRt="rbxassetid://17124367200",MoonAngularSize=0},LunarNight2={StarCount=3000,SkyboxUp="rbxassetid://14365026442",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://14365026242",SkyboxLf="rbxassetid://14365025904",SkyboxBk="rbxassetid://14365026085",SunTextureId="rbxassetid://8281961896",SunAngularSize=21,SkyboxFt="rbxassetid://14365025735",SkyboxRt="rbxassetid://14365025444",MoonAngularSize=0},Pinkie={StarCount=0,SkyboxUp="rbxassetid://11554996247",MoonTextureId="rbxassetid://6444320592",SkyboxDn="rbxassetid://11555013415",SkyboxBk="rbxassetid://11555017034",SkyboxFt="rbxassetid://11555010145",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://11555006545",SkyboxRt="rbxassetid://11555000712",MoonAngularSize=1.5},PurpleMountains={StarCount=3000,SkyboxUp="rbxassetid://17901365106",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://17901359687",SkyboxDn="rbxassetid://17901366771",SkyboxBk="rbxassetid://17901353811",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxFt="rbxassetid://17901356262",SkyboxRt="rbxassetid://17901362326",MoonAngularSize=0},DarkClouds={StarCount=0,SkyboxUp="rbxassetid://190477146",SkyboxDn="rbxassetid://190477222",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://190477185",SkyboxBk="rbxassetid://190477248",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxFt="rbxassetid://190477200",SkyboxRt="rbxassetid://190477166",MoonAngularSize=1.5},BetterNight2={StarCount=3000,SkyboxBk="rbxassetid://248431616",SkyboxUp="rbxassetid://248431605",SkyboxDn="rbxassetid://248431677",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://248431686",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxFt="rbxassetid://248431598",SkyboxRt="rbxassetid://248431611",MoonAngularSize=1.5},DarkMountains={StarCount=3000,SkyboxUp="rbxassetid://5098819127",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://5098814730",SkyboxFt="rbxassetid://5098815653",SkyboxDn="rbxassetid://5098815227",SunTextureId="rbxassetid://6196665106",SunAngularSize=0,SkyboxLf="rbxassetid://5098816155",SkyboxRt="rbxassetid://5098820352",MoonAngularSize=0},Nebula3={StarCount=3000,SkyboxUp="rbxassetid://17839226876",MoonTextureId="rbxassetid://6444320592",SkyboxBk="rbxassetid://17839210699",SkyboxFt="rbxassetid://17839218166",SkyboxLf="rbxassetid://17839220800",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxDn="rbxassetid://17839215896",SkyboxRt="rbxassetid://17839223605",MoonAngularSize=0},BetterSky={StarCount=3000,SkyboxUp="rbxassetid://591059642",MoonTextureId="rbxassetid://6444320592",SkyboxLf="rbxassetid://591057861",SkyboxBk="rbxassetid://591058823",SkyboxFt="rbxassetid://591058104",SunTextureId="rbxassetid://6196665106",SunAngularSize=0,SkyboxDn="rbxassetid://591059876",SkyboxRt="rbxassetid://591057625",MoonAngularSize=0},MagentaOrange={StarCount=3000,SkyboxUp="rbxassetid://566616187",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://566616141",SkyboxBk="rbxassetid://566616113",SkyboxDn="rbxassetid://566616232",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://566616044",SkyboxRt="rbxassetid://566616082",MoonAngularSize=0},Aesthetic={StarCount=3000,SkyboxUp="rbxassetid://1417494643",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://1417494253",SkyboxBk="rbxassetid://1417494030",SkyboxDn="rbxassetid://1417494146",SunTextureId="rbxassetid://8281961896",SunAngularSize=0,SkyboxLf="rbxassetid://1417494402",SkyboxRt="rbxassetid://1417494499",MoonAngularSize=0},Alien={StarCount=0,SkyboxUp="rbxassetid://159248176",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://159248187",SkyboxBk="rbxassetid://159248188",SkyboxDn="rbxassetid://159248183",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://159248173",SkyboxRt="rbxassetid://159248192",MoonAngularSize=0},Lunar={StarCount=3000,SkyboxUp="rbxassetid://179724054",MoonTextureId="rbxasset://sky/moon.jpg",SkyboxFt="rbxassetid://179724018",SkyboxBk="rbxassetid://179723991",SkyboxDn="rbxassetid://179724005",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://179724029",SkyboxRt="rbxassetid://179724037",MoonAngularSize=0},Retro={StarCount=3000,SkyboxUp="rbxassetid://16642401907",MoonTextureId="rbxasset://sky/moon.jpg",SkyboxFt="rbxassetid://16642398372",SkyboxBk="rbxassetid://16642396302",SkyboxDn="rbxassetid://16642397027",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://16642399309",SkyboxRt="rbxassetid://16642400745",MoonAngularSize=0},Realistic={StarCount=3000,SkyboxUp="rbxassetid://402560052",MoonTextureId="rbxasset://sky/moon.jpg",SkyboxFt="rbxassetid://402559953",SkyboxBk="rbxassetid://402559900",SkyboxDn="rbxassetid://402559927",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://402559983",SkyboxRt="rbxassetid://402560019",MoonAngularSize=0},Midnight={StarCount=3000,SkyboxUp="rbxassetid://154185031",MoonTextureId="rbxasset://sky/moon.jpg",SkyboxFt="rbxassetid://154185021",SkyboxBk="rbxassetid://154185004",SkyboxDn="rbxassetid://154184960",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://154184943",SkyboxRt="rbxassetid://154184972",MoonAngularSize=0},Antartica={StarCount=3000,SkyboxUp="rbxassetid://2118766003",MoonTextureId="rbxasset://sky/moon.jpg",SkyboxFt="rbxassetid://2118765204",SkyboxBk="rbxassetid://2118763079",SkyboxDn="rbxassetid://2118766919",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://2118764070",SkyboxRt="rbxassetid://2118761853"},Moon={StarCount=3000,SkyboxUp="rbxassetid://17489393055",MoonTextureId="rbxasset://sky/moon.jpg",SkyboxFt="rbxassetid://17489388310",SkyboxBk="rbxassetid://17489386489",SkyboxDn="rbxassetid://17489387417",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://17489389632",SkyboxRt="rbxassetid://17489391101"},NightMountains={StarCount=3000,MoonAngularSize=11,SkyboxUp="rbxassetid://264907379",MoonTextureId="rbxasset://sky/moon.jpg",SkyboxFt="rbxassetid://264909420",SkyboxBk="rbxassetid://264908339",SkyboxDn="rbxassetid://264907909",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://264909758",SkyboxRt="rbxassetid://264908886"},Art={StarCount=3000,MoonAngularSize=11,SkyboxUp="rbxassetid://9831769868",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://9831766232",SkyboxBk="rbxassetid://9831762777",SkyboxDn="rbxassetid://9831764283",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://9831768023",SkyboxRt="rbxassetid://9831768909"},Ame={StarCount=3000,MoonAngularSize=11,SkyboxUp="rbxassetid://160186148",MoonTextureId="rbxassetid://6444320592",SkyboxFt="rbxassetid://160186027",SkyboxBk="rbxassetid://160185927",SkyboxDn="rbxassetid://160185945",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://160186075",SkyboxRt="rbxassetid://160186126"},Dawn={StarCount=3000,MoonAngularSize=11,SkyboxUp="rbxassetid://250381047",SkyboxFt="rbxassetid://250380916",SkyboxBk="rbxassetid://250381017",SkyboxDn="rbxassetid://254156892",SunTextureId="rbxasset://sky/sun.jpg",SunAngularSize=21,SkyboxLf="rbxassetid://250380953",SkyboxRt="rbxassetid://250380985"}}

    local SKYBOX_NAMES = {
    "GreenHaze",
    "Space2",
    "PinkMountains",
    "Valentines",
    "PinkArt",
    "PurplePlanet",
    "Blizzard",
    "Winter",
    "FlamingSunset",
    "Mountains",
    "FPSBoost",
    "AestheticMountains",
    "BetterNight3",
    "Galaxy2",
    "Aesthetic3",
    "PurpleSpace",
    "Pink",
    "PurpleNight",
    "Flame",
    "Galaxy3",
    "Storm",
    "Milkyway",
    "PurpleClouds",
    "BlueClouds",
    "BetterNight",
    "Cloudy",
    "NetherWorld",
    "NewYork",
    "Purple2",
    "FunnyStorm",
    "Galaxy",
    "BlueSpace",
    "Purple3",
    "Nebula2",
    "Nebula",
    "LunarNight",
    "Purple",
    "Hell",
    "Nebula6",
    "DarkishPink",
    "RedNight",
    "Space",
    "OverPlanet",
    "Orange",
    "Pastel",
    "Beach",
    "FakeClouds",
    "Aesthetic2",
    "Nebula4",
    "BluePlanet",
    "Nebula5",
    "LunarNight2",
    "Pinkie",
    "PurpleMountains",
    "DarkClouds",
    "BetterNight2",
    "DarkMountains",
    "Nebula3",
    "BetterSky",
    "MagentaOrange",
    "Aesthetic",
    "Alien",
    "Lunar",
    "Retro",
    "Realistic",
    "Midnight",
    "Antartica",
    "Moon",
    "NightMountains",
    "Art",
    "Ame",
    "Dawn"
}

    local SKY_PROPS = {
        "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp",
        "StarCount", "CelestialBodiesShown", "SunAngularSize", "MoonAngularSize",
        "SunTextureId", "MoonTextureId"
    }

    local stashedSkies = {}
    local skyChildConn = nil

    local function applyCustomSky(enabled)
        local Lighting = game:GetService("Lighting")
        if not Lighting then return end
        if not enabled then
            local customSky = Lighting:FindFirstChild("MytersCustomSky")
            if customSky then pcall(function() customSky:Destroy() end) end
            for _, s in ipairs(stashedSkies) do
                if s and s.Parent == nil then pcall(function() s.Parent = Lighting end) end
            end
            table.clear(stashedSkies)
            return
        end
        local preset = MYTERS_SKYBOXES[VfxState.skyPreset] or MYTERS_SKYBOXES["GreenHaze"]
        if not preset then return end
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Sky") and child.Name ~= "MytersCustomSky" then
                table.insert(stashedSkies, child)
                pcall(function() child.Parent = nil end)
            end
        end
        local customSky = Lighting:FindFirstChild("MytersCustomSky")
        if not customSky or not customSky:IsA("Sky") then
            customSky = Instance.new("Sky")
            customSky.Name = "MytersCustomSky"
            customSky.Parent = Lighting
        end
        for _, prop in ipairs(SKY_PROPS) do
            local val = preset[prop]
            if val ~= nil then
                pcall(function() customSky[prop] = val end)
            else
                if prop == "CelestialBodiesShown" then
                    pcall(function() customSky[prop] = true end)
                elseif prop == "StarCount" then
                    pcall(function() customSky[prop] = 3000 end)
                elseif prop == "SunAngularSize" then
                    pcall(function() customSky[prop] = 11 end)
                elseif prop == "MoonAngularSize" then
                    pcall(function() customSky[prop] = 11 end)
                end
            end
        end
    end

    local function bindSkyListener()
        if skyChildConn then return end
        local Lighting = game:GetService("Lighting")
        skyChildConn = Lighting.ChildAdded:Connect(function(child)
            if VfxState.customSky and child:IsA("Sky") and child.Name ~= "MytersCustomSky" then
                table.insert(stashedSkies, child)
                task.defer(function() pcall(function() child.Parent = nil end) end)
            end
        end)
    end

    local function unbindSkyListener()
        if skyChildConn then
            pcall(function() skyChildConn:Disconnect() end)
            skyChildConn = nil
        end
    end

    fxLeft:AddToggle({
        Label    = "Enable Death FX",
        Config   = { "DeathVfxEnabled" },
        Default  = false,
        Tooltip  = "Recolors death particles and effects in the workspace.",
        Callback = function(on)
            VfxState.deathVfx = on
            if on then
                bindDeathVfxListener()
                scanExistingDeathVfx()
            else
                unbindDeathVfxListener()
                restoreDeathVfxColors()
            end
        end
    })

    fxLeft:AddColorPicker({
        Label    = "Death FX Color",
        Config   = { "DeathVfxColor" },
        Default  = VfxState.deathColor,
        Callback = function(val)
            local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color))
            if c then
                VfxState.deathColor = c
                if VfxState.deathVfx then scanExistingDeathVfx() end
            end
        end
    })

    fxLeft:AddDivider()

    fxLeft:AddToggle({
        Label    = "Custom Streak Color",
        Config   = { "StreakColorEnabled" },
        Default  = false,
        Tooltip  = "Recolors killstreak fire icon and numbers on players.",
        Callback = function(on)
            VfxState.streakColorEnabled = on
            if on then
                bindStreakListener()
                applyWorkspaceStreaks()
            else
                unbindStreakListener()
                restoreStreakColors()
            end
        end
    })

    fxLeft:AddColorPicker({
        Label    = "Streak Color",
        Config   = { "StreakColor" },
        Default  = VfxState.streakColor,
        Callback = function(val)
            local c = typeof(val) == "Color3" and val or (type(val) == "table" and (val.Rgb or val.Color))
            if c then
                VfxState.streakColor = c
                if VfxState.streakColorEnabled then applyWorkspaceStreaks() end
            end
        end
    })

    fxRight:AddToggle({
        Label    = "Frostbite Kill Effect",
        Config   = { "FrostbiteEnabled" },
        Default  = false,
        Tooltip  = "Freezes eliminated enemies into ice statues with particle bursts and sounds.",
        Callback = function(on)
            VfxState.frostbite = on
            if on then
                FrostFx.start()
            else
                FrostFx.stop()
            end
            if updateFrostbiteEditorUI then updateFrostbiteEditorUI() end
        end
    })

    fxRight:AddButton({
        Label    = "Visual Effect: Frostbite (Photo & Status)",
        Tooltip  = "Opens the Frostbite preview card with the mythic kill effect photo from Clix Old.",
        Callback = function()
            if openFrostbiteEditor then openFrostbiteEditor() end
        end
    })

    skyLeft:AddToggle({
        Label    = "Enable Custom Sky",
        Config   = { "CustomSkyEnabled" },
        Default  = false,
        Tooltip  = "Applies a custom skybox to the game.",
        Callback = function(on)
            VfxState.customSky = on
            if on then
                bindSkyListener()
                applyCustomSky(true)
            else
                unbindSkyListener()
                applyCustomSky(false)
            end
        end
    })

    skyLeft:AddDropdown({
        Label    = "Skybox Preset",
        Config   = { "SkyboxPreset" },
        Options  = SKYBOX_NAMES,
        Default  = VfxState.skyPreset,
        Callback = function(val)
            VfxState.skyPreset = tostring(val)
            if VfxState.customSky then applyCustomSky(true) end
        end
    })

    skyRight:AddLabel({
        Label = "Choose from 72 high-quality skyboxes imported from Myters Rival."
    })

    skyRight:AddLabel({
        Label = "Includes custom stars, celestial bodies, and lighting adjustments."
    })

    skyRight:AddDivider()

    skyRight:AddButton({
        Label    = "Reset Default Sky",
        Callback = function()
            applyCustomSky(false)
        end
    })

    unloadVfx = function()
        unbindDeathVfxListener()
        restoreDeathVfxColors()
        unbindStreakListener()
        restoreStreakColors()
        FrostFx.stop()
        unbindSkyListener()
        applyCustomSky(false)
        for mesh in pairs(wrapMeshes) do unwrapMesh(mesh) end
        for _, connection in ipairs(wrapConnections) do pcall(function() connection:Disconnect() end) end
        table.clear(wrapConnections)
        for _, connection in ipairs(wrapCharConnections) do pcall(function() connection:Disconnect() end) end
        table.clear(wrapCharConnections)
    end
end


clixWearEmbeddedSource = [==[

local getgenv = getgenv or function() return _G end

-- ============================================================
-- MYTERS · WEAR ITEM  v3  (directo al character, sin ApplyDescription)
-- Shirt/Pants → escribe ShirtTemplate/PantsTemplate directo
-- Accesorios  → carga via AssetService o rbxasset y weld
-- ============================================================

-- Pace UI construction during the initial module boot. The feature logic is
-- unchanged; only bursts of interface creation yield back to the game loop.
local __mytersWearBootEnv = (getgenv and getgenv()) or _G
local __mytersWearBootRunService = game:GetService("RunService")
local __mytersWearBootCreateCount = 0
local __mytersWearBootSliceAt = os.clock()
local function __mytersWearBootYield()
    local boot = (__mytersWearBootEnv and __mytersWearBootEnv.MytersBoot) or rawget(_G, "MytersBoot")
    if not boot or boot.finished or boot.cancelled then return end
    __mytersWearBootCreateCount = __mytersWearBootCreateCount + 1
    if __mytersWearBootCreateCount >= 4 then
        __mytersWearBootCreateCount = 0
        if (os.clock() - __mytersWearBootSliceAt) >= 0.004 then
            __mytersWearBootRunService.Heartbeat:Wait()
            __mytersWearBootSliceAt = os.clock()
        end
    end
end

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService      = game:GetService("InsertService")
local TweenService       = game:GetService("TweenService")
local UIS                = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")
local CoreGui            = game:GetService("CoreGui")
local LogService         = game:GetService("LogService")

local player = Players.LocalPlayer
if not player then
	pcall(function() Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end)
	player = Players.LocalPlayer
end
if not player then
	for _ = 1, 50 do
		player = Players.LocalPlayer
		if player then break end
		task.wait(0.05)
	end
end
if not player then
	warn("[Myters] ERROR: LocalPlayer is nil (MytersWear)")
	return
end
local mytersEnv = (getgenv and getgenv()) or _G
-- MytersWear se compila con loadstring en un chunk independiente: no puede ver
-- la funcion local del script principal. Leer el marcador compartido evita nil.
local function __mytersInRoundTransition()
    local untilTime = tonumber(mytersEnv.__mytersRoundTransitionUntil) or 0
    return os.clock() < untilTime
end
mytersEnv.MytersWearClosed = false
rawset(_G, "MytersWearClosed", false)
local mytersWearConnections = {}
mytersEnv.MytersWearConnections = mytersWearConnections
local function mytersWearConnect(signal, callback)
    if not signal or type(signal.Connect) ~= "function" then return nil end
    local connection = signal:Connect(callback)
    table.insert(mytersWearConnections, connection)
    return connection
end
local function mytersWearDisconnectAll()
    for i = #mytersWearConnections, 1, -1 do
        local connection = mytersWearConnections[i]
        mytersWearConnections[i] = nil
        pcall(function() connection:Disconnect() end)
    end
    local logConnection = mytersEnv.MytersWearLogConnection
    mytersEnv.MytersWearLogConnection = nil
    pcall(function() if logConnection then logConnection:Disconnect() end end)
end
local persistentConfig = mytersEnv.MytersWearPersistentConfig or {}
local persistentWorn = {}
local persistentUI = mytersEnv.MytersUIState or {}
local savedItems = mytersEnv.MytersSavedItems or {}
local savedAvatars = mytersEnv.MytersSavedAvatars or {}
-- El clonador aplica una descripción completa al personaje local. Mientras dura
-- la operación, MytersWear no debe reaplicar el outfit anterior por respawn o por
-- su escáner de mantenimiento, porque eso pisa colores, escalas y accesorios.
local cloneAppearance = mytersEnv.MytersCloneAppearance or {}
cloneAppearance.locked = cloneAppearance.locked == true
mytersEnv.MytersCloneAppearance = cloneAppearance
mytersEnv.MytersWearPersistentConfig = persistentConfig
mytersEnv.MytersWornState = persistentWorn
mytersEnv.MytersUIState = persistentUI
mytersEnv.MytersSavedItems = savedItems
mytersEnv.MytersSavedAvatars = savedAvatars

-- Persistencia de avatares guardados y ajustes de MytersWear (no del outfit actual)
local WEAR_AV_FILE = "myters-config/wear-avatars.json"
local function wearEnsureFolder()
	-- Delta y otros executors pueden exponer makefolder sin isfolder.
	-- Intentar crear la carpeta dentro de pcall es seguro si ya existe.
	if type(makefolder) == "function" then
		local exists = false
		if type(isfolder) == "function" then
			local ok, value = pcall(isfolder, "myters-config")
			exists = ok and value == true
		end
		if not exists then pcall(makefolder, "myters-config") end
	end
end
local function wearSaveAvatarsDisk()
	if type(writefile) ~= "function" then return false end
	local ok = pcall(function()
		wearEnsureFolder()
		local envConfig = mytersEnv.MytersWearPersistentConfig or persistentConfig
		local envUI = mytersEnv.MytersUIState or persistentUI
		local envSavedItems = mytersEnv.MytersSavedItems or savedItems
		local payload = {
			avatars = {},
			config = envConfig,
			ui = envUI,
			savedItems = envSavedItems,
		}
		for _, a in ipairs(savedAvatars) do
			table.insert(payload.avatars, { name = a.name, state = a.state })
		end
		writefile(WEAR_AV_FILE, HttpService:JSONEncode(payload))
	end)
	return ok
end
local function wearLoadAvatarsDisk()
	-- isfile es opcional: algunos builds de Delta permiten readfile aunque no
	-- publiquen isfile. Probar la lectura directamente y validar el JSON después.
	if type(readfile) ~= "function" then return false end
	local readOk, raw = pcall(function()
		if type(isfile) == "function" then
			local checkOk, exists = pcall(isfile, WEAR_AV_FILE)
			if checkOk and exists == false then return nil end
		end
		return readfile(WEAR_AV_FILE)
	end)
	if not readOk or type(raw) ~= "string" or raw == "" then return false end
	local decodeOk, d = pcall(function() return HttpService:JSONDecode(raw) end)
	if not decodeOk or type(d) ~= "table" then return false end
	local function restoreIfEmpty(target, source)
		if type(target) ~= "table" or type(source) ~= "table" or next(target) ~= nil then return end
		for key, value in pairs(source) do target[key] = value end
	end
	restoreIfEmpty(persistentConfig, d.config)
	restoreIfEmpty(persistentUI, d.ui)
	restoreIfEmpty(savedItems, d.savedItems)
	if type(d.avatars) == "table" and #d.avatars > 0 and #savedAvatars == 0 then
		for _, a in ipairs(d.avatars) do
			if type(a) == "table" and type(a.state) == "table" then
				table.insert(savedAvatars, { name = a.name or "Avatar", state = a.state })
			end
		end
		mytersEnv.MytersSavedAvatars = savedAvatars
	end
	return true
end
wearLoadAvatarsDisk()

-- ──────────────────────────────────────────────
-- UTILS
-- ──────────────────────────────────────────────
local function tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quart), props):Play()
end

local function parseId(input)
    input = tostring(input or ""):match("^%s*(.-)%s*$")
    -- Conservar también el ID como texto: bundles UGC pueden usar IDs largos y
    -- convertirlos a number para reconstruir una URL puede producir notación científica.
    local raw = input:match("^%d+$") or
        input:match("/catalog/(%d+)") or
        input:match("/bundles/(%d+)") or
        input:match("/library/(%d+)") or
        input:match("/asset/%?id=(%d+)") or
        input:match("id=(%d+)") or
        input:match("/(%d+)/[^/]*$") or
        input:match("/(%d+)$")
    if not raw then return nil end
    return tonumber(raw), raw
end

local function exactCatalogId(id)
    local s = tostring(id or ""):match("^%s*(.-)%s*$")
    if s:match("^%d+$") then return s end
    local n = tonumber(s)
    if n then
        local ok, formatted = pcall(string.format, "%.0f", n)
        if ok and formatted then return formatted end
    end
    return s
end

local function safeHttp(url)
    local requester = request or (syn and syn.request) or http_request
    if not requester then return nil end
    local ok, response = pcall(requester, {Url=url, Method="GET"})
    local res = type(response) == "table" and (response.Body or response.body) or response
    if not ok or type(res) ~= "string" or res == "" then return nil end
    local jok, data = pcall(HttpService.JSONDecode, HttpService, res)
    return jok and data or nil
end

-- Cache de metadatos: Korblox y el mantenimiento consultan a menudo
-- los mismos IDs. Evita repetir llamadas de red a GetProductInfo en cada respawn.
local mytersProductInfoCache = {}
local function apiProductInfo(id)
    local key = tostring(id or "")
    if key == "" then return nil end
    local now = os.clock()
    local cached = mytersProductInfoCache[key]
    if cached and now - cached.at < (cached.value and 1800 or 5) then
        return cached.value or nil
    end
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(tonumber(id) or id, Enum.InfoType.Asset)
    end)
    mytersProductInfoCache[key] = { at = now, value = (ok and info) or false }
    return ok and info or nil
end

-- ──────────────────────────────────────────────
-- BACKUP DEL OUTFIT ORIGINAL (para restaurar)
-- ──────────────────────────────────────────────
local MytersOriginal = {
    shirt        = nil, -- ShirtTemplate original
    pants        = nil, -- PantsTemplate original
    tshirt       = nil, -- Graphic original
    accessories  = {},  -- lista de Accessory/Hat originales (clones)
    faceTexture  = nil,
    legs         = {},
    hipC0        = {},
    captured     = false,
    character    = nil,
}

local function captureOriginalOutfit(char)
    if not char then return end
    if MytersOriginal.captured and MytersOriginal.character == char then return end
    -- Cada respawn tiene piezas nuevas. No reutilizar MeshId/transparencias del
    -- personaje anterior porque eso desincroniza el rig y deja partes flotando.
    if MytersOriginal.character ~= char then
        MytersOriginal.shirt = nil
        MytersOriginal.pants = nil
        MytersOriginal.tshirt = nil
        MytersOriginal.accessories = {}
        MytersOriginal.faceTexture = nil
        MytersOriginal.legs = {}
        MytersOriginal.hipC0 = {}
        MytersOriginal.captured = false
    end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Shirt") and not v:GetAttribute("MytersWear") then
            MytersOriginal.shirt = v.ShirtTemplate
        elseif v:IsA("Pants") and not v:GetAttribute("MytersWear") then
            MytersOriginal.pants = v.PantsTemplate
        elseif v:IsA("ShirtGraphic") and not v:GetAttribute("MytersWear") then
            MytersOriginal.tshirt = v.Graphic
        elseif (v:IsA("Accessory") or v:IsA("Hat")) and not v:GetAttribute("MytersWear") then
            table.insert(MytersOriginal.accessories, v:Clone())
        end
    end
    local head = char:FindFirstChild("Head")
    if head then
        local face = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
        if face and not face:GetAttribute("MytersWear") then MytersOriginal.faceTexture = face.Texture end
    end
    local lowerTorso = char:FindFirstChild("LowerTorso")
    if lowerTorso then
        for _, side in ipairs({"Right", "Left"}) do
            local motor = lowerTorso:FindFirstChild(side .. "Hip")
            if motor and motor:IsA("Motor6D") then
                MytersOriginal.hipC0[side .. "Hip"] = motor.C0
            end
        end
    end
    for _, partName in ipairs({"Left Leg","Right Leg","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            MytersOriginal.legs[partName] = {
                meshId = part:IsA("MeshPart") and part.MeshId or nil,
                textureId = part:IsA("MeshPart") and part.TextureID or nil,
                baseTransparency = part.Transparency,
                transparency = part.LocalTransparencyModifier,
            }
        end
    end
    MytersOriginal.character = char
    MytersOriginal.captured = true
    pcall(function()
        getgenv().MytersOriginalOutfit = MytersOriginal
        _G.MytersOriginalOutfit = MytersOriginal
    end)
end

-- Después de clonar otro avatar, ese avatar pasa a ser el nuevo "original"
-- para que una futura acción de MytersWear no restaure la apariencia vieja.
local function recaptureOriginalOutfit(char)
    if not char then return false end
    MytersOriginal.shirt = nil
    MytersOriginal.pants = nil
    MytersOriginal.tshirt = nil
    MytersOriginal.accessories = {}
    MytersOriginal.faceTexture = nil
    MytersOriginal.legs = {}
    MytersOriginal.hipC0 = {}
    MytersOriginal.captured = false
    captureOriginalOutfit(char)
    return MytersOriginal.captured == true
end

-- ANTI-FLASHEO: true si esa clase de ropa ya está puesta con ese ID de MytersWear.
-- Tras un reset se re-aplica el outfit entero; sin esta comprobación, cada prenda ya
-- correcta se destruía y se volvía a crear, y eso se ve como un fogonazo/parpadeo
-- de la ropa aunque no haya cambiado nada.
local function mytersClothingAlreadyOn(char, className, id)
    if not char or not id then return false end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA(className) and v:GetAttribute("MytersWear") == true then
            local cur = tonumber(v:GetAttribute("MytersWearId"))
            if cur and cur == tonumber(id) then return true end
        end
    end
    return false
end

-- ──────────────────────────────────────────────
-- CONFIGURACIÓN
-- ──────────────────────────────────────────────
local MytersConfig = {
    multiAccessory = persistentConfig.multiAccessory ~= false,
    keepOnRespawn  = persistentConfig.keepOnRespawn ~= false,
    removeOriginal = persistentConfig.removeOriginal == true,
    autoLoadSkin   = persistentConfig.autoLoadSkin ~= false,
}

-- Lista de accesorios Myters actualmente equipados (para el modo "solo uno")
local mytersEquippedAccessories = {} -- { [id] = accessoryInstance }

-- Estado persistente del outfit puesto por Myters — sobrevive a CharacterAdded
-- Se usa para re-equipar automáticamente tras un respawn/reset
local MytersWornState = {
    shirtId       = persistentWorn.shirtId,
    pantsId       = persistentWorn.pantsId,
    tshirtId      = persistentWorn.tshirtId,
    headId        = persistentWorn.headId,
    faceId        = persistentWorn.faceId,
    accessoryIds  = table.clone(persistentWorn.accessoryIds or {}),
    hairIds       = table.clone(persistentWorn.hairIds or {}),
    legIds        = table.clone(persistentWorn.legIds or {}),
    legSides      = table.clone(persistentWorn.legSides or {}),
    bodyIds       = table.clone(persistentWorn.bodyIds or {}),
    bodyDescription = type(persistentWorn.bodyDescription) == "table" and table.clone(persistentWorn.bodyDescription) or nil,
    bundleRigSync = nil,
    bundleRigModel = nil,
}
local reapplyMytersLegs
local reapplyMytersBodySlots
local mytersEquipBodyAsset
local mytersBodySlotApplied
local mytersEquipBundleBodyRig
local mytersSerializeBundleBodyDescription
local mytersApplyBundleBodyVisuals
local mytersDestroyBundleBodyOverlay
local reapplyMytersHeadless
local runMytersDiagnostics
local applyDescriptionPreservingLegs
local verifyMytersItem
local descriptionHasId
local normalizeAssetType
local safeDescriptionField
local unequipItem
local compilerIssue
local MytersDiagnostic = mytersEnv.MytersWearDiagnostic or {
    checks=0,
    lastOk=nil,
    lastIssues={},
    checkedAt=0,
    autoRepair=true,
}
mytersEnv.MytersWearDiagnostic=MytersDiagnostic
MytersDiagnostic.compiler=MytersDiagnostic.compiler or {runs=0,errors={},current={},steps={}}
MytersDiagnostic.compiler.errors=MytersDiagnostic.compiler.errors or {}
MytersDiagnostic.compiler.steps=MytersDiagnostic.compiler.steps or {}

safeDescriptionField=function(desc,field)
    if not desc or not field then return nil end
    local ok,value=pcall(function() return desc[field] end)
    return ok and value or nil
end

local function compilerReport(id,stage,message,ok)
    local report=MytersDiagnostic.compiler or {steps={}}
    report.itemId=id
    report.lastStage=stage
    report.lastMessage=message
    report.ok=ok==true
    report.checkedAt=os.time()
    report.steps=report.steps or {}
    table.insert(report.steps,1,{stage=stage,message=message,ok=ok==true,at=os.time()})
    while #report.steps>12 do table.remove(report.steps) end
    MytersDiagnostic.compiler=report
    mytersEnv.MytersWearDiagnostic=MytersDiagnostic
    if ok==false and compilerIssue then
        compilerIssue("direct","LOAD_"..tostring(stage),tostring(message),id)
    end
end

compilerIssue=function(kind,code,message,context)
    local report=MytersDiagnostic.compiler or {runs=0,errors={},current={},steps={}}
    report.errors=report.errors or {}
    report.current=report.current or {}
    local entry={kind=kind or "direct",code=code or "MYTERS_ERROR",message=tostring(message),context=context,at=os.time()}
    table.insert(report.errors,1,entry)
    table.insert(report.current,entry)
    if entry.kind=="indirect" then
        report.indirectErrors=(report.indirectErrors or 0)+1
    else
        report.directErrors=(report.directErrors or 0)+1
    end
    while #report.errors>60 do table.remove(report.errors) end
    while #report.current>30 do table.remove(report.current) end
    report.lastError=entry
    MytersDiagnostic.compiler=report
    mytersEnv.MytersWearDiagnostic=MytersDiagnostic
end

local function compilerStart()
    local report=MytersDiagnostic.compiler or {errors={},steps={}}
    report.runs=(report.runs or 0)+1
    report.current={}
    report.directErrors=0
    report.indirectErrors=0
    report.startedAt=os.time()
    MytersDiagnostic.compiler=report
    return report
end

pcall(function()
    if mytersEnv.MytersWearLogConnection then mytersEnv.MytersWearLogConnection:Disconnect() end
    mytersEnv.MytersWearLogConnection=LogService.MessageOut:Connect(function(message,messageType)
        local text=tostring(message or "")
        local lower=text:lower()
        local relevant=lower:find("myterswear",1,true) or lower:find("accessory",1,true) or lower:find("humanoiddescription",1,true) or lower:find("addaccessory",1,true) or lower:find("equip",1,true)
        local failure=lower:find("fail",1,true) or lower:find("fall",1,true) or lower:find("error",1,true) or lower:find("invalid",1,true) or lower:find("already",1,true) or lower:find("not valid",1,true) or lower:find("no se pudo",1,true)
        local hardError=tostring(messageType):find("Error",1,true)
        local warningFailure=tostring(messageType):find("Warning",1,true) and failure
        if relevant and (hardError or warningFailure) then
            compilerIssue("indirect","ENGINE_LOG",text,"LogService.MessageOut")
        end
    end)
end)

local function persistMytersSession()
    mytersEnv.MytersWearPersistentConfig = {
        multiAccessory = MytersConfig.multiAccessory,
        keepOnRespawn = MytersConfig.keepOnRespawn,
        removeOriginal = MytersConfig.removeOriginal,
        autoLoadSkin = MytersConfig.autoLoadSkin,
        activeAvatarName = persistentConfig.activeAvatarName,
    }
    persistentConfig.multiAccessory = MytersConfig.multiAccessory
    persistentConfig.keepOnRespawn = MytersConfig.keepOnRespawn
    persistentConfig.removeOriginal = MytersConfig.removeOriginal
    persistentConfig.autoLoadSkin = MytersConfig.autoLoadSkin
    pcall(wearSaveAvatarsDisk)
    mytersEnv.MytersWornState = {
        shirtId=MytersWornState.shirtId, pantsId=MytersWornState.pantsId,
        tshirtId=MytersWornState.tshirtId, headId=MytersWornState.headId,
        faceId=MytersWornState.faceId, accessoryIds=table.clone(MytersWornState.accessoryIds),
        hairIds=table.clone(MytersWornState.hairIds), legIds=table.clone(MytersWornState.legIds),
        legSides=table.clone(MytersWornState.legSides),
        bodyIds=table.clone(MytersWornState.bodyIds),
        bodyDescription=MytersWornState.bodyDescription and table.clone(MytersWornState.bodyDescription) or nil,
    }
end

-- MytersWear guarda desde “Guardar avatar” y las acciones manuales.
-- El autosave global de Myters no persiste ni reaplica el outfit actual.

-- ──────────────────────────────────────────────
-- EQUIP — métodos directos al character
-- ──────────────────────────────────────────────

-- Para Shirt/Pants: el ShirtTemplate necesita el mismo ID del asset del catálogo
-- Roblox aceptar rbxassetid://ID directamente para items de catálogo modernos
-- assetdelivery solo se necesita para items legacy pre-2015
local mytersTemplateCache = {}
local function resolveTemplateId(assetId)
    -- Cache: antes hacia un HttpGet a assetdelivery en CADA llamada. Eso es una
    -- peticion de red bloqueante (y se repite en cada reintento de verificacion),
    -- ademas de que su id no siempre es el template de ropa clasica.
    local cache = mytersTemplateCache
    if cache[tostring(assetId)] ~= nil then return cache[tostring(assetId)] end
    local result = assetId
    local ok, res = pcall(function()
        return game:HttpGet("https://assetdelivery.roblox.com/v1/assetId/" .. assetId)
    end)
    if ok and type(res) == "string" then
        local loc = res:match('"location":"([^"]+)"')
        if loc then
            -- extraer ID del query string o path
            local rid = loc:match("[?&]id=(%d+)") or loc:match("/(%d+)[?/]") or loc:match("/(%d+)$")
            if rid and rid ~= tostring(assetId) then
                result = tonumber(rid)
            end
        end
    end
    cache[tostring(assetId)] = result
    return result
end

-- Template REAL de ropa clasica. El ID del catalogo (asset Shirt/T-Shirt) NO es el id de
-- la textura: p.ej. 855777286 -> template 855777285, 4047884939 -> 4047884910. Poner el
-- ID del catalogo en ShirtTemplate/Graphic deja la camisa en blanco, y GetObjects no
-- devuelve nada para estos assets. Se resuelve con un modelo temporal (no toca tu avatar).
local mytersClothTplCache = {}
local mytersClothTplOwner = {}
local function resolveClothingTemplate(kind, id)
    local key = kind .. ":" .. tostring(id)
    if mytersClothTplCache[key] then return mytersClothTplCache[key] end
    local nid = tonumber(id)
    if not nid then return nil end
    local ok, tpl = pcall(function()
        local d = Instance.new("HumanoidDescription")
        if kind == "Shirt" then d.Shirt = nid
        elseif kind == "Pants" then d.Pants = nid
        else d.GraphicTShirt = nid end
        local m = game:GetService("Players"):CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
        local r
        if m then
            local inst = m:FindFirstChildOfClass(kind)
            if inst then
                if kind == "Shirt" then r = inst.ShirtTemplate
                elseif kind == "Pants" then r = inst.PantsTemplate
                else r = inst.Graphic end
            end
            m:Destroy()
        end
        d:Destroy()
        return r
    end)
    if ok and type(tpl) == "string" and tpl ~= "" then
        -- Los ids nuevos NO estan cerca del id del catalogo (p.ej. 91884161160972 -> 81281625716753),
        -- asi que no se valida por cercania. Unica defensa: dos ids distintos no pueden
        -- compartir textura; si pasa, el motor devolvio otra prenda y se descarta.
        local owner = mytersClothTplOwner[kind .. ":" .. tpl]
        if owner and owner ~= key then
            warn("[MytersWear] template repetido (" .. tpl .. ") para " .. key .. ", descartado")
            return nil
        end
        mytersClothTplOwner[kind .. ":" .. tpl] = key
        mytersClothTplCache[key] = tpl
        return tpl
    end
    return nil
end

-- Obtener la URL de textura real del asset via assetdelivery
-- Cargar Shirt/Pants via GetObjects (mismo método confirmado que funciona con Accessory)
local function equipShirt(id, char)
    if not char then return false end
    captureOriginalOutfit(char)
    id = tonumber(id) or id
    if not id then return false end
    local tid = id
    pcall(function() tid = resolveTemplateId(id) or id end)
    tid = tonumber(tid) or tid

    -- ANTI-FLASHEO: si esta misma camisa ya está puesta, NO la quites ni la repongas.
    -- Quitarla y volver a crearla en cada reset es justo lo que hacía parpadear.
    if mytersClothingAlreadyOn(char, "Shirt", id) then
        MytersWornState.shirtId = id
        persistMytersSession()
        return true
    end

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Shirt") then pcall(function() v:Destroy() end) end
    end

    -- Camisa clasica: template real resuelto (el id del catalogo no sirve como textura)
    local realTpl = resolveClothingTemplate("Shirt", id)
    if realTpl then
        local sh = Instance.new("Shirt")
        sh.Name = "MytersShirt"
        sh.ShirtTemplate = realTpl
        pcall(function() sh:SetAttribute("MytersWear", true) end)
        pcall(function() sh:SetAttribute("MytersWearId", id) end)
        sh.Parent = char
        MytersWornState.shirtId = id
        persistMytersSession()
        return true
    end

    -- El que GANA es el ultimo aplicado, y el bucle los recorre en orden inverso,
    -- asi que templates[1] es el final. Para ropa CLASICA el ID del catalogo ES el
    -- template id, igual que usa equipPants. resolveTemplateId puede devolver otro id
    -- (hace HttpGet a assetdelivery) y entonces ShirtTemplate apuntava a un asset que
    -- no era la camisa: salia en blanco y verifyMytersItem tambien fallaba.
    local templates = {
        "rbxassetid://" .. tostring(id),
        "http://www.roblox.com/asset/?id=" .. tostring(id),
        "rbxassetid://" .. tostring(tid),
        "http://www.roblox.com/asset/?id=" .. tostring(tid),
    }

    -- 1) GetObjects
    local ok, result = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(tid))
    end)
    if ok and type(result) == "table" then
        for _, obj in ipairs(result) do
            local shirt = obj:IsA("Shirt") and obj or (obj:FindFirstChildOfClass("Shirt"))
            if shirt then
                shirt.Name = "MytersShirt"
                -- ANTI-FLASHEO: se aplican en orden inverso para que la última (la que
                -- queda) sea la URL válida. Dejar una inválida al final hacía que la
                -- textura fallara y la camisa saliera en blanco un instante.
                for i = #templates, 1, -1 do
                    local u = templates[i]
                    pcall(function() shirt.ShirtTemplate = u end)
                end
                pcall(function() shirt:SetAttribute("MytersWear", true) end)
                pcall(function() shirt:SetAttribute("MytersWearId", id) end)
                shirt.Parent = char
                MytersWornState.shirtId = id
                persistMytersSession()
                return true
            end
        end
    end

    -- 2) Instance.new + template URLs
    local shirt = Instance.new("Shirt")
    shirt.Name = "MytersShirt"
    -- ANTI-FLASHEO: orden inverso (la URL válida queda al final).
    for i = #templates, 1, -1 do
        local u = templates[i]
        pcall(function() shirt.ShirtTemplate = u end)
    end
    pcall(function() shirt:SetAttribute("MytersWear", true) end)
    pcall(function() shirt:SetAttribute("MytersWearId", id) end)
    shirt.Parent = char

    -- 3) SIN ApplyDescription: hum:ApplyDescription* reconstruye el avatar entero
    --    desde cero y eso se ve como un fogonazo de pantalla. La instancia Shirt
    --    ya está puesta y visible; no hace falta el camino por HumanoidDescription.

    MytersWornState.shirtId = id
    persistMytersSession()
    return true
end

local function equipPants(id, char)
    captureOriginalOutfit(char)
    id = tonumber(id) or id
    if not id then return false end
    -- ANTI-FLASHEO: si este mismo pantalón ya está puesto, NO lo quites ni lo repongas.
    if mytersClothingAlreadyOn(char, "Pants", id) then
        MytersWornState.pantsId = id
        persistMytersSession()
        return true
    end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Pants") then v:Destroy() end
    end
    -- Template REAL del pantalon (el id del catalogo no es la textura)
    local realPantsTpl = resolveClothingTemplate("Pants", id)
    if realPantsTpl then
        local pn = Instance.new("Pants")
        pn.Name = "MytersPants"
        pn.PantsTemplate = realPantsTpl
        pcall(function() pn:SetAttribute("MytersWear", true) end)
        pcall(function() pn:SetAttribute("MytersWearId", id) end)
        pn.Parent = char
        MytersWornState.pantsId = id
        persistMytersSession()
        return true
    end
    local function applyPantsObj(obj)
        if not obj then return false end
        obj.Name = "MytersPants"
        pcall(function() obj:SetAttribute("MytersWear", true) end)
        pcall(function() obj:SetAttribute("MytersWearId", id) end)
        pcall(function()
            if obj:IsA("Pants") then obj.PantsTemplate = "rbxassetid://" .. tostring(id) end
        end)
        obj.Parent = char
        MytersWornState.pantsId = id
        persistMytersSession()
        return true
    end
    local ok, result = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if ok and type(result) == "table" then
        for _, obj in ipairs(result) do
            if obj:IsA("Pants") then
                if applyPantsObj(obj) then return true end
            elseif obj:IsA("Model") or obj:IsA("Folder") then
                local pants = obj:FindFirstChildOfClass("Pants")
                if pants and applyPantsObj(pants) then
                    pcall(function() obj:Destroy() end)
                    return true
                end
            end
        end
    end
    local pants = Instance.new("Pants")
    pants.Name = "MytersPants"
    pants.PantsTemplate = "rbxassetid://" .. tostring(id)
    pcall(function() pants:SetAttribute("MytersWear", true) end)
    pcall(function() pants:SetAttribute("MytersWearId", id) end)
    pants.Parent = char
    MytersWornState.pantsId = id
    persistMytersSession()
    return true
end

local function equipTShirt(id, char)
    captureOriginalOutfit(char)
    id = tonumber(id) or id
    -- ANTI-FLASHEO: si esta misma camisa clásica ya está puesta, no la reponas.
    if mytersClothingAlreadyOn(char, "ShirtGraphic", id) then
        MytersWornState.tshirtId = id
        persistMytersSession()
        return true
    end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("ShirtGraphic") and v:GetAttribute("MytersWear") then v:Destroy() end
    end
    local tshirt = Instance.new("ShirtGraphic")
    tshirt.Name = "MytersTShirt"
    tshirt:SetAttribute("MytersWear", true)
    tshirt:SetAttribute("MytersWearId", id)
    tshirt.Parent = char
    -- Graphic necesita la imagen real, no el id del asset T-Shirt del catalogo
    local realGraphic = resolveClothingTemplate("ShirtGraphic", id)
    warn("[MytersWear] TSHIRT: Graphic = " .. tostring(realGraphic or ("rbxassetid://" .. tostring(id))))
    local ok, err = pcall(function()
        tshirt.Graphic = realGraphic or ("rbxassetid://" .. tostring(id))
    end)
    if not ok then
        warn("[MytersWear] TSHIRT: falló →", err)
        tshirt:Destroy()
    else
        MytersWornState.tshirtId = id
        warn("[MytersWear] TSHIRT: OK")
    end
    return ok
end

-- Accessory: usar HumanoidDescription.AddAccessory via método directo
-- El approach de SpecialMesh no funciona para accesorios de avatar modernos
-- porque Roblox necesita que sea un Accessory con Handle válido del servidor
local function equipAccessoryDirect(id, char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then warn("[MytersWear] ACC: no Humanoid") return false end

    captureOriginalOutfit(char)

    -- ANTI-FLASHEO: si este accesorio ya está puesto con este ID, no lo quites ni lo
    -- vuelvas a soldar. Esa quita+pone en cada reset hacía parpadear el personaje.
    for _, existing in ipairs(char:GetChildren()) do
        if (existing:IsA("Accessory") or existing:IsA("Hat"))
            and tonumber(existing:GetAttribute("MytersWearId")) == tonumber(id) then
            return true
        end
    end

    compilerReport(id,"loader","intentando GetObjects",nil)
    warn("[MytersWear] ACC: cargando via GetObjects id=" .. id)
    local ok, result = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)
    end)
    if not ok or not result or #result == 0 then compilerReport(id,"GetObjects","no devolvió objetos",false) end

    local acc = nil
    local function findAccessory(objects)
        if type(objects)~="table" then return nil end
        for _, obj in ipairs(objects) do
            if obj:IsA("Accessory") or obj:IsA("Hat") then
                return obj
            elseif obj:IsA("Model") or obj:IsA("Folder") then
                local found=obj:FindFirstChildWhichIsA("Accessory",true) or obj:FindFirstChildWhichIsA("Hat",true)
                if found then return found end
            end
        end
        return nil
    end
    acc=findAccessory(result)

    if not acc then
        compilerReport(id,"InsertService","intentando cargador alternativo",nil)
        local loadOk,container=pcall(function() return InsertService:LoadAsset(id) end)
        if loadOk and container then
            result={container}
            acc=findAccessory(result)
        end
        if not acc then compilerReport(id,"loader","no se encontró Accessory en ningún cargador",false) end
    end

    if not acc then warn("[MytersWear] ACC: no Accessory en result") return false end

    -- GetObjects puede devolver una instancia que Roblox considera ya vestida.
    -- Clonarla evita el error "Accessory is already being worn by another character".
    local cloneOk,cloned=pcall(function() return acc:Clone() end)
    if cloneOk and cloned then acc=cloned end

    local handle = acc:FindFirstChild("Handle")
    if not handle then compilerReport(id,"validación","Accessory sin Handle",false); warn("[MytersWear] ACC: no Handle") return false end
    compilerReport(id,"validación","Accessory y Handle encontrados",true)
    for _,obj in ipairs(handle:GetChildren()) do
        if obj:IsA("Weld") or obj:IsA("WeldConstraint") or obj:IsA("AccessoryWeld") then obj:Destroy() end
    end

    -- Solo sustituir después de cargar y validar el nuevo accesorio.
    if not MytersConfig.multiAccessory then
        for _, existing in ipairs(char:GetChildren()) do
            if (existing:IsA("Accessory") or existing:IsA("Hat"))
                and (existing:GetAttribute("MytersWear") == true or existing:GetAttribute("MytersWearId") ~= nil) then existing:Destroy() end
        end
        mytersEquippedAccessories = {}
        MytersWornState.accessoryIds = {}
        MytersWornState.hairIds = {}
    else
        for _, existing in ipairs(char:GetChildren()) do
            if (existing:IsA("Accessory") or existing:IsA("Hat"))
                and existing:GetAttribute("MytersWearId") == id then existing:Destroy() end
        end
    end

    acc:SetAttribute("MytersWear", true)
    acc:SetAttribute("MytersWearId", id)

    -- Loguear todos los attachments del handle y del char
    warn("[MytersWear] ACC: Handle children:")
    for _, c in ipairs(handle:GetChildren()) do
        warn("  →", c.ClassName, c.Name)
    end

    -- Buscar qué attachment tiene el handle (HatAttachment, FaceFrontAttachment, etc.)
    local handleAtt = handle:FindFirstChildOfClass("Attachment")
    warn("[MytersWear] ACC: handleAtt =", handleAtt and handleAtt.Name or "NINGUNO")

    -- Buscar el attachment correspondiente en el char
    local targetPart = nil
    local targetAtt  = nil
    if handleAtt then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("Attachment") and part.Name == handleAtt.Name and part.Parent ~= handle then
                targetAtt  = part
                targetPart = part.Parent
                break
            end
        end
    end
    warn("[MytersWear] ACC: targetPart =", targetPart and targetPart.Name or "NINGUNO")
    warn("[MytersWear] ACC: targetAtt  =", targetAtt  and targetAtt.Name  or "NINGUNO")

    -- Método 1: usar el Humanoid para crear el weld estándar.
    local addOk,addError=pcall(function() hum:AddAccessory(acc) end)
    if not addOk or acc.Parent~=char then pcall(function() acc.Parent=char end) end
    pcall(function() acc:SetAttribute("MytersWear",true); acc:SetAttribute("MytersWearId",id) end)
    compilerReport(id,"AddAccessory",addOk and "accesorio aceptado por Humanoid" or tostring(addError),addOk and acc.Parent==char)
    mytersEquippedAccessories[id] = acc
    do
        local already = false
        for _, existingId in ipairs(MytersWornState.accessoryIds) do
            if existingId == id then already = true break end
        end
        if not already then table.insert(MytersWornState.accessoryIds, id) end
    end

    -- Método 2: si Humanoid no hizo el weld, hacerlo manual via Attachment
    task.wait(0.1)
    if acc.Parent~=char then pcall(function() acc.Parent=char end) end
    if handle and handle.Parent and targetAtt then
        -- Usar RigidConstraint entre los attachments (más correcto que WeldConstraint)
        local existing = handle:FindFirstChildOfClass("RigidConstraint")
        if not existing then
            local rigid = Instance.new("RigidConstraint")
            rigid.Attachment0 = targetAtt
            rigid.Attachment1 = handleAtt
            rigid.Parent       = handle
            warn("[MytersWear] ACC: RigidConstraint creado entre", targetAtt.Name, "y", handleAtt.Name)
        end
    elseif handle and handle.Parent then
        -- fallback: WeldConstraint directo al Head
        local head = char:FindFirstChild("Head")
        if head then
            local w = Instance.new("WeldConstraint")
            w.Part0 = head; w.Part1 = handle; w.Parent = handle
            warn("[MytersWear] ACC: WeldConstraint fallback al Head")
        end
    end

    return true
end

-- HumanoidDescription patch: para layered clothing que SOLO funciona via HD
-- Aplica directo en HumanoidDescription sin ApplyDescription
local function patchHD(id, field, char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local desc = hum.HumanoidDescription
    if not desc then return false end

    -- Campos lista (accesorios)
    local listFields = {
        HatAccessory=true, FaceAccessory=true, NeckAccessory=true,
        ShouldersAccessory=true, FrontAccessory=true, BackAccessory=true,
        WaistAccessory=true, TShirtAccessory=true, ShirtAccessory=true,
        PantsAccessory=true, JacketAccessory=true, SweaterAccessory=true,
        ShortsAccessory=true, LeftShoeAccessory=true, RightShoeAccessory=true,
        DressSkirtAccessory=true, EyebrowAccessory=true, EyelashAccessory=true,
    }

    local ok
    if listFields[field] then
        ok = pcall(function()
            local cur = desc[field] or ""
            local ids = {}; local seen = {}
            for v in cur:gmatch("%d+") do
                if not seen[v] then seen[v]=true; table.insert(ids, v) end
            end
            local s = tostring(id)
            if not seen[s] then table.insert(ids, s) end
            desc[field] = table.concat(ids, ",")
        end)
    else
        ok = pcall(function() desc[field] = id end)
    end

    -- Forzar refresh del character disparando CharacterAdded workaround
    -- (cambiar un valor irrelevante de la desc para triggerar update)
    if ok then
        pcall(function()
            local cur = desc.DepthOffset
            desc.DepthOffset = cur + 0.001
            desc.DepthOffset = cur
        end)
    end

    return ok
end

-- Mapa AssetTypeId → método + campo HD
local TYPE_MAP = {
    -- {method, hdField}
    [11] = {"shirt",   "Shirt"},
    [12] = {"pants",   "Pants"},
    [2]  = {"tshirt",  "GraphicTShirt"},
    -- Accesorios clásicos → HD list field
    [8]  = {"acc_hd",  "HatAccessory"},
    [41] = {"acc_hd",  "HatAccessory"},
    [42] = {"acc_hd",  "FaceAccessory"},
    [43] = {"acc_hd",  "NeckAccessory"},
    [44] = {"acc_hd",  "ShouldersAccessory"},
    [45] = {"acc_hd",  "FrontAccessory"},
    [46] = {"acc_hd",  "BackAccessory"},
    [47] = {"acc_hd",  "WaistAccessory"},
    -- Layered clothing → HD
    [61] = {"acc_hd",  "TShirtAccessory"},
    [62] = {"acc_hd",  "ShirtAccessory"},
    [63] = {"acc_hd",  "PantsAccessory"},
    [64] = {"acc_hd",  "JacketAccessory"},
    [65] = {"acc_hd",  "SweaterAccessory"},
    [66] = {"acc_hd",  "ShortsAccessory"},
    [67] = {"acc_hd",  "LeftShoeAccessory"},
    [68] = {"acc_hd",  "RightShoeAccessory"},
    [69] = {"acc_hd",  "DressSkirtAccessory"},
    [72] = {"acc_hd",  "EyebrowAccessory"},
    [73] = {"acc_hd",  "EyelashAccessory"},
    -- Face / Head
    [18] = {"acc_hd",  "Face"},
    [17] = {"acc_hd",  "Head"},
}
local BODY_TYPE_FIELDS = {
    [27]="Torso", [28]="RightArm", [29]="LeftArm", [30]="LeftLeg",
}

-- Overlay aislado para piernas legacy en R15. Es importante no escribir MeshId
-- sobre RightUpperLeg/LeftUpperLeg: algunos rigs dejan el volumen original como
-- un bloque negro aunque la malla parezca haber cambiado.
local function mytersDestroyKorbloxVisual(char, attachName, wantedId)
    if not char then return end
    -- MytersWear crea el overlay como hijo directo del Character; no recorrer todo el rig.
    for _, obj in ipairs(char:GetChildren()) do
        if obj.Name == "MytersKorbloxVisual" or obj:GetAttribute("MytersKorbloxVisual") == true then
            local samePart = not attachName or obj:GetAttribute("MytersKorbloxAttach") == attachName
            local sameId = not wantedId or tonumber(obj:GetAttribute("MytersKorbloxId")) == tonumber(wantedId)
            if samePart and sameId then pcall(function() obj:Destroy() end) end
        end
    end
end

local function mytersApplyKorbloxHipLift(char, side, lift)
    if not char then return false end
    local lowerTorso = char:FindFirstChild("LowerTorso")
    local motor = lowerTorso and lowerTorso:FindFirstChild((side or "Right") .. "Hip")
    if not motor or not motor:IsA("Motor6D") then return false end
    local key = (side or "Right") .. "Hip"
    local original = MytersOriginal.hipC0[key]
    if not original then
        original = motor.C0
        MytersOriginal.hipC0[key] = original
    end
    motor.C0 = original + Vector3.new(0, tonumber(lift) or 0.65, 0)
    return true
end

local function mytersRestoreKorbloxHip(char, side)
    if not char then return false end
    local lowerTorso = char:FindFirstChild("LowerTorso")
    local motor = lowerTorso and lowerTorso:FindFirstChild((side or "Right") .. "Hip")
    local original = MytersOriginal.hipC0[(side or "Right") .. "Hip"]
    if motor and motor:IsA("Motor6D") and original then
        motor.C0 = original
        return true
    end
    return false
end

local mytersKorbProtoCache = {}
local function mytersGetKorbloxProto(meshId, textureId)
    local key = tostring(meshId) .. "|" .. tostring(textureId or "")
    local c = mytersKorbProtoCache[key]
    if c then return c.part, c.h, true end
    local mp, mh = __MytersL.KorbMeshPart(meshId, textureId)
    local part, h
    if mp then
        part, h = mp, mh
    else
        part = Instance.new("Part")
        part.Size = Vector3.new(1, 2.6, 1)
        local sm = Instance.new("SpecialMesh")
        sm.Name = "MytersKorbloxMesh"
        sm.MeshType = Enum.MeshType.FileMesh
        sm.MeshId = meshId
        sm.TextureId = textureId or ""
        sm.Parent = part
        h = 2.6
    end
    if mp then
        mytersKorbProtoCache[key] = { part = part, h = h }
        return part, h, true
    end
    return part, h, false
end
local mytersKorbFallbackAt = 0

local function mytersEnsureKorbloxVisual(char, attachPart, meshId, textureId, id)
    if not char or not attachPart or not meshId then return nil end
    for _, obj in ipairs(char:GetChildren()) do
        if obj.Name == "MytersKorbloxVisual"
            and obj:GetAttribute("MytersKorbloxAttach") == attachPart.Name
            and tonumber(obj:GetAttribute("MytersKorbloxId")) == tonumber(id)
            and tostring(obj:GetAttribute("MytersKorbloxMeshId") or "") == tostring(meshId) then
            local w = obj:FindFirstChild("MytersKorbloxVisualWeld")
            local stale = obj:GetAttribute("MytersKorbFallback") == true and os.clock() - mytersKorbFallbackAt > 3
            if obj:IsA("BasePart") and w and w:IsA("Weld") and not stale then
                if w.Part0 ~= attachPart then w.Part0 = attachPart end
                return obj
            end
        end
    end
    local proto, h, real = mytersGetKorbloxProto(meshId, textureId)
    if not real then mytersKorbFallbackAt = os.clock() end
    if setthreadidentity then pcall(setthreadidentity, 8) end
    if not char.Parent or not attachPart.Parent then return nil end
    mytersDestroyKorbloxVisual(char, attachPart.Name)

    local visual = proto:Clone()
    visual.Name = "MytersKorbloxVisual"
    visual.Anchored = false
    visual.CanCollide = false
    visual.CanTouch = false
    visual.CanQuery = false
    visual.Massless = true
    visual.CastShadow = false
    visual.Transparency = 0
    visual:SetAttribute("MytersKorbloxVisual", true)
    visual:SetAttribute("MytersKorbloxOwner", "MytersWear")
    visual:SetAttribute("MytersKorbloxAttach", attachPart.Name)
    visual:SetAttribute("MytersKorbloxId", id)
    visual:SetAttribute("MytersKorbloxMeshId", tostring(meshId))
    if not real then visual:SetAttribute("MytersKorbFallback", true) end

    local hipName = (attachPart.Name:gsub("UpperLeg", "Hip"))
    local hip = attachPart:FindFirstChild(hipName)
    local jp = (hip and hip:IsA("JointInstance") and hip.C1.Position) or Vector3.new(0, 0.5, 0)
    local weld = Instance.new("Weld")
    weld.Name = "MytersKorbloxVisualWeld"
    weld.Part0 = attachPart
    weld.Part1 = visual
    weld.C0 = CFrame.new(jp.X, jp.Y - h / 2, jp.Z)
    weld.Parent = visual
    visual.CFrame = attachPart.CFrame * weld.C0
    visual.Parent = char
    return visual
end

-- Respaldo para assets que Roblox no permite cargar con GetObjects.
-- Se usa HumanoidDescription únicamente si el accesorio no pudo insertarse directamente.
local function equipAccessoryDescription(id, typeId, char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local field = TYPE_MAP[typeId] and TYPE_MAP[typeId][2]
    local listFields = {
        HatAccessory=true, FaceAccessory=true, NeckAccessory=true,
        ShouldersAccessory=true, FrontAccessory=true, BackAccessory=true,
        WaistAccessory=true, TShirtAccessory=true, ShirtAccessory=true,
        PantsAccessory=true, JacketAccessory=true, SweaterAccessory=true,
        ShortsAccessory=true, LeftShoeAccessory=true, RightShoeAccessory=true,
        DressSkirtAccessory=true, EyebrowAccessory=true, EyelashAccessory=true,
    }
    if typeId==8 or typeId==41 then field="HatAccessory" end
    if not field or not listFields[field] then return false end

    local ok, desc = pcall(function()
        if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
        return hum.HumanoidDescription
    end)
    if not ok or not desc then return false end

    local ids={}; local seen={}
    if MytersConfig.multiAccessory then
        for v in tostring(desc[field] or ""):gmatch("%d+") do
            if not seen[v] then seen[v]=true; table.insert(ids,v) end
        end
    end
    local sid=tostring(id)
    if not seen[sid] then table.insert(ids,sid) end
    local callOk,applied=pcall(function()
        desc[field]=table.concat(ids,",")
        return applyDescriptionPreservingLegs(desc,hum,char)
    end)
    if not callOk or not applied then return false end

    return true
end

-- Piezas de pierna legacy tipo Korblox (AssetTypeId 31 = LeftLeg / RightLeg mesh)
-- Estos NO son accesorios equipables — son mallas que reemplazan las piernas
-- del avatar directamente (como hace el script de Korblox)
local mytersLegMeshAssetCache = {}
local function mytersResolveLegMeshAsset(id)
    local key = tostring(id)
    local cached = mytersLegMeshAssetCache[key]
    if cached then return cached.meshId, cached.textureId end

    local ok, result = pcall(function()
        return game:GetObjects("rbxassetid://" .. key)
    end)
    if not ok or type(result) ~= "table" or #result == 0 then
        warn("[MytersWear] LEG-MESH: GetObjects falló →", result)
        return nil, nil
    end

    local meshId, textureId
    for _, obj in ipairs(result) do
        if obj:IsA("MeshPart") then
            meshId = obj.MeshId
            pcall(function() textureId = obj.TextureID end)
        elseif obj:IsA("SpecialMesh") then
            meshId = obj.MeshId
            textureId = obj.TextureId
        elseif obj:IsA("Model") or obj:IsA("Folder") then
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("MeshPart") and not meshId then
                    meshId = d.MeshId
                    pcall(function() textureId = d.TextureID end)
                elseif d:IsA("SpecialMesh") and not meshId then
                    meshId = d.MeshId
                    textureId = d.TextureId
                end
            end
        end
    end
    -- GetObjects devuelve instancias temporales; no deben quedar acumuladas en memoria.
    for _, obj in ipairs(result) do pcall(function() obj:Destroy() end) end
    if not meshId or meshId == "" then return nil, nil end
    mytersLegMeshAssetCache[key] = { meshId = meshId, textureId = textureId or "" }
    return meshId, textureId
end

local function mytersEquipOfficialR15Leg(id, char, isRight)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then
        return false, "se requiere un personaje R15"
    end
    if type(mytersEquipBundleBodyRig) ~= "function" then
        return false, "el constructor de rig R15 no está disponible"
    end

    local descOk, desc = pcall(function() return hum:GetAppliedDescription() end)
    if not descOk or not desc or not desc:IsA("HumanoidDescription") then
        return false, "no se pudo leer HumanoidDescription"
    end

    local slots = {}
    local fieldOrder = {"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}
    local validFields = {
        Head = true, Torso = true, RightArm = true, LeftArm = true,
        RightLeg = true, LeftLeg = true,
    }

    -- Preserve other MytersWear body pieces by rebuilding them into the same rig.
    for _, field in ipairs(fieldOrder) do
        local savedId = tonumber(MytersWornState.bodyIds and MytersWornState.bodyIds[field])
        if savedId and savedId > 0 and not (field == "Head" and savedId == 15093053680) then
            slots[field] = {id = savedId}
            pcall(function() desc[field] = savedId end)
        end
    end

    -- Also preserve body overlays that may have been created by a previous bundle.
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj:GetAttribute("MytersWearBodyVisual") == true then
            local field = tostring(obj:GetAttribute("MytersWearBodyField") or "")
            local bodyId = tonumber(obj:GetAttribute("MytersWearBodyId"))
            if validFields[field] and bodyId and bodyId > 0
                and not (field == "Head" and bodyId == 15093053680)
                and not slots[field] then
                slots[field] = {id = bodyId}
                pcall(function() desc[field] = bodyId end)
            end
        end
    end

    local targetField = isRight and "RightLeg" or "LeftLeg"
    local sideName = isRight and "Right" or "Left"
    local numericId = tonumber(id) or id
    slots[targetField] = {id = numericId}
    local setOk, setError = pcall(function() desc[targetField] = numericId end)
    if not setOk then
        pcall(function() desc:Destroy() end)
        return false, "Roblox rechazó " .. targetField .. ": " .. tostring(setError)
    end

    local order = {}
    for _, field in ipairs(fieldOrder) do
        if slots[field] then table.insert(order, field) end
    end

    local applied, failed, errors
    local applyOk, applyError = pcall(function()
        applied, failed, errors = mytersEquipBundleBodyRig(slots, order, char, desc)
    end)

    local serialized
    pcall(function() serialized = mytersSerializeBundleBodyDescription(desc) end)
    pcall(function()
        if mytersApplyBundleBodyVisuals then mytersApplyBundleBodyVisuals(char, desc) end
    end)
    pcall(function() desc:Destroy() end)

    if not applyOk then
        return false, tostring(applyError)
    end
    if (tonumber(applied) or 0) < #order or (tonumber(failed) or 0) > 0 then
        local why = errors and (errors[targetField] or errors.RightLeg or errors.LeftLeg)
        return false, tostring(why or "Roblox no pudo montar el segmento R15")
    end

    MytersWornState.bodyIds[targetField] = numericId
    if serialized then MytersWornState.bodyDescription = serialized end

    -- Tag the original target segment for fast checks; the visible Korblox mesh
    -- lives in MytersBundleBodyRig and follows the live Motor6D transforms.
    local upperName = isRight and "RightUpperLeg" or "LeftUpperLeg"
    local upper = char:FindFirstChild(upperName)
    if upper then
        pcall(function()
            upper:SetAttribute("MytersKorbloxId", numericId)
            upper:SetAttribute("MytersKorbloxNative", nil)
            upper:SetAttribute("MytersKorbloxMeshId", nil)
        end)
    end

    MytersWornState.legSides = MytersWornState.legSides or {}
    local keptLegIds = {}
    for _, previousId in ipairs(MytersWornState.legIds or {}) do
        local previousKey = tostring(previousId)
        local previousSide = MytersWornState.legSides[previousKey]
        if previousSide ~= sideName then
            table.insert(keptLegIds, previousId)
        else
            MytersWornState.legSides[previousKey] = nil
        end
    end
    table.insert(keptLegIds, numericId)
    MytersWornState.legIds = keptLegIds
    MytersWornState.legSides[tostring(numericId)] = sideName
    persistMytersSession()
    return true
end

local function equipLegMeshDirectCore(id, char, forcedRight)
    if not char or char ~= player.Character or not char.Parent then return false end
    warn("[MytersWear] LEG-MESH: resolviendo malla id=" .. id)
    -- Restore the previous manual Korblox hip offset before recording the
    -- baseline, so the authentic R15 part starts from the avatar's real joint.
    pcall(function()
        local kh = mytersEnv.MytersKorbloxHeadlessControl
        if kh and kh.isEnabled and kh.isEnabled() and kh.set then kh.set(false) end
    end)
    pcall(function() mytersRestoreKorbloxHip(char, forcedRight == false and "Left" or "Right") end)
    captureOriginalOutfit(char)
    -- Determinar primero rig y lado: Korblox Deathspeaker R15 usa IDs conocidos
    -- y no necesita bloquearse esperando GetObjects.
    local isRight = forcedRight == nil and true or forcedRight
    if forcedRight == nil then
        local info = apiProductInfo(id)
        if info and info.Name then
            local n = info.Name:lower()
            if n:find("left") or n:find("izquierd") then isRight = false end
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
    if isR15 and (
        ((not isRight) and tonumber(id) == 139607673)
    ) then
        local fitted, fitError = mytersEquipOfficialR15Leg(id, char, isRight)
        if fitted then
            warn("[MytersWear] LEG-MESH: pieza oficial R15 montada con sus uniones originales")
            return true
        end
        warn("[MytersWear] LEG-MESH: no se pudo generar el rig oficial: " .. tostring(fitError))
        -- Let equipSingleCore try its HumanoidDescription fallback; do not
        -- silently replace the R15 segment with a stretched upper-leg mesh.
        return false
    end
    local meshId, textureId
    if isR15 and isRight and tonumber(id) == 139607718 then
        meshId, textureId = "rbxassetid://902942096", "rbxassetid://902843398"
    else
        meshId, textureId = mytersResolveLegMeshAsset(id)
    end
    if not meshId then
        warn("[MytersWear] LEG-MESH: no se encontró MeshId en el asset")
        return false
    end
    warn("[MytersWear] LEG-MESH: meshId=", meshId, "textureId=", textureId)

    local partNames
    if isR15 then
        partNames = isRight
            and {"RightUpperLeg","RightLowerLeg","RightFoot"}
            or  {"LeftUpperLeg","LeftLowerLeg","LeftFoot"}
    else
        partNames = isRight and {"Right Leg"} or {"Left Leg"}
    end

    -- En R15 el overlay vive en una Part separada. Primero se restaura la
    -- malla original por si quedó modificada por una versión anterior.
    local visualOk = false
    local nativeMeshOk = false
    if isR15 then
        local rootPart = char:FindFirstChild(partNames[1])
        mytersDestroyKorbloxVisual(char, partNames[1])
        if false and rootPart and rootPart:IsA("MeshPart") then
            nativeMeshOk = pcall(function()
                rootPart.MeshId = meshId
                rootPart.TextureID = textureId or ""
                rootPart.Transparency = 0
                rootPart.LocalTransparencyModifier = 0
                rootPart:SetAttribute("MytersKorbloxNative", true)
                rootPart:SetAttribute("MytersKorbloxMeshId", tostring(meshId))
            end)
        end
        if nativeMeshOk then
            visualOk = true
        else
            -- Fallback only if the runtime blocks MeshPart.MeshId writes.
            visualOk = mytersEnsureKorbloxVisual(char, rootPart, meshId, textureId, id) ~= nil
        end
    end

    local count = 0
    for i, partName in ipairs(partNames) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            if i == 1 and isR15 then
                pcall(function()
                    part:SetAttribute("MytersKorbloxId", id)
                    if nativeMeshOk then
                        part.Transparency = 0
                        part.LocalTransparencyModifier = 0
                        part:SetAttribute("MytersKorbloxNative", true)
                        part:SetAttribute("MytersKorbloxMeshId", tostring(meshId))
                    else
                        part.Transparency = 1
                        part.LocalTransparencyModifier = 1
                        part:SetAttribute("MytersKorbloxNative", nil)
                        part:SetAttribute("MytersWearVisual", true)
                    end
                end)
                if visualOk then count = count + 1 end
            elseif i == 1 then
                for _, child in ipairs(part:GetChildren()) do
                    if child.Name == "MytersLegMesh" or child.Name == "MytersKorbloxMesh" then
                        pcall(function() child:Destroy() end)
                    end
                end
                local wrote=false
                if part:IsA("MeshPart") then
                    wrote=pcall(function()
                        part.MeshId = meshId
                        if textureId and textureId ~= "" then part.TextureID = textureId end
                    end)
                else
                    local legMesh=part:FindFirstChild("MytersLegMesh")
                    if not legMesh then legMesh=Instance.new("SpecialMesh"); legMesh.Name="MytersLegMesh"; legMesh.Parent=part end
                    wrote=pcall(function()
                        legMesh.MeshType=Enum.MeshType.FileMesh
                        legMesh.MeshId=meshId
                        legMesh.TextureId=textureId or ""
                    end)
                end
                if wrote then
                    count=count+1
                    pcall(function() part:SetAttribute("MytersKorbloxId",id) end)
                end
            else
                pcall(function()
                    part.Transparency = 1
                    part.LocalTransparencyModifier = 1
                    part:SetAttribute("MytersKorbloxHidden",id)
                end)
            end
        end
    end
    if count > 0 then
        MytersWornState.legSides[tostring(id)] = isRight and "Right" or "Left"
        MytersWornState.bodyIds[isRight and "RightLeg" or "LeftLeg"] = id
        persistMytersSession()
    end
    warn("[MytersWear] LEG-MESH: aplicado en", count, "parte(s) —", isRight and "derecha" or "izquierda")
    return count > 0
end

local function equipLegMeshDirect(id, char, forcedRight)
    local kh = mytersEnv.MytersKorbloxHeadlessControl
    local wasOn = false
    pcall(function() wasOn = (kh and kh.isEnabled and kh.isEnabled() == true) or false end)
    local ok, res = pcall(equipLegMeshDirectCore, id, char, forcedRight)
    if wasOn then
        -- Player Animation se apagó solo para soltar la pierna; reactivar (Headless sigue activo,
        -- Korblox lo salta porque MytersWear ya es dueño de la pierna).
        task.delay(0.15, function()
            pcall(function()
                if kh and kh.set and kh.isEnabled and not kh.isEnabled() then kh.set(true) end
            end)
        end)
    end
    if not ok then
        warn("[MytersWear] LEG-MESH: error", res)
        return false
    end
    return res
end

-- ANTI-FLASHEO: true si esa pieza de pierna ya lleva esa malla puesta.
-- Reescribir MeshId hace parpadear la pierna, así que sólo se hace si falta.
local function mytersLegAlreadyApplied(char, id, forcedRight)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
    local partName
    if isR15 then
        partName = forcedRight and "RightUpperLeg" or "LeftUpperLeg"
    else
        partName = forcedRight and "Right Leg" or "Left Leg"
    end
    local part = char and char:FindFirstChild(partName)
    if isR15 and mytersBodySlotApplied then
        local field = forcedRight and "RightLeg" or "LeftLeg"
        local ok, applied = pcall(mytersBodySlotApplied, char, field, id)
        if ok and applied == true then return true end
    end
    if not part or not part:IsA("BasePart") then return false end
    return tonumber(part:GetAttribute("MytersKorbloxId")) == tonumber(id)
end

reapplyMytersLegs=function(char)
    if not char then return false end
    local any=false
    for _,id in ipairs(MytersWornState.legIds or {}) do
        local side=MytersWornState.legSides[tostring(id)]
        local forcedRight=side ~= "Left"
        if mytersLegAlreadyApplied(char,id,forcedRight) then
            any=true
        elseif equipLegMeshDirect(id,char,forcedRight) then
            any=true
        end
    end
    -- Las piezas normales del bundle también se restauran directamente en R15.
    if reapplyMytersBodySlots then
        local bodyOk = false
        pcall(function() bodyOk = reapplyMytersBodySlots(char) == true end)
        any = bodyOk or any
    end
    return any
end

-- Mantenimiento Korblox (R15): existe solo mientras haya piernas MytersWear activas.
local mytersLegMaintBusy = false
local mytersLegMaintThread = nil
local function mytersStopLegMaintenance()
    local thread = mytersLegMaintThread
    mytersLegMaintThread = nil
    if thread then pcall(task.cancel, thread) end
end
local function mytersStartLegMaintenance()
    if mytersEnv.MytersWearClosed == true or rawget(_G, "MytersSessionClosed")
        or #(MytersWornState.legIds or {}) == 0 then
        mytersStopLegMaintenance()
        return
    end
    if mytersLegMaintThread and coroutine.status(mytersLegMaintThread) ~= "dead" then return end
    mytersLegMaintThread = task.defer(function()
        local thisThread = coroutine.running()
        while mytersEnv.MytersWearClosed ~= true and not rawget(_G, "MytersSessionClosed")
            and #(MytersWornState.legIds or {}) > 0 do
            task.wait(0.4)
            if #(MytersWornState.legIds or {}) > 0 and not mytersLegMaintBusy then
                mytersLegMaintBusy = true
                pcall(function()
                    if __mytersInRoundTransition() or cloneAppearance.locked then return end
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if not char or not char.Parent or not hum or hum.Health <= 0 then return end
                    if hum.RigType ~= Enum.HumanoidRigType.R15 then return end
                    for _, id in ipairs(MytersWornState.legIds or {}) do
                        local left = MytersWornState.legSides[tostring(id)] == "Left"
                        local prefix = left and "Left" or "Right"
                        local upper = char:FindFirstChild(prefix .. "UpperLeg")
                        local field = prefix .. "Leg"
                        local bodyRigApplied = false
                        if mytersBodySlotApplied then
                            local ok, value = pcall(mytersBodySlotApplied, char, field, id)
                            bodyRigApplied = ok and value == true
                        end
                        local nativeApplied = bodyRigApplied or (upper
                            and tonumber(upper:GetAttribute("MytersKorbloxId")) == tonumber(id))
                        if not nativeApplied then
                            equipLegMeshDirect(id, char, not left)
                        else
                            local wearVis = char:FindFirstChild("MytersKorbloxVisual")
                            if upper and upper:GetAttribute("MytersWearVisual") == true and not bodyRigApplied then
                                if wearVis and wearVis:GetAttribute("MytersKorbloxAttach") == upper.Name then
                                    pcall(function()
                                        upper.Transparency = 1
                                        upper.LocalTransparencyModifier = 1
                                    end)
                                else
                                    equipLegMeshDirect(id, char, not left)
                                end
                            else
                                pcall(function()
                                    upper.Transparency = 0
                                    upper.LocalTransparencyModifier = 0
                                end)
                            end
                            for _, n in ipairs({prefix .. "LowerLeg", prefix .. "Foot"}) do
                                local part = char:FindFirstChild(n)
                                if part and part:IsA("BasePart") then
                                    if part.Transparency < 1 then part.Transparency = 1 end
                                    if part.LocalTransparencyModifier < 1 then part.LocalTransparencyModifier = 1 end
                                end
                            end
                        end
                    end
                end)
                mytersLegMaintBusy = false
            end
        end
        if mytersLegMaintThread == thisThread then mytersLegMaintThread = nil end
    end)
end
if #(MytersWornState.legIds or {}) > 0 then mytersStartLegMaintenance() end

applyDescriptionPreservingLegs=function(desc, hum, char)
    -- Los slots corporales no son accesorios y deben sobrevivir a cualquier
    -- ApplyDescription usado como respaldo.
    for field,id in pairs(MytersWornState.bodyIds or {}) do
        if id then desc[field]=id end
    end
    if MytersWornState.headId then desc.Head=MytersWornState.headId end
    if MytersWornState.faceId then desc.Face=MytersWornState.faceId end
    if MytersWornState.shirtId then desc.Shirt=MytersWornState.shirtId end
    if MytersWornState.pantsId then desc.Pants=MytersWornState.pantsId end
    if MytersWornState.tshirtId then desc.GraphicTShirt=MytersWornState.tshirtId end
    for key,side in pairs(MytersWornState.legSides or {}) do
        local id=tonumber(key) or key
        if side=="Right" then desc.RightLeg=id elseif side=="Left" then desc.LeftLeg=id end
    end
    for _,id in ipairs(MytersWornState.legIds or {}) do
        local key=tostring(id)
        if not MytersWornState.legSides[key] then
            local info=apiProductInfo(id)
            local name=tostring(info and info.Name or ""):lower()
            local side=(name:find("left",1,true) or name:find("izquier",1,true)) and "Left" or "Right"
            MytersWornState.legSides[key]=side
            if side=="Right" then desc.RightLeg=id else desc.LeftLeg=id end
        end
    end
    persistMytersSession()
    local callOk,applied=pcall(function()
        -- API pública de Humanoid. La llamada puede devolver nil aun si termina bien.
        hum:ApplyDescriptionAsync(desc)
        return true
    end)
    applied = callOk and applied == true
    if applied then
        task.defer(function()
            task.wait(.3)
            if char and char.Parent then
                -- ApplyDescription puede recrear Head y quitar el overlay
                -- local de Headless. Reaplicar ambos overlays después de
                -- cualquier accesorio evita que desaparezcan.
                if reapplyMytersHeadless then pcall(reapplyMytersHeadless, char) end
                if reapplyMytersLegs then pcall(reapplyMytersLegs, char) end
            end
        end)
    end
    return callOk and applied or false
end

local function equipLegDescription(id, typeId, char)
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local ok,desc=pcall(function()
        if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
        return hum.HumanoidDescription
    end)
    if not ok or not desc then return false end
    local callOk,applied=pcall(function()
        if typeId==32 then desc.RightLeg=id else desc.LeftLeg=id end
        return applyDescriptionPreservingLegs(desc,hum,char)
    end)
    if callOk and applied then
        table.insert(MytersWornState.legIds,id)
        mytersStartLegMaintenance()
        MytersWornState.legSides[tostring(id)] = typeId==32 and "Right" or "Left"
        MytersWornState.bodyIds[typeId==32 and "RightLeg" or "LeftLeg"] = id
        persistMytersSession()
    end
    return callOk and applied or false
end

local function equipBodyDescription(id, typeId, char)
    local field = BODY_TYPE_FIELDS[typeId]
    if not field or not mytersEquipBodyAsset then return false end
    local ok, err = mytersEquipBodyAsset(field, id, char)
    if not ok then warn("[MytersWear] no se pudo sustituir la pieza R15 " .. tostring(field) .. ": " .. tostring(err)) end
    return ok == true
end

local function equipFaceDirect(id, char)
    local head=char and char:FindFirstChild("Head")
    if not head then return false end
    captureOriginalOutfit(char)
    for _, obj in ipairs(head:GetChildren()) do if obj:IsA("Decal") and obj:GetAttribute("MytersWear") then obj:Destroy() end end
    local decal
    local ok, result=pcall(function() return game:GetObjects("rbxassetid://"..id) end)
    if ok and result then
        for _, obj in ipairs(result) do
            if obj:IsA("Decal") then decal=obj; break end
            decal=obj:FindFirstChildWhichIsA("Decal",true)
            if decal then break end
        end
    end
    if not decal then decal=Instance.new("Decal"); decal.Texture="rbxassetid://"..id end
    decal.Name="MytersFace"; decal.Face=Enum.NormalId.Front; decal:SetAttribute("MytersWear",true); decal:SetAttribute("MytersFaceId",id); decal.Parent=head
    MytersWornState.faceId=id; persistMytersSession(); return true
end

local function equipHeadDirect(id, char)
    local head=char and char:FindFirstChild("Head")
    if not head then return false end
    captureOriginalOutfit(char)
    local ok, result=pcall(function() return game:GetObjects("rbxassetid://"..id) end)
    local meshId, textureId
    if ok and result then
        for _, obj in ipairs(result) do
            local meshPart=obj:IsA("MeshPart") and obj or obj:FindFirstChildWhichIsA("MeshPart",true)
            if meshPart then meshId=meshPart.MeshId; textureId=meshPart.TextureID; break end
            local mesh=obj:IsA("SpecialMesh") and obj or obj:FindFirstChildWhichIsA("SpecialMesh",true)
            if mesh then meshId=mesh.MeshId; textureId=mesh.TextureId; break end
        end
    end
    if not meshId or meshId=="" then return false end
    local mesh=head:FindFirstChildWhichIsA("SpecialMesh")
    if mesh then mesh.MeshId=meshId; mesh.TextureId=textureId or "" else
        local newMesh=Instance.new("SpecialMesh"); newMesh.MeshType=Enum.MeshType.FileMesh; newMesh.MeshId=meshId; newMesh.TextureId=textureId or ""; newMesh:SetAttribute("MytersWear",true); newMesh.Parent=head
    end
    head:SetAttribute("MytersHeadId",id)
    MytersWornState.headId=id; MytersWornState.bodyIds.Head=id; persistMytersSession(); return true
end

local function equipHeadDescription(id, char)
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local ok,desc=pcall(function()
        if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
        return hum.HumanoidDescription
    end)
    if not ok or not desc then return false end
    local callOk,applied=pcall(function()
        desc.Head=id
        return applyDescriptionPreservingLegs(desc,hum,char)
    end)
    if callOk and applied then MytersWornState.headId=id; MytersWornState.bodyIds.Head=id; persistMytersSession() end
    return callOk and applied
end

local MYTERS_HEADLESS_ASSET_ID = 15093053680

-- Ruta ligera: no consulta catálogo, no espera Humanoid/RootPart y no aplica
-- HumanoidDescription. Se usa al equipar y en cuanto aparece Head tras respawn.
local function mytersApplyHeadlessVisualImmediate(id, char)
    if tonumber(id) ~= MYTERS_HEADLESS_ASSET_ID or not char or char ~= player.Character then return false end
    local head = char:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return false end
    local ok = pcall(function()
        head.LocalTransparencyModifier = 1
        head.Transparency = 1
        head:SetAttribute("MytersHeadless", true)
        head:SetAttribute("MytersHeadId", MYTERS_HEADLESS_ASSET_ID)
        for _, obj in ipairs(head:GetChildren()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
                obj:SetAttribute("MytersHeadless", true)
            end
        end
    end)
    return ok
end

local function equipHeadlessVisual(id,char)
    local head=char and char:FindFirstChild("Head")
    if not head then return false end
    captureOriginalOutfit(char)
    if not mytersApplyHeadlessVisualImmediate(id, char) then return false end
    MytersWornState.headId=id
    MytersWornState.bodyIds.Head=id
    persistMytersSession()
    return true
end

-- ApplyDescription (usado al equipar accesorios) puede reemplazar Head y
-- borrar los flags/transparencias locales. El ID Headless se reaplica sin
-- esperar el resto del outfit.
reapplyMytersHeadless=function(char)
    char = char or player.Character
    if not char or tonumber(MytersWornState.headId) ~= MYTERS_HEADLESS_ASSET_ID then return false end
    return mytersApplyHeadlessVisualImmediate(MYTERS_HEADLESS_ASSET_ID, char)
end

local function equipSingleCore(id, typeId, char)
    -- Tipo 31: pieza de pierna legacy (Korblox y similares)
    if typeId == 31 or typeId == 32 then
        pcall(function()
            local kh = mytersEnv.MytersKorbloxHeadlessControl
            if kh and kh.isEnabled and kh.isEnabled() and kh.set then kh.set(false) end
        end)
        local forcedRight = (typeId == 32)
        -- ANTI-FLASHEO: si esa pierna ya lleva la malla, no la reescribas.
        if mytersLegAlreadyApplied(char, id, forcedRight) then
            local exists=false; for _,x in ipairs(MytersWornState.legIds) do if x==id then exists=true end end
            if not exists then table.insert(MytersWornState.legIds,id) end
            mytersStartLegMaintenance()
            persistMytersSession()
            return true, "leg-mesh"
        end
        local ok = equipLegMeshDirect(id, char, forcedRight)
        if not ok then ok=equipLegDescription(id,typeId,char) end
        if ok then
            local exists=false; for _,x in ipairs(MytersWornState.legIds) do if x==id then exists=true end end
            if not exists then table.insert(MytersWornState.legIds,id) end
            mytersStartLegMaintenance()
            persistMytersSession()
        end
        return ok, "leg-mesh"
    end
    if BODY_TYPE_FIELDS[typeId] then return equipBodyDescription(id,typeId,char),BODY_TYPE_FIELDS[typeId] end
    if typeId == 18 then return equipFaceDirect(id,char), "face" end
    if typeId == 17 or typeId == 79 then
        pcall(function()
            local kh = mytersEnv.MytersKorbloxHeadlessControl
            if kh and kh.isEnabled and kh.isEnabled() and kh.set then kh.set(false) end
        end)
        local isHeadless=(tonumber(id)==15093053680)
        local ok=isHeadless and equipHeadlessVisual(id,char) or ((typeId==79 and equipHeadDescription(id,char)) or equipHeadDirect(id,char))
        if not ok then ok=equipAccessoryDirect(id,char) end
        if not ok then ok=equipAccessoryDescription(id,typeId,char) end
        if not ok then ok=equipHeadDescription(id,char) end
        if ok then
            MytersWornState.headId=id
            for _,obj in ipairs(char:GetChildren()) do if obj:GetAttribute("MytersWearId")==id then obj:SetAttribute("MytersHead",true) end end
            persistMytersSession()
        end
        return ok, "head"
    end

    local entry = TYPE_MAP[typeId]
    if not entry then
        warn("[MytersWear] tipo no mapeado:", typeId, "— intentando GetObjects directo")
        local ok = equipAccessoryDirect(id, char)
        if not ok then ok=equipAccessoryDescription(id,typeId,char) end
        return ok, ok and "acc (tipo " .. typeId .. ")" or "falló, tipo desconocido id=" .. typeId
    end

    local method, field = entry[1], entry[2]
    warn("[MytersWear] método:", method, "campo:", field)

    if method == "shirt"  then return equipShirt(id, char),           "shirt"  end
    if method == "pants"  then return equipPants(id, char),           "pants"  end
    if method == "tshirt" then return equipTShirt(id, char),          "tshirt" end
    if method == "acc_hd" then
        local ok=equipAccessoryDirect(id,char)
        if not ok then ok=equipAccessoryDescription(id,typeId,char) end
        if ok then
            if typeId==41 then
                local exists=false; for _,x in ipairs(MytersWornState.hairIds) do if x==id then exists=true end end
                if not exists then table.insert(MytersWornState.hairIds,id) end
                for _,obj in ipairs(char:GetChildren()) do if obj:GetAttribute("MytersWearId")==id then obj:SetAttribute("MytersHair",true) end end
            else
                local exists=false; for _,x in ipairs(MytersWornState.accessoryIds) do if x==id then exists=true end end
                if not exists then table.insert(MytersWornState.accessoryIds,id) end
            end
            persistMytersSession()
        end
        return ok, field
    end

    return false, "método desconocido"
end

local function equipSingle(id,typeId,char)
    local keepLegs=#(MytersWornState.legIds or {})>0 or (MytersWornState.bodyIds and (MytersWornState.bodyIds.LeftLeg~=nil or MytersWornState.bodyIds.RightLeg~=nil))
    local keepHeadless=tonumber(MytersWornState.headId)==15093053680
    local ok,detail=equipSingleCore(id,typeId,char)
    if (keepLegs or keepHeadless) and tonumber(typeId)~=31 and tonumber(typeId)~=32 then
        -- ANTI-FLASHEO: un solo reintento. Con tres (0.2 / 0.7 / 1.35 s) la pierna
        -- reescribía su MeshId varias veces seguidas y se veía parpadear.
        task.delay(.35,function()
            if char and char.Parent and reapplyMytersLegs then
                if keepHeadless and reapplyMytersHeadless then pcall(reapplyMytersHeadless, char) end
                local restored=reapplyMytersLegs(char)
                if restored then compilerReport(id,"KorbloxGuard","malla de pierna reaplicada tras equipar otro item",true) end
                if not restored and keepLegs and compilerIssue then compilerIssue("indirect","KORBLOX_GUARD_FAILED","No se pudo reaplicar la malla de Korblox después del equipamiento.",id) end
            end
        end)
    end
    return ok,detail
end

-- ──────────────────────────────────────────────
-- RESTAURAR ORIGINAL
-- ──────────────────────────────────────────────

local function isMytersAccessory(acc)
    return (acc:IsA("Accessory") or acc:IsA("Hat"))
        and (acc:GetAttribute("MytersWear") == true or acc:GetAttribute("MytersWearId") ~= nil)
end

local function isHairAccessoryInstance(acc)
    if not (acc:IsA("Accessory") or acc:IsA("Hat")) then return false end
    local ok, kind = pcall(function() return acc.AccessoryType end)
    if ok and kind == Enum.AccessoryType.Hair then return true end
    local n = acc.Name:lower()
    return n:find("hair") ~= nil or n:find("pelo") ~= nil
end

local function isMytersClothing(obj, name)
    return obj:GetAttribute("MytersWear") == true or obj.Name == name
end

local function removeOriginalOutfit(char)
    if not char then return end
    for _, obj in ipairs(char:GetChildren()) do
        if not obj:GetAttribute("MytersWear") and obj:IsA("Shirt") then obj:Destroy() end
        if not obj:GetAttribute("MytersWear") and obj:IsA("Pants") then obj:Destroy() end
        if not obj:GetAttribute("MytersWear") and obj:IsA("ShirtGraphic") then obj:Destroy() end
        if not obj:GetAttribute("MytersWear") and (obj:IsA("Accessory") or obj:IsA("Hat")) then obj:Destroy() end
    end
end

-- Quitar Shirt puesta por Myters y devolver la original (si la había)
local function restoreShirt(char)
    if not char then return false end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Shirt") then v:Destroy() end
    end
    if MytersOriginal.shirt and MytersOriginal.shirt ~= "" then
        local shirt = Instance.new("Shirt")
        shirt.ShirtTemplate = MytersOriginal.shirt
        shirt.Parent = char
        warn("[MytersWear] Shirt original restaurada")
    else
        warn("[MytersWear] Shirt quitada (no había original)")
    end
    MytersWornState.shirtId=nil; persistMytersSession(); return true
end

-- Quitar Pants puestos por Myters y devolver los originales (si los había)
local function restorePants(char)
    if not char then return false end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Pants") then v:Destroy() end
    end
    if MytersOriginal.pants and MytersOriginal.pants ~= "" then
        local pants = Instance.new("Pants")
        pants.PantsTemplate = MytersOriginal.pants
        pants.Parent = char
        warn("[MytersWear] Pants originales restaurados")
    else
        warn("[MytersWear] Pants quitados (no había original)")
    end
    MytersWornState.pantsId=nil; persistMytersSession(); return true
end

-- Quitar T-Shirt (camisa clásica / graphic) puesta por Myters
local function restoreTShirt(char)
    if not char then return false end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("ShirtGraphic") then v:Destroy() end
    end
    if MytersOriginal.tshirt and MytersOriginal.tshirt ~= "" then
        local t = Instance.new("ShirtGraphic")
        t.Graphic = MytersOriginal.tshirt
        t.Parent = char
        warn("[MytersWear] T-Shirt original restaurada")
    else
        warn("[MytersWear] T-Shirt quitada (no había original)")
    end
    MytersWornState.tshirtId=nil; persistMytersSession(); return true
end

-- Quitar todos los accesorios puestos por Myters y devolver los originales
local function restoreAccessories(char)
    if not char then return false end
    for _, acc in ipairs(char:GetChildren()) do
        if isMytersAccessory(acc) and not isHairAccessoryInstance(acc) and acc:GetAttribute("MytersHair") ~= true then
            acc:Destroy()
        end
    end
    mytersEquippedAccessories = {}
    local existing = {}
    for _, acc in ipairs(char:GetChildren()) do
        if (acc:IsA("Accessory") or acc:IsA("Hat")) and not isMytersAccessory(acc) then existing[acc.Name] = true end
    end
    for _, original in ipairs(MytersOriginal.accessories) do
        if not isHairAccessoryInstance(original) and not existing[original.Name] then
            local clone = original:Clone(); clone.Parent = char; existing[original.Name] = true
        end
    end
    MytersWornState.accessoryIds = {}
    persistMytersSession()
    warn("[MytersWear] Accesorios restaurados:", #MytersOriginal.accessories)
    return true
end

local function restoreHair(char)
    if not char then return false end
    for _, acc in ipairs(char:GetChildren()) do
        if isMytersAccessory(acc) and (isHairAccessoryInstance(acc) or acc:GetAttribute("MytersHair") == true) then acc:Destroy() end
    end
    local existing = {}
    for _, acc in ipairs(char:GetChildren()) do
        if (acc:IsA("Accessory") or acc:IsA("Hat")) and not isMytersAccessory(acc) then existing[acc.Name] = true end
    end
    for _, original in ipairs(MytersOriginal.accessories) do
        if isHairAccessoryInstance(original) and not existing[original.Name] then original:Clone().Parent=char; existing[original.Name]=true end
    end
    MytersWornState.hairIds = {}
    persistMytersSession()
    return true
end

local function restoreHead(char)
    if not char then return false end
    if mytersDestroyBundleBodyOverlay then pcall(function() mytersDestroyBundleBodyOverlay(char, "Head", true) end) end
    for _, obj in ipairs(char:GetChildren()) do
        if isMytersAccessory(obj) and (obj:GetAttribute("MytersHead") == true or obj:GetAttribute("MytersWearId") == MytersWornState.headId) then obj:Destroy() end
    end
    local head=char:FindFirstChild("Head")
    if head then
        pcall(function() head.LocalTransparencyModifier=0; head.Transparency=0; head:SetAttribute("MytersHeadless",nil); head:SetAttribute("MytersHeadId",nil) end)
        for _,obj in ipairs(head:GetChildren()) do
            if obj:GetAttribute("MytersHeadless") then pcall(function() obj.Transparency=0; obj:SetAttribute("MytersHeadless",nil) end) end
        end
    end
    MytersWornState.headId = nil
    MytersWornState.bodyIds.Head = nil
    persistMytersSession()
    return true
end

local function restoreFace(char)
    if not char then return false end
    local head = char:FindFirstChild("Head")
    if not head then return false end
    for _, obj in ipairs(head:GetChildren()) do
        if obj:IsA("Decal") and obj:GetAttribute("MytersWear") then obj:Destroy() end
    end
    if MytersOriginal.faceTexture and MytersOriginal.faceTexture ~= "" then
        local face = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
        if not face then face=Instance.new("Decal"); face.Name="face"; face.Face=Enum.NormalId.Front; face.Parent=head end
        face.Texture=MytersOriginal.faceTexture; face:SetAttribute("MytersWear",nil)
    end
    MytersWornState.faceId=nil
    persistMytersSession()
    return true
end

local function restoreLegMeshes(char)
    if not char then return false end
    if mytersDestroyBundleBodyOverlay then
        pcall(function() mytersDestroyBundleBodyOverlay(char, "LeftLeg", true) end)
        pcall(function() mytersDestroyBundleBodyOverlay(char, "RightLeg", true) end)
    end
    mytersDestroyKorbloxVisual(char)
    for _,part in ipairs(char:GetChildren()) do
        local mytersMesh=part:FindFirstChild("MytersLegMesh")
        if mytersMesh then mytersMesh:Destroy() end
        pcall(function()
            part:SetAttribute("MytersKorbloxId",nil)
            part:SetAttribute("MytersKorbloxHidden",nil)
            part:SetAttribute("MytersKorbloxNative",nil); part:SetAttribute("MytersWearVisual",nil)
            part:SetAttribute("MytersKorbloxMeshId",nil)
        end)
    end
    mytersRestoreKorbloxHip(char, "Right")
    mytersRestoreKorbloxHip(char, "Left")
    for name, data in pairs(MytersOriginal.legs) do
        local part=char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            pcall(function()
                part.Transparency=data.baseTransparency or 0
                part.LocalTransparencyModifier=data.transparency or 0
            end)
            if part:IsA("MeshPart") and data.meshId then
                pcall(function() part.MeshId=data.meshId; part.TextureID=data.textureId or "" end)
            end
        end
    end
    MytersWornState.legIds={}
    mytersStopLegMaintenance()
    MytersWornState.legSides={}
    MytersWornState.bodyIds.LeftLeg=nil
    MytersWornState.bodyIds.RightLeg=nil
    persistMytersSession()
    return true
end

-- Restaurar TODO el outfit original de una vez
local function restoreAll(char)
    restoreShirt(char)
    restorePants(char)
    restoreTShirt(char)
    restoreAccessories(char)
    restoreHair(char)
    restoreHead(char)
    restoreFace(char)
    restoreLegMeshes(char)
    if mytersDestroyBundleBodyOverlay then
        for _, field in ipairs({"Torso", "RightArm", "LeftArm"}) do
            pcall(function() mytersDestroyBundleBodyOverlay(char, field, true) end)
        end
    end
    MytersWornState.bodyIds = {}
    MytersWornState.bodyDescription = nil
    persistMytersSession()
    warn("[MytersWear] Outfit completo restaurado")
    task.defer(function() if runMytersDiagnostics then runMytersDiagnostics(char,false) end end)
    return true
end

local function findMytersAccessory(char,id)
    if not char then return nil end
    for _,obj in ipairs(char:GetDescendants()) do
        if (obj:IsA("Accessory") or obj:IsA("Hat")) and tonumber(obj:GetAttribute("MytersWearId"))==tonumber(id) then return obj end
    end
    return nil
end

local function hasMytersId(char,id)
    return findMytersAccessory(char,id)~=nil
end

local function hasMytersLeg(char,id)
    for _,obj in ipairs(char:GetChildren()) do
        if tonumber(obj:GetAttribute("MytersKorbloxId"))==tonumber(id) then return true end
        local mesh=obj:FindFirstChild("MytersLegMesh")
        if mesh then return true end
    end
    return false
end

runMytersDiagnostics=function(char,repair)
    local issues={}
    local report=compilerStart()
    local function add(message,kind,code,context)
        table.insert(issues,message)
        compilerIssue(kind or "direct",code or "MYTERS_CHECK",message,context)
    end
    if not char then add("No hay personaje activo.") end
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local desc
    if hum then
        local descOk
        descOk,desc=pcall(function()
            if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
            return hum.HumanoidDescription
        end)
        if not descOk then desc=nil end
    end
    if char and not hum then add("Falta el Humanoid.") end
    if char and not char.Parent then add("El personaje no tiene Parent activo.","indirect","CHARACTER_DETACHED") end
    if char then
        for _,partName in ipairs({"HumanoidRootPart","Head"}) do
            if not char:FindFirstChild(partName) then add("Falta la parte obligatoria: "..partName,"direct","MISSING_BODY_PART",partName) end
        end
        if hum and hum.Health<=0 then add("El Humanoid está muerto o en proceso de reset.","indirect","HUMANOID_RESET") end
        if hum and not desc then add("No se pudo leer HumanoidDescription.","direct","DESCRIPTION_UNAVAILABLE") end
    end

    if char then
        for _,id in ipairs(MytersWornState.legIds or {}) do
            if not hasMytersLeg(char,id) then add("Pierna no aplicada: "..tostring(id)) end
        end
        for field,id in pairs(MytersWornState.bodyIds or {}) do
            if (field=="LeftLeg" or field=="RightLeg") and id and not hasMytersLeg(char,id) then
                add(field.." de Korblox no aplicada: "..tostring(id),"direct","KORBLOX_MISSING",id)
            end
        end
        for _,id in ipairs(MytersWornState.accessoryIds or {}) do
            if not hasMytersId(char,id) then
                local found=false
                if hum then
                    local ok,desc=pcall(function()
                        if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
                        return hum.HumanoidDescription
                    end)
                    if ok and desc then
                        for v in tostring(safeDescriptionField(desc,"HatAccessory") or ""):gmatch("%d+") do if tonumber(v)==id then found=true end end
                        for _,field in ipairs({"FaceAccessory","NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory"}) do
                            for v in tostring(safeDescriptionField(desc,field) or ""):gmatch("%d+") do if tonumber(v)==id then found=true end end
                        end
                    end
                end
                if not found then
                    add("Accesorio no aplicado: "..tostring(id),"direct","ACCESSORY_MISSING",id)
                else
                    add("Accesorio "..tostring(id).." quedó solo en HumanoidDescription; falta la instancia visible.","indirect","DESCRIPTION_ONLY_ACCESSORY",id)
                end
            end
        end
        local accessorySeen={}
        for _,obj in ipairs(char:GetDescendants()) do
            if (obj:IsA("Accessory") or obj:IsA("Hat")) and obj:GetAttribute("MytersWearId") then
                local objId=tonumber(obj:GetAttribute("MytersWearId")) or obj:GetAttribute("MytersWearId")
                if accessorySeen[objId] then add("Accesorio duplicado detectado: "..tostring(objId),"indirect","DUPLICATE_ACCESSORY",objId) end
                accessorySeen[objId]=true
                local handle=obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart",true)
                if not handle then add("Accesorio "..tostring(objId).." no tiene Handle/BasePart.","direct","ACCESSORY_NO_HANDLE",objId) end
                if handle and handle.Transparency>=1 and handle.LocalTransparencyModifier>=1 then add("Accesorio "..tostring(objId).." está completamente invisible.","indirect","ACCESSORY_INVISIBLE",objId) end
                if handle and not (handle:FindFirstChildOfClass("AccessoryWeld") or handle:FindFirstChildOfClass("RigidConstraint") or handle:FindFirstChildOfClass("WeldConstraint")) then
                    add("Accesorio "..tostring(objId).." no tiene unión al personaje.","indirect","ACCESSORY_NO_JOINT",objId)
                end
            end
        end
        if MytersWornState.headId then
            local head=char:FindFirstChild("Head")
            local present=head and (head:GetAttribute("MytersHeadless") or head:GetAttribute("MytersHeadId")==MytersWornState.headId or descriptionHasId(desc,"Head",MytersWornState.headId))
            if not present then add("Cabeza no aplicada: "..tostring(MytersWornState.headId),"direct","HEAD_MISSING",MytersWornState.headId) end
        end
        if MytersWornState.faceId then
            local faceFound=false
            local head=char:FindFirstChild("Head")
            if head then for _,obj in ipairs(head:GetChildren()) do if obj:IsA("Decal") and obj:GetAttribute("MytersFaceId")==MytersWornState.faceId then faceFound=true end end end
            local faceInDescription=descriptionHasId(desc,"Face",MytersWornState.faceId)
            if not faceFound and not faceInDescription then
                add("Cara no aplicada: "..tostring(MytersWornState.faceId),"direct","FACE_MISSING",MytersWornState.faceId)
            elseif faceInDescription and not faceFound then
                add("La cara "..tostring(MytersWornState.faceId).." figura en la descripción, pero no hay Decal visible.","indirect","FACE_DESCRIPTION_ONLY",MytersWornState.faceId)
            end
        end
        for field,id in pairs(MytersWornState.bodyIds or {}) do
            if field~="Head" and field~="LeftLeg" and field~="RightLeg" and not descriptionHasId(desc,field,id) then
                add(field.." no aplicada: "..tostring(id),"direct","BODY_SLOT_MISMATCH",field)
            end
        end
        local clothingChecks={{"Shirt","shirtId","MytersShirt","SHIRT_MISSING"},{"Pants","pantsId","MytersPants","PANTS_MISSING"},{"ShirtGraphic","tshirtId","MytersTShirt","TSHIRT_MISSING"}}
        for _,check in ipairs(clothingChecks) do
            local expected=MytersWornState[check[2]]
            if expected then
                local present=false
                for _,obj in ipairs(char:GetChildren()) do
                    if obj:IsA(check[1]) and obj:GetAttribute("MytersWear")==true then present=true; break end
                end
                if not present then add(check[1].." guardada en el estado pero no existe en el personaje.","direct",check[4],expected) end
            end
        end
        local listNames={{"accessoryIds","accesorios"},{"hairIds","pelo"},{"legIds","piernas"}}
        for _,entry in ipairs(listNames) do
            local seen={}
            for _,id in ipairs(MytersWornState[entry[1]] or {}) do
                local key=tostring(id)
                if seen[key] then add("ID duplicado en el estado de "..entry[2]..": "..key,"indirect","STATE_DUPLICATE",key) end
                seen[key]=true
            end
        end
    end

    local repaired=false
    if repair and char then
        for _,message in ipairs(issues) do
            if message:find("Pierna no aplicada",1,true) or message:find("Korblox no aplicada",1,true) then
                repaired=reapplyMytersLegs(char) or repaired
                break
            end
        end
        if char and hum then
            if MytersWornState.headId then
                local head=char:FindFirstChild("Head")
                local present=head and (head:GetAttribute("MytersHeadless") or head:GetAttribute("MytersHeadId")==MytersWornState.headId or descriptionHasId(desc,"Head",MytersWornState.headId))
                if not present then
                    if tonumber(MytersWornState.headId)==15093053680 then equipHeadlessVisual(MytersWornState.headId,char)
                    else
                        local info=apiProductInfo(MytersWornState.headId)
                        if info then pcall(equipSingle,MytersWornState.headId,tonumber(info.AssetTypeId),char) end
                    end
                    repaired=true
                end
            end
            if MytersWornState.faceId then
                local present=descriptionHasId(desc,"Face",MytersWornState.faceId)
                if not present then
                    local info=apiProductInfo(MytersWornState.faceId)
                    if info then pcall(equipSingle,MytersWornState.faceId,tonumber(info.AssetTypeId),char); repaired=true end
                end
            end
            for _,id in ipairs(MytersWornState.accessoryIds or {}) do
                if not hasMytersId(char,id) then
                    local info=apiProductInfo(id)
                    if info then
                        local callOk,applied=pcall(equipSingle,id,normalizeAssetType(id,info.AssetTypeId,info),char)
                        task.wait(.12)
                        local verified,why=false,"reparación no confirmada"
                        if callOk and applied and verifyMytersItem then verified,why=verifyMytersItem(id,normalizeAssetType(id,info.AssetTypeId,info),char) end
                        if verified then
                            repaired=true
                        else
                            add("No se pudo reparar el accesorio "..tostring(id)..": "..tostring(why),"indirect","AUTO_REPAIR_FAILED",id)
                        end
                    end
                end
            end
            for field,id in pairs(MytersWornState.bodyIds or {}) do
                local isHead = field == "Head"
                local alreadyDirect = mytersBodySlotApplied and mytersBodySlotApplied(char, field, id)
                if not isHead and not alreadyDirect and not descriptionHasId(desc,field,id) then
                    local callOk, current = pcall(function()
                        if not mytersEquipBodyAsset then return false end
                        return mytersEquipBodyAsset(field,id,char)
                    end)
                    repaired=(callOk and current == true) or repaired
                end
            end
        end
    end
    MytersDiagnostic.checks=(MytersDiagnostic.checks or 0)+1
    MytersDiagnostic.lastOk=(#issues==0)
    report.finishedAt=os.time()
    report.lastOk=MytersDiagnostic.lastOk
    report.issueCount=#issues
    report.directCount=report.directErrors or 0
    report.indirectCount=report.indirectErrors or 0
    report.lastSummary=(#issues==0 and "sin errores" or (tostring(#issues).." error(es) detectado(s)"))
    MytersDiagnostic.compiler=report
    MytersDiagnostic.lastIssues=issues
    MytersDiagnostic.checkedAt=os.time()
    mytersEnv.MytersWearDiagnostic=MytersDiagnostic
    if MytersDiagnostic.onUpdate then pcall(MytersDiagnostic.onUpdate,MytersDiagnostic.lastOk,issues,repaired) end
    return MytersDiagnostic.lastOk,issues,repaired
end

descriptionHasId=function(desc,field,id)
    if not desc or not field then return false end
    local wanted=tostring(id)
    for value in tostring(safeDescriptionField(desc,field) or ""):gmatch("%d+") do
        if value==wanted then return true end
    end
    return false
end

verifyMytersItem=function(id,typeId,char)
    if not char then return false,"personaje ausente" end
    local wanted=tonumber(id) or id
    local hum=char:FindFirstChildOfClass("Humanoid")
    local ok,desc=pcall(function()
        if hum and hum.GetAppliedDescription then return hum:GetAppliedDescription() end
        return hum and hum.HumanoidDescription
    end)
    if not ok then desc=nil end

    if typeId==31 or typeId==32 then
        for _,part in ipairs(char:GetChildren()) do
            if part:GetAttribute("MytersKorbloxId")==wanted then return true,"pierna verificada" end
            if part:FindFirstChild("MytersLegMesh") then return true,"malla de pierna verificada" end
        end
        local field=typeId==32 and "RightLeg" or "LeftLeg"
        if descriptionHasId(desc,field,wanted) then return true,"pierna verificada por descripción" end
        return false,"la malla de la pierna no apareció"
    end

    if typeId==17 or typeId==79 then
        local head=char:FindFirstChild("Head")
        if wanted==15093053680 and head and (head:GetAttribute("MytersHeadless") or head.LocalTransparencyModifier>=.99) then
            return true,"Headless verificado"
        end
        if head and head:GetAttribute("MytersHeadId")==wanted then return true,"cabeza verificada" end
        if descriptionHasId(desc,"Head",wanted) then return true,"cabeza verificada por descripción" end
        return false,"la cabeza no se aplicó"
    end

    if typeId==18 then
        local head=char:FindFirstChild("Head")
        if head then
            for _,obj in ipairs(head:GetChildren()) do
                if obj:IsA("Decal") and (obj:GetAttribute("MytersFaceId")==wanted or tostring(obj.Texture):find(tostring(wanted),1,true)) then return true,"cara verificada" end
            end
        end
        if descriptionHasId(desc,"Face",wanted) then return true,"cara verificada por descripción" end
        return false,"la cara no se aplicó"
    end

    local bodyField=BODY_TYPE_FIELDS[typeId]
    if bodyField then
        if descriptionHasId(desc,bodyField,wanted) then return true,bodyField.." verificado" end
        return false,"la parte corporal no se aplicó"
    end

    local clothingFields={[11]="Shirt",[12]="Pants",[2]="GraphicTShirt"}
    local clothingField=clothingFields[typeId]
    if clothingField then
        for _,obj in ipairs(char:GetChildren()) do
            local rightClass=(typeId==11 and obj:IsA("Shirt")) or (typeId==12 and obj:IsA("Pants")) or (typeId==2 and obj:IsA("ShirtGraphic"))
            local stateMatch=(typeId==11 and MytersWornState.shirtId) or (typeId==12 and MytersWornState.pantsId) or (typeId==2 and MytersWornState.tshirtId)
            if rightClass and (tonumber(obj:GetAttribute("MytersWearId"))==tonumber(wanted) or (obj:GetAttribute("MytersWear")==true and tonumber(stateMatch)==tonumber(wanted))) then return true,"ropa verificada por ID interno" end
        end
    end
    if clothingField and descriptionHasId(desc,clothingField,wanted) then return true,"ropa verificada" end
    if clothingField then
        for _,obj in ipairs(char:GetChildren()) do
            local value=(typeId==11 and obj:IsA("Shirt") and obj.ShirtTemplate)
                or (typeId==12 and obj:IsA("Pants") and obj.PantsTemplate)
                or (typeId==2 and obj:IsA("ShirtGraphic") and obj.Graphic)
            if value and tostring(value):find(tostring(wanted),1,true) then return true,"ropa verificada" end
        end
        return false,"la ropa no se aplicó"
    end

    local accessory=findMytersAccessory(char,wanted)
    if accessory then
        local handle=accessory:FindFirstChild("Handle") or accessory:FindFirstChildWhichIsA("BasePart",true)
        local visible=false
        local joint=false
        if handle then
            for _,part in ipairs(accessory:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency<1 and part.LocalTransparencyModifier<1 then visible=true end
            end
            joint=handle:FindFirstChildOfClass("AccessoryWeld")~=nil
                or handle:FindFirstChildOfClass("RigidConstraint")~=nil
                or handle:FindFirstChildOfClass("WeldConstraint")~=nil
        end
        if handle and visible and joint then return true,"accesorio visible y unido" end
        return false,"Accessory encontrado, pero Handle no está visible o unido"
    end
    if desc then
        for _,field in ipairs({"HatAccessory","HairAccessory","FaceAccessory","NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory","TShirtAccessory","ShirtAccessory","PantsAccessory","JacketAccessory","SweaterAccessory","ShortsAccessory","LeftShoeAccessory","RightShoeAccessory","DressSkirtAccessory"}) do
            if descriptionHasId(desc,field,wanted) then
                return false,"el ID está en HumanoidDescription, pero no existe un Accessory visible"
            end
        end
    end
    return false,"Roblox no confirmó un Accessory visible con Handle"
end

normalizeAssetType=function(id,typeId,info)
    local t=tonumber(typeId) or 0
    if t==31 or t==32 then
        local name=tostring(info and info.Name or ""):lower()
        if tonumber(id)==139607718 or name:find("right",1,true) or name:find("derech",1,true) then return 32 end
        if name:find("left",1,true) or name:find("izquier",1,true) then return 31 end
    end
    return t
end

-- Los bundles de cuerpo tienen tipos de asset distintos a los accesorios.
-- En la ruta de bundle usamos nombres/IDs actuales de AvatarAssetType y no
-- pasamos RightLeg/LeftLeg por el fallback legacy de Korblox (31/32).
local function mytersBundleAssetType(item, info)
    local raw = item and (item.assetType or item.AssetType or item.assetTypeId or item.assetTypeID)
    local at = tonumber(raw) or 0
    local typeName = ""
    if type(raw) == "table" then
        at = tonumber(raw.id or raw.Id or raw.assetTypeId or raw.AssetTypeId or raw.typeId) or at
        typeName = tostring(raw.name or raw.Name or raw.value or raw.Value or "")
    elseif type(raw) == "string" then
        typeName = raw
    end
    if typeName == "" then
        typeName = tostring(item and (item.assetTypeName or item.AssetTypeName or item.assetTypeNameString) or "")
    end
    if at <= 0 then at = tonumber(info and info.AssetTypeId) or 0 end
    if typeName == "" then typeName = tostring(info and info.AssetTypeName or "") end

    -- Catalog responses vary: some carry the type as a number, others as a name.
    if at <= 0 and typeName ~= "" then
        local key = typeName:lower():gsub("[^%w]", "")
        local byName = {
            tshirt=2, graphictshirt=2, hat=8, shirt=11, pants=12,
            head=17, face=18, torso=27, rightarm=28, leftarm=29,
            leftleg=30, rightleg=31, hairaccessory=41, faceaccessory=42,
            neckaccessory=43, shoulderaccessory=44, frontaccessory=45,
            backaccessory=46, waistaccessory=47, dynamichead=79,
        }
        at = byName[key] or 0
    end
    return at, typeName
end

local function mytersBundleBodyField(at, typeName, itemName)
    local typeKey = tostring(typeName or ""):lower():gsub("[^%w]", "")
    local byTypeName = {
        head="Head", dynamichead="Head", face="Face",
        torso="Torso", rightarm="RightArm", leftarm="LeftArm",
        leftleg="LeftLeg", rightleg="RightLeg",
    }
    if byTypeName[typeKey] then return byTypeName[typeKey] end

    -- AssetType IDs del cuerpo de Roblox. En los bundles, RightLeg (31)
    -- es una ranura corporal, NO una malla legacy de Korblox.
    local byId = {
        [17]="Head", [18]="Face", [27]="Torso", [28]="RightArm",
        [29]="LeftArm", [30]="LeftLeg", [31]="RightLeg", [79]="Head",
    }
    if byId[tonumber(at)] then return byId[tonumber(at)] end

    -- Algunos endpoints solo dan el nombre completo de cada pieza.
    local itemKey = tostring(itemName or ""):lower():gsub("[^%w]", "")
    local byName = {
        {"rightarm", "RightArm"}, {"leftarm", "LeftArm"},
        {"rightleg", "RightLeg"}, {"leftleg", "LeftLeg"},
        {"torso", "Torso"}, {"dynamichead", "Head"},
    }
    for _, entry in ipairs(byName) do
        if itemKey:find(entry[1], 1, true) then return entry[2] end
    end
    if itemKey:match("head$") or itemKey:find("bodyhead", 1, true) then return "Head" end
    if itemKey:match("face$") or itemKey:find("bodyface", 1, true) then return "Face" end
    return nil
end

-- Equipar todas las piezas corporales de un bundle en UNA sola aplicación.
-- Aplicar cada brazo/pierna por separado provoca que el juego reconstruya el rig
-- entre llamadas y deje parte de la skin sin aplicar.
local function mytersBundleOutfitDescription(bundleData)
    -- Roblox publica UserOutfit dentro del detalle del bundle. Su descripción
    -- incluye los slots corporales, colores y escalas oficiales del bundle.
    for _, item in ipairs((bundleData and bundleData.items) or {}) do
        local itemType = tostring(item.type or item.itemType or item.Type or item.ItemType or ""):lower()
        if itemType == "useroutfit" then
            local outfitId = tonumber(exactCatalogId(item.id or item.Id))
            if outfitId and outfitId > 0 then
                local ok, desc = pcall(function()
                    return Players:GetHumanoidDescriptionFromOutfitIdAsync(outfitId)
                end)
                if ok and typeof(desc) == "Instance" and desc:IsA("HumanoidDescription") then
                    return desc
                end
                warn("[MytersWear] no se pudo leer la descripción UserOutfit del bundle:", outfitId, tostring(desc))
            end
        end
    end
    return nil
end

-- Si el endpoint de Outfit no devuelve una descripción, reconstruirla desde
-- los seis Asset IDs que ya entrega el detalle oficial del bundle. Esto evita
-- caer al cargador individual de modelos, que no admite todos los UGC bodyparts.
local function mytersBundleDescriptionFromAssets(bundleDesc, bodyItems, char)
    local desc = bundleDesc
    if typeof(desc) ~= "Instance" or not desc:IsA("HumanoidDescription") then
        desc = nil
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local ok, currentDesc = pcall(function()
            return hum and hum:GetAppliedDescription()
        end)
        if ok and typeof(currentDesc) == "Instance" and currentDesc:IsA("HumanoidDescription") then
            desc = currentDesc
        else
            desc = Instance.new("HumanoidDescription")
        end
    end

    local fields = {"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
    for _, field in ipairs(fields) do
        local entry = bodyItems and bodyItems[field]
        local id = entry and tonumber(entry.id or entry.idText)
        if not id or id <= 0 then
            if desc ~= bundleDesc then pcall(function() desc:Destroy() end) end
            return nil, "falta el ID oficial de " .. field .. " en el bundle"
        end
        local ok, err = pcall(function() desc[field] = id end)
        if not ok then
            if desc ~= bundleDesc then pcall(function() desc:Destroy() end) end
            return nil, "Roblox rechazó " .. field .. " (" .. tostring(err) .. ")"
        end
        local readOk, assigned = pcall(function() return desc[field] end)
        if not readOk or tonumber(assigned) ~= id then
            if desc ~= bundleDesc then pcall(function() desc:Destroy() end) end
            return nil, "Roblox no confirmó el ID de " .. field
        end
    end
    return desc
end

local MYTERS_R15_BODY_PARTS = {
    Torso = {"UpperTorso", "LowerTorso"},
    RightArm = {"RightUpperArm", "RightLowerArm", "RightHand"},
    LeftArm = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},
    RightLeg = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
    LeftLeg = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
    Head = {"Head"},
}

-- Anclar primero el LowerTorso al root real del personaje; después reconstruir
-- el resto del esqueleto con las uniones originales del bundle.
local MYTERS_R15_BODY_JOINTS = {
    {parent = "HumanoidRootPart", parentAttachment = "RootRigAttachment", child = "LowerTorso", childAttachment = "RootRigAttachment"},
    {parent = "LowerTorso", parentAttachment = "WaistRigAttachment", child = "UpperTorso", childAttachment = "WaistRigAttachment"},
    {parent = "UpperTorso", parentAttachment = "NeckRigAttachment", child = "Head", childAttachment = "NeckRigAttachment"},
    {parent = "UpperTorso", parentAttachment = "LeftShoulderRigAttachment", child = "LeftUpperArm", childAttachment = "LeftShoulderRigAttachment"},
    {parent = "LeftUpperArm", parentAttachment = "LeftElbowRigAttachment", child = "LeftLowerArm", childAttachment = "LeftElbowRigAttachment"},
    {parent = "LeftLowerArm", parentAttachment = "LeftWristRigAttachment", child = "LeftHand", childAttachment = "LeftWristRigAttachment"},
    {parent = "UpperTorso", parentAttachment = "RightShoulderRigAttachment", child = "RightUpperArm", childAttachment = "RightShoulderRigAttachment"},
    {parent = "RightUpperArm", parentAttachment = "RightElbowRigAttachment", child = "RightLowerArm", childAttachment = "RightElbowRigAttachment"},
    {parent = "RightLowerArm", parentAttachment = "RightWristRigAttachment", child = "RightHand", childAttachment = "RightWristRigAttachment"},
    {parent = "LowerTorso", parentAttachment = "LeftHipRigAttachment", child = "LeftUpperLeg", childAttachment = "LeftHipRigAttachment"},
    {parent = "LeftUpperLeg", parentAttachment = "LeftKneeRigAttachment", child = "LeftLowerLeg", childAttachment = "LeftKneeRigAttachment"},
    {parent = "LeftLowerLeg", parentAttachment = "LeftAnkleRigAttachment", child = "LeftFoot", childAttachment = "LeftAnkleRigAttachment"},
    {parent = "LowerTorso", parentAttachment = "RightHipRigAttachment", child = "RightUpperLeg", childAttachment = "RightHipRigAttachment"},
    {parent = "RightUpperLeg", parentAttachment = "RightKneeRigAttachment", child = "RightLowerLeg", childAttachment = "RightKneeRigAttachment"},
    {parent = "RightLowerLeg", parentAttachment = "RightAnkleRigAttachment", child = "RightFoot", childAttachment = "RightAnkleRigAttachment"},
}

local function mytersSameBodyAssetId(a, b)
    if a == nil or b == nil then return false end
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then return na == nb end
    return tostring(a) == tostring(b)
end

local function mytersBundleOverlayExists(char, field, id, partName)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart")
            and obj:GetAttribute("MytersWearBodyVisual") == true
            and obj:GetAttribute("MytersWearBodyField") == field
            and obj:GetAttribute("MytersWearBodyPart") == partName
            and mytersSameBodyAssetId(obj:GetAttribute("MytersWearBodyId"), id) then
            return true
        end
    end
    return false
end

mytersBodySlotApplied = function(char, field, id)
    if not char or not field or id == nil then return false end
    if field == "Head" and tonumber(id) == 15093053680 then
        local head = char:FindFirstChild("Head")
        return head and head:GetAttribute("MytersHeadless") == true
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    for _, obj in ipairs(char:GetChildren()) do
        if obj:GetAttribute("MytersWearBodyVisual") == true
            and (not root or not root:IsA("BasePart") or not obj:IsA("BasePart")
                or (obj.Position - root.Position).Magnitude > 12) then
            return false
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local descOk, appliedDesc = pcall(function() return hum:GetAppliedDescription() end)
        if descOk and typeof(appliedDesc) == "Instance" and appliedDesc:IsA("HumanoidDescription") then
            local fieldOk, appliedId = pcall(function() return appliedDesc[field] end)
            pcall(function() appliedDesc:Destroy() end)
            if fieldOk and mytersSameBodyAssetId(appliedId, id) then return true end
        end
    end
    if field == "Face" then
        local head = char:FindFirstChild("Head")
        if not head then return false end
        for _, obj in ipairs(head:GetChildren()) do
            if obj:GetAttribute("MytersFaceId") and mytersSameBodyAssetId(obj:GetAttribute("MytersFaceId"), id) then return true end
        end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and obj:GetAttribute("MytersWearBodyPart") == "Head"
                and mytersSameBodyAssetId(obj:GetAttribute("MytersWearFaceId"), id) then return true end
        end
        return false
    end
    local names = MYTERS_R15_BODY_PARTS[field]
    if not names then return false end
    for _, partName in ipairs(names) do
        local part = char:FindFirstChild(partName)
        if not part or part:GetAttribute("MytersWearBodyField") ~= field
            or not mytersSameBodyAssetId(part:GetAttribute("MytersWearBodyId"), id)
            or not mytersBundleOverlayExists(char, field, id, partName) then
            return false
        end
        if part.LocalTransparencyModifier ~= 1 then
            pcall(function() part.LocalTransparencyModifier = 1 end)
        end
    end
    return true
end

mytersDestroyBundleBodyOverlay = function(char, field, restoreTarget)
    if not char then return false end
    if field == "Face" then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and obj:GetAttribute("MytersWearBodyPart") == "Head" then
                pcall(function() obj:SetAttribute("MytersWearFaceId", nil) end)
            elseif (obj:IsA("Decal") or obj:IsA("Texture")) and obj:GetAttribute("MytersFaceId") then
                pcall(function() obj:Destroy() end)
            end
        end
        return true
    end

    local bundleRig = char:FindFirstChild("MytersBundleBodyRig")
    if bundleRig and bundleRig:IsA("Model") and bundleRig:GetAttribute("MytersWearBodyRig") == true then
        if field then
            for _, obj in ipairs(bundleRig:GetDescendants()) do
                if obj:IsA("BasePart") and obj:GetAttribute("MytersWearBodyVisual") == true
                    and obj:GetAttribute("MytersWearBodyField") == field then
                    pcall(function()
                        obj.LocalTransparencyModifier = 1
                        obj:SetAttribute("MytersWearBodyVisual", nil)
                        obj:SetAttribute("MytersWearBodyField", nil)
                        obj:SetAttribute("MytersWearBodyId", nil)
                        obj:SetAttribute("MytersWearBodyPart", nil)
                        obj:SetAttribute("MytersWearFaceId", nil)
                    end)
                end
            end
        else
            pcall(function() bundleRig:Destroy() end)
        end
        local anyVisibleBody = false
        if bundleRig.Parent then
            for _, obj in ipairs(bundleRig:GetDescendants()) do
                if obj:IsA("BasePart") and obj:GetAttribute("MytersWearBodyVisual") == true then
                    anyVisibleBody = true
                    break
                end
            end
        end
        if not anyVisibleBody and bundleRig.Parent then pcall(function() bundleRig:Destroy() end) end
        if not anyVisibleBody and MytersWornState.bundleRigSync then
            pcall(function() MytersWornState.bundleRigSync:Disconnect() end)
            MytersWornState.bundleRigSync = nil
            MytersWornState.bundleRigModel = nil
        end
    end

    for _, obj in ipairs(char:GetChildren()) do
        if obj:GetAttribute("MytersWearBodyVisual") == true
            and (not field or obj:GetAttribute("MytersWearBodyField") == field) then
            pcall(function() obj:Destroy() end)
        end
    end
    local anyBodyVisual = false
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj:GetAttribute("MytersWearBodyVisual") == true then
            anyBodyVisual = true
            break
        end
    end
    if not anyBodyVisual and MytersWornState.bundleRigSync then
        pcall(function() MytersWornState.bundleRigSync:Disconnect() end)
        MytersWornState.bundleRigSync = nil
        MytersWornState.bundleRigModel = nil
    end
    local fields = field and {field} or {"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}
    for _, bodyField in ipairs(fields) do
        for _, partName in ipairs(MYTERS_R15_BODY_PARTS[bodyField] or {}) do
            local part = char:FindFirstChild(partName)
            if part and part:GetAttribute("MytersWearBodyHiddenByMyters") == true then
                if restoreTarget ~= false then
                    local previous = part:GetAttribute("MytersWearBodyOriginalLTM")
                    pcall(function() part.LocalTransparencyModifier = tonumber(previous) or 0 end)
                end
                pcall(function()
                    part:SetAttribute("MytersWearBodyHiddenByMyters", nil)
                    part:SetAttribute("MytersWearBodyOriginalLTM", nil)
                    part:SetAttribute("MytersWearBodyField", nil)
                    part:SetAttribute("MytersWearBodyId", nil)
                    if bodyField == "Head" then part:SetAttribute("MytersHeadId", nil) end
                end)
            end
        end
    end
    return true
end

local function mytersDestroyBundleRoots(roots)
    for _, root in ipairs(roots or {}) do pcall(function() root:Destroy() end) end
end

local function mytersMakeBundleHead(id, char, roots)
    local sourcePart, sourceMesh
    for _, root in ipairs(roots) do
        if root:IsA("BasePart") and (root.Name == "Head" or not sourcePart) then sourcePart = root end
        if root:IsA("SpecialMesh") and not sourceMesh then sourceMesh = root end
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "Head" or not sourcePart) then sourcePart = obj end
            if obj:IsA("SpecialMesh") and not sourceMesh then sourceMesh = obj end
        end
    end
    if sourcePart then
        local ok, clone = pcall(function() return sourcePart:Clone() end)
        if ok and clone then clone.Name = "Head"; return clone end
    end
    if not sourceMesh or tostring(sourceMesh.MeshId or "") == "" then
        return nil, "el asset no contiene Head ni SpecialMesh"
    end
    local oldHead = char:FindFirstChild("Head")
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = oldHead and oldHead.Size or Vector3.new(2, 1, 1)
    head.CFrame = oldHead and oldHead.CFrame or CFrame.new()
    head.Color = oldHead and oldHead.Color or Color3.new(1, 1, 1)
    head.Material = oldHead and oldHead.Material or Enum.Material.Plastic
    head.Transparency = 0
    head.Anchored = false
    head.CanCollide = false
    head.CanTouch = false
    head.CanQuery = false
    head.Massless = true
    local mesh = sourceMesh:Clone()
    mesh.Name = "MytersBundleHeadMesh"
    mesh.Parent = head
    for _, root in ipairs(roots) do
        local candidates = {root}
        for _, obj in ipairs(root:GetDescendants()) do table.insert(candidates, obj) end
        for _, obj in ipairs(candidates) do
            if obj:IsA("Vector3Value") and obj.Name:find("Attachment", 1, true) then
                local attachment = Instance.new("Attachment")
                attachment.Name = obj.Name
                attachment.Position = obj.Value
                attachment.Parent = head
            end
        end
    end
    return head
end

mytersApplyBundleBodyVisuals = function(char, bundleDesc)
    if typeof(bundleDesc) ~= "Instance" or not bundleDesc:IsA("HumanoidDescription") then return end
    local colorMap = {
        Head = "HeadColor", Torso = "TorsoColor",
        RightArm = "RightArmColor", LeftArm = "LeftArmColor",
        RightLeg = "RightLegColor", LeftLeg = "LeftLegColor",
    }
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj:GetAttribute("MytersWearBodyVisual") == true then
            local colorField = colorMap[obj:GetAttribute("MytersWearBodyField")]
            if colorField then
                pcall(function()
                    local color = bundleDesc[colorField]
                    if typeof(color) == "Color3" then obj.Color = color end
                end)
            end
        end
    end
end

local MYTERS_BUNDLE_BODY_DESCRIPTION_FIELDS = {
    "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face",
    "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
    "BodyTypeScale", "ProportionScale", "HeightScale", "WidthScale", "DepthScale", "HeadScale",
}

mytersSerializeBundleBodyDescription = function(bundleDesc)
    if typeof(bundleDesc) ~= "Instance" or not bundleDesc:IsA("HumanoidDescription") then return nil end
    local data = {}
    for _, field in ipairs(MYTERS_BUNDLE_BODY_DESCRIPTION_FIELDS) do
        pcall(function() data[field] = bundleDesc[field] end)
    end
    return data
end

local function mytersCreateBundleBodyDescription(data)
    if type(data) ~= "table" then return nil end
    local desc = Instance.new("HumanoidDescription")
    for field, value in pairs(data) do
        pcall(function() desc[field] = value end)
    end
    return desc
end

-- La API de descripción requiere autoridad de servidor. Para el overlay local,
-- reconstruir el cuerpo padre -> hijo con sus RigAttachments y copiar solo los
-- giros articulares del rig activo; así se conservan juntas y proporciones.
local function mytersEquipBundleBodyVisualsLocally(char, bundleDesc, slots, order)
    local errors, succeeded = {}, {}
    local totalRequested = #(order or {})
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        for _, field in ipairs(order or {}) do errors[field] = "no se encontró Humanoid" end
        return 0, totalRequested, errors, succeeded
    end
    if hum.RigType ~= Enum.HumanoidRigType.R15 then
        for _, field in ipairs(order or {}) do errors[field] = "el bundle requiere un rig R15" end
        return 0, totalRequested, errors, succeeded
    end
    if typeof(bundleDesc) ~= "Instance" or not bundleDesc:IsA("HumanoidDescription") then
        for _, field in ipairs(order or {}) do errors[field] = "no hay HumanoidDescription del bundle" end
        return 0, totalRequested, errors, succeeded
    end

    local createOk, sourceRig = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(bundleDesc, Enum.HumanoidRigType.R15)
    end)
    if not createOk or not sourceRig or not sourceRig:IsA("Model") then
        local message = "Roblox no pudo generar los segmentos del bundle: " .. tostring(sourceRig)
        for _, field in ipairs(order or {}) do errors[field] = message end
        return 0, totalRequested, errors, succeeded
    end
    local sourceRoot = sourceRig:FindFirstChild("HumanoidRootPart")
    local targetRoot = char:FindFirstChild("HumanoidRootPart")
    if not sourceRoot or not sourceRoot:IsA("BasePart") or not targetRoot or not targetRoot:IsA("BasePart") then
        sourceRig:Destroy()
        for _, field in ipairs(order or {}) do errors[field] = "no se encontró HumanoidRootPart para unir el cuerpo" end
        return 0, totalRequested, errors, succeeded
    end

    local partsToCopy, requestedFields = {}, {}
    for _, field in ipairs(order or {}) do
        if field ~= "Face" then requestedFields[field] = true end
    end
    for field in pairs(requestedFields) do
        for _, partName in ipairs(MYTERS_R15_BODY_PARTS[field] or {}) do
            local sourcePart = sourceRig:FindFirstChild(partName)
            local targetPart = char:FindFirstChild(partName)
            if not sourcePart or not sourcePart:IsA("BasePart") then
                errors[field] = "el rig generado no contiene " .. partName
                break
            elseif not targetPart or not targetPart:IsA("BasePart") then
                errors[field] = "no se encontró la parte R15 " .. partName
                break
            end
            table.insert(partsToCopy, {
                field = field, name = partName, source = sourcePart, target = targetPart,
            })
        end
    end
    if next(errors) then
        sourceRig:Destroy()
        for _, field in ipairs(order or {}) do errors[field] = errors[field] or "no se pudo preparar el cuerpo completo" end
        return 0, totalRequested, errors, succeeded
    end

    local visuals, visualsByName, failedField = {}, {}, nil
    for _, entry in ipairs(partsToCopy) do
        local cloneOk, visual = pcall(function() return entry.source:Clone() end)
        if not cloneOk or not visual or not visual:IsA("BasePart") then
            failedField = entry.field
            errors[entry.field] = "no se pudo clonar " .. entry.name .. ": " .. tostring(visual)
            break
        end
        for _, child in ipairs(visual:GetDescendants()) do
            if child:IsA("JointInstance") or child:IsA("Constraint") or child:IsA("Script")
                or child:IsA("LocalScript") or child:IsA("Humanoid") or child:IsA("AnimationController") then
                pcall(function() child:Destroy() end)
            end
        end
        local setupOk, setupError = pcall(function()
            visual.Name = "MytersBundleBodyVisual_" .. entry.name
            visual:SetAttribute("MytersWearBodyVisual", true)
            visual:SetAttribute("MytersWearBodyField", entry.field)
            visual:SetAttribute("MytersWearBodyId", tonumber(slots[entry.field].id) or slots[entry.field].id)
            visual:SetAttribute("MytersWearBodyPart", entry.name)
            if entry.name == "Head" and slots.Face then
                visual:SetAttribute("MytersWearFaceId", tonumber(slots.Face.id) or slots.Face.id)
            end
            visual.Anchored = true
            visual.CanCollide = false
            visual.CanTouch = false
            visual.CanQuery = false
            visual.Massless = true
            visual.Transparency = 0
            visual.LocalTransparencyModifier = 0
            -- La pose inicial sale del segmento real para que un pivot extraño
            -- del rig temporal no deje el bundle a decenas de studs.
            visual.CFrame = entry.target.CFrame
        end)
        if not setupOk then
            pcall(function() visual:Destroy() end)
            failedField = entry.field
            errors[entry.field] = "no se pudo preparar " .. entry.name .. ": " .. tostring(setupError)
            break
        end
        table.insert(visuals, {
            field = entry.field, name = entry.name, visual = visual, target = entry.target,
        })
        visualsByName[entry.name] = visuals[#visuals]
    end
    sourceRig:Destroy()
    if failedField then
        for _, entry in ipairs(visuals) do pcall(function() entry.visual:Destroy() end) end
        for _, field in ipairs(order or {}) do errors[field] = errors[field] or "no se pudo preparar el cuerpo completo" end
        return 0, totalRequested, errors, succeeded
    end

    captureOriginalOutfit(char)
    mytersDestroyBundleBodyOverlay(char, nil, true)
    if MytersWornState.bundleRigSync then
        pcall(function() MytersWornState.bundleRigSync:Disconnect() end)
        MytersWornState.bundleRigSync = nil
    end
    MytersWornState.bundleRigModel = nil

    local function hideTarget(field, id, target)
        if target:GetAttribute("MytersWearBodyHiddenByMyters") ~= true then
            target:SetAttribute("MytersWearBodyOriginalLTM", target.LocalTransparencyModifier)
        end
        target:SetAttribute("MytersWearBodyHiddenByMyters", true)
        target:SetAttribute("MytersWearBodyField", field)
        target:SetAttribute("MytersWearBodyId", tonumber(id) or id)
        if field == "Head" then target:SetAttribute("MytersHeadId", tonumber(id) or id) end
        target.LocalTransparencyModifier = 1
    end
    local function showTarget(target)
        if not target or target:GetAttribute("MytersWearBodyHiddenByMyters") ~= true then return end
        local previous = target:GetAttribute("MytersWearBodyOriginalLTM")
        target.LocalTransparencyModifier = tonumber(previous) or 0
        target:SetAttribute("MytersWearBodyHiddenByMyters", nil)
        target:SetAttribute("MytersWearBodyOriginalLTM", nil)
        target:SetAttribute("MytersWearBodyField", nil)
        target:SetAttribute("MytersWearBodyId", nil)
        if target.Name == "Head" then target:SetAttribute("MytersHeadId", nil) end
    end
    local visualsByField = {}
    for _, entry in ipairs(visuals) do
        entry.visual.Parent = char
        visualsByField[entry.field] = (visualsByField[entry.field] or 0) + 1
    end
    for field in pairs(requestedFields) do
        local expected = #(MYTERS_R15_BODY_PARTS[field] or {})
        if expected > 0 and visualsByField[field] == expected then
            succeeded[field] = true
            MytersWornState.bodyIds[field] = tonumber(slots[field].id) or slots[field].id
            if field == "Head" then MytersWornState.headId = tonumber(slots[field].id) or slots[field].id end
        end
    end

    -- Ocultar el cuerpo original solo después de comprobar que cada copia ya
    -- está junto a su segmento real. Así no aparece el avatar base debajo del bundle.
    local initialRoot = char:FindFirstChild("HumanoidRootPart")
    local initialPoseNear = initialRoot and initialRoot:IsA("BasePart")
    if initialPoseNear then
        for _, entry in ipairs(visuals) do
            if entry.visual.Parent ~= char or (entry.visual.Position - initialRoot.Position).Magnitude > 12 then
                initialPoseNear = false
                break
            end
        end
    end
    if initialPoseNear then
        for _, entry in ipairs(visuals) do
            local target = char:FindFirstChild(entry.name)
            if target and target:IsA("BasePart") then
                entry.target = target
                hideTarget(entry.field, slots[entry.field].id, target)
            end
        end
    end

    if slots.Face and table.find(order, "Face") then
        local faceOk, faceError = pcall(function() return equipFaceDirect(slots.Face.id, char) end)
        if faceOk and faceError == true then
            succeeded.Face = true
            MytersWornState.faceId = tonumber(slots.Face.id) or slots.Face.id
        else
            errors.Face = "no se pudo aplicar Face: " .. tostring(faceError)
        end
    end
    local bundleFaceId
    pcall(function() bundleFaceId = tonumber(bundleDesc.Face) end)
    if not succeeded.Face then MytersWornState.faceId = bundleFaceId and bundleFaceId > 0 and bundleFaceId or nil end

    local runService = game:GetService("RunService")
    local syncConnection
    local function syncVisualJoint(joint)
        local entry = visualsByName[joint.child]
        if not entry or entry.visual.Parent ~= char then return end

        local parentTarget = char:FindFirstChild(joint.parent)
        local childTarget = char:FindFirstChild(joint.child)
        local parentTargetAttachment = parentTarget and parentTarget:FindFirstChild(joint.parentAttachment)
        local childTargetAttachment = childTarget and childTarget:FindFirstChild(joint.childAttachment)
        local childSourceAttachment = entry.visual:FindFirstChild(joint.childAttachment)
        if not parentTarget or not parentTarget:IsA("BasePart") or not childTarget or not childTarget:IsA("BasePart")
            or not parentTargetAttachment or not parentTargetAttachment:IsA("Attachment")
            or not childTargetAttachment or not childTargetAttachment:IsA("Attachment")
            or not childSourceAttachment or not childSourceAttachment:IsA("Attachment") then
            return
        end

        local parentJointWorld = parentTarget.CFrame * parentTargetAttachment.CFrame
        local childJointWorld = childTarget.CFrame * childTargetAttachment.CFrame
        local currentJointRelative = parentJointWorld:ToObjectSpace(childJointWorld).Rotation
        if entry.targetJointParent ~= parentTarget or entry.targetJointChild ~= childTarget or not entry.targetJointBase then
            entry.targetJointParent = parentTarget
            entry.targetJointChild = childTarget
            entry.targetJointBase = currentJointRelative
        end
        local targetJointDelta = entry.targetJointBase:ToObjectSpace(currentJointRelative)

        local parentVisualEntry = visualsByName[joint.parent]
        local parentVisual = parentVisualEntry and parentVisualEntry.visual
        local parentVisualAttachment = parentVisual and parentVisual.Parent == char
            and parentVisual:FindFirstChild(joint.parentAttachment)
        local jointWorld
        if parentVisual and parentVisual.Parent == char and parentVisualAttachment and parentVisualAttachment:IsA("Attachment") then
            local sourceBasis = parentVisualAttachment.CFrame.Rotation
            local targetBasis = parentTargetAttachment.CFrame.Rotation
            local deltaInPartSpace = targetBasis * targetJointDelta * targetBasis:Inverse()
            local deltaInSourceBasis = sourceBasis:Inverse() * deltaInPartSpace * sourceBasis
            jointWorld = parentVisual.CFrame * parentVisualAttachment.CFrame * deltaInSourceBasis
        else
            jointWorld = parentTarget.CFrame * parentTargetAttachment.CFrame * targetJointDelta
        end
        entry.visual.CFrame = jointWorld * childSourceAttachment.CFrame:Inverse()
        entry.target = childTarget
    end

    local syncAccumulator = 0
    syncConnection = runService.RenderStepped:Connect(function(dt)
        if __mytersInRoundTransition() then return end
        syncAccumulator = syncAccumulator + (tonumber(dt) or 0)
        if syncAccumulator < (1 / 30) then return end
        syncAccumulator = syncAccumulator % (1 / 30)
        if setthreadidentity then pcall(setthreadidentity, 8) end
        if player.Character ~= char or not char.Parent then
            if syncConnection then syncConnection:Disconnect() end
            if MytersWornState.bundleRigSync == syncConnection then MytersWornState.bundleRigSync = nil end
            return
        end
        local liveRoot = char:FindFirstChild("HumanoidRootPart")
        if not liveRoot or not liveRoot:IsA("BasePart") then return end

        -- Usa los segmentos vivos como fallback cercano. El primer joint de la
        -- lista realinea LowerTorso con HumanoidRootPart mediante RootRigAttachment.
        for _, entry in ipairs(visuals) do
            if entry.visual.Parent == char then
                local target = char:FindFirstChild(entry.name)
                if target and target:IsA("BasePart") then
                    entry.target = target
                    entry.visual.CFrame = target.CFrame
                end
            end
        end
        for _, joint in ipairs(MYTERS_R15_BODY_JOINTS) do
            syncVisualJoint(joint)
        end

        local allNearCharacter = true
        for _, entry in ipairs(visuals) do
            if entry.visual.Parent ~= char or (entry.visual.Position - liveRoot.Position).Magnitude > 12 then
                allNearCharacter = false
                break
            end
        end
        for _, entry in ipairs(visuals) do
            local target = char:FindFirstChild(entry.name)
            if target and target:IsA("BasePart") then
                entry.target = target
                if allNearCharacter then
                    hideTarget(entry.field, slots[entry.field].id, target)
                else
                    showTarget(target)
                end
            end
        end
    end)
    MytersWornState.bundleRigSync = syncConnection

    local applied = 0
    for _, field in ipairs(order or {}) do
        if succeeded[field] then applied += 1 end
    end
    return applied, totalRequested - applied, errors, succeeded
end

-- Construir el cuerpo a partir de la HumanoidDescription oficial del bundle.
-- Así se conservan las proporciones, posiciones y uniones de sus 15 segmentos.
mytersEquipBundleBodyRig = function(slots, order, char, bundleDesc)
    local errors = {}
    local requestedFields, targets = {}, {}
    local totalRequested = #(order or {})
    for _, field in ipairs(order or {}) do
        if field ~= "Face" then requestedFields[field] = true end
    end
    if next(requestedFields) == nil then return 0, 0, errors end

    local createOk, bundleRig = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(bundleDesc, Enum.HumanoidRigType.R15)
    end)
    if not createOk or not bundleRig or not bundleRig:IsA("Model") then
        local message = "Roblox no pudo generar el rig del bundle: " .. tostring(bundleRig)
        for _, field in ipairs(order) do errors[field] = message end
        return 0, totalRequested, errors
    end

    local bundleRoot = bundleRig:FindFirstChild("HumanoidRootPart")
    local characterRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not bundleRoot or not characterRoot then
        bundleRig:Destroy()
        local message = "no se encontró HumanoidRootPart para alinear el rig del bundle"
        for _, field in ipairs(order) do errors[field] = message end
        return 0, totalRequested, errors
    end

    for field in pairs(requestedFields) do
        for _, partName in ipairs(MYTERS_R15_BODY_PARTS[field] or {}) do
            local sourcePart = bundleRig:FindFirstChild(partName)
            local target = char:FindFirstChild(partName)
            if not sourcePart or not sourcePart:IsA("BasePart") then
                errors[field] = "el rig generado no contiene " .. partName
                break
            elseif not target or not target:IsA("BasePart") then
                errors[field] = "no se encontró la parte original " .. partName
                break
            end
            targets[partName] = target
        end
    end
    if next(errors) then
        bundleRig:Destroy()
        return 0, totalRequested, errors
    end

    local oldBundleRig = char:FindFirstChild("MytersBundleBodyRig")
    local activeExact, activeByName, activeByPart1 = {}, {}, {}
    local function normalizedMotorName(value)
        local key = tostring(value or ""):lower():gsub("[^%w]", "")
        if key == "rootjoint" then return "root" end
        return key
    end
    local function partName(motor, property)
        local part = motor and motor[property]
        return part and tostring(part.Name) or ""
    end
    local function addMotor(index, key, motor)
        if key == "" then return end
        local bucket = index[key]
        if not bucket then bucket = {}; index[key] = bucket end
        table.insert(bucket, motor)
    end
    local function exactMotorKey(motor)
        return normalizedMotorName(motor.Name) .. "|"
            .. normalizedMotorName(partName(motor, "Part0")) .. "|"
            .. normalizedMotorName(partName(motor, "Part1"))
    end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Motor6D") and (not oldBundleRig or not obj:IsDescendantOf(oldBundleRig)) then
            addMotor(activeExact, exactMotorKey(obj), obj)
            addMotor(activeByName, normalizedMotorName(obj.Name), obj)
            addMotor(activeByPart1, normalizedMotorName(partName(obj, "Part1")), obj)
        end
    end
    local bundleMotors = {}
    for _, obj in ipairs(bundleRig:GetDescendants()) do
        if obj:IsA("Motor6D") then table.insert(bundleMotors, obj) end
    end
    local usedActiveMotors, syncPairs = {}, {}
    local function findMotor(index, key, expectedPart0)
        for _, candidate in ipairs(index[key] or {}) do
            if not usedActiveMotors[candidate]
                and (expectedPart0 == "" or normalizedMotorName(partName(candidate, "Part0")) == expectedPart0) then
                return candidate
            end
        end
        for _, candidate in ipairs(index[key] or {}) do
            if not usedActiveMotors[candidate] then return candidate end
        end
        return nil
    end
    for _, bundleMotor in ipairs(bundleMotors) do
        local nameKey = normalizedMotorName(bundleMotor.Name)
        local part0Key = normalizedMotorName(partName(bundleMotor, "Part0"))
        local part1Key = normalizedMotorName(partName(bundleMotor, "Part1"))
        local activeMotor = findMotor(activeExact, exactMotorKey(bundleMotor), part0Key)
            or findMotor(activeByName, nameKey, part0Key)
            or findMotor(activeByPart1, part1Key, part0Key)
        if activeMotor then
            usedActiveMotors[activeMotor] = true
            -- Use the live avatar's actual joint attachment frames. Female/body-package
            -- rigs can have different hip C0/C1 values from the generated description rig.
            -- Copying only Transform leaves the Korblox segment floating at the default hip.
            bundleMotor.C0 = activeMotor.C0
            bundleMotor.C1 = activeMotor.C1
            bundleMotor.Transform = activeMotor.Transform
            table.insert(syncPairs, {active = activeMotor, bundle = bundleMotor})
        end
    end
    if #syncPairs < 10 then
        bundleRig:Destroy()
        local message = "uniones de animación insuficientes: " .. tostring(#syncPairs)
            .. " coincidentes de " .. tostring(#bundleMotors)
        for _, field in ipairs(order) do errors[field] = message end
        return 0, totalRequested, errors
    end

    local alignOk, alignError = pcall(function()
        local transform = characterRoot.CFrame * bundleRoot.CFrame:Inverse()
        bundleRig:PivotTo(transform * bundleRig:GetPivot())
    end)
    if not alignOk then
        bundleRig:Destroy()
        local message = "no se pudo posicionar el rig del bundle: " .. tostring(alignError)
        for _, field in ipairs(order) do errors[field] = message end
        return 0, totalRequested, errors
    end

    for _, obj in ipairs(bundleRig:GetDescendants()) do
        if obj:IsA("Humanoid") or obj:IsA("AnimationController") or obj:IsA("Script")
            or obj:IsA("LocalScript") or obj:IsA("Accessory") or obj:IsA("Shirt")
            or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
            pcall(function() obj:Destroy() end)
        end
    end
    bundleRig.Name = "MytersBundleBodyRig"
    bundleRig:SetAttribute("MytersWearBodyRig", true)
    local fieldForPart = {}
    for field, names in pairs(MYTERS_R15_BODY_PARTS) do
        for _, partName in ipairs(names) do fieldForPart[partName] = field end
    end
    local bodyVisuals = {}
    for _, obj in ipairs(bundleRig:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Anchored = false
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
            obj.Massless = true
            local field = fieldForPart[obj.Name]
            if field and requestedFields[field] then
                obj:SetAttribute("MytersWearBodyVisual", true)
                obj:SetAttribute("MytersWearBodyField", field)
                obj:SetAttribute("MytersWearBodyId", tonumber(slots[field].id) or slots[field].id)
                obj:SetAttribute("MytersWearBodyPart", obj.Name)
                if obj.Name == "Head" and slots.Face then
                    obj:SetAttribute("MytersWearFaceId", tonumber(slots.Face.id) or slots.Face.id)
                end
                obj.LocalTransparencyModifier = 0
                bodyVisuals[field] = (bodyVisuals[field] or 0) + 1
            else
                obj.LocalTransparencyModifier = 1
            end
            if obj == bundleRoot then
                obj.Transparency = 1
                obj.LocalTransparencyModifier = 1
            end
        end
    end

    captureOriginalOutfit(char)
    for _, field in ipairs(order) do mytersDestroyBundleBodyOverlay(char, field, true) end
    if MytersWornState.bundleRigSync then
        pcall(function() MytersWornState.bundleRigSync:Disconnect() end)
        MytersWornState.bundleRigSync = nil
    end

    bundleRig.Parent = char
    local weldOk, weldError = pcall(function()
        local rootWeld = Instance.new("WeldConstraint")
        rootWeld.Name = "MytersBundleRigRootWeld"
        rootWeld.Part0 = characterRoot
        rootWeld.Part1 = bundleRoot
        rootWeld.Parent = bundleRoot
    end)
    if not weldOk then
        bundleRig:Destroy()
        local message = "no se pudo sujetar el rig del bundle al personaje: " .. tostring(weldError)
        for _, field in ipairs(order) do errors[field] = message end
        return 0, totalRequested, errors
    end

    for partName, target in pairs(targets) do
        local field = fieldForPart[partName]
        if target:GetAttribute("MytersWearBodyHiddenByMyters") ~= true then
            target:SetAttribute("MytersWearBodyOriginalLTM", target.LocalTransparencyModifier)
        end
        target:SetAttribute("MytersWearBodyHiddenByMyters", true)
        target:SetAttribute("MytersWearBodyField", field)
        target:SetAttribute("MytersWearBodyId", tonumber(slots[field].id) or slots[field].id)
        if field == "Head" then target:SetAttribute("MytersHeadId", tonumber(slots[field].id) or slots[field].id) end
        target.LocalTransparencyModifier = 1
    end

    local runService = game:GetService("RunService")
    local syncConnection
    local syncAccumulator = 0
    syncConnection = runService.RenderStepped:Connect(function(dt)
        if __mytersInRoundTransition() then return end
        syncAccumulator = syncAccumulator + (tonumber(dt) or 0)
        if syncAccumulator < (1 / 30) then return end
        syncAccumulator = syncAccumulator % (1 / 30)
        if __mytersInRoundTransition() or player.Character ~= char or not char.Parent
            or bundleRig.Parent ~= char or not characterRoot.Parent or not bundleRoot.Parent then
            if syncConnection then syncConnection:Disconnect() end
            if MytersWornState.bundleRigSync == syncConnection then MytersWornState.bundleRigSync = nil end
            if MytersWornState.bundleRigModel == bundleRig then MytersWornState.bundleRigModel = nil end
            return
        end
        for _, pair in ipairs(syncPairs) do
            if pair.active.Parent and pair.bundle.Parent then
                -- Mirror both joint attachment frames and the current animation pose.
                -- This is important for R15 feminine bodies / custom proportions.
                pair.bundle.C0 = pair.active.C0
                pair.bundle.C1 = pair.active.C1
                pair.bundle.Transform = pair.active.Transform
            end
        end
    end)
    MytersWornState.bundleRigSync = syncConnection
    MytersWornState.bundleRigModel = bundleRig

    local applied = 0
    for _, field in ipairs(order) do
        local slot = slots[field]
        if field == "Face" then
            if bodyVisuals.Head then
                MytersWornState.faceId = tonumber(slot.id) or slot.id
                applied += 1
            else
                errors[field] = "el bundle no generó una cabeza para su cara"
            end
        elseif bodyVisuals[field] and bodyVisuals[field] > 0 then
            if field == "Head" then
                MytersWornState.headId = tonumber(slot.id) or slot.id
                MytersWornState.bodyIds.Head = tonumber(slot.id) or slot.id
            else
                MytersWornState.bodyIds[field] = tonumber(slot.id) or slot.id
            end
            applied += 1
        else
            errors[field] = "no se pudo aplicar el cuerpo del bundle"
        end
    end
    return applied, totalRequested - applied, errors
end

local function mytersReplaceR15BodyAsset(field, id, char)
    if field == "Face" then
        local ok, result = pcall(function() return equipFaceDirect(id, char) end)
        if ok and result == true then return true end
        return false, tostring(result or "no se pudo cargar la cara")
    end
    local partNames = MYTERS_R15_BODY_PARTS[field]
    if not partNames then return false, "ranura corporal no compatible: " .. tostring(field) end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return false, "no se encontró Humanoid" end
    if hum.RigType ~= Enum.HumanoidRigType.R15 then return false, "el bundle requiere un rig R15" end
    if mytersBodySlotApplied(char, field, id) then return true end

    local ok, roots = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
    if not ok or type(roots) ~= "table" or #roots == 0 then
        return false, "GetObjects no pudo cargar " .. tostring(id) .. ": " .. tostring(roots)
    end

    local replacements = {}
    if field == "Head" then
        local head, headErr = mytersMakeBundleHead(id, char, roots)
        if head then replacements.Head = head else
            mytersDestroyBundleRoots(roots)
            return false, tostring(headErr)
        end
    else
        local wanted = {}
        for _, partName in ipairs(partNames) do wanted[partName] = true end
        for _, root in ipairs(roots) do
            local candidates = {root}
            for _, obj in ipairs(root:GetDescendants()) do table.insert(candidates, obj) end
            for _, obj in ipairs(candidates) do
                if obj:IsA("BasePart") and wanted[obj.Name] and not replacements[obj.Name] then
                    local cloneOk, clone = pcall(function() return obj:Clone() end)
                    if cloneOk and clone then replacements[obj.Name] = clone end
                end
            end
        end
    end
    mytersDestroyBundleRoots(roots)

    for _, partName in ipairs(partNames) do
        if not replacements[partName] then
            for _, clone in pairs(replacements) do pcall(function() clone:Destroy() end) end
            return false, "falta la subparte " .. partName .. " en el asset " .. tostring(id)
        end
    end

    captureOriginalOutfit(char)
    mytersDestroyBundleBodyOverlay(char, field, true)
    local failure
    for _, partName in ipairs(partNames) do
        local target = char:FindFirstChild(partName)
        local visual = replacements[partName]
        if not target or not target:IsA("BasePart") then
            failure = "no se encontró la parte original " .. partName
            break
        end
        local applyOk, applyErr = pcall(function()
            visual.Name = "MytersBundleBodyVisual_" .. partName
            visual:SetAttribute("MytersWearBodyVisual", true)
            visual:SetAttribute("MytersWearBodyField", field)
            visual:SetAttribute("MytersWearBodyId", tonumber(id) or id)
            visual:SetAttribute("MytersWearBodyPart", partName)
            visual.Anchored = false
            visual.CanCollide = false
            visual.CanTouch = false
            visual.CanQuery = false
            visual.Massless = true
            visual.LocalTransparencyModifier = 0
            visual.Transparency = 0
            -- Los meshes del bundle traen dimensiones de authoring distintas al rig del jugador.
            -- Escalar y centrar cada una en su segmento evita huecos entre brazos, torso y piernas.
            visual.Size = target.Size
            visual.CFrame = target.CFrame
            visual.Parent = char

            local weld = Instance.new("WeldConstraint")
            weld.Name = "MytersBundleBodyWeld"
            weld.Part0 = target
            weld.Part1 = visual
            weld.Parent = visual

            if target:GetAttribute("MytersWearBodyHiddenByMyters") ~= true then
                target:SetAttribute("MytersWearBodyOriginalLTM", target.LocalTransparencyModifier)
            end
            target:SetAttribute("MytersWearBodyHiddenByMyters", true)
            target:SetAttribute("MytersWearBodyField", field)
            target:SetAttribute("MytersWearBodyId", tonumber(id) or id)
            if field == "Head" then target:SetAttribute("MytersHeadId", tonumber(id) or id) end
            target.LocalTransparencyModifier = 1
        end)
        if not applyOk then
            failure = "no se pudo unir " .. partName .. ": " .. tostring(applyErr)
            break
        end
    end

    if failure then
        mytersDestroyBundleBodyOverlay(char, field, true)
        for _, clone in pairs(replacements) do
            if clone.Parent ~= char then pcall(function() clone:Destroy() end) end
        end
        return false, failure
    end
    return true
end

mytersEquipBodyAsset = function(field, id, char)
    if field == "Head" and tonumber(id) == 15093053680 then
        mytersDestroyBundleBodyOverlay(char, "Head", true)
        local ok, err = pcall(function() return equipHeadlessVisual(id, char) end)
        if not ok or err ~= true then return false, tostring(err or "no se pudo aplicar Headless") end
    else
        local ok, err = mytersReplaceR15BodyAsset(field, id, char)
        if not ok then return false, err end
    end
    if field == "Head" then
        MytersWornState.headId = tonumber(id) or id
        MytersWornState.bodyIds.Head = tonumber(id) or id
    elseif field == "Face" then
        MytersWornState.faceId = tonumber(id) or id
    else
        MytersWornState.bodyIds[field] = tonumber(id) or id
    end
    if type(MytersWornState.bodyDescription) == "table" then
        MytersWornState.bodyDescription[field] = tonumber(id) or id
    end
    persistMytersSession()
    return true
end

reapplyMytersBodySlots = function(char)
    if not char then return false end
    local charHum = char:FindFirstChildOfClass("Humanoid")
    if type(MytersWornState.bodyDescription) == "table"
        and charHum and charHum.RigType == Enum.HumanoidRigType.R15 then
        local desc = mytersCreateBundleBodyDescription(MytersWornState.bodyDescription)
        if desc then
            local slots, savedOrder = {}, {}
            local fields = {"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}
            for _, field in ipairs(fields) do
                local id = MytersWornState.bodyIds and MytersWornState.bodyIds[field]
                if tonumber(id) and tonumber(id) > 0 then
                    slots[field] = {id = tonumber(id)}
                    table.insert(savedOrder, field)
                end
            end
            if tonumber(MytersWornState.faceId) and tonumber(MytersWornState.faceId) > 0 then
                slots.Face = {id = tonumber(MytersWornState.faceId)}
                table.insert(savedOrder, "Face")
            end
            if #savedOrder > 0 and mytersEquipBundleBodyVisualsLocally then
                local hasOfficialKorbloxLeg =
                    tonumber(MytersWornState.bodyIds and MytersWornState.bodyIds.RightLeg) == 139607718
                    or tonumber(MytersWornState.bodyIds and MytersWornState.bodyIds.LeftLeg) == 139607673
                local applied, failed
                if hasOfficialKorbloxLeg and mytersEquipBundleBodyRig then
                    applied, failed = mytersEquipBundleBodyRig(slots, savedOrder, char, desc)
                else
                    applied, failed = mytersEquipBundleBodyVisualsLocally(char, desc, slots, savedOrder)
                end
                if applied > 0 then mytersApplyBundleBodyVisuals(char, desc) end
                if applied > 0 and failed == 0 then
                    MytersWornState.bodyDescription = mytersSerializeBundleBodyDescription(desc)
                end
                pcall(function() desc:Destroy() end)
                if applied > 0 and failed == 0 then
                    persistMytersSession()
                    return true
                end
                return false
            end
            pcall(function() desc:Destroy() end)
        end
    end
    local any = false
    local order = {"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}
    for _, field in ipairs(order) do
        local id = MytersWornState.bodyIds and MytersWornState.bodyIds[field]
        if id then
            if mytersBodySlotApplied(char, field, id) then
                any = true
            elseif mytersEquipBodyAsset then
                local ok = false
                pcall(function() ok = mytersEquipBodyAsset(field, id, char) == true end)
                any = ok or any
            end
        end
    end
    return any
end

local function mytersEquipBundleBodySlots(bodyItems, char, bundleDesc)
    local fields = {"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg", "Face"}
    local slots, order = {}, {}
    for _, field in ipairs(fields) do
        local entry = bodyItems and bodyItems[field]
        local id = entry and (entry.id or entry.idText)
        if (not tonumber(id) or tonumber(id) <= 0) and typeof(bundleDesc) == "Instance" and bundleDesc:IsA("HumanoidDescription") then
            pcall(function() id = bundleDesc[field] end)
        end
        if tonumber(id) and tonumber(id) > 0 then
            slots[field] = {id = tonumber(id), entry = entry}
            table.insert(order, field)
        end
    end
    if #order == 0 then return 0, 0, {} end
    local charHum = char and char:FindFirstChildOfClass("Humanoid")
    if not charHum then
        local errors = {}
        for _, field in ipairs(order) do errors[field] = "no se encontró Humanoid" end
        return 0, #order, errors
    end
    captureOriginalOutfit(char)

    local applied, failed, errors, succeeded = 0, 0, {}, {}
    local hasCompleteBody = typeof(bundleDesc) == "Instance"
        and bundleDesc:IsA("HumanoidDescription")
        and charHum.RigType == Enum.HumanoidRigType.R15
    for _, field in ipairs({"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}) do
        if not slots[field] then
            hasCompleteBody = false
            break
        end
    end
    if hasCompleteBody then
        local hasOfficialKorbloxLeg =
            tonumber(slots.RightLeg and slots.RightLeg.id) == 139607718
            or tonumber(slots.LeftLeg and slots.LeftLeg.id) == 139607673
        if hasOfficialKorbloxLeg and mytersEquipBundleBodyRig then
            applied, failed, errors = mytersEquipBundleBodyRig(slots, order, char, bundleDesc)
            for _, field in ipairs(order) do
                if not (errors and errors[field]) then succeeded[field] = true end
            end
        else
            applied, failed, errors, succeeded = mytersEquipBundleBodyVisualsLocally(char, bundleDesc, slots, order)
        end
        if applied > 0 and failed == 0 then
            MytersWornState.bodyDescription = mytersSerializeBundleBodyDescription(bundleDesc)
        end
    else
        MytersWornState.bodyDescription = nil
        for _, field in ipairs(order) do
            local slot = slots[field]
            local ok, err = mytersEquipBodyAsset(field, slot.id, char)
            if ok then
                applied += 1
                succeeded[field] = true
            else
                failed += 1
                errors[field] = tostring(err or "no se pudo aplicar la pieza")
            end
        end
    end

    if applied > 0 then mytersApplyBundleBodyVisuals(char, bundleDesc) end
    local replaceLeft, replaceRight = succeeded.LeftLeg == true, succeeded.RightLeg == true
    if replaceLeft or replaceRight then
        local kept = {}
        for _, id in ipairs(MytersWornState.legIds or {}) do
            local key = tostring(id)
            local side = MytersWornState.legSides and MytersWornState.legSides[key]
            local replacedSide = (side == "Left" and replaceLeft) or (side == "Right" and replaceRight)
            if not replacedSide then table.insert(kept, id) else MytersWornState.legSides[key] = nil end
        end
        MytersWornState.legIds = kept
        if #kept == 0 then mytersStopLegMaintenance() else mytersStartLegMaintenance() end
        if replaceLeft then pcall(function() mytersDestroyKorbloxVisual(char, "LeftUpperLeg") end) end
        if replaceRight then pcall(function() mytersDestroyKorbloxVisual(char, "RightUpperLeg") end) end
    end
    persistMytersSession()
    if reapplyMytersHeadless then
        task.defer(function()
            task.wait(0.3)
            if char and char.Parent then pcall(function() reapplyMytersHeadless(char) end) end
        end)
    end
    return applied, failed, errors
end

local function equipBundle(bundleId, char, onStatus)
    -- Conservar el ID exacto al construir la URL (incluye bundles UGC largos).
    local bundleIdText = exactCatalogId(bundleId)
    local data = safeHttp("https://catalog.roblox.com/v1/bundles/" .. bundleIdText .. "/details")
    if not data or type(data.items) ~= "table" then
        return false, "bundle no encontrado en el catalogo", { Name = "Bundle " .. bundleIdText }
    end

    local name = tostring(data.name or ("Bundle " .. bundleIdText))
    local applied, failed, skipped = 0, 0, 0
    local failures, bodyItems, otherItems = {}, {}, {}
    local bundleDesc
    if tostring(data.bundleType or ""):lower() == "bodyparts" then
        bundleDesc = mytersBundleOutfitDescription(data)
    end

    -- Primero identificar el cuerpo completo. No aplicar brazos/piernas uno a uno.
    for _, item in ipairs(data.items) do
        local itemType = tostring(item.type or item.itemType or item.Type or item.ItemType or ""):lower()
        if itemType == "asset" then
            local assetIdText = exactCatalogId(item.id or item.Id or item.assetId)
            local assetId = tonumber(assetIdText) or assetIdText
            local info = apiProductInfo(assetId)
            local at, typeName = mytersBundleAssetType(item, info)

            if at <= 0 or not info then
                local catalogItem = safeHttp("https://catalog.roblox.com/v1/catalog/items/" .. assetIdText .. "/details?itemType=Asset")
                if catalogItem then
                    local rawType = catalogItem.assetType or catalogItem.AssetType
                    local catalogType = tonumber(rawType) or 0
                    local catalogTypeName = ""
                    if type(rawType) == "table" then
                        catalogType = tonumber(rawType.id or rawType.Id or rawType.assetTypeId or rawType.AssetTypeId) or catalogType
                        catalogTypeName = tostring(rawType.name or rawType.Name or "")
                    elseif type(rawType) == "string" then
                        catalogTypeName = rawType
                    end
                    if at <= 0 and catalogType > 0 then at = catalogType end
                    if typeName == "" then
                        typeName = catalogTypeName
                        if typeName == "" then typeName = tostring(catalogItem.assetTypeName or catalogItem.AssetTypeName or "") end
                    end
                end
            end

            local field = mytersBundleBodyField(at, typeName, item.name or item.Name)
            local entry = {
                id = assetId,
                idText = assetIdText,
                name = tostring(item.name or item.Name or assetIdText),
                typeId = at,
                typeName = typeName,
                info = info,
            }
            if field then
                bodyItems[field] = entry
            else
                table.insert(otherItems, entry)
            end
        end
    end

    -- Los IDs de /bundles/{id}/details son la fuente autoritativa. Sobrescribir
    -- los slots de la descripción UserOutfit (puede haber dos outfits duplicados)
    -- y crear una descripción base si el endpoint de Outfit falló.
    if tostring(data.bundleType or ""):lower() == "bodyparts" then
        local resolvedDesc, descError = mytersBundleDescriptionFromAssets(bundleDesc, bodyItems, char)
        if resolvedDesc then
            bundleDesc = resolvedDesc
        else
            bundleDesc = nil
            warn("[MytersWear] no se pudo preparar la descripción corporal del bundle:", tostring(descError))
        end
    end

    -- Usar el rig oficial del bundle para conservar uniones y proporciones.
    local bodyApplied, bodyFailed, bodyErrors = mytersEquipBundleBodySlots(bodyItems, char, bundleDesc)
    applied += bodyApplied or 0
    failed += bodyFailed or 0
    for field, bodyErr in pairs(bodyErrors or {}) do
        local entry = bodyItems[field]
        local itemName = entry and entry.name or (name .. " - " .. field)
        table.insert(failures, itemName .. " [cuerpo: " .. field .. "]")
        warn("[MytersWear] no se pudo aplicar la ranura corporal " .. tostring(field) .. ": " .. tostring(bodyErr))
    end

    -- Procesar cualquier pieza adicional que no sea una ranura corporal.
    for _, entry in ipairs(otherItems) do
        local at = tonumber(entry.typeId) or 0
        local itemName = entry.name
        local assetId = entry.id
        local assetIdText = entry.idText
        local info = entry.info
        if at == 78 or at == 24 or at == 10 or at == 3 or at == 9 then
            skipped += 1
        else
            local ok = false
            local resolvedType = tonumber(info and info.AssetTypeId) or at
            if resolvedType > 0 then
                local typeInfo = info or {Name = itemName}
                local callOk, result = pcall(function()
                    return equipSingle(assetId, normalizeAssetType(assetId, resolvedType, typeInfo), char)
                end)
                ok = callOk and result == true
            end

            if not ok and at > 0 then
                local fallbackInfo = {Name = itemName}
                local callOk, result = pcall(function()
                    return equipSingle(assetId, normalizeAssetType(assetId, at, fallbackInfo), char)
                end)
                ok = callOk and result == true
            end

            if ok then
                applied += 1
            else
                failed += 1
                table.insert(failures, itemName .. " [tipo " .. tostring(at) .. "]")
                warn("[MytersWear] bundle item falló:", assetIdText, itemName, "tipo", at, entry.typeName)
            end
        end
        task.wait(0.12)
    end

    local summary = tostring(applied) .. " piezas equipadas"
        .. (failed > 0 and (", " .. tostring(failed) .. " fallaron") or "")
    if failed > 0 then
        local detail
        for _, field in ipairs({"Head", "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg", "Face"}) do
            if bodyErrors and bodyErrors[field] then
                detail = tostring(bodyErrors[field]):gsub("[%c]", " ")
                if #detail > 100 then detail = string.sub(detail, 1, 100) .. "…" end
                break
            end
        end
        local first = detail and ("; causa: " .. detail)
            or (failures[1] and ("; revisa: " .. failures[1]) or "")
        summary ..= first
        if skipped > 0 then summary ..= ", " .. tostring(skipped) .. " omitidas (no son ropa)" end
        return false, summary, { Name = name, AssetTypeName = "Bundle", FailedItems = failures }
    end
    if skipped > 0 then summary ..= ", " .. tostring(skipped) .. " omitidas (no son ropa)" end
    if applied == 0 then
        return false, summary, { Name = name, AssetTypeName = "Bundle" }
    end
    return true, summary, { Name = name, AssetTypeName = "Bundle" }
end

-- ──────────────────────────────────────────────
-- ENTRY POINT
-- ──────────────────────────────────────────────
local function mytersWearItem(input, onStatus, onDone)
    local rawInput = tostring(input or ""):match("^%s*(.-)%s*$")
    local id, parsedIdText = parseId(rawInput)
    local bundleIdText = rawInput:lower():match("/bundles/(%d+)")
    local isBundleLink = bundleIdText ~= nil
    local idText = bundleIdText or parsedIdText or exactCatalogId(id)
    if not id then
        if onStatus then onStatus("link/ID inválido", false) end
        return
    end

    if onStatus then onStatus("consultando...", nil) end

    task.spawn(function()
        local char = player.Character
        if not char then
            if onStatus then onStatus("sin personaje", false) end
            if onDone then onDone(false, nil) end
            return
        end

        -- RUTA BUNDLE: detectar explícitamente el formato URL y conservar el ID
        -- original como texto. También se prueba la ruta bundle para IDs largos
        -- pegados sin URL, antes de consultar GetProductInfo como si fuera un Asset.
        local bundleCandidate = bundleIdText
        if not bundleCandidate and parsedIdText and #parsedIdText >= 15 then
            bundleCandidate = parsedIdText
        end
        if bundleCandidate then
            if onStatus then onStatus(isBundleLink and "equipando bundle..." or "consultando...", nil) end
            local ok, msg, binfo = equipBundle(bundleCandidate, char, isBundleLink and onStatus or nil)
            warn("[MytersWear] bundle:", bundleCandidate, ok, msg)
            -- Si el usuario pegó un URL /bundles/, nunca tratar ese ID como Asset
            -- aunque el endpoint falle: se devuelve un error explícito de bundle.
            if ok or isBundleLink then
                if ok then
                    MytersDiagnostic.lastEquip = nil
                else
                    MytersDiagnostic.lastItem = idText
                    MytersDiagnostic.lastError = msg or "el bundle fallo"
                    MytersDiagnostic.lastEquip = { id = idText, name = (binfo and binfo.Name) or ("Bundle " .. idText), error = msg, checkedAt = os.time() }
                end
                if onStatus then
                    onStatus(ok and ("✓ " .. tostring((binfo and binfo.Name) or "Bundle") .. " (" .. tostring(msg) .. ")")
                        or ("✗ " .. tostring(msg or "bundle fallo")), ok)
                end
                if onDone then onDone(ok, ok and binfo or nil) end
                return
            end
        end

        -- Usar catalog API para tipo real (MarketplaceService da tipos incorrectos para UGC)
        local info = apiProductInfo(id)
        if not info then
            if onStatus then onStatus("asset no encontrado", false) end
            if onDone then onDone(false, nil) end
            return
        end

        -- Verificar tipo real via catalog v1 (más preciso que MarketplaceService)
        local catalogData = safeHttp("https://catalog.roblox.com/v1/catalog/items/" .. id .. "/details?itemType=Asset")
        local realTypeId = tonumber(catalogData and catalogData.assetType)
        local typeId   = normalizeAssetType(id,realTypeId or tonumber(info.AssetTypeId) or 0,info)
        local typeName = info.AssetTypeName or ""
        local name     = info.Name or tostring(id)
        local typeL    = typeName:lower()

        warn("[MytersWear] AssetTypeId:", typeId, "| catalog assetType:", realTypeId, "| AssetTypeName:", typeName, "| ID:", id)

        local supported = TYPE_MAP[typeId] or typeId==17 or typeId==18 or typeId==31 or typeId==32 or typeId==39
        if typeId==39 or typeId==24 or typeId==61 and typeName:lower():find("animation") then
            local msg="Este objeto es un modelo/animación y no se puede equipar como ropa."
            if onStatus then onStatus("✗ "..msg,false) end
            if onDone then onDone(false,info) end
            return
        end

        if onStatus then onStatus("equipando...", nil) end

        local ok, msg
        if typeL == "bundle" then
            ok, msg = equipBundle(id, char)
        else
            ok, msg = equipSingle(id, typeId, char)
        end

        local verified=false
        local verifyReason="no se pudo confirmar la aplicación"
        if ok and verifyMytersItem then
            for attempt=1,5 do
                task.wait(attempt==1 and .15 or .3)
                verified,verifyReason=verifyMytersItem(id,typeId,char)
                if verified then break end
                if attempt==3 then
                    if typeId==31 or typeId==32 then
                        if reapplyMytersLegs then reapplyMytersLegs(char) end
                    elseif (typeId==17 or typeId==79) and tonumber(id)==15093053680 then
                        equipHeadlessVisual(id,char)
                    else
                        pcall(equipSingle,id,typeId,char)
                    end
                end
            end
            compilerReport(id,"verificación",verifyReason or "item visible",verified)
            if not verified then
                ok=false
                msg="no se equipó: "..tostring(verifyReason)
                MytersDiagnostic.lastItem=id
                MytersDiagnostic.lastError=msg
                MytersDiagnostic.lastIssues={msg}
                MytersDiagnostic.lastEquip={id=id,name=name,error=msg,checkedAt=os.time()}
            end
        end
        if not ok then
            MytersDiagnostic.lastItem=id
            MytersDiagnostic.lastError=msg or "el método de equipamiento falló"
            MytersDiagnostic.lastEquip={id=id,name=name,error=MytersDiagnostic.lastError,checkedAt=os.time()}
        end
        if ok then MytersDiagnostic.lastEquip=nil end

        warn("[MytersWear] Resultado:", ok, msg)

        if onStatus then
            onStatus(ok and ("✓ " .. name) or ("✗ falló: " .. (msg or typeName)), ok)
        end
        if onDone then onDone(ok, info) end
        task.defer(function()
            if runMytersDiagnostics then runMytersDiagnostics(char,MytersDiagnostic.autoRepair==true) end
        end)
    end)
end

local function mytersWaitForRigReady(char, state)
    if not char or char ~= player.Character then return false end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 6)
    local root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 6)
    if not hum or not root or player.Character ~= char or not char.Parent then return false end

    state = type(state) == "table" and state or MytersWornState
    local needed, seen = {}, {}
    local function need(name)
        if name and not seen[name] then seen[name] = true; table.insert(needed, name) end
    end
    if state.headId or state.faceId or #(state.accessoryIds or {}) > 0 or #(state.hairIds or {}) > 0 then need("Head") end
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local body = state.bodyIds or {}
        if body.Torso then need("UpperTorso") end
        if body.RightArm then need("RightUpperArm") end
        if body.LeftArm then need("LeftUpperArm") end
        if body.RightLeg then need("RightUpperLeg") end
        if body.LeftLeg then need("LeftUpperLeg") end
        for _, id in ipairs(state.legIds or {}) do
            local side = state.legSides and state.legSides[tostring(id)]
            need(side == "Left" and "LeftUpperLeg" or "RightUpperLeg")
        end
    else
        local body = state.bodyIds or {}
        if body.Torso then need("Torso") end
        if body.RightArm then need("Right Arm") end
        if body.LeftArm then need("Left Arm") end
        if body.RightLeg or #(state.legIds or {}) > 0 then need("Right Leg") end
        if body.LeftLeg then need("Left Leg") end
    end

    local deadline = os.clock() + 12
    for _, name in ipairs(needed) do
        if player.Character ~= char or not char.Parent or os.clock() >= deadline then return false end
        if not char:FindFirstChild(name) then char:WaitForChild(name, math.max(0, deadline - os.clock())) end
        if not char:FindFirstChild(name) then return false end
    end
    if player.Character ~= char or not char.Parent then return false end
    return player.Character == char and char.Parent ~= nil
end

local respawnApplying=false
local function reapplyMytersOutfit(char)
    if mytersEnv.MytersWearClosed or rawget(_G, "MytersSessionClosed") or __mytersInRoundTransition() then return end
    if cloneAppearance.locked or respawnApplying or not MytersConfig.keepOnRespawn
        or not char or char ~= player.Character then return end
    respawnApplying=true
    task.spawn(function()
        local ok, err = pcall(function()
            if not mytersWaitForRigReady(char, MytersWornState) then return end
            local function stillCurrent()
                local humNow = char:FindFirstChildOfClass("Humanoid")
                return player.Character == char and char.Parent ~= nil
                    and not mytersEnv.MytersWearClosed and not rawget(_G, "MytersSessionClosed")
                    and not __mytersInRoundTransition()
                    and humNow ~= nil and humNow.Health > 0
            end
            if not stillCurrent() then return end
            local hum=char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if not mytersWearHasSavedItems() and MytersConfig.autoLoadSkin ~= false and getAutoLoadAvatar then
                local targetAvatar = getAutoLoadAvatar()
                if targetAvatar and targetAvatar.state and loadAvatar then
                    loadAvatar(targetAvatar.state)
                    return
                end
            end
            pcall(captureOriginalOutfit, char)
            local function apply(id)
                if not id or not stillCurrent() then return end
                local infoOk, info = pcall(apiProductInfo, id)
                if infoOk and info and stillCurrent() then
                    pcall(equipSingle,id,normalizeAssetType(id,info.AssetTypeId,info),char)
                end
                task.wait(0.12)
            end
            apply(MytersWornState.shirtId)
            apply(MytersWornState.pantsId)
            apply(MytersWornState.tshirtId)
            apply(MytersWornState.faceId)
            apply(MytersWornState.headId)
            for _,id in ipairs(MytersWornState.accessoryIds or {}) do
                if not stillCurrent() then return end
                apply(id)
            end
            for _,id in ipairs(MytersWornState.hairIds or {}) do
                if not stillCurrent() then return end
                apply(id)
            end
            if not stillCurrent() then return end
            if reapplyMytersHeadless then pcall(reapplyMytersHeadless,char) end
            if reapplyMytersLegs then pcall(reapplyMytersLegs,char) end
            if MytersConfig.removeOriginal then pcall(removeOriginalOutfit,char) end
            if runMytersDiagnostics then pcall(runMytersDiagnostics,char,MytersDiagnostic.autoRepair==true) end
        end)
        respawnApplying=false
        if not ok then warn("[MytersWear] Error al restaurar outfit tras respawn:", err) end
    end)
end
mytersWearConnect(player.CharacterAdded, function(char)
    if not cloneAppearance.locked then reapplyMytersOutfit(char) end
end)
	if player.Character and not cloneAppearance.locked then task.defer(reapplyMytersOutfit,player.Character) end

-- ──────────────────────────────────────────────
-- MANTENIMIENTO CONTINUO
-- Mismo criterio que Korblox & Headless de PLAYER ANIMS: la ropa, el pelo y los
-- accesorios vuelven a aparecer aunque Roblox los borre a mitad de sesión
-- (primera persona, zoom o un resync de HumanoidDescription), sin depender del
-- siguiente respawn. Aquí solo se detecta, que es barato; la reaplicación cara va
-- por reapplyMytersOutfit y va limitada para no saturar GetProductInfo.
-- ──────────────────────────────────────────────
local MYTERSWEAR_REPAIR_COOLDOWN = 8
local lastRepairAt = -math.huge
local function mytersWearHasSavedItems()
    return MytersWornState.shirtId or MytersWornState.pantsId or MytersWornState.tshirtId
        or MytersWornState.headId or MytersWornState.faceId
        or #(MytersWornState.accessoryIds or {})>0 or #(MytersWornState.hairIds or {})>0
        or #(MytersWornState.legIds or {})>0 or next(MytersWornState.bodyIds or {})~=nil
end
local function mytersWearMaintain(char)
    if mytersEnv.MytersWearClosed or rawget(_G, "MytersSessionClosed") or __mytersInRoundTransition() then return end
    if cloneAppearance.locked or not MytersConfig.keepOnRespawn or not char or not char.Parent then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then return end
    local descOk,desc = pcall(function()
        if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
        return hum.HumanoidDescription
    end)
    if not descOk then desc=nil end

    -- Un solo recorrido del personaje en lugar de uno por item.
    local worn,legUp,headless,bodySlots = {},false,false,{}
    local root = char:FindFirstChild("HumanoidRootPart")
    local staleBundleBody = false
    local bundleVisualCount = 0
    -- Shirt/Pants/ShirtGraphic tambien se equipan como INSTANCIA padreada al
    -- personaje, no en HumanoidDescription. Si no se incluyen aqui, el chequeo
    -- de "falta?" los daria por perdidos eternamente y este mismo bucle dispararia
    -- ApplyDescription, que reconstruye el avatar y los borra.
    for _,obj in ipairs(char:GetDescendants()) do
        if obj.Name=="MytersLegMesh" or obj.Name=="MytersKorbloxMesh" then legUp=true end
        if obj:IsA("Accessory") or obj:IsA("Hat") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
            local nid=obj:GetAttribute("MytersWearId")
            if nid then worn[tonumber(nid) or tostring(nid)]=true end
        elseif obj:IsA("BasePart") then
            if obj:GetAttribute("MytersWearBodyVisual") == true then
                bundleVisualCount += 1
                if not root or not root:IsA("BasePart") or (obj.Position-root.Position).Magnitude > 12 then
                    staleBundleBody = true
                end
            end
            if obj:GetAttribute("MytersKorbloxId") then legUp=true end
            if obj:GetAttribute("MytersHeadless") then headless=true end
            local bodyField=obj:GetAttribute("MytersWearBodyField")
            local bodyId=obj:GetAttribute("MytersWearBodyId") or obj:GetAttribute("MytersHeadId")
            if bodyField and bodyId then bodySlots[bodyField]=tonumber(bodyId) or bodyId end
            if obj.Name=="Head" and obj:GetAttribute("MytersHeadId") then bodySlots.Head=tonumber(obj:GetAttribute("MytersHeadId")) or obj:GetAttribute("MytersHeadId") end
        elseif obj:IsA("Decal") and obj:GetAttribute("MytersFaceId") then
            bodySlots.Face=tonumber(obj:GetAttribute("MytersFaceId")) or obj:GetAttribute("MytersFaceId")
        end
    end

    -- Si el sincronizador murió aunque el overlay siga cerca, reconstruirlo:
    -- de otro modo se separará apenas el jugador vuelva a moverse.
    local sync = MytersWornState.bundleRigSync
    local syncConnected = false
    pcall(function() syncConnected = sync ~= nil and sync.Connected == true end)
    if bundleVisualCount > 0 and not syncConnected then staleBundleBody = true end

    local missing=staleBundleBody
    local function wantWorn(id)
        if id and not worn[tonumber(id) or tostring(id)] then missing=true end
    end
    local function wantSlot(field,id)
        if id and not descriptionHasId(desc,field,id) then missing=true end
    end
for _,id in ipairs(MytersWornState.accessoryIds or {}) do wantWorn(id) end
    for _,id in ipairs(MytersWornState.hairIds or {}) do wantWorn(id) end
    -- Ropa y cabeza: van como instancia con MytersWearId, se comprueban por atributo.
    wantWorn(MytersWornState.shirtId)
    wantWorn(MytersWornState.pantsId)
    wantWorn(MytersWornState.tshirtId)
    -- La cara va como Decal pegado a la cabeza: se comprueba en la descripción.
    wantSlot("Face", MytersWornState.faceId)
    if MytersWornState.headId then
        -- Cabezas directas y Headless se reconocen por los atributos del Head R15.
        if tonumber(MytersWornState.headId)==15093053680 then
            if not headless then missing=true end
        elseif not (mytersBodySlotApplied and mytersBodySlotApplied(char, "Head", MytersWornState.headId))
            and not mytersSameBodyAssetId(bodySlots.Head, MytersWornState.headId) then
            wantWorn(MytersWornState.headId)
        end
    end
    for field,id in pairs(MytersWornState.bodyIds or {}) do
        local directApplied = mytersBodySlotApplied and mytersBodySlotApplied(char, field, id)
        if field~="Head" and not directApplied and not descriptionHasId(desc, field, id) then missing=true end
    end
    if not legUp and #(MytersWornState.legIds or {})>0 then missing=true end

    if not missing then return end
    if (os.clock()-lastRepairAt)<MYTERSWEAR_REPAIR_COOLDOWN then return end
    lastRepairAt=os.clock()
    warn("[MytersWear] Mantenimiento: reaplicando el outfit guardado.")
    reapplyMytersOutfit(char)
end
-- No escanear GetDescendants cada segundo: revisar solo cuando un objeto
-- perteneciente al outfit guardado realmente sale del personaje.
local mytersWearMaintenanceCharacter = nil
local mytersWearMaintenanceConn = nil
local mytersWearMaintenanceQueued = false
local mytersWearMaintenanceQueuedCharacter = nil
local mytersWearMaintenanceRequest = 0
local function mytersWearIsTrackedObject(obj)
    if not obj then return false end
    if obj.Name == "MytersLegMesh" or obj.Name == "MytersKorbloxMesh" or obj.Name == "MytersKorbloxVisual" then return true end
    return obj:GetAttribute("MytersWearId") ~= nil
        or obj:GetAttribute("MytersKorbloxId") ~= nil
        or obj:GetAttribute("MytersHeadless") ~= nil
        or obj:GetAttribute("MytersFaceId") ~= nil
        or obj:GetAttribute("MytersWearBodyVisual") == true
        or obj:GetAttribute("MytersWearBodyField") ~= nil
        or obj:GetAttribute("MytersWearBodyId") ~= nil
        or obj:GetAttribute("MytersHeadId") ~= nil
end
local function mytersWearQueueMaintenance(char, delaySeconds)
    if mytersWearMaintenanceQueued and mytersWearMaintenanceQueuedCharacter == char then return end
    mytersWearMaintenanceRequest = mytersWearMaintenanceRequest + 1
    local request = mytersWearMaintenanceRequest
    mytersWearMaintenanceQueued = true
    mytersWearMaintenanceQueuedCharacter = char
    task.delay(delaySeconds or 0.35, function()
        if request ~= mytersWearMaintenanceRequest then return end
        mytersWearMaintenanceQueued = false
        mytersWearMaintenanceQueuedCharacter = nil
        if mytersEnv.MytersWearClosed or rawget(_G, "MytersSessionClosed") then return end
        if char ~= player.Character or not char or not char.Parent then return end
        if mytersWearHasSavedItems() then
            pcall(mytersWearMaintain, char)
        end
    end)
end
local function mytersWearDisconnectMaintenance()
    local connection = mytersWearMaintenanceConn
    mytersWearMaintenanceConn = nil
    if not connection then return end
    for i = #mytersWearConnections, 1, -1 do
        if mytersWearConnections[i] == connection then
            table.remove(mytersWearConnections, i)
            break
        end
    end
    pcall(function() connection:Disconnect() end)
end
local function mytersWearBindMaintenance(char)
    mytersWearDisconnectMaintenance()
    mytersWearMaintenanceCharacter = char
    if not char or not char.Parent then return end
    mytersWearMaintenanceConn = mytersWearConnect(char.DescendantRemoving, function(obj)
        if char ~= mytersWearMaintenanceCharacter or not mytersWearIsTrackedObject(obj) then return end
        mytersWearQueueMaintenance(char)
    end)
    -- La primera pasada espera a que el rig termine de componerse tras el respawn.
    mytersWearQueueMaintenance(char, 1.0)
end
mytersWearConnect(player.CharacterRemoving, function(char)
    if char == mytersWearMaintenanceCharacter then
        mytersWearDisconnectMaintenance()
        mytersWearMaintenanceCharacter = nil
    end
end)
mytersWearConnect(player.CharacterAdded, mytersWearBindMaintenance)
if player.Character then task.defer(mytersWearBindMaintenance, player.Character) end

-- Headless se aplica al reaparecer apenas Roblox parenta la cabeza al Character.
local wearFastHeadlessWatches = setmetatable({}, { __mode = "k" })
local function wearFastHeadlessDisconnect(char)
    local watch = char and wearFastHeadlessWatches[char]
    if not watch then return end
    wearFastHeadlessWatches[char] = nil
    for _, connection in ipairs(watch.connections or {}) do
        pcall(function() connection:Disconnect() end)
        -- Quitar conexiones dinámicas del registro general para que respawns
        -- repetidos no acumulen referencias ya desconectadas.
        for i = #mytersWearConnections, 1, -1 do
            if mytersWearConnections[i] == connection then
                table.remove(mytersWearConnections, i)
                break
            end
        end
    end
end

local function wearGetRespawnHeadlessId()
    local id = MytersWornState.headId or (MytersWornState.bodyIds and MytersWornState.bodyIds.Head)
    if tonumber(id) == MYTERS_HEADLESS_ASSET_ID then return MYTERS_HEADLESS_ASSET_ID end
    return nil
end

local function wearFastApplyHeadlessOnRespawn(char)
    if not char or char ~= player.Character or not char.Parent then return false end
    if mytersEnv.MytersWearClosed or rawget(_G, "MytersSessionClosed") then return false end
    local id = wearGetRespawnHeadlessId()
    if not id then return false end

    local watch = wearFastHeadlessWatches[char]
    if not watch then
        watch = { connections = {}, head = nil }
        wearFastHeadlessWatches[char] = watch
    end
    local function remember(connection)
        if connection then table.insert(watch.connections, connection) end
        return connection
    end
    local function current()
        return player.Character == char and char.Parent ~= nil
            and not mytersEnv.MytersWearClosed and not rawget(_G, "MytersSessionClosed")
            and wearGetRespawnHeadlessId() == id
    end
    local function bindHead(head)
        if not current() or not head or head.Name ~= "Head" or not head:IsA("BasePart") then return false end
        if not mytersApplyHeadlessVisualImmediate(id, char) then return false end
        if watch.head == head then return true end
        watch.head = head
        remember(mytersWearConnect(head.ChildAdded, function(child)
            if not current() or watch.head ~= head then return end
            if child:IsA("Decal") or child:IsA("Texture") then
                pcall(function()
                    child.Transparency = 1
                    child:SetAttribute("MytersHeadless", true)
                end)
            end
        end))
        remember(mytersWearConnect(head:GetPropertyChangedSignal("LocalTransparencyModifier"), function()
            if current() and watch.head == head and head.Parent and head.LocalTransparencyModifier < 0.99 then
                pcall(function() head.LocalTransparencyModifier = 1 end)
            end
        end))
        remember(mytersWearConnect(head:GetPropertyChangedSignal("Transparency"), function()
            if current() and watch.head == head and head.Parent and head.Transparency < 0.99 then
                pcall(function() head.Transparency = 1 end)
            end
        end))
        return true
    end

    local head = char:FindFirstChild("Head")
    if head then
        bindHead(head)
    elseif not watch.waitingForHead then
        watch.waitingForHead = true
        remember(mytersWearConnect(char.ChildAdded, function(child)
            if child.Name ~= "Head" or not child:IsA("BasePart") then return end
            bindHead(child)
        end))
    end
    return watch.head ~= nil
end

mytersWearConnect(player.CharacterRemoving, function(char)
    wearFastHeadlessDisconnect(char)
end)
mytersWearConnect(player.CharacterAdded, function(char)
    wearFastApplyHeadlessOnRespawn(char)
end)
if player.Character then
    task.defer(wearFastApplyHeadlessOnRespawn, player.Character)
end
-- Los avatares guardados se equipan únicamente mediante la acción manual.

-- ──────────────────────────────────────────────
-- UI

-- ══════════════════════════════════════════════════════════════
-- MYTERS WEAR · UI V2
-- Rediseño completo de la capa visual; la lógica permanece intacta.
-- ══════════════════════════════════════════════════════════════
local function __buildMytersWearV2()
local oldMytersUI = CoreGui:FindFirstChild("MytersWearUI")
if oldMytersUI then oldMytersUI:Destroy() end

local MT=(_G.MytersGetMiniTheme and _G.MytersGetMiniTheme()) or {}
local function mt(k,d) local v=MT[k]; if v==nil then return d end return v end
local U={
    surface=mt("surface",Color3.fromRGB(28,28,32)), card=mt("card",Color3.fromRGB(22,22,26)), input=mt("input",Color3.fromRGB(40,40,46)),
    border=mt("border",Color3.fromRGB(200,200,206)), text=mt("text",Color3.fromRGB(235,235,240)), muted=mt("muted",Color3.fromRGB(170,170,178)),
    primaryText=mt("primaryText",Color3.fromRGB(18,18,20)), toggleOn=mt("toggleOn",Color3.fromRGB(165,165,172)), toggleOff=mt("toggleOff",Color3.fromRGB(60,60,66)),
    purple=mt("accent",Color3.fromRGB(165,165,172)), purpleSoft=mt("accentSoft",Color3.fromRGB(140,140,148)),
    green=Color3.fromRGB(52,211,153), red=Color3.fromRGB(248,113,113),
}
U.bg=U.surface
setmetatable(U,{__index=function(_,k) if k=="faint" then return rawget(U,"muted"):Lerp(rawget(U,"surface"),.4) end end})
local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1100,700)
local compactDevice=MytersIsTouch
local PW=compactDevice and math.min(420,math.max(280,math.floor(vp.X*.92))) or math.max(380,math.min(640,math.floor(vp.X*.9)))
local PH=compactDevice and math.min(560,math.max(360,math.floor(vp.Y*.72))) or math.max(340,math.min(480,math.floor(vp.Y*.86)))
local wearMinScale=compactDevice and .60 or .72
local wearMaxScale=compactDevice and .98 or 1.22
local savedWearScale=math.clamp(tonumber(persistentUI.wearScale) or 1,wearMinScale,wearMaxScale)
local HEADER_H,NAV_H=54,48

local ui=Instance.new("ScreenGui"); ui.Name="MytersWearUI"; ui.ResetOnSpawn=false; ui.IgnoreGuiInset=true; ui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; ui.DisplayOrder=100000; ui.Enabled=false
pcall(function() ui.Parent=CoreGui end)
pcall(function() if _G.MytersRegisterI18nRoot then _G.MytersRegisterI18nRoot(ui) end end)
pcall(function() if _G.MytersRegisterUIFontRoot then _G.MytersRegisterUIFontRoot(ui) end end)
local panel=Instance.new("Frame",ui); panel.Name="MytersWearMiniWindow"; panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(PW,PH); panel.BackgroundColor3=U.surface; panel.BackgroundTransparency=1; panel.BorderSizePixel=0; panel.ClipsDescendants=true; panel.Active=true; panel.Visible=false; panel.ZIndex=200
panel:SetAttribute("MytersMiniWindow",true)
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,18); local panelGradient=Instance.new("UIGradient",panel); panelGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,U.surface:Lerp(U.card,.18)),ColorSequenceKeypoint.new(.48,U.surface),ColorSequenceKeypoint.new(1,U.card:Lerp(U.surface,.35))}); panelGradient.Rotation=115; local panelStroke=Instance.new("UIStroke",panel); panelStroke.Color=U.purpleSoft; panelStroke.Transparency=1; panelStroke.Thickness=1.2; if _G.MytersMiniBindWindow then _G.MytersMiniBindWindow("MytersWearPanel", panel) end
local panelScale=Instance.new("UIScale",panel); panelScale.Name="MytersWearScale"; panelScale.Scale=savedWearScale

-- Helpers: todo el color sale del tema compartido (roles), nada hardcodeado.
local function role(o,r,textRole) if r then o:SetAttribute("MytersMiniThemeRole",r) end; if textRole then o:SetAttribute("MytersMiniThemeTextRole",textRole) end; return o end
local function corner(o,r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r or 8); __mytersWearBootYield(); return c end
local function stroke(o,c,t) local s=Instance.new("UIStroke",o); s.Color=c or U.border; s.Transparency=math.max(t or .75,.6); s.Thickness=1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; role(s,"border"); __mytersWearBootYield(); return s end
local function label(p,t,pos,size,col,font)
    local l=Instance.new("TextLabel",p); l.Position=pos or UDim2.new(); l.Size=size or UDim2.new(1,0,0,16); l.BackgroundTransparency=1; l.BorderSizePixel=0; l.Text=t; l.TextSize=12; l.Font=font or Enum.Font.GothamMedium; l.TextXAlignment=Enum.TextXAlignment.Left; l.TextStrokeTransparency=1
    col=col or U.text
    if col==U.faint then l.TextColor3=U.muted; l.TextTransparency=.38; role(l,nil,"muted")
    elseif col==U.muted then l.TextColor3=col; role(l,nil,"muted")
    elseif col==U.purpleSoft then l.TextColor3=col; role(l,nil,"accent")
    elseif col==U.primaryText then l.TextColor3=col; role(l,nil,"primary")
    elseif col==U.text then l.TextColor3=col; role(l,nil,"text")
    else l.TextColor3=col; role(l,nil,"keep") end
    __mytersWearBootYield(); return l
end
local function button(p,t,pos,size,primary,noHover)
    local b=Instance.new("TextButton",p); b.Position=pos or UDim2.new(); b.Size=size or UDim2.fromOffset(80,28); b.Text=t; b.BorderSizePixel=0; b.AutoButtonColor=false; b.TextSize=11; b.Font=Enum.Font.GothamBold; b.TextStrokeTransparency=1
    if primary then b.TextColor3=U.primaryText; b.BackgroundColor3=U.purple; b:SetAttribute("MytersMiniThemePrimaryText",true); role(b,"accent","primary")
    else b.TextColor3=U.text; b.BackgroundColor3=U.input; role(b,"input","text") end
    corner(b,9); stroke(b,primary and U.purpleSoft or U.border,primary and .7 or .75)
    local bs=Instance.new("UIScale",b); bs.Scale=1
    if not noHover then
        b.MouseEnter:Connect(function() tween(b,{BackgroundColor3=primary and U.purple:Lerp(Color3.new(1,1,1),.18) or U.input:Lerp(Color3.new(1,1,1),.09)},.1); tween(bs,{Scale=1.02},.1) end)
        b.MouseLeave:Connect(function() tween(b,{BackgroundColor3=primary and U.purple or U.input},.1); tween(bs,{Scale=1},.1) end)
    end
    b.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then tween(bs,{Scale=.96},.06) end end)
    b.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then tween(bs,{Scale=1.02},.08) end end)
    __mytersWearBootYield(); return b
end
local function danger(b) b.TextColor3=U.red; b:SetAttribute("MytersMiniThemeTextRole","keep"); return b end
local function cardFrame(p,pos,size) local f=Instance.new("Frame",p); f.Position=pos; f.Size=size; f.BackgroundColor3=U.card; f.BorderSizePixel=0; role(f,"card"); corner(f,12); stroke(f); return f end
local function fieldBox(o) o.BackgroundColor3=U.input; o.BorderSizePixel=0; role(o,"input"); corner(o,10); return stroke(o,U.border,.7) end
local function heading(p,kicker,headline,sub)
    local k=label(p,kicker,UDim2.fromOffset(0,0),UDim2.new(1,0,0,14),U.purpleSoft,Enum.Font.GothamBold); k.TextSize=10
    local h=label(p,headline,UDim2.fromOffset(0,16),UDim2.new(1,0,0,26),U.text,Enum.Font.GothamBold); h.TextSize=19
    local s=label(p,sub,UDim2.fromOffset(0,44),UDim2.new(1,0,0,16),U.muted); s.TextSize=11; s.TextTruncate=Enum.TextTruncate.AtEnd
    return k,h,s
end
local function caption(p,text,pos) local l=label(p,text,pos,UDim2.new(1,0,0,14),U.muted,Enum.Font.GothamBold); l.TextSize=10; return l end

-- Header
local header=Instance.new("Frame",panel); header.Name="MytersWearHeader"; header.Size=UDim2.new(1,0,0,HEADER_H); header.BackgroundTransparency=1; header.BorderSizePixel=0; header.ZIndex=60
local headerAccent=Instance.new("Frame",header); headerAccent.Name="ClixWearAccent"; headerAccent.Position=UDim2.fromOffset(14,8); headerAccent.Size=UDim2.fromOffset(3,38); headerAccent.BackgroundColor3=U.purple; headerAccent.BorderSizePixel=0; headerAccent.ZIndex=64; role(headerAccent,"accent"); corner(headerAccent,3)
-- Se elimina el distintivo cuadrado con la letra W del encabezado.
local hTitle=label(header,"CLIX WEAR",UDim2.fromOffset(26,9),UDim2.new(1,-80,0,20),U.text,Enum.Font.GothamBold); hTitle.TextSize=14
local hSub=label(header,"AVATAR WARDROBE  ·  LOCAL CATALOG",UDim2.fromOffset(26,29),UDim2.new(1,-80,0,14),U.muted,Enum.Font.GothamMedium); hSub.TextSize=9
local headerLine=Instance.new("Frame",header); headerLine.Position=UDim2.new(0,0,1,-1); headerLine.Size=UDim2.new(1,0,0,1); headerLine.BackgroundColor3=U.input; headerLine.BorderSizePixel=0; role(headerLine,"input")
local close=Instance.new("TextButton",header); close.Name="MytersWearClose"; close.AutoButtonColor=false; close.Text=""; close.BorderSizePixel=0; close.BackgroundColor3=Color3.fromRGB(255,95,86); close.BackgroundTransparency=.05; close.Position=UDim2.new(1,-30,0.5,-7); close.Size=UDim2.fromOffset(compactDevice and 18 or 14,compactDevice and 18 or 14); close.ZIndex=65; corner(close,compactDevice and 9 or 7); role(close,"keep")
close.MouseEnter:Connect(function() tween(close,{BackgroundTransparency=0},.1) end); close.MouseLeave:Connect(function() tween(close,{BackgroundTransparency=.05},.1) end)
local resize=Instance.new("TextButton",panel); resize.Name="MytersWearResizeHandle"; resize.AnchorPoint=Vector2.new(1,1); resize.Position=UDim2.new(1,-6,1,-6); resize.Size=UDim2.fromOffset(compactDevice and 30 or 34,compactDevice and 30 or 34); resize.BackgroundTransparency=1; resize.BorderSizePixel=0; resize.Text=""; resize.AutoButtonColor=false; resize.ZIndex=70; resize:SetAttribute("MytersMiniResize",true)
local resizing=false; local resizeStartX=0; local resizeStartY=0; local resizeStartScale=panelScale.Scale
resize.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then resizing=true; resizeStartX=inp.Position.X; resizeStartY=inp.Position.Y; resizeStartScale=panelScale.Scale end end)
UIS.InputChanged:Connect(function(inp) if resizing and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local dx=inp.Position.X-resizeStartX; local dy=inp.Position.Y-resizeStartY; panelScale.Scale=math.clamp(resizeStartScale+(dx+dy)/320,wearMinScale,wearMaxScale) end end)
UIS.InputEnded:Connect(function(inp) if (inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch) and resizing then resizing=false; persistentUI.wearScale=panelScale.Scale end end)

-- Navegación (pill, mismo lenguaje que la UI principal)
local nav=Instance.new("Frame",panel); nav.Name="MytersWearNav"; nav.Position=UDim2.fromOffset(12,HEADER_H+8); nav.Size=UDim2.new(1,-24,0,34); nav.BackgroundColor3=U.card; nav.BorderSizePixel=0; nav.ZIndex=60; role(nav,"card"); corner(nav,11); stroke(nav)
local names={"Catalog","Settings","My Avatars","Popular"}; local tabs={}
local indicator=Instance.new("Frame",nav); indicator.Position=UDim2.new(0,3,0,3); indicator.Size=UDim2.new(1/#names,-6,1,-6); indicator.BackgroundColor3=U.purple; indicator.BorderSizePixel=0; indicator.ZIndex=62; role(indicator,"accent"); corner(indicator,8)
for i,n in ipairs(names) do
    local b=Instance.new("TextButton",nav); b.Position=UDim2.new((i-1)/#names,0,0,0); b.Size=UDim2.new(1/#names,0,1,0); b.BackgroundTransparency=1; b.BorderSizePixel=0; b.Text=n; b.TextSize=11; b.Font=Enum.Font.GothamBold; b.TextStrokeTransparency=1; b.TextColor3=i==1 and U.primaryText or U.muted; b.AutoButtonColor=false; b.ZIndex=65
    b:SetAttribute("MytersMiniThemeTextRole",i==1 and "primary" or "muted")
    local bs=Instance.new("UIScale",b); bs.Scale=1
    b.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then tween(bs,{Scale=.94},.06) end end)
    b.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then tween(bs,{Scale=1},.1) end end)
    tabs[i]=b
end

-- Cuerpo y páginas
local BODY_Y=HEADER_H+NAV_H+8
local body=Instance.new("Frame",panel); body.Name="MytersWearBody"; body.Position=UDim2.fromOffset(0,BODY_Y); body.Size=UDim2.new(1,0,1,-BODY_Y); body.BackgroundTransparency=1; body.BorderSizePixel=0; body.ClipsDescendants=true
local function page()
    local p=Instance.new("ScrollingFrame",body); p.Size=UDim2.fromScale(1,1); p.BackgroundTransparency=1; p.BorderSizePixel=0; p.ScrollBarThickness=3; p.ScrollBarImageColor3=U.purple; p:SetAttribute("MytersMiniThemeScrollBar",true); p.ScrollingDirection=Enum.ScrollingDirection.Y; p.AutomaticCanvasSize=Enum.AutomaticSize.Y; p.CanvasSize=UDim2.fromOffset(0,0); p.Visible=false; p.Active=true
    local pad=Instance.new("UIPadding",p); pad.PaddingLeft=UDim.new(0,14); pad.PaddingRight=UDim.new(0,14); pad.PaddingTop=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,18); return p
end
local catalog=page(); local settings=page(); local avatars=page(); local popular=page(); catalog.Visible=true
local pages={catalog,settings,avatars,popular}
local function showPage(i)
    i=math.clamp(tonumber(i) or 1,1,#pages)
    for n,p in ipairs(pages) do
        local active=n==i; p.Visible=active
        tabs[n]:SetAttribute("MytersMiniThemeTextRole",active and "primary" or "muted")
        tween(tabs[n],{TextColor3=active and U.primaryText or U.muted},.16)
        if active then p.Position=UDim2.fromOffset(0,8); tween(p,{Position=UDim2.fromOffset(0,0)},.2) else p.Position=UDim2.fromOffset(0,0) end
    end
    tween(indicator,{Position=UDim2.new((i-1)/#names,3,0,3)},.2); persistentUI.tab=i
end
for i,b in ipairs(tabs) do b.MouseButton1Click:Connect(function() showPage(i) end) end
showPage(tonumber(persistentUI.tab) or 1)

-- Glass: misma transparencia de tarjetas/campos que el sistema de la UI principal.
local wearGlassPass
wearGlassPass=function(theme)
    theme=theme or (_G.MytersGetMiniTheme and _G.MytersGetMiniTheme()) or MT
    local cT=theme.cardTransparency or .3; local iT=theme.inputTransparency or .4
    for _,o in ipairs(panel:GetDescendants()) do
        if o:IsA("GuiObject") and o~=panel and o.BackgroundTransparency<1 and not o:GetAttribute("MytersWearNoGlass") then
            local r=o:GetAttribute("MytersMiniThemeRole")
            if r==nil then
                local c=o.BackgroundColor3
                if c==U.card then r="card" elseif c==U.input or c==U.surface then r="input" end
                if r then o:SetAttribute("MytersMiniThemeRole",r) end
            end
            if r=="card" then o.BackgroundTransparency=cT elseif r=="input" then o.BackgroundTransparency=iT end
        end
    end
end
if _G.MytersMiniBind then _G.MytersMiniBind("MytersWearGlass", panel, function(theme) if wearGlassPass then wearGlassPass(theme) end end) end

-- Catálogo: preview, importación, recientes y guardados.
local cTitle,cHead,cSub=heading(catalog,"CATÁLOGO","Elige tu próxima pieza.","Importa un item por enlace o ID y añádelo a tu avatar.")
local preview=cardFrame(catalog,UDim2.fromOffset(0,72),UDim2.new(1,0,0,100))
local pImage=Instance.new("ImageLabel",preview); pImage.Position=UDim2.fromOffset(10,10); pImage.Size=UDim2.fromOffset(80,80); pImage.BackgroundColor3=U.input; pImage.BorderSizePixel=0; pImage.ScaleType=Enum.ScaleType.Fit; pImage.Image=""; role(pImage,"input"); corner(pImage,9)
local pPlaceholder=label(pImage,"—",UDim2.fromScale(0,0),UDim2.fromScale(1,1),U.faint,Enum.Font.GothamBold); pPlaceholder.TextXAlignment=Enum.TextXAlignment.Center; pPlaceholder.TextYAlignment=Enum.TextYAlignment.Center; pPlaceholder.TextSize=24
local pName=label(preview,"Sin item seleccionado",UDim2.fromOffset(102,16),UDim2.new(1,-114,0,20),U.text,Enum.Font.GothamBold); pName.TextSize=14; pName.TextTruncate=Enum.TextTruncate.AtEnd
local pType=label(preview,"Añade un enlace del catálogo",UDim2.fromOffset(102,42),UDim2.new(1,-114,0,16),U.muted); pType.TextTruncate=Enum.TextTruncate.AtEnd
local pId=label(preview,"—",UDim2.fromOffset(102,64),UDim2.new(1,-114,0,14),U.faint); pId.TextSize=10
local inLabel=caption(catalog,"ENLACE O ID DEL CATÁLOGO",UDim2.fromOffset(0,188))
local input=Instance.new("TextBox",catalog); input.Position=UDim2.fromOffset(0,206); input.Size=UDim2.new(1,0,0,38); input.ClearTextOnFocus=false; input.PlaceholderText="Pega una URL o un ID de Roblox..."; input.Text=persistentUI.input or ""; input.TextColor3=U.text; input.PlaceholderColor3=U.faint; input.TextSize=12; input.Font=Enum.Font.GothamMedium; input.TextXAlignment=Enum.TextXAlignment.Left; input.TextStrokeTransparency=1; input:SetAttribute("MytersMiniThemeTextRole","text")
local inputStroke=fieldBox(input); local inPad=Instance.new("UIPadding",input); inPad.PaddingLeft=UDim.new(0,12); inPad.PaddingRight=UDim.new(0,12)
input.Focused:Connect(function() inputStroke.Color=U.purpleSoft; inputStroke.Transparency=.15 end); input.FocusLost:Connect(function() inputStroke.Color=U.border; inputStroke.Transparency=.7 end)
local status=Instance.new("Frame",catalog); status.Position=UDim2.fromOffset(0,252); status.Size=UDim2.new(1,0,0,32); status.BackgroundColor3=U.input; status.BorderSizePixel=0; role(status,"input"); corner(status,10)
local sDot=Instance.new("Frame",status); sDot.Position=UDim2.fromOffset(12,12); sDot.Size=UDim2.fromOffset(8,8); sDot.BackgroundColor3=U.faint; sDot.BorderSizePixel=0; sDot:SetAttribute("MytersWearNoGlass",true); corner(sDot,4)
local sText=label(status,"Listo para importar un item.",UDim2.fromOffset(30,0),UDim2.new(1,-40,1,0),U.muted); sText.TextYAlignment=Enum.TextYAlignment.Center; sText.TextSize=11
local equip=button(catalog,"Equipar item",UDim2.fromOffset(0,292),UDim2.new(1,0,0,38),true)
local recentTitle=caption(catalog,"RECIENTES",UDim2.fromOffset(0,344))
local recent=cardFrame(catalog,UDim2.fromOffset(0,362),UDim2.new(1,0,0,40)); local recentText=label(recent,"No hay items recientes todavía.",UDim2.fromOffset(14,0),UDim2.new(1,-28,1,0),U.faint); recentText.TextYAlignment=Enum.TextYAlignment.Center; recentText.TextTruncate=Enum.TextTruncate.AtEnd
local savedTitle=caption(catalog,"ITEMS GUARDADOS",UDim2.fromOffset(0,418))
local categories={"Todos","Accesorios","Pelo","Cabezas","Caras","Camisas","Pantalones","Piernas","Bundles"}; local selectedCategory=persistentUI.selectedCategory or "Todos"
local catBar=Instance.new("ScrollingFrame",catalog); catBar.Position=UDim2.fromOffset(0,438); catBar.Size=UDim2.new(1,0,0,32); catBar.BackgroundTransparency=1; catBar.BorderSizePixel=0; catBar.ScrollBarThickness=2; catBar.ScrollBarImageColor3=U.purple; catBar:SetAttribute("MytersMiniThemeScrollBar",true); catBar.ScrollingDirection=Enum.ScrollingDirection.X; catBar.ScrollingEnabled=true; catBar.Active=true; catBar.AutomaticCanvasSize=Enum.AutomaticSize.X; catBar.CanvasSize=UDim2.fromOffset(0,0)
local catLayout=Instance.new("UIListLayout",catBar); catLayout.FillDirection=Enum.FillDirection.Horizontal; catLayout.Padding=UDim.new(0,6); catLayout.SortOrder=Enum.SortOrder.LayoutOrder
local catButtons={}; local renderSaved
local function styleChip(b,active)
    b:SetAttribute("MytersMiniThemeRole",active and "accent" or "input"); b:SetAttribute("MytersMiniThemeTextRole",active and "primary" or "muted")
    b.BackgroundColor3=active and U.purple or U.input; b.TextColor3=active and U.primaryText or U.muted
    b.BackgroundTransparency=active and 0 or (MT.inputTransparency or .4)
end
for i,n in ipairs(categories) do
    local b=button(catBar,n,UDim2.new(),UDim2.fromOffset(n=="Todos" and 54 or 84,28),false,true); b.LayoutOrder=i; b.TextSize=10; styleChip(b,n==selectedCategory); catButtons[n]=b
    b.MouseButton1Click:Connect(function() selectedCategory=n; persistentUI.selectedCategory=n; for name,x in pairs(catButtons) do styleChip(x,name==n) end; renderSaved() end)
end
local saveName=Instance.new("TextBox",catalog); saveName.Position=UDim2.fromOffset(0,478); saveName.Size=UDim2.new(1,-94,0,38); saveName.ClearTextOnFocus=false; saveName.PlaceholderText="Nombre del item guardado..."; saveName.Text=persistentUI.itemName or ""; saveName.TextColor3=U.text; saveName.PlaceholderColor3=U.faint; saveName.TextSize=11; saveName.Font=Enum.Font.GothamMedium; saveName.TextXAlignment=Enum.TextXAlignment.Left; saveName.TextStrokeTransparency=1; saveName:SetAttribute("MytersMiniThemeTextRole","text"); fieldBox(saveName); local snPad=Instance.new("UIPadding",saveName); snPad.PaddingLeft=UDim.new(0,12); snPad.PaddingRight=UDim.new(0,12)
input:GetPropertyChangedSignal("Text"):Connect(function() persistentUI.input=input.Text end)
saveName:GetPropertyChangedSignal("Text"):Connect(function() persistentUI.itemName=saveName.Text end)
local saveItem=button(catalog,"Guardar",UDim2.new(1,-84,0,478),UDim2.fromOffset(84,38),true)
local savedRow=Instance.new("ScrollingFrame",catalog); savedRow.Name="MytersSavedItemsScroll"; savedRow.Position=UDim2.fromOffset(0,526); savedRow.Size=UDim2.new(1,0,0,276); savedRow.BackgroundTransparency=1; savedRow.BorderSizePixel=0; savedRow.ScrollBarThickness=3; savedRow.ScrollBarImageColor3=U.purple; savedRow:SetAttribute("MytersMiniThemeScrollBar",true); savedRow.ScrollingDirection=Enum.ScrollingDirection.Y; savedRow.ScrollingEnabled=true; savedRow.Active=true; savedRow.CanvasSize=UDim2.new(0,0,0,0)
local savedLayout=Instance.new("UIGridLayout",savedRow); savedLayout.CellSize=UDim2.new(.5,-5,0,106); savedLayout.CellPadding=UDim2.fromOffset(10,8); savedLayout.SortOrder=Enum.SortOrder.LayoutOrder
local savedEmptyLabel=label(catalog,"No hay items guardados en esta categoría.",UDim2.fromOffset(0,540),UDim2.new(1,0,0,36),U.faint); savedEmptyLabel.TextYAlignment=Enum.TextYAlignment.Center; savedEmptyLabel.TextXAlignment=Enum.TextXAlignment.Center; savedEmptyLabel.Visible=false

local function setStatus(text,ok) sText.Text=text; sText.TextColor3=ok==true and U.green or ok==false and U.red or U.muted; sDot.BackgroundColor3=ok==true and U.green or ok==false and U.red or U.faint end

-- Populares: selección fija de artículos destacados con miniatura y equipamiento directo.
local popularTitle,popularHead,popularSub=heading(popular,"POPULARES","Artículos populares.","Explora piezas destacadas y equípalas con un toque.")


local popularList=Instance.new("Frame",popular); popularList.Position=UDim2.fromOffset(0,72); popularList.Size=UDim2.new(1,0,0,20*86); popularList.BackgroundTransparency=1; popularList.BorderSizePixel=0
local popularLayout=Instance.new("UIListLayout",popularList); popularLayout.FillDirection=Enum.FillDirection.Vertical; popularLayout.Padding=UDim.new(0,6); popularLayout.SortOrder=Enum.SortOrder.LayoutOrder
popular.CanvasSize=UDim2.new(0,0,0,82+(20*78)+12)
local popularItems={
    {48545806,"Dominus Frigidus"},
    {21070012,"Dominus Empyreus"},
    {76479271580913,"Stormbreak Horns of the Tempest Skies"},
    {1744060292,"Poisoned Horns of the Toxic Wasteland"},
    {1016143686,"White Sparkle Time Fedora"},
    {74891470,"Frozen Horns of the Frigid Planes"},
    {493476042,"Sky Blue Sparkle Time Fedora"},
    {1029025,"The Classic ROBLOX Fedora"},
    {215718515,"Fiery Horns of the Netherworld"},
    {215751161,"Orange Sparkle Time Fedora"},
    {162067148,"Dominus Astra"},
    {124730194,"Blackvalk"},
    {147180077,"Teal Sparkle Time Fedora"},
    {259423244,"Black Sparkle Time Fedora"},
    {119916949,"Midnight Blue Sparkle Time Fedora"},
    {100929604,"Green Sparkle Time Fedora"},
    {98346834,"Bluesteel Fedora"},
    {72082328,"Red Sparkle Time Fedora"},
    {63043890,"Purple Sparkle Time Fedora"},
    {31101391,"Dominus Infernus"},
    {1031429,"Domino Crown"},
    {10159600649,"8-Bit Royal Crown"},
    {139607718,"Korblox Deathspeaker Right Leg",32},
    {15093053680,"Headless Head",17}
}
popularList.Size=UDim2.new(1,0,0,#popularItems*78)
popular.CanvasSize=UDim2.new(0,0,0,82+(#popularItems*78)+12)
local function equipPopularItem(id,typeHint,char)
    if not char then return false end
    local reason="no se pudo confirmar la aplicación"
    local candidates={}
    local seen={}
    local function addType(v)
        v=tonumber(v)
        if v and not seen[v] then seen[v]=true; table.insert(candidates,v) end
    end
    local info=apiProductInfo(id)
    addType(info and normalizeAssetType(id,info.AssetTypeId,info))
    addType(typeHint)
    -- Accesorios UGC pueden aparecer como Hat, Hair, Face o accesorios rígidos.
    for _,v in ipairs({8,41,42,43,44,45,46,47,17,18,31,32}) do addType(v) end
    for _,typeId in ipairs(candidates) do
        local ok,result=pcall(function() return equipSingle(id,typeId,char) end)
        if ok and result==true then
            task.wait(.15)
            local verified,why=true,""
            if verifyMytersItem then verified,why=verifyMytersItem(id,typeId,char) end
            compilerReport(id,"verificación",why or "item visible",verified)
            if verified then return true,typeId end
            reason=why or reason
            if typeId==31 or typeId==32 then
                if reapplyMytersLegs then reapplyMytersLegs(char) end
            elseif (typeId==17 or typeId==79) and tonumber(id)==15093053680 then
                equipHeadlessVisual(id,char)
            end
        end
    end
    return false,reason
end
for order,item in ipairs(popularItems) do
    local id,name=item[1],item[2]
    local card=Instance.new("Frame",popularList); card.LayoutOrder=order; card.Size=UDim2.new(1,0,0,72); card.BackgroundColor3=U.card; card.BorderSizePixel=0; role(card,"card"); corner(card,12); stroke(card)
    local img=Instance.new("ImageLabel",card); img.Position=UDim2.fromOffset(8,8); img.Size=UDim2.fromOffset(56,56); img.BackgroundColor3=U.input; img.BorderSizePixel=0; img.ScaleType=Enum.ScaleType.Fit; img.Image="rbxthumb://type=Asset&id="..id.."&w=150&h=150"; role(img,"input"); corner(img,8)
    local title=label(card,name,UDim2.fromOffset(72,10),UDim2.new(1,compactDevice and -224 or -238,0,20),U.text,Enum.Font.GothamBold); title.TextSize=11; title.TextTruncate=Enum.TextTruncate.AtEnd
    local meta=label(card,"ID: "..id,UDim2.fromOffset(72,36),UDim2.new(1,compactDevice and -224 or -238,0,15),U.muted); meta.TextSize=9
    local wear=button(card,"Equipar",UDim2.new(1,compactDevice and -140 or -152,0,21),UDim2.fromOffset(compactDevice and 64 or 70,compactDevice and 26 or 28),true); wear.TextSize=9
    local remove=button(card,"Quitar",UDim2.new(1,compactDevice and -72 or -76,0,21),UDim2.fromOffset(compactDevice and 64 or 70,compactDevice and 26 or 28),false); remove.TextSize=9; danger(remove)
    wear.MouseButton1Click:Connect(function()
        input.Text=tostring(id)
        wear.Text="Equipando..."
        popularSub.Text="Aplicando "..name.." al avatar..."
        task.spawn(function()
            local ok,detail,reason=pcall(function()
                return equipPopularItem(id,item[3] or 8,player.Character)
            end)
            local equipped=ok and detail==true
            if equipped then
                MytersDiagnostic.lastEquip=nil
            else
                MytersDiagnostic.lastEquip={id=id,name=name,error=tostring(reason or "no se pudo confirmar la aplicación"),checkedAt=os.time()}
                MytersDiagnostic.lastItem=id
                MytersDiagnostic.lastError=MytersDiagnostic.lastEquip.error
            end
            if runMytersDiagnostics then runMytersDiagnostics(player.Character,MytersDiagnostic.autoRepair==true) end
            wear.Text=equipped and "Equipado" or "Reintentar"
            tween(wear,{BackgroundColor3=equipped and U.green or U.red},.14)
            local wearScale=wear:FindFirstChildOfClass("UIScale")
            if wearScale then tween(wearScale,{Scale=1.08},.1); task.delay(.1,function() if wearScale and wearScale.Parent then tween(wearScale,{Scale=1},.14) end end) end
            popularSub.Text=equipped and ("✓ "..name.." equipado.") or ("No se pudo equipar "..name..": "..tostring(reason or "error no identificado"))
            if equipped then setStatus(name.." equipado.",true) else setStatus("No se pudo equipar: "..tostring(reason or "error no identificado"),false) end
            task.delay(1.5,function() if wear and wear.Parent then wear.Text="Equipar"; tween(wear,{BackgroundColor3=U.purple},.18) end end)
        end)
    end)
    remove.MouseButton1Click:Connect(function()
        local info=apiProductInfo(id)
        local typeId=normalizeAssetType(id,item[3] or (info and info.AssetTypeId) or 8,info)
        local removed=unequipItem and unequipItem(id,typeId,player.Character)
        remove.Text=removed and "Quitado" or "No puesto"
        tween(remove,{BackgroundColor3=removed and U.green or U.red},.14)
        local removeScale=remove:FindFirstChildOfClass("UIScale")
        if removeScale then tween(removeScale,{Scale=1.08},.1); task.delay(.1,function() if removeScale and removeScale.Parent then tween(removeScale,{Scale=1},.14) end end) end
        if removed then
            popularSub.Text=name.." quitado del avatar."
            setStatus(name.." desequipado.",true)
        else
            setStatus("Ese item no está equipado.",nil)
        end
        task.delay(1.5,function() if remove and remove.Parent then remove.Text="Quitar"; tween(remove,{BackgroundColor3=U.input},.18) end end)
    end)
end

local function clearDescriptionId(id,typeId,char)
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local field=TYPE_MAP[typeId] and TYPE_MAP[typeId][2]
    if not hum or not field or field=="Face" or field=="Head" then return false end
    local ok,desc=pcall(function()
        if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
        return hum.HumanoidDescription
    end)
    if not ok or not desc then return false end
    local kept={}; local changed=false
    for value in tostring(safeDescriptionField(desc,field) or ""):gmatch("%d+") do
        if tostring(value)~=tostring(id) then table.insert(kept,value) else changed=true end
    end
    if not changed then return false end
    local applied=pcall(function()
        desc[field]=table.concat(kept,",")
        return applyDescriptionPreservingLegs(desc,hum,char)
    end)
    return applied
end

unequipItem=function(id,typeId,char)
    if not char then return false end
    local wanted=tonumber(id) or id
    typeId=tonumber(typeId)
    if typeId==11 then return restoreShirt(char) end
    if typeId==12 then return restorePants(char) end
    if typeId==2 then return restoreTShirt(char) end
    if typeId==17 or typeId==79 then return restoreHead(char) end
    if typeId==18 then return restoreFace(char) end

    if typeId==31 or typeId==32 then
        local removed=false
        local removedSide = MytersWornState.legSides[tostring(wanted)]
        for _, obj in ipairs(char:GetDescendants()) do
            if (obj.Name == "MytersKorbloxVisual" or obj:GetAttribute("MytersKorbloxVisual") == true)
                and tonumber(obj:GetAttribute("MytersKorbloxId")) == tonumber(wanted) then
                removed=true
            end
        end
        mytersDestroyKorbloxVisual(char, nil, wanted)
        for _,part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and tonumber(part:GetAttribute("MytersKorbloxId"))==tonumber(wanted) then
                local mesh=part:FindFirstChild("MytersLegMesh")
                if mesh then mesh:Destroy() end
                local original=MytersOriginal.legs[part.Name]
                if original then
                    pcall(function()
                        part.Transparency=original.baseTransparency or 0
                        part.LocalTransparencyModifier=original.transparency or 0
                    end)
                    if part:IsA("MeshPart") and original.meshId then
                        pcall(function() part.MeshId=original.meshId; part.TextureID=original.textureId or "" end)
                    end
                end
                part:SetAttribute("MytersKorbloxId",nil)
                part:SetAttribute("MytersKorbloxNative",nil); part:SetAttribute("MytersWearVisual",nil)
                part:SetAttribute("MytersKorbloxMeshId",nil)
                removed=true
            elseif part:IsA("BasePart") and tonumber(part:GetAttribute("MytersKorbloxHidden"))==tonumber(wanted) then
                local original=MytersOriginal.legs[part.Name]
                if original then
                    pcall(function()
                        part.Transparency=original.baseTransparency or 0
                        part.LocalTransparencyModifier=original.transparency or 0
                    end)
                end
                part:SetAttribute("MytersKorbloxHidden",nil)
                removed=true
            end
        end
        for i=#MytersWornState.legIds,1,-1 do if tonumber(MytersWornState.legIds[i])==tonumber(wanted) then table.remove(MytersWornState.legIds,i) end end
        if #MytersWornState.legIds == 0 then mytersStopLegMaintenance() else mytersStartLegMaintenance() end
        MytersWornState.legSides[tostring(wanted)]=nil
        if removedSide then
            local sideStillWorn = false
            for _, activeSide in pairs(MytersWornState.legSides or {}) do
                if activeSide == removedSide then sideStillWorn = true break end
            end
            if not sideStillWorn then
                pcall(function() mytersRestoreKorbloxHip(char, removedSide) end)
            end
        end
        for field,current in pairs(MytersWornState.bodyIds) do
            if tonumber(current)==tonumber(wanted) then
                if mytersDestroyBundleBodyOverlay then pcall(function() mytersDestroyBundleBodyOverlay(char,field,true) end) end
                MytersWornState.bodyIds[field]=nil
                if field=="Head" then MytersWornState.headId=nil end
                if field=="Face" then MytersWornState.faceId=nil end
                removed=true
            end
        end
        persistMytersSession()
        return removed
    end

    local removed=false
    for _,obj in ipairs(char:GetChildren()) do
        if (obj:IsA("Accessory") or obj:IsA("Hat")) and tonumber(obj:GetAttribute("MytersWearId"))==tonumber(wanted) then
            obj:Destroy(); removed=true
        end
    end
    for i=#MytersWornState.accessoryIds,1,-1 do if tonumber(MytersWornState.accessoryIds[i])==tonumber(wanted) then table.remove(MytersWornState.accessoryIds,i); removed=true end end
    for i=#MytersWornState.hairIds,1,-1 do if tonumber(MytersWornState.hairIds[i])==tonumber(wanted) then table.remove(MytersWornState.hairIds,i); removed=true end end
    if clearDescriptionId(wanted,typeId,char) then removed=true end
    persistMytersSession()
    task.defer(function() if runMytersDiagnostics then runMytersDiagnostics(char,false) end end)
    return removed
end

local function equipSavedItem(item)
    local raw = item.input or exactCatalogId(item.id)
    input.Text = raw
    setStatus("Aplicando item guardado...", nil)
    mytersWearItem(raw, function(msg, ok)
        setStatus(msg, ok)
    end, function(ok)
        if ok then
            setStatus("Item guardado equipado.", true)
        end
    end)
end

local mytersWearBundleThumbCache = {}
local function mytersSetBundleThumbnail(imageLabel, bundleId, guard)
    if not imageLabel then return end
    local idText = exactCatalogId(bundleId)
    local fallback = "rbxthumb://type=BundleThumbnail&id=" .. idText .. "&w=150&h=150"
    imageLabel.Image = mytersWearBundleThumbCache[idText] or fallback
    if mytersWearBundleThumbCache[idText] then return end
    task.spawn(function()
        local response = safeHttp("https://thumbnails.roblox.com/v1/bundles/thumbnails?bundleIds=" .. idText .. "&size=150x150&format=Png&isCircular=false")
        local row = response and type(response.data) == "table" and response.data[1]
        local imageUrl = row and row.imageUrl
        if type(imageUrl) ~= "string" or imageUrl == "" then
            local fallbackResponse = safeHttp("https://thumbnails.roblox.com/v1/bundles/icons?bundleIds=" .. idText .. "&size=150x150&format=Png&isCircular=false")
            local fallbackRow = fallbackResponse and type(fallbackResponse.data) == "table" and fallbackResponse.data[1]
            imageUrl = fallbackRow and fallbackRow.imageUrl
        end
        if type(imageUrl) ~= "string" or imageUrl == "" then return end
        mytersWearBundleThumbCache[idText] = imageUrl
        local allowed = true
        if guard then
            local okGuard, result = pcall(guard)
            allowed = okGuard and result == true
        end
        if allowed and imageLabel.Parent then
            pcall(function() imageLabel.Image = imageUrl end)
        end
    end)
end

function renderSaved()
    for _,x in ipairs(savedRow:GetChildren()) do
        if x:IsA("Frame") or x:IsA("TextLabel") then x:Destroy() end
    end
    local count=0
    for _,item in ipairs(savedItems) do
        if selectedCategory=="Todos" or item.category==selectedCategory then
            count=count+1
            local card=Instance.new("Frame",savedRow)
            card.LayoutOrder=count
            card.Size=UDim2.fromOffset(math.floor((PW-58)/2),106)
            card.BackgroundColor3=U.card
            card.BorderSizePixel=0
            role(card,"card")
            corner(card,12)
            stroke(card)
            local img=Instance.new("ImageLabel",card)
            img.Position=UDim2.fromOffset(7,7)
            img.Size=UDim2.fromOffset(44,44)
            img.BackgroundColor3=U.input
            img.BorderSizePixel=0
            if item.category=="Bundles" then
                mytersSetBundleThumbnail(img,item.id)
            else
                img.Image="rbxthumb://type=Asset&id="..exactCatalogId(item.id).."&w=150&h=150"
            end
            img.ScaleType=Enum.ScaleType.Fit
            corner(img,6)
            local n=label(card,item.name or ("Item "..item.id),UDim2.fromOffset(58,8),UDim2.new(1,-64,0,30),U.text,Enum.Font.GothamBold)
            n.TextSize=10
            n.TextWrapped=true
            local t=label(card,item.category or "Accesorio",UDim2.fromOffset(58,43),UDim2.new(1,-64,0,14),U.muted)
            t.TextSize=9
            local load=button(card,"Cargar",UDim2.fromOffset(7,78),UDim2.new(.5,-10,0,21),false)
            load.TextSize=10
            load.MouseButton1Click:Connect(function() equipSavedItem(item) end)
            local remove=button(card,"Quitar",UDim2.new(.5,3,0,78),UDim2.new(.5,-10,0,21),false)
            remove.TextSize=10; danger(remove)
            remove.MouseButton1Click:Connect(function()
                local info=apiProductInfo(item.id)
                local typeId=normalizeAssetType(item.id,info and info.AssetTypeId or 8,info)
                local removed=unequipItem and unequipItem(item.id,typeId,player.Character)
                remove.Text=removed and "Quitado" or "No puesto"
                if removed then setStatus((item.name or "Item").." desequipado.",true) else setStatus("Ese item no está equipado.",nil) end
                task.delay(1.5,function() if remove and remove.Parent then remove.Text="Quitar" end end)
            end)
        end
    end
    if savedEmptyLabel then savedEmptyLabel.Visible=(count==0) end
    if wearGlassPass then pcall(wearGlassPass) end
    local rows=math.ceil(math.max(count,1)/2)
    savedRow.CanvasSize=UDim2.fromOffset(0,rows*114)
    savedRow.CanvasPosition=Vector2.new(0,math.clamp(savedRow.CanvasPosition.Y,0,math.max(0,rows*114-savedRow.AbsoluteSize.Y)))
end

local previewToken=0
local function updateMytersWearPreview(raw)
    previewToken=previewToken+1
    local token=previewToken
    raw=tostring(raw or input.Text or "")
    local id,idText=parseId(raw)
    local isBundle=raw:lower():find("/bundles/",1,true) ~= nil
    if not id then
        pName.Text="Sin item seleccionado"; pType.Text="Añade un enlace del catálogo"; pId.Text="—"; pImage.Image=""; pPlaceholder.Text="—"
        setStatus("Listo para importar un item.",nil)
        return
    end

    idText=idText or exactCatalogId(id)
    pName.Text="Cargando item..."
    pId.Text="ID · "..idText
    pPlaceholder.Text=""
    if isBundle then
        -- Probar miniatura local de Roblox y usar el endpoint de thumbnails como respaldo.
        mytersSetBundleThumbnail(pImage,idText,function() return token==previewToken end)
    else
        pImage.Image="rbxthumb://type=Asset&id="..idText.."&w=150&h=150"
    end

    task.delay(.25,function()
        if token~=previewToken then return end
        if isBundle then
            local data=safeHttp("https://catalog.roblox.com/v1/bundles/"..idText.."/details")
            if data and data.items then
                pName.Text=data.name or ("Bundle "..idText)
                pType.Text="Bundle · "..tostring(#data.items).." piezas"
                pPlaceholder.Text=""
                setStatus("Bundle válido. Listo para equipar.",true)
            else
                pName.Text="Bundle no encontrado"; pType.Text="Revisa el enlace"; setStatus("No se pudo validar este bundle.",false)
            end
        else
            local info=apiProductInfo(id)
            local typeId=tonumber(info and info.AssetTypeId)
            if info and (typeId==39 or typeId==24) then
                pName.Text=info.Name or ("Item "..idText); pType.Text="No es ropa ni accesorio"; setStatus("Este objeto no se puede equipar en el avatar.",false)
            elseif info then
                pName.Text=info.Name or ("Item "..idText); pType.Text=info.AssetTypeName or "Catálogo"; setStatus("Item válido. Listo para equipar.",true)
            else
                pName.Text="Item no encontrado"; pType.Text="Revisa el enlace o ID"; setStatus("No se pudo validar este item.",false)
            end
        end
    end)
end
input:GetPropertyChangedSignal("Text"):Connect(updateMytersWearPreview)
-- La caja de texto puede cargarse desde la configuración antes de conectar el evento.
-- Forzar la vista previa inicial evita que se quede en "Sin item seleccionado".
task.defer(function()
    if input and input.Parent then updateMytersWearPreview(input.Text) end
end)
local busy=false; equip.MouseButton1Click:Connect(function() if busy then return end; if input.Text=="" then setStatus("Introduce un enlace o ID primero.",false); return end; busy=true; equip.Text="Equipando..."; tween(equip,{BackgroundColor3=U.purpleSoft},.12); setStatus("Aplicando item al avatar...",nil); mytersWearItem(input.Text,function(msg,ok) setStatus(msg,ok) end,function(ok,info) busy=false; equip.Text=ok and "Equipado" or "Reintentar"; tween(equip,{BackgroundColor3=ok and U.green or U.red},.14); local equipScale=equip:FindFirstChildOfClass("UIScale"); if equipScale then tween(equipScale,{Scale=1.06},.1); task.delay(.1,function() if equipScale and equipScale.Parent then tween(equipScale,{Scale=1},.14) end end) end; if ok and info then recentText.Text=info.Name or "Item equipado" end; task.delay(1.4,function() if equip and equip.Parent then equip.Text="Equipar item"; tween(equip,{BackgroundColor3=U.purple},.18) end end) end) end)
local function categoryForInfo(info)
    local typeId=tonumber(info and info.AssetTypeId)
    if typeId==41 then return "Pelo" end
    if typeId==17 or typeId==79 then return "Cabezas" end
    if typeId==18 then return "Caras" end
    if typeId==31 or typeId==32 then return "Piernas" end
    if typeId==2 then return "Camisas" end
    if typeId==12 then return "Pantalones" end
    if typeId==13 then return "Camisas" end
    local text=tostring(info and info.AssetTypeName or ""):lower()
    if text:find("hair") or text:find("pelo") then return "Pelo" end
    if text:find("face") or text:find("cara") then return "Caras" end
    if text:find("head") or text:find("cabeza") then return "Cabezas" end
    if text:find("shirt") or text:find("camisa") then return "Camisas" end
    if text:find("pant") then return "Pantalones" end
    if text:find("bundle") then return "Bundles" end
    if tonumber(info and info.AssetTypeId)==31 or tonumber(info and info.AssetTypeId)==32 then return "Piernas" end
    return "Accesorios"
end
saveItem.MouseButton1Click:Connect(function()
    local raw=input.Text; local id,idText=parseId(raw)
    if not id then setStatus("Introduce un item válido antes de guardarlo.",false); return end
    local name=saveName.Text:gsub("^%s+",""):gsub("%s+$","")
    if name=="" then name=pName.Text end
    local isBundle=raw:lower():find("/bundles/") ~= nil
    local info=isBundle and nil or apiProductInfo(id)
    local savedId=isBundle and (idText or exactCatalogId(id)) or id
    for i=#savedItems,1,-1 do if tostring(savedItems[i].id)==tostring(savedId) then table.remove(savedItems,i) end end
    table.insert(savedItems,1,{id=savedId,name=name,input=raw,category=isBundle and "Bundles" or categoryForInfo(info)})
    getgenv().MytersSavedItems=savedItems; saveName.Text=""; renderSaved(); setStatus("Item guardado.",true)
end)
renderSaved()

-- Ajustes
local stTitle,stHead,stSub=heading(settings,"AJUSTES","Ajusta tu sesión.","Controla cómo Myters aplica y restaura tus piezas.")
local behavior=cardFrame(settings,UDim2.fromOffset(0,72),UDim2.new(1,0,0,205)); local bTitle=caption(behavior,"COMPORTAMIENTO",UDim2.fromOffset(14,12)); bTitle.Size=UDim2.new(1,-28,0,14)
local function toggle(parent,pos,value,callback)
    local b=Instance.new("TextButton",parent); b.Position=pos; b.Size=UDim2.fromOffset(40,22); b.Text=""; b.BorderSizePixel=0; b.AutoButtonColor=false
    value=value and true or false
    b:SetAttribute("MytersMiniThemeRole","toggleState"); b:SetAttribute("MytersMiniThemeSelected",value)
    b.BackgroundColor3=value and U.toggleOn or U.toggleOff; corner(b,11); stroke(b)
    local k=Instance.new("Frame",b); k.Size=UDim2.fromOffset(16,16); k.BorderSizePixel=0; k:SetAttribute("MytersWearNoGlass",true); corner(k,8)
    local function paint(v,animate)
        local kp=v and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3); local kc=v and U.primaryText or U.muted
        b:SetAttribute("MytersMiniThemeSelected",v)
        if animate then tween(b,{BackgroundColor3=v and U.toggleOn or U.toggleOff},.14); tween(k,{Position=kp,BackgroundColor3=kc},.14) else b.BackgroundColor3=v and U.toggleOn or U.toggleOff; k.Position=kp; k.BackgroundColor3=kc end
    end
    paint(value,false)
    b.MouseButton1Click:Connect(function() value=callback(not value) and true or false; paint(value,true) end)
    return b
end
local bRow1=label(behavior,"Varios accesorios",UDim2.fromOffset(14,38),UDim2.new(1,-80,0,18),U.text,Enum.Font.GothamBold); local mSub=label(behavior,"Acumula piezas sin sustituir las anteriores.",UDim2.fromOffset(14,57),UDim2.new(1,-80,0,14),U.muted); mSub.TextSize=10; toggle(behavior,UDim2.new(1,-54,0,42),MytersConfig.multiAccessory,function(v) MytersConfig.multiAccessory=v; persistMytersSession(); return v end)
local bDiv=Instance.new("Frame",behavior); bDiv.Position=UDim2.fromOffset(14,82); bDiv.Size=UDim2.new(1,-28,0,1); bDiv.BackgroundColor3=U.input; bDiv.BorderSizePixel=0; role(bDiv,"input"); bDiv:SetAttribute("MytersWearNoGlass",true)
local bRow2=label(behavior,"Quitar ropa original",UDim2.fromOffset(14,94),UDim2.new(1,-80,0,18),U.text,Enum.Font.GothamBold); local rSub=label(behavior,"Ocúltala mientras construyes tu avatar.",UDim2.fromOffset(14,113),UDim2.new(1,-80,0,14),U.muted); rSub.TextSize=10; toggle(behavior,UDim2.new(1,-54,0,98),MytersConfig.removeOriginal,function(v) MytersConfig.removeOriginal=v; if v and player.Character then captureOriginalOutfit(player.Character); removeOriginalOutfit(player.Character) end; persistMytersSession(); return v end)
local bDiv2=Instance.new("Frame",behavior); bDiv2.Position=UDim2.fromOffset(14,138); bDiv2.Size=UDim2.new(1,-28,0,1); bDiv2.BackgroundColor3=U.input; bDiv2.BorderSizePixel=0; role(bDiv2,"input"); bDiv2:SetAttribute("MytersWearNoGlass",true)
local bRow3=label(behavior,"Auto-cargar skin guardada",UDim2.fromOffset(14,150),UDim2.new(1,-80,0,18),U.text,Enum.Font.GothamBold); local acSub=label(behavior,"Aplica tu skin guardada al entrar o reaparecer.",UDim2.fromOffset(14,169),UDim2.new(1,-80,0,14),U.muted); acSub.TextSize=10; toggle(behavior,UDim2.new(1,-54,0,154),MytersConfig.autoLoadSkin,function(v) MytersConfig.autoLoadSkin=v; persistMytersSession(); return v end)

local equipAllSaved=button(settings,"Equipar todo guardado",UDim2.fromOffset(0,290),UDim2.new(1,0,0,38),true)
local function onEquipAllClicked()
    if #savedItems==0 then
        setStatus("No hay items guardados para equipar.",false)
        return
    end
    equipAllSaved.Text="Equipando todo..."
    tween(equipAllSaved,{BackgroundColor3=U.purpleSoft},.12)
    task.spawn(function()
        for _,item in ipairs(savedItems) do
            pcall(function() equipSavedItem(item) end)
            task.wait(.18)
        end
        equipAllSaved.Text="Equipar todo guardado"
        tween(equipAllSaved,{BackgroundColor3=U.green},.14)
        local allScale=equipAllSaved:FindFirstChildOfClass("UIScale")
        if allScale then tween(allScale,{Scale=1.05},.1); task.delay(.1,function() if allScale and allScale.Parent then tween(allScale,{Scale=1},.14) end end) end
        setStatus("Items guardados aplicados.",true)
        task.wait(1.2)
        if equipAllSaved and equipAllSaved.Parent then tween(equipAllSaved,{BackgroundColor3=U.purple},.18) end
    end)
end
equipAllSaved.MouseButton1Click:Connect(onEquipAllClicked)
equipAllSaved.Activated:Connect(onEquipAllClicked)

local reTitle=caption(settings,"RESTAURAR POR CATEGORÍA",UDim2.fromOffset(0,344)); local reCard=cardFrame(settings,UDim2.fromOffset(0,364),UDim2.new(1,0,0,146))
local reInner=Instance.new("Frame",reCard); reInner.Position=UDim2.fromOffset(12,12); reInner.Size=UDim2.new(1,-24,1,-24); reInner.BackgroundTransparency=1; reInner.BorderSizePixel=0; local reGrid=Instance.new("UIGridLayout",reInner); reGrid.CellSize=UDim2.new(.5,-4,0,26); reGrid.CellPadding=UDim2.fromOffset(8,6); reGrid.SortOrder=Enum.SortOrder.LayoutOrder
local restores={{"Camisa",restoreShirt},{"Pantalón",restorePants},{"Camisa clásica",restoreTShirt},{"Accesorios",restoreAccessories},{"Pelo",restoreHair},{"Piernas",restoreLegMeshes},{"Cabeza",restoreHead},{"Cara",restoreFace}}
for i,e in ipairs(restores) do local b=button(reInner,e[1],UDim2.new(),UDim2.fromOffset(10,26),false); b.LayoutOrder=i; b.TextSize=10; b.MouseButton1Click:Connect(function() if player.Character then e[2](player.Character); b.Text="✓ "..e[1]; task.delay(1,function() b.Text=e[1] end) end end) end
local allRestore=button(settings,"Restaurar todo",UDim2.fromOffset(0,522),UDim2.new(1,0,0,36),false); danger(allRestore)
local function onRestoreAllClicked()
    if player.Character then
        restoreAll(player.Character)
        allRestore.Text="✓ Restaurado"
        task.delay(1.2,function() if allRestore and allRestore.Parent then allRestore.Text="Restaurar todo" end end)
    end
end
allRestore.MouseButton1Click:Connect(onRestoreAllClicked)
allRestore.Activated:Connect(onRestoreAllClicked)

-- Panel compilador retirado; conservar diagnósticos internos sin UI.
MytersDiagnostic.onUpdate=nil

local function removeMytersOnly(kind,char)
    if not char then return end
    if kind=="shirt" then
        for _,v in ipairs(char:GetChildren()) do if v:IsA("Shirt") and isMytersClothing(v,"MytersShirt") then v:Destroy() end end
        MytersWornState.shirtId=nil
    elseif kind=="pants" then
        for _,v in ipairs(char:GetChildren()) do if v:IsA("Pants") and isMytersClothing(v,"MytersPants") then v:Destroy() end end
        MytersWornState.pantsId=nil
    elseif kind=="tshirt" then
        for _,v in ipairs(char:GetChildren()) do if v:IsA("ShirtGraphic") and isMytersClothing(v,"MytersTShirt") then v:Destroy() end end
        MytersWornState.tshirtId=nil
    elseif kind=="accessories" or kind=="hair" or kind=="allAccessories" then
        local removed={}
        for _,acc in ipairs(char:GetChildren()) do
            if (acc:IsA("Accessory") or acc:IsA("Hat")) and isMytersAccessory(acc) then
                local hair=isHairAccessoryInstance(acc) or acc:GetAttribute("MytersHair")==true
                if kind=="allAccessories" or (kind=="hair" and hair) or (kind=="accessories" and not hair) then
                    local removedId=acc:GetAttribute("MytersWearId")
                    if removedId then removed[removedId]=true end
                    acc:Destroy()
                end
            end
        end
        for i=#MytersWornState.accessoryIds,1,-1 do if removed[MytersWornState.accessoryIds[i]] then table.remove(MytersWornState.accessoryIds,i) end end
        for i=#MytersWornState.hairIds,1,-1 do if removed[MytersWornState.hairIds[i]] then table.remove(MytersWornState.hairIds,i) end end
        if kind=="allAccessories" then mytersEquippedAccessories={} end
    elseif kind=="head" then
        restoreHead(char)
    elseif kind=="face" then
        restoreFace(char)
    elseif kind=="legs" then
        restoreLegMeshes(char)
    end
end

local removeTitle=caption(settings,"QUITAR EQUIPADOS",UDim2.fromOffset(0,580)); local removeCard=cardFrame(settings,UDim2.fromOffset(0,602),UDim2.new(1,0,0,178))
local removeInner=Instance.new("Frame",removeCard); removeInner.Position=UDim2.fromOffset(12,12); removeInner.Size=UDim2.new(1,-24,1,-24); removeInner.BackgroundTransparency=1; removeInner.BorderSizePixel=0; local removeGrid=Instance.new("UIGridLayout",removeInner); removeGrid.CellSize=UDim2.new(.5,-4,0,26); removeGrid.CellPadding=UDim2.fromOffset(8,6); removeGrid.SortOrder=Enum.SortOrder.LayoutOrder
local removals={{"Camisa","shirt"},{"Pantalón","pants"},{"Camisa clásica","tshirt"},{"Accesorios","accessories"},{"Pelo","hair"},{"Todo accesorio","allAccessories"},{"Cabeza","head"},{"Cara","face"},{"Piernas","legs"}}
for i,e in ipairs(removals) do
    local b=button(removeInner,"Quitar "..e[1],UDim2.new(),UDim2.fromOffset(10,26),false); b.LayoutOrder=i
    b.TextSize=10
    b.MouseButton1Click:Connect(function()
        if player.Character then removeMytersOnly(e[2],player.Character); b.Text="✓ "..e[1]; task.delay(1,function() b.Text="Quitar "..e[1] end) end
    end)
end
-- Mis avatares
local avTitle,avHead,avSub=heading(avatars,"MIS AVATARES","Looks guardados.","Tus combinaciones listas para volver a vestir.")
local avName=Instance.new("TextBox",avatars); avName.Position=UDim2.fromOffset(0,82); avName.Size=UDim2.new(1,-94,0,38); avName.ClearTextOnFocus=false; avName.PlaceholderText="Nombre de este look..."; avName.Text=persistentUI.avatarName or ""; avName.TextColor3=U.text; avName.PlaceholderColor3=U.faint; avName.TextSize=11; avName.Font=Enum.Font.GothamMedium; avName.TextXAlignment=Enum.TextXAlignment.Left; avName.TextStrokeTransparency=1; avName:SetAttribute("MytersMiniThemeTextRole","text"); fieldBox(avName); local avPad=Instance.new("UIPadding",avName); avPad.PaddingLeft=UDim.new(0,12); avPad.PaddingRight=UDim.new(0,12); avName:GetPropertyChangedSignal("Text"):Connect(function() persistentUI.avatarName=avName.Text end)
local avSave=button(avatars,"Guardar",UDim2.new(1,-84,0,82),UDim2.fromOffset(84,38),true); local avGrid=Instance.new("Frame",avatars); avGrid.Position=UDim2.fromOffset(0,134); avGrid.Size=UDim2.new(1,0,0,0); avGrid.AutomaticSize=Enum.AutomaticSize.Y; avGrid.BackgroundTransparency=1; avGrid.BorderSizePixel=0; local grid=Instance.new("UIGridLayout",avGrid); grid.CellSize=compactDevice and UDim2.new(1,0,0,232) or UDim2.new(.5,-5,0,232); grid.CellPadding=UDim2.fromOffset(10,10); grid.SortOrder=Enum.SortOrder.LayoutOrder
local function captureAvatarSnapshot(char)
    if not char then return nil end
    local previous={}
    for _,obj in ipairs(char:GetDescendants()) do
        previous[obj]=obj.Archivable
        obj.Archivable=true
    end
    local oldRootArchivable=char.Archivable
    char.Archivable=true
    local ok,snapshot=pcall(function() return char:Clone() end)
    char.Archivable=oldRootArchivable
    for obj,value in pairs(previous) do if obj and obj.Parent then obj.Archivable=value end end
    if not ok or not snapshot then return nil end
    snapshot.Name="MytersSavedAvatar"
    for _,obj in ipairs(snapshot:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            obj:Destroy()
        elseif obj:IsA("Motor6D") then
            pcall(function() obj.Transform=CFrame.identity end)
        elseif obj:IsA("BasePart") then
            obj.Anchored=true; obj.CanCollide=false; obj.LocalTransparencyModifier=0
            if obj.Name=="HumanoidRootPart" then obj.Transparency=1 end
        end
    end
    pcall(function() snapshot:PivotTo(CFrame.new()) end)
    return snapshot
end
local function avatarState() return {shirtId=MytersWornState.shirtId,pantsId=MytersWornState.pantsId,tshirtId=MytersWornState.tshirtId,headId=MytersWornState.headId,faceId=MytersWornState.faceId,accessoryIds=table.clone(MytersWornState.accessoryIds),hairIds=table.clone(MytersWornState.hairIds),legIds=table.clone(MytersWornState.legIds),legSides=table.clone(MytersWornState.legSides),bodyIds=table.clone(MytersWornState.bodyIds)} end
local mytersAvatarLoadGeneration = 0
local function loadAvatar(state)
    local char = player.Character
    if not char then return end
    state = state or {}
    mytersAvatarLoadGeneration = mytersAvatarLoadGeneration + 1
    local loadGeneration = mytersAvatarLoadGeneration
    task.spawn(function()
        local function stillCurrent()
            return loadGeneration == mytersAvatarLoadGeneration
                and not mytersEnv.MytersWearClosed and not rawget(_G, "MytersSessionClosed")
                and player.Character == char and char.Parent ~= nil
        end
        local transitionDeadline = os.clock() + 5
        while __mytersInRoundTransition() and os.clock() < transitionDeadline and stillCurrent() do
            task.wait(0.1)
        end
        if not stillCurrent() or __mytersInRoundTransition() then return end
        -- Esperar humanoid estable sin bloquear el hilo principal.
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not hum or not stillCurrent() then return end
        task.wait(0.5)
        if not stillCurrent() then return end

        -- NO restoreAll completo al inicio: a veces resetea y el juego pisa la ropa.
        -- ANTI-FLASHEO: solo quita la prenda de MytersWear cuyo ID sea DISTINTO al que
        -- vamos a poner. Si es la misma se deja intacta; si no, desaparece y
        -- reaparece, y eso se ve como un fogonazo en cada reset.
        pcall(function()
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Shirt") or v:IsA("Pants") then
                    local isMyters = v:GetAttribute("MytersWear") or v.Name:find("Myters")
                    if isMyters then
                        local cur = tonumber(v:GetAttribute("MytersWearId"))
                        local want = v:IsA("Shirt") and tonumber(state.shirtId) or tonumber(state.pantsId)
                        if not cur or not want or cur ~= want then
                            v:Destroy()
                        end
                    end
                end
            end
        end)

        -- Ropa PRIMERO (tipos fijos)
        if state.shirtId then
            if not stillCurrent() then return end
            pcall(function() equipShirt(state.shirtId, char) end)
            task.wait(0.2)
        end
        if state.pantsId then
            if not stillCurrent() then return end
            pcall(function() equipPants(state.pantsId, char) end)
            task.wait(0.2)
        end
        if state.tshirtId then
            if not stillCurrent() then return end
            pcall(function() equipSingle(state.tshirtId, 2, char) end)
            task.wait(0.15)
        end
        if state.headId then
            if not stillCurrent() then return end
            local info = apiProductInfo(state.headId)
            local tid = info and normalizeAssetType(state.headId, info.AssetTypeId, info) or 17
            pcall(function() equipSingle(state.headId, tid, char) end)
            task.wait(0.12)
        end
        if state.faceId then
            if not stillCurrent() then return end
            pcall(function() equipSingle(state.faceId, 18, char) end)
            task.wait(0.12)
        end
        for field,id in pairs(state.bodyIds or {}) do
            if not stillCurrent() then return end
            if id and mytersEquipBodyAsset then
                pcall(function() mytersEquipBodyAsset(field,id,char) end)
                task.wait(0.12)
            end
        end
        for _, id in ipairs(state.accessoryIds or {}) do
            if not stillCurrent() then return end
            local info = apiProductInfo(id)
            local tid = info and normalizeAssetType(id, info.AssetTypeId, info) or 8
            pcall(function() equipSingle(id, tid, char) end)
            task.wait(0.12)
        end
        for _, id in ipairs(state.hairIds or {}) do
            if not stillCurrent() then return end
            local info = apiProductInfo(id)
            local tid = info and normalizeAssetType(id, info.AssetTypeId, info) or 41
            pcall(function() equipSingle(id, tid, char) end)
            task.wait(0.12)
        end
        for _, id in ipairs(state.legIds or {}) do
            if not stillCurrent() then return end
            local side=state.legSides and state.legSides[tostring(id)]
            pcall(function() equipSingle(id,side=="Left" and 31 or 32,char) end)
            task.wait(0.12)
        end

        -- Refuerzo de ropa (el juego a veces pisa al entrar lobby/ronda).
        -- ANTI-FLASHEO: se hace UNA vez y sólo si la prenda NO está puesta. Antes se
        -- forzaba 3 veces (0.4 / 1.2 / 2.5 s) sin comprobar nada, así que la ropa se
        -- quitaba y se ponía tres veces y el avatar parpadeaba.
        task.delay(0.5, function()
            if not stillCurrent() then return end
            if state.shirtId and not mytersClothingAlreadyOn(char, "Shirt", state.shirtId) then
                pcall(function() equipShirt(state.shirtId, char) end)
            end
            if state.pantsId and not mytersClothingAlreadyOn(char, "Pants", state.pantsId) then
                pcall(function() equipPants(state.pantsId, char) end)
            end
        end)
    end)
end
local function createAvatarViewport(parent,snapshot)
    local vp=Instance.new("ViewportFrame",parent)
    vp.Position=UDim2.fromOffset(10,10); vp.Size=UDim2.new(1,-20,0,104); vp.BackgroundColor3=U.input; vp.BorderSizePixel=0; vp.Ambient=Color3.fromRGB(190,190,190); vp.LightColor=Color3.fromRGB(255,255,255); corner(vp,7)
    local model
    if snapshot then pcall(function() model=snapshot:Clone() end) end
    if not model then
        local fallback=Instance.new("ImageLabel",vp); fallback.Size=UDim2.fromScale(1,1); fallback.BackgroundTransparency=1; fallback.ScaleType=Enum.ScaleType.Fit; fallback.Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150"; return vp
    end
    local world=Instance.new("WorldModel",vp); model.Parent=world
    for _,d in ipairs(model:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored=true; d.CanCollide=false; d.LocalTransparencyModifier=0
            if d.Name=="HumanoidRootPart" then d.Transparency=1 else d.Transparency=0 end
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency=0
        end
    end
    -- Orientación fija: el frente del avatar de Roblox mira hacia -Z.
    -- Así la miniatura no depende de hacia dónde estaba caminando al guardarla.
    pcall(function() model:PivotTo(CFrame.new()) end)
    local cf,size=model:GetBoundingBox()
    if size.Magnitude < 0.1 then
        model:Destroy()
        local fallback=Instance.new("ImageLabel",vp); fallback.Size=UDim2.fromScale(1,1); fallback.BackgroundTransparency=1; fallback.ScaleType=Enum.ScaleType.Fit; fallback.Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150"; return vp
    end
    local cam=Instance.new("Camera",vp); vp.CurrentCamera=cam; cam.FieldOfView=45
    local center=cf.Position+Vector3.new(0,size.Y*.06,0); local distance=math.max(size.Y*1.15,size.X,size.Z)*1.25+1
    cam.CFrame=CFrame.lookAt(center+Vector3.new(0,size.Y*.02,-distance),center)
    return vp
end

local function createAvatarItemSummary(parent,state)
    local summary=Instance.new("Frame",parent)
    summary.Name="EquippedItemsSummary"
    summary.Position=UDim2.fromOffset(10,10)
    summary.Size=UDim2.new(1,-20,0,104)
    summary.BackgroundColor3=U.input
    summary.BackgroundTransparency=0
    summary.BorderSizePixel=0
    corner(summary,7)
    stroke(summary,U.border,.45)

    local lines={}
    local function displayName(id)
        for _,saved in ipairs(savedItems) do
            if tonumber(saved.id)==tonumber(id) and saved.name and saved.name~="" then return tostring(saved.name) end
        end
        return "ID "..tostring(id)
    end
    local function addPiece(title,id)
        if id then table.insert(lines,title..": "..displayName(id)) end
    end
    state=state or {}
    addPiece("Camisa",state.shirtId)
    addPiece("Pantalón",state.pantsId)
    addPiece("Camisa clásica",state.tshirtId)
    addPiece("Cabeza",state.headId)
    addPiece("Cara",state.faceId)
    for _,id in ipairs(state.hairIds or {}) do addPiece("Pelo",id) end
    for _,id in ipairs(state.accessoryIds or {}) do addPiece("Accesorio",id) end
    for _,id in ipairs(state.legIds or {}) do
        local side=state.legSides and state.legSides[tostring(id)]
        addPiece(side=="Left" and "Pierna izquierda" or side=="Right" and "Pierna derecha" or "Pierna",id)
    end
    local bodyLabels={LeftArm="Brazo izquierdo",RightArm="Brazo derecho",Torso="Torso",LeftLeg="Pierna izquierda",RightLeg="Pierna derecha"}
    for field,id in pairs(state.bodyIds or {}) do
        if field~="Head" and field~="LeftLeg" and field~="RightLeg" then addPiece(bodyLabels[field] or field,id) end
    end
    if #lines==0 then table.insert(lines,"Sin piezas de MytersWear guardadas") end

    local title=label(summary,"PIEZAS EQUIPADAS · "..tostring(#lines),UDim2.fromOffset(8,6),UDim2.new(1,-16,0,14),U.purpleSoft,Enum.Font.GothamBold)
    title.TextSize=9
    local list=Instance.new("ScrollingFrame",summary)
    list.Name="EquippedItemsList"
    list.Position=UDim2.fromOffset(8,24)
    list.Size=UDim2.new(1,-16,0,72)
    list.BackgroundTransparency=1
    list.BorderSizePixel=0
    list.ScrollBarThickness=2
    list.ScrollBarImageColor3=U.purple
    list.ScrollingDirection=Enum.ScrollingDirection.Y
    list.ScrollingEnabled=true
    list.Active=true
    list.CanvasSize=UDim2.fromOffset(0,#lines*15)
    local text=label(list,table.concat(lines,"\n"),UDim2.fromOffset(2,0),UDim2.new(1,-8,0,#lines*15),U.text,Enum.Font.GothamMedium)
    text.TextSize=9
    text.TextWrapped=true
    text.TextYAlignment=Enum.TextYAlignment.Top
    return summary
end

local editingAvatar=nil
local function renderAvatars()
    for _,x in ipairs(avGrid:GetChildren()) do if x:IsA("Frame") then x:Destroy() end end
    for i,a in ipairs(savedAvatars) do
        a.snapshot=nil
        local c=Instance.new("Frame",avGrid); c.LayoutOrder=i; c.BackgroundColor3=U.card; c.BorderSizePixel=0; role(c,"card"); corner(c,12); stroke(c)
        createAvatarItemSummary(c,a.state)
        local isAutoLoad = (persistentConfig.activeAvatarName == a.name) or (persistentConfig.activeAvatarName == nil and i == 1)
        local n=label(c,(isAutoLoad and "★ " or "") .. (a.name or ("Avatar "..i)),UDim2.fromOffset(10,119),UDim2.new(1,-20,0,18),isAutoLoad and Color3.fromRGB(120,235,160) or U.text,Enum.Font.GothamBold); n.TextSize=11
        local l=button(c,"Cargar",UDim2.fromOffset(10,143),UDim2.new(.5,-15,0,22),false); l.TextSize=9; l.MouseButton1Click:Connect(function() persistentConfig.activeAvatarName=a.name; pcall(wearSaveAvatarsDisk); renderAvatars(); loadAvatar(a.state) end)
        local update=button(c,"Update",UDim2.new(.5,5,0,143),UDim2.new(.5,-15,0,22),false); update.TextSize=9; update.MouseButton1Click:Connect(function()
            a.state=avatarState(); a.snapshot=nil; getgenv().MytersSavedAvatars=savedAvatars; pcall(wearSaveAvatarsDisk); renderAvatars()
        end)
        local edit=button(c,"Editar",UDim2.fromOffset(10,169),UDim2.new(.5,-10,0,22),false); edit.TextSize=9; edit.MouseButton1Click:Connect(function()
            avName.Text=a.name or ""; avName:CaptureFocus(); avName.CursorPosition=#avName.Text+1; editingAvatar=a; avSave.Text="Guardar cambios"
        end)
        local delete=button(c,"Eliminar",UDim2.new(.5,3,0,169),UDim2.new(.5,-10,0,22),false); delete.TextSize=9; danger(delete); delete.MouseButton1Click:Connect(function()
            for index,value in ipairs(savedAvatars) do
                if value==a then
                    table.remove(savedAvatars,index)
                    if persistentConfig.activeAvatarName == a.name then
                        persistentConfig.activeAvatarName = (savedAvatars[1] and savedAvatars[1].name) or nil
                    end
                    break
                end
            end
            getgenv().MytersSavedAvatars=savedAvatars; pcall(wearSaveAvatarsDisk); renderAvatars()
        end)
        local autoBtn=button(c,isAutoLoad and "★ Auto Load (Activo)" or "☆ Elegir para Auto Load",UDim2.fromOffset(10,195),UDim2.new(1,-20,0,22),isAutoLoad)
        autoBtn.TextSize=9
        if isAutoLoad then
            autoBtn.TextColor3=Color3.fromRGB(112,232,158)
        else
            autoBtn.TextColor3=U.muted
        end
        autoBtn.MouseButton1Click:Connect(function()
            persistentConfig.activeAvatarName=a.name
            getgenv().MytersSavedAvatars=savedAvatars
            pcall(wearSaveAvatarsDisk)
            renderAvatars()
        end)
    end
    if wearGlassPass then pcall(wearGlassPass) end
end

avSave.MouseButton1Click:Connect(function()
    local n=avName.Text:gsub("^%s+",""):gsub("%s+$",""); if n=="" then n="Avatar "..(#savedAvatars+1) end
    local state=avatarState()
    if editingAvatar then
        local oldName = editingAvatar.name
        editingAvatar.name=n; editingAvatar.state=state; editingAvatar.snapshot=nil
        if persistentConfig.activeAvatarName == oldName then
            persistentConfig.activeAvatarName = n
        end
        editingAvatar=nil; avSave.Text="Guardar"
    else
        table.insert(savedAvatars,1,{name=n,state=state})
        if not persistentConfig.activeAvatarName or #savedAvatars == 1 then
            persistentConfig.activeAvatarName = n
        end
        while #savedAvatars>20 do table.remove(savedAvatars) end
    end
    avName.Text=""; getgenv().MytersSavedAvatars=savedAvatars; pcall(wearSaveAvatarsDisk); renderAvatars()
end)
renderAvatars()

local function getAutoLoadAvatar()
    if #savedAvatars == 0 then return nil end
    if persistentConfig.activeAvatarName then
        for _, av in ipairs(savedAvatars) do
            if av.name == persistentConfig.activeAvatarName and av.state then
                return av
            end
        end
    end
    return savedAvatars[1]
end

task.spawn(function()
    if MytersConfig.autoLoadSkin == false then return end
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid", 15)
    if not hum then return end
    local deadline = os.clock() + 10
    while __mytersInRoundTransition() and os.clock() < deadline do
        task.wait(0.2)
    end
    task.wait(1.5)
    if not player.Character or player.Character ~= char then return end

    local targetAvatar = getAutoLoadAvatar()
    if targetAvatar and targetAvatar.state and loadAvatar then
        loadAvatar(targetAvatar.state)
    end
end)

-- CharacterRemoving invalida cargas manuales pendientes de loadAvatar().
mytersWearConnect(player.CharacterRemoving, function()
    mytersAvatarLoadGeneration = mytersAvatarLoadGeneration + 1
end)

-- Ajustes tiene contenido largo; fija el canvas para que nunca quede cortado.
catalog.AutomaticCanvasSize=Enum.AutomaticSize.None
catalog.CanvasSize=UDim2.fromOffset(0,910)

local dragging=false; local dragStart; local startPos
header.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=i.Position; startPos=panel.Position end end)
UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-dragStart; panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)

local function openMytersWear()
    if not ui or not panel or not ui.Parent or not panel.Parent then return end
    ui.Enabled=true
    panel.Visible=true
    local targetScale=math.clamp(tonumber(panelScale.Scale) or 1,wearMinScale,wearMaxScale)
    panel.BackgroundTransparency=1
    panelStroke.Transparency=1
    panel.Size=UDim2.fromOffset(math.max(240,PW-30),math.max(320,PH-20))
    panelScale.Scale=math.max(wearMinScale,targetScale*.92)
    tween(panel,{BackgroundTransparency=(_G.MytersMiniPanelT and _G.MytersMiniPanelT() or 0),Size=UDim2.fromOffset(PW,PH)},.22)
    tween(panelStroke,{Transparency=.35},.22)
    tween(panelScale,{Scale=targetScale},.22)
    return true
end
local function closeMytersWear()
    if not panel or not ui then return end
    local targetScale=math.clamp(tonumber(panelScale.Scale) or 1,wearMinScale,wearMaxScale)
    tween(panel,{BackgroundTransparency=1,Size=UDim2.fromOffset(math.max(240,PW-30),math.max(320,PH-20))},.16)
    tween(panelStroke,{Transparency=1},.16)
    tween(panelScale,{Scale=math.max(wearMinScale,targetScale*.92)},.16)
    task.delay(.17,function()
        if panel and panel.Parent then panel.Visible=false end
        if ui and ui.Parent then ui.Enabled=false end
        if panelScale and panelScale.Parent then panelScale.Scale=targetScale end
    end)
end
close.MouseButton1Click:Connect(closeMytersWear)
local releaseMytersWearTheme
local function mytersWearCleanupFn()
	if releaseMytersWearTheme then pcall(releaseMytersWearTheme); releaseMytersWearTheme = nil end
	mytersEnv.MytersWearClosed = true
	rawset(_G, "MytersWearClosed", true)
	mytersStopLegMaintenance()
	mytersWearDisconnectAll()
	respawnApplying = false
    -- Restaurar outfit ORIGINAL al cerrar el script
    pcall(function()
        local char = player and player.Character
        if char and type(restoreAll) == "function" then
            restoreAll(char)
        elseif char then
            -- fallback mínimo ropa
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Shirt") and (v:GetAttribute("MytersWear") or v.Name == "MytersShirt") then v:Destroy() end
                if v:IsA("Pants") and (v:GetAttribute("MytersWear") or v.Name == "MytersPants") then v:Destroy() end
                if (v:IsA("Accessory") or v:IsA("Hat")) and v:GetAttribute("MytersWear") then v:Destroy() end
            end
            if MytersOriginal then
                if MytersOriginal.shirt and MytersOriginal.shirt ~= "" then
                    local s = Instance.new("Shirt"); s.ShirtTemplate = MytersOriginal.shirt; s.Parent = char
                end
                if MytersOriginal.pants and MytersOriginal.pants ~= "" then
                    local p = Instance.new("Pants"); p.PantsTemplate = MytersOriginal.pants; p.Parent = char
                end
            end
        end
    end)
    -- limpiar estado worn
    pcall(function()
        if MytersWornState then
            MytersWornState.shirtId = nil
            MytersWornState.pantsId = nil
            MytersWornState.tshirtId = nil
            MytersWornState.headId = nil
            MytersWornState.faceId = nil
            MytersWornState.accessoryIds = {}
            MytersWornState.hairIds = {}
            MytersWornState.legIds = {}
            MytersWornState.legSides = {}
            MytersWornState.bodyIds = {}
            if persistMytersSession then persistMytersSession() end
        end
    end)
    if ui and ui.Parent then pcall(function() ui.Enabled=false; ui:Destroy() end) end
    if mytersEnv.MytersWearUI==ui then mytersEnv.MytersWearUI=nil end
    mytersEnv.MytersWearConnections = {}
end
pcall(function()
	local register = rawget(_G, "MytersRegisterMiniTheme")
	if type(register) == "function" then releaseMytersWearTheme = register("MytersWearUI", ui, U) end
	if wearGlassPass then wearGlassPass() end
end)
getgenv().MytersWearCleanup = mytersWearCleanupFn
rawset(_G, "MytersWearCleanup", mytersWearCleanupFn)
getgenv().MytersWearOpen=openMytersWear
getgenv().MytersWearClose=closeMytersWear
pcall(function()
    if MytersCleanup and MytersCleanup.register then
        MytersCleanup.register(function()
            pcall(function()
                local cleanup = rawget(_G, "MytersWearCleanup")
                if type(cleanup) ~= "function" then
                    pcall(function() cleanup = getgenv().MytersWearCleanup end)
                end
                if type(cleanup) == "function" then cleanup() end
            end)
        end)
    end
end)
local mytersWearRestoreApi = {shirt=restoreShirt,pants=restorePants,tshirt=restoreTShirt,accessories=restoreAccessories,hair=restoreHair,legs=restoreLegMeshes,head=restoreHead,face=restoreFace,all=restoreAll}
getgenv().MytersWearItem=mytersWearItem; getgenv().MytersWearUI=ui; getgenv().MytersWearConfig=MytersConfig; getgenv().MytersWearDiagnostic=MytersDiagnostic; getgenv().MytersWearDiagnose=runMytersDiagnostics; getgenv().MytersWearCompileReport=function() return MytersDiagnostic.compiler end; getgenv().MytersWearRestore=mytersWearRestoreApi
rawset(_G, "MytersWearRestore", mytersWearRestoreApi)

-- ══════════════════════════════════════════════════════════════
-- EXPORT INTERNOS
-- Todo lo que la mini UI "Clonar Avatar" necesita para equipar
-- en el personaje local lo que lleva puesto OTRO jugador.
-- Sin esto la otra UI tendría que reimplementar el equipador
-- completo (templates de ropa, weld de accesorios, Korblox...).
-- ══════════════════════════════════════════════════════════════
getgenv().MytersWearInternal = {
	player                 = player,
	Players                = Players,
	equipSingle            = equipSingle,
	equipBundle            = equipBundle,
	equipShirt             = equipShirt,
	equipPants             = equipPants,
	equipAccessoryDirect   = equipAccessoryDirect,
	equipLegMeshDirect     = equipLegMeshDirect,
	equipHeadlessVisual    = equipHeadlessVisual,
	unequipItem            = unequipItem,
	restoreAll             = restoreAll,
	restoreShirt           = restoreShirt,
	restorePants           = restorePants,
	restoreTShirt          = restoreTShirt,
	restoreAccessories     = restoreAccessories,
	restoreHair            = restoreHair,
	restoreHead            = restoreHead,
	restoreFace            = restoreFace,
	restoreLegMeshes       = restoreLegMeshes,
	removeOriginalOutfit   = removeOriginalOutfit,
	captureOriginalOutfit  = captureOriginalOutfit,
	mytersClothingAlreadyOn   = mytersClothingAlreadyOn,
	MytersWornState           = MytersWornState,
	MytersConfig              = MytersConfig,
	MytersDiagnostic          = MytersDiagnostic,
	MytersOriginal            = MytersOriginal,
	recaptureOriginalOutfit = recaptureOriginalOutfit,
	cloneAppearance        = cloneAppearance,
	savedAvatars           = savedAvatars,
	avatarState            = avatarState,
	loadAvatar             = loadAvatar,
	renderAvatars          = renderAvatars,
	wearSaveAvatarsDisk    = wearSaveAvatarsDisk,
	normalizeAssetType     = normalizeAssetType,
	apiProductInfo         = apiProductInfo,
	parseId                = parseId,
	safeHttp               = safeHttp,
	runMytersDiagnostics      = runMytersDiagnostics,
	persistMytersSession      = persistMytersSession,
	descriptionHasId       = descriptionHasId,
	verifyMytersItem          = verifyMytersItem,
}

end
__buildMytersWearV2()

-- ══════════════════════════════════════════════════════════════
-- MYTERS CLONE · mini UI para clonar el avatar de otro jugador
-- Se abre desde la tarjeta "Clonar Avatar" de la pestaña MytersWear,
-- con la misma mecánica de ventana (arrastre, resize, animación).
-- ══════════════════════════════════════════════════════════════
local function __buildMytersCloneUI()
local mytersEnv = (getgenv and getgenv()) or _G
mytersEnv.MytersCloneCancel = false
local IW = mytersEnv.MytersWearInternal or {}
local equipSingle         = IW.equipSingle
local restoreAll          = IW.restoreAll
local normalizeAssetType  = IW.normalizeAssetType
local apiProductInfo      = IW.apiProductInfo
local runMytersDiagnostics   = IW.runMytersDiagnostics
local persistMytersSession   = IW.persistMytersSession
local savedAvatars        = IW.savedAvatars
local avatarState         = IW.avatarState
local renderAvatars       = IW.renderAvatars
local wearSaveAvatarsDisk = IW.wearSaveAvatarsDisk

local UIstate = mytersEnv.MytersUIState or {}
mytersEnv.MytersUIState = UIstate

local C = {
	bg=Color3.fromRGB(18,18,20), surface=Color3.fromRGB(28,28,32), card=Color3.fromRGB(24,24,28),
	input=Color3.fromRGB(32,32,36), border=Color3.fromRGB(50,50,55), text=Color3.fromRGB(230,230,234),
	muted=Color3.fromRGB(165,165,170), faint=Color3.fromRGB(120,120,126), primaryText=Color3.fromRGB(18,18,20), toggleOn=Color3.fromRGB(50,50,56), toggleOff=Color3.fromRGB(30,30,34), purple=Color3.fromRGB(165, 165, 172),
	purpleSoft=Color3.fromRGB(124,124,129), green=Color3.fromRGB(52,211,153), red=Color3.fromRGB(248,113,113),
}

local function tw(o, p, d)
	TweenService:Create(o, TweenInfo.new(d or .14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), p):Play()
end
local function corner(o, r)
	local c = Instance.new("UICorner", o)
	c.CornerRadius = UDim.new(0, r or 8)
	__mytersWearBootYield()
	return c
end
local function stroke(o, c, t)
	local s = Instance.new("UIStroke", o)
	s.Color = c or C.border
	s.Transparency = (t == nil and .25 or t)
	__mytersWearBootYield()
	return s
end
local function lbl(p, t, pos, size, col, font, ts)
	local l = Instance.new("TextLabel", p)
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = t or ""
	l.TextColor3 = col or C.text
	l.TextSize = (ts or 11) + 1
	l.Font = font or Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	__mytersWearBootYield()
	return l
end
local function btn(p, t, pos, size, primary)
	local b = Instance.new("TextButton", p)
	b.Position = pos
	b.Size = size
	b.Text = t or ""
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.TextSize = 11
	b.Font = Enum.Font.GothamBold
	b.TextXAlignment = Enum.TextXAlignment.Center
	b.TextColor3 = primary and Color3.fromRGB(18,18,20) or C.muted
	if primary then b:SetAttribute("MytersMiniThemePrimaryText", true) end
	b.BackgroundColor3 = primary and C.purple or C.surface
	corner(b, 7)
	stroke(b, primary and C.purpleSoft or C.border, primary and .55 or .2)
	local bs = Instance.new("UIScale", b)
	bs.Name = "MytersCloneScale"
	bs.Scale = 1
	b.MouseEnter:Connect(function() if __mytersElev then __mytersElev() end;
		b.BackgroundColor3 = primary and C.purple:Lerp(Color3.new(1,1,1), .20) or C.card
		tw(bs, {Scale = 1.03}, .1)
	end)
	b.MouseLeave:Connect(function() if __mytersElev then __mytersElev() end;
		b.BackgroundColor3 = primary and C.purple or C.surface
		tw(bs, {Scale = 1}, .12)
	end)
	b.InputBegan:Connect(function(i) if __mytersElev then __mytersElev() end;
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			tw(bs, {Scale = .95}, .06)
		end
	end)
	b.InputEnded:Connect(function(i) if __mytersElev then __mytersElev() end;
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			tw(bs, {Scale = 1.03}, .08)
		end
	end)
	__mytersWearBootYield()
	return b
end

-- Iconos vectoriales (la fuente Gotham no tiene ▸ ▾ ↻ y salian como cuadros)
local function iconBar(h, rot, len, thick, ox, oy, col)
	local f = Instance.new("Frame", h)
	f.AnchorPoint = Vector2.new(.5, .5); f.Position = UDim2.new(.5, ox, .5, oy)
	f.Size = UDim2.fromOffset(len, thick); f.Rotation = rot
	f.BackgroundColor3 = col; f.BorderSizePixel = 0; f.ZIndex = h.ZIndex; f.Active = false
	local uc = Instance.new("UICorner", f); uc.CornerRadius = UDim.new(1, 0)
	return f
end
local function iconHolder(b, name)
	local h = Instance.new("Frame")
	h.Name = name; h.BackgroundTransparency = 1; h.BorderSizePixel = 0; h.Active = false
	h.AnchorPoint = Vector2.new(.5, .5); h.Position = UDim2.fromScale(.5, .5)
	h.Size = UDim2.fromOffset(12, 12); h.ZIndex = b.ZIndex + 1
	h.Parent = b
	b.Text = ""
	return h
end
local function recolorIcon(b, h)
	local function paint()
		for _, d in ipairs(h:GetDescendants()) do
			if d:IsA("Frame") then d.BackgroundColor3 = b.TextColor3 end
			if d:IsA("UIStroke") then d.Color = b.TextColor3 end
		end
	end
	paint()
	b:GetPropertyChangedSignal("TextColor3"):Connect(function() if __mytersElev then __mytersElev() end; pcall(paint) end)
end
local function setChevron(b, expanded)
	local h = b:FindFirstChild("MytersChevron")
	if h then h.Rotation = expanded and 90 or 0 end
end
local function makeChevron(b, expanded)
	local h = iconHolder(b, "MytersChevron")
	iconBar(h, 45, 6, 2, -0.5, -2.5, b.TextColor3)
	iconBar(h, -45, 6, 2, -0.5, 2.5, b.TextColor3)
	recolorIcon(b, h)
	h.Rotation = expanded and 90 or 0
end
local function makeRefresh(b)
	local h = iconHolder(b, "MytersRefreshIcon")
	local ring = Instance.new("Frame", h)
	ring.AnchorPoint = Vector2.new(.5, .5); ring.Position = UDim2.fromScale(.5, .5)
	ring.Size = UDim2.fromOffset(11, 11); ring.BackgroundTransparency = 1; ring.BorderSizePixel = 0; ring.ZIndex = h.ZIndex
	local rc = Instance.new("UICorner", ring); rc.CornerRadius = UDim.new(1, 0)
	local rs = Instance.new("UIStroke", ring); rs.Thickness = 1.6; rs.Color = b.TextColor3
	iconBar(h, 45, 4, 4, 4.5, -4.5, b.TextColor3)
	recolorIcon(b, h)
end

local compact = MytersIsTouch
local cloneViewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1100, 700)
local PW = compact and math.min(420, math.max(280, math.floor(cloneViewport.X * .92))) or math.max(360, math.min(620, math.floor(cloneViewport.X * .90)))
local PH = compact and math.min(560, math.max(360, math.floor(cloneViewport.Y * .72))) or math.max(300, math.min(430, math.floor(math.min(PW * 630 / 980, cloneViewport.Y * .88))))
local MIN_SCALE = compact and .60 or .72
local MAX_SCALE = compact and .98 or 1.22
local CARD_W = PW - 20
local savedScale = math.clamp(tonumber(UIstate.cloneScale) or 1, MIN_SCALE, MAX_SCALE)

local gui = Instance.new("ScreenGui")
gui.Name = "MytersCloneUI"
pcall(function() if _G.MytersRegisterI18nRoot then _G.MytersRegisterI18nRoot(gui) end end)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100001
gui.Enabled = false
pcall(function() gui.Parent = CoreGui end)
pcall(function() if _G.MytersRegisterUIFontRoot then _G.MytersRegisterUIFontRoot(gui) end end)

local panel = Instance.new("Frame", gui)
panel.Name = "MytersCloneWindow"
panel.AnchorPoint = Vector2.new(.5, .5)
panel.Position = UDim2.fromScale(.5, .5)
panel.Size = UDim2.fromOffset(PW, PH)
panel.BackgroundColor3 = Color3.fromRGB(18,18,20)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Active = true
panel.Visible = false
panel.ZIndex = 210
panel:SetAttribute("MytersMiniWindow", true)
corner(panel, 20)
local pStroke = stroke(panel, C.purpleSoft, 1)
pStroke.Thickness = 1.2
if _G.MytersMiniBindWindow then _G.MytersMiniBindWindow("MytersClonePanel", panel) end
local pg = Instance.new("UIGradient", panel)
pg.Color = ColorSequence.new(Color3.fromRGB(18,18,20), Color3.fromRGB(18,18,20))
pg.Rotation = 135
pg.Transparency = NumberSequence.new(0)
local pScale = Instance.new("UIScale", panel)
pScale.Name = "MytersCloneWindowScale"
pScale.Scale = savedScale

-- ── Header ──
local header = Instance.new("Frame", panel)
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = C.surface
header.BackgroundTransparency = 0
header.BorderSizePixel = 0
header.ZIndex = 60
header.ClipsDescendants = true
corner(header, 20)
local headerSquareFill = Instance.new("Frame", header)
headerSquareFill.Position = UDim2.fromOffset(0, 20)
headerSquareFill.Size = UDim2.new(1, 0, 1, -20)
headerSquareFill.BackgroundColor3 = C.surface
headerSquareFill.BorderSizePixel = 0
local dot = Instance.new("Frame", header)
dot.Position = UDim2.fromOffset(16, 24)
dot.Size = UDim2.fromOffset(6, 6)
dot.BackgroundColor3 = C.purple
dot.BorderSizePixel = 0
corner(dot, 3)
lbl(header, "CLIX CLONE", UDim2.fromOffset(30, 9), UDim2.new(1, -80, 0, 21), C.text, Enum.Font.GothamBold, 14)
lbl(header, "CLONAR AVATAR DE JUGADORES DEL SERVIDOR", UDim2.fromOffset(30, 31), UDim2.new(1, -80, 0, 14), C.muted, Enum.Font.GothamMedium, 8)
local closeBtn = btn(header, "×", UDim2.new(1, -42, 0, 14), UDim2.fromOffset(26, 26), false)
pcall(mytersXIcon, closeBtn)
closeBtn.TextSize = 15
closeBtn.ZIndex = 65

-- ── Toolbar (buscar + refrescar) ──
local bar = Instance.new("Frame", panel)
bar.Position = UDim2.fromOffset(0, 56)
bar.Size = UDim2.new(1, 0, 0, 38)
bar.BackgroundColor3 = C.surface
bar.BackgroundTransparency = 0
bar.BorderSizePixel = 0
bar.ZIndex = 60
local barLine = Instance.new("Frame", bar)
barLine.Position = UDim2.new(0, 0, 1, -1)
barLine.Size = UDim2.new(1, 0, 0, 1)
barLine.BackgroundColor3 = C.border
barLine.BorderSizePixel = 0
local search = Instance.new("TextBox", bar)
search.Position = UDim2.fromOffset(12, 6)
search.Size = UDim2.new(1, -92, 0, 26)
search.BackgroundColor3 = C.input
search.BorderSizePixel = 0
search.ClearTextOnFocus = false
search.PlaceholderText = "Buscar jugador..."
search.Text = tostring(UIstate.cloneSearch or "")
search.TextColor3 = C.text
search.PlaceholderColor3 = C.faint
search.TextSize = 11
search.Font = Enum.Font.GothamMedium
search.TextXAlignment = Enum.TextXAlignment.Left
corner(search, 6)
stroke(search, C.border, .2)
do local sp = Instance.new("UIPadding", search); sp.PaddingLeft = UDim.new(0, 9); sp.PaddingRight = UDim.new(0, 6) end
local refreshBtn = btn(bar, "", UDim2.new(1, -40, 0, 6), UDim2.fromOffset(28, 26), false)
refreshBtn.TextSize = 15
makeRefresh(refreshBtn)

-- ── Filtros (qué partes clonar) ──
local FILTERS = {
	{ key = "all",     label = "Todo" },
	{ key = "clothes", label = "Ropa" },
	{ key = "acc",     label = "Accesorios" },
	{ key = "hair",    label = "Pelo" },
	{ key = "head",    label = "Cabeza/Cara" },
	{ key = "legs",    label = "Piernas" },
	{ key = "body",    label = "Cuerpo" },
}
-- Forward declarations: el loop de filtros ya dispara refreshSummaries()
-- y las filas necesitan refreshRowHeight / updateCanvas.
local refreshSummaries
UIstate.cloneSel = UIstate.cloneSel or { clothes = true, acc = true, hair = true, head = true, legs = true, body = true }
local filterScroll = Instance.new("ScrollingFrame", panel)
filterScroll.Position = UDim2.fromOffset(10, 96)
filterScroll.Size = UDim2.new(1, -20, 0, 28)
filterScroll.BackgroundTransparency = 1
filterScroll.BorderSizePixel = 0
filterScroll.ScrollingDirection = Enum.ScrollingDirection.X
filterScroll.ScrollingEnabled = true
filterScroll.Active = true
filterScroll.ScrollBarThickness = 3
filterScroll.ScrollBarImageColor3 = C.purple
filterScroll.ScrollBarImageTransparency = .35
filterScroll.CanvasSize = UDim2.fromOffset(#FILTERS * 76, 0)
local filterBtns = {}
local function anyFilter()
	local s = UIstate.cloneSel
	return s.clothes or s.acc or s.hair or s.head or s.legs or s.body
end
local function paintFilters()
	for k, b in pairs(filterBtns) do
		local on = (k == "all") and anyFilter() or (UIstate.cloneSel[k] == true)
		b:SetAttribute("MytersMiniThemeSelected", on)
		b.BackgroundColor3 = on and C.toggleOn or C.toggleOff
		b.TextColor3 = on and C.text or C.muted
	end
end
for i, f in ipairs(FILTERS) do
	local b = btn(filterScroll, f.label, UDim2.fromOffset(0, 0), UDim2.fromOffset(70, 26), f.key == "all")
	b.TextSize = 10
	b.LayoutOrder = i
	b:SetAttribute("MytersMiniThemeRole", "toggleState")
	b:SetAttribute("MytersMiniThemeSelected", f.key == "all")
	filterBtns[f.key] = b
	b.MouseButton1Click:Connect(function() if __mytersElev then __mytersElev() end;
		if f.key == "all" then
			for _, k in ipairs({"clothes","acc","hair","head","legs","body"}) do
				UIstate.cloneSel[k] = true
			end
		else
			UIstate.cloneSel[f.key] = not (UIstate.cloneSel[f.key] == true)
		end
		paintFilters()
		refreshSummaries()
	end)
end
paintFilters()

-- ── Barra de estado ──
local status = Instance.new("Frame", panel)
status.Position = UDim2.fromOffset(10, 128)
status.Size = UDim2.new(1, -20, 0, 30)
status.BackgroundColor3 = C.surface
status.BackgroundTransparency = 0
status.BorderSizePixel = 0
corner(status, 7)
stroke(status, C.border, .3)
local sDot = Instance.new("Frame", status)
sDot.Position = UDim2.fromOffset(12, 12)
sDot.Size = UDim2.fromOffset(6, 6)
sDot.BackgroundColor3 = C.faint
sDot.BorderSizePixel = 0
corner(sDot, 3)
local sText = lbl(status, "Listo.", UDim2.fromOffset(26, 0), UDim2.new(1, -36, 1, 0), C.muted, Enum.Font.GothamMedium, 10)
sText.TextYAlignment = Enum.TextYAlignment.Center
local function setStatus(t, ok)
	sText.Text = tostring(t or "")
	if ok == true then
		sText.TextColor3 = C.green; sDot.BackgroundColor3 = C.green
	elseif ok == false then
		sText.TextColor3 = C.red; sDot.BackgroundColor3 = C.red
	else
		sText.TextColor3 = C.muted; sDot.BackgroundColor3 = C.faint
	end
end

-- ── Footer ──
local foot = Instance.new("Frame", panel)
foot.Position = UDim2.new(0, 0, 1, -40)
foot.Size = UDim2.new(1, 0, 0, 40)
foot.BackgroundColor3 = C.surface
foot.BackgroundTransparency = 0
foot.BorderSizePixel = 0
foot.ZIndex = 60
corner(foot, 20)
local footSquareFill = Instance.new("Frame", foot)
footSquareFill.Size = UDim2.new(1, 0, 0, 20)
footSquareFill.BackgroundColor3 = C.surface
footSquareFill.BorderSizePixel = 0
local footLine = Instance.new("Frame", foot)
footLine.Size = UDim2.new(1, 0, 0, 1)
footLine.BackgroundColor3 = C.border
footLine.BorderSizePixel = 0
UIstate.cloneClean = UIstate.cloneClean ~= false
local cleanLbl = lbl(foot, "Limpiar antes", UDim2.fromOffset(14, 0), UDim2.fromOffset(88, 40), C.muted, Enum.Font.GothamMedium, 10)
cleanLbl.TextYAlignment = Enum.TextYAlignment.Center
local cleanBtn = btn(foot, UIstate.cloneClean and "ON" or "OFF", UDim2.fromOffset(104, 7), UDim2.fromOffset(40, 26), UIstate.cloneClean)
cleanBtn.TextSize = 10
cleanBtn.Text = ""
cleanBtn:SetAttribute("MytersMiniThemeRole", "toggleState")
cleanBtn:SetAttribute("MytersMiniThemeSelected", UIstate.cloneClean)
local cleanStateText = Instance.new("TextLabel")
cleanStateText.Name = "MytersCloneStateLabel"
cleanStateText.BackgroundTransparency = 1
cleanStateText.BorderSizePixel = 0
cleanStateText.Size = UDim2.fromScale(1, 1)
cleanStateText.Position = UDim2.fromScale(0, 0)
cleanStateText.Font = Enum.Font.GothamBold
cleanStateText.Text = UIstate.cloneClean and "ON" or "OFF"
cleanStateText.TextColor3 = C.text
cleanStateText.TextSize = 10
cleanStateText.TextXAlignment = Enum.TextXAlignment.Center
cleanStateText.TextYAlignment = Enum.TextYAlignment.Center
cleanStateText.TextTransparency = 0
cleanStateText.Active = false
cleanStateText.ZIndex = cleanBtn.ZIndex + 1
cleanStateText.Parent = cleanBtn
cleanBtn.MouseButton1Click:Connect(function() if __mytersElev then __mytersElev() end;
	UIstate.cloneClean = not UIstate.cloneClean
	cleanBtn:SetAttribute("MytersMiniThemeSelected", UIstate.cloneClean)
	cleanStateText.Text = UIstate.cloneClean and "ON" or "OFF"
	cleanStateText.TextColor3 = C.text
	cleanBtn.BackgroundColor3 = UIstate.cloneClean and C.toggleOn or C.toggleOff
	cleanBtn.TextColor3 = UIstate.cloneClean and C.text or C.muted
end)
local saveLookBtn = btn(foot, "Guardar look", UDim2.new(1, -134, 0, 7), UDim2.fromOffset(110, 26), false)
saveLookBtn.TextSize = 10

-- ── Lista de jugadores ──
local list = Instance.new("ScrollingFrame", panel)
list.Name = "MytersCloneList"
list.Position = UDim2.fromOffset(10, 162)
list.Size = UDim2.new(1, -20, 1, -206)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollingEnabled = true
list.Active = true
list.ScrollBarThickness = compact and 3 or 4
list.ScrollBarImageColor3 = C.purple
list.ScrollBarImageTransparency = .1
list.CanvasSize = UDim2.fromOffset(0, 0)
list.ZIndex = 55
list.ClipsDescendants = true
local listLayout = Instance.new("UIListLayout", list)
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
local emptyLabel = lbl(list, "No hay jugadores para mostrar.", UDim2.fromOffset(10, 18), UDim2.new(1, -20, 0, 40), C.faint, Enum.Font.GothamMedium, 10)
emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
emptyLabel.LayoutOrder = 10000
emptyLabel.Visible = false

local entries = {}
local function updateCanvas()
	local h = 0
	for _, e in ipairs(entries) do
		h = h + e.card.Size.Y.Offset + 8
	end
	list.CanvasSize = UDim2.fromOffset(0, h)
end

-- ══════════════════════════════════════════════════════════════
-- MAPEO DE CAMPOS DE HumanoidDescription → método de MytersWear
-- typeId coincide con el TYPE_MAP que ya usa el módulo Avatar.
-- ══════════════════════════════════════════════════════════════
local LABELS = {
	Shirt = "Camisa", Pants = "Pantalón", GraphicTShirt = "T-Shirt",
	Head = "Cabeza", Face = "Cara",
	HatAccessory = "Acc. Cabeza", FaceAccessory = "Acc. Cara", NeckAccessory = "Acc. Cuello",
	ShouldersAccessory = "Acc. Hombros", FrontAccessory = "Acc. Frontal", BackAccessory = "Acc. Espalda",
	WaistAccessory = "Acc. Cintura", HairAccessory = "Pelo",
	TShirtAccessory = "Capa T-Shirt", ShirtAccessory = "Capa Camisa", PantsAccessory = "Capa Pantalón",
	JacketAccessory = "Chaqueta", SweaterAccessory = "Jersey", ShortsAccessory = "Shorts",
	DressSkirtAccessory = "Falda", LeftShoeAccessory = "Zap. Izq.", RightShoeAccessory = "Zap. Der.",
	EyebrowAccessory = "Cejas", EyelashAccessory = "Pestañas",
	Torso = "Torso", LeftArm = "Brazo Izq.", RightArm = "Brazo Der.",
	LeftLeg = "Pierna Izq.", RightLeg = "Pierna Der.",
}
-- El orden importa: primero ropa y cabeza, luego pelo/accesorios,
-- y las piernas al final (re-aplican malla tras todo lo demás).
local GROUP_ORDER = { "clothes", "head", "hair", "acc", "body", "legs" }
local FIELD_MAP = {
	{ field = "Shirt",            typeId = 11, group = "clothes" },
	{ field = "Pants",            typeId = 12, group = "clothes" },
	{ field = "GraphicTShirt",    typeId = 2,  group = "clothes" },
	{ field = "TShirtAccessory",  typeId = 61, group = "clothes" },
	{ field = "ShirtAccessory",   typeId = 62, group = "clothes" },
	{ field = "PantsAccessory",   typeId = 63, group = "clothes" },
	{ field = "JacketAccessory",  typeId = 64, group = "clothes" },
	{ field = "SweaterAccessory", typeId = 65, group = "clothes" },
	{ field = "ShortsAccessory",  typeId = 66, group = "clothes" },
	{ field = "DressSkirtAccessory", typeId = 69, group = "clothes" },
	{ field = "Head",             typeId = 17, group = "head" },
	{ field = "Face",             typeId = 18, group = "head" },
	{ field = "HairAccessory",    typeId = 41, group = "hair" },
	{ field = "HatAccessory",     typeId = 8,  group = "acc" },
	{ field = "FaceAccessory",    typeId = 42, group = "acc" },
	{ field = "NeckAccessory",    typeId = 43, group = "acc" },
	{ field = "ShouldersAccessory", typeId = 44, group = "acc" },
	{ field = "FrontAccessory",   typeId = 45, group = "acc" },
	{ field = "BackAccessory",    typeId = 46, group = "acc" },
	{ field = "WaistAccessory",   typeId = 47, group = "acc" },
	{ field = "LeftShoeAccessory",  typeId = 67, group = "acc" },
	{ field = "RightShoeAccessory", typeId = 68, group = "acc" },
	{ field = "EyebrowAccessory",   typeId = 72, group = "acc" },
	{ field = "EyelashAccessory",   typeId = 73, group = "acc" },
	{ field = "Torso",            typeId = 27, group = "body" },
	{ field = "LeftArm",          typeId = 29, group = "body" },
	{ field = "RightArm",         typeId = 28, group = "body" },
	{ field = "LeftLeg",          typeId = 31, group = "legs" },
	{ field = "RightLeg",         typeId = 32, group = "legs" },
}

local function readField(desc, field)
	local ok, v = pcall(function() return desc[field] end)
	if not ok or v == nil then return nil end
	v = tostring(v)
	if v == "" or v == "0" then return nil end
	return v
end

local descCache = {}
local function getDesc(plr, force)
	if not plr then return nil end
	local now = os.clock()
	local c = descCache[plr]
	if not force and c and (now - c.at) < 6 then return c.desc end
	local desc = nil
	-- 1) Descripción viva del personaje (respeta lo que lleva puesto AHORA)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local ok, d = pcall(function()
			if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
			return hum.HumanoidDescription
		end)
		if ok and typeof(d) == "Instance" then
			for _, e in ipairs(FIELD_MAP) do
				if readField(d, e.field) then desc = d break end
			end
		end
	end
	-- 2) Fallback: avatar de la cuenta vía API
	if not desc and plr.UserId and plr.UserId > 0 then
		local ok2, d2 = pcall(function() return Players:GetHumanoidDescriptionFromUserId(plr.UserId) end)
		if ok2 and typeof(d2) == "Instance" then desc = d2 end
	end
	descCache[plr] = { desc = desc, at = now }
	return desc
end

-- Lee la descripción que está usando el personaje ahora mismo. A diferencia de
-- GetHumanoidDescriptionFromUserId, esto conserva cuerpo, escalas, colores,
-- cabeza y la ropa viva del avatar que está en el servidor.
local function getLiveDesc(plr)
	local char = plr and plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local ok, desc = pcall(function()
		if hum.GetAppliedDescription then return hum:GetAppliedDescription() end
		return hum.HumanoidDescription
	end)
	return ok and typeof(desc) == "Instance" and desc or nil
end

local BODY_COLOR_FIELDS = {
	"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
}

local function copyBodyColors(sourceChar, targetChar)
	local sourceColors = sourceChar and sourceChar:FindFirstChildOfClass("BodyColors")
	if not sourceColors or not targetChar then return false end
	local targetColors = targetChar:FindFirstChildOfClass("BodyColors")
	if not targetColors then
		targetColors = Instance.new("BodyColors")
		targetColors.Parent = targetChar
	end
	local copied = false
	for _, field in ipairs(BODY_COLOR_FIELDS) do
		local ok, value = pcall(function() return sourceColors[field] end)
		if ok and value ~= nil then
			pcall(function() targetColors[field] = value end)
			copied = true
		end
	end
	return copied
end

local function copyVisibleMytersWear(sourceChar, targetChar)
	-- Solo copia piezas explícitamente marcadas por MytersWear. La descripción
	-- completa ya crea la ropa normal y esto evita duplicar accesorios estándar.
	if not sourceChar or not targetChar then return 0 end
	local copied = 0
	for _, obj in ipairs(sourceChar:GetChildren()) do
		if (obj:IsA("Accessory") or obj:IsA("Hat") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic"))
			and obj:GetAttribute("MytersWear") == true then
			-- ApplyDescription ya pudo crear la ropa base. Para una pieza MytersWear
			-- del jugador fuente se elimina solo el duplicado de la misma ranura/id
			-- antes de copiarla, evitando dos camisas, pantalones o accesorios.
			for _, existing in ipairs(targetChar:GetChildren()) do
				local sameClothing = (obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic"))
					and obj.ClassName == existing.ClassName
				local sameWearId = obj:GetAttribute("MytersWearId") ~= nil
					and existing:GetAttribute("MytersWearId") == obj:GetAttribute("MytersWearId")
				local sameName = (obj:IsA("Accessory") or obj:IsA("Hat"))
					and existing.Name == obj.Name and existing:GetAttribute("MytersWear") == true
				if sameClothing or sameWearId or sameName then
					pcall(function() existing:Destroy() end)
				end
			end
			local ok, clone = pcall(function() return obj:Clone() end)
			if ok and clone then
				local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
				if clone:IsA("Accessory") and targetHum then
					pcall(function() targetHum:AddAccessory(clone) end)
					if not clone.Parent then clone.Parent = targetChar end
				else
					clone.Parent = targetChar
				end
				copied = copied + 1
			end
		end
	end
	return copied
end

local function applyExactAvatar(sourcePlr, targetChar, sourceDesc)
	local sourceChar = sourcePlr and sourcePlr.Character
	local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
	if not sourceChar or not targetHum then return false, "falta Humanoid" end
	sourceDesc = sourceDesc or getLiveDesc(sourcePlr)
	if typeof(sourceDesc) ~= "Instance" then return false, "no se pudo leer la descripción viva" end

	local desc = sourceDesc
	local cloneOk, clonedDesc = pcall(function() return sourceDesc:Clone() end)
	if cloneOk and clonedDesc then desc = clonedDesc end
	local applyCallOk, applyResult = pcall(function()
		-- ApplyDescriptionClientServer no es una API pública válida.
		targetHum:ApplyDescriptionAsync(desc)
		return true
	end)
	if not applyCallOk then return false, tostring(applyResult) end
	if applyResult ~= true then return false, "ApplyDescriptionAsync no terminó correctamente" end

	-- Roblox puede reconstruir BodyColors un frame después de ApplyDescription;
	-- repetirlos aquí conserva el tono exacto del jugador fuente.
	task.wait(0.2)
	copyBodyColors(sourceChar, targetChar)
	copyVisibleMytersWear(sourceChar, targetChar)
	return true
end

local function collectGroups(desc)
	local sel = UIstate.cloneSel
	local out = {}
	if typeof(desc) ~= "Instance" then return out end
	for _, group in ipairs(GROUP_ORDER) do
		if sel[group] then
			for _, e in ipairs(FIELD_MAP) do
				if e.group == group then
					local raw = readField(desc, e.field)
					if raw then
						local ids = {}
						for v in raw:gmatch("%d+") do
							local n = tonumber(v)
							if n and n > 0 then table.insert(ids, n) end
						end
						if #ids > 0 then
							table.insert(out, { field = e.field, typeId = e.typeId, ids = ids })
						end
					end
				end
			end
		end
	end
	return out
end

local function summarize(desc)
	if typeof(desc) ~= "Instance" then return "sin avatar legible" end
	local sel = UIstate.cloneSel
	local parts = {}
	for _, e in ipairs(FIELD_MAP) do
		if sel[e.group] then
			local raw = readField(desc, e.field)
			if raw then
				local n = 0
				for _ in raw:gmatch("%d+") do n = n + 1 end
				if n > 0 then
					local nm = LABELS[e.field] or e.field
					table.insert(parts, (n > 1) and (nm .. " x" .. n) or nm)
				end
			end
		end
	end
	if #parts == 0 then return "sin piezas en los filtros activos" end
	return table.concat(parts, "  ·  ")
end

local function buildDetail(desc)
	if typeof(desc) ~= "Instance" then return "no se pudo leer el avatar" end
	local sel = UIstate.cloneSel
	local lines = {}
	for _, e in ipairs(FIELD_MAP) do
		if sel[e.group] then
			local raw = readField(desc, e.field)
			if raw then
				local ids = {}
				for v in raw:gmatch("%d+") do table.insert(ids, v) end
				if #ids > 0 then
					table.insert(lines, (LABELS[e.field] or e.field) .. ": " .. table.concat(ids, ", "))
				end
			end
		end
	end
	if #lines == 0 then return "sin piezas en los filtros activos" end
	return table.concat(lines, "\n")
end

local CARD_H = 96
local function refreshRowHeight(entry)
	local extra = 0
	if entry.expanded and entry.detailText and entry.detailText ~= "" then
		local perLine = math.max(18, math.floor((CARD_W - 28) / 4.3))
		local lines = math.min(8, math.max(1, math.ceil(#entry.detailText / perLine)))
		extra = lines * 11 + 10
		entry.detail.Visible = true
		entry.detail.Text = entry.detailText
		entry.detail.Size = UDim2.new(1, -24, 0, extra - 4)
	else
		entry.detail.Visible = false
	end
	entry.card.Size = UDim2.new(1, 0, 0, CARD_H + extra)
	updateCanvas()
end

local cloning = false
local function cloneFrom(entry)
	if cloning then return end
	local sel = UIstate.cloneSel
	if not anyFilter() then
		setStatus("Activa al menos un filtro.", false)
		return
	end
	if type(equipSingle) ~= "function" then
		setStatus("El módulo MytersWear aún no está listo.", false)
		return
	end
	local char = player.Character
	if not char then
		setStatus("No hay personaje activo.", false)
		return
	end
	local desc = getDesc(entry.plr, true)
	if not desc then
		setStatus("No se pudo leer el avatar de " .. entry.plr.DisplayName .. ".", false)
		return
	end
	cloning = true
	setStatus("Clonando " .. entry.plr.DisplayName .. " ...", nil)
	local cloneBtn = entry.cloneBtn
	if cloneBtn then cloneBtn.Text = "..." end
	local cloneGeneration = tonumber(mytersEnv.MytersSessionGeneration) or 0
	local function cloneCancelled()
		return mytersEnv.MytersCloneCancel == true or mytersEnv.MytersSessionClosed == true or rawget(_G, "MytersSessionClosed") == true
			or (tonumber(mytersEnv.MytersSessionGeneration) or 0) ~= cloneGeneration
	end
	if cloneCancelled() then cloning = false; return end
	mytersEnv.MytersClonePending = true
	task.spawn(function()
		local appearanceLock = mytersEnv.MytersCloneAppearance or {}
		mytersEnv.MytersCloneAppearance = appearanceLock
		appearanceLock.locked = true
		appearanceLock.sourceUserId = entry.plr.UserId
		local ok, err = pcall(function()
			if cloneCancelled() then return "cancelled" end
			local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
			if not hum then error("sin Humanoid") end
			if cloneCancelled() then return "cancelled" end

			-- Korblox/Headless de Player Anims es un overlay local. Se quita antes
			-- del clon para que no cambie la pierna o la cabeza recién aplicadas.
			local kh = mytersEnv.MytersKorbloxHeadlessControl
			if kh and type(kh.isEnabled) == "function" and kh.isEnabled() and type(kh.set) == "function" then
				pcall(kh.set, false)
			end

			-- Para un clon exacto siempre se parte del personaje limpio. Dejar el
			-- outfit anterior activo es lo que provocaba el choque con MytersWear.
			if type(restoreAll) == "function" then
				pcall(restoreAll, char)
				task.wait(0.25)
			end
			if cloneCancelled() then return "cancelled" end

			local allSelected = true
			for _, key in ipairs({"clothes", "acc", "hair", "head", "legs", "body"}) do
				if UIstate.cloneSel[key] ~= true then allSelected = false break end
			end

			-- Con "Todo" se aplica la HumanoidDescription viva completa: incluye
			-- color de piel, forma/escala corporal, cabeza, cara, ropa y accesorios.
			-- Los filtros parciales conservan el flujo antiguo por piezas.
			if allSelected then
				local live = getLiveDesc(entry.plr)
				local exact, exactErr = applyExactAvatar(entry.plr, char, live)
				if cloneCancelled() then return "cancelled" end
				if not exact then error(exactErr or "no se pudo aplicar el avatar completo") end
				if type(IW.recaptureOriginalOutfit) == "function" then
					pcall(IW.recaptureOriginalOutfit, char)
				end
				if persistMytersSession then pcall(persistMytersSession) end
				return "avatar completo"
			end

			local groups = collectGroups(desc)
			if #groups == 0 then
				error("no hay piezas aplicables con los filtros activos")
			end
			local done = 0
			for _, g in ipairs(groups) do
				if cloneCancelled() then return "cancelled" end
				for _, id in ipairs(g.ids) do
					if cloneCancelled() then return "cancelled" end
					local tid = g.typeId
					if apiProductInfo then
						local info = apiProductInfo(id)
						if info and normalizeAssetType then
							tid = normalizeAssetType(id, info.AssetTypeId, info) or g.typeId
						end
					end
					pcall(equipSingle, id, tid, char)
					done = done + 1
					task.wait(0.08)
				end
			end
			if persistMytersSession then pcall(persistMytersSession) end
			return done
		end)
		appearanceLock.locked = false
		appearanceLock.sourceUserId = nil
		mytersEnv.MytersClonePending = false
		if cloneCancelled() then cloning = false; return end
		task.wait(0.2)
		if cloneCancelled() then cloning = false; return end
		if runMytersDiagnostics then pcall(runMytersDiagnostics, char, true) end
		if ok then
			if type(err) == "number" then
				setStatus("Avatar de " .. entry.plr.DisplayName .. " clonado (" .. tostring(err) .. " piezas).", true)
			else
				setStatus("Avatar de " .. entry.plr.DisplayName .. " clonado: " .. tostring(err), true)
			end
		else
			setStatus("Clonado incompleto: " .. tostring(err), false)
		end
		cloning = false
		if cloneBtn and cloneBtn.Parent then
			cloneBtn.Text = "Clonar"
			cloneBtn.BackgroundColor3 = C.purple
		end
		refreshSummaries()
	end)
end

local function buildRow(plr, order)
	local entry = { plr = plr, expanded = false, detailText = "" }
	local card = Instance.new("Frame", list)
	card.Name = "CloneRow_" .. plr.Name
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, CARD_H)
	card.BackgroundColor3 = C.card
	card.BorderSizePixel = 0
	corner(card, 9)
	stroke(card, C.border, .25)
	entry.card = card

	local head = Instance.new("ImageLabel", card)
	head.Position = UDim2.fromOffset(10, 14)
	head.Size = UDim2.fromOffset(52, 52)
	head.BackgroundColor3 = C.input
	head.BorderSizePixel = 0
	head.ScaleType = Enum.ScaleType.Fit
	head.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(plr.UserId) .. "&w=150&h=150"
	corner(head, 8)

	local nm = lbl(card, plr.DisplayName, UDim2.fromOffset(72, 12), UDim2.new(1, -190, 0, 18), C.text, Enum.Font.GothamBold, 11)
	nm.TextTruncate = Enum.TextTruncate.AtEnd
	local un = lbl(card, "@" .. plr.Name, UDim2.fromOffset(72, 32), UDim2.new(1, -190, 0, 14), C.muted, Enum.Font.GothamMedium, 8)
	un.TextTruncate = Enum.TextTruncate.AtEnd
	local sum = lbl(card, "leyendo avatar...", UDim2.fromOffset(72, 50), UDim2.new(1, -190, 0, 16), C.faint, Enum.Font.GothamMedium, 8)
	sum.TextTruncate = Enum.TextTruncate.AtEnd
	entry.summary = sum

	local cloneBtn = btn(card, "Clonar", UDim2.new(1, -100, 0, 14), UDim2.fromOffset(88, 28), true)
	cloneBtn.TextSize = 10
	entry.cloneBtn = cloneBtn
	local moreBtn = btn(card, "", UDim2.new(1, -100, 0, 48), UDim2.fromOffset(88, 22), false)
	moreBtn.TextSize = 11
	makeChevron(moreBtn, false)
	entry.moreBtn = moreBtn

	local detail = lbl(card, "", UDim2.fromOffset(12, 70), UDim2.new(1, -24, 0, 0), C.muted, Enum.Font.Gotham, 8)
	detail.TextWrapped = true
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.Visible = false
	entry.detail = detail

	cloneBtn.MouseButton1Click:Connect(function() cloneFrom(entry) end)
	moreBtn.MouseButton1Click:Connect(function() if __mytersElev then __mytersElev() end;
		entry.expanded = not entry.expanded
		setChevron(moreBtn, entry.expanded)
		refreshRowHeight(entry)
	end)

	table.insert(entries, entry)
	return entry
end

refreshSummaries = function()
	for _, e in ipairs(entries) do
		task.spawn(function()
			local desc = getDesc(e.plr)
			if desc then
				e.detailText = buildDetail(desc)
				if e.summary and e.summary.Parent then
					e.summary.Text = summarize(desc)
				end
			else
				e.detailText = ""
				if e.summary and e.summary.Parent then
					e.summary.Text = "no se pudo leer su avatar"
				end
			end
			refreshRowHeight(e)
		end)
	end
end

local function refreshList()
	for _, e in ipairs(entries) do
		pcall(function() e.card:Destroy() end)
	end
	entries = {}
	local q = string.lower(tostring(search.Text or ""))
	UIstate.cloneSearch = search.Text
	local list0 = Players:GetPlayers()
	table.sort(list0, function(a, b)
		return tostring(a.DisplayName):lower() < tostring(b.DisplayName):lower()
	end)
	local n = 0
	for _, plr in ipairs(list0) do
		if plr ~= player then
			local hay = q == ""
				or string.find(string.lower(plr.DisplayName), q, 1, true) ~= nil
				or string.find(string.lower(plr.Name), q, 1, true) ~= nil
			if hay then
				n = n + 1
				buildRow(plr, n)
			end
		end
	end
	emptyLabel.Visible = (n == 0)
	updateCanvas()
	refreshSummaries()
	setStatus(n .. " jugador(es) en el servidor.", nil)
end

search:GetPropertyChangedSignal("Text"):Connect(function() if __mytersElev then __mytersElev() end;
	task.defer(refreshList)
end)
refreshBtn.MouseButton1Click:Connect(function() if __mytersElev then __mytersElev() end;
	descCache = {}
	refreshList()
	setStatus("Lista actualizada.", true)
end)

saveLookBtn.MouseButton1Click:Connect(function() if __mytersElev then __mytersElev() end;
	if type(avatarState) ~= "function" or type(savedAvatars) ~= "table" then
		setStatus("MytersWear aún no está listo.", false)
		return
	end
	local n = tostring(UIstate.cloneSaveName or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if n == "" then n = "Clone " .. os.date("%H:%M") end
	local state = avatarState()
	local idx = nil
	for i, v in ipairs(savedAvatars) do
		if tostring(v.name or "") == n then idx = i break end
	end
	if idx then
		savedAvatars[idx] = { name = n, state = state }
	else
		table.insert(savedAvatars, 1, { name = n, state = state })
	end
	while #savedAvatars > 20 do table.remove(savedAvatars) end
	mytersEnv.MytersSavedAvatars = savedAvatars
	if wearSaveAvatarsDisk then pcall(wearSaveAvatarsDisk) end
	if type(renderAvatars) == "function" then pcall(renderAvatars) end
	setStatus("Look guardado como '" .. n .. "'.", true)
end)

local conns = {}
conns[#conns + 1] = Players.PlayerAdded:Connect(function() if __mytersElev then __mytersElev() end;
	task.defer(refreshList)
end)
conns[#conns + 1] = Players.PlayerRemoving:Connect(function() if __mytersElev then __mytersElev() end;
	descCache = {}
	task.defer(refreshList)
end)

-- ── Arrastre de la ventana ──
local dragging = false
local dragStart, dragStartPos
header.InputBegan:Connect(function(i) if __mytersElev then __mytersElev() end;
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = i.Position
		dragStartPos = panel.Position
	end
end)
UIS.InputChanged:Connect(function(i) if __mytersElev then __mytersElev() end;
	if not dragging then return end
	if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
	local d = i.Position - dragStart
	panel.Position = UDim2.new(
		dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
		dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y
	)
end)
UIS.InputEnded:Connect(function(i) if __mytersElev then __mytersElev() end;
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- ── Handle de escala (esquina inferior derecha) ──
local resizing = false
local resizeStartX, resizeStartY, resizeStartScale
local resize = Instance.new("TextButton", panel)
resize.Name = "MytersCloneResizeHandle"
resize.AnchorPoint = Vector2.new(1, 1)
resize.Position = UDim2.new(1, -6, 1, -6)
resize.Size = UDim2.fromOffset(compact and 30 or 34, compact and 30 or 34)
resize.BackgroundTransparency = 1
resize.BorderSizePixel = 0
resize.Text = ""
resize.AutoButtonColor = false
resize.ZIndex = 70
resize:SetAttribute("MytersMiniResize", true)
resize.InputBegan:Connect(function(i) if __mytersElev then __mytersElev() end;
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStartX = i.Position.X
		resizeStartY = i.Position.Y
		resizeStartScale = pScale.Scale
	end
end)
UIS.InputChanged:Connect(function(i) if __mytersElev then __mytersElev() end;
	if not resizing then return end
	if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
	local dx = i.Position.X - resizeStartX
	local dy = i.Position.Y - resizeStartY
	pScale.Scale = math.clamp(resizeStartScale + (dx + dy) / 320, MIN_SCALE, MAX_SCALE)
end)
UIS.InputEnded:Connect(function(i) if __mytersElev then __mytersElev() end;
	if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and resizing then
		resizing = false
		UIstate.cloneScale = pScale.Scale
	end
end)

-- ── Abrir / cerrar ──
local function openClone()
	if not gui or not panel or not gui.Parent or not panel.Parent then return false end
	gui.Enabled = true
	panel.Visible = true
	local targetScale = math.clamp(tonumber(pScale.Scale) or 1, MIN_SCALE, MAX_SCALE)
	panel.BackgroundTransparency = 1
	pStroke.Transparency = 1
	panel.Size = UDim2.fromOffset(math.max(240, PW - 30), math.max(320, PH - 20))
	pScale.Scale = math.max(MIN_SCALE, targetScale * .92)
	tw(panel, { BackgroundTransparency = (_G.MytersMiniPanelT and _G.MytersMiniPanelT() or 0), Size = UDim2.fromOffset(PW, PH) }, .22)
	tw(pStroke, { Transparency = .35 }, .22)
	tw(pScale, { Scale = targetScale }, .22)
	refreshList()
	return true
end
local function closeClone()
	if not panel or not gui then return end
	local targetScale = math.clamp(tonumber(pScale.Scale) or 1, MIN_SCALE, MAX_SCALE)
	tw(panel, { BackgroundTransparency = 1, Size = UDim2.fromOffset(math.max(240, PW - 30), math.max(320, PH - 20)) }, .16)
	tw(pStroke, { Transparency = 1 }, .16)
	tw(pScale, { Scale = math.max(MIN_SCALE, targetScale * .92) }, .16)
	task.delay(.17, function()
		if panel and panel.Parent then panel.Visible = false end
		if gui and gui.Parent then gui.Enabled = false end
		if pScale and pScale.Parent then pScale.Scale = targetScale end
		UIstate.cloneScale = targetScale
	end)
end
closeBtn.MouseButton1Click:Connect(closeClone)

local releaseMytersCloneTheme
pcall(function()
	local register = rawget(_G, "MytersRegisterMiniTheme")
	if type(register) == "function" then releaseMytersCloneTheme = register("MytersCloneUI", gui, C) end
end)
mytersEnv.MytersCloneOpen = openClone
mytersEnv.MytersCloneClose = closeClone
mytersEnv.MytersCloneUI = gui
mytersEnv.MytersCloneCleanup = function()
	mytersEnv.MytersCloneCancel = true
	if releaseMytersCloneTheme then pcall(releaseMytersCloneTheme); releaseMytersCloneTheme = nil end
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	if gui and gui.Parent then pcall(function() gui:Destroy() end) end
	if mytersEnv.MytersCloneUI == gui then mytersEnv.MytersCloneUI = nil end
	mytersEnv.MytersCloneOpen = nil
end

-- Montar la lista una vez para que al abrir no haya un frame vacío.
task.defer(refreshList)
end
__buildMytersCloneUI()



]==]

do
ClixWearLoad = function()
    local env = (getgenv and getgenv()) or _G
    local open = env.MytersWearOpen or rawget(_G, "MytersWearOpen")
    if type(open) == "function" then
        local ok, opened = pcall(open)
        if ok and opened == true then return true end
        local staleCleanup = env.MytersWearCleanup or rawget(_G, "MytersWearCleanup")
        if type(staleCleanup) == "function" then pcall(staleCleanup) end
    end
    local candidates = { "clix_wear.lua", "Clix/clix_wear.lua", "scripts/clix_wear.lua" }
    local source = clixWearEmbeddedSource
    for _, path in ipairs(candidates) do
        if not source and isfile and readfile and isfile(path) then source = readfile(path); break end
    end
    if type(source) ~= "string" or source == "" then
        if win then win:Notify("Clix Wear module not found", 3) end
        return false
    end
    local chunk, err = loadstring(source)
    if not chunk then
        if win then win:Notify("Clix Wear failed to compile", 3) end
        warn(tostring(err))
        return false
    end
    local ok, runErr = pcall(chunk)
    if not ok then
        if win then win:Notify("Clix Wear failed to load", 3) end
        warn(tostring(runErr))
        return false
    end
    env = (getgenv and getgenv()) or _G
    open = env.MytersWearOpen or rawget(_G, "MytersWearOpen")
    if type(open) == "function" then
        local openedOk, opened = pcall(open)
        if openedOk and opened == true then return true end
    end
    if win then win:Notify("Clix Wear loaded without an open panel", 3) end
    return false
end
clixWearTab = win:CreateTab("Clix Wear")
clixWearSubTab = clixWearTab:CreateSubTab("Wear")
clixWearCols = clixWearSubTab:CreateColumns("Clix Wear", "Actions")
clixWearCols.left:AddLabel({ Label = "Clothing, accessories and saved avatars." })
clixWearCols.right:AddButton({ Label = "Open Clix Wear", Callback = ClixWearLoad })
clixWearCols.right:AddButton({ Label = "Close Clix Wear", Callback = function()
    local wearEnv = (getgenv and getgenv()) or _G
    local close = wearEnv.MytersWearClose or rawget(_G, "MytersWearClose") or wearEnv.MytersWearCleanup or rawget(_G, "MytersWearCleanup")
    if type(close) == "function" then close() end
end })
clixWearCols.right:AddButton({ Label = "Restore Wear", Callback = function()
    local wearEnv = (getgenv and getgenv()) or _G
    local restore = wearEnv.MytersWearRestore or rawget(_G, "MytersWearRestore")
    if type(restore) == "function" then restore() else ClixWearLoad() end
end })

local animTab = win:CreateTab("Animations")
local packsSubTab = animTab:CreateSubTab("Packs")
local avatarSubTab = animTab:CreateSubTab("Avatar")

local packCols = packsSubTab:CreateColumns("Packs 3D", "Custom Slots")
local packLeft = packCols.left
local packRight = packCols.right

local avatarCols = avatarSubTab:CreateColumns("Korblox & Headless", "Avatar Copier")
local avatarLeft = avatarCols.left
local avatarRight = avatarCols.right

local ANIM_PACKS = {
    ["Old School"] = { idle1="10921230744", idle2="10921232093", walk="10921244891", run="10921240218", jump="10921242013", climb="10921229866", fall="10921241244", swim="10921243048", swimIdle="10921244018" },
    ["Adidas Sports"] = { idle1="18537376492", idle2="18537371272", walk="18537392113", run="18537384940", jump="18537380791", climb="18537363391", fall="18537367238", swim="18537389531", swimIdle="18537387180" },
    ["Adidas Community"] = { idle1="122257458498464", idle2="102357151005774", walk="122150855457006", run="82598234841035", jump="75290611992385", climb="88763136693023", fall="98600215928904", swim="133308483266208", swimIdle="109346520324160" },
    ["Adidas Aura"] = { idle1="110211186840347", idle2="114191137265065", walk="83842218823011", run="118320322718866", jump="109996626521204", climb="97824616490448", fall="95603166884636", swim="134530128383903", swimIdle="94922130551805" },
    ["Wicked Popular"] = { idle1="118832222982049", idle2="76049494037641", walk="92072849924640", run="72301599441680", jump="104325245285198", climb="131326830509784", fall="121152442762481", swim="99384245425157", swimIdle="113199415118199" },
    ["Elder"] = { idle1="10921101664", idle2="10921102574", walk="10921111375", run="10921104374", jump="10921107367", climb="10921100400", fall="10921105765", swim="10921108971", swimIdle="10921110146" },
    ["Zombie"] = { idle1="10921344533", idle2="10921345304", walk="10921355261", run="616163682", jump="10921351278", climb="10921343576", fall="10921350320", swim="10921352344", swimIdle="10921353442" },
    ["Mage"] = { idle1="10921144709", idle2="10921145797", walk="10921152678", run="10921148209", jump="10921149743", climb="10921143404", fall="10921148939", swim="10921150788", swimIdle="10921151661" },
    ["Catwalk Glam"] = { idle1="133806214992291", idle2="94970088341563", walk="109168724482748", run="81024476153754", jump="116936326516985", climb="119377220967554", fall="92294537340807", swim="134591743181628", swimIdle="98854111361360" },
    ["Astronaut"] = { idle1="10921034824", idle2="10921036806", walk="10921046031", run="10921039308", jump="10921042494", climb="10921032124", fall="10921040576", swim="10921044000", swimIdle="10921045006" },
    ["Wicked Dancing Through Life"] = { idle1="92849173543269", idle2="132238900951109", walk="73718308412641", run="135515454877967", jump="78508480717326", climb="129447497744818", fall="78147885297412", swim="110657013921774", swimIdle="129183123083281" },
    ["Werewolf"] = { idle1="10921330408", idle2="10921333667", walk="10921342074", run="10921336997", climb="10921329322", fall="10921337907", swim="10921340419", swimIdle="10921341319" },
    ["Superhero"] = { idle1="10921288909", idle2="10921290167", walk="10921298616", run="10921291831", jump="10921294559", climb="10921286911", fall="10921293373", swim="10921295495", swimIdle="10921297391" },
    ["Toy"] = { idle1="10921301576", walk="10921312010", run="10921306285", jump="10921308158", climb="10921300839", fall="10921307241", swim="10921309319", swimIdle="10921310341" },
    ["No Boundaries"] = { idle1="18747067405", idle2="18747063918", walk="18747074203", run="18747070484", jump="18747069148", climb="18747060903", fall="18747062535", swim="18747073181", swimIdle="18747071682" },
    ["NFL"] = { idle1="92080889861410", idle2="74451233229259", walk="110358958299415", run="117333533048078", jump="119846112151352", climb="134630013742019", fall="129773241321032", swim="132697394189921", swimIdle="79090109939093" },
    ["Amazon Unboxed"] = { idle1="98281136301627", walk="90478085024465", run="134824450619865", jump="121454505477205", climb="121145883950231", fall="94788218468396", swim="105962919001086", swimIdle="129126268464847" },
    ["Vampire"] = { idle1="10921315373", walk="10921326949", run="10921320299", jump="10921322186", climb="10921314188", fall="10921321317", swim="10921324408", swimIdle="10921325443" },
    ["Ninja"] = { idle1="656117400", idle2="656118341", walk="656121766", run="656118852", jump="656117878", climb="656114359", fall="656115606", swim="656119721", swimIdle="656121397" },
    ["Robot"] = { idle1="616088211", idle2="616089559", walk="616095330", run="616091570", jump="616090535", climb="616086039", fall="616087089", swim="616092998", swimIdle="616094091" },
    ["Levitation"] = { idle1="616006778", idle2="616008087", walk="616013216", run="616010382", jump="616008936", climb="616003713", fall="616005863", swim="616011509", swimIdle="616012453" },
    ["Stylish"] = { idle1="616136790", idle2="616138447", walk="616146177", run="616140816", jump="616139451", climb="616133594", fall="616134815", swim="616143378", swimIdle="616144772" },
    ["Bubbly"] = { idle1="910004836", idle2="910009958", walk="910034870", run="910025107", jump="910016857", climb="909997997", fall="910001910", swim="910028158", swimIdle="910030921" },
    ["Cartoon"] = { idle1="742637544", idle2="742638445", walk="742640026", run="742638842", jump="742637942", climb="742636889", fall="742637151", swim="742639220", swimIdle="742639812" },
}

local DEFAULT_ANIMS = {
    idle1 = "rbxassetid://507766666",
    idle2 = "rbxassetid://507766951",
    walk = "rbxassetid://507777826",
    run = "rbxassetid://507767714",
    jump = "rbxassetid://507765000",
    climb = "rbxassetid://507765644",
    fall = "rbxassetid://507767968",
    swim = "rbxassetid://913384386",
    swimIdle = "rbxassetid://913376220",
}

local PACK_THUMBNAILS = {
    ["Old School"] = "rbxthumb://type=BundleThumbnail&id=667&w=150&h=150",
    ["Adidas Sports"] = "rbxthumb://type=BundleThumbnail&id=427999&w=150&h=150",
    ["Adidas Community"] = "rbxthumb://type=BundleThumbnail&id=2623795&w=150&h=150",
    ["Adidas Aura"] = "rbxthumb://type=BundleThumbnail&id=4294795&w=150&h=150",
    ["Wicked Popular"] = "rbxthumb://type=BundleThumbnail&id=1189398&w=150&h=150",
    ["Elder"] = "rbxthumb://type=BundleThumbnail&id=48&w=150&h=150",
    ["Zombie"] = "rbxthumb://type=BundleThumbnail&id=80&w=150&h=150",
    ["Mage"] = "rbxthumb://type=BundleThumbnail&id=63&w=150&h=150",
    ["Catwalk Glam"] = "rbxthumb://type=BundleThumbnail&id=1601900&w=150&h=150",
    ["Astronaut"] = "rbxthumb://type=BundleThumbnail&id=34&w=150&h=150",
    ["Wicked Dancing Through Life"] = "rbxthumb://type=BundleThumbnail&id=4128695&w=150&h=150",
    ["Werewolf"] = "rbxthumb://type=BundleThumbnail&id=32&w=150&h=150",
    ["Superhero"] = "rbxthumb://type=BundleThumbnail&id=81&w=150&h=150",
    ["Toy"] = "rbxthumb://type=BundleThumbnail&id=43&w=150&h=150",
    ["No Boundaries"] = "rbxthumb://type=BundleThumbnail&id=455003&w=150&h=150",
    ["NFL"] = "rbxthumb://type=BundleThumbnail&id=932296&w=150&h=150",
    ["Amazon Unboxed"] = "rbxthumb://type=BundleThumbnail&id=4164795&w=150&h=150",
    ["Vampire"] = "rbxthumb://type=BundleThumbnail&id=33&w=150&h=150",
    ["Ninja"] = "rbxthumb://type=BundleThumbnail&id=75&w=150&h=150",
    ["Robot"] = "rbxthumb://type=BundleThumbnail&id=82&w=150&h=150",
    ["Levitation"] = "rbxthumb://type=BundleThumbnail&id=79&w=150&h=150",
    ["Stylish"] = "rbxthumb://type=BundleThumbnail&id=83&w=150&h=150",
    ["Bubbly"] = "rbxthumb://type=BundleThumbnail&id=39&w=150&h=150",
    ["Cartoon"] = "rbxthumb://type=BundleThumbnail&id=56&w=150&h=150",
}

local PACK_OPTIONS = {}
for name in pairs(ANIM_PACKS) do
    table.insert(PACK_OPTIONS, name)
end
table.sort(PACK_OPTIONS)

local SLOT_OPTIONS = { "None" }
for _, name in ipairs(PACK_OPTIONS) do
    table.insert(SLOT_OPTIONS, name)
end
table.insert(PACK_OPTIONS, 1, "None")

local AnimState = {
    enabled = false,
    fullPack = "None",
    slots = {
        idle = "None",
        walk = "None",
        run = "None",
        jump = "None",
        fall = "None",
        climb = "None",
        swim = "None"
    },
    korbloxHeadless = false,
    korbloxMode = "both",
}

local sessionOriginals = nil
local originalsByChar = setmetatable({}, {__mode = "k"})
local animBusy = false
local animApplied = false

local function getAnimate(char)
    return char and char:FindFirstChild("Animate")
end

local function idNum(id)
    if not id then return nil end
    return tostring(id):match("(%d+)")
end

local function grabFromAnimate(animate)
    local o = {}
    local function grab(folder, child)
        local f = animate:FindFirstChild(folder)
        if not f then return nil end
        local a = f:FindFirstChild(child)
        if a and a:IsA("Animation") then return a.AnimationId end
        for _, c in ipairs(f:GetChildren()) do
            if c:IsA("Animation") then return c.AnimationId end
        end
        return nil
    end
    pcall(function()
        o.idle1 = grab("idle", "Animation1")
        o.idle2 = grab("idle", "Animation2")
        o.walk = grab("walk", "WalkAnim")
        o.run = grab("run", "RunAnim")
        o.jump = grab("jump", "JumpAnim")
        o.climb = grab("climb", "ClimbAnim")
        o.fall = grab("fall", "FallAnim")
        o.swim = grab("swim", "Swim")
        o.swimIdle = grab("swim", "SwimIdle")
    end)
    for k, def in pairs(DEFAULT_ANIMS) do
        if not idNum(o[k]) then o[k] = def end
    end
    return o
end

local function cacheOriginal(char, force)
    if not char then return end
    local animate = getAnimate(char)
    if not animate then return end
    if sessionOriginals and not force then
        originalsByChar[char] = sessionOriginals
        return
    end
    if not force and originalsByChar[char] and originalsByChar[char]._clean then
        return
    end
    local o = grabFromAnimate(animate)
    o._clean = true
    sessionOriginals = o
    originalsByChar[char] = sessionOriginals
end

local function getOriginals(char)
    if sessionOriginals then return sessionOriginals end
    if char and originalsByChar[char] then return originalsByChar[char] end
    local o = {}
    for k, def in pairs(DEFAULT_ANIMS) do o[k] = def end
    o._clean = true
    return o
end

local function updateAnimId(animate, folderName, animName, animId)
    if not animId then return false end
    local id = tostring(animId):match("%d+")
    if not id then return false end
    local folder = animate:FindFirstChild(folderName)
        or animate:FindFirstChild(folderName:gsub("^%l", string.upper) .. "Anim")
        or animate:FindFirstChild(string.upper(folderName))
    if not folder then return false end
    local changed = false
    local wantUrl = "rbxassetid://" .. id
    local function setOne(a)
        if a and a:IsA("Animation") then
            pcall(function() a.AnimationId = wantUrl end)
            changed = true
        end
    end
    setOne(folder:FindFirstChild(animName))
    if not changed then
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("Animation") then setOne(c) end
        end
    end
    return changed
end

local function softRefreshAnimate(char)
    if not char then return end
    local animate = getAnimate(char)
    pcall(function()
        if animate and animate.Parent then
            animate.Disabled = true
            task.wait()
            if animate.Parent then animate.Disabled = false end
        end
    end)
end

local _writtenSlots = {}
local FIELD_CAT = {
    idle1 = "idle", idle2 = "idle",
    walk = "walk", run = "run", jump = "jump",
    fall = "fall", climb = "climb",
    swim = "swim", swimIdle = "swim",
}

local function packMap(p)
    return {
        idle1 = p.idle1, idle2 = p.idle2 or p.idle1,
        walk = p.walk, run = p.run, jump = p.jump,
        fall = p.fall, climb = p.climb,
        swim = p.swim, swimIdle = p.swimIdle or p.swim,
    }
end

local function stopPlayingTracks(char)
    char = char or currentCharacter()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        local animator = hum:FindFirstChildOfClass("Animator")
        local list = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
        for _, track in ipairs(list or {}) do
            pcall(function()
                track:Stop(0)
                track:AdjustWeight(0, 0)
            end)
        end
    end)
end

local function writeAllIds(animate, useOriginalsOnly)
    local o = getOriginals(currentCharacter())
    local function original(field, fb)
        if o and o[field] and idNum(o[field]) then return idNum(o[field]) end
        return idNum(DEFAULT_ANIMS[field]) or fb
    end

    local function pick(field, fb)
        if useOriginalsOnly then
            local was = _writtenSlots[field]
            _writtenSlots[field] = nil
            if was then
                return original(field, fb)
            end
            return nil
        end

        local cat = FIELD_CAT[field] or field
        local slotVal = AnimState.slots[cat]
        if slotVal and slotVal ~= "None" and ANIM_PACKS[slotVal] then
            local id = idNum(packMap(ANIM_PACKS[slotVal])[field])
            if id then
                _writtenSlots[field] = true
                return id
            end
        end

        if AnimState.fullPack and AnimState.fullPack ~= "None" and ANIM_PACKS[AnimState.fullPack] then
            local id = idNum(packMap(ANIM_PACKS[AnimState.fullPack])[field])
            if id then
                _writtenSlots[field] = true
                return id
            end
        end

        if _writtenSlots[field] then
            _writtenSlots[field] = nil
            return original(field, fb)
        end

        return nil
    end

    updateAnimId(animate, "idle", "Animation1", pick("idle1", 507766666))
    updateAnimId(animate, "idle", "Animation2", pick("idle2", 507766951))
    updateAnimId(animate, "walk", "WalkAnim", pick("walk", 507777826))
    updateAnimId(animate, "run", "RunAnim", pick("run", 507767714))
    updateAnimId(animate, "jump", "JumpAnim", pick("jump", 507765000))
    updateAnimId(animate, "climb", "ClimbAnim", pick("climb", 507765644))
    updateAnimId(animate, "fall", "FallAnim", pick("fall", 507767968))
    updateAnimId(animate, "swim", "Swim", pick("swim", 507784897))
    updateAnimId(animate, "swimidle", "SwimIdle", pick("swimIdle", 507785072))
end

local function applyAnimState(force)
    if animBusy then return end
    animBusy = true
    pcall(function()
        local char = currentCharacter()
        if not char then return end
        local animate = getAnimate(char)
        if not animate then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if AnimState.enabled and not animator then return end

        if not AnimState.enabled then
            pcall(function() animate.Disabled = true end)
            stopPlayingTracks(char)
            task.wait(0.05)
            writeAllIds(animate, true)
            softRefreshAnimate(char)
            animApplied = false
            return
        end

        if not sessionOriginals then
            cacheOriginal(char, true)
        end

        pcall(function() animate.Disabled = true end)
        stopPlayingTracks(char)
        task.wait(0.05)
        writeAllIds(animate, false)
        softRefreshAnimate(char)
        animApplied = true
    end)
    animBusy = false
end

local function khResolveKorbloxMesh()
    return "rbxassetid://902942096", "rbxassetid://902843398"
end

local function korbMeshPart(meshId, textureId)
    local function elev()
        local f = setthreadidentity or setidentity or set_thread_identity
        if f then pcall(f, 8) end
    end
    elev()
    local AS = game:GetService("AssetService")
    local mp
    for _ = 1, 3 do
        local ok, r = pcall(function() return AS:CreateMeshPartAsync(meshId) end)
        if ok and r then mp = r; break end
        elev()
        task.wait()
    end
    if not mp then
        local ok, r = pcall(function()
            local m = Instance.new("MeshPart")
            m.MeshId = meshId
            return m
        end)
        if ok and r then
            local t0 = os.clock()
            while r.MeshSize.Y <= 0 and os.clock() - t0 < 3 do task.wait() end
            if r.MeshSize.Y > 0 then
                r.Size = r.MeshSize
                mp = r
            else
                pcall(function() r:Destroy() end)
            end
        end
    end
    elev()
    if mp then
        pcall(function() mp.TextureID = textureId or "" end)
        return mp, mp.Size.Y
    end
    return nil, 2.6
end

local function khApply(char)
    char = char or currentCharacter()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local mode = AnimState.korbloxMode or "both"
    local doHead = (mode == "both" or mode == "headless")
    local doKorb = (mode == "both" or mode == "korblox")

    if doHead then
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            pcall(function()
                head.LocalTransparencyModifier = 1
                head.Transparency = 1
                for _, v in ipairs(head:GetChildren()) do
                    if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
                end
            end)
        end
    end

    if doKorb then
        local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
        local kMesh, kTex = khResolveKorbloxMesh()
        if isR15 then
            local rul = char:FindFirstChild("RightUpperLeg")
            local rll = char:FindFirstChild("RightLowerLeg")
            local rf  = char:FindFirstChild("RightFoot")
            if rul and rul:IsA("BasePart") then
                pcall(function()
                    rul.LocalTransparencyModifier = 1
                    rul.Transparency = 1
                end)
                local old = char:FindFirstChild("ClixKorbloxAnimVisual")
                if not old then
                    local mp, mh = korbMeshPart(kMesh, kTex)
                    local visual = mp or Instance.new("Part")
                    if not mp then
                        visual.Size = Vector3.new(1, 2.6, 1)
                        local sm = Instance.new("SpecialMesh")
                        sm.MeshType = Enum.MeshType.FileMesh
                        sm.MeshId = kMesh
                        sm.TextureId = kTex
                        sm.Parent = visual
                    end
                    visual.Name = "ClixKorbloxAnimVisual"
                    visual.CanCollide = false
                    visual.Massless = true
                    visual.CastShadow = false
                    visual.Transparency = 0
                    local hip = rul:FindFirstChild("RightHip")
                    local jp = (hip and hip:IsA("JointInstance") and hip.C1.Position) or Vector3.new(0, 0.5, 0)
                    local weld = Instance.new("Weld")
                    weld.Name = "ClixKorbloxVisualWeld"
                    weld.Part0 = rul
                    weld.Part1 = visual
                    weld.C0 = CFrame.new(jp.X, jp.Y - (mh or 2.6) / 2, jp.Z)
                    weld.Parent = visual
                    visual.CFrame = rul.CFrame * weld.C0
                    visual.Parent = char
                end
            end
            if rll and rll:IsA("BasePart") then
                pcall(function() rll.LocalTransparencyModifier = 1; rll.Transparency = 1 end)
            end
            if rf and rf:IsA("BasePart") then
                pcall(function() rf.LocalTransparencyModifier = 1; rf.Transparency = 1 end)
            end
        else
            local r6 = char:FindFirstChild("Right Leg")
            if r6 and r6:IsA("BasePart") and not r6:IsA("MeshPart") then
                pcall(function()
                    local sm = r6:FindFirstChild("ClixKorbloxMesh")
                    if not sm then
                        sm = Instance.new("SpecialMesh")
                        sm.Name = "ClixKorbloxMesh"
                        sm.MeshType = Enum.MeshType.FileMesh
                        sm.MeshId = kMesh
                        sm.TextureId = kTex
                        sm.Scale = Vector3.new(1, 1, 1)
                        sm.Parent = r6
                    end
                end)
            end
        end
    end
end

local function khRestore(char)
    char = char or currentCharacter()
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        pcall(function()
            head.LocalTransparencyModifier = 0
            head.Transparency = 0
            for _, v in ipairs(head:GetChildren()) do
                if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 0 end
            end
        end)
    end
    local animVisual = char:FindFirstChild("ClixKorbloxAnimVisual")
    if animVisual then pcall(function() animVisual:Destroy() end) end
    for _, partName in ipairs({"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            pcall(function()
                part.LocalTransparencyModifier = 0
                part.Transparency = 0
                local mesh = part:FindFirstChild("ClixKorbloxMesh")
                if mesh then mesh:Destroy() end
            end)
        end
    end
end

scheduleKorbloxApply = function(char)
    task.spawn(function()
        for _ = 1, 16 do
            if unloaded or not AnimState.korbloxHeadless then return end
            local target = char or currentCharacter()
            local humanoid = target and target:FindFirstChildOfClass("Humanoid")
            if target and humanoid and target:FindFirstChild("Head") then
                khApply(target)
                if AnimState.korbloxMode == "headless" or target:FindFirstChild("ClixKorbloxAnimVisual") then return end
            end
            task.wait(0.25)
        end
    end)
end

local function setKorbloxHeadless(on)
    AnimState.korbloxHeadless = on == true
    if on then
        scheduleKorbloxApply(currentCharacter())
    else
        khRestore(currentCharacter())
    end
end

packLeft:AddToggle({
    Label = "Enable Animations",
    Config = { "EnableAnimations" },
    Default = false,
    Tooltip = "Replaces the character's R15 animations with the selected pack.",
    Callback = function(on)
        AnimState.enabled = on == true
        applyAnimState(true)
    end
})

local animPackDropdown
local slotDropdowns = {}
local updatePackPreview
local openAnimCatalog
local animCatalogWindow

local animPreviewCard = Instance.new("Frame")
animPreviewCard.Name = "AnimPackPreviewCard"
animPreviewCard.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
animPreviewCard.BackgroundTransparency = 0.15
animPreviewCard.Size = UDim2.new(1, 0, 0, 80)
animPreviewCard.BorderSizePixel = 0
animPreviewCard.ClipsDescendants = true
pcall(function() animPreviewCard.Parent = packLeft._raw._elements end)

local apCorner = Instance.new("UICorner")
apCorner.CornerRadius = UDim.new(0, 8)
apCorner.Parent = animPreviewCard

local apStroke = Instance.new("UIStroke")
apStroke.Color = Color3.fromRGB(50, 50, 58)
apStroke.Thickness = 1
apStroke.Transparency = 0.5
apStroke.Parent = animPreviewCard

local apImg = Instance.new("ImageLabel")
apImg.Name = "Thumb"
apImg.BackgroundTransparency = 1
apImg.Position = UDim2.fromOffset(8, 8)
apImg.Size = UDim2.fromOffset(64, 64)
apImg.ScaleType = Enum.ScaleType.Fit
apImg.Image = (AnimState.fullPack and PACK_THUMBNAILS[AnimState.fullPack]) or ""
apImg.Parent = animPreviewCard

local apImgCorner = Instance.new("UICorner")
apImgCorner.CornerRadius = UDim.new(0, 6)
apImgCorner.Parent = apImg

local apTitle = Instance.new("TextLabel")
apTitle.Name = "Title"
apTitle.BackgroundTransparency = 1
apTitle.Position = UDim2.new(0, 80, 0, 16)
apTitle.Size = UDim2.new(1, -88, 0, 20)
apTitle.Text = AnimState.fullPack or "None"
apTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
apTitle.Font = Enum.Font.GothamBold
apTitle.TextSize = 13
apTitle.TextXAlignment = Enum.TextXAlignment.Left
apTitle.Parent = animPreviewCard

local apDesc = Instance.new("TextLabel")
apDesc.Name = "Desc"
apDesc.BackgroundTransparency = 1
apDesc.Position = UDim2.new(0, 80, 0, 40)
apDesc.Size = UDim2.new(1, -88, 0, 16)
apDesc.Text = "Selected R15 pack"
apDesc.TextColor3 = Color3.fromRGB(140, 140, 150)
apDesc.Font = Enum.Font.Gotham
apDesc.TextSize = 11
apDesc.TextXAlignment = Enum.TextXAlignment.Left
apDesc.Parent = animPreviewCard

updatePackPreview = function(name)
    if apImg then apImg.Image = (name and PACK_THUMBNAILS[name]) or "" end
    if apTitle then apTitle.Text = tostring((name and name ~= "") and name or "None") end
end

animPackDropdown = packLeft:AddDropdown({
    Label = "Pack 3D",
    Config = { "AnimPack" },
    Options = PACK_OPTIONS,
    Default = AnimState.fullPack,
    Callback = function(val)
        local str = tostring(val)
        AnimState.fullPack = str
        if str ~= "None" then
            for k in pairs(AnimState.slots) do
                AnimState.slots[k] = "None"
                if slotDropdowns[k] and type(slotDropdowns[k].Set) == "function" then
                    slotDropdowns[k]:Set("None")
                end
            end
        end
        updatePackPreview(AnimState.fullPack)
        if AnimState.enabled then
            applyAnimState(true)
        end
    end
})

do
    local animEd = Instance.new("CanvasGroup")
    animEd.Name = "ClixAnimPackCatalog"
    animEd.AnchorPoint = Vector2.new(0.5, 0.5)
    animEd.Position = UDim2.fromScale(0.5, 0.5)
    animEd.Size = UDim2.fromOffset(470, 420)
    animEd.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    animEd.BackgroundTransparency = 0.05
    animEd.GroupTransparency = 0
    animEd.Visible = false
    animEd.ZIndex = 5000
    animEd.Active = true
    animEd.ClipsDescendants = true
    local animScale = Instance.new("UIScale", animEd)
    animScale.Scale = 1
    pcall(function() animEd.Parent = getClixScreenGui() end)
    animCatalogWindow = animEd

    local edCorner = Instance.new("UICorner")
    edCorner.CornerRadius = UDim.new(0, 14)
    edCorner.Parent = animEd

    local edStroke = Instance.new("UIStroke")
    edStroke.Color = Color3.fromRGB(60, 60, 70)
    edStroke.Thickness = 1.2
    edStroke.Transparency = 0.3
    edStroke.Parent = animEd

    local topBar = Instance.new("TextButton")
    topBar.AutoButtonColor = false
    topBar.Text = ""
    topBar.BackgroundTransparency = 1
    topBar.Size = UDim2.new(1, -45, 0, 36)
    topBar.Position = UDim2.fromOffset(0, 0)
    topBar.ZIndex = 303
    topBar.Parent = animEd

    local aDragging, aDragStart, aStartPos = false, nil, nil
    trackConnection(topBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            aDragging = true
            aDragStart = inp.Position
            aStartPos = animEd.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then aDragging = false end
            end)
        end
    end))
    trackConnection(UserInputService.InputChanged:Connect(function(inp)
        if not aDragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local d = inp.Position - aDragStart
            animEd.Position = UDim2.new(aStartPos.X.Scale, aStartPos.X.Offset + d.X, aStartPos.Y.Scale, aStartPos.Y.Offset + d.Y)
        end
    end))

    local aTitle = Instance.new("TextLabel")
    aTitle.BackgroundTransparency = 1
    aTitle.Position = UDim2.fromOffset(16, 6)
    aTitle.Size = UDim2.fromOffset(260, 24)
    aTitle.Text = "Animation Catalog"
    aTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
    aTitle.Font = Enum.Font.GothamBold
    aTitle.TextSize = 15
    aTitle.TextXAlignment = Enum.TextXAlignment.Left
    aTitle.ZIndex = 304
    aTitle.Parent = animEd

    local aClose = Instance.new("TextButton")
    aClose.AutoButtonColor = false
    aClose.Position = UDim2.new(1, -34, 0, 6)
    aClose.Size = UDim2.fromOffset(26, 26)
    aClose.BackgroundColor3 = Color3.fromRGB(36, 36, 42)
    aClose.BackgroundTransparency = 0.3
    aClose.Text = "X"
    aClose.TextColor3 = Color3.fromRGB(220, 220, 225)
    aClose.Font = Enum.Font.GothamBold
    aClose.TextSize = 13
    aClose.ZIndex = 304
    aClose.Parent = animEd

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = aClose

    local animTweenToken = 0
    local function closeAnimCatalog()
        animTweenToken = animTweenToken + 1
        local myToken = animTweenToken
        local t1 = TweenService:Create(animScale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.86 })
        local t2 = TweenService:Create(animEd, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
        t1:Play()
        t2:Play()
        task.spawn(function()
            t1.Completed:Wait()
            if animTweenToken == myToken then
                animEd.Visible = false
                animScale.Scale = 1
                animEd.GroupTransparency = 0
            end
        end)
    end

    trackConnection(aClose.MouseButton1Click:Connect(closeAnimCatalog))

    local catBar = Instance.new("ScrollingFrame")
    catBar.BackgroundTransparency = 1
    catBar.BorderSizePixel = 0
    catBar.Position = UDim2.fromOffset(12, 38)
    catBar.Size = UDim2.new(1, -24, 0, 28)
    catBar.ScrollBarThickness = 0
    catBar.ScrollingDirection = Enum.ScrollingDirection.X
    catBar.ZIndex = 304
    catBar.Parent = animEd

    local catLayout = Instance.new("UIListLayout")
    catLayout.FillDirection = Enum.FillDirection.Horizontal
    catLayout.Padding = UDim.new(0, 5)
    catLayout.SortOrder = Enum.SortOrder.LayoutOrder
    catLayout.Parent = catBar

    local currentCat = "full"
    local catBtns = {}

    local catalogCats = {
        { key = "full", label = "Pack Completo" },
        { key = "idle", label = "Idle" },
        { key = "walk", label = "Walk" },
        { key = "run", label = "Run" },
        { key = "jump", label = "Jump" },
        { key = "fall", label = "Fall" },
        { key = "climb", label = "Climb" },
        { key = "swim", label = "Swim" },
    }

    local searchBox = Instance.new("TextBox")
    searchBox.Position = UDim2.fromOffset(12, 72)
    searchBox.Size = UDim2.new(1, -24, 0, 26)
    searchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    searchBox.BackgroundTransparency = 0
    searchBox.Text = ""
    searchBox.PlaceholderText = "Buscar pack..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
    searchBox.TextColor3 = Color3.fromRGB(230, 230, 235)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 12
    searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = 304
    searchBox.Parent = animEd

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 6)
    sCorner.Parent = searchBox

    local sPad = Instance.new("UIPadding")
    sPad.PaddingLeft = UDim.new(0, 8)
    sPad.Parent = searchBox

    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.fromOffset(12, 104)
    scroll.Size = UDim2.new(1, -24, 1, -114)
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 110)
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ZIndex = 302
    scroll.ClipsDescendants = true
    scroll.Parent = animEd

    local grid = Instance.new("UIGridLayout")
    grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.CellSize = UDim2.fromOffset(140, 56)
    grid.SortOrder = Enum.SortOrder.Name
    grid.Parent = scroll

    local function populateCatalog(filter)
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("GuiObject") and not child:IsA("UIGridLayout") then
                child:Destroy()
            end
        end
        local f = string.lower(filter or "")
        for _, name in ipairs(PACK_OPTIONS) do
            if name ~= "None" and (f == "" or string.find(string.lower(name), f, 1, true)) then
                local isSel = (currentCat == "full" and AnimState.fullPack == name)
                    or (currentCat ~= "full" and AnimState.slots[currentCat] == name)
                local b = Instance.new("TextButton")
                b.Name = name
                b.AutoButtonColor = false
                b.BackgroundColor3 = isSel and Color3.fromRGB(30, 42, 60) or Color3.fromRGB(26, 26, 30)
                b.Size = UDim2.fromOffset(140, 56)
                b.Text = ""
                b.ZIndex = 303
                b.Parent = scroll

                local bCorn = Instance.new("UICorner")
                bCorn.CornerRadius = UDim.new(0, 8)
                bCorn.Parent = b

                local bStroke = Instance.new("UIStroke")
                bStroke.Color = isSel and Color3.fromRGB(80, 180, 255) or Color3.fromRGB(45, 45, 52)
                bStroke.Thickness = isSel and 1.5 or 1
                bStroke.Transparency = isSel and 0 or 0.6
                bStroke.Parent = b

                local img = Instance.new("ImageLabel")
                img.BackgroundTransparency = 1
                img.Position = UDim2.fromOffset(6, 6)
                img.Size = UDim2.fromOffset(44, 44)
                img.ScaleType = Enum.ScaleType.Fit
                img.Image = PACK_THUMBNAILS[name] or ""
                img.ZIndex = 304
                img.Parent = b

                local imgC = Instance.new("UICorner")
                imgC.CornerRadius = UDim.new(0, 6)
                imgC.Parent = img

                local title = Instance.new("TextLabel")
                title.BackgroundTransparency = 1
                title.Position = UDim2.fromOffset(54, 8)
                title.Size = UDim2.new(1, -58, 0, 40)
                title.Text = name
                title.TextColor3 = isSel and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(230, 230, 235)
                title.Font = Enum.Font.GothamBold
                title.TextSize = 11
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.TextYAlignment = Enum.TextYAlignment.Center
                title.TextWrapped = true
                title.ZIndex = 304
                title.Parent = b

                b.MouseButton1Click:Connect(function()
                    if currentCat == "full" then
                        if AnimState.fullPack == name then
                            AnimState.fullPack = "None"
                            updatePackPreview("None")
                            if animPackDropdown and type(animPackDropdown.Set) == "function" then
                                animPackDropdown:Set("None")
                            end
                            win:Notify("Pack disabled", 2)
                        else
                            AnimState.fullPack = name
                            for k in pairs(AnimState.slots) do
                                AnimState.slots[k] = "None"
                                if slotDropdowns[k] and type(slotDropdowns[k].Set) == "function" then
                                    slotDropdowns[k]:Set("None")
                                end
                            end
                            updatePackPreview(name)
                            if animPackDropdown and type(animPackDropdown.Set) == "function" then
                                animPackDropdown:Set(name)
                            end
                            win:Notify("Pack equipped: " .. name, 2)
                        end
                    else
                        if AnimState.slots[currentCat] == name then
                            AnimState.slots[currentCat] = "None"
                            if slotDropdowns[currentCat] and type(slotDropdowns[currentCat].Set) == "function" then
                                slotDropdowns[currentCat]:Set("None")
                            end
                            win:Notify(currentCat .. " restored", 2)
                        else
                            AnimState.slots[currentCat] = name
                            AnimState.fullPack = "None"
                            if animPackDropdown and type(animPackDropdown.Set) == "function" then
                                animPackDropdown:Set("None")
                            end
                            if slotDropdowns[currentCat] and type(slotDropdowns[currentCat].Set) == "function" then
                                slotDropdowns[currentCat]:Set(name)
                            end
                            win:Notify(name .. " -> " .. currentCat, 2)
                        end
                    end
                    if AnimState.enabled then
                        applyAnimState(true)
                    end
                    populateCatalog(searchBox.Text)
                end)
            end
        end
    end

    local function updateCatBtns()
        for k, btn in pairs(catBtns) do
            local active = (k == currentCat)
            btn.BackgroundColor3 = active and Color3.fromRGB(45, 75, 120) or Color3.fromRGB(28, 28, 34)
            btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 170)
        end
    end

    for idx, c in ipairs(catalogCats) do
        local cb = Instance.new("TextButton")
        cb.Name = c.key
        cb.AutoButtonColor = false
        cb.Size = UDim2.fromOffset(c.key == "full" and 100 or 58, 26)
        cb.BackgroundColor3 = (c.key == currentCat) and Color3.fromRGB(45, 75, 120) or Color3.fromRGB(28, 28, 34)
        cb.Text = c.label
        cb.TextColor3 = (c.key == currentCat) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 170)
        cb.Font = Enum.Font.GothamBold
        cb.TextSize = 11
        cb.LayoutOrder = idx
        cb.ZIndex = 304
        cb.Parent = catBar

        local cCorn = Instance.new("UICorner")
        cCorn.CornerRadius = UDim.new(0, 6)
        cCorn.Parent = cb

        catBtns[c.key] = cb

        cb.MouseButton1Click:Connect(function()
            currentCat = c.key
            updateCatBtns()
            populateCatalog(searchBox.Text)
        end)
    end
    catBar.CanvasSize = UDim2.fromOffset(105 + 7 * 63 + 10, 0)

    trackConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        populateCatalog(searchBox.Text)
    end))

    openAnimCatalog = function()
        animTweenToken = animTweenToken + 1
        local myToken = animTweenToken
        currentCat = "full"
        updateCatBtns()
        populateCatalog("")
        pcall(function() animEd.Parent = getClixScreenGui() end)
        animEd.ZIndex = 5000
        centerOverMainWindow(animEd)
        animEd.Visible = true
        animScale.Scale = 0.88
        animEd.GroupTransparency = 1
        TweenService:Create(animScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        TweenService:Create(animEd, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
    end
end

packLeft:AddButton({
    Label = "Open 3D Catalog (Photos)",
    Callback = function()
        if openAnimCatalog then openAnimCatalog() end
    end
})

packLeft:AddButton({
    Label = "Reapply Animations",
    Callback = function()
        applyAnimState(true)
        win:Notify("Animations reapplied", 2)
    end
})

local slotCats = {
    { key = "idle", label = "Idle" },
    { key = "walk", label = "Walk" },
    { key = "run", label = "Run" },
    { key = "jump", label = "Jump" },
    { key = "fall", label = "Fall" },
    { key = "climb", label = "Climb" },
    { key = "swim", label = "Swim" },
}

for _, slot in ipairs(slotCats) do
    slotDropdowns[slot.key] = packRight:AddDropdown({
        Label = slot.label,
        Config = { "AnimSlot_" .. slot.key },
        Options = SLOT_OPTIONS,
        Default = "None",
        Callback = function(val)
            local str = tostring(val)
            AnimState.slots[slot.key] = str
            if str ~= "None" then
                AnimState.fullPack = "None"
                if animPackDropdown and type(animPackDropdown.Set) == "function" then
                    animPackDropdown:Set("None")
                end
            end
            if AnimState.enabled then
                applyAnimState(true)
            end
        end
    })
end

korbloxToggle = avatarLeft:AddToggle({
    Label = "Korblox & Headless",
    Config = { "KorbloxHeadless" },
    Default = false,
    Tooltip = "Applies Korblox and/or Headless, visible only to you.",
    Callback = setKorbloxHeadless
})
if korbloxToggle then
    AnimState.korbloxHeadless = korbloxToggle.Value == true
    if AnimState.korbloxHeadless then scheduleKorbloxApply(currentCharacter()) end
end

korbloxModeDropdown = avatarLeft:AddDropdown({
    Label = "Mode",
    Config = { "KorbloxMode" },
    Options = { "Both", "Headless", "Korblox" },
    Default = "Both",
    Callback = function(val)
        local modeMap = { ["Both"] = "both", ["Headless"] = "headless", ["Korblox"] = "korblox" }
        AnimState.korbloxMode = modeMap[tostring(val)] or "both"
        if AnimState.korbloxHeadless then
            khRestore(currentCharacter())
            task.wait(0.05)
            scheduleKorbloxApply(currentCharacter())
        end
    end
})
if korbloxModeDropdown and korbloxModeDropdown.Value then
    korbloxModeMap = { ["Both"] = "both", ["Headless"] = "headless", ["Korblox"] = "korblox" }
    AnimState.korbloxMode = korbloxModeMap[tostring(korbloxModeDropdown.Value)] or AnimState.korbloxMode
end

local AvatarCopyState = {
    active = false,
    targetUserId = nil,
    keepOnRespawn = false,
    inputTarget = "",
    selectedServerPlayer = "",
}

local function clearCurrentAccessories(char)
    if not char then return end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Accessory") then
            pcall(function() item:Destroy() end)
        end
    end
end

local function attachAccessoryToChar(item, char)
    local handle = item:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        item.Parent = char
        return
    end
    for _, w in ipairs(handle:GetChildren()) do
        if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("ManualWeld") then
            pcall(function() w:Destroy() end)
        end
    end
    local att0 = handle:FindFirstChildOfClass("Attachment")
    if not att0 then
        item.Parent = char
        return
    end
    local att1 = nil
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            local a = part:FindFirstChild(att0.Name)
            if a and a:IsA("Attachment") then
                att1 = a
                break
            end
        end
    end
    if not att1 then
        item.Parent = char
        return
    end
    handle.Anchored = false
    local weld = Instance.new("Weld")
    weld.Name = "AccessoryWeld"
    weld.Part0 = handle
    weld.Part1 = att1.Parent
    weld.C0 = att0.CFrame
    weld.C1 = att1.CFrame
    weld.Parent = handle
    item.Parent = char
end

local function applyAvatarFromUserId(userId, char)
    char = char or currentCharacter()
    if not char then return false, "No character" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false, "Character dead" end
    local uid = tonumber(userId)
    if not uid or uid <= 0 then return false, "Invalid UserId" end

    local okDesc, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserIdAsync(uid)
    end)
    if not okDesc or not desc then return false, "Failed to load description" end

    local okModel, tempModel = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(desc, hum.RigType or Enum.HumanoidRigType.R15)
    end)
    if not okModel or not tempModel then return false, "Failed to build model" end

    clearCurrentAccessories(char)

    for _, item in ipairs(tempModel:GetChildren()) do
        if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
            local current = char:FindFirstChildOfClass(item.ClassName)
            if current then pcall(function() current:Destroy() end) end
            item.Parent = char
        elseif item:IsA("BodyColors") then
            local currentBc = char:FindFirstChildOfClass("BodyColors")
            if currentBc then
                currentBc.HeadColor3 = item.HeadColor3
                currentBc.LeftArmColor3 = item.LeftArmColor3
                currentBc.RightArmColor3 = item.RightArmColor3
                currentBc.LeftLegColor3 = item.LeftLegColor3
                currentBc.RightLegColor3 = item.RightLegColor3
                currentBc.TorsoColor3 = item.TorsoColor3
            else
                item.Parent = char
            end
        end
    end

    for _, item in ipairs(tempModel:GetChildren()) do
        if item:IsA("Accessory") then
            local attachedOk = false
            pcall(function()
                hum:AddAccessory(item)
                attachedOk = true
            end)
            if not attachedOk then
                attachAccessoryToChar(item, char)
            end
        end
    end

    local srcHead = tempModel:FindFirstChild("Head")
    local myHead = char:FindFirstChild("Head")
    if srcHead and myHead then
        local srcFace = srcHead:FindFirstChildOfClass("Decal")
        local myFace = myHead:FindFirstChildOfClass("Decal")
        if srcFace then
            if myFace then
                myFace.Texture = srcFace.Texture
            else
                local nf = srcFace:Clone()
                nf.Parent = myHead
            end
        end
        if srcHead:IsA("MeshPart") and myHead:IsA("MeshPart") then
            pcall(function()
                myHead.MeshId = srcHead.MeshId
                myHead.TextureID = srcHead.TextureID
            end)
        end
    end

    tempModel:Destroy()
    AvatarCopyState.active = true
    AvatarCopyState.targetUserId = uid
    if AnimState.korbloxHeadless then
        khApply(char)
    end
    return true
end

local function restoreOriginalAvatar(char)
    char = char or currentCharacter()
    if not char then return end
    AvatarCopyState.active = false
    AvatarCopyState.targetUserId = nil
    khRestore(char)

    task.spawn(function()
        pcall(function()
            local desc = Players:GetHumanoidDescriptionFromUserIdAsync(LocalPlayer.UserId)
            if not desc then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local tempModel = Players:CreateHumanoidModelFromDescriptionAsync(desc, hum.RigType or Enum.HumanoidRigType.R15)
            if not tempModel then return end

            clearCurrentAccessories(char)

            for _, item in ipairs(tempModel:GetChildren()) do
                if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                    local current = char:FindFirstChildOfClass(item.ClassName)
                    if current then pcall(function() current:Destroy() end) end
                    item.Parent = char
                elseif item:IsA("BodyColors") then
                    local currentBc = char:FindFirstChildOfClass("BodyColors")
                    if currentBc then
                        currentBc.HeadColor3 = item.HeadColor3
                        currentBc.LeftArmColor3 = item.LeftArmColor3
                        currentBc.RightArmColor3 = item.RightArmColor3
                        currentBc.LeftLegColor3 = item.LeftLegColor3
                        currentBc.RightLegColor3 = item.RightLegColor3
                        currentBc.TorsoColor3 = item.TorsoColor3
                    else
                        item.Parent = char
                    end
                elseif item:IsA("Accessory") then
                    attachAccessoryToChar(item, char)
                end
            end

            local srcHead = tempModel:FindFirstChild("Head")
            local myHead = char:FindFirstChild("Head")
            if srcHead and myHead then
                local srcFace = srcHead:FindFirstChildOfClass("Decal")
                local myFace = myHead:FindFirstChildOfClass("Decal")
                if srcFace and myFace then myFace.Texture = srcFace.Texture end
                if srcHead:IsA("MeshPart") and myHead:IsA("MeshPart") then
                    pcall(function()
                        myHead.MeshId = srcHead.MeshId
                        myHead.TextureID = srcHead.TextureID
                    end)
                end
            end

            tempModel:Destroy()
        end)
    end)
end

local function resolveUserId(input)
    if not input or input == "" then return nil end
    local asNum = tonumber(input)
    if asNum and asNum > 0 then return asNum end
    local ok, id = pcall(function()
        return Players:GetUserIdFromNameAsync(input)
    end)
    if ok and id and id > 0 then return id end
    local p = Players:FindFirstChild(input)
    if p then return p.UserId end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower() == input:lower() or plr.DisplayName:lower() == input:lower() then
            return plr.UserId
        end
    end
    return nil
end

local function getServerPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

avatarLeft:AddDivider()

avatarLeft:AddButton({
    Label = "Force Update Avatar",
    Callback = function()
        local char = currentCharacter()
        if AvatarCopyState.active and AvatarCopyState.targetUserId then
            applyAvatarFromUserId(AvatarCopyState.targetUserId, char)
            win:Notify("Copied avatar reapplied", 2)
        elseif AnimState.korbloxHeadless then
            khApply(char)
            win:Notify("Korblox updated", 2)
        end
    end
})

local openAvatarInspector, closeAvatarInspector
local avatarEd = Instance.new("Frame")
avatarEd.Name = "ClixAvatarInspector"
avatarEd.AnchorPoint = Vector2.new(0.5, 0.5)
avatarEd.Position = UDim2.fromScale(0.5, 0.5)
avatarEd.Size = UDim2.fromOffset(590, 470)
avatarEd.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
avatarEd.BorderSizePixel = 0
avatarEd.Visible = false
avatarEd.ZIndex = 5000

local avatarEdCorn = Instance.new("UICorner")
avatarEdCorn.CornerRadius = UDim.new(0, 12)
avatarEdCorn.Parent = avatarEd

local avatarEdStroke = Instance.new("UIStroke")
avatarEdStroke.Color = Color3.fromRGB(38, 38, 46)
avatarEdStroke.Thickness = 1.2
avatarEdStroke.Parent = avatarEd

local avatarScale = Instance.new("UIScale", avatarEd)
avatarScale.Scale = 1

local avatarDragBar = Instance.new("TextButton")
avatarDragBar.Name = "DragBar"
avatarDragBar.AutoButtonColor = false
avatarDragBar.BackgroundTransparency = 1
avatarDragBar.Size = UDim2.new(1, -40, 0, 36)
avatarDragBar.Text = ""
avatarDragBar.ZIndex = 5001
avatarDragBar.Parent = avatarEd

local avatarDragging, avatarDragStart, avatarStartPos = false, nil, nil
avatarDragBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        avatarDragging = true
        avatarDragStart = inp.Position
        avatarStartPos = avatarEd.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then avatarDragging = false end
        end)
    end
end)
trackConnection(UserInputService.InputChanged:Connect(function(inp)
    if avatarDragging and avatarDragStart and avatarStartPos then
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local d = inp.Position - avatarDragStart
            avatarEd.Position = UDim2.new(avatarStartPos.X.Scale, avatarStartPos.X.Offset + d.X, avatarStartPos.Y.Scale, avatarStartPos.Y.Offset + d.Y)
        end
    end
end))

local avatarCloseBtn = Instance.new("TextButton")
avatarCloseBtn.Name = "CloseButton"
avatarCloseBtn.AutoButtonColor = false
avatarCloseBtn.Position = UDim2.new(1, -34, 0, 8)
avatarCloseBtn.Size = UDim2.fromOffset(24, 24)
avatarCloseBtn.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
avatarCloseBtn.Text = ""
avatarCloseBtn.TextColor3 = Color3.fromRGB(190, 190, 200)
avatarCloseBtn.Font = Enum.Font.GothamBold
avatarCloseBtn.TextSize = 12
avatarCloseBtn.ZIndex = 5002
avatarCloseBtn.Parent = avatarEd

local closeLineA = Instance.new("Frame")
closeLineA.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
closeLineA.BorderSizePixel = 0
closeLineA.AnchorPoint = Vector2.new(0.5, 0.5)
closeLineA.Position = UDim2.fromScale(0.5, 0.5)
closeLineA.Size = UDim2.fromOffset(14, 2)
closeLineA.Rotation = 45
closeLineA.ZIndex = 5003
closeLineA.Parent = avatarCloseBtn

local closeLineB = Instance.new("Frame")
closeLineB.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
closeLineB.BorderSizePixel = 0
closeLineB.AnchorPoint = Vector2.new(0.5, 0.5)
closeLineB.Position = UDim2.fromScale(0.5, 0.5)
closeLineB.Size = UDim2.fromOffset(14, 2)
closeLineB.Rotation = -45
closeLineB.ZIndex = 5003
closeLineB.Parent = avatarCloseBtn

local avatarCloseCorn = Instance.new("UICorner")
avatarCloseCorn.CornerRadius = UDim.new(0, 6)
avatarCloseCorn.Parent = avatarCloseBtn

local avatarTweenToken = 0
closeAvatarInspector = function()
    avatarTweenToken = avatarTweenToken + 1
    local myToken = avatarTweenToken
    TweenService:Create(avatarScale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 }):Play()
        task.delay(0.20, function()
        if avatarTweenToken == myToken and avatarEd and avatarEd.Parent then
            avatarEd.Visible = false
        end
    end)
end
avatarCloseBtn.MouseButton1Click:Connect(closeAvatarInspector)

local leftPanel = Instance.new("Frame")
leftPanel.Name = "LeftPanel"
leftPanel.BackgroundTransparency = 1
leftPanel.Position = UDim2.fromOffset(14, 40)
leftPanel.Size = UDim2.fromOffset(210, 416)
leftPanel.ZIndex = 5001
leftPanel.Parent = avatarEd

local playersCountLabel = Instance.new("TextLabel")
playersCountLabel.Name = "PlayersCount"
playersCountLabel.BackgroundTransparency = 1
playersCountLabel.Position = UDim2.fromOffset(0, 0)
playersCountLabel.Size = UDim2.new(1, 0, 0, 22)
playersCountLabel.Text = "Jugadores • 0"
playersCountLabel.TextColor3 = Color3.fromRGB(225, 225, 235)
playersCountLabel.Font = Enum.Font.GothamBold
playersCountLabel.TextSize = 14
playersCountLabel.TextXAlignment = Enum.TextXAlignment.Left
playersCountLabel.ZIndex = 5002
playersCountLabel.Parent = leftPanel

local playersScroll = Instance.new("ScrollingFrame")
playersScroll.Name = "PlayersScroll"
playersScroll.BackgroundTransparency = 1
playersScroll.Position = UDim2.fromOffset(0, 28)
playersScroll.Size = UDim2.new(1, 0, 1, -28)
playersScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
playersScroll.ScrollBarThickness = 3
playersScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
playersScroll.BorderSizePixel = 0
playersScroll.ZIndex = 5002
playersScroll.Parent = leftPanel

local playersLayout = Instance.new("UIListLayout")
playersLayout.Padding = UDim.new(0, 6)
playersLayout.SortOrder = Enum.SortOrder.LayoutOrder
playersLayout.Parent = playersScroll

playersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    playersScroll.CanvasSize = UDim2.fromOffset(0, playersLayout.AbsoluteContentSize.Y + 10)
end)

local rightPanel = Instance.new("Frame")
rightPanel.Name = "RightPanel"
rightPanel.BackgroundTransparency = 1
rightPanel.Position = UDim2.fromOffset(238, 40)
rightPanel.Size = UDim2.fromOffset(338, 416)
rightPanel.ZIndex = 5001
rightPanel.Parent = avatarEd

local searchBar = Instance.new("Frame")
searchBar.Name = "SearchBar"
searchBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
searchBar.Size = UDim2.new(1, 0, 0, 36)
searchBar.BorderSizePixel = 0
searchBar.ZIndex = 5002
searchBar.Parent = rightPanel

local searchBarCorn = Instance.new("UICorner")
searchBarCorn.CornerRadius = UDim.new(0, 8)
searchBarCorn.Parent = searchBar

local searchBarStroke = Instance.new("UIStroke")
searchBarStroke.Color = Color3.fromRGB(36, 36, 44)
searchBarStroke.Thickness = 1
searchBarStroke.Parent = searchBar

local searchBox = Instance.new("TextBox")
searchBox.Name = "SearchBox"
searchBox.BackgroundTransparency = 1
searchBox.Position = UDim2.fromOffset(12, 0)
searchBox.Size = UDim2.new(1, -44, 1, 0)
searchBox.PlaceholderText = "buscar ID/nombre (opcional)"
searchBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.ZIndex = 5003
searchBox.Parent = searchBar

local searchIcon = Instance.new("TextLabel")
searchIcon.Name = "SearchIcon"
searchIcon.BackgroundTransparency = 1
searchIcon.Position = UDim2.new(1, -32, 0, 0)
searchIcon.Size = UDim2.fromOffset(26, 36)
searchIcon.Text = ""
searchIcon.TextColor3 = Color3.fromRGB(140, 140, 150)
searchIcon.Font = Enum.Font.GothamBold
searchIcon.TextSize = 12
searchIcon.ZIndex = 5003
searchIcon.Parent = searchBar

local previewCard = Instance.new("Frame")
previewCard.Name = "PreviewCard"
previewCard.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
previewCard.Position = UDim2.fromOffset(0, 46)
previewCard.Size = UDim2.new(1, 0, 0, 204)
previewCard.BorderSizePixel = 0
previewCard.ZIndex = 5002
previewCard.Parent = rightPanel

local previewCardCorn = Instance.new("UICorner")
previewCardCorn.CornerRadius = UDim.new(0, 10)
previewCardCorn.Parent = previewCard

local previewCardStroke = Instance.new("UIStroke")
previewCardStroke.Color = Color3.fromRGB(36, 36, 44)
previewCardStroke.Thickness = 1
previewCardStroke.Parent = previewCard

local starIcon = Instance.new("TextLabel")
starIcon.Name = "StarIcon"
starIcon.BackgroundTransparency = 1
starIcon.Position = UDim2.new(1, -28, 0, 8)
starIcon.Size = UDim2.fromOffset(20, 20)
starIcon.Text = ""
starIcon.TextColor3 = Color3.fromRGB(150, 150, 160)
starIcon.Font = Enum.Font.GothamBold
starIcon.TextSize = 16
starIcon.ZIndex = 5003
starIcon.Parent = previewCard

local avatarImg = Instance.new("ImageLabel")
avatarImg.Name = "AvatarImage"
avatarImg.BackgroundTransparency = 1
avatarImg.AnchorPoint = Vector2.new(0.5, 0.5)
avatarImg.Position = UDim2.fromScale(0.5, 0.44)
avatarImg.Size = UDim2.fromOffset(170, 170)
avatarImg.ScaleType = Enum.ScaleType.Fit
avatarImg.Image = ""
avatarImg.ZIndex = 5003
avatarImg.Parent = previewCard

local previewDispName = Instance.new("TextLabel")
previewDispName.Name = "PreviewDispName"
previewDispName.BackgroundTransparency = 1
previewDispName.Position = UDim2.new(0, 0, 1, -38)
previewDispName.Size = UDim2.new(1, 0, 0, 18)
previewDispName.Text = "Selecciona un jugador"
previewDispName.TextColor3 = Color3.fromRGB(245, 245, 250)
previewDispName.Font = Enum.Font.GothamBold
previewDispName.TextSize = 14
previewDispName.TextXAlignment = Enum.TextXAlignment.Center
previewDispName.ZIndex = 5003
previewDispName.Parent = previewCard

local previewUsername = Instance.new("TextLabel")
previewUsername.Name = "PreviewUsername"
previewUsername.BackgroundTransparency = 1
previewUsername.Position = UDim2.new(0, 0, 1, -18)
previewUsername.Size = UDim2.new(1, 0, 0, 14)
previewUsername.Text = "@..."
previewUsername.TextColor3 = Color3.fromRGB(140, 140, 150)
previewUsername.Font = Enum.Font.Gotham
previewUsername.TextSize = 11
previewUsername.TextXAlignment = Enum.TextXAlignment.Center
previewUsername.ZIndex = 5003
previewUsername.Parent = previewCard

local copyAvatarBtn = Instance.new("TextButton")
copyAvatarBtn.Name = "CopyAvatarBtn"
copyAvatarBtn.AutoButtonColor = false
copyAvatarBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
copyAvatarBtn.Position = UDim2.fromOffset(0, 260)
copyAvatarBtn.Size = UDim2.new(0.64, -4, 0, 36)
copyAvatarBtn.Text = "Copiar avatar"
copyAvatarBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
copyAvatarBtn.Font = Enum.Font.GothamBold
copyAvatarBtn.TextSize = 12
copyAvatarBtn.ZIndex = 5002
copyAvatarBtn.Parent = rightPanel

local copyBtnCorn = Instance.new("UICorner")
copyBtnCorn.CornerRadius = UDim.new(0, 8)
copyBtnCorn.Parent = copyAvatarBtn

local copyBtnStroke = Instance.new("UIStroke")
copyBtnStroke.Color = Color3.fromRGB(44, 44, 52)
copyBtnStroke.Thickness = 1
copyBtnStroke.Parent = copyAvatarBtn

local removeAvatarBtn = Instance.new("TextButton")
removeAvatarBtn.Name = "RemoveAvatarBtn"
removeAvatarBtn.AutoButtonColor = false
removeAvatarBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
removeAvatarBtn.Position = UDim2.new(0.64, 4, 0, 260)
removeAvatarBtn.Size = UDim2.new(0.36, -4, 0, 36)
removeAvatarBtn.Text = "Quitar"
removeAvatarBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
removeAvatarBtn.Font = Enum.Font.GothamBold
removeAvatarBtn.TextSize = 12
removeAvatarBtn.ZIndex = 5002
removeAvatarBtn.Parent = rightPanel

local removeBtnCorn = Instance.new("UICorner")
removeBtnCorn.CornerRadius = UDim.new(0, 8)
removeBtnCorn.Parent = removeAvatarBtn

local removeBtnStroke = Instance.new("UIStroke")
removeBtnStroke.Color = Color3.fromRGB(44, 44, 52)
removeBtnStroke.Thickness = 1
removeBtnStroke.Parent = removeAvatarBtn

local atravesarBtn = Instance.new("TextButton")
atravesarBtn.Name = "AtravesarBtn"
atravesarBtn.AutoButtonColor = false
atravesarBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
atravesarBtn.Position = UDim2.fromOffset(0, 304)
atravesarBtn.Size = UDim2.new(1, 0, 0, 36)
atravesarBtn.Text = "Atravesar jugadores: no"
atravesarBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
atravesarBtn.Font = Enum.Font.GothamBold
atravesarBtn.TextSize = 12
atravesarBtn.ZIndex = 5002
atravesarBtn.Parent = rightPanel

local atravesarCorn = Instance.new("UICorner")
atravesarCorn.CornerRadius = UDim.new(0, 8)
atravesarCorn.Parent = atravesarBtn

local atravesarStroke = Instance.new("UIStroke")
atravesarStroke.Color = Color3.fromRGB(44, 44, 52)
atravesarStroke.Thickness = 1
atravesarStroke.Parent = atravesarBtn

local r15Btn = Instance.new("TextButton")
r15Btn.Name = "R15Btn"
r15Btn.AutoButtonColor = false
r15Btn.BackgroundColor3 = Color3.fromRGB(36, 48, 70)
r15Btn.Position = UDim2.fromOffset(0, 348)
r15Btn.Size = UDim2.new(0.5, -4, 0, 32)
r15Btn.Text = "R15"
r15Btn.TextColor3 = Color3.fromRGB(240, 240, 255)
r15Btn.Font = Enum.Font.GothamBold
r15Btn.TextSize = 12
r15Btn.ZIndex = 5002
r15Btn.Parent = rightPanel

local r15Corn = Instance.new("UICorner")
r15Corn.CornerRadius = UDim.new(0, 8)
r15Corn.Parent = r15Btn

local r6Btn = Instance.new("TextButton")
r6Btn.Name = "R6Btn"
r6Btn.AutoButtonColor = false
r6Btn.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
r6Btn.Position = UDim2.new(0.5, 4, 0, 348)
r6Btn.Size = UDim2.new(0.5, -4, 0, 32)
r6Btn.Text = "R6"
r6Btn.TextColor3 = Color3.fromRGB(160, 160, 170)
r6Btn.Font = Enum.Font.GothamBold
r6Btn.TextSize = 12
r6Btn.ZIndex = 5002
r6Btn.Parent = rightPanel

local r6Corn = Instance.new("UICorner")
r6Corn.CornerRadius = UDim.new(0, 8)
r6Corn.Parent = r6Btn

local selectedInspectorPlayer = nil
local selectedInspectorUserId = nil
local inspectorRigType = Enum.HumanoidRigType.R15

r15Btn.MouseButton1Click:Connect(function()
    inspectorRigType = Enum.HumanoidRigType.R15
    r15Btn.BackgroundColor3 = Color3.fromRGB(36, 48, 70)
    r15Btn.TextColor3 = Color3.fromRGB(240, 240, 255)
    r6Btn.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    r6Btn.TextColor3 = Color3.fromRGB(160, 160, 170)
end)

r6Btn.MouseButton1Click:Connect(function()
    inspectorRigType = Enum.HumanoidRigType.R6
    r6Btn.BackgroundColor3 = Color3.fromRGB(36, 48, 70)
    r6Btn.TextColor3 = Color3.fromRGB(240, 240, 255)
    r15Btn.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    r15Btn.TextColor3 = Color3.fromRGB(160, 160, 170)
end)

local atravesarEnabled = false
local atravesarConn = nil
local function updateAtravesarUI()
    if atravesarEnabled then
        atravesarBtn.Text = "Atravesar jugadores: si"
        atravesarBtn.BackgroundColor3 = Color3.fromRGB(36, 60, 92)
        atravesarStroke.Color = Color3.fromRGB(60, 120, 190)
    else
        atravesarBtn.Text = "Atravesar jugadores: no"
        atravesarBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        atravesarStroke.Color = Color3.fromRGB(44, 44, 52)
    end
end

atravesarBtn.MouseButton1Click:Connect(function()
    atravesarEnabled = not atravesarEnabled
    updateAtravesarUI()
    if atravesarEnabled then
        if not atravesarConn then
            atravesarConn = RunService.Stepped:Connect(function()
                if not atravesarEnabled or unloaded then return end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        for _, part in ipairs(p.Character:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end)
        end
        win:Notify("Atravesar jugadores activado", 2)
    else
        if atravesarConn then
            pcall(function() atravesarConn:Disconnect() end)
            atravesarConn = nil
        end
        win:Notify("Atravesar jugadores desactivado", 2)
    end
end)

local avatarFetchToken = 0
local function updateInspectorPreview(displayName, username, userId)
    selectedInspectorUserId = userId
    previewDispName.Text = tostring(displayName or "Desconocido")
    previewUsername.Text = "@" .. tostring(username or "...")
    avatarFetchToken = avatarFetchToken + 1
    local currentTok = avatarFetchToken
    if userId and userId > 0 then
        avatarImg.Image = "rbxthumb://type=Avatar&id=" .. tostring(userId) .. "&w=420&h=420"
        task.spawn(function()
            local ok, thumb = pcall(function()
                return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
            end)
            if ok and type(thumb) == "string" and thumb ~= "" and avatarFetchToken == currentTok then
                avatarImg.Image = thumb
            end
        end)
    else
        avatarImg.Image = ""
    end
end

playerCardButtons = {}
createPlayerCard = assert(loadstring([=[
return function(ctx, p, idx, isSelected)
    local ui = {}
    local dName, uName = p.DisplayName, p.Name
    ui.card = Instance.new("TextButton")
    ui.card.Name = p.Name
    ui.card.AutoButtonColor = false
    ui.card.BackgroundColor3 = isSelected and Color3.fromRGB(36, 48, 70) or Color3.fromRGB(24, 24, 28)
    ui.card.Size = UDim2.new(1, -6, 0, 48)
    ui.card.Text = ""
    ui.card.LayoutOrder = idx
    ui.card.ZIndex = 5003
    ui.card.Parent = ctx.scroll
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = ui.card
    ui.stroke = Instance.new("UIStroke")
    ui.stroke.Color = isSelected and Color3.fromRGB(70, 140, 230) or Color3.fromRGB(36, 36, 42)
    ui.stroke.Thickness = isSelected and 1.5 or 1
    ui.stroke.Parent = ui.card
    local thumb = Instance.new("ImageLabel")
    thumb.Name = "Headshot"
    thumb.BackgroundTransparency = 1
    thumb.Position = UDim2.fromOffset(8, 7)
    thumb.Size = UDim2.fromOffset(34, 34)
    thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(p.UserId) .. "&w=150&h=150"
    thumb.ScaleType = Enum.ScaleType.Fit
    thumb.ZIndex = 5004
    thumb.Parent = ui.card
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(1, 0)
    thumbCorner.Parent = thumb
    ui.display = Instance.new("TextLabel")
    ui.display.BackgroundTransparency = 1
    ui.display.Position = UDim2.fromOffset(48, 6)
    ui.display.Size = UDim2.new(1, -54, 0, 18)
    ui.display.Text = dName
    ui.display.TextColor3 = isSelected and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(240, 240, 245)
    ui.display.Font = Enum.Font.GothamBold
    ui.display.TextSize = 13
    ui.display.TextXAlignment = Enum.TextXAlignment.Left
    ui.display.ZIndex = 5004
    ui.display.Parent = ui.card
    local username = Instance.new("TextLabel")
    username.BackgroundTransparency = 1
    username.Position = UDim2.fromOffset(48, 26)
    username.Size = UDim2.new(1, -54, 0, 16)
    username.Text = "@" .. uName
    username.TextColor3 = Color3.fromRGB(140, 140, 150)
    username.Font = Enum.Font.Gotham
    username.TextSize = 11
    username.TextXAlignment = Enum.TextXAlignment.Left
    username.ZIndex = 5004
    username.Parent = ui.card
    ctx.buttons[p.UserId] = { card = ui.card, stroke = ui.stroke, label = ui.display }
    ui.card.MouseButton1Click:Connect(function()
        ctx.setSelected(p)
        ctx.preview(p.DisplayName, p.Name, p.UserId)
        for userId, data in pairs(ctx.buttons) do
            local selected = userId == p.UserId
            data.card.BackgroundColor3 = selected and Color3.fromRGB(36, 48, 70) or Color3.fromRGB(24, 24, 28)
            data.stroke.Color = selected and Color3.fromRGB(70, 140, 230) or Color3.fromRGB(36, 36, 42)
            data.stroke.Thickness = selected and 1.5 or 1
            data.label.TextColor3 = selected and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(240, 240, 245)
        end
    end)
end
]=])())
playerCardContext = {
    scroll = playersScroll,
    buttons = playerCardButtons,
    preview = updateInspectorPreview,
    setSelected = function(player) selectedInspectorPlayer = player end,
}
local function populatePlayersList(filter)
    filter = tostring(filter or ""):lower()
    for _, child in ipairs(playersScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    table.clear(playerCardButtons)
    local players = Players:GetPlayers()
    playersCountLabel.Text = "Jugadores • " .. tostring(#players)
    for index, player in ipairs(players) do
        local name, username = player.DisplayName, player.Name
        local matches = filter == "" or name:lower():find(filter, 1, true) or username:lower():find(filter, 1, true) or tostring(player.UserId):find(filter, 1, true)
        if matches then createPlayerCard(playerCardContext, player, index, selectedInspectorUserId == player.UserId) end
    end
end

trackConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    populatePlayersList(searchBox.Text)
end))

searchBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local raw = tostring(searchBox.Text or ""):gsub("%s+", "")
        if raw ~= "" then
            local asNum = tonumber(raw)
            if asNum and asNum > 0 then
                pcall(function()
                    local uName = Players:GetNameFromUserIdAsync(asNum)
                    updateInspectorPreview(uName or ("User " .. asNum), uName or raw, asNum)
                end)
            else
                local ok, uId = pcall(function() return Players:GetUserIdFromNameAsync(raw) end)
                if ok and uId and uId > 0 then
                    updateInspectorPreview(raw, raw, uId)
                else
                    win:Notify("Usuario no encontrado", 2)
                end
            end
        end
    end
end)

copyAvatarBtn.MouseButton1Click:Connect(function()
    if not selectedInspectorUserId or selectedInspectorUserId <= 0 then
        win:Notify("Selecciona un jugador primero", 2)
        return
    end
    task.spawn(function()
        win:Notify("Copiando avatar...", 2)
        local ok, err = applyAvatarFromUserId(selectedInspectorUserId)
        if ok then
            win:Notify("Avatar copiado correctamente", 3)
        else
            win:Notify("Error: " .. tostring(err), 3)
        end
    end)
end)

removeAvatarBtn.MouseButton1Click:Connect(function()
    restoreOriginalAvatar(currentCharacter())
    win:Notify("Avatar original restaurado", 2)
end)

openAvatarInspector = function()
    avatarTweenToken = avatarTweenToken + 1
    local myToken = avatarTweenToken
    pcall(function() avatarEd.Parent = getClixScreenGui() end)
    avatarEd.ZIndex = 5000
    centerOverMainWindow(avatarEd)
    avatarEd.Visible = true
    avatarScale.Scale = 0.88
        local firstPlr = Players:GetPlayers()[1]
    if firstPlr and (not selectedInspectorUserId or selectedInspectorUserId <= 0) then
        selectedInspectorPlayer = firstPlr
        updateInspectorPreview(firstPlr.DisplayName, firstPlr.Name, firstPlr.UserId)
    end
    populatePlayersList(searchBox.Text)
    TweenService:Create(avatarScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    
end

trackConnection(Players.PlayerAdded:Connect(function()
    if avatarEd.Visible then populatePlayersList(searchBox.Text) end
end))
trackConnection(Players.PlayerRemoving:Connect(function()
    if avatarEd.Visible then populatePlayersList(searchBox.Text) end
end))

avatarRight:AddButton({
    Label = "Open Avatar Inspector (Server List & 3D Preview)",
    Callback = function()
        if openAvatarInspector then openAvatarInspector() end
    end
})

avatarRight:AddDivider()

avatarRight:AddTextBox({
    Label = "Username / UserId",
    Placeholder = "Enter name or UserId",
    Callback = function(val)
        AvatarCopyState.inputTarget = tostring(val or ""):gsub("%s+", "")
    end
})

local playerDropdown
playerDropdown = avatarRight:AddDropdown({
    Label = "Server Player",
    Options = getServerPlayerNames(),
    Default = getServerPlayerNames()[1] or "None",
    Callback = function(val)
        AvatarCopyState.selectedServerPlayer = tostring(val or "")
    end
})

avatarRight:AddButton({
    Label = "Copy Server Player",
    Callback = function()
        local targetName = AvatarCopyState.selectedServerPlayer
        if not targetName or targetName == "" or targetName == "None" then
            win:Notify("Select a server player first", 2)
            return
        end
        local uid = resolveUserId(targetName)
        if not uid then
            win:Notify("Could not resolve player ID", 2)
            return
        end
        task.spawn(function()
            win:Notify("Copying " .. targetName .. "...", 2)
            local ok, err = applyAvatarFromUserId(uid)
            if ok then
                win:Notify("Avatar copied from " .. targetName, 3)
            else
                win:Notify("Failed: " .. tostring(err), 3)
            end
        end)
    end
})

avatarRight:AddButton({
    Label = "Copy by Name / UserId",
    Callback = function()
        local target = AvatarCopyState.inputTarget
        if not target or target == "" then
            win:Notify("Enter a username or UserId", 2)
            return
        end
        task.spawn(function()
            win:Notify("Resolving " .. target .. "...", 2)
            local uid = resolveUserId(target)
            if not uid then
                win:Notify("User not found: " .. target, 3)
                return
            end
            local ok, err = applyAvatarFromUserId(uid)
            if ok then
                win:Notify("Avatar copied: " .. target, 3)
            else
                win:Notify("Failed: " .. tostring(err), 3)
            end
        end)
    end
})

avatarRight:AddToggle({
    Label = "Keep on Respawn",
    Config = { "AvatarCopyKeepOnRespawn" },
    Default = false,
    Tooltip = "Automatically reapplies copied avatar on respawn.",
    Callback = function(on)
        AvatarCopyState.keepOnRespawn = on
    end
})

avatarRight:AddDivider()

avatarRight:AddButton({
    Label = "Restore Original Avatar",
    Callback = function()
        restoreOriginalAvatar(currentCharacter())
        win:Notify("Original avatar restored", 2)
    end
})

local function refreshServerDropdown()
    if playerDropdown and type(playerDropdown.SetOptions) == "function" then
        playerDropdown:SetOptions(getServerPlayerNames())
    end
end
trackConnection(Players.PlayerAdded:Connect(refreshServerDropdown))
trackConnection(Players.PlayerRemoving:Connect(refreshServerDropdown))

trackConnection(LocalPlayer.CharacterAdded:Connect(function(char)
    task.defer(function()
        if unloaded then return end
        _writtenSlots = {}
        if AnimState.enabled then
            task.delay(0.6, function()
                if not unloaded and AnimState.enabled then
                    applyAnimState(true)
                end
            end)
        end
        if AnimState.korbloxHeadless then
            scheduleKorbloxApply(char)
        end
        if AvatarCopyState.active and AvatarCopyState.keepOnRespawn and AvatarCopyState.targetUserId then
            task.delay(0.6, function()
                if not unloaded and AvatarCopyState.active and AvatarCopyState.targetUserId then
                    applyAvatarFromUserId(AvatarCopyState.targetUserId, char)
                end
            end)
        end
    end)
end))

unloadAnimations = function()
    AnimState.enabled = false
    AnimState.korbloxHeadless = false
    _writtenSlots = {}
    if AvatarCopyState.active then
        restoreOriginalAvatar(currentCharacter())
    end
    if atravesarConn then
        pcall(function() atravesarConn:Disconnect() end)
        atravesarConn = nil
    end
    if avatarEd and avatarEd.Parent then
        pcall(function() avatarEd:Destroy() end)
    end
    if vfxFxEd and vfxFxEd.Parent then
        pcall(function() vfxFxEd:Destroy() end)
    end
    pcall(function()
        local char = currentCharacter()
        if char then
            local animate = getAnimate(char)
            if animate then
                pcall(function() animate.Disabled = true end)
                task.wait(0.05)
                writeAllIds(animate, true)
                softRefreshAnimate(char)
            end
            khRestore(char)
        end
    end)
    if animCatalogWindow then pcall(function() animCatalogWindow:Destroy() end); animCatalogWindow = nil end
    if animPreviewCard then pcall(function() animPreviewCard:Destroy() end); animPreviewCard = nil end
end

end
