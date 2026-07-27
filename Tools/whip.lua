--[[
	Whip
	Builds a whip in your Backpack. The thong hangs off the FAR end of the grip and is
	simulated procedurally -- anchored parts driven by a rope solver, never touching the
	physics engine, so it can't push or drag your character. Click to crack it forward.

	Client-side only: it exists on your screen, nobody else sees it.
--]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function notify(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = "Whip", Text = text, Duration = 4 })
	end)
end

-- Handing the tool over fails silently in two ways: FindFirstChildOfClass("Backpack") returns nil
-- if we ran while dead or mid-respawn, and `Parent = nil` is perfectly legal -- the tool just goes
-- nowhere with no error. And plenty of games switch the Backpack CoreGui off, so the tool lands
-- correctly but no hotbar ever renders to show it. Handle both, then equip either way.
local function giveTool(t)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack then
		t.Parent = backpack
	else
		local char = player.Character
		if not char then
			notify("no Backpack and no character - respawn and retry")
			return false
		end
		t.Parent = char
	end

	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum:EquipTool(t)
		end)
	end
	return true
end

-- Swap this if it doesn't resolve in your game -- asset availability varies per experience.
local CRACK_SOUND = "rbxassetid://5801257793"

local GRIP_LEN = 1.10
local GRIP_WIDTH = 0.26
local GRIP_COLOUR = Color3.fromRGB(64, 42, 30)

local LINKS = 16
local LINK_LEN = 0.34
local LINK_HEAD_W = 0.17 -- width at the grip end
local LINK_TAIL_W = 0.055 -- width at the tip; tapers between the two
local LINK_COLOUR = Color3.fromRGB(38, 26, 20)

-- Rope solver. GRAVITY is in studs/s^2 and deliberately heavier than the world's, or the thong
-- floats. DAMPING bleeds off velocity each frame; ITERATIONS is how hard we enforce the segment
-- length -- more passes means a stiffer, less stretchy rope.
local GRAVITY = Vector3.new(0, -85, 0)
local DAMPING = 0.90
local ITERATIONS = 8
local MAX_DT = 1 / 30 -- clamp, so an alt-tab stall doesn't fling the rope to infinity
local CRACK_STRENGTH = 26

local tool, links, points, prev, stepConn

local function crackSound()
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = CRACK_SOUND
		s.Volume = 1
		-- SoundService, not a whip part: the parts move fast and a 3D sound on one would doppler
		-- and pan oddly. This is a sound you're making, so play it flat.
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 4)
	end)
end

-- Where the thong leaves the grip: the far end, pointing away from your hand. GripPos puts the
-- hand below the handle's centre, so +Y is the end away from you -- this is the "rope is on the
-- bottom" fix.
local function tipOfGrip(handle)
	return handle.CFrame * CFrame.new(0, GRIP_LEN / 2, 0)
end

local function build()
	tool = Instance.new("Tool")
	tool.Name = "Whip"
	tool.ToolTip = "click to crack"
	tool.CanBeDropped = true
	tool.GripPos = Vector3.new(0, -0.35, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(GRIP_WIDTH, GRIP_LEN, GRIP_WIDTH)
	handle.Color = GRIP_COLOUR
	handle.Material = Enum.Material.Wood
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	Instance.new("CylinderMesh").Parent = handle
	handle.Parent = tool

	-- One more point than link: each link spans points[i] -> points[i+1].
	links, points, prev = {}, {}, {}
	local start = tipOfGrip(handle).Position
	for i = 1, LINKS + 1 do
		points[i] = start + Vector3.new(0, -(i - 1) * LINK_LEN, 0)
		prev[i] = points[i]
	end

	for i = 1, LINKS do
		local t = (i - 1) / math.max(LINKS - 1, 1)
		local width = LINK_HEAD_W + (LINK_TAIL_W - LINK_HEAD_W) * t -- linear taper to the tip

		local seg = Instance.new("Part")
		seg.Name = "Link" .. i
		seg.Size = Vector3.new(width, LINK_LEN, width)
		seg.Color = LINK_COLOUR
		seg.Material = Enum.Material.SmoothPlastic
		-- Anchored and non-colliding: this is the whole reason it can't drag you. The parts are
		-- scenery we position by hand each frame, not bodies the solver can push your character with.
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.TopSurface = Enum.SurfaceType.Smooth
		seg.BottomSurface = Enum.SurfaceType.Smooth
		Instance.new("CylinderMesh").Parent = seg
		seg.Parent = tool
		links[i] = seg
	end

	-- a streak off the last link so a crack reads as motion rather than a twitching stick
	local tip = links[#links]
	if tip then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, LINK_LEN / 2, 0)
		a0.Parent = tip
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -LINK_LEN / 2, 0)
		a1.Parent = tip

		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.28
		trail.MinLength = 0.1
		trail.LightEmission = 0.2
		trail.Color = ColorSequence.new(Color3.fromRGB(210, 200, 190))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Parent = tip
	end

	giveTool(tool)
	return tool, handle
