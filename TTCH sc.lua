-- LocalScript (StarterPlayerScripts)
-- Script Hub: CFrame Speed + Gravity
-- K = hide/show GUI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
_G.CFrameSpeed = _G.CFrameSpeed or 0.09

-- clean up a previous run so movement/connections never double up
if _G.ScriptHubCleanup then pcall(_G.ScriptHubCleanup) end

local conns = {}
local function connect(sig, fn)
    local c = sig:Connect(fn)
    conns[#conns + 1] = c
    return c
end

local VERSION = "Unknown"

local url = "https://raw.githubusercontent.com/mckenziii/The-Twink-Community-Hub/refs/heads/main/version.txt?t=" .. os.time()

local req = (syn and syn.request) or http_request or request

local response = req({
    Url = url,
    Method = "GET"
})

if response and response.Body then
    VERSION = response.Body:gsub("%s+", "")
end

print("Loaded Version:", VERSION)

local TOGGLE_KEY = Enum.KeyCode.K
local SPEED_KEY = Enum.KeyCode.C
local GRAV_KEY = Enum.KeyCode.G

local COL = {
    bg      = Color3.fromRGB(24, 25, 31),
    element = Color3.fromRGB(41, 44, 54),
    stroke  = Color3.fromRGB(58, 62, 75),
    accent  = Color3.fromRGB(99, 120, 255),
    on      = Color3.fromRGB(230, 68, 68),
    text    = Color3.fromRGB(235, 238, 245),
    sub     = Color3.fromRGB(142, 148, 165),
    off     = Color3.fromRGB(84, 88, 102),
}

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local function round(o, r)
    make("UICorner", {CornerRadius = UDim.new(0, r)}, o)
end

local function tween(o, props)
    TweenService:Create(o, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ========== GUI ==========
local gui = make("ScreenGui", {Name = "ScriptHub", ResetOnSpawn = false}, player:WaitForChild("PlayerGui"))

-- toggle click sound (built-in asset, always loads; swap SoundId for any catalog sound)
local clickSound = make("Sound", {SoundId = "rbxasset://sounds/clickfast.wav", Volume = 0.6}, gui)
local function click()
    clickSound:Play()
end

local main = make("Frame", {
    Size = UDim2.new(0, 380, 0, 210),
    Position = UDim2.new(0, 16, 0.5, -105),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    Active = true,
}, gui)
round(main, 10)
make("UIStroke", {Color = COL.stroke, Thickness = 1}, main)

-- Background image at 25% visibility. Roblox can't show a raw/local image directly, so
-- this resolves one two ways, in order:
--   1) a local image file in your executor's workspace folder (loaded via getcustomasset)
--   2) the uploaded decal id, resolved to its underlying texture
local HUB_IMAGE_FILE = "twinkhub_bg.png" -- put this file in your executor's workspace folder
local HUB_IMAGE_ID = 104049828893869     -- fallback: the uploaded decal

local function resolveHubImage()
    -- 1) local file via the executor
    local getasset = getcustomasset or getsynasset or (syn and syn.getcustomasset)
    if getasset and isfile and isfile(HUB_IMAGE_FILE) then
        local ok, res = pcall(getasset, HUB_IMAGE_FILE)
        if ok and res then return res end
    end
    -- 2) resolve the decal to its image texture
    local ok, tex = pcall(function()
        local model = game:GetService("InsertService"):LoadAsset(HUB_IMAGE_ID)
        local decal = model:FindFirstChildWhichIsA("Decal", true)
        local texture = decal and decal.Texture
        model:Destroy()
        return texture
    end)
    if ok and tex then return tex end
    return "rbxassetid://" .. HUB_IMAGE_ID
end

local bgImage = make("ImageLabel", {
    Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    Image = resolveHubImage(),
    ImageTransparency = 0.75, -- 0.75 = 25% visible
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 0, -- sit behind every other element
}, main)
round(bgImage, 10)

