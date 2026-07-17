-- LocalScript (StarterPlayerScripts)
-- Script Hub: CFrame Speed + Gravity
-- K = hide/show GUI

-- H is the ONE chunk-level local in this file. Everything else lives inside a
-- do..end block and reaches across via H, so Lua's 200-locals-per-function cap
-- applies per BLOCK, not to the file. Adding a section costs zero permanent locals.
--
-- Convention: each block starts by aliasing what it needs out of H into real locals
-- (fast register access, no H. lookups in per-frame loops), and ends by publishing
-- its public surface back onto H.
local H = {}

do -- ===== CORE: services, theme, widgets, the main window, tabs =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
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

local waitingForToggleKey = false
H.keyChangeCooldown = false

-- Keybind labels. Anything in the UI that prints a key registers a refresher here;
-- H.refreshKeys() re-runs them all. Called after ANY rebind (the key chip, the fly key
-- button, !bind / !unbind, or a config load) so no label can show a stale key.
H.keyRefreshers = {}
H.refreshKeys = function()
	for _, f in ipairs(H.keyRefreshers) do
		pcall(f)
	end
end

-- what key currently triggers `action` ("-" if none)
H.keyFor = function(action)
	for keyName, boundCmd in pairs(H.Binds or {}) do
		if boundCmd == action then
			return keyName
		end
	end
	return "-"
end

-- Rebind `action` to keyName (nil to just clear it). Drops whatever the action was on
-- before, so an action never ends up on two keys and keyFor stays deterministic.
H.setBind = function(action, keyName)
	for k, v in pairs(H.Binds) do
		if v == action then
			H.Binds[k] = nil
		end
	end
	if keyName then
		H.Binds[keyName] = action
	end
	H.refreshKeys()
end

