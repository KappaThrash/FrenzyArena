local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local player = Players.LocalPlayer
local enabledConnection

tool.Activated:Connect(function()
	shootEvent:FireServer(
		camera.CFrame.Position,
		camera.CFrame.LookVector
	)
end)

tool.Equipped:Connect(function()
	tool.Enabled = true
	if enabledConnection then
		enabledConnection:Disconnect()
	end
	enabledConnection = RunService.Heartbeat:Connect(function()
		if tool.Parent == player.Character and not tool.Enabled then
			tool.Enabled = true
		end
	end)
end)

tool.Unequipped:Connect(function()
	if enabledConnection then
		enabledConnection:Disconnect()
		enabledConnection = nil
	end
end)


--[[ 
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()

-- Função para deletar o Grip intruso
local function matarGrip(child)
	if child.Name == "RightGrip" or child.Name == "LeftGrip" then
		task.wait() -- Pequena espera para garantir que o Roblox o instanciou
		child:Destroy()
		print("Grip fantasma destruído!")
	end
end

tool.Equipped:Connect(function()
	local rHand = char:WaitForChild("RightHand")
	local lHand = char:WaitForChild("LeftHand")

	-- Conecta o "vigilante" às mãos
	rHand.ChildAdded:Connect(matarGrip)
	lHand.ChildAdded:Connect(matarGrip)

	-- Limpeza inicial caso ele já tenha sido criado
	for _, c in pairs(rHand:GetChildren()) do matarGrip(c) end
	for _, c in pairs(lHand:GetChildren()) do matarGrip(c) end

	-- Agora o seu Motor6D terá o caminho livre
	local motorR = tool:FindFirstChildOfClass("Motor6D") or tool.Handle:FindFirstChildOfClass("Motor6D")
	if motorR then
		motorR.Part0 = rHand
		-- O C1 da sua imagem será respeitado agora
	end
end)


local player = game.Players.LocalPlayer

-- Configura a distância da câmera para você enxergar o boneco
player.CameraMaxZoomDistance = 15
player.CameraMinZoomDistance = 10
--player.CameraMode = Enum.CameraMode.Classic
--]]


