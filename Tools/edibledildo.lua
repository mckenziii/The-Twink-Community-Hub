--[[
	Edible Dildo
	Builds a segmented edible in your Backpack. Equip it, click to take a bite --
	each bite takes the top segment off, so it gets shorter as you go.

	Client-side only: it exists on your screen, nobody else sees it.
--]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

-- Swap this if it doesn't resolve in your game -- asset availability varies per experience,
-- and a dead id here should never stop you eating, hence the pcall down in chomp().
local BITE_SOUND = "rbxassetid://3765537148"

local COLOUR = Color3.fromRGB(236, 148, 176)

local BASE_HEIGHT = 0.40
local BASE_WIDTH = 1.30
local SEG_HEIGHT = 0.62
local SEG_WIDTH = 0.85
local SEGMENTS = 5

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

	-- The Handle IS the base, so the stack welds to something the Tool already anchors to
	-- your hand -- no separate invisible handle to keep in sync.
	local handle = cylinder("Handle", BASE_WIDTH, BASE_HEIGHT)
	handle.Parent = tool

	edible = {}
	local height = BASE_HEIGHT / 2 -- running offset from the handle's centre

	local function attach(part)
		part.CanCollide = false
		part.Massless = true -- a seven-part stack otherwise drags your arm down
		part.CFrame = handle.CFrame * CFrame.new(0, height + part.Size.Y / 2, 0)
		part.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part

		height = height + part.Size.Y
		edible[#edible + 1] = part
	end

	for i = 1, SEGMENTS do
		attach(cylinder("Seg" .. i, SEG_WIDTH, SEG_HEIGHT))
	end

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(SEG_WIDTH, SEG_WIDTH, SEG_WIDTH)
	tip.Color = COLOUR
	tip.Material = Enum.Material.SmoothPlastic
	attach(tip)

	tool.Parent = player:FindFirstChildOfClass("Backpack")
	return tool
end

local function chomp(at)
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = BITE_SOUND
		s.Volume = 1
		s.Parent = at
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

	chomp(top)
	top:Destroy()
	eaten = eaten + 1

	if #edible > 0 then
		return
	end

	-- nothing left but the base in your hand
	chomp(tool:FindFirstChild("Handle") or player.Character)
	task.wait(0.25)
	if tool then
		tool:Destroy()
		tool = nil
	end
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "Edible Dildo",
		Text = ("gone. %d bites."):format(eaten),
		Duration = 4,
	})
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