-- title bar
local titleBar = make("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1}, main)
make("TextLabel", {
    Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = COL.text, Text = "The Twink Community Hub", TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)
local keyChip = make("TextLabel", {
    Size = UDim2.new(0, 28, 0, 20), Position = UDim2.new(1, -36, 0, 8),
    BackgroundColor3 = COL.element, Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = COL.sub, Text = "K", BorderSizePixel = 0,
}, titleBar)
round(keyChip, 6)
make("Frame", {
    Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 0, 36),
    BackgroundColor3 = COL.stroke, BorderSizePixel = 0,
}, main)

-- tabs
local pages, tabs = {}, {}
local selectTab

local TAB_COUNT = 7
local function makeTab(name, order)
    local m, gap = 8, 5
    local w = (380 - m * 2 - gap * (TAB_COUNT - 1)) / TAB_COUNT
    local btn = make("TextButton", {
        Size = UDim2.new(0, w, 0, 26),
        Position = UDim2.new(0, m + (order - 1) * (w + gap), 0, 44),
        BackgroundColor3 = COL.element, Font = Enum.Font.GothamMedium, TextSize = 10,
        TextColor3 = COL.sub, Text = name, AutoButtonColor = false, BorderSizePixel = 0,
    }, main)
    round(btn, 7)
    local page = make("Frame", {
        Size = UDim2.new(1, -24, 1, -88), Position = UDim2.new(0, 12, 0, 80),
        BackgroundTransparency = 1, Visible = false,
    }, main)
    pages[name], tabs[name] = page, btn
    connect(btn.MouseButton1Click, function()
        click()
        selectTab(name)
    end)
    return page
end

local speedPage = makeTab("Speed", 1)
local gravPage = makeTab("Gravity", 2)
local espPage = makeTab("ESP", 3)
local hitboxPage = makeTab("Hitbox", 4)
local playerPage = makeTab("Player", 5)
local flyPage = makeTab("Fly", 6)
local toolsPage = makeTab("Tools", 7)

function selectTab(name)
    for n, page in pairs(pages) do
        local active = n == name
        page.Visible = active
        tween(tabs[n], {
            BackgroundColor3 = active and COL.accent or COL.element,
            TextColor3 = active and Color3.new(1, 1, 1) or COL.sub,
        })
    end
end

-- reusable widgets
local function row(parent, y, text)
    return make("TextLabel", {
        Size = UDim2.new(1, -60, 0, 22), Position = UDim2.new(0, 0, 0, y),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = COL.text, Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function makeSwitch(parent, y, initial, onChanged)
    local btn = make("TextButton", {
        Size = UDim2.new(0, 40, 0, 22), Position = UDim2.new(1, -40, 0, y),
        BackgroundColor3 = initial and COL.on or COL.off,
        Text = "", AutoButtonColor = false, BorderSizePixel = 0,
    }, parent)
    round(btn, 11)
    local knob = make("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = initial and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, btn)
    round(knob, 8)
    local state = initial
    local function render()
        tween(btn, {BackgroundColor3 = state and COL.on or COL.off})
        tween(knob, {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)})
    end
    local function toggle()
        click()
        state = not state
        render()
        onChanged(state)
    end
    connect(btn.MouseButton1Click, toggle)
    -- returns: setter to sync visuals without firing the callback, and toggle (same as clicking)
    return function(newState)
        if newState ~= state then state = newState render() end
    end, toggle
end

-- ========== SPEED TAB ==========
local speedEnabled = false
row(speedPage, 0, "CFrame movement [C]")
local setSpeedSwitch, toggleSpeed = makeSwitch(speedPage, 0, false, function(on) speedEnabled = on end)

row(speedPage, 36, "Speed (0-99999)")
local speedBox = make("TextBox", {
    Size = UDim2.new(0, 78, 0, 26), Position = UDim2.new(1, -78, 0, 34),
    BackgroundColor3 = COL.element, Font = Enum.Font.Gotham, TextSize = 13,
    TextColor3 = COL.text, PlaceholderText = "speed", PlaceholderColor3 = COL.sub,
    ClearTextOnFocus = false, BorderSizePixel = 0,
}, speedPage)
round(speedBox, 6)
local currentLbl = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 72),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = COL.sub, TextXAlignment = Enum.TextXAlignment.Left,
}, speedPage)

local function updateSpeedUI()
    currentLbl.Text = "Current: " .. _G.CFrameSpeed
    if not speedBox:IsFocused() then speedBox.Text = tostring(_G.CFrameSpeed) end
end
updateSpeedUI()

connect(speedBox.FocusLost, function()
    local n = tonumber(speedBox.Text)
    if n then _G.CFrameSpeed = math.clamp(n, 0, 99999) end
    updateSpeedUI()
end)

-- movement
local keys = {W = false, A = false, S = false, D = false, Up = false, Down = false}

connect(UIS.InputBegan, function(i, g)
    if not g and keys[i.KeyCode.Name] ~= nil then keys[i.KeyCode.Name] = true end
end)
connect(UIS.InputEnded, function(i)
    if keys[i.KeyCode.Name] ~= nil then keys[i.KeyCode.Name] = false end
end)

connect(player.CharacterAdded, function(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
    for k in pairs(keys) do keys[k] = false end
    updateSpeedUI()
end)

connect(RunService.RenderStepped, function()
    if not speedEnabled then return end
    if not hrp or not hrp.Parent then
        char = player.Character or player.CharacterAdded:Wait()
        hrp = char:WaitForChild("HumanoidRootPart")
    end
    local cf = workspace.CurrentCamera.CFrame
    local l, r = cf.LookVector, cf.RightVector
    local fw = Vector3.new(l.X, 0, l.Z).Unit
    local ri = Vector3.new(r.X, 0, r.Z).Unit
    local mv = Vector3.zero
    if keys.W or keys.Up then mv += fw end
    if keys.S or keys.Down then mv -= fw end
    if keys.A then mv -= ri end
    if keys.D then mv += ri end
    if mv.Magnitude > 0 then
        hrp.CFrame += mv.Unit * _G.CFrameSpeed * 0.1
    end
end)

-- ========== GRAVITY TAB ==========
local normalGravity = workspace.Gravity
if normalGravity == 0 then normalGravity = 196.2 end

row(gravPage, 0, "Zero gravity [G]")

row(gravPage, 36, "Gravity (0-500)")
local gravBox = make("TextBox", {
    Size = UDim2.new(0, 78, 0, 26), Position = UDim2.new(1, -78, 0, 34),
    BackgroundColor3 = COL.element, Font = Enum.Font.Gotham, TextSize = 13,
    TextColor3 = COL.text, PlaceholderText = "gravity", PlaceholderColor3 = COL.sub,
    ClearTextOnFocus = false, BorderSizePixel = 0,
}, gravPage)
round(gravBox, 6)

local gravLbl = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 72),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = COL.sub, TextXAlignment = Enum.TextXAlignment.Left,
}, gravPage)

