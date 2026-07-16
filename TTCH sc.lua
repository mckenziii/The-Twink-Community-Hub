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
if _G.ScriptHubCleanup then
	pcall(_G.ScriptHubCleanup)
end

local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local VERSION = "Unknown"

local url = "https://raw.githubusercontent.com/mckenziii/The-Twink-Community-Hub/refs/heads/main/version.txt?t="
	.. os.time()

local req = (syn and syn.request) or http_request or request

local response = req({
	Url = url,
	Method = "GET",
})

if response and response.Body then
	VERSION = response.Body:gsub("%s+", "")
end

print("Loaded Version:", VERSION)

local TOGGLE_KEY = Enum.KeyCode.K
local SPEED_KEY = Enum.KeyCode.C
local GRAV_KEY = Enum.KeyCode.G

local waitingForToggleKey = false
local keyChangeCooldown = false

local COL = {
	bg = Color3.fromRGB(24, 25, 31),
	element = Color3.fromRGB(41, 44, 54),
	stroke = Color3.fromRGB(58, 62, 75),
	accent = Color3.fromRGB(99, 120, 255),
	on = Color3.fromRGB(230, 68, 68),
	text = Color3.fromRGB(235, 238, 245),
	sub = Color3.fromRGB(142, 148, 165),
	off = Color3.fromRGB(84, 88, 102),
}

-- ESP drawing colours. Deliberately a separate table from COL: `make` auto-registers any
-- Color3 prop matching a COL role for live re-theming, so putting the ESP name colour
-- (white) in COL would silently capture every Color3.new(1, 1, 1) knob and tab label too.
-- The ESP render loop reads these live each frame, so edits apply with no repaint step.
local ESPCOL = {
	box = Color3.fromRGB(230, 68, 68),
	name = Color3.fromRGB(255, 255, 255),
	skeleton = Color3.fromRGB(230, 68, 68),
}

-- Theming. Any Color3 prop whose value came from COL is remembered here, so changing a
-- role later can restyle every existing instance without touching each call site.
-- themeRefreshers holds redraw callbacks for things whose colour depends on live state
-- (switch on/off, selected tab) and so can't be restored from creation values alone.
local themedRefs = {}
local themeRefreshers = {}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
		if typeof(v) == "Color3" then
			for role, c in pairs(COL) do
				if c == v then
					themedRefs[#themedRefs + 1] = { obj = o, prop = k, role = role }
					break
				end
			end
		end
	end
	o.Parent = parent
	return o
end

local function round(o, r)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function tween(o, props)
	TweenService:Create(o, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ========== GUI ==========
local gui = make("ScreenGui", { Name = "ScriptHub", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

-- toggle click sound (built-in asset, always loads; swap SoundId for any catalog sound)
local clickSound = make("Sound", { SoundId = "rbxasset://sounds/clickfast.wav", Volume = 0.6 }, gui)
local function click()
	clickSound:Play()
end

local main = make("Frame", {
	Size = UDim2.new(0, 380, 0, 254), -- 254 = 210 + a 44px bottom bar (cog / command bar / unload)
	Position = UDim2.new(0, 16, 0.5, -127),
	BackgroundColor3 = COL.bg,
	BorderSizePixel = 0,
	Active = true,
}, gui)
round(main, 10)
make("UIStroke", { Color = COL.stroke, Thickness = 1 }, main)

-- Background image at 25% visibility. Roblox can't show a raw/local image directly, so
-- this resolves one two ways, in order:
--   1) a local image file in your executor's workspace folder (loaded via getcustomasset)
--   2) the uploaded decal id, resolved to its underlying texture
local HUB_IMAGE_FILE = "twinkhub_bg.png" -- put this file in your executor's workspace folder
local HUB_IMAGE_ID = 104049828893869 -- fallback: the uploaded decal

local function resolveHubImage()
	-- 1) local file via the executor
	local getasset = getcustomasset or getsynasset or (syn and syn.getcustomasset)
	if getasset and isfile and isfile(HUB_IMAGE_FILE) then
		local ok, res = pcall(getasset, HUB_IMAGE_FILE)
		if ok and res then
			return res
		end
	end
	-- 2) resolve the decal to its image texture
	local ok, tex = pcall(function()
		local model = game:GetService("InsertService"):LoadAsset(HUB_IMAGE_ID)
		local decal = model:FindFirstChildWhichIsA("Decal", true)
		local texture = decal and decal.Texture
		model:Destroy()
		return texture
	end)
	if ok and tex then
		return tex
	end
	return "rbxassetid://" .. HUB_IMAGE_ID
end

local bgImage = make("ImageLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundTransparency = 1,
	Image = resolveHubImage(),
	ImageTransparency = 0.75, -- 0.75 = 25% visible
	ScaleType = Enum.ScaleType.Crop,
	ZIndex = 0, -- sit behind every other element
}, main)
round(bgImage, 10)

-- title bar
local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, main)
make("TextLabel", {
	Size = UDim2.new(1, -52, 1, 0),
	Position = UDim2.new(0, 12, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = COL.text,
	Text = "The Twink Community Hub",
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local keyChip = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 20),
	Position = UDim2.new(1, -36, 0, 8),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = COL.sub,
	Text = TOGGLE_KEY.Name,
	BorderSizePixel = 0,
	AutoButtonColor = false,
}, titleBar)

round(keyChip, 6)

connect(keyChip.MouseButton1Click, function()
	if waitingForToggleKey then
		return
	end

	waitingForToggleKey = true
	keyChip.Text = "..."

	local bind
	bind = UIS.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			TOGGLE_KEY = input.KeyCode
			keyChip.Text = TOGGLE_KEY.Name

			waitingForToggleKey = false
			keyChangeCooldown = true

			bind:Disconnect()

			task.delay(0.25, function()
				keyChangeCooldown = false
			end)
		end
	end)
end)

make("Frame", {
	Size = UDim2.new(1, -16, 0, 1),
	Position = UDim2.new(0, 8, 0, 36),
	BackgroundColor3 = COL.stroke,
	BorderSizePixel = 0,
}, main)

-- tabs live in a horizontal scroll strip, so adding tabs never shrinks the existing ones
local pages, tabs = {}, {}
local selectTab
local currentTab

local TAB_WIDTH = 62

local tabStrip = make("ScrollingFrame", {
	Size = UDim2.new(1, -16, 0, 30),
	Position = UDim2.new(0, 8, 0, 44),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = COL.sub,
	ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(0, 0, 0, 0),
}, main)

local tabLayout = make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabStrip)

local tabOrder = 0
local function makeTab(name)
	tabOrder += 1
	local btn = make("TextButton", {
		Size = UDim2.new(0, TAB_WIDTH, 0, 26),
		BackgroundColor3 = COL.element,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = COL.sub,
		Text = name,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = tabOrder,
	}, tabStrip)
	round(btn, 7)
	local page = make("Frame", {
		Size = UDim2.new(1, -24, 1, -132), -- keeps the 122px page height; the extra goes to the bottom bar
		Position = UDim2.new(0, 12, 0, 80),
		BackgroundTransparency = 1,
		Visible = false,
	}, main)
	pages[name], tabs[name] = page, btn
	connect(btn.MouseButton1Click, function()
		click()
		selectTab(name)
	end)
	return page
end

local speedPage = makeTab("Speed")
local gravPage = makeTab("Gravity")
local espPage = makeTab("ESP")
local hitboxPage = makeTab("Hitbox")
local playerPage = makeTab("Player")
local flyPage = makeTab("Fly")
local movePage = makeTab("Movement")
-- the World tab holds ALL its state (page, funcs, originals) in this one table:
-- the chunk is near Lua's 200-local-per-function cap, so it can't spare loose locals
local world = {}
world.page = makeTab("World")
local toolsPage = makeTab("Tools")

-- keep the strip's canvas as wide as the tab row
local function sizeTabCanvas()
	tabStrip.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X, 0, 0)
end
connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), sizeTabCanvas)
sizeTabCanvas()

-- the wheel only drives CanvasPosition.Y by default, so map it sideways here
connect(tabStrip.InputChanged, function(i)
	if i.UserInputType == Enum.UserInputType.MouseWheel then
		local maxX = math.max(tabStrip.CanvasSize.X.Offset - tabStrip.AbsoluteSize.X, 0)
		local x = math.clamp(tabStrip.CanvasPosition.X - i.Position.Z * 40, 0, maxX)
		tabStrip.CanvasPosition = Vector2.new(x, 0)
	end
end)

function selectTab(name)
	currentTab = name
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
		Size = UDim2.new(1, -60, 0, 22),
		Position = UDim2.new(0, 0, 0, y),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = COL.text,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end

local function makeSwitch(parent, y, initial, onChanged)
	local btn = make("TextButton", {
		Size = UDim2.new(0, 40, 0, 22),
		Position = UDim2.new(1, -40, 0, y),
		BackgroundColor3 = initial and COL.on or COL.off,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, parent)
	round(btn, 11)
	local knob = make("Frame", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = initial and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, btn)
	round(knob, 8)
	local state = initial
	local function render()
		tween(btn, { BackgroundColor3 = state and COL.on or COL.off })
		tween(knob, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) })
	end
	themeRefreshers[#themeRefreshers + 1] = render -- re-assert on/off colour after a theme change
	local function toggle()
		click()
		state = not state
		render()
		onChanged(state)
	end
	connect(btn.MouseButton1Click, toggle)
	-- returns: setter to sync visuals without firing the callback, and toggle (same as clicking)
	return function(newState)
		if newState ~= state then
			state = newState
			render()
		end
	end, toggle
end

-- ========== SPEED TAB ==========
-- Scoped; `Speed` below is the public surface (_G.CFrameSpeed stays global by design).
local Speed
do

local speedEnabled = false
row(speedPage, 0, "CFrame movement [C]")
local toggleSpeed = select(2, makeSwitch(speedPage, 0, false, function(on)
	speedEnabled = on
end))

row(speedPage, 36, "Speed (0-99999)")
local speedBox = make("TextBox", {
	Size = UDim2.new(0, 78, 0, 26),
	Position = UDim2.new(1, -78, 0, 34),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COL.text,
	PlaceholderText = "speed",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, speedPage)
round(speedBox, 6)
local currentLbl = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.new(0, 0, 0, 72),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = COL.sub,
	TextXAlignment = Enum.TextXAlignment.Left,
}, speedPage)

local function updateSpeedUI()
	currentLbl.Text = "Current: " .. _G.CFrameSpeed
	if not speedBox:IsFocused() then
		speedBox.Text = tostring(_G.CFrameSpeed)
	end
end
updateSpeedUI()

