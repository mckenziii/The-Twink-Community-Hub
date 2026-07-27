--[[
	Edible Dildo
	Builds a segmented edible in your Backpack. Equip it, click to take a bite --
	each bite takes the top segment off, so it gets shorter as you go.

	Client-side only: it exists on your screen, nobody else sees it.
--]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local function notify(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = "Edible Dildo", Text = text, Duration = 4 })
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

local SEG_HEIGHT = 0.62
local SEG_WIDTH = 0.85
local SEGMENTS = 5 -- shaft segments, counting the Handle as the first

local BALL_SIZE = 0.80
local BALL_SPREAD = 0.42 -- how far out from centre each one sits on X

local tool, edible

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

	edible = {}
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

	-- goes on top of the running stack, and is something you can bite off
	local function stack(part)
		part.CFrame = handle.CFrame * CFrame.new(0, height + part.Size.Y / 2, 0)
		weldTo(part)
		height = height + part.Size.Y
		edible[#edible + 1] = part
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

	-- Deliberately NOT in `edible`: bites come off the top, so these stay put until the whole
	-- thing is gone, at which point destroying the Tool takes them with it.
	for i, side in ipairs({ -1, 1 }) do
		local b = sphere("Ball" .. i, BALL_SIZE)
		b.CFrame = handle.CFrame * CFrame.new(side * BALL_SPREAD, -SEG_HEIGHT / 2 + 0.05, 0)
		weldTo(b)
	end

	for i = 2, SEGMENTS do -- 1 is the Handle, already placed
		stack(cylinder("Seg" .. i, SEG_WIDTH, SEG_HEIGHT))
	end
	stack(sphere("Tip", SEG_WIDTH))

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

local eaten = 0

local function bite()
	local top = table.remove(edible) -- topmost remaining segment
	if not top then
		return
	end

	chomp()
	top:Destroy()
	eaten = eaten + 1

	if #edible > 0 then
		return
	end

	-- nothing left but the base in your hand
	chomp()
	task.wait(0.25)
	if tool then
		tool:Destroy()
		tool = nil
	end
	notify(("gone. %d bites."):format(eaten))
end

local function spawnEdible()
	if tool then
		tool:Destroy()
	end
	eaten = 0
	build().Activated:Connect(bite)
end

spawnEdible()
-- a fresh Backpack comes with every respawn, so hand yourself another one
player.CharacterAdded:Connect(function()
	task.wait(1)
	spawnEdible()
end)