local function updateGravUI()
    gravLbl.Text = ("Current: %.1f"):format(workspace.Gravity)
    if not gravBox:IsFocused() then gravBox.Text = ("%g"):format(workspace.Gravity) end
end

local setGravSwitch, toggleGrav = makeSwitch(gravPage, 0, workspace.Gravity == 0, function(on)
    if on then
        if workspace.Gravity ~= 0 then normalGravity = workspace.Gravity end
        workspace.Gravity = 0
    else
        workspace.Gravity = normalGravity
    end
end)

connect(gravBox.FocusLost, function()
    local n = tonumber(gravBox.Text)
    if n then workspace.Gravity = math.clamp(n, 0, 500) end
    updateGravUI()
end)

connect(workspace:GetPropertyChangedSignal("Gravity"), function()
    if workspace.Gravity ~= 0 then normalGravity = workspace.Gravity end
    setGravSwitch(workspace.Gravity == 0)
    updateGravUI()
end)
updateGravUI()

-- ========== ESP TAB ==========
local espEnabled = false
local drawingOk = (Drawing ~= nil) -- Drawing is an executor feature; guard so the hub still loads without it
local espObjects = {} -- [player] = { box, name }

row(espPage, 0, "Box ESP")
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 36),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = COL.sub, TextXAlignment = Enum.TextXAlignment.Left,
    Text = drawingOk and "Draws a box + name over players" or "Unavailable: no Drawing API",
}, espPage)