connect(speedBox.FocusLost, function()
	local n = tonumber(speedBox.Text)
	if n then
		_G.CFrameSpeed = math.clamp(n, 0, 99999)
	end
	updateSpeedUI()
end)

-- movement
local keys = { W = false, A = false, S = false, D = false, Up = false, Down = false }

connect(UIS.InputBegan, function(i, g)
	if not g and keys[i.KeyCode.Name] ~= nil then
		keys[i.KeyCode.Name] = true
	end
end)
connect(UIS.InputEnded, function(i)
	if keys[i.KeyCode.Name] ~= nil then
		keys[i.KeyCode.Name] = false
	end
end)

connect(player.CharacterAdded, function(c)
	char = c
	hrp = c:WaitForChild("HumanoidRootPart")
	for k in pairs(keys) do
		keys[k] = false
	end
	updateSpeedUI()
end)

connect(RunService.RenderStepped, function()
	if not speedEnabled then
		return
	end
	if not hrp or not hrp.Parent then
		char = player.Character or player.CharacterAdded:Wait()
		hrp = char:WaitForChild("HumanoidRootPart")
	end
	local cf = workspace.CurrentCamera.CFrame
	local l, r = cf.LookVector, cf.RightVector
	local fw = Vector3.new(l.X, 0, l.Z).Unit
	local ri = Vector3.new(r.X, 0, r.Z).Unit
	local mv = Vector3.zero
	if keys.W or keys.Up then
		mv += fw
	end
	if keys.S or keys.Down then
		mv -= fw
	end
	if keys.A then
		mv -= ri
	end
	if keys.D then
		mv += ri
	end
	if mv.Magnitude > 0 then
		hrp.CFrame += mv.Unit * _G.CFrameSpeed * 0.1
	end
end)

Speed = { toggle = toggleSpeed, updateUI = updateSpeedUI }
end -- Speed scope

-- ========== GRAVITY TAB ==========
-- Scoped; `Grav` below is the public surface.
local Grav
do

local normalGravity = workspace.Gravity
if normalGravity == 0 then
	normalGravity = 196.2
end

-- the switch applies whatever is in the box; flipping it off restores normalGravity
local customGravity = normalGravity
local gravEnabled = false
local applyingGravity = false -- guard so our own writes aren't mistaken for the game's

row(gravPage, 0, "Custom gravity [G]")

row(gravPage, 36, "Gravity (0-500)")
local gravBox = make("TextBox", {
	Size = UDim2.new(0, 78, 0, 26),
	Position = UDim2.new(1, -78, 0, 34),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COL.text,
	PlaceholderText = "gravity",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, gravPage)
round(gravBox, 6)

local gravLbl = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.new(0, 0, 0, 72),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = COL.sub,
	TextXAlignment = Enum.TextXAlignment.Left,
}, gravPage)

local function updateGravUI()
	gravLbl.Text = ("Current: %.1f"):format(workspace.Gravity)
	if not gravBox:IsFocused() then
		gravBox.Text = ("%g"):format(customGravity)
	end
end

local function applyGravity(value)
	applyingGravity = true
	workspace.Gravity = value
	applyingGravity = false
end

local toggleGrav = select(2, makeSwitch(gravPage, 0, false, function(on)
	gravEnabled = on
	applyGravity(on and customGravity or normalGravity)
	updateGravUI()
end))

connect(gravBox.FocusLost, function()
	local n = tonumber(gravBox.Text)
	if n then
		customGravity = math.clamp(n, 0, 500)
		if gravEnabled then
			applyGravity(customGravity) -- live-update while the switch is on
		end
	end
	updateGravUI()
end)

connect(workspace:GetPropertyChangedSignal("Gravity"), function()
	-- if the game changes gravity while we're off, that becomes the new "normal"
	if not applyingGravity and not gravEnabled then
		normalGravity = workspace.Gravity
	end
	updateGravUI()
end)
updateGravUI()

Grav = {
	toggle = toggleGrav,
	getCustom = function()
		return customGravity
	end,
	setCustom = function(v)
		customGravity = math.clamp(v, 0, 500)
		if gravEnabled then
			applyGravity(customGravity)
		end
		updateGravUI()
	end,
}
end -- Gravity scope

-- ========== ESP TAB ==========
-- Scoped; the `Esp` table at the bottom is the whole public surface.
local Esp
do

local espEnabled = false
local espBox = true
local espDistance = false
local espHealth = false
local espSkeleton = false
local drawingOk = (Drawing ~= nil) -- Drawing is an executor feature; guard so the hub still loads without it
local espObjects = {} -- [player] = { box, name, hpBg, hpFill, bones = {} }

-- colours live in ESPCOL (top of file) so the settings panel can drive them

-- skeleton joint pairs per rig; parts are resolved by name each frame
local SKELETON_R6 = {
	{ "Head", "Torso" },
	{ "Torso", "Left Arm" },
	{ "Torso", "Right Arm" },
	{ "Torso", "Left Leg" },
	{ "Torso", "Right Leg" },
}
local SKELETON_R15 = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
}
local SKELETON_POOL = 16 -- enough line drawings to cover an R15 rig

row(espPage, 0, "Enabled")
row(espPage, 24, "Distance")
row(espPage, 48, "Health")
row(espPage, 72, "Skeleton")
row(espPage, 96, "Box")

local function newDrawing(class, props)
	local d = Drawing.new(class)
	for k, v in pairs(props) do
		d[k] = v
	end
	return d
end

local function espHide(o)
	o.box.Visible = false
	o.name.Visible = false
	o.hpBg.Visible = false
	o.hpFill.Visible = false
	for _, ln in ipairs(o.bones) do
		ln.Visible = false
	end
end

local function espAdd(plr)
	if not drawingOk or plr == player or espObjects[plr] then
		return
	end
	local bones = {}
	for i = 1, SKELETON_POOL do
		bones[i] = newDrawing("Line", { Thickness = 1, Color = Color3.new(1, 1, 1), Visible = false })
	end
	espObjects[plr] = {
		box = newDrawing("Square", { Thickness = 1.5, Color = ESPCOL.box, Filled = false, Visible = false }),
		name = newDrawing(
			"Text",
			{ Size = 13, Center = true, Outline = true, Color = Color3.new(1, 1, 1), Visible = false }
		),
		hpBg = newDrawing("Square", { Thickness = 1, Color = Color3.new(0, 0, 0), Filled = true, Visible = false }),
		hpFill = newDrawing(
			"Square",
			{ Thickness = 1, Color = Color3.fromRGB(70, 210, 110), Filled = true, Visible = false }
		),
		bones = bones,
	}
end

local function espRemove(plr)
	local o = espObjects[plr]
	if not o then
		return
	end
	o.box:Remove()
	o.name:Remove()
	o.hpBg:Remove()
	o.hpFill:Remove()
	for _, ln in ipairs(o.bones) do
		ln:Remove()
	end
	espObjects[plr] = nil
end

for _, plr in ipairs(Players:GetPlayers()) do
	espAdd(plr)
end
connect(Players.PlayerAdded, espAdd)
connect(Players.PlayerRemoving, espRemove)

makeSwitch(espPage, 0, false, function(on)
	espEnabled = on and drawingOk
	if not espEnabled then
		for _, o in pairs(espObjects) do
			espHide(o)
		end
	end
end)

-- setters kept so a loaded config can sync the switch visuals without firing callbacks
local espSetters = {}

espSetters.distance = makeSwitch(espPage, 24, espDistance, function(on)
	espDistance = on
end)

espSetters.health = makeSwitch(espPage, 48, espHealth, function(on)
	espHealth = on
end)

espSetters.skeleton = makeSwitch(espPage, 72, espSkeleton, function(on)
	espSkeleton = on
end)

espSetters.box = makeSwitch(espPage, 96, espBox, function(on)
	espBox = on
	if not on then
		for _, o in pairs(espObjects) do
			o.box.Visible = false
		end
	end
end)

connect(RunService.RenderStepped, function()
	if not espEnabled then
		return
	end
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
				local boxX = top.X - width / 2
				if espBox then
					o.box.Color = ESPCOL.box
					o.box.Size = Vector2.new(width, height)
					o.box.Position = Vector2.new(boxX, top.Y)
					o.box.Visible = true
				else
					o.box.Visible = false
				end

				-- name, plus optional distance / health readouts
				local label = plr.Name
				if espDistance then
					local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
					label = string.format("%s [%dm]", label, math.floor(dist))
				end
				if espHealth then
					label = string.format("%s (%d)", label, math.floor(hum.Health))
				end
				o.name.Text = label
				o.name.Color = ESPCOL.name
				o.name.Position = Vector2.new(top.X, top.Y - 16)
				o.name.Visible = true

				-- health bar running down the left edge of the box
				if espHealth then
					local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					local barW = 3
					local barX = boxX - barW - 3
					o.hpBg.Size = Vector2.new(barW, height)
					o.hpBg.Position = Vector2.new(barX, top.Y)
					o.hpBg.Visible = true
					local fillH = height * pct
					o.hpFill.Size = Vector2.new(barW, fillH)
					o.hpFill.Position = Vector2.new(barX, top.Y + (height - fillH))
					o.hpFill.Color = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(210 * pct), 90)
					o.hpFill.Visible = true
				else
					o.hpBg.Visible = false
					o.hpFill.Visible = false
				end

				-- skeleton: connect resolvable joint pairs for the character's rig
				if espSkeleton then
					local rig = hum.RigType == Enum.HumanoidRigType.R15 and SKELETON_R15 or SKELETON_R6
					local used = 0
					for _, pair in ipairs(rig) do
						local a = ch:FindFirstChild(pair[1])
						local b = ch:FindFirstChild(pair[2])
						if a and b then
							local pa, va = camera:WorldToViewportPoint(a.Position)
							local pb, vb = camera:WorldToViewportPoint(b.Position)
							if va and vb then
								used += 1
								local ln = o.bones[used]
								if ln then
									ln.Color = ESPCOL.skeleton
									ln.From = Vector2.new(pa.X, pa.Y)
									ln.To = Vector2.new(pb.X, pb.Y)
									ln.Visible = true
								end
							end
						end
					end
					for j = used + 1, #o.bones do
						o.bones[j].Visible = false
					end
				else
					for _, ln in ipairs(o.bones) do
						ln.Visible = false
					end
				end
			else
				espHide(o)
			end
		else
			espHide(o)
		end
	end
end)