end

-- Verlet rope: integrate each point, then relax the segment lengths a few times. Point 1 is
-- pinned to the grip, so the whole chain trails from there.
local function simulate(handle, dt)
	local anchor = tipOfGrip(handle).Position

	for i = 2, #points do
		local p = points[i]
		local velocity = (p - prev[i]) * DAMPING
		prev[i] = p
		points[i] = p + velocity + GRAVITY * dt * dt
	end

	for _ = 1, ITERATIONS do
		points[1] = anchor
		for i = 2, #points do
			local delta = points[i] - points[i - 1]
			local dist = delta.Magnitude
			if dist > 1e-4 then
				points[i] = points[i - 1] + delta * (LINK_LEN / dist)
			end
		end
	end

	for i = 1, #links do
		local a, b = points[i], points[i + 1]
		local span = b - a
		if span.Magnitude > 1e-4 then
			-- lookAt aims -Z at the target; rotating -90 on X swings the part's +Y onto that
			-- axis, which is the direction a CylinderMesh actually runs along
			links[i].CFrame = CFrame.lookAt(a + span * 0.5, b) * CFrame.Angles(-math.pi / 2, 0, 0)
		end
	end
end

-- Aim from the grip toward whatever the cursor is over. Mouse.Hit already resolves the click into
-- a world point -- and it lands 1000 studs down the ray when you click empty sky, so there's
-- always a direction. Measuring from the grip rather than using the camera's LookVector is what
-- makes it lash where you point instead of always flicking up along the view axis.
local function aimFrom(origin)
	local hit = mouse.Hit
	if hit then
		local delta = hit.Position - origin
		if delta.Magnitude > 1e-4 then
			return delta.Unit
		end
	end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
end

local function crack()
	crackSound()
	if not points then
		return
	end
	local dir = aimFrom(points[1])

	-- Verlet has no velocity variable -- speed IS (current - previous). Dragging `prev` backwards
	-- is how you inject a shove. Weighted toward the tip so it uncoils instead of swinging rigid.
	for i = 2, #points do
		prev[i] = prev[i] - dir * CRACK_STRENGTH * (i / #points)
	end
end

local function stop()
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
end

local function spawnWhip()
	stop()
	if tool then
		tool:Destroy()
	end

	local t, handle = build()

	t.Equipped:Connect(function()
		stop()
		-- reset the rope onto the grip, or it snaps in from wherever it was left
		local start = tipOfGrip(handle).Position
		for i = 1, #points do
			points[i] = start + Vector3.new(0, -(i - 1) * LINK_LEN, 0)
			prev[i] = points[i]
		end
		stepConn = RunService.RenderStepped:Connect(function(dt)
			if handle.Parent then
				simulate(handle, math.min(dt, MAX_DT))
			end
		end)
	end)

	t.Unequipped:Connect(stop) -- no reason to solve a rope nobody can see
	t.Activated:Connect(crack)
end

spawnWhip()
-- a fresh Backpack comes with every respawn, so hand yourself another one
player.CharacterAdded:Connect(function()
	task.wait(1)
	spawnWhip()
end)