local function newDrawing(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function espHide(o)
    o.box.Visible = false
    o.name.Visible = false
end

local function espAdd(plr)
    if not drawingOk or plr == player or espObjects[plr] then return end
    espObjects[plr] = {
        box = newDrawing("Square", {Thickness = 1.5, Color = COL.on, Filled = false, Visible = false}),
        name = newDrawing("Text", {Size = 13, Center = true, Outline = true, Color = Color3.new(1, 1, 1), Visible = false}),
    }
end

local function espRemove(plr)
    local o = espObjects[plr]
    if not o then return end
    o.box:Remove()
    o.name:Remove()
    espObjects[plr] = nil
end

for _, plr in ipairs(Players:GetPlayers()) do espAdd(plr) end
connect(Players.PlayerAdded, espAdd)
connect(Players.PlayerRemoving, espRemove)

local setEspSwitch, toggleEsp = makeSwitch(espPage, 0, false, function(on)
    espEnabled = on and drawingOk
    if not espEnabled then
        for _, o in pairs(espObjects) do espHide(o) end
    end
end)

connect(RunService.RenderStepped, function()
    if not espEnabled then return end
    local camera = workspace.CurrentCamera
    for plr, o in pairs(espObjects) do
        local ch = plr.Character
        local rootPart = ch and ch:FindFirstChild("HumanoidRootPart")
        local head = ch and ch:FindFirstChild("Head")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if rootPart and head and hum and hum.Health > 0 then
            local topPos = head.Position + Vector3.new(0, 0.5, 0)
            local botPos = rootPart.Position - Vector3.new(0, 3, 0)
            local top, onTop = camera:WorldToViewportPoint(topPos)
            local bot = camera:WorldToViewportPoint(botPos)
            if onTop then
                local height = math.abs(bot.Y - top.Y)
                local width = height * 0.5
                o.box.Size = Vector2.new(width, height)
                o.box.Position = Vector2.new(top.X - width / 2, top.Y)
                o.box.Visible = true
                local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
                o.name.Text = string.format("%s [%dm]", plr.Name, math.floor(dist))
                o.name.Position = Vector2.new(top.X, top.Y - 16)
                o.name.Visible = true
            else
                espHide(o)
            end
        else
            espHide(o)
        end
    end
end)

-- ========== HITBOX TAB ==========
local hitboxEnabled = false
local hitboxVisible = true -- true = 25% visible red box (test), false = invisible
local hitboxSize = 5
local HITBOX_COLOR = Color3.fromRGB(255, 40, 40)
local hbOriginals = {} -- [hrp] = {Size, Transparency, Color, CanCollide, Massless}

local function hbStore(hrp)
    if hbOriginals[hrp] then return end
    hbOriginals[hrp] = {
        Size = hrp.Size, Transparency = hrp.Transparency, Color = hrp.Color,
        CanCollide = hrp.CanCollide, Massless = hrp.Massless,
    }
end

local function hbRestoreAll()
    for hrp, o in pairs(hbOriginals) do
        if hrp and hrp.Parent then
            hrp.Size = o.Size
            hrp.Transparency = o.Transparency
            hrp.Color = o.Color
            hrp.CanCollide = o.CanCollide
            hrp.Massless = o.Massless
        end
    end
    hbOriginals = {}
end

row(hitboxPage, 0, "Hitbox extender")
local setHbSwitch, toggleHb = makeSwitch(hitboxPage, 0, false, function(on)
    hitboxEnabled = on
    if not on then hbRestoreAll() end -- turning off snaps every hitbox back to normal
end)

row(hitboxPage, 36, "Show box (25%)")
local setHbVis, toggleHbVis = makeSwitch(hitboxPage, 36, true, function(on)
    hitboxVisible = on -- on = 25% visible, off = invisible
end)

row(hitboxPage, 72, "Size (1-10)")
local hbBox = make("TextBox", {
    Size = UDim2.new(0, 78, 0, 26), Position = UDim2.new(1, -78, 0, 70),
    BackgroundColor3 = COL.element, Font = Enum.Font.Gotham, TextSize = 13,
    TextColor3 = COL.text, Text = tostring(hitboxSize), PlaceholderText = "size",
    PlaceholderColor3 = COL.sub, ClearTextOnFocus = false, BorderSizePixel = 0,
}, hitboxPage)
round(hbBox, 6)

connect(hbBox.FocusLost, function()
    local n = tonumber(hbBox.Text)
    if n then hitboxSize = math.clamp(n, 1, 10) end
    hbBox.Text = tostring(hitboxSize)
end)

connect(RunService.Heartbeat, function()
    if not hitboxEnabled then return end
    local sizeVec = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    local tp = hitboxVisible and 0.75 or 1
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local ch = plr.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then
                hbStore(hrp)
                -- only rewrite physical props when they actually differ, so we don't
                -- churn the physics assembly (that's what froze characters before)
                if hrp.Size ~= sizeVec then hrp.Size = sizeVec end
                if hrp.CanCollide then hrp.CanCollide = false end
                hrp.Transparency = tp
                hrp.Color = HITBOX_COLOR
            end
        end
    end
end)

-- ========== PLAYER TAB ==========

local function findPlayer(txt)
    txt = (txt or ""):lower()
    if txt == "" then return nil end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and (
            p.Name:lower():sub(1, #txt) == txt or
            p.DisplayName:lower():sub(1, #txt) == txt
        ) then
            return p
        end
    end
end

local playerMainRow = make("TextLabel", {
    Size = UDim2.new(1, -10, 0, 28),
    Position = UDim2.new(0, 5, -0.085, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = COL.text,
    Text = "Player name",
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextScaled = true,
    TextWrapped = false,
}, playerPage)


local playerBox = make("TextBox", {
    Size = UDim2.new(1, 0, 0, 28),
    Position = UDim2.new(0, 0, 0, 26),
    BackgroundColor3 = COL.element,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = COL.text,
    PlaceholderText = "name or display name",
    PlaceholderColor3 = COL.sub,
    ClearTextOnFocus = false,
    BorderSizePixel = 0,
    Text = "",
}, playerPage)

round(playerBox, 6)

local selectedPlayer = nil

playerBox.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end

    local found = findPlayer(playerBox.Text)

    if found then
        selectedPlayer = found

	playerMainRow.Text = string.format(
    	"Player: %s, Username: %s, ID: %s",
    	found.DisplayName,
    	found.Name,
    	found.UserId
	)

        playerBox.Text = found.Name
    else
        selectedPlayer = nil
        playerMainRow.Text = "Player: Not found"
    end
end)

local tpBtn = make("TextButton", {
    Size = UDim2.new(0.5, -4, 0, 28), Position = UDim2.new(0, 0, 0, 62),
    BackgroundColor3 = COL.accent, Font = Enum.Font.GothamMedium, TextSize = 13,
    TextColor3 = Color3.new(1, 1, 1), Text = "Teleport", AutoButtonColor = false, BorderSizePixel = 0,
}, playerPage)
round(tpBtn, 6)

local specBtn = make("TextButton", {
    Size = UDim2.new(0.5, -4, 0, 28), Position = UDim2.new(0.5, 4, 0, 62),
    BackgroundColor3 = COL.accent, Font = Enum.Font.GothamMedium, TextSize = 13,
    TextColor3 = Color3.new(1, 1, 1), Text = "Spectate", AutoButtonColor = false, BorderSizePixel = 0,
}, playerPage)
round(specBtn, 6)

local playerStatus = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 96),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = COL.sub, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
}, playerPage)

connect(tpBtn.MouseButton1Click, function()
    click()
    local target = findPlayer(playerBox.Text)
    if not target then playerStatus.Text = "Player not found" return end
    local thrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local mychar = player.Character
    local myhrp = mychar and mychar:FindFirstChild("HumanoidRootPart")
    if thrp and myhrp then
        myhrp.CFrame = thrp.CFrame + Vector3.new(0, 0, 3)
        playerStatus.Text = "Teleported to " .. target.Name
    else
        playerStatus.Text = "No character to teleport to"
    end
end)

local spectating = nil
connect(specBtn.MouseButton1Click, function()
    click()
    local cam = workspace.CurrentCamera
    if spectating then
        local myhum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if myhum then cam.CameraSubject = myhum end
        spectating = nil
        specBtn.Text = "Spectate"
        playerStatus.Text = "Stopped spectating"
    else
        local target = findPlayer(playerBox.Text)
        if not target then playerStatus.Text = "Player not found" return end
        local thum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        if thum then
            cam.CameraSubject = thum
            spectating = target
            specBtn.Text = "Stop Spec"
            playerStatus.Text = "Spectating " .. target.Name
        else
            playerStatus.Text = "No character to spectate"
        end
    end
end)

-- ========== FLY TAB ==========
-- (adapted from the standalone sfly build: gyro/velocity flight, bobbing hover,
--  inertia slide, superman pitch/roll, custom fly animations)
local flyEnabled = false
local flightSpeed = 50
local FLY_MAX_SPEED = 9842774
local flyKey = Enum.KeyCode.X
local awaitingFlyKey = false
local flyConns = {}
local flyGyro, flyVel
local flyMove = {forward = 0, backward = 0, left = 0, right = 0}
local flyCurrentVel = Vector3.zero
local flyCurrentCF = nil
local flyRoll = 0
local flyLerp = 0.1
local flyBobFreq, flyBobAmp = 1, 0.5
local flyAnimTrack = nil
local FLY_IDLE_ANIM = 10714347256
local FLY_FWD_ANIM = 10714177846

local function flySetAnimate(disabled)
    local ch = player.Character
    local a = ch and ch:FindFirstChild("Animate")
    if a then a.Disabled = disabled end
end

local function flyPlayAnim(animId, startTime, spd)
    local ch = player.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if flyAnimTrack then flyAnimTrack:Stop(0.1) flyAnimTrack = nil end
    flySetAnimate(true)
    for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do tr:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(animId)
    local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
    if ok and track then
        flyAnimTrack = track
        track:Play()
        track.TimePosition = startTime
        track:AdjustSpeed(spd)
    end
end

local function flyStopAnim()
    if flyAnimTrack then flyAnimTrack:Stop(0.1) flyAnimTrack = nil end
    flySetAnimate(false)
    local ch = player.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then
        for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do tr:Stop() end
    end
end

local function startFly()
    local ch = player.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    hum.PlatformStand = true
    flyPlayAnim(FLY_IDLE_ANIM, 4, 0)

    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "FlyGyro"
    flyGyro.P = 90000
    flyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyGyro.CFrame = root.CFrame
    flyGyro.Parent = root

    flyVel = Instance.new("BodyVelocity")
    flyVel.Name = "FlyVelocity"
    flyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyVel.Velocity = Vector3.new(0, 0.1, 0)
    flyVel.Parent = root

    flyCurrentVel = Vector3.zero
    flyCurrentCF = nil

    local upd = RunService.RenderStepped:Connect(function()
        if not flyGyro or not flyVel then return end
        local cam = workspace.CurrentCamera
        local fwd = flyMove.forward - flyMove.backward
        local side = flyMove.right - flyMove.left
        local inputVec = (cam.CFrame.LookVector * fwd) + (cam.CFrame.RightVector * side)
        if fwd ~= 0 then inputVec = inputVec + Vector3.new(0, 0.2 * fwd, 0) end
        local bobbing = math.sin(tick() * flyBobFreq) * flyBobAmp
        local desired = Vector3.zero
        if inputVec.Magnitude > 0 then
            desired = inputVec.Unit * flightSpeed
        else
            desired = Vector3.new(0, bobbing, 0)
        end
        flyCurrentVel = flyCurrentVel:Lerp(desired, 0.1)
        flyVel.Velocity = flyCurrentVel
        local desiredCF
        if fwd > 0 then
            desiredCF = cam.CFrame * CFrame.Angles(math.rad(-90), 0, math.rad(flyRoll))
        else
            desiredCF = cam.CFrame * CFrame.Angles(math.rad(-45 * fwd), 0, math.rad(flyRoll))
        end
        if flyCurrentCF then
            flyCurrentCF = flyCurrentCF:Lerp(desiredCF, flyLerp)
        else
            flyCurrentCF = desiredCF
        end
        flyGyro.CFrame = flyCurrentCF
    end)
    table.insert(flyConns, upd)

    local began = UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local k = i.KeyCode
        if k == Enum.KeyCode.W then flyMove.forward = 1 flyPlayAnim(FLY_FWD_ANIM, 4.65, 0)
        elseif k == Enum.KeyCode.S then flyMove.backward = 1 flyPlayAnim(FLY_IDLE_ANIM, 4, 0)
        elseif k == Enum.KeyCode.A then flyMove.left = 1 if flyMove.forward > 0 then flyPlayAnim(FLY_FWD_ANIM, 4.65, 0) end
        elseif k == Enum.KeyCode.D then flyMove.right = 1 if flyMove.forward > 0 then flyPlayAnim(FLY_FWD_ANIM, 4.65, 0) end
        end
    end)
    table.insert(flyConns, began)

    local ended = UIS.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local k = i.KeyCode
        if k == Enum.KeyCode.W then flyMove.forward = 0 flyPlayAnim(FLY_IDLE_ANIM, 4, 0)
        elseif k == Enum.KeyCode.S then flyMove.backward = 0 flyPlayAnim(FLY_IDLE_ANIM, 4, 0)
        elseif k == Enum.KeyCode.A then flyMove.left = 0 if flyMove.forward > 0 then flyPlayAnim(FLY_FWD_ANIM, 4.65, 0) end
        elseif k == Enum.KeyCode.D then flyMove.right = 0 if flyMove.forward > 0 then flyPlayAnim(FLY_FWD_ANIM, 4.65, 0) end
        end
    end)
    table.insert(flyConns, ended)