Esp = {
	remove = espRemove,
	objects = espObjects,
	get = function()
		return { box = espBox, distance = espDistance, health = espHealth, skeleton = espSkeleton }
	end,
	-- every field optional; ignore anything that isn't a real boolean
	set = function(t)
		if type(t.box) == "boolean" then
			espBox = t.box
			espSetters.box(espBox)
		end
		if type(t.distance) == "boolean" then
			espDistance = t.distance
			espSetters.distance(espDistance)
		end
		if type(t.health) == "boolean" then
			espHealth = t.health
			espSetters.health(espHealth)
		end
		if type(t.skeleton) == "boolean" then
			espSkeleton = t.skeleton
			espSetters.skeleton(espSkeleton)
		end
	end,
}
end -- ESP scope

-- ========== HITBOX TAB ==========
-- Scoped; `Hitbox` below is the public surface.
local Hitbox
do

local hitboxEnabled = false
local hitboxVisible = true -- true = 25% visible red box (test), false = invisible
local hitboxSize = 5
local HITBOX_COLOR = Color3.fromRGB(255, 40, 40)
local hbOriginals = {} -- [hrp] = {Size, Transparency, Color, CanCollide, Massless}

local function hbStore(hrp)
	if hbOriginals[hrp] then
		return
	end
	hbOriginals[hrp] = {
		Size = hrp.Size,
		Transparency = hrp.Transparency,
		Color = hrp.Color,
		CanCollide = hrp.CanCollide,
		Massless = hrp.Massless,
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
makeSwitch(hitboxPage, 0, false, function(on)
	hitboxEnabled = on
	if not on then
		hbRestoreAll()
	end -- turning off snaps every hitbox back to normal
end)

row(hitboxPage, 36, "Show box (25%)")
makeSwitch(hitboxPage, 36, true, function(on)
	hitboxVisible = on -- on = 25% visible, off = invisible
end)

row(hitboxPage, 72, "Size (1-10)")
local hbBox = make("TextBox", {
	Size = UDim2.new(0, 78, 0, 26),
	Position = UDim2.new(1, -78, 0, 70),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COL.text,
	Text = tostring(hitboxSize),
	PlaceholderText = "size",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, hitboxPage)
round(hbBox, 6)

connect(hbBox.FocusLost, function()
	local n = tonumber(hbBox.Text)
	if n then
		hitboxSize = math.clamp(n, 1, 10)
	end
	hbBox.Text = tostring(hitboxSize)
end)

connect(RunService.Heartbeat, function()
	if not hitboxEnabled then
		return
	end
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
				if hrp.Size ~= sizeVec then
					hrp.Size = sizeVec
				end
				if hrp.CanCollide then
					hrp.CanCollide = false
				end
				hrp.Transparency = tp
				hrp.Color = HITBOX_COLOR
			end
		end
	end
end)

Hitbox = {
	restore = hbRestoreAll,
	getSize = function()
		return hitboxSize
	end,
	setSize = function(v)
		hitboxSize = math.clamp(v, 1, 10)
		hbBox.Text = tostring(hitboxSize)
	end,
}
end -- Hitbox scope

-- ========== PLAYER TAB ==========
-- Scoped: only findPlayer escapes (the chat commands use it). Exporting a closure at the
-- bottom means nothing in here needs renaming.
local hubFindPlayer
do

local function findPlayer(txt)
	txt = (txt or ""):lower()
	if txt == "" then
		return nil
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and (p.Name:lower():sub(1, #txt) == txt or p.DisplayName:lower():sub(1, #txt) == txt) then
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
	if not enterPressed then
		return
	end

	local found = findPlayer(playerBox.Text)

	if found then
		selectedPlayer = found

		playerMainRow.Text =
			string.format("Player: %s, Username: %s, ID: %s", found.DisplayName, found.Name, found.UserId)

		playerBox.Text = found.Name
	else
		selectedPlayer = nil
		playerMainRow.Text = "Player: Not found"
	end
end)

local tpBtn = make("TextButton", {
	Size = UDim2.new(0.5, -4, 0, 28),
	Position = UDim2.new(0, 0, 0, 62),
	BackgroundColor3 = COL.accent,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Teleport",
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, playerPage)
round(tpBtn, 6)

local specBtn = make("TextButton", {
	Size = UDim2.new(0.5, -4, 0, 28),
	Position = UDim2.new(0.5, 4, 0, 62),
	BackgroundColor3 = COL.accent,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Spectate",
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, playerPage)
round(specBtn, 6)

local playerStatus = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.new(0, 0, 0, 96),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = COL.sub,
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
}, playerPage)

connect(tpBtn.MouseButton1Click, function()
	click()
	local target = findPlayer(playerBox.Text)
	if not target then
		playerStatus.Text = "Player not found"
		return
	end
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
		if myhum then
			cam.CameraSubject = myhum
		end
		spectating = nil
		specBtn.Text = "Spectate"
		playerStatus.Text = "Stopped spectating"
	else
		local target = findPlayer(playerBox.Text)
		if not target then
			playerStatus.Text = "Player not found"
			return
		end
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

hubFindPlayer = findPlayer
end -- Player scope

-- ========== FLY TAB ==========
-- (adapted from the standalone sfly build: gyro/velocity flight, bobbing hover,
--  inertia slide, superman pitch/roll, custom fly animations)
-- Scoped: the fattest section in the file (~27 locals). Everything the outside needs is
-- handed out through the `Fly` table at the bottom, so nothing in here gets renamed.
local Fly
do

local flyEnabled = false
local flightSpeed = 50
local FLY_MAX_SPEED = 9842774
local flyKey = Enum.KeyCode.X
local awaitingFlyKey = false
local flyConns = {}
local flyGyro, flyVel
local flyMove = { forward = 0, backward = 0, left = 0, right = 0 }
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
	if a then
		a.Disabled = disabled
	end
end

local function flyPlayAnim(animId, startTime, spd)
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if flyAnimTrack then
		flyAnimTrack:Stop(0.1)
		flyAnimTrack = nil
	end
	flySetAnimate(true)
	for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
		tr:Stop()
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(animId)
	local ok, track = pcall(function()
		return hum:LoadAnimation(anim)
	end)
	if ok and track then
		flyAnimTrack = track
		track:Play()
		track.TimePosition = startTime
		track:AdjustSpeed(spd)
	end
end

local function flyStopAnim()
	if flyAnimTrack then
		flyAnimTrack:Stop(0.1)
		flyAnimTrack = nil
	end
	flySetAnimate(false)
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
			tr:Stop()
		end
	end
end

local function startFly()
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
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
		if not flyGyro or not flyVel then
			return
		end
		local cam = workspace.CurrentCamera
		local fwd = flyMove.forward - flyMove.backward
		local side = flyMove.right - flyMove.left
		local inputVec = (cam.CFrame.LookVector * fwd) + (cam.CFrame.RightVector * side)
		if fwd ~= 0 then
			inputVec = inputVec + Vector3.new(0, 0.2 * fwd, 0)
		end
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
		if gp then
			return
		end
		if i.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local k = i.KeyCode
		if k == Enum.KeyCode.W then
			flyMove.forward = 1
			flyPlayAnim(FLY_FWD_ANIM, 4.65, 0)
		elseif k == Enum.KeyCode.S then
			flyMove.backward = 1
			flyPlayAnim(FLY_IDLE_ANIM, 4, 0)
		elseif k == Enum.KeyCode.A then
			flyMove.left = 1
			if flyMove.forward > 0 then
				flyPlayAnim(FLY_FWD_ANIM, 4.65, 0)
			end
		elseif k == Enum.KeyCode.D then
			flyMove.right = 1
			if flyMove.forward > 0 then
				flyPlayAnim(FLY_FWD_ANIM, 4.65, 0)
			end
		end
	end)
	table.insert(flyConns, began)

	local ended = UIS.InputEnded:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local k = i.KeyCode
		if k == Enum.KeyCode.W then
			flyMove.forward = 0
			flyPlayAnim(FLY_IDLE_ANIM, 4, 0)
		elseif k == Enum.KeyCode.S then
			flyMove.backward = 0
			flyPlayAnim(FLY_IDLE_ANIM, 4, 0)
		elseif k == Enum.KeyCode.A then
			flyMove.left = 0
			if flyMove.forward > 0 then
				flyPlayAnim(FLY_FWD_ANIM, 4.65, 0)
			end
		elseif k == Enum.KeyCode.D then
			flyMove.right = 0
			if flyMove.forward > 0 then
				flyPlayAnim(FLY_FWD_ANIM, 4.65, 0)
			end
		end
	end)
	table.insert(flyConns, ended)
end

local function stopFly()
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
	end
	flyStopAnim()
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root then
		local g = root:FindFirstChild("FlyGyro")
		if g then
			g:Destroy()
		end
		local v = root:FindFirstChild("FlyVelocity")
		if v then
			v:Destroy()
		end
	end
	flyGyro, flyVel = nil, nil
	for _, c in ipairs(flyConns) do
		if c.Connected then
			c:Disconnect()
		end
	end
	flyConns = {}
	flyMove = { forward = 0, backward = 0, left = 0, right = 0 }
end

-- UI
row(flyPage, 0, "Fly")
local setFlySwitch, toggleFly = makeSwitch(flyPage, 0, false, function(on)
	flyEnabled = on
	if on then
		startFly()
	else
		stopFly()
	end
end)

row(flyPage, 36, "Speed (0-9842774)")
local flyBox = make("TextBox", {
	Size = UDim2.new(0, 90, 0, 26),
	Position = UDim2.new(1, -90, 0, 34),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COL.text,
	Text = tostring(flightSpeed),
	PlaceholderText = "speed",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, flyPage)
round(flyBox, 6)
connect(flyBox.FocusLost, function()
	local n = tonumber(flyBox.Text)
	if n then
		flightSpeed = math.clamp(n, 0, FLY_MAX_SPEED)
	end
	flyBox.Text = tostring(flightSpeed)
end)

-- shared !sfly command action: "!sfly" toggles fly; "!sfly <n>" sets speed and turns it on
local function doSfly(arg)
	local n = tonumber(arg)
	if n then
		flightSpeed = math.clamp(n, 0, FLY_MAX_SPEED)
		flyBox.Text = tostring(flightSpeed)
		if not flyEnabled then
			toggleFly()
		end
	else
		toggleFly()
	end
end

row(flyPage, 72, "Toggle key")
local flyKeyBtn = make("TextButton", {
	Size = UDim2.new(0, 90, 0, 26),
	Position = UDim2.new(1, -90, 0, 70),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextColor3 = COL.text,
	Text = flyKey.Name,
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, flyPage)
round(flyKeyBtn, 6)
connect(flyKeyBtn.MouseButton1Click, function()
	click()
	awaitingFlyKey = true
	flyKeyBtn.Text = "press key"
end)

-- global handler: capture a new toggle key when rebinding, otherwise fire the toggle
connect(UIS.InputBegan, function(i, gp)
	if i.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if awaitingFlyKey then
		local kc = i.KeyCode
		local ignore = {
			Enum.KeyCode.LeftShift,
			Enum.KeyCode.RightShift,
			Enum.KeyCode.LeftControl,
			Enum.KeyCode.RightControl,
			Enum.KeyCode.LeftAlt,
			Enum.KeyCode.RightAlt,
			Enum.KeyCode.Unknown,
		}
		for _, m in ipairs(ignore) do
			if kc == m then
				return
			end
		end
		awaitingFlyKey = false
		flyKey = kc
		flyKeyBtn.Text = kc.Name
		return
	end
	if gp then
		return
	end
	if i.KeyCode == flyKey then
		toggleFly()
	end
end)

-- stop flying cleanly on respawn (old body objects die with the old character)
connect(player.CharacterAdded, function()
	if flyEnabled then
		flyEnabled = false
		setFlySwitch(false)
		stopFly()
	end
end)

-- exports: setters clamp and update the UI, so callers can't desync the two
Fly = {
	stop = stopFly,
	doSfly = doSfly,
	getSpeed = function()
		return flightSpeed
	end,
	setSpeed = function(v)
		flightSpeed = math.clamp(v, 0, FLY_MAX_SPEED)
		flyBox.Text = tostring(flightSpeed)
	end,
	getKey = function()
		return flyKey
	end,
	setKey = function(k)
		flyKey = k
		flyKeyBtn.Text = k.Name
	end,
}
end -- Fly scope

-- ========== MOVEMENT TAB ==========
-- Scoped; `Move` below is the public surface.
local Move
do

local noclipEnabled = false
local infJumpEnabled = false
local walkSpeed = 16
local jumpPower = 50
local noclipParts = {} -- [part] = original CanCollide, so toggling off restores collisions

local function noclipRestore()
	for part, orig in pairs(noclipParts) do
		if part and part.Parent then
			part.CanCollide = orig
		end
	end
	noclipParts = {}
end

row(movePage, 0, "Noclip")
makeSwitch(movePage, 0, false, function(on)
	noclipEnabled = on
	if not on then
		noclipRestore()
	end
end)

row(movePage, 24, "Infinite jump")
makeSwitch(movePage, 24, false, function(on)
	infJumpEnabled = on
end)

connect(RunService.Stepped, function()
	if not noclipEnabled then
		return
	end
	local ch = player.Character
	if not ch then
		return
	end
	for _, part in ipairs(ch:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			if noclipParts[part] == nil then
				noclipParts[part] = true
			end
			part.CanCollide = false
		end
	end
end)

connect(UIS.JumpRequest, function()
	if not infJumpEnabled then
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

local function applyWalkSpeed()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = walkSpeed
	end
end

local function applyJumpPower()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.UseJumpPower = true -- JumpHeight is ignored unless this is set
		hum.JumpPower = jumpPower
	end
end

row(movePage, 52, "Walk speed")
local wsBox = make("TextBox", {
	Size = UDim2.new(0, 78, 0, 26),
	Position = UDim2.new(1, -78, 0, 50),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COL.text,
	Text = tostring(walkSpeed),
	PlaceholderText = "speed",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, movePage)
round(wsBox, 6)
connect(wsBox.FocusLost, function()
	local n = tonumber(wsBox.Text)
	if n then
		walkSpeed = math.clamp(n, 0, 500)
		applyWalkSpeed()
	end
	wsBox.Text = tostring(walkSpeed)
end)

row(movePage, 86, "Jump power")
local jpBox = make("TextBox", {
	Size = UDim2.new(0, 78, 0, 26),
	Position = UDim2.new(1, -78, 0, 84),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COL.text,
	Text = tostring(jumpPower),
	PlaceholderText = "power",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, movePage)
round(jpBox, 6)
connect(jpBox.FocusLost, function()
	local n = tonumber(jpBox.Text)
	if n then
		jumpPower = math.clamp(n, 0, 500)
		applyJumpPower()
	end
	jpBox.Text = tostring(jumpPower)
end)

-- respawning hands back a fresh humanoid at the game's defaults, so re-apply ours
connect(player.CharacterAdded, function(c)
	noclipParts = {}
	c:WaitForChild("Humanoid")
	applyWalkSpeed()
	applyJumpPower()
end)

Move = {
	restore = noclipRestore,
	getWalkSpeed = function()
		return walkSpeed
	end,
	setWalkSpeed = function(v)
		walkSpeed = math.clamp(v, 0, 500)
		wsBox.Text = tostring(walkSpeed)
		applyWalkSpeed()
	end,
	getJumpPower = function()
		return jumpPower
	end,
	setJumpPower = function(v)
		jumpPower = math.clamp(v, 0, 500)
		jpBox.Text = tostring(jumpPower)
		applyJumpPower()
	end,
}
end -- Movement scope

-- ========== WORLD TAB ==========
world.lighting = game:GetService("Lighting")
world.fullbright = false
world.nofog = false
world.fov = 70
world.orig = nil -- Lighting props as we found them
world.xrayParts = {} -- [part] = original LocalTransparencyModifier
world.origFov = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70

-- capture once, on first use, so we always have something honest to restore to
world.capture = function()
	if world.orig then
		return
	end
	local L = world.lighting
	world.orig = {
		Ambient = L.Ambient,
		OutdoorAmbient = L.OutdoorAmbient,
		Brightness = L.Brightness,
		ClockTime = L.ClockTime,
		GlobalShadows = L.GlobalShadows,
		FogEnd = L.FogEnd,
		FogStart = L.FogStart,
	}
end

-- fullbright and fog share the Lighting service, so both toggles route through here
world.applyLighting = function()
	world.capture()
	local L, o = world.lighting, world.orig
	if world.fullbright then
		L.Ambient = Color3.fromRGB(178, 178, 178)
		L.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
		L.Brightness = 2
		L.ClockTime = 14
		L.GlobalShadows = false
	else
		L.Ambient = o.Ambient
		L.OutdoorAmbient = o.OutdoorAmbient
		L.Brightness = o.Brightness
		L.ClockTime = o.ClockTime
		L.GlobalShadows = o.GlobalShadows
	end
	if world.nofog then
		L.FogEnd = 1e6
		L.FogStart = 1e6
	else
		L.FogEnd = o.FogEnd
		L.FogStart = o.FogStart
	end
end

-- LocalTransparencyModifier is client-only, so this never replicates to the server.
-- One-shot pass: parts streamed in later aren't affected until you re-toggle.
world.setXray = function(on)
	if on then
		for _, p in ipairs(workspace:GetDescendants()) do
			if p:IsA("BasePart") and not p.Parent:FindFirstChildOfClass("Humanoid") then
				if world.xrayParts[p] == nil then
					world.xrayParts[p] = p.LocalTransparencyModifier
				end
				p.LocalTransparencyModifier = 0.65
			end
		end
	else
		for p, orig in pairs(world.xrayParts) do
			if p and p.Parent then
				p.LocalTransparencyModifier = orig
			end
		end
		world.xrayParts = {}
	end
end

world.applyFov = function()
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = world.fov
	end
end

-- Infinite baseplate: tiles a grid of anchored parts out to TARGET_RADIUS, matching the
-- existing baseplate's height/material/colour when it can find one. Toggles: a second call
-- tears the folder back down. The !infbaseplate chat command routes through here too.
world.toggleInfBaseplate = function()
	local existing = workspace:FindFirstChild("InfBaseplate")
	if existing then
		existing:Destroy()
		return
	end

	local TILE_SIZE = 2048
	local TARGET_RADIUS = 50000
	local MAX_TILES_PER_AXIS = 25
	local THICKNESS = 16

	if _G.InfBaseplateCleanup then
		pcall(_G.InfBaseplateCleanup)
	end

	local bp = workspace:FindFirstChild("Baseplate")
		or workspace:FindFirstChild("Base")
		or workspace:FindFirstChild("Ground")
	if bp and not bp:IsA("BasePart") then
		bp = nil
	end

	local floorY = 0
	local mat = Enum.Material.Plastic
	local col = Color3.fromRGB(110, 110, 110)

	if bp then
		floorY = bp.Position.Y + bp.Size.Y / 2 - THICKNESS / 2
		mat = bp.Material
		col = bp.Color
	end

	local n = math.min(math.ceil(TARGET_RADIUS / TILE_SIZE), MAX_TILES_PER_AXIS)

	local folder = Instance.new("Folder")
	folder.Name = "InfBaseplate"
	folder.Parent = workspace

	local parts = {}
	local cf = {}
	local index = 1

	for x = -n, n do
		for z = -n, n do
			local p = Instance.new("Part")

			p.Anchored = true
			p.CanCollide = true
			p.Size = Vector3.new(TILE_SIZE, THICKNESS, TILE_SIZE)

			p.Material = mat
			p.Color = col

			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth

			parts[index] = p
			cf[index] = CFrame.new(x * TILE_SIZE, floorY, z * TILE_SIZE)

			index += 1
		end
	end

	-- parent after creation to reduce replication/update spam
	for _, p in ipairs(parts) do
		p.Parent = folder
	end

	-- move everything in one operation
	workspace:BulkMoveTo(parts, cf, Enum.BulkMoveMode.FireCFrameChanged)

	print(("[infbaseplate] %d tiles loaded (~%d studs)"):format(#parts, n * TILE_SIZE))

	_G.InfBaseplateCleanup = function()
		if folder then
			folder:Destroy()
		end

		_G.InfBaseplateCleanup = nil
	end
end

world.restore = function()
	if world.orig then
		world.fullbright, world.nofog = false, false
		pcall(world.applyLighting)
	end
	pcall(world.setXray, false)
	pcall(function()
		if workspace.CurrentCamera then
			workspace.CurrentCamera.FieldOfView = world.origFov
		end
	end)
end

row(world.page, 0, "Fullbright")
makeSwitch(world.page, 0, false, function(on)
	world.fullbright = on
	world.applyLighting()
end)

row(world.page, 24, "No fog")
makeSwitch(world.page, 24, false, function(on)
	world.nofog = on
	world.applyLighting()
end)

row(world.page, 48, "X-ray")
makeSwitch(world.page, 48, false, function(on)
	world.setXray(on)
end)

row(world.page, 76, "FOV (1-120)")
world.fovBox = make("TextBox", {
	Size = UDim2.new(0, 78, 0, 26),
	Position = UDim2.new(1, -78, 0, 74),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COL.text,
	Text = tostring(world.fov),
	PlaceholderText = "fov",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, world.page)
round(world.fovBox, 6)
connect(world.fovBox.FocusLost, function()
	local n = tonumber(world.fovBox.Text)
	if n then
		world.fov = math.clamp(n, 1, 120)
		world.applyFov()
	end
	world.fovBox.Text = tostring(world.fov)
end)

world.infBtn = make("TextButton", {
	Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.new(0, 0, 0, 104),
	BackgroundColor3 = COL.accent,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Infbaseplate",
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, world.page)
round(world.infBtn, 6)
connect(world.infBtn.MouseButton1Click, function()
	click()
	world.toggleInfBaseplate()
end)

-- ========== TOOLS TAB ==========
-- scrolling list of placeholder buttons (10 don't fit in the panel, so it scrolls)
-- Wrapped in do..end: nothing outside this block reads these locals, and Lua's 200-local
-- cap counts *active* locals, so closing the block hands the registers back.
-- (Body left at its original indent to keep the diff readable.)
do
local toolsScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, 0),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = COL.sub,
	CanvasSize = UDim2.new(0, 0, 0, 0),
}, toolsPage)
local toolsLayout = make("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, toolsScroll)

-- add a tool by giving it a name + run function; unset slots stay placeholders
local slots = 11

local toolDefs = {

	[1] = {
		name = "Jerk off",
		run = function()
			loadstring(
				game:HttpGet(
					"https://raw.githubusercontent.com/mckenziii/The-Twink-Community-Hub/refs/heads/main/Tools/jerkoff.lua"
				)
			)()
		end,
	},

	[2] = {
		name = "Teleport tool",
		run = function()
			loadstring(
				game:HttpGet(
					"https://raw.githubusercontent.com/mckenziii/The-Twink-Community-Hub/refs/heads/main/Tools/tptool.lua"
				)
			)()
		end,
	},

	[3] = {
		name = "Noclip tool",
		run = function()
			loadstring(
				game:HttpGet("https://raw.githubusercontent.com/mckenziii/The-Twink-Community-Hub/refs/heads/main/Tools/noclip.lua")
			)()
		end,
	},

	[4] = {
		name = "Twin-Towers Fab",
		run = function()
			loadstring(
				game:HttpGet(
					"https://raw.githubusercontent.com/mckenziii/twin-towers/refs/heads/main/twin%20towers%20sc"
				)
			)()
		end,
	},

	[5] = {
		name = "Stage Fab",
		run = function()
			loadstring(game:HttpGet("https://raw.githubusercontent.com/mckenziii/stage/refs/heads/main/stage%20sc"))()
		end,
	},

	[6] = {
		name = "Dance floor Fab",
		run = function()
			loadstring(
				game:HttpGet(
					"https://raw.githubusercontent.com/mckenziii/dance-floor/refs/heads/main/dance%20floor%20sc"
				)
			)()
		end,
	},

	[7] = {
		name = "Stripclub Fab",
		run = function()
			loadstring(
				game:HttpGet("https://raw.githubusercontent.com/mckenziii/stripclub/refs/heads/main/stripclub%20sc")
			)()
		end,
	},

	[8] = {
		name = "City islands Fab",
		run = function()
			loadstring(
				game:HttpGet(
					"https://raw.githubusercontent.com/mckenziii/city-islands/refs/heads/main/city%20islands%20sc"
				)
			)()
		end,
	},

	[9] = {
		name = "Racetrack Fab",
		run = function()
			loadstring(
				game:HttpGet("https://raw.githubusercontent.com/mckenziii/racetrack/refs/heads/main/racetrack%20sc")
			)()
		end,
	},

	[10] = {
		name = "Treehouse Fab",
		run = function()
			loadstring(
				game:HttpGet("https://raw.githubusercontent.com/unicornnmann/Treehouse/refs/heads/main/Treehouse")
			)()
		end,
	},

	[11] = {
		name = "Smoke your lungs out",
		run = function()
			loadstring(
				game:HttpGet(
					"https://raw.githubusercontent.com/mckenziii/smoke-your-lungs-out/refs/heads/main/smoke%20your%20lungs%20out%20sc"
				)
			)()
		end,
	},
}

for i = 1, slots do
	local def = toolDefs[i]
	local b = make("TextButton", {
		Size = UDim2.new(1, -6, 0, 28),
		BackgroundColor3 = COL.element,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = COL.text,
		Text = def and def.name or ("Tool " .. i),
		AutoButtonColor = true,
		BorderSizePixel = 0,
		LayoutOrder = i,
	}, toolsScroll)
	round(b, 6)
	connect(b.MouseButton1Click, function()
		click()
		if def and def.run then
			local ok, err = pcall(def.run)
			if not ok then
				warn("[Tools] " .. tostring(def.name) .. " failed: " .. tostring(err))
			end
		end
	end)
end

-- keep the scroll canvas sized to the button list
local function sizeToolsCanvas()
	toolsScroll.CanvasSize = UDim2.new(0, 0, 0, toolsLayout.AbsoluteContentSize.Y + 6)
end
connect(toolsLayout:GetPropertyChangedSignal("AbsoluteContentSize"), sizeToolsCanvas)
sizeToolsCanvas()
end -- Tools scope

-- ========== SETTINGS ==========
-- Cog (bottom-left) opens a panel for theming + config save/load.
-- Whole section is scoped in do..end to give ~30 locals back to the chunk; `hubLoadConfig`
-- is the only thing the outside world needs. Reading outer locals still works fine in here.
-- (Body left at its original indent to keep the diff readable.)
local hubLoadConfig
do
local CONFIG_FILE = "twinkhub_config.json"
-- writefile/readfile/isfile are executor features; degrade to in-memory-only without them
local canSaveFiles = (writefile ~= nil and readfile ~= nil and isfile ~= nil)

local DEFAULT_COL, DEFAULT_ESPCOL = {}, {}
for k, v in pairs(COL) do
	DEFAULT_COL[k] = v
end
for k, v in pairs(ESPCOL) do
	DEFAULT_ESPCOL[k] = v
end

-- each role carries its own table: COL rows repaint existing UI via applyTheme,
-- ESPCOL rows need no repaint (the ESP loop re-reads them every frame)
local COLOR_ROLES = {
	{ key = "bg", label = "Background", tbl = COL },
	{ key = "element", label = "Elements", tbl = COL },
	{ key = "stroke", label = "Outline", tbl = COL },
	{ key = "accent", label = "Accent", tbl = COL },
	{ key = "on", label = "Toggle on", tbl = COL },
	{ key = "off", label = "Toggle off", tbl = COL },
	{ key = "text", label = "Text", tbl = COL },
	{ key = "sub", label = "Sub text", tbl = COL },
	{ key = "box", label = "ESP box", tbl = ESPCOL },
	{ key = "name", label = "ESP name", tbl = ESPCOL },
	{ key = "skeleton", label = "ESP skeleton", tbl = ESPCOL },
}

local function toHex(c)
	return string.format(
		"%02X%02X%02X",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function fromHex(s)
	s = tostring(s):gsub("#", ""):gsub("%s", "")
	if #s ~= 6 or s:match("%X") then
		return nil
	end
	local r, g, b = tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

-- Enum.KeyCode[name] throws on a bad name, so resolve by scanning instead
local function keyFromName(name)
	if type(name) ~= "string" then
		return nil
	end
	for _, kc in ipairs(Enum.KeyCode:GetEnumItems()) do
		if kc.Name == name then
			return kc
		end
	end
	return nil
end

local function applyTheme()
	for _, ref in ipairs(themedRefs) do
		local c = COL[ref.role]
		if c and ref.obj then
			pcall(function()
				ref.obj[ref.prop] = c
			end)
		end
	end
	for _, fn in ipairs(themeRefreshers) do
		pcall(fn)
	end
end

local function gatherConfig()
	local colors, espColors = {}, {}
	for k, v in pairs(COL) do
		colors[k] = toHex(v)
	end
	for k, v in pairs(ESPCOL) do
		espColors[k] = toHex(v)
	end
	return {
		colors = colors,
		espColors = espColors,
		toggleKey = TOGGLE_KEY.Name,
		flyKey = Fly.getKey().Name,
		cframeSpeed = _G.CFrameSpeed,
		gravity = Grav.getCustom(),
		hitboxSize = Hitbox.getSize(),
		flySpeed = Fly.getSpeed(),
		walkSpeed = Move.getWalkSpeed(),
		jumpPower = Move.getJumpPower(),
		fov = world.fov,
		esp = Esp.get(),
	}
end

local refreshSettingsUI -- defined once the swatch rows exist

local function applyConfig(cfg)
	if type(cfg) ~= "table" then
		return
	end
	if type(cfg.colors) == "table" then
		for k, hex in pairs(cfg.colors) do
			if COL[k] ~= nil then
				local c = fromHex(hex)
				if c then
					COL[k] = c
				end
			end
		end
	end
	if type(cfg.espColors) == "table" then
		for k, hex in pairs(cfg.espColors) do
			if ESPCOL[k] ~= nil then
				local c = fromHex(hex)
				if c then
					ESPCOL[k] = c
				end
			end
		end
	end
	if tonumber(cfg.cframeSpeed) then
		_G.CFrameSpeed = math.clamp(tonumber(cfg.cframeSpeed), 0, 99999)
		Speed.updateUI()
	end
	if tonumber(cfg.gravity) then
		Grav.setCustom(tonumber(cfg.gravity))
	end
	if tonumber(cfg.hitboxSize) then
		Hitbox.setSize(tonumber(cfg.hitboxSize))
	end
	if tonumber(cfg.flySpeed) then
		Fly.setSpeed(tonumber(cfg.flySpeed))
	end
	if tonumber(cfg.walkSpeed) then
		Move.setWalkSpeed(tonumber(cfg.walkSpeed))
	end
	if tonumber(cfg.jumpPower) then
		Move.setJumpPower(tonumber(cfg.jumpPower))
	end
	if tonumber(cfg.fov) then
		world.fov = math.clamp(tonumber(cfg.fov), 1, 120)
		world.fovBox.Text = tostring(world.fov)
		world.applyFov()
	end
	if type(cfg.esp) == "table" then
		Esp.set(cfg.esp)
	end
	local tk = keyFromName(cfg.toggleKey)
	if tk then
		TOGGLE_KEY = tk
		keyChip.Text = tk.Name
	end
	local fk = keyFromName(cfg.flyKey)
	if fk then
		Fly.setKey(fk)
	end
	applyTheme()
	if refreshSettingsUI then
		refreshSettingsUI()
	end
end

local function saveConfig()
	if not canSaveFiles then
		return false, "no file API"
	end
	local ok, err = pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode(gatherConfig()))
	end)
	return ok, err
end

local function loadConfig()
	if not canSaveFiles or not isfile(CONFIG_FILE) then
		return false, "no saved config"
	end
	local ok, cfg = pcall(function()
		return HttpService:JSONDecode(readfile(CONFIG_FILE))
	end)
	if not ok or type(cfg) ~= "table" then
		return false, "config unreadable"
	end
	applyConfig(cfg)
	return true
end

-- cog button, bottom-left of the panel
local cogBtn = make("TextButton", {
	Size = UDim2.new(0, 26, 0, 26),
	Position = UDim2.new(0, 8, 1, -32),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = COL.text,
	Text = "⚙",
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, main)
round(cogBtn, 6)

local setFrame = make("Frame", {
	Name = "SettingsPanel",
	Size = UDim2.new(0, 320, 0, 340),
	Position = UDim2.new(0.5, -160, 0.5, -170),
	BackgroundColor3 = COL.bg,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
}, gui)
round(setFrame, 10)
make("UIStroke", { Color = COL.stroke, Thickness = 1 }, setFrame)

local setTitle = make("TextLabel", {
	Size = UDim2.new(1, -44, 0, 32),
	Position = UDim2.new(0, 12, 0, 2),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = COL.text,
	Text = "Settings",
	TextXAlignment = Enum.TextXAlignment.Left,
}, setFrame)
setTitle.Active = true

local setClose = make("TextButton", {
	Size = UDim2.new(0, 24, 0, 24),
	Position = UDim2.new(1, -30, 0, 6),
	BackgroundColor3 = COL.on,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, setFrame)
round(setClose, 6)
connect(setClose.MouseButton1Click, function()
	click()
	setFrame.Visible = false
end)

connect(cogBtn.MouseButton1Click, function()
	click()
	setFrame.Visible = not setFrame.Visible
end)

local setScroll = make("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -110),
	Position = UDim2.new(0, 10, 0, 38),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = COL.sub,
	CanvasSize = UDim2.new(0, 0, 0, 0),
}, setFrame)
local setLayout = make("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, setScroll)

local setStatus = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 16),
	Position = UDim2.new(0, 10, 1, -22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = COL.sub,
	Text = canSaveFiles and ("Config: " .. CONFIG_FILE) or "No file API: settings won't persist",
	TextXAlignment = Enum.TextXAlignment.Left,
}, setFrame)

local swatches = {}

local function autoSave()
	if not canSaveFiles then
		return
	end
	local ok = saveConfig()
	setStatus.Text = ok and "Saved" or "Save failed"
end

-- ---------- colour picker popup ----------
-- Clicking a swatch opens this. Saturation/value square + hue strip, live-applied.
-- Everything lives in one table so we don't burn top-level locals (the chunk is near
-- Lua's 200-local cap).
local GuiService = game:GetService("GuiService")
local picker = { tbl = nil, key = nil, h = 0, s = 0, v = 0, dragSV = false, dragHue = false }

picker.frame = make("Frame", {
	Name = "ColorPicker",
	Size = UDim2.new(0, 230, 0, 216),
	Position = UDim2.new(0.5, 180, 0.5, -108),
	BackgroundColor3 = COL.bg,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
	ZIndex = 5,
}, gui)
round(picker.frame, 8)
make("UIStroke", { Color = COL.stroke, Thickness = 1 }, picker.frame)

picker.title = make("TextLabel", {
	Size = UDim2.new(1, -24, 0, 24),
	Position = UDim2.new(0, 12, 0, 2),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = COL.text,
	Text = "Colour",
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
}, picker.frame)
picker.title.Active = true

-- SV square: hue-coloured base, white gradient across X (saturation),
-- black gradient down Y (value). Overlays are parented inline to save locals.
picker.sv = make("TextButton", {
	Size = UDim2.new(0, 200, 0, 116),
	Position = UDim2.new(0, 15, 0, 28),
	BackgroundColor3 = Color3.fromHSV(0, 1, 1),
	AutoButtonColor = false,
	Text = "",
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 5,
}, picker.frame)
round(picker.sv, 5)

make("UIGradient", {
	Color = ColorSequence.new(Color3.new(1, 1, 1)),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 5,
}, picker.sv))

make("UIGradient", {
	Color = ColorSequence.new(Color3.new(0, 0, 0)),
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	}),
}, make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ZIndex = 6,
}, picker.sv))

picker.svDot = make("Frame", {
	Size = UDim2.new(0, 8, 0, 8),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 7,
}, picker.sv)
round(picker.svDot, 4)
make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }, picker.svDot)

picker.hue = make("TextButton", {
	Size = UDim2.new(0, 200, 0, 14),
	Position = UDim2.new(0, 15, 0, 152),
	BackgroundColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
	Text = "",
	BorderSizePixel = 0,
	ZIndex = 5,
}, picker.frame)
round(picker.hue, 4)
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
	}),
}, picker.hue)

