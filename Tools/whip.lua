--[[
	Whip
	Builds a jointed whip in your Backpack. Equip it and the thong dangles and swings off
	your hand under real physics; click to crack it forward.

	Client-side only: it exists on your screen, nobody else sees it.
--]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

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

-- Swap this if it doesn't resolve in your game -- asset availability varies per experience,
-- and a dead id should never stop the whip working, hence the pcall in crackSound().
local CRACK_SOUND = "rbxassetid://5801257793"

local GRIP_LEN = 1.10
local GRIP_WIDTH = 0.26
local GRIP_COLOUR = Color3.fromRGB(64, 42, 30)

local SEGMENTS = 16
local SEG_LEN = 0.34
local SEG_HEAD_W = 0.17 -- width at the grip end
local SEG_TAIL_W = 0.055 -- width at the tip; tapers between the two
local SEG_COLOUR = Color3.fromRGB(38, 26, 20)

-- A whip you can actually hold: heavy enough to swing convincingly, light enough that 16 links
-- don't drag your arm to the floor.
local LINK_DENSITY = 0.05
local CRACK_IMPULSE = 90

local tool, segments

local function crackSound()
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = CRACK_SOUND
		s.Volume = 1
		-- SoundService, not a whip part: the parts are moving fast and a 3D sound on one would
		-- doppler and pan oddly. This is a sound you're making, so play it flat.
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 4)
	end)
end

-- Joints two parts with a BallSocket at the point where they meet, so the chain can fold in any
-- direction but can't pull apart. Offsets are along local Y -- bottom of `a` to top of `b`.
local function link(a, aOffset, b, bOffset)
	local at0 = Instance.new("Attachment")
	at0.Position = Vector3.new(0, aOffset, 0)
	at0.Parent = a

	local at1 = Instance.new("Attachment")
	at1.Position = Vector3.new(0, bOffset, 0)
	at1.Parent = b

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = at0
	socket.Attachment1 = at1
	socket.Parent = a
	return at1
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

	segments = {}
	-- the chain starts at the base of the grip and runs downward
	local prev, prevHalf = handle, GRIP_LEN / 2

	for i = 1, SEGMENTS do
		local t = (i - 1) / math.max(SEGMENTS - 1, 1)
		local width = SEG_HEAD_W + (SEG_TAIL_W - SEG_HEAD_W) * t -- linear taper to the tip

		local seg = Instance.new("Part")
		seg.Name = "Link" .. i
		seg.Size = Vector3.new(width, SEG_LEN, width)
		seg.Color = SEG_COLOUR
		seg.Material = Enum.Material.SmoothPlastic
		seg.CanCollide = false -- otherwise the thong catches on every doorway and stairstep
		seg.TopSurface = Enum.SurfaceType.Smooth
		seg.BottomSurface = Enum.SurfaceType.Smooth
		seg.CustomPhysicalProperties = PhysicalProperties.new(LINK_DENSITY, 0.3, 0, 1, 1)
		Instance.new("CylinderMesh").Parent = seg
		seg.CFrame = handle.CFrame * CFrame.new(0, -(prevHalf + SEG_LEN / 2 + (i - 1) * SEG_LEN), 0)
		seg.Parent = tool

		link(prev, -prevHalf, seg, SEG_LEN / 2)

		prev, prevHalf = seg, SEG_LEN / 2
		segments[i] = seg
	end

	-- a streak off the last link so a crack reads as motion rather than a twitching stick
	local tip = segments[#segments]
	if tip then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, SEG_LEN / 2, 0)
		a0.Parent = tip
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -SEG_LEN / 2, 0)
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
	return tool
end

local function crack()
	crackSound()
	if not segments then
		return
	end

	local cam = workspace.CurrentCamera
	local dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)

	-- Impulse scales with each link's own mass, so the taper doesn't make the thin end fly off
	-- while the fat end barely moves. Weighted toward the tip so it uncoils rather than
	-- swinging as one rigid bar.
	for i, seg in ipairs(segments) do
		local weight = i / #segments
		pcall(function()
			seg:ApplyImpulse(dir * CRACK_IMPULSE * weight * seg.AssemblyMass)
		end)
	end
end

local function spawnWhip()
	if tool then
		tool:Destroy()
	end
	build().Activated:Connect(crack)
end

spawnWhip()
-- a fresh Backpack comes with every respawn, so hand yourself another one
player.CharacterAdded:Connect(function()
	task.wait(1)
	spawnWhip()
end)