end

local function stopFly()
    local ch = player.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    flyStopAnim()
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if root then
        local g = root:FindFirstChild("FlyGyro") if g then g:Destroy() end
        local v = root:FindFirstChild("FlyVelocity") if v then v:Destroy() end
    end
    flyGyro, flyVel = nil, nil
    for _, c in ipairs(flyConns) do if c.Connected then c:Disconnect() end end
    flyConns = {}
    flyMove = {forward = 0, backward = 0, left = 0, right = 0}
end

-- UI
row(flyPage, 0, "Fly")
local setFlySwitch, toggleFly = makeSwitch(flyPage, 0, false, function(on)
    flyEnabled = on
    if on then startFly() else stopFly() end
end)

row(flyPage, 36, "Speed (0-9842774)")
local flyBox = make("TextBox", {
    Size = UDim2.new(0, 90, 0, 26), Position = UDim2.new(1, -90, 0, 34),
    BackgroundColor3 = COL.element, Font = Enum.Font.Gotham, TextSize = 13,
    TextColor3 = COL.text, Text = tostring(flightSpeed), PlaceholderText = "speed",
    PlaceholderColor3 = COL.sub, ClearTextOnFocus = false, BorderSizePixel = 0,
}, flyPage)
round(flyBox, 6)
connect(flyBox.FocusLost, function()
    local n = tonumber(flyBox.Text)
    if n then flightSpeed = math.clamp(n, 0, FLY_MAX_SPEED) end
    flyBox.Text = tostring(flightSpeed)
end)