picker.hueDot = make("Frame", {
	Size = UDim2.new(0, 3, 1, 4),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 7,
}, picker.hue)
make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }, picker.hueDot)

picker.preview = make("Frame", {
	Size = UDim2.new(0, 34, 0, 24),
	Position = UDim2.new(0, 15, 0, 176),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ZIndex = 5,
}, picker.frame)
round(picker.preview, 5)
-- same fixed grey as the swatches, so the preview stays visible at any colour
make("UIStroke", { Color = Color3.fromRGB(175, 180, 190), Thickness = 1 }, picker.preview)

picker.hex = make("TextBox", {
	Size = UDim2.new(0, 100, 0, 24),
	Position = UDim2.new(0, 55, 0, 176),
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = COL.text,
	Text = "#000000",
	PlaceholderText = "RRGGBB",
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
	ZIndex = 5,
}, picker.frame)
round(picker.hex, 5)

picker.done = make("TextButton", {
	Size = UDim2.new(0, 55, 0, 24),
	Position = UDim2.new(0, 160, 0, 176),
	BackgroundColor3 = COL.accent,
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Done",
	AutoButtonColor = false,
	BorderSizePixel = 0,
	ZIndex = 5,
}, picker.frame)
round(picker.done, 5)

local function pickerRender()
	local c = Color3.fromHSV(picker.h, picker.s, picker.v)
	picker.sv.BackgroundColor3 = Color3.fromHSV(picker.h, 1, 1)
	picker.svDot.Position = UDim2.new(picker.s, 0, 1 - picker.v, 0)
	picker.hueDot.Position = UDim2.new(picker.h, 0, 0.5, 0)
	picker.preview.BackgroundColor3 = c
	if not picker.hex:IsFocused() then
		picker.hex.Text = "#" .. toHex(c)
	end