-- Same character as the original (dark, blue accent) with a little more depth: the bg
-- sits lower so panels read as raised, and stroke doubles as the tab hover colour.
-- NOTE: these are DEFAULTS. A saved twinkhub/config.json overrides them on load, so an
-- existing config keeps the old palette until you hit Reset in Settings.
local COL = {
	bg = Color3.fromRGB(19, 20, 26),
	element = Color3.fromRGB(38, 41, 52),
	stroke = Color3.fromRGB(55, 60, 74),
	accent = Color3.fromRGB(108, 128, 255),
	on = Color3.fromRGB(235, 76, 76),
	text = Color3.fromRGB(238, 241, 248),
	sub = Color3.fromRGB(139, 146, 165),
	off = Color3.fromRGB(70, 75, 90),
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

-- Click TP settings live out here, not inside the !clicktp builder, so closing the window
-- keeps them: the builder reads these on open and writes them as you change them.
-- Also saved to the config file, so they survive a rejoin too.
local ClickTp = {
	enabled = false,
	modifier = Enum.KeyCode.LeftControl,
	key = Enum.KeyCode.R,
}

-- THE keybind system. [KeyCode.Name] = command name; pressing the key feeds that command
-- back through hubRunCommand, so anything the command bar can do is bindable.
--
-- These four used to be hard-wired in two other places (K/C/G in their own InputBegan
-- handler, X inside the Fly tab). That meant `!bind fly x` fired BOTH X handlers and the
-- toggle cancelled itself out -- binds looked broken for any default key. One table, one
-- listener, no double-fire. Saved to the config file.
local Binds = {
	K = "menu",
	C = "cframe",
	G = "gravity",
	X = "fly",
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
round(main, 12)
make("UIStroke", { Color = COL.stroke, Thickness = 1 }, main)

-- ---------------- resizing ----------------
-- Every window is laid out with absolute pixel offsets (rows at y=0,24,48..., boxes at
-- 1,-78). Roblox has no layout engine, so genuinely reflowing that would mean rewriting
-- every element's geometry. A UIScale does what's actually wanted: it scales the frame,
-- its children AND their text together.
--
-- One scale per window, keyed by frame name, so you can size the hub and the settings
-- panel differently. Persisted in the config.
H.scales = {}
local liveScales = {}

H.setScale = function(name, v)
	v = math.clamp(tonumber(v) or 1, 0.6, 2.5)
	H.scales[name] = v
	local s = liveScales[name]
	if s and s.Parent then
		s.Scale = v
	end
	return v
end

-- Adds the UIScale + a drag grip in the bottom-right corner.
-- baseW/baseH are the frame's design size: dragging that many pixels = +1.0 scale, so
-- the drag feels the same on a small popup as on the main panel.
H.makeResizable = function(frame, baseW, baseH)
	local name = frame.Name
	local scale = Instance.new("UIScale")
	scale.Scale = H.scales[name] or 1
	scale.Parent = frame
	liveScales[name] = scale

	local grip = make("Frame", {
		Name = "ResizeGrip",
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(1, -15, 1, -15),
		BackgroundTransparency = 1,
		Active = true, -- so it catches the drag
		ZIndex = 50, -- above whatever the window puts in that corner
	}, frame)

	-- The classic corner dots, built from Frames rather than a glyph like "◢" -- Gotham
	-- has no such character and a missing glyph renders as a blank box.
	-- They're COL.sub, so make() registers them and they follow the theme.
	for _, d in ipairs({ { 9, 3 }, { 9, 6 }, { 6, 6 }, { 9, 9 }, { 6, 9 }, { 3, 9 } }) do
		make("Frame", {
			Size = UDim2.new(0, 2, 0, 2),
			Position = UDim2.new(0, d[1], 0, d[2]),
			BackgroundColor3 = COL.sub,
			BorderSizePixel = 0,
			ZIndex = 51,
		}, grip)
	end

	local dragging, startPos, startScale
	connect(grip.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, startPos, startScale = true, i.Position, scale.Scale
		end
	end)
	connect(UIS.InputChanged, function(i)
		if not dragging or i.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local d = i.Position - startPos
		-- average both axes so a diagonal drag tracks the corner
		H.setScale(name, startScale + ((d.X / baseW) + (d.Y / baseH)) / 2)
	end)
	connect(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			dragging = false
			if H.saveConfig then
				pcall(H.saveConfig) -- keep the size across reloads
			end
		end
	end)
	return scale
end

main.Name = "Main" -- keyed by name, so it needs one
H.makeResizable(main, 380, 254)

-- ---------------- dragging ----------------
-- Move `frame` by dragging `handle` (the frame itself if you don't pass one).
-- Every window used to carry its own near-identical copy of this; one of them had the
-- bug where rebuilding the position dropped the Scale component and snapped the panel
-- to the top -- hence carrying X.Scale/Y.Scale through here rather than assuming 0.
-- `conn` lets a caller supply its own connector: windows that get destroyed and rebuilt
-- (Click TP) track their connections separately so they can disconnect them, and using
-- the hub's `connect` there would leak two listeners per open.
H.makeDraggable = function(frame, handle, conn)
	handle = handle or frame
	conn = conn or connect
	handle.Active = true
	local dragging, startPos, framePos

	local function isDrag(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch
	end

	conn(handle.InputBegan, function(i)
		if isDrag(i) then
			dragging, startPos, framePos = true, i.Position, frame.Position
		end
	end)
	conn(UIS.InputChanged, function(i)
		if not dragging then
			return
		end
		if i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch
		then
			local d = i.Position - startPos
			frame.Position = UDim2.new(
				framePos.X.Scale,
				framePos.X.Offset + d.X,
				framePos.Y.Scale,
				framePos.Y.Offset + d.Y
			)
		end
	end)
	conn(UIS.InputEnded, function(i)
		if isDrag(i) then
			dragging = false
		end
	end)
	return frame
end


-- title bar
local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, main)

-- small accent pip: gives the title a spot of colour and reads as the theme's swatch
round(make("Frame", {
	Size = UDim2.new(0, 7, 0, 7),
	Position = UDim2.new(0, 13, 0, 15),
	BackgroundColor3 = COL.accent,
	BorderSizePixel = 0,
}, titleBar), 4)

make("TextLabel", {
	Size = UDim2.new(1, -66, 1, 0),
	Position = UDim2.new(0, 26, 0, 0),
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
	Text = "K", -- placeholder; H.refreshKeys() paints the real bind at startup
	BorderSizePixel = 0,
	AutoButtonColor = false,
}, titleBar)

round(keyChip, 6)

-- the chip always reads live: a !bind on `menu` shows here too
H.keyRefreshers[#H.keyRefreshers + 1] = function()
	if not waitingForToggleKey then
		keyChip.Text = H.keyFor("menu")
	end
end

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
			H.setBind("menu", input.KeyCode.Name) -- refreshes labels itself

			waitingForToggleKey = false
			H.keyChangeCooldown = true

			bind:Disconnect()

			task.delay(0.25, function()
				H.keyChangeCooldown = false
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

	-- hover only applies to inactive tabs; the selected one keeps its accent
	connect(btn.MouseEnter, function()
		if currentTab ~= name then
			tween(btn, { BackgroundColor3 = COL.stroke, TextColor3 = COL.text })
		end
	end)
	connect(btn.MouseLeave, function()
		if currentTab ~= name then
			tween(btn, { BackgroundColor3 = COL.element, TextColor3 = COL.sub })
		end
	end)

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

-- ---- publish the core surface ----
H.Players, H.RunService, H.UIS = Players, RunService, UIS
H.TweenService, H.HttpService = TweenService, HttpService
H.player, H.conns, H.connect = player, conns, connect
H.VERSION = VERSION
H.COL, H.ESPCOL, H.ClickTp, H.Binds = COL, ESPCOL, ClickTp, Binds
H.themedRefs, H.themeRefreshers = themedRefs, themeRefreshers
H.make, H.round, H.tween = make, round, tween
H.gui, H.click, H.main, H.titleBar, H.keyChip = gui, click, main, titleBar, keyChip
H.pages, H.tabs, H.selectTab, H.makeTab = pages, tabs, selectTab, makeTab
H.row, H.makeSwitch = row, makeSwitch
H.titleBar, H.conns = titleBar, conns
H.speedPage, H.gravPage, H.espPage, H.hitboxPage = speedPage, gravPage, espPage, hitboxPage
H.playerPage, H.flyPage, H.movePage, H.toolsPage = playerPage, flyPage, movePage, toolsPage
H.world = world
-- currentTab is block-local; hand out a re-assert instead of the variable
H.reselectTab = function()
	if currentTab then
		selectTab(currentTab)
	end
end
end -- CORE scope


-- ========== SPEED TAB ==========
-- Scoped; `Speed` below is the public surface (_G.CFrameSpeed stays global by design).
do
-- pulled out of H once, so the body below uses fast locals
local RunService, UIS, player, connect, COL, make = H.RunService, H.UIS, H.player, H.connect, H.COL, H.make
local round, row, makeSwitch, speedPage = H.round, H.row, H.makeSwitch, H.speedPage

-- these were chunk-level; only this section ever touched them
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local speedEnabled = false
-- label re-reads the key, so `!bind cframe <key>` retitles this row
local speedRow = row(speedPage, 0, "CFrame movement")
H.keyRefreshers[#H.keyRefreshers + 1] = function()
	speedRow.Text = "CFrame movement [" .. H.keyFor("cframe") .. "]"
end
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

H.Speed = { toggle = toggleSpeed, updateUI = updateSpeedUI }
end -- Speed scope

-- ========== GRAVITY TAB ==========
-- Scoped; `Grav` below is the public surface.
do
-- pulled out of H once, so the body below uses fast locals
local connect, COL, make, round, row, makeSwitch = H.connect, H.COL, H.make, H.round, H.row, H.makeSwitch
local gravPage = H.gravPage

local normalGravity = workspace.Gravity
if normalGravity == 0 then
	normalGravity = 196.2
end

-- the switch applies whatever is in the box; flipping it off restores normalGravity
local customGravity = normalGravity
local gravEnabled = false
local applyingGravity = false -- guard so our own writes aren't mistaken for the game's

local gravRow = row(gravPage, 0, "Custom gravity")
H.keyRefreshers[#H.keyRefreshers + 1] = function()
	gravRow.Text = "Custom gravity [" .. H.keyFor("gravity") .. "]"
end

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

H.Grav = {
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
do
-- pulled out of H once, so the body below uses fast locals
local Players, RunService, player, connect, ESPCOL, row = H.Players, H.RunService, H.player, H.connect, H.ESPCOL, H.row
local makeSwitch, espPage = H.makeSwitch, H.espPage

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

local toggleEspMain = select(2, makeSwitch(espPage, 0, false, function(on)
	espEnabled = on and drawingOk
	if not espEnabled then
		for _, o in pairs(espObjects) do
			espHide(o)
		end
	end
end))

-- setters sync switch visuals from a loaded config (no callback); toggles are what the
-- `esp <type>` command uses, so a command and a click behave identically
local espSetters, espToggles = {}, {}

espSetters.distance, espToggles.distance = makeSwitch(espPage, 24, espDistance, function(on)
	espDistance = on
end)

espSetters.health, espToggles.health = makeSwitch(espPage, 48, espHealth, function(on)
	espHealth = on
end)

espSetters.skeleton, espToggles.skeleton = makeSwitch(espPage, 72, espSkeleton, function(on)
	espSkeleton = on
end)

espSetters.box, espToggles.box = makeSwitch(espPage, 96, espBox, function(on)
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

H.Esp = {
	remove = espRemove,
	objects = espObjects,
	toggle = function()
		toggleEspMain()
		return espEnabled
	end,
	isOn = function()
		return espEnabled
	end,
	hasDrawing = function()
		return drawingOk
	end,
	-- "box" | "distance" | "health" | "skeleton"; returns nil if the name isn't one
	toggleType = function(name)
		if not espToggles[name] then
			return nil
		end
		espToggles[name]()
		return ({ box = espBox, distance = espDistance, health = espHealth, skeleton = espSkeleton })[name]
	end,
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
do
-- pulled out of H once, so the body below uses fast locals
local Players, RunService, player, connect, COL, make = H.Players, H.RunService, H.player, H.connect, H.COL, H.make
local round, row, makeSwitch, hitboxPage = H.round, H.row, H.makeSwitch, H.hitboxPage

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

H.Hitbox = {
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
do
-- pulled out of H once, so the body below uses fast locals
local Players, player, connect, COL, make, round = H.Players, H.player, H.connect, H.COL, H.make, H.round
local click, playerPage = H.click, H.playerPage

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
	Position = UDim2.new(0, 5, 0, 0),
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
-- TextScaled alone made "Player name" fill the whole row (huge), then shrink to nothing
-- once it became the long "Player: x, Username: y, ID: z". The constraint keeps the
-- scaling (long names still shrink to fit) but caps it at the size everything else uses.
make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7 }, playerMainRow)

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

H.findPlayer = findPlayer
end -- Player scope

-- ========== FLY TAB ==========
-- (adapted from the standalone sfly build: gyro/velocity flight, bobbing hover,
--  inertia slide, superman pitch/roll, custom fly animations)
-- Scoped: the fattest section in the file (~27 locals). Everything the outside needs is
-- handed out through the `Fly` table at the bottom, so nothing in here gets renamed.
do
-- pulled out of H once, so the body below uses fast locals
local RunService, UIS, player, connect, COL, make = H.RunService, H.UIS, H.player, H.connect, H.COL, H.make
local round, click, row, makeSwitch, flyPage = H.round, H.click, H.row, H.makeSwitch, H.flyPage

local flyEnabled = false
local flightSpeed = 50
local FLY_MAX_SPEED = 9842774
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
	Text = "X", -- placeholder; H.refreshKeys() paints the real bind at startup
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, flyPage)
round(flyKeyBtn, 6)
-- reads live, so `!bind fly <key>` retitles this button too
H.keyRefreshers[#H.keyRefreshers + 1] = function()
	if not awaitingFlyKey then
		flyKeyBtn.Text = H.keyFor("fly")
	end
end
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
		H.setBind("fly", kc.Name)
		return
	end
	-- no `if i.KeyCode == flyKey` here any more: the single bind listener owns that,
	-- and having both meant X toggled twice and appeared to do nothing
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
H.Fly = {
	stop = stopFly,
	doSfly = doSfly,
	getSpeed = function()
		return flightSpeed
	end,
	setSpeed = function(v)
		flightSpeed = math.clamp(v, 0, FLY_MAX_SPEED)
		flyBox.Text = tostring(flightSpeed)
	end,
}
end -- Fly scope

-- ========== MOVEMENT TAB ==========
-- Scoped; `Move` below is the public surface.
do
-- pulled out of H once, so the body below uses fast locals
local RunService, UIS, player, connect, COL, make = H.RunService, H.UIS, H.player, H.connect, H.COL, H.make
local round, row, makeSwitch, movePage = H.round, H.row, H.makeSwitch, H.movePage

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

-- capture the toggle halves so commands flip the switch the same way a click does
-- (that keeps the tab visuals in sync automatically)
row(movePage, 0, "Noclip")
local toggleNoclip = select(2, makeSwitch(movePage, 0, false, function(on)
	noclipEnabled = on
	if not on then
		noclipRestore()
	end
end))

row(movePage, 24, "Infinite jump")
local toggleInfJump = select(2, makeSwitch(movePage, 24, false, function(on)
	infJumpEnabled = on
end))

-- spin: command-only (the Movement page has no room for a 5th row)
local spinEnabled = false
local spinSpeed = 10
connect(RunService.RenderStepped, function()
	if not spinEnabled then
		return
	end
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0)
	end
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

H.Move = {
	restore = noclipRestore,
	toggleNoclip = toggleNoclip,
	toggleInfJump = toggleInfJump,
	isNoclip = function()
		return noclipEnabled
	end,
	isInfJump = function()
		return infJumpEnabled
	end,
	-- spin: no arg toggles, a number sets the speed and turns it on (same shape as sfly)
	spin = function(v)
		if v then
			spinSpeed = math.clamp(v, -50, 50)
			spinEnabled = true
		else
			spinEnabled = not spinEnabled
		end
		return spinEnabled, spinSpeed
	end,
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
-- Scoped like every other section. (It was the one tab still sitting at chunk level:
-- once the core moved into H, its bare `world` / `row` / `make` / `COL` references
-- would have resolved to nil globals.)
do
-- pulled out of H once, so the body below uses fast locals
local COL, make, round, connect, click, world = H.COL, H.make, H.round, H.connect, H.click, H.world
local row, makeSwitch, player, Players = H.row, H.makeSwitch, H.player, H.Players

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

-- brightness/time also write world.orig so switching fullbright off restores the value
-- you asked for, not the one the game started with
world.setBrightness = function(v)
	world.capture()
	v = math.clamp(v, 0, 10)
	world.orig.Brightness = v
	world.lighting.Brightness = v
	return v
end

world.setTime = function(v)
	world.capture()
	v = math.clamp(v, 0, 24) % 24
	world.orig.ClockTime = v
	world.lighting.ClockTime = v
	return v
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

-- toggle halves captured so the commands drive the same switches the clicks do
row(world.page, 0, "Fullbright")
world.toggleFullbright = select(2, makeSwitch(world.page, 0, false, function(on)
	world.fullbright = on
	world.applyLighting()
end))

row(world.page, 24, "No fog")
world.toggleNofog = select(2, makeSwitch(world.page, 24, false, function(on)
	world.nofog = on
	world.applyLighting()
end))

row(world.page, 48, "X-ray")
world.xrayOn = false
world.toggleXray = select(2, makeSwitch(world.page, 48, false, function(on)
	world.xrayOn = on
	world.setXray(on)
end))

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

end -- World scope

-- ========== TOOLS TAB ==========
-- scrolling list of placeholder buttons (10 don't fit in the panel, so it scrolls)
-- Wrapped in do..end: nothing outside this block reads these locals, and Lua's 200-local
-- cap counts *active* locals, so closing the block hands the registers back.
-- (Body left at its original indent to keep the diff readable.)
do
-- pulled out of H once, so the body below uses fast locals
local connect, COL, make, round, click, toolsPage = H.connect, H.COL, H.make, H.round, H.click, H.toolsPage
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
do
-- pulled out of H once, so the body below uses fast locals
local UIS, HttpService, connect, COL, ESPCOL, ClickTp = H.UIS, H.HttpService, H.connect, H.COL, H.ESPCOL, H.ClickTp
local Binds, themedRefs, themeRefreshers, make, round, gui = H.Binds, H.themedRefs, H.themeRefreshers, H.make, H.round, H.gui
local click, main, keyChip, selectTab, world = H.click, H.main, H.keyChip, H.selectTab, H.world
local Speed, Grav, Esp, Hitbox, Move, Fly = H.Speed, H.Grav, H.Esp, H.Hitbox, H.Move, H.Fly
-- Everything the hub writes lives under ONE folder in the executor's workspace:
--   twinkhub/config.json
--   twinkhub/themes/<name>.json
-- Paths are relative because that's all writefile gives us; the executor decides where
-- its workspace folder actually is on disk.
local HUB_DIR = "twinkhub"
local THEME_DIR = HUB_DIR .. "/themes"
local CONFIG_FILE = HUB_DIR .. "/config.json"

-- writefile/readfile/isfile are executor features; degrade to in-memory-only without them
local canSaveFiles = (writefile ~= nil and readfile ~= nil and isfile ~= nil)

-- writefile won't create parent folders, so make them before any write
local function ensureDirs()
	if not makefolder then
		return false
	end
	if isfolder and not isfolder(HUB_DIR) then
		pcall(makefolder, HUB_DIR)
	end
	if isfolder and not isfolder(THEME_DIR) then
		pcall(makefolder, THEME_DIR)
	end
	return true
end

-- One-time move from the old flat layout (twinkhub_config.json + twinkhub_themes/ sat
-- loose in the workspace root). Copy rather than trust a rename, then drop the original.
local function migrateOldFiles()
	if not canSaveFiles then
		return
	end
	ensureDirs()
	if isfile("twinkhub_config.json") and not isfile(CONFIG_FILE) then
		local ok, raw = pcall(readfile, "twinkhub_config.json")
		if ok and pcall(writefile, CONFIG_FILE, raw) and delfile then
			pcall(delfile, "twinkhub_config.json")
		end
	end
	if listfiles and isfolder and isfolder("twinkhub_themes") then
		local ok, files = pcall(listfiles, "twinkhub_themes")
		if ok then
			for _, f in ipairs(files) do
				local name = tostring(f):match("([^\\/]+%.json)$")
				if name and not isfile(THEME_DIR .. "/" .. name) then
					local ok2, raw = pcall(readfile, f)
					if ok2 then
						pcall(writefile, THEME_DIR .. "/" .. name, raw)
					end
				end
			end
		end
	end
end
pcall(migrateOldFiles)

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

-- Enum.KeyCode[name] throws on a bad name, so resolve by scanning instead.
-- Case-insensitive so `bind fly x` and `bind fly LeftControl` both work.
local function keyFromName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	name = name:lower()
	for _, kc in ipairs(Enum.KeyCode:GetEnumItems()) do
		if kc.Name:lower() == name then
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
		cframeSpeed = _G.CFrameSpeed,
		gravity = Grav.getCustom(),
		hitboxSize = Hitbox.getSize(),
		flySpeed = Fly.getSpeed(),
		walkSpeed = Move.getWalkSpeed(),
		jumpPower = Move.getJumpPower(),
		fov = world.fov,
		esp = Esp.get(),
		clickTp = {
			enabled = ClickTp.enabled,
			modifier = ClickTp.modifier.Name,
			key = ClickTp.key.Name,
		},
		binds = Binds,
		scales = H.scales,
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
	if type(cfg.scales) == "table" then
		for winName, v in pairs(cfg.scales) do
			if tonumber(v) then
				H.setScale(winName, v)
			end
		end
	end
	if tonumber(cfg.fov) then
		world.fov = math.clamp(tonumber(cfg.fov), 1, 120)
		world.fovBox.Text = tostring(world.fov)
		world.applyFov()
	end
	if type(cfg.esp) == "table" then
		Esp.set(cfg.esp)
	end
	-- Only a NON-EMPTY binds table replaces the seeded defaults. An empty/missing one
	-- leaves K/C/G/X alone -- otherwise a config written before the defaults existed
	-- (or a stray `bind clear` + save) would wipe your keys on every load and there'd
	-- be no key left to open the menu with.
	local hasBinds = false
	if type(cfg.binds) == "table" then
		for _ in pairs(cfg.binds) do
			hasBinds = true
			break
		end
	end
	if hasBinds then
		for k in pairs(Binds) do
			Binds[k] = nil
		end
		for keyName, command in pairs(cfg.binds) do
			-- re-resolve the key so a garbage name in the file can't wedge the listener
			if type(command) == "string" and keyFromName(keyName) then
				Binds[keyName] = command
			end
		end
	end
	if type(cfg.clickTp) == "table" then
		if type(cfg.clickTp.enabled) == "boolean" then
			ClickTp.enabled = cfg.clickTp.enabled
		end
		local mk = keyFromName(cfg.clickTp.modifier)
		if mk then
			ClickTp.modifier = mk
		end
		local ck = keyFromName(cfg.clickTp.key)
		if ck then
			ClickTp.key = ck
		end
	end
	-- legacy configs stored these separately; fold them into Binds
	if cfg.toggleKey and keyFromName(cfg.toggleKey) then
		H.setBind("menu", cfg.toggleKey)
	end
	if cfg.flyKey and keyFromName(cfg.flyKey) then
		H.setBind("fly", cfg.flyKey)
	end
	applyTheme()
	H.refreshKeys() -- binds/keys may have changed
	if refreshSettingsUI then
		refreshSettingsUI()
	end
end

local function saveConfig()
	if not canSaveFiles then
		return false, "no file API"
	end
	ensureDirs() -- writefile fails if twinkhub/ doesn't exist yet
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
H.makeResizable(setFrame, 320, 340)

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
H.makeResizable(picker.frame, 230, 216)

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

H.makeDraggable(picker.frame, picker.title)

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

-- ---------------- themes ----------------
-- A theme is just the colour tables as JSON. Paste one in, or save the current one to
-- twinkhub/themes/<name>.json and pick it back out of the dropdown.
-- (THEME_DIR / ensureDirs live up with CONFIG_FILE, so both writers share one layout)

-- Built-in themes. Written as hex on purpose: this table IS theme JSON, so it doubles as
-- the format's documentation and you can paste any of it straight into the box.
-- `on` is the toggle-ON colour and the knob drawn over it is always white, so every one
-- of these keeps `on` mid-dark enough for the knob to read.
local PRESETS = {
	{
		name = "Default",
		colors = { bg = "#13141A", element = "#262934", stroke = "#373C4A", accent = "#6C80FF",
			on = "#EB4C4C", text = "#EEF1F8", sub = "#8B92A5", off = "#464B5A" },
		espColors = { box = "#E64444", name = "#FFFFFF", skeleton = "#E64444" },
	},
	{
		name = "Midnight",
		colors = { bg = "#0D111F", element = "#1A2238", stroke = "#283450", accent = "#528CFF",
			on = "#E8546E", text = "#E7EEFC", sub = "#8091B4", off = "#374460" },
		espColors = { box = "#528CFF", name = "#FFFFFF", skeleton = "#528CFF" },
	},
	{
		name = "Dracula",
		colors = { bg = "#1E1F2C", element = "#2D2F42", stroke = "#444760", accent = "#BD93F9",
			on = "#FF5555", text = "#F8F8F2", sub = "#9498B5", off = "#4F526E" },
		espColors = { box = "#BD93F9", name = "#F8F8F2", skeleton = "#FF79C6" },
	},
	{
		name = "Catppuccin",
		colors = { bg = "#1E1E2E", element = "#313244", stroke = "#45475A", accent = "#89B4FA",
			on = "#F38BA8", text = "#CDD6F4", sub = "#9399B2", off = "#585B70" },
		espColors = { box = "#89B4FA", name = "#CDD6F4", skeleton = "#F5C2E7" },
	},
	{
		name = "Nord",
		colors = { bg = "#2E3440", element = "#3B4252", stroke = "#4C566A", accent = "#88C0D0",
			on = "#BF616A", text = "#ECEFF4", sub = "#949EAE", off = "#545E72" },
		espColors = { box = "#88C0D0", name = "#ECEFF4", skeleton = "#8FBCBB" },
	},
	{
		name = "Crimson",
		colors = { bg = "#160F11", element = "#2C1A1E", stroke = "#48282E", accent = "#E83E50",
			on = "#E83E50", text = "#F5EBED", sub = "#A88A90", off = "#54363C" },
		espColors = { box = "#E83E50", name = "#FFFFFF", skeleton = "#E83E50" },
	},
	{
		name = "Emerald",
		colors = { bg = "#0F1A16", element = "#1B2E26", stroke = "#2A463A", accent = "#34D399",
			on = "#F46060", text = "#E8F5EF", sub = "#82A496", off = "#385448" },
		espColors = { box = "#34D399", name = "#E8F5EF", skeleton = "#34D399" },
	},
	{
		name = "Ocean",
		colors = { bg = "#0C1A20", element = "#162D36", stroke = "#224452", accent = "#22C5D6",
			on = "#F05A6E", text = "#E2F4F8", sub = "#7C9EAA", off = "#2E505C" },
		espColors = { box = "#22C5D6", name = "#E2F4F8", skeleton = "#22C5D6" },
	},
	{
		name = "Amber",
		-- accent is deliberately darker than the ESP amber: white text sits on the accent
		-- (active tab, buttons) and #FBB034 only gave it 1.85 contrast
		colors = { bg = "#1A150D", element = "#2F2618", stroke = "#4A3C26", accent = "#C2800E",
			on = "#EB573C", text = "#F8F1E5", sub = "#AC9B80", off = "#584830" },
		espColors = { box = "#FBB034", name = "#FFFFFF", skeleton = "#FBB034" },
	},
	{
		name = "Rose",
		colors = { bg = "#1C121A", element = "#32202E", stroke = "#4E3248", accent = "#F472B6",
			on = "#F05078", text = "#FAEEF6", sub = "#B28EA8", off = "#5C3E54" },
		espColors = { box = "#F472B6", name = "#FAEEF6", skeleton = "#F472B6" },
	},
	{
		name = "Ultraviolet",
		colors = { bg = "#120C1F", element = "#231838", stroke = "#392A58", accent = "#A855F7",
			on = "#EC4899", text = "#EDE4FA", sub = "#9C8CB8", off = "#443064" },
		espColors = { box = "#A855F7", name = "#EDE4FA", skeleton = "#EC4899" },
	},
	{
		name = "Matrix",
		-- UI greens are the muted ones (white text/knob ride on accent and `on`); the
		-- vivid #3BE86B is kept for the ESP drawings, where nothing sits on top of it
		colors = { bg = "#0A0F0A", element = "#152015", stroke = "#263A26", accent = "#239E49",
			on = "#239E49", text = "#D6F5DC", sub = "#7BA383", off = "#2C452F" },
		espColors = { box = "#3BE86B", name = "#D6F5DC", skeleton = "#3BE86B" },
	},
	{
		name = "Mono",
		colors = { bg = "#121212", element = "#262626", stroke = "#3E3E3E", accent = "#7A7A7A",
			on = "#9E9E9E", text = "#F0F0F0", sub = "#919191", off = "#3C3C3C" },
		espColors = { box = "#EBEBEB", name = "#FFFFFF", skeleton = "#C8C8C8" },
	},
	{
		-- the only light one: `text` goes dark, and the white switch knob still reads
		-- because `on`/`off` stay mid-tone
		name = "Daylight",
		colors = { bg = "#F2F3F7", element = "#E2E5EE", stroke = "#C8CDDC", accent = "#4C6EF5",
			on = "#E03C3C", text = "#1C1E26", sub = "#6C748A", off = "#B0B6C6" },
		espColors = { box = "#E03C3C", name = "#FFFFFF", skeleton = "#E03C3C" },
	},
}

local function findPreset(name)
	for _, t in ipairs(PRESETS) do
		if t.name == name then
			return t
		end
	end
end
local themeBox, themeNameBox, themeDropBtn, themeDropList
local selectedTheme

local function themeToJson()
	local t = { colors = {}, espColors = {} }
	for k, v in pairs(COL) do
		t.colors[k] = "#" .. toHex(v)
	end
	for k, v in pairs(ESPCOL) do
		t.espColors[k] = "#" .. toHex(v)
	end
	return HttpService:JSONEncode(t)
end

-- returns how many colours it actually applied
local function applyThemeTable(t)
	if type(t) ~= "table" then
		return 0
	end
	local n = 0
	local function put(tbl, k, hex)
		if tbl[k] == nil or type(hex) ~= "string" then
			return
		end
		local c = fromHex(hex)
		if c then
			tbl[k] = c
			n += 1
		end
	end
	if type(t.colors) == "table" then
		for k, hex in pairs(t.colors) do
			put(COL, k, hex)
		end
	end
	if type(t.espColors) == "table" then
		for k, hex in pairs(t.espColors) do
			put(ESPCOL, k, hex)
		end
	end
	-- also accept a flat { bg = "#111", box = "#f00" } shape, so a hand-written theme
	-- doesn't have to know about the colors/espColors split
	for k, hex in pairs(t) do
		if type(hex) == "string" then
			put(COL, k, hex)
			put(ESPCOL, k, hex)
		end
	end
	if n > 0 then
		applyTheme()
		refreshSettingsUI()
	end
	return n
end

local function themeFiles()
	local out = {}
	if not listfiles then
		return out
	end
	local ok, files = pcall(listfiles, THEME_DIR)
	if not ok then
		return out
	end
	for _, f in ipairs(files) do
		local name = tostring(f):match("([^\\/]+)%.json$")
		if name then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

local function saveTheme(name)
	name = tostring(name or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return false, "name it first"
	end
	if not writefile then
		return false, "executor has no writefile"
	end
	ensureDirs()
	local ok = pcall(writefile, THEME_DIR .. "/" .. name .. ".json", themeToJson())
	return ok, ok and name or "writefile failed"
end

local function readTheme(name)
	local path = THEME_DIR .. "/" .. name .. ".json"
	if not (readfile and isfile and isfile(path)) then
		return false, "not found"
	end
	local ok, raw = pcall(readfile, path)
	if not ok then
		return false, "read failed"
	end
	local ok2, t = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok2 then
		return false, "file isn't valid JSON"
	end
	local n = applyThemeTable(t)
	return n > 0, n > 0 and n or "no known colours in it"
end

-- NOT the same `row` as the tab sections use (that one makes a labelled switch row).
-- Named apart on purpose: Settings doesn't alias H.row, and two meanings for one name
-- is how you get a confusing bug later.
local function themeRow(order, height)
	return make("Frame", {
		Size = UDim2.new(1, -6, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, setScroll)
end

local function smallBtn(parent, text, xScale, xOff, w, colour)
	local b = make("TextButton", {
		Size = UDim2.new(xScale, w, 0, 22),
		Position = UDim2.new(xScale == 0 and 0 or xScale, xOff, 0.5, -11),
		BackgroundColor3 = colour,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, parent)
	round(b, 5)
	return b
end

do
	make("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = COL.sub,
		Text = "THEMES  -  paste JSON, or save the current colours",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, themeRow(20, 18))

	themeBox = make("TextBox", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = COL.element,
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = COL.text,
		Text = "",
		PlaceholderText = '{"colors":{"bg":"#131A1A"...}}',
		PlaceholderColor3 = COL.sub,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ClipsDescendants = true,
	}, themeRow(21, 56))
	round(themeBox, 5)

	local r22 = themeRow(22, 26)
	local copyBtn = smallBtn(r22, "Copy current", 0, 0, 0.48, COL.element)
	copyBtn.Size = UDim2.new(0.48, 0, 0, 22)
	local applyBtn = smallBtn(r22, "Apply pasted", 0.52, 0, 0.48, COL.accent)
	applyBtn.Size = UDim2.new(0.48, 0, 0, 22)

	connect(copyBtn.MouseButton1Click, function()
		click()
		themeBox.Text = themeToJson()
		setStatus.Text = "current theme in the box - copy it out"
	end)

	connect(applyBtn.MouseButton1Click, function()
		click()
		local ok, t = pcall(function()
			return HttpService:JSONDecode(themeBox.Text)
		end)
		if not ok then
			setStatus.Text = "that isn't valid JSON"
			return
		end
		local n = applyThemeTable(t)
		if n > 0 then
			autoSave()
			setStatus.Text = "applied " .. n .. " colours"
		else
			setStatus.Text = "no known colours in that JSON"
		end
	end)

	-- name + save
	local r23 = themeRow(23, 26)
	themeNameBox = make("TextBox", {
		Size = UDim2.new(0.62, 0, 0, 22),
		Position = UDim2.new(0, 0, 0.5, -11),
		BackgroundColor3 = COL.element,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = COL.text,
		Text = "",
		PlaceholderText = "theme name",
		PlaceholderColor3 = COL.sub,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, r23)
	round(themeNameBox, 5)
	local saveThemeBtn = smallBtn(r23, "Save theme", 0.65, 0, 0.35, COL.accent)
	saveThemeBtn.Size = UDim2.new(0.35, 0, 0, 22)

	-- dropdown + load/delete
	local r24 = themeRow(24, 26)
	themeDropBtn = make("TextButton", {
		Size = UDim2.new(0.62, 0, 0, 22),
		Position = UDim2.new(0, 0, 0.5, -11),
		BackgroundColor3 = COL.element,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = COL.text,
		Text = "saved themes",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, r24)
	round(themeDropBtn, 5)
	local loadThemeBtn = smallBtn(r24, "Load", 0.65, 0, 0.16, COL.accent)
	loadThemeBtn.Size = UDim2.new(0.16, 0, 0, 22)
	local delThemeBtn = smallBtn(r24, "Delete", 0.83, 0, 0.17, COL.on)
	delThemeBtn.Size = UDim2.new(0.17, 0, 0, 22)

	-- The popup hangs off setFrame, not the scrolling row: inside the ScrollingFrame it
	-- would be clipped and would scroll away from its button.
	themeDropList = make("ScrollingFrame", {
		Size = UDim2.new(0, 180, 0, 110),
		BackgroundColor3 = COL.element,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = COL.sub,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Visible = false,
		ZIndex = 20,
	}, setFrame)
	round(themeDropList, 5)
	make("UIStroke", { Color = COL.stroke, Thickness = 1 }, themeDropList)
	local dropLayout = make("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, themeDropList)

	local function pick(name)
		selectedTheme = name
		themeDropBtn.Text = name or "saved themes"
		themeDropList.Visible = false
	end

	local function rebuildDrop()
		for _, c in ipairs(themeDropList:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		-- built-ins first, then whatever's on disk
		local entries, order = {}, 0
		for _, t in ipairs(PRESETS) do
			entries[#entries + 1] = { name = t.name, preset = true }
		end
		for _, name in ipairs(themeFiles()) do
			entries[#entries + 1] = { name = name, preset = false }
		end
		for _, e in ipairs(entries) do
			order += 1
			local b = make("TextButton", {
				Size = UDim2.new(1, -6, 0, 20),
				BackgroundColor3 = COL.bg,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextColor3 = e.preset and COL.sub or COL.text,
				Text = (e.preset and "  " or "  * ") .. e.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = order,
				ZIndex = 21,
			}, themeDropList)
			round(b, 4)
			connect(b.MouseButton1Click, function()
				click()
				pick(e.name)
			end)
		end
		themeDropList.CanvasSize = UDim2.new(0, 0, 0, dropLayout.AbsoluteContentSize.Y + 4)
	end

	connect(themeDropBtn.MouseButton1Click, function()
		click()
		if themeDropList.Visible then
			themeDropList.Visible = false
			return
		end
		rebuildDrop()
		-- park it under the button, in setFrame's coordinate space
		local a, b = themeDropBtn.AbsolutePosition, setFrame.AbsolutePosition
		themeDropList.Position = UDim2.new(0, a.X - b.X, 0, a.Y - b.Y + 24)
		themeDropList.Visible = true
	end)

	connect(saveThemeBtn.MouseButton1Click, function()
		click()
		local ok, res = saveTheme(themeNameBox.Text)
		setStatus.Text = ok and ("saved theme '" .. res .. "'") or ("save failed: " .. res)
		if ok then
			themeNameBox.Text = ""
			rebuildDrop()
			pick(res)
		end
	end)

	connect(loadThemeBtn.MouseButton1Click, function()
		click()
		if not selectedTheme then
			setStatus.Text = "pick a theme first"
			return
		end
		local preset = findPreset(selectedTheme)
		if preset then
			local n = applyThemeTable(preset)
			themeBox.Text = themeToJson() -- so you can see/copy what it just applied
			autoSave()
			setStatus.Text = "loaded '" .. selectedTheme .. "' (" .. n .. " colours)"
			return
		end
		local ok, res = readTheme(selectedTheme)
		if ok then
			themeBox.Text = themeToJson()
			autoSave()
			setStatus.Text = "loaded '" .. selectedTheme .. "' (" .. res .. " colours)"
		else
			setStatus.Text = "load failed: " .. tostring(res)
		end
	end)

	connect(delThemeBtn.MouseButton1Click, function()
		click()
		if not selectedTheme then
			setStatus.Text = "pick a theme first"
			return
		end
		if findPreset(selectedTheme) then
			setStatus.Text = "can't delete a built-in theme"
			return
		end
		if delfile then
			pcall(delfile, THEME_DIR .. "/" .. selectedTheme .. ".json")
			setStatus.Text = "deleted '" .. selectedTheme .. "'"
			selectedTheme = nil
			rebuildDrop()
			pick(nil)
		else
			setStatus.Text = "executor has no delfile"
		end
	end)

	rebuildDrop()
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
-- re-assert the accent on the selected tab (reselectTab no-ops if none is selected)
themeRefreshers[#themeRefreshers + 1] = H.reselectTab

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

H.makeDraggable(setFrame, setTitle)

-- exports: startup calls load once every tab exists; save is used by the Click TP window
-- and the bind commands; keyFromName resolves `bind fly x`
H.loadConfig = loadConfig
H.saveConfig = saveConfig
H.keyFromName = keyFromName
end -- Settings scope

-- ========== COMMAND BAR ==========
-- Inline bar in the bottom strip, sat between the cog (ends x=34) and Unload (starts x=248).
-- hubRunCommand is THE command implementation: this bar, the !cmdbar popup and
-- player.Chatted all route through it, so the three copies that used to drift are gone.
-- Feedback goes to this bar's placeholder via say(); chat callers just ignore it.
do
-- pulled out of H once, so the body below uses fast locals
local Players, UIS, player, connect, COL, ClickTp = H.Players, H.UIS, H.player, H.connect, H.COL, H.ClickTp
local Binds, make, round, gui, click, main = H.Binds, H.make, H.round, H.gui, H.click, H.main
local world = H.world
local Speed, Grav, Esp, Hitbox, Move, Fly, hubFindPlayer, hubSaveConfig, hubKeyFromName = H.Speed, H.Grav, H.Esp, H.Hitbox, H.Move, H.Fly, H.findPlayer, H.saveConfig, H.keyFromName
local hubRunCommand

local cmdBox = make("TextBox", {
	Size = UDim2.new(0, 190, 0, 26),
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

-- ---------------- command registry ----------------
-- Adding a command is ONE add{} block. `help` and `bind help` are generated from this
-- list, so they can never drift out of sync with what actually runs.
--
--   add{
--     name  = "noclip",              -- what you type
--     alias = { "nc" },              -- optional extra names
--     args  = "<n>",                 -- optional, shown in help only
--     group = "Toggles",             -- help section heading
--     help  = "Walk through walls",  -- one-line description
--     bindable = true,               -- offer it in `bind help`
--     run = function(c) ... end,     -- c.arg = text after the name, c.n = that as a number
--   }
--
-- run() returns a string to show in the bar, or nil to stay quiet.
local CMDS, ORDER = {}, {}

local function add(spec)
	ORDER[#ORDER + 1] = spec
	CMDS[spec.name] = spec
	for _, a in ipairs(spec.alias or {}) do
		CMDS[a] = spec
	end
end

local function onoff(b)
	return b and "on" or "off"
end

-- "fly / sfly <speed>"
local function signature(s)
	local out = s.name
	for _, a in ipairs(s.alias or {}) do
		out = out .. " / " .. a
	end
	return s.args and (out .. " " .. s.args) or out
end

-- ---------------- shared window helper ----------------
-- every popup here is the same shape: titled frame + close X + scrolling rows
local function listWindow(name, title, rows)
	if gui:FindFirstChild(name) then
		gui[name]:Destroy()
		return
	end
	local f = make("Frame", {
		Name = name,
		Size = UDim2.new(0, 380, 0, 420),
		Position = UDim2.new(0.5, -190, 0.5, -210),
		BackgroundColor3 = COL.bg,
		BorderSizePixel = 0,
		Active = true,
	}, gui)
	round(f, 10)
	make("UIStroke", { Color = COL.stroke, Thickness = 1 }, f)
	H.makeResizable(f, 380, 420)

	local bar = make("TextLabel", {
		Size = UDim2.new(1, -44, 0, 34),
		Position = UDim2.new(0, 14, 0, 2),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = COL.text,
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	bar.Active = true

	local x = make("TextButton", {
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -32, 0, 6),
		BackgroundColor3 = COL.on,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, f)
	round(x, 6)
	connect(x.MouseButton1Click, function()
		click()
		f:Destroy()
	end)

	local sc = make("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -48),
		Position = UDim2.new(0, 10, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COL.sub,
		CanvasSize = UDim2.new(0, 0, 0, 0),
	}, f)
	local layout = make("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, sc)

	for i, r in ipairs(rows) do
		local isHeader = r.header
		local lbl = make("TextLabel", {
			Size = UDim2.new(1, -6, 0, isHeader and 20 or 24),
			BackgroundTransparency = isHeader and 1 or 0,
			Font = isHeader and Enum.Font.GothamBold or Enum.Font.Gotham,
			TextSize = isHeader and 11 or 12,
			TextColor3 = isHeader and COL.sub or COL.text,
			Text = isHeader and r.text or ("  " .. r.text),
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, sc)
		if not isHeader then
			lbl.BackgroundColor3 = COL.element
			round(lbl, 5)
		end
	end

	local function size()
		sc.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
	end
	connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), size)
	size()

	H.makeDraggable(f, bar)
end

-- ---------------- generated windows ----------------
local function openHelp()
	local rows, lastGroup = {}, nil
	for _, s in ipairs(ORDER) do
		if s.group ~= lastGroup then
			lastGroup = s.group
			rows[#rows + 1] = { text = string.upper(s.group), header = true }
		end
		rows[#rows + 1] = { text = "!" .. signature(s) .. "   -   " .. s.help }
	end
	listWindow("HelpUI", "Twink Hub Commands", rows)
end

local function openBindHelp()
	local rows = { { text = "bind <action> <key>   e.g.  bind fly x", header = true } }
	for _, s in ipairs(ORDER) do
		if s.bindable then
			local bound
			for k, c in pairs(Binds) do
				if c == s.name then
					bound = k
					break
				end
			end
			rows[#rows + 1] = { text = s.name .. (bound and ("   [" .. bound .. "]") or "") .. "   -   " .. s.help }
		end
	end
	listWindow("BindHelp", "Bindable actions", rows)
end

-- ---------------- lifted windows ----------------
local function openCmdBar()
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
	H.makeResizable(cmdGui, 420, 45)
	-- no handle: drag it by its border (clicks inside still go to the text box)
	H.makeDraggable(cmdGui)

	local box = make("TextBox", {
		-- -34 not -20: leaves the bottom-right corner free for the resize grip
		Size = UDim2.new(1, -34, 1, -10),
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
end

local function openClickTp()
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

	-- no local state here on purpose: it all lives in ClickTp so it survives a close
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
		-- 162, not 150: the Key button ends at y=138 and the grip needs the corner below it
		Size = UDim2.new(0, 220, 0, 162),
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
	H.makeResizable(frame, 220, 162)

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
		-- settings survive in ClickTp; persist them so a rejoin keeps them too
		pcall(hubSaveConfig)
		-- full teardown, not a bare Destroy: the old version left the UIS listeners
		-- connected, so a closed window still teleported you on the keybind
		if _G.ClickTpCleanup then
			_G.ClickTpCleanup()
		else
			clickGui:Destroy()
		end
	end)

	-- opens showing whatever it was left on
	local toggle = make("TextButton", {
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 40),
		BackgroundColor3 = COL.off,
		Text = "Enabled: " .. (ClickTp.enabled and "ON" or "OFF"),
		TextColor3 = COL.text,
		BorderSizePixel = 0,
	}, frame)

	round(toggle, 6)
	toggle.BackgroundColor3 = ClickTp.enabled and COL.on or COL.off

	local mod = make("TextButton", {
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 75),
		BackgroundColor3 = COL.element,
		Text = "Modifier: " .. ClickTp.modifier.Name,
		TextColor3 = COL.text,
		BorderSizePixel = 0,
	}, frame)

	round(mod, 6)

	local key = make("TextButton", {
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 110),
		BackgroundColor3 = COL.element,
		Text = "Key: " .. ClickTp.key.Name,
		TextColor3 = COL.text,
		BorderSizePixel = 0,
	}, frame)

	round(key, 6)

	toggle.MouseButton1Click:Connect(function()
		ClickTp.enabled = not ClickTp.enabled

		toggle.Text = "Enabled: " .. (ClickTp.enabled and "ON" or "OFF")
		toggle.BackgroundColor3 = ClickTp.enabled and COL.on or COL.off
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
			ClickTp.modifier = input.KeyCode
			waitingModifier = false

			mod.Text = "Modifier: " .. ClickTp.modifier.Name

			return
		end

		if waitingKey then
			ClickTp.key = input.KeyCode
			waitingKey = false

			key.Text = "Key: " .. ClickTp.key.Name

			return
		end

		if gp or not ClickTp.enabled then
			return
		end

		if input.KeyCode == ClickTp.key then
			if UIS:IsKeyDown(ClickTp.modifier) then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

				if root and mouse.Hit then
					root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
				end
			end
		end
	end)

	-- clickConnect, not the hub's connect: this window is rebuilt on every !clicktp,
	-- so its listeners have to be disconnectable by ClickTpCleanup
	H.makeDraggable(frame, title, clickConnect)

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
end


-- ---------------- toggles ----------------
add{
	name = "fly",
	alias = { "sfly" },
	args = "<speed>",
	group = "Toggles",
	help = "Fly. A number sets the speed",
	bindable = true,
	run = function(c)
		Fly.doSfly(c.arg)
	end,
}
add{
	name = "cframe",
	alias = { "speed" },
	args = "<speed>",
	group = "Toggles",
	help = "CFrame movement. A number sets the speed",
	bindable = true,
	run = function(c)
		if c.n then
			_G.CFrameSpeed = math.clamp(c.n, 0, 99999)
			Speed.updateUI()
			return "cframe speed " .. _G.CFrameSpeed
		end
		Speed.toggle()
		return "cframe movement toggled"
	end,
}
add{
	name = "gravity",
	alias = { "grav" },
	args = "<n>",
	group = "Toggles",
	help = "Custom gravity. A number sets the value",
	bindable = true,
	run = function(c)
		if c.n then
			Grav.setCustom(c.n)
			return "gravity set to " .. Grav.getCustom()
		end
		Grav.toggle()
		return "gravity toggled"
	end,
}
add{
	name = "noclip",
	group = "Toggles",
	help = "Walk through walls",
	bindable = true,
	run = function()
		Move.toggleNoclip()
		return "noclip " .. onoff(Move.isNoclip())
	end,
}
add{
	name = "infjump",
	group = "Toggles",
	help = "Jump again in mid-air, forever",
	bindable = true,
	run = function()
		Move.toggleInfJump()
		return "infinite jump " .. onoff(Move.isInfJump())
	end,
}
add{
	name = "spin",
	args = "<speed>",
	group = "Toggles",
	help = "Spin your character. A number sets the speed",
	bindable = true,
	run = function(c)
		local on, sp = Move.spin(c.n)
		return on and ("spin on @ " .. sp) or "spin off"
	end,
}
add{
	name = "esp",
	args = "<box|skeleton|health|distance>",
	group = "Toggles",
	help = "Master ESP, or one type with an argument",
	bindable = true,
	run = function(c)
		if not Esp.hasDrawing() then
			return "no Drawing API"
		end
		if c.arg == "" then
			Esp.toggle()
			return "esp " .. onoff(Esp.isOn())
		end
		local state = Esp.toggleType(c.arg:lower())
		if state == nil then
			return "esp: box | skeleton | health | distance"
		end
		return "esp " .. c.arg:lower() .. " " .. onoff(state)
	end,
}
add{
	name = "fullbright",
	alias = { "fb" },
	group = "Toggles",
	help = "Remove all darkness",
	bindable = true,
	run = function()
		world.toggleFullbright()
		return "fullbright " .. onoff(world.fullbright)
	end,
}
add{
	name = "nofog",
	group = "Toggles",
	help = "Remove fog",
	bindable = true,
	run = function()
		world.toggleNofog()
		return "fog removal " .. onoff(world.nofog)
	end,
}
add{
	name = "xray",
	group = "Toggles",
	help = "See through the map",
	bindable = true,
	run = function()
		world.toggleXray()
		return "x-ray " .. onoff(world.xrayOn)
	end,
}
add{
	name = "infbaseplate",
	alias = { "infinitebaseplate" },
	group = "Toggles",
	help = "Infinite baseplate",
	bindable = true,
	run = function()
		world.toggleInfBaseplate()
	end,
}
add{
	name = "menu",
	group = "Toggles",
	help = "Show / hide the hub",
	bindable = true,
	run = function()
		main.Visible = not main.Visible
	end,
}

-- ---------------- values ----------------
add{
	name = "ws",
	alias = { "walkspeed" },
	args = "<n>",
	group = "Values",
	help = "Walk speed (0-500)",
	run = function(c)
		if not c.n then
			return "needs a number"
		end
		Move.setWalkSpeed(c.n)
		return "walkspeed " .. Move.getWalkSpeed()
	end,
}
add{
	name = "jp",
	alias = { "jumppower" },
	args = "<n>",
	group = "Values",
	help = "Jump power (0-500)",
	run = function(c)
		if not c.n then
			return "needs a number"
		end
		Move.setJumpPower(c.n)
		return "jumppower " .. Move.getJumpPower()
	end,
}
add{
	name = "fov",
	args = "<n>",
	group = "Values",
	help = "Field of view (1-120)",
	run = function(c)
		if not c.n then
			return "needs a number"
		end
		world.fov = math.clamp(c.n, 1, 120)
		world.fovBox.Text = tostring(world.fov)
		world.applyFov()
		return "fov " .. world.fov
	end,
}
add{
	name = "hitbox",
	args = "<n>",
	group = "Values",
	help = "Hitbox size (1-10)",
	run = function(c)
		if not c.n then
			return "needs a number"
		end
		Hitbox.setSize(c.n)
		return "hitbox " .. Hitbox.getSize()
	end,
}
add{
	name = "brightness",
	args = "<n>",
	group = "Values",
	help = "Lighting brightness (0-10)",
	run = function(c)
		if not c.n then
			return "needs a number"
		end
		return "brightness " .. world.setBrightness(c.n)
	end,
}
add{
	name = "time",
	args = "<0-24>",
	group = "Values",
	help = "Time of day, 24hr clock",
	run = function(c)
		if not c.n then
			return "needs an hour"
		end
		return "time " .. world.setTime(c.n)
	end,
}

-- ---------------- players ----------------
add{
	name = "tp",
	args = "<player>",
	group = "Players",
	help = "Teleport to a player",
	run = function(c)
		local t = hubFindPlayer(c.arg)
		local thrp = t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
		local myhrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (thrp and myhrp) then
			return "player not found"
		end
		myhrp.CFrame = thrp.CFrame + Vector3.new(0, 0, 3)
		return "teleported to " .. t.Name
	end,
}
add{
	name = "sp",
	args = "<player>",
	group = "Players",
	help = "Spectate a player",
	run = function(c)
		local t = hubFindPlayer(c.arg)
		local thum = t and t.Character and t.Character:FindFirstChildOfClass("Humanoid")
		if not thum then
			return "player not found"
		end
		workspace.CurrentCamera.CameraSubject = thum
		return "spectating " .. t.Name
	end,
}
add{
	name = "unsp",
	group = "Players",
	help = "Stop spectating",
	run = function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			workspace.CurrentCamera.CameraSubject = hum
		end
		return "stopped spectating"
	end,
}
add{
	name = "clicktp",
	group = "Players",
	help = "Open the Click TP window",
	bindable = true,
	run = openClickTp,
}

-- ---------------- binds ----------------
add{
	name = "bind",
	args = "<action> <key>",
	group = "Binds",
	help = "Bind a key. Also: bind help / bind list / bind clear",
	run = function(c)
		local action, keyName = c.arg:match("^(%S*)%s*(.-)$")
		action = action:lower()
		if action == "" or action == "help" then
			openBindHelp()
			return
		end
		if action == "list" then
			local out = {}
			for k, cmdName in pairs(Binds) do
				out[#out + 1] = k .. "=" .. cmdName
			end
			return #out > 0 and table.concat(out, " ") or "no binds set"
		end
		if action == "clear" then
			for k in pairs(Binds) do
				Binds[k] = nil
			end
			H.refreshKeys()
			pcall(hubSaveConfig)
			return "binds cleared"
		end
		local spec = CMDS[action]
		if not (spec and spec.bindable) then
			return "can't bind that - try: bind help"
		end
		if keyName == "" then
			return "usage: bind " .. action .. " <key>"
		end
		local kc = hubKeyFromName(keyName)
		if not kc then
			return "unknown key: " .. keyName
		end
		H.setBind(spec.name, kc.Name)
		pcall(hubSaveConfig)
		return "bound " .. kc.Name .. " -> " .. spec.name
	end,
}
add{
	name = "unbind",
	args = "<key>",
	group = "Binds",
	help = "Remove one bind",
	run = function(c)
		local kc = hubKeyFromName(c.arg)
		if not (kc and Binds[kc.Name]) then
			return "nothing bound to that key"
		end
		Binds[kc.Name] = nil
		H.refreshKeys()
		pcall(hubSaveConfig)
		return "unbound " .. kc.Name
	end,
}

-- ---------------- other ----------------
add{
	name = "reset",
	alias = { "respawn" },
	group = "Other",
	help = "Respawn your character",
	bindable = true,
	run = function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			return "no character"
		end
		hum.Health = 0
		return "respawning"
	end,
}
add{
	name = "print",
	args = "<text>",
	group = "Other",
	help = "Echo text back in the bar",
	run = function(c)
		if c.arg == "" then
			return "needs some text"
		end
		print("[hub] " .. c.arg)
		return c.arg
	end,
}
add{
    name = "antivc",
	alias = { "antivcb", "vcbypass" },
    group = "Other",
    help = "Load the anti-VC script",
    run = function()
        if not loadstring then
            return "loadstring is not available"
        end
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://shield.xao.wtf/api/loader/550af30c-aaa3-4338-acab-f44010a5ef09"))()
        end)
        if not ok then
            warn("[antivc] " .. tostring(err))
            return "antivc failed - see console"
        end
        return "antivc loaded"
    end,
}
add{
	name = "rejoin",
	group = "Other",
	help = "Rejoin the same server",
	bindable = true,
	run = function()
		local ts = game:GetService("TeleportService")
		local ok = pcall(function()
			if #Players:GetPlayers() <= 1 then
				ts:Teleport(game.PlaceId, player) -- last one out: a place teleport is all we can do
			else
				ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
			end
		end)
		return ok and "rejoining..." or "rejoin failed"
	end,
}
add{
	name = "runcode",
	alias = { "lua" },
	args = "<code>",
	group = "Other",
	help = "Execute Lua",
	run = function(c)
		if c.arg == "" then
			return "needs code"
		end
		local fn, err = loadstring(c.arg)
		if not fn then
			return "load error: " .. tostring(err)
		end
		local ok, res = pcall(fn)
		return ok and "ran ok" or ("error: " .. tostring(res))
	end,
}
add{
	name = "cmdbar",
	group = "Other",
	help = "Open the floating command bar",
	bindable = true,
	run = openCmdBar,
}
add{
	name = "help",
	group = "Other",
	help = "Open this menu",
	bindable = true,
	run = openHelp,
}
add{
	name = "unload",
	group = "Other",
	help = "Remove the hub",
	bindable = true,
	run = function()
		if _G.ScriptHubCleanup then
			_G.ScriptHubCleanup()
		end
	end,
}

-- ---------------- dispatch ----------------
hubRunCommand = function(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if input:sub(1, 1) == "!" then -- tolerate the chat-style prefix
		input = input:sub(2)
	end
	local name, arg = input:match("^(%S+)%s*(.-)$")
	if not name then
		return
	end
	local spec = CMDS[name:lower()]
	if not spec then
		say("unknown: " .. name .. " (type help)")
		return
	end
	local msg = spec.run({ arg = arg, n = tonumber(arg), raw = input })
	if msg then
		say(msg)
	end
end

-- The ONE keybind listener. Pressing a bound key replays its command through the same
-- dispatch the bar and chat use.
connect(UIS.InputBegan, function(i, gp)
	if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	-- belt and braces: never fire a bind while a text box has focus, or typing "x" in
	-- the command bar would toggle fly
	if UIS:GetFocusedTextBox() then
		return
	end
	-- swallow the keypress that just rebound the chip
	if H.keyChangeCooldown then
		return
	end
	local name = Binds[i.KeyCode.Name]
	if name then
		pcall(hubRunCommand, name)
	end
end)


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

H.runCommand = hubRunCommand
end -- Command bar scope

do -- ===== TAIL: dragging, keybinds, chat, cleanup, FPS overlay =====
-- pulled out of H once, so the body below uses fast locals
-- NOTE: connect/gui/make/round/COL/... are aliased here even though the FPS overlay at
-- the bottom of this block declares its own. A Lua local isn't visible before its
-- declaration, so the dragging/keybind/chat code above it needs these; the overlay's
-- own locals simply shadow these from its declaration onward, which is what it wants.
local Players, RunService, UIS, player, conns, connect =
	H.Players, H.RunService, H.UIS, H.player, H.conns, H.connect
local COL, make, round, gui = H.COL, H.make, H.round, H.gui
local VERSION, click, main, titleBar = H.VERSION, H.click, H.main, H.titleBar
local selectTab, world = H.selectTab, H.world
local Speed, Grav, Esp, Hitbox, Move, Fly, hubLoadConfig, hubRunCommand = H.Speed, H.Grav, H.Esp, H.Hitbox, H.Move, H.Fly, H.loadConfig, H.runCommand

-- ========== DRAGGING ==========
H.makeDraggable(main, titleBar)

-- ========== KEYBINDS ==========
-- Nothing here any more: K/C/G/X are seeded entries in Binds (see CORE) and the single
-- listener in the command-bar block runs them. That's what stopped `!bind` on a default
-- key from firing two handlers and cancelling itself out.

selectTab("Speed")

-- restore the saved theme/settings, if any (after every tab exists so the UI can sync)
pcall(hubLoadConfig)

H.refreshKeys() -- paint every key label once, after config

-- version tag (bottom-right) so you can tell which copy is running
make("TextLabel", {
	Size = UDim2.new(0, 60, 0, 12),
	Position = UDim2.new(1, -84, 1, -25), -- shifted left to clear the resize grip
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
	Position = UDim2.new(1, -146, 1, -28), -- centred on the same line as the cog/cmd bar
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
-- `connect` here is the overlay's own (declared above), so its cleanup handles these
H.makeDraggable(bar, nil, connect)

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

end -- Tail scope