-- shared !sfly command action: "!sfly" toggles fly; "!sfly <n>" sets speed and turns it on
local function doSfly(arg)
    local n = tonumber(arg)
    if n then
        flightSpeed = math.clamp(n, 0, FLY_MAX_SPEED)
        flyBox.Text = tostring(flightSpeed)
        if not flyEnabled then toggleFly() end
    else
        toggleFly()
    end
end

row(flyPage, 72, "Toggle key")
local flyKeyBtn = make("TextButton", {
    Size = UDim2.new(0, 90, 0, 26), Position = UDim2.new(1, -90, 0, 70),
    BackgroundColor3 = COL.element, Font = Enum.Font.GothamMedium, TextSize = 12,
    TextColor3 = COL.text, Text = flyKey.Name, AutoButtonColor = false, BorderSizePixel = 0,
}, flyPage)
round(flyKeyBtn, 6)
connect(flyKeyBtn.MouseButton1Click, function()
    click()
    awaitingFlyKey = true
    flyKeyBtn.Text = "press key"
end)

-- global handler: capture a new toggle key when rebinding, otherwise fire the toggle
connect(UIS.InputBegan, function(i, gp)
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if awaitingFlyKey then
        local kc = i.KeyCode
        local ignore = {
            Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
            Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl,
            Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt, Enum.KeyCode.Unknown,
        }
        for _, m in ipairs(ignore) do if kc == m then return end end
        awaitingFlyKey = false
        flyKey = kc
        flyKeyBtn.Text = kc.Name
        return
    end
    if gp then return end
    if i.KeyCode == flyKey then toggleFly() end
end)

-- stop flying cleanly on respawn (old body objects die with the old character)
connect(player.CharacterAdded, function()
    if flyEnabled then
        flyEnabled = false
        setFlySwitch(false)
        stopFly()
    end
end)

-- ========== TOOLS TAB ==========
-- scrolling list of placeholder buttons (10 don't fit in the panel, so it scrolls)
local toolsScroll = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = COL.sub,
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, toolsPage)
local toolsLayout = make("UIListLayout", {
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
}, toolsScroll)

-- add a tool by giving it a name + run function; unset slots stay placeholders
local toolDefs = {
    [1] = {name = "Jerk off", run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/mckenziii/The-Twink-Community-Hub/refs/heads/main/Tools/jerkoff.lua"))()
    end},
}


for i = 1, 10 do
    local def = toolDefs[i]
    local b = make("TextButton", {
        Size = UDim2.new(1, -6, 0, 28),
        BackgroundColor3 = COL.element, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = COL.text, Text = def and def.name or ("Tool " .. i), AutoButtonColor = true,
        BorderSizePixel = 0, LayoutOrder = i,
    }, toolsScroll)
    round(b, 6)
    connect(b.MouseButton1Click, function()
        click()
        if def and def.run then
            local ok, err = pcall(def.run)
            if not ok then warn("[Tools] " .. tostring(def.name) .. " failed: " .. tostring(err)) end
        end
    end)
end

-- keep the scroll canvas sized to the button list
local function sizeToolsCanvas()
    toolsScroll.CanvasSize = UDim2.new(0, 0, 0, toolsLayout.AbsoluteContentSize.Y + 6)
end
connect(toolsLayout:GetPropertyChangedSignal("AbsoluteContentSize"), sizeToolsCanvas)
sizeToolsCanvas()