end

local function pickerCommit()
	if not picker.tbl then
		return
	end
	picker.tbl[picker.key] = Color3.fromHSV(picker.h, picker.s, picker.v)
	-- only COL drives already-built instances; ESPCOL is re-read by the render loop
	if picker.tbl == COL then
		applyTheme()
	end
	if refreshSettingsUI then
		refreshSettingsUI()
	end
end

-- GetMouseLocation() is raw screen space; AbsolutePosition sits below the topbar,
-- so subtract the GUI inset to compare them.
local function pickerFromMouse()
	local m = UIS:GetMouseLocation() - GuiService:GetGuiInset()
	if picker.dragSV then
		local a, sz = picker.sv.AbsolutePosition, picker.sv.AbsoluteSize
		picker.s = math.clamp((m.X - a.X) / math.max(sz.X, 1), 0, 1)
		picker.v = 1 - math.clamp((m.Y - a.Y) / math.max(sz.Y, 1), 0, 1)
	elseif picker.dragHue then
		local a, sz = picker.hue.AbsolutePosition, picker.hue.AbsoluteSize
		picker.h = math.clamp((m.X - a.X) / math.max(sz.X, 1), 0, 1)
	else
		return
	end
	pickerRender()
	pickerCommit()
end

local function openPicker(role)
	picker.tbl, picker.key = role.tbl, role.key
	picker.h, picker.s, picker.v = role.tbl[role.key]:ToHSV()
	picker.title.Text = role.label
	-- park it just right of the settings panel; drag by the title if it lands badly
	picker.frame.Position = UDim2.new(
		0,
		setFrame.AbsolutePosition.X + setFrame.AbsoluteSize.X + 8,
		0,
		setFrame.AbsolutePosition.Y
	)
	picker.frame.Visible = true
	pickerRender()
