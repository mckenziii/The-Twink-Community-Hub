--[[
	Sandwich
	Builds a layered sandwich Tool in your Backpack. Equip it, click to take a bite.
	Each bite removes the top layer; finish it and the tool disappears.

	Client-side only: the sandwich exists on your screen, nobody else sees it.
--]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local function notify(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = "Sandwich", Text = text, Duration = 4 })
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
local BITE_SOUND = "rbxassetid://91209592691035"

-- UGC item to put on when you click. Named so we can spot it already being worn and not
-- stack a second copy on every bite.
local UGC_ID = 5461538290
local UGC_NAME = "SandwichUGC"

-- bottom of the stack first; each layer sits on top of the one before it
local LAYERS = {
	{ name = "Bread",   size = Vector3.new(2.0, 0.40, 2.0), colour = Color3.fromRGB(214, 168, 106) },
	{ name = "Lettuce", size = Vector3.new(1.9, 0.14, 1.9), colour = Color3.fromRGB(102, 190, 84) },
	{ name = "Tomato",  size = Vector3.new(1.7, 0.18, 1.7), colour = Color3.fromRGB(206, 62, 54) },
	{ name = "Cheese",  size = Vector3.new(1.9, 0.12, 1.9), colour = Color3.fromRGB(245, 197, 66) },
	{ name = "Ham",     size = Vector3.new(1.8, 0.20, 1.8), colour = Color3.fromRGB(232, 145, 158) },
	{ name = "Top",     size = Vector3.new(2.0, 0.50, 2.0), colour = Color3.fromRGB(214, 168, 106) },
}

local tool, layers

local function build()
	tool = Instance.new("Tool")
	tool.Name = "Sandwich"
	tool.ToolTip = "click to eat"
	tool.CanBeDropped = true
	-- held flat in the palm rather than swinging like a sword
	tool.GripPos = Vector3.new(0, -0.3, 0)

	-- The Handle IS the bottom slice, so the whole stack welds to something the Tool already
	-- anchors to your hand -- no separate invisible handle to keep in sync.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = LAYERS[1].size
	handle.Color = LAYERS[1].colour
	handle.Material = Enum.Material.Sand -- closest thing Roblox has to a crust
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	layers = {}
	local height = LAYERS[1].size.Y / 2 -- running offset from the handle's centre

	for i = 2, #LAYERS do
		local def = LAYERS[i]
		local part = Instance.new("Part")
		part.Name = def.name
		part.Size = def.size
		part.Color = def.colour
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.Massless = true -- otherwise a six-part stack drags your arm down
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = handle.CFrame * CFrame.new(0, height + def.size.Y / 2, 0)
		part.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part

		height = height + def.size.Y
		layers[#layers + 1] = part
	end

	giveTool(tool)
	return tool
end

-- Parented to SoundService, NOT to the layer being eaten. The old version put the Sound inside
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

-- Pull the accessory out of whatever shape the asset arrives in. GetObjects is the executor
-- path and hands back a list; InsertService:LoadAsset is the sanctioned one but is normally
-- server-only, so it's the fallback rather than the first try. Either can hand us the Accessory
-- directly or wrapped in a Model, hence the recursive search.
local function fetchAccessory()
	local objects
	local ok = pcall(function()
		objects = game:GetObjects("rbxassetid://" .. UGC_ID)
	end)
	if not ok or not objects or not objects[1] then
		objects = nil
		pcall(function()
			local model = game:GetService("InsertService"):LoadAsset(UGC_ID)
			objects = model and model:GetChildren()
		end)
	end
	if not objects then
		return nil
	end
	for _, inst in ipairs(objects) do
		if inst:IsA("Accessory") then
			return inst
		end
		local nested = inst:FindFirstChildWhichIsA("Accessory", true)
		if nested then
			return nested
		end
	end
	return nil
end

local warned = false

local function wearUGC()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then
		return
	end
	if char:FindFirstChild(UGC_NAME) then
		return -- already wearing it; clicking again shouldn't pile them up
	end

	local acc = fetchAccessory()
	if not acc then
		if not warned then
			warned = true -- once, not once per bite
			notify("couldn't load UGC " .. UGC_ID)
		end
		return
	end

	acc.Name = UGC_NAME
	-- AddAccessory does the attachment matching and welding for us; if the asset has no
	-- matching attachment point it throws, so fall back to just parenting it
	if not pcall(function()
		hum:AddAccessory(acc)
	end) then
		acc.Parent = char
	end
end

local eaten = 0

local function bite()
	wearUGC()

	local top = table.remove(layers) -- topmost remaining layer
	if not top then
		return
	end

	chomp()
	top:Destroy()
	eaten = eaten + 1

	if #layers > 0 then
		return
	end

	-- nothing left but the slice in your hand
	chomp()
	task.wait(0.25)
	if tool then
		tool:Destroy()
		tool = nil
	end
	notify(("gone. %d bites."):format(eaten))
end

local function spawnSandwich()
	if tool then
		tool:Destroy()
	end
	eaten = 0
	warned = false -- a new life gets to hear about a failed load again
	build().Activated:Connect(bite)
end

spawnSandwich()
-- a fresh Backpack comes with every respawn, so hand yourself another one
player.CharacterAdded:Connect(function()
	task.wait(1)
	spawnSandwich()
end)
