local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local camera = workspace.CurrentCamera

tool.Activated:Connect(function()
	shootEvent:FireServer(
		camera.CFrame.Position,
		camera.CFrame.LookVector
	)
end)