end

connect(picker.sv.InputBegan, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		picker.dragSV = true
		pickerFromMouse()
	end
end)

connect(picker.hue.InputBegan, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		picker.dragHue = true
		pickerFromMouse()
	end
end)

connect(UIS.InputChanged, function(i)
	if i.UserInputType == Enum.UserInputType.MouseMovement and (picker.dragSV or picker.dragHue) then
		pickerFromMouse()
	end
end)

connect(UIS.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 and (picker.dragSV or picker.dragHue) then
		picker.dragSV, picker.dragHue = false, false
		autoSave() -- save once on release, not on every mouse move
	end
end)

connect(picker.hex.FocusLost, function()
	local c = fromHex(picker.hex.Text)
	if c then
		picker.h, picker.s, picker.v = c:ToHSV()
		pickerRender()
		pickerCommit()
		autoSave()
	else
		pickerRender() -- bad hex: snap the text back
	end
end)

connect(picker.done.MouseButton1Click, function()
	click()
	picker.frame.Visible = false
end)

do
	local pDrag, pStart, pPos
	connect(picker.title.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			pDrag, pStart, pPos = true, i.Position, picker.frame.Position
		end
	end)
	connect(UIS.InputChanged, function(i)
		if pDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - pStart
			picker.frame.Position =
				UDim2.new(pPos.X.Scale, pPos.X.Offset + d.X, pPos.Y.Scale, pPos.Y.Offset + d.Y)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			pDrag = false
		end
	end)
end