-- ========== DRAGGING ==========
do
    local drag, start, pos
    connect(titleBar.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            start = i.Position
            pos = main.Position
        end
    end)
    connect(UIS.InputChanged, function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - start
            main.Position = UDim2.new(0, pos.X.Offset + d.X, 0, pos.Y.Offset + d.Y)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
end

-- ========== KEYBINDS ==========
-- wired last, after every toggle exists: K = hide/show, C = cframe speed, G = zero gravity
connect(UIS.InputBegan, function(i, g)
    if g or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if i.KeyCode == TOGGLE_KEY then
        main.Visible = not main.Visible
    elseif i.KeyCode == SPEED_KEY then
        toggleSpeed()
    elseif i.KeyCode == GRAV_KEY then
        toggleGrav()
    end
end)

selectTab("Speed")

-- version tag (bottom-right) so you can tell which copy is running
make("TextLabel", {
    Size = UDim2.new(0, 60, 0, 12), Position = UDim2.new(1, -66, 1, -16),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = COL.sub, Text = VERSION, TextXAlignment = Enum.TextXAlignment.Right,
}, main)

-- unload button (just left of the version tag) — fully removes the script
local unloadBtn = make("TextButton", {
    Size = UDim2.new(0, 58, 0, 18), Position = UDim2.new(1, -132, 1, -22),
    BackgroundColor3 = COL.on, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextColor3 = Color3.new(1, 1, 1), Text = "Unload", AutoButtonColor = false, BorderSizePixel = 0,
}, main)
round(unloadBtn, 5)
connect(unloadBtn.MouseButton1Click, function()
    click()
    if _G.ScriptHubCleanup then _G.ScriptHubCleanup() end
end)

connect(player.Chatted, function(msg)
    if msg:sub(1, 1) ~= "!" then return end

    local cmd, arg = msg:sub(2):match("^(%S+)%s*(.-)$")
    if not cmd then return end

    cmd = cmd:lower()


    -- =========================
    -- COMMAND BAR
    -- =========================
    if cmd == "cmdbar" then

        if gui:FindFirstChild("CmdBar") then
            gui.CmdBar:Destroy()
            return
        end

        local cmdGui = make("Frame", {
            Name = "CmdBar",
            Size = UDim2.new(0, 420, 0, 45),
            Position = UDim2.new(0.5, -210, 1, -80),
            BackgroundColor3 = COL.bg,
            BorderSizePixel = 0,
        }, gui)

        round(cmdGui, 10)

        make("UIStroke", {
            Color = COL.stroke,
            Thickness = 1
        }, cmdGui)


        local box = make("TextBox", {
            Size = UDim2.new(1, -20, 1, -10),
            Position = UDim2.new(0, 10, 0, 5),

            BackgroundColor3 = COL.element,

            Font = Enum.Font.Gotham,
            TextSize = 14,

            TextColor3 = COL.text,

            PlaceholderText = "!command player",
            PlaceholderColor3 = COL.sub,

            ClearTextOnFocus = false,

            BorderSizePixel = 0,
        }, cmdGui)

        round(box, 7)


        box.FocusLost:Connect(function(enter)

            if not enter then return end

            local input = box.Text
            box.Text = ""

            if input == "" then return end


            if input:sub(1,1) ~= "!" then
                input = "!" .. input
            end


            local c, a = input:sub(2):match("^(%S+)%s*(.-)$")

            if not c then return end

            c = c:lower()



            -- =========================
            -- CMD BAR COMMANDS
            -- =========================

            if c == "tp" then

                local target = findPlayer(a)

                if target then
                    local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                    local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

                    if targetHRP and myHRP then
                        myHRP.CFrame = targetHRP.CFrame + Vector3.new(0,0,3)
                    end
                end

                elseif c == "help" then

    if gui:FindFirstChild("HelpUI") then
        gui.HelpUI:Destroy()
        return
    end

    local help = make("Frame", {
        Name = "HelpUI",
        Size = UDim2.new(0, 360, 0, 420),
        Position = UDim2.new(0.5, -180, 0.5, -210),
        BackgroundColor3 = COL.bg,
        BorderSizePixel = 0,
        Active = true,
    }, gui)

    round(help, 10)

    make("UIStroke", {
        Color = COL.stroke,
        Thickness = 1
    }, help)


    local title = make("TextLabel", {
        Size = UDim2.new(1, -40, 0, 35),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = COL.text,
        Text = "Twink Hub Commands",
        TextXAlignment = Enum.TextXAlignment.Left,
    }, help)


    local close = make("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = COL.on,
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
    }, help)

    round(close, 6)

    close.MouseButton1Click:Connect(function()
        help:Destroy()
    end)


    local scroll = make("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -55),
        Position = UDim2.new(0, 10, 0, 45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0,0,0,0),
    }, help)


    local commands = {
        "!tp <player>",
        "!sp <player>",
        "!unsp",
        "!sfly <speed>",
        "!cmdbar",
        "!help",
        "!runcode <lua>",
        "!lua <lua>",
    }


    local y = 5

    for _, text in ipairs(commands) do

        local label = make("TextLabel", {
            Size = UDim2.new(1, -10, 0, 28),
            Position = UDim2.new(0, 5, 0, y),
            BackgroundColor3 = COL.element,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = COL.text,
            Text = text,
            BorderSizePixel = 0,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, scroll)

        round(label, 6)

        y += 33
    end

    scroll.CanvasSize = UDim2.new(0,0,0,y)



            elseif c == "sp" then

                local target = findPlayer(a)

                if target then
                    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")

                    if hum then
                        workspace.CurrentCamera.CameraSubject = hum
                    end
                end

			elseif c == "runcode" or c == "lua" then

    			if not loadstring then
    	    			warn("loadstring is not available")
    	    		return
    			end

    			local code = a

    			if not code or code == "" then
    	    		warn("No code provided")
    	    		return
    			end

    			local fn, err = loadstring(code)

    			if not fn then
    			    warn("Load error:", err)
    			    return
    			end

    			local success, result = pcall(fn)

    			if not success then
    			    warn("Runtime error:", result)
    			    return
    			end



            elseif c == "unsp" then

                local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

                if myHum then
                    workspace.CurrentCamera.CameraSubject = myHum
                end

            elseif c == "sfly" then

                doSfly(a)

            end
        end)


        box:CaptureFocus()



    -- =========================
    -- TELEPORT
    -- =========================
    elseif cmd == "tp" then

        local target = findPlayer(arg)

        if target then
            local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

            if targetHRP and myHRP then
                myHRP.CFrame = targetHRP.CFrame + Vector3.new(0,0,3)
            end
        end



    -- =========================
    -- SPECTATE
    -- =========================
    elseif cmd == "sp" then

        if arg ~= "" then

            local target = findPlayer(arg)

            if target then
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")

                if hum then
                    workspace.CurrentCamera.CameraSubject = hum
                end
            end

        else

            local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

            if myHum then
                workspace.CurrentCamera.CameraSubject = myHum
            end

        end

    elseif cmd == "help" then

    if gui:FindFirstChild("HelpUI") then
        gui.HelpUI:Destroy()
        return
    end

    local help = make("Frame", {
        Name = "HelpUI",
        Size = UDim2.new(0, 360, 0, 420),
        Position = UDim2.new(0.5, -180, 0.5, -210),
        BackgroundColor3 = COL.bg,
        BorderSizePixel = 0,
        Active = true,
    }, gui)

    round(help, 10)

    make("UIStroke", {
        Color = COL.stroke,
        Thickness = 1
    }, help)


    local title = make("TextLabel", {
        Size = UDim2.new(1, -40, 0, 35),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = COL.text,
        Text = "Twink Hub Commands",
        TextXAlignment = Enum.TextXAlignment.Left,
    }, help)


    local close = make("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = COL.on,
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
    }, help)

    round(close, 6)

    close.MouseButton1Click:Connect(function()
        help:Destroy()
    end)



    local scroll = make("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -55),
        Position = UDim2.new(0, 10, 0, 45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0,0,0,0),
    }, help)


    local commands = {
        "!tp <player> - Teleport to player",
        "!sp <player> - Spectate player",
        "!unsp - Stop spectating",
        "!sfly <speed> - Toggle fly / set fly speed",
        "!cmdbar - Open command bar",
        "!help - Open this menu",
        "!runcode <lua> - Execute Lua code",
        "!lua <lua> - Execute Lua code",
    }


    local y = 5

    for _, text in ipairs(commands) do

        local label = make("TextLabel", {
            Size = UDim2.new(1, -10, 0, 28),
            Position = UDim2.new(0, 5, 0, y),
            BackgroundColor3 = COL.element,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = COL.text,
            Text = text,
            BorderSizePixel = 0,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, scroll)

        round(label, 6)

        y += 33
    end

    scroll.CanvasSize = UDim2.new(0,0,0,y)



    -- DRAGGING
    local dragging = false
    local dragStart
    local startPos

    title.InputBegan:Connect(function(input)

        if input.UserInputType == Enum.UserInputType.MouseButton1 then

            dragging = true
            dragStart = input.Position
            startPos = help.Position

        end
    end)


    UIS.InputChanged:Connect(function(input)

        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then

            local delta = input.Position - dragStart

            help.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )

        end
    end)


    UIS.InputEnded:Connect(function(input)

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end

    end)
    
	elseif cmd == "runcode" or cmd == "lua" then

    	if not loadstring then
    	    warn("loadstring is not available")
    	    return
    	end

    	local code = arg

    	if not code or code == "" then
    	    warn("No code provided")
    	    return
    	end

    	local fn, err = loadstring(code)

    	if not fn then
    	    warn("Load error:", err)
    	    return
    	end

    	local success, result = pcall(fn)

    	if not success then
    	    warn("Runtime error:", result)
    	    return
    	end

    -- =========================
    -- STOP SPECTATE
    -- =========================
    elseif cmd == "unsp" then

        local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

        if myHum then
            workspace.CurrentCamera.CameraSubject = myHum
        end

    elseif cmd == "sfly" then

        doSfly(arg)

    end
end)

_G.ScriptHubCleanup = function()
    for _, c in ipairs(conns) do c:Disconnect() end
    for plr in pairs(espObjects) do espRemove(plr) end
    hbRestoreAll()
    stopFly()
    -- make sure we're not left stuck in someone else's camera
    pcall(function()
        local myhum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if myhum then workspace.CurrentCamera.CameraSubject = myhum end
    end)
    gui:Destroy()
    _G.ScriptHubCleanup = nil
end

-- load notification = proof this version actually ran
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Twink Community Hub",
        Text = VERSION .. " loaded | K hide | C speed | G gravity",
        Duration = 4,
    })
end)