--[[
	Edible Dildo
	Builds a segmented prop in your Backpack. Equip it and click for a sound and a
	puff of particles from the tip. Nothing gets consumed -- click as much as you like.

	Client-side only: it exists on your screen, nobody else sees it.
--]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local function notify(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = "feverdreamstick.exe", Text = text, Duration = 4 })
	end)
end

-- Handing the tool over fails silently in two ways, which is why "nothing happened" was the
-- symptom rather than an error: FindFirstChildOfClass("Backpack") returns nil if we ran while
-- dead or mid-respawn, and `Parent = nil` is perfectly legal -- the tool just goes nowhere. And
-- plenty of games switch the Backpack CoreGui off, so the tool lands correctly but no hotbar
-- ever renders to show it. Handle both, then equip so it's in your hand either way.
local function giveTool(t)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if backpack then
		t.Parent = backpack
	else
		-- no Backpack at all: parenting to the character equips it outright
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
-- and a dead id here should never stop you eating, hence the pcall down in chomp().
local BITE_SOUND = "rbxassetid://120043778768093"

local COLOUR = Color3.fromRGB(236, 148, 176)

local SEG_HEIGHT = 10000000000000
local SEG_WIDTH = 0.01
local SEGMENTS = 5 -- shaft segments, counting the Handle as the first

local BALL_SIZE = 0.80
local BALL_SPREAD = 0.42 -- how far out from centre each one sits on X

-- rbxasset:// ships inside the client rather than being fetched from the catalog, so unlike the
-- bite sound this can't fail to resolve in a given game.
local PARTICLE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local PARTICLE_RATE = 5 -- steady trickle; set to 0 for bursts only
local PARTICLE_BURST = 24 -- extra puff on each click

local tool, emitter

-- Roblox's built-in Cylinder PartType lies along X, which is never what you want for a stack.
-- A CylinderMesh on a Block part gives a Y-axis cylinder instead, so everything stacks on Y.
local function cylinder(name, width, height)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(width, height, width)
	p.Color = COLOUR
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	Instance.new("CylinderMesh").Parent = p
	return p
end

local function build()
	tool = Instance.new("Tool")
	tool.Name = "Edible Dildo"
	tool.ToolTip = "click to eat"
	tool.CanBeDropped = true
	tool.GripPos = Vector3.new(0, -0.2, 0)

	-- The Handle IS the bottom shaft segment, so the stack welds to something the Tool already
	-- anchors to your hand -- no separate invisible handle to keep in sync.
	local handle = cylinder("Handle", SEG_WIDTH, SEG_HEIGHT)
	handle.Parent = tool

	local height = SEG_HEIGHT / 2 -- running offset from the handle's centre

	local function weldTo(part)
		part.CanCollide = false
		part.Massless = true -- an eight-part stack otherwise drags your arm down
		part.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end

	-- goes on top of the running stack
	local function stack(part)
		part.CFrame = handle.CFrame * CFrame.new(0, height + part.Size.Y / 2, 0)
		weldTo(part)
		height = height + part.Size.Y
	end

	local function sphere(name, size)
		local s = Instance.new("Part")
		s.Name = name
		s.Shape = Enum.PartType.Ball
		s.Size = Vector3.new(size, size, size)
		s.Color = COLOUR
		s.Material = Enum.Material.SmoothPlastic
		return s
	end

	for i, side in ipairs({ -1, 1 }) do
		local b = sphere("Ball" .. i, BALL_SIZE)
		b.CFrame = handle.CFrame * CFrame.new(side * BALL_SPREAD, -SEG_HEIGHT / 2 + 0.05, 0)
		weldTo(b)
	end

	for i = 2, SEGMENTS do -- 1 is the Handle, already placed
		stack(cylinder("Seg" .. i, SEG_WIDTH, SEG_HEIGHT))
	end
	stack(sphere("Tip", SEG_WIDTH))

	-- The emitter rides its own invisible part parked just above the tip, rather than sitting on
	-- the tip itself -- keeps the emission point independent of the geometry.
	local nozzle = Instance.new("Part")
	nozzle.Name = "Nozzle"
	nozzle.Size = Vector3.new(0.2, 0.2, 0.2)
	nozzle.Transparency = 1
	nozzle.CanCollide = false
	nozzle.Massless = true
	nozzle.Parent = tool

	local nozzleWeld = Instance.new("Weld")
	nozzleWeld.Part0 = handle
	nozzleWeld.Part1 = nozzle
	nozzleWeld.C0 = CFrame.new(0, height + 0.15, 0) -- just above the tip
	nozzleWeld.Parent = handle

	emitter = Instance.new("ParticleEmitter")
	emitter.Texture = PARTICLE_TEXTURE
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.30),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.0)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Acceleration = Vector3.new(0, -20, 0) -- arc over instead of going straight up forever
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = PARTICLE_RATE
	emitter.Parent = nozzle

	giveTool(tool)
	return tool
end

-- Parented to SoundService, NOT to the segment being eaten. The old version put the Sound inside
-- the part and then destroyed that part on the very next line, which took the Sound down with it
-- before it made a noise. 2D is the right call here anyway -- it's your own mouth, it shouldn't
-- attenuate with distance.
local function chomp()
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = BITE_SOUND
		s.Volume = 1
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 3)
	end)
end

-- Nothing is consumed: the tool stays whole and a click is just sound plus a puff, as many
-- times as you like.
local function onClick()
	if emitter then
		emitter:Emit(PARTICLE_BURST)
	end
	chomp()
end

local function spawnEdible()
	if tool then
		tool:Destroy()
	end
	build().Activated:Connect(onClick)
end

spawnEdible()
-- a fresh Backpack comes with every respawn, so hand yourself another one
player.CharacterAdded:Connect(function()
	task.wait(1)
	spawnEdible()
end)