-- hiding the settings panel takes the picker with it (extra handlers: the originals were
-- created before `picker` existed, so they can't see it)
connect(setClose.MouseButton1Click, function()
	picker.frame.Visible = false
end)
connect(cogBtn.MouseButton1Click, function()
	if not setFrame.Visible then
		picker.frame.Visible = false
	end
end)

for i, role in ipairs(COLOR_ROLES) do
	local line = make("Frame", {
		Size = UDim2.new(1, -6, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = i,
	}, setScroll)

	make("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = COL.text,
		Text = role.label,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, line)

	-- a button, not a label: clicking it opens the picker on this role
	local swatch = make("TextButton", {
		Size = UDim2.new(0, 24, 0, 20),
		Position = UDim2.new(1, -116, 0.5, -10),
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
	}, line)
	-- set AFTER make() on purpose: make() registers any Color3 matching a COL role for
	-- re-theming, and a swatch must always show its OWN role. ESPCOL.box happens to equal
	-- COL.on, so passing it in would bind this swatch to "Toggle on".
	swatch.BackgroundColor3 = role.tbl[role.key]
	round(swatch, 4)
	-- fixed light grey, deliberately NOT COL.stroke: a themed outline would vanish along
	-- with the swatch when a role is set near the panel background
	make("UIStroke", { Color = Color3.fromRGB(175, 180, 190), Thickness = 1 }, swatch)

	connect(swatch.MouseButton1Click, function()
		click()
		openPicker(role)
	end)

	local hexBox = make("TextBox", {
		Size = UDim2.new(0, 86, 0, 24),
		Position = UDim2.new(1, -86, 0.5, -12),
		BackgroundColor3 = COL.element,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = COL.text,
		Text = "#" .. toHex(role.tbl[role.key]),
		PlaceholderText = "RRGGBB",
		PlaceholderColor3 = COL.sub,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, line)
	round(hexBox, 5)

	swatches[role.key] = { swatch = swatch, box = hexBox }

	connect(hexBox.FocusLost, function()
		local c = fromHex(hexBox.Text)
		if c then
			role.tbl[role.key] = c
			if role.tbl == COL then
				applyTheme() -- ESPCOL needs no repaint; the render loop re-reads it
			end
			autoSave()
		else
			setStatus.Text = "Bad hex (use RRGGBB)"
		end
		refreshSettingsUI()
	end)
end

function refreshSettingsUI()
	for _, role in ipairs(COLOR_ROLES) do
		local s = swatches[role.key]
		if s then
			s.swatch.BackgroundColor3 = role.tbl[role.key]
			if not s.box:IsFocused() then
				s.box.Text = "#" .. toHex(role.tbl[role.key])
			end
		end
	end
end
themeRefreshers[#themeRefreshers + 1] = refreshSettingsUI
themeRefreshers[#themeRefreshers + 1] = function()
	if currentTab then
		selectTab(currentTab) -- re-assert the accent on the selected tab
	end
end

local function sizeSetCanvas()
	setScroll.CanvasSize = UDim2.new(0, 0, 0, setLayout.AbsoluteContentSize.Y + 6)
end
connect(setLayout:GetPropertyChangedSignal("AbsoluteContentSize"), sizeSetCanvas)
sizeSetCanvas()

-- Save / Load / Reset
local setBtns = {
	{ text = "Save", x = 0 },
	{ text = "Load", x = 1 },
	{ text = "Reset", x = 2 },
}
for _, def in ipairs(setBtns) do
	local b = make("TextButton", {
		Size = UDim2.new(0.333, -6, 0, 26),
		Position = UDim2.new(0.333 * def.x, def.x == 0 and 10 or 4, 1, -50),
		BackgroundColor3 = def.text == "Reset" and COL.on or COL.accent,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		Text = def.text,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, setFrame)
	round(b, 6)
	connect(b.MouseButton1Click, function()
		click()
		if def.text == "Save" then
			local ok, err = saveConfig()
			setStatus.Text = ok and ("Saved to " .. CONFIG_FILE) or ("Save failed: " .. tostring(err))
		elseif def.text == "Load" then
			local ok, err = loadConfig()
			setStatus.Text = ok and "Config loaded" or ("Load failed: " .. tostring(err))
		else
			for k, v in pairs(DEFAULT_COL) do
				COL[k] = v
			end
			for k, v in pairs(DEFAULT_ESPCOL) do
				ESPCOL[k] = v
			end
			applyTheme()
			refreshSettingsUI()
			autoSave()
			setStatus.Text = "Reset to defaults"
		end
	end)
end

-- settings panel dragging
do
	local sDrag, sStart, sPos
	connect(setTitle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			sDrag, sStart, sPos = true, i.Position, setFrame.Position
		end
	end)
	connect(UIS.InputChanged, function(i)
		if sDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - sStart
			setFrame.Position =
				UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			sDrag = false
		end
	end)
end

hubLoadConfig = loadConfig -- the one export: startup calls this once every tab exists
end -- Settings scope

-- ========== COMMAND BAR ==========
-- Inline bar in the bottom strip, sat between the cog (ends x=34) and Unload (starts x=248).
-- hubRunCommand is THE command implementation: this bar, the !cmdbar popup and
-- player.Chatted all route through it, so the three copies that used to drift are gone.
-- Feedback goes to this bar's placeholder via say(); chat callers just ignore it.
local hubRunCommand
do

local cmdBox = make("TextBox", {
	Size = UDim2.new(0, 202, 0, 26),
	Position = UDim2.new(0, 40, 1, -32), -- same -32 as the cog so the row lines up
	BackgroundColor3 = COL.element,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextColor3 = COL.text,
	Text = "",
	PlaceholderText = "command...  (type help)",
	ClipsDescendants = true,
	PlaceholderColor3 = COL.sub,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, main)
round(cmdBox, 6)

local IDLE = "command...  (type help)"

-- reply in the placeholder, then fade back to the prompt
local function say(msg)
	cmdBox.Text = ""
	cmdBox.PlaceholderText = msg
	task.delay(2.5, function()
		if cmdBox and cmdBox.Parent and cmdBox.PlaceholderText == msg then
			cmdBox.PlaceholderText = IDLE
		end
	end)
end

hubRunCommand = function(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if input == "" then
		return
	end
	if input:sub(1, 1) == "!" then -- tolerate the chat-style prefix
		input = input:sub(2)
	end
	local cmd, arg = input:match("^(%S+)%s*(.-)$")
	if not cmd then
		return
	end
	cmd = cmd:lower()
	local n = tonumber(arg)

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
			Thickness = 1,
		}, cmdGui)

		local box = make("TextBox", {
			Size = UDim2.new(1, -20, 1, -10),
			Position = UDim2.new(0, 10, 0, 5),

			BackgroundColor3 = COL.element,

			Font = Enum.Font.Gotham,
			TextSize = 14,

			Text = "",
			TextColor3 = COL.text,

			PlaceholderText = "Enter command here",
			PlaceholderColor3 = COL.sub,

			ClearTextOnFocus = false,

			BorderSizePixel = 0,
		}, cmdGui)

		round(box, 7)

		box.FocusLost:Connect(function(enter)
			if not enter then
				return
			end

			local input = box.Text
			box.Text = ""

			if input == "" then
				return
			end

			hubRunCommand(input)
		end)
		box:CaptureFocus()

	-- =========================
	-- TELEPORT
	-- =========================
	elseif cmd == "tp" then
		local target = hubFindPlayer(arg)

		if target then
			local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

			if targetHRP and myHRP then
				myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 0, 3)
			end
		end
	elseif cmd == "infbaseplate" or cmd == "infinitebaseplate" then
		world.toggleInfBaseplate()
	elseif cmd == "clicktp" then
		if _G.ClickTpCleanup then
			pcall(_G.ClickTpCleanup)
			task.wait()
		end

		local Players = game:GetService("Players")
		local UIS = game:GetService("UserInputService")

		local player = Players.LocalPlayer
		local mouse = player:GetMouse()

		if _G.ClickTpCleanup then
			pcall(_G.ClickTpCleanup)
		end

		local clickConns = {}

		local function clickConnect(signal, func)
			local c = signal:Connect(func)
			table.insert(clickConns, c)
			return c
		end

		local enabled = false

		local modifierKey = Enum.KeyCode.LeftControl
		local keybindKey = Enum.KeyCode.R

		local waitingModifier = false
		local waitingKey = false

		local clickGui = gui:FindFirstChild("ClickTpUI")

		if clickGui then
			clickGui:Destroy()
		end

		clickGui = make("ScreenGui", {
			Name = "ClickTpUI",
			ResetOnSpawn = false,
		}, gui)

		local frame = make("Frame", {
			Name = "ClickTpFrame",
			Size = UDim2.new(0, 220, 0, 150),
			Position = UDim2.new(0, 20, 0, 250),
			BackgroundColor3 = COL.bg,
			BorderSizePixel = 0,
			Active = true,
		}, clickGui)

		round(frame, 10)

		make("UIStroke", {
			Color = COL.stroke,
			Thickness = 1,
		}, frame)

		local title = make("TextLabel", {
			Size = UDim2.new(1, -40, 0, 30),
			Position = UDim2.new(0, 10, 0, 5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = COL.text,
			Text = "Click TP",
			TextXAlignment = Enum.TextXAlignment.Left,
		}, frame)

		title.Active = true

		local close = make("TextButton", {
			Size = UDim2.new(0, 25, 0, 25),
			Position = UDim2.new(1, -30, 0, 5),
			Text = "X",
			BackgroundColor3 = COL.on,
			TextColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, frame)

		round(close, 6)

		close.MouseButton1Click:Connect(function()
			clickGui:Destroy()
		end)

		local toggle = make("TextButton", {
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.new(0, 10, 0, 40),
			BackgroundColor3 = Color3.fromRGB(84, 88, 102),
			Text = "Enabled: OFF",
			TextColor3 = COL.text,
			BorderSizePixel = 0,
		}, frame)

		round(toggle, 6)

		local mod = make("TextButton", {
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.new(0, 10, 0, 75),
			BackgroundColor3 = COL.element,
			Text = "Modifier: " .. modifierKey.Name,
			TextColor3 = COL.text,
			BorderSizePixel = 0,
		}, frame)

		round(mod, 6)

		local key = make("TextButton", {
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.new(0, 10, 0, 110),
			BackgroundColor3 = COL.element,
			Text = "Key: " .. keybindKey.Name,
			TextColor3 = COL.text,
			BorderSizePixel = 0,
		}, frame)

		round(key, 6)

		toggle.MouseButton1Click:Connect(function()
			enabled = not enabled

			toggle.Text = "Enabled: " .. (enabled and "ON" or "OFF")

			toggle.BackgroundColor3 = enabled and COL.on or Color3.fromRGB(84, 88, 102)
		end)

		mod.MouseButton1Click:Connect(function()
			waitingModifier = true
			mod.Text = "Modifier: press key"
		end)

		key.MouseButton1Click:Connect(function()
			waitingKey = true
			key.Text = "Key: press key"
		end)

		clickConnect(UIS.InputBegan, function(input, gp)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end

			if waitingModifier then
				modifierKey = input.KeyCode
				waitingModifier = false

				mod.Text = "Modifier: " .. modifierKey.Name

				return
			end

			if waitingKey then
				keybindKey = input.KeyCode
				waitingKey = false

				key.Text = "Key: " .. keybindKey.Name

				return
			end

			if gp or not enabled then
				return
			end

			if input.KeyCode == keybindKey then
				if UIS:IsKeyDown(modifierKey) then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

					if root and mouse.Hit then
						root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
					end
				end
			end
		end)

		-- DRAGGING

		do
			local dragging = false
			local start
			local startPos

			clickConnect(title.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
					start = input.Position
					startPos = frame.Position
				end
			end)

			clickConnect(UIS.InputChanged, function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = input.Position - start

					frame.Position = UDim2.new(
						startPos.X.Scale,
						startPos.X.Offset + delta.X,
						startPos.Y.Scale,
						startPos.Y.Offset + delta.Y
					)
				end
			end)

			clickConnect(UIS.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end)
		end

		_G.ClickTpToggle = function()
			frame.Visible = not frame.Visible
		end

		_G.ClickTpCleanup = function()
			for _, c in ipairs(clickConns) do
				pcall(function()
					c:Disconnect()
				end)
			end

			if clickGui then
				clickGui:Destroy()
			end

			_G.ClickTpToggle = nil
			_G.ClickTpCleanup = nil
		end

	-- DO NOT PUT AN EXTRA "end" HERE

	-- =========================
	-- SPECTATE
	-- =========================
	elseif cmd == "sp" then
		if arg ~= "" then
			local target = hubFindPlayer(arg)

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
			Thickness = 1,
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
			TextColor3 = Color3.new(1, 1, 1),
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
			CanvasSize = UDim2.new(0, 0, 0, 0),
		}, help)

		-- works from chat (with !), the bar at the bottom of the hub, or !cmdbar
		local commands = {
			"tp <player> - Teleport to player",
			"sp <player> - Spectate player",
			"unsp - Stop spectating",
			"sfly <speed> - Toggle fly / set fly speed",
			"ws <n> - Set walk speed",
			"jp <n> - Set jump power",
			"speed <n> - Set CFrame speed",
			"grav <n> - Set custom gravity",
			"fov <n> - Set field of view",
			"hitbox <n> - Set hitbox size",
			"clicktp - Toggle the Click TP window",
			"infbaseplate - Toggle the infinite baseplate",
			"runcode <lua> / lua <lua> - Execute Lua",
			"cmdbar - Open the floating command bar",
			"unload - Remove the hub",
			"help - Open this menu",
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

		scroll.CanvasSize = UDim2.new(0, 0, 0, y)

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
		Fly.doSfly(arg)
	elseif cmd == "ws" or cmd == "walkspeed" then
		if n then
			Move.setWalkSpeed(n)
			say("walkspeed " .. Move.getWalkSpeed())
		else
			say("needs a number")
		end
	elseif cmd == "jp" or cmd == "jumppower" then
		if n then
			Move.setJumpPower(n)
			say("jumppower " .. Move.getJumpPower())
		else
			say("needs a number")
		end
	elseif cmd == "fov" then
		if n then
			world.fov = math.clamp(n, 1, 120)
			world.fovBox.Text = tostring(world.fov)
			world.applyFov()
			say("fov " .. world.fov)
		else
			say("needs a number")
		end
	elseif cmd == "grav" or cmd == "gravity" then
		if n then
			Grav.setCustom(n)
			say("gravity " .. Grav.getCustom())
		else
			say("needs a number")
		end
	elseif cmd == "speed" then
		if n then
			_G.CFrameSpeed = math.clamp(n, 0, 99999)
			Speed.updateUI()
			say("speed " .. _G.CFrameSpeed)
		else
			say("needs a number")
		end
	elseif cmd == "hitbox" then
		if n then
			Hitbox.setSize(n)
			say("hitbox " .. Hitbox.getSize())
		else
			say("needs a number")
		end
	elseif cmd == "fly" then
		Fly.doSfly(arg)
	elseif cmd == "unload" then
		if _G.ScriptHubCleanup then
			_G.ScriptHubCleanup()
		end
	else
		say("unknown: " .. cmd)
	end
end

connect(cmdBox.FocusLost, function(enter)
	if not enter then -- clicking away shouldn't fire the command
		return
	end
	local input = cmdBox.Text
	cmdBox.Text = ""
	local ok, err = pcall(hubRunCommand, input)
	if not ok then
		say("error: " .. tostring(err))
	end
end)
end -- Command bar scope

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
			-- keep the original scale; rebuilding it as 0 snapped the panel to the top
			main.Position =
				UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = false
		end
	end)
end

-- ========== KEYBINDS ==========
-- wired last, after every toggle exists: K = hide/show, C = cframe speed, G = zero gravity
connect(UIS.InputBegan, function(i, g)
	if g or i.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if i.KeyCode == TOGGLE_KEY then
		if keyChangeCooldown then
			return
		end
		main.Visible = not main.Visible
	elseif i.KeyCode == SPEED_KEY then
		Speed.toggle()
	elseif i.KeyCode == GRAV_KEY then
		Grav.toggle()
	end
end)

selectTab("Speed")

-- restore the saved theme/settings, if any (after every tab exists so the UI can sync)
pcall(hubLoadConfig)

-- version tag (bottom-right) so you can tell which copy is running
make("TextLabel", {
	Size = UDim2.new(0, 60, 0, 12),
	Position = UDim2.new(1, -66, 1, -25), -- centred on the same line as the cog/cmd bar
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextColor3 = COL.sub,
	Text = VERSION,
	TextXAlignment = Enum.TextXAlignment.Right,
}, main)

-- unload button (just left of the version tag) — fully removes the script
local unloadBtn = make("TextButton", {
	Size = UDim2.new(0, 58, 0, 18),
	Position = UDim2.new(1, -132, 1, -28), -- centred on the same line as the cog/cmd bar
	BackgroundColor3 = COL.on,
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Unload",
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, main)
round(unloadBtn, 5)
connect(unloadBtn.MouseButton1Click, function()
	click()
	if _G.ScriptHubCleanup then
		_G.ScriptHubCleanup()
	end

	local folder = workspace:FindFirstChild("InfBaseplate")

	if folder then
		folder:Destroy()
	end
end)

connect(player.Chatted, function(msg)
	if msg:sub(1, 1) ~= "!" then
		return
	end
	-- single implementation: the command bar owns dispatch. (The old nested
	-- connect(player.Chatted) in here registered a fresh handler per command,
	-- so commands fired more times the longer you played.)
	local ok, err = pcall(hubRunCommand, msg)
	if not ok then
		warn("[cmd] " .. tostring(err))
	end
end)

_G.ScriptHubCleanup = function()
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	for plr in pairs(Esp.objects) do
		Esp.remove(plr)
	end
	Hitbox.restore()
	Move.restore()
	world.restore() -- put Lighting / X-ray / FOV back the way we found them
	Fly.stop()
	-- make sure we're not left stuck in someone else's camera
	pcall(function()
		local myhum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if myhum then
			workspace.CurrentCamera.CameraSubject = myhum
		end
	end)
	gui:Destroy()
	local FpsPingGui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("FpsPingGui")

	if FpsPingGui then
		FpsPingGui:Destroy()
	end
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

-- FPS + Ping counter --- execute through your executor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer

if _G.FpsPingCleanup then
	pcall(_G.FpsPingCleanup)
end

local conns = {}

local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local COL = {
	bg = Color3.fromRGB(24, 25, 31),
	stroke = Color3.fromRGB(58, 62, 75),

	green = Color3.fromRGB(80, 220, 130),
	yellow = Color3.fromRGB(240, 200, 80),
	red = Color3.fromRGB(230, 68, 68),

	text = Color3.fromRGB(235, 238, 245),
	sub = Color3.fromRGB(142, 148, 165),
}

local function make(class, props, parent)
	local o = Instance.new(class)

	for k, v in pairs(props) do
		o[k] = v
	end

	o.Parent = parent
	return o
end

local function round(obj, size)
	make("UICorner", {
		CornerRadius = UDim.new(0, size),
	}, obj)
end

-- GUI

local old = player.PlayerGui:FindFirstChild("FpsPingGui")

if old then
	old:Destroy()
end

local gui = make("ScreenGui", {
	Name = "FpsPingGui",
	ResetOnSpawn = false,
}, player.PlayerGui)

local bar = make("Frame", {
	AnchorPoint = Vector2.new(0, 1),

	Position = UDim2.new(0, 12, 1, -12),

	Size = UDim2.new(0, 0, 0, 30),

	AutomaticSize = Enum.AutomaticSize.X,

	BackgroundColor3 = COL.bg,

	BorderSizePixel = 0,

	Active = true,
}, gui)

round(bar, 8)

make("UIStroke", {
	Color = COL.stroke,
	Thickness = 1,
}, bar)

make("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
}, bar)

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)

local function label(text, color, font, order)
	return make("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),

		AutomaticSize = Enum.AutomaticSize.X,

		BackgroundTransparency = 1,

		Font = font,

		TextSize = 14,

		TextColor3 = color,

		Text = text,

		LayoutOrder = order,
	}, bar)
end

label("FPS", COL.red, Enum.Font.GothamBold, 1)

local fpsValue = label("--", COL.red, Enum.Font.GothamSemibold, 2)

make("Frame", {
	Size = UDim2.new(0, 1, 0, 16),

	BackgroundColor3 = COL.stroke,

	BorderSizePixel = 0,

	LayoutOrder = 3,
}, bar)

label("PING", COL.red, Enum.Font.GothamBold, 4)

local pingValue = label("--", COL.red, Enum.Font.GothamSemibold, 5)

local function fpsColor(fps)
	if fps >= 50 then
		return COL.green
	elseif fps >= 30 then
		return COL.yellow
	else
		return COL.red
	end
end

local function pingColor(ms)
	if ms <= 50 then
		return COL.green
	elseif ms <= 100 then
		return COL.yellow
	else
		return COL.red
	end
end

-- FPS

local frames = 0
local elapsed = 0

connect(RunService.RenderStepped, function(dt)
	frames = frames + 1
	elapsed = elapsed + dt

	if elapsed >= 0.5 then
		local fps = math.floor(frames / elapsed + 0.5)

		fpsValue.Text = tostring(fps)

		fpsValue.TextColor3 = fpsColor(fps)

		frames = 0
		elapsed = 0
	end
end)

-- PING

local pingTimer = 0

local function getPing()
	return math.floor(player:GetNetworkPing() * 1000 + 0.5)
end

connect(RunService.Heartbeat, function(dt)
	pingTimer = pingTimer + dt

	if pingTimer >= 1 then
		local ms = getPing()

		pingValue.Text = tostring(ms) .. "ms"

		pingValue.TextColor3 = pingColor(ms)

		pingTimer = 0
	end
end)

-- DRAGGING

do
	local dragging = false
	local start
	local pos

	connect(bar.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true

			start = i.Position

			pos = bar.Position
		end
	end)

	connect(UIS.InputChanged, function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - start

			bar.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
		end
	end)

	connect(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

_G.FpsPingCleanup = function()
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end

	if gui then
		gui:Destroy()
	end

	_G.FpsPingCleanup = nil
end