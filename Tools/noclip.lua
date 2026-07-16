local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local noclip = false
local connection

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Noclip Tool",
            Text = msg,
            Duration = 3
        })
    end)
end

local function stopNoclip(char)
    noclip = false

    if connection then
        connection:Disconnect()
        connection = nil
    end

    if char then
        for _,v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = true
            end
        end
    end

    notify("Noclip Disabled")
end

local function startNoclip(char)
    noclip = true

    connection = RunService.Stepped:Connect(function()
        if not char then return end

        for _,v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end)

    notify("Noclip Enabled")
end

local function toggle()
    local char = player.Character
    if not char then return end

    if noclip then
        stopNoclip(char)
    else
        startNoclip(char)
    end
end

local function giveTool(char)
    local backpack = player:WaitForChild("Backpack")

    if backpack:FindFirstChild("Noclip Tool") then
        backpack["Noclip Tool"]:Destroy()
    end

    local tool = Instance.new("Tool")
    tool.Name = "Noclip Tool"
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.Parent = backpack

    tool.Activated:Connect(toggle)
end

if player.Character then
    giveTool(player.Character)
end

player.CharacterAdded:Connect(function(char)
    stopNoclip()
    task.wait(0.2)
    giveTool(char)
end)