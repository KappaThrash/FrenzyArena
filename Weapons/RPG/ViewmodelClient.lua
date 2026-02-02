local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local tool = script.Parent

--Trocar nome dependendo da arma!!!
local viewmodelFolder = ReplicatedStorage:WaitForChild("Viewmodel")
local viewmodelTemplate = viewmodelFolder:WaitForChild("ViewmodelRPG")


local viewmodel
local connection

-- posio base da arma
local OFFSET = CFrame.new(0.9, -1, -1.5)

-- =========================
-- BOBBING CONFIG (QUAKE)
-- =========================
-- Frequncia do bobbing
-- Controla QUO RPIDO a arma balana
-- ? menor = sensao mais pesada / lenta
-- ? maior = mais nervoso / arcade
-- Quake costuma ficar entre 6 ~ 8
local BOB_FREQ = 7

-- Amplitude vertical do bobbing
-- Controla o quanto a arma SOBE e DESCE
-- Valor pequeno evita enjoo
-- Muito alto = sensao de boneco inflvel
-- Bom range: 0.04 ~ 0.08
local BOB_VERT = 0.07

-- Amplitude lateral do bobbing
-- Controla o quanto a arma VAI PROS LADOS
-- D sensao de peso e passo
-- Geralmente menor que o vertical
-- Bom range: 0.03 ~ 0.06
local BOB_SIDE = 0.05

-- Suavizao do bobbing (anti-tremida)
-- Controla o quo rpido o bobbing acompanha o alvo
-- ? baixo = responde rpido, pode tremer
-- ? alto = mais suave, mais pesado
-- Range saudvel: 8 ~ 14
local BOB_SMOOTH = 10
local bobTime = 0
local currentBob = Vector3.zero

-- partes a esconder
local HIDE_NAMES = {
	"RightHand","RightLowerArm","RightUpperArm",
	"LeftHand","LeftLowerArm","LeftUpperArm",
	"Right Arm","Left Arm"
}

local hiddenParts = {}

local function clearExistingViewmodels()
	for _, child in ipairs(camera:GetChildren()) do
		if child:IsA("Model") and viewmodelFolder:FindFirstChild(child.Name) then
			child:Destroy()
		end
	end
end

local function hidePart(part)
	if part:IsA("BasePart") then
		hiddenParts[part] = part.LocalTransparencyModifier
		part.LocalTransparencyModifier = 1
	end
end

local function hideDefaultViewmodel()
	local char = player.Character
	if not char then return end

	-- 1. Esconde os braos padro do personagem (Terceira pessoa)
	for _, name in ipairs(HIDE_NAMES) do
		local part = char:FindFirstChild(name)
		if part then hidePart(part) end
	end

	-- 2. Esconde TODAS as partes visuais da Tool para voc
	-- Isso limpa o Handle, o HandleO e qualquer Cube/Cylinder
	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("BasePart") then
			hidePart(obj)
		end
	end
end

local function restoreDefaultViewmodel()
	for part, old in pairs(hiddenParts) do
		if part then
			part.LocalTransparencyModifier = old
		end
	end
	table.clear(hiddenParts)
end

local function createViewmodel()
	clearExistingViewmodels()
	viewmodel = viewmodelTemplate:Clone()
	viewmodel.Parent = camera

	for _, obj in ipairs(viewmodel:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CastShadow = false
		end
	end
end

local function removeViewmodel()
	if connection then
		connection:Disconnect()
		connection = nil
	end


	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end

	restoreDefaultViewmodel()
end

-- ?? VELOCIDADE VEM DA MOVI (ATTRIBUTE)
local function getHorizontalSpeed()
	local char = player.Character
	if not char then return 0 end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return 0 end

	return root:GetAttribute("Q3Speed") or 0
end

tool.Equipped:Connect(function()
	hideDefaultViewmodel()
	createViewmodel()

	connection = RunService.RenderStepped:Connect(function(dt)
		if not (viewmodel and viewmodel.PrimaryPart) then return end

		local speed = getHorizontalSpeed()
		local speedFactor = math.clamp(speed / 20, 0, 2)

		bobTime += dt * (BOB_FREQ * speedFactor)

		local targetBob = Vector3.new(
			math.sin(bobTime) * BOB_SIDE * speedFactor,
			math.abs(math.cos(bobTime)) * BOB_VERT * speedFactor,
			0
		)

		currentBob = currentBob:Lerp(
			targetBob,
			math.clamp(dt * BOB_SMOOTH, 0, 1)
		)

		viewmodel:SetPrimaryPartCFrame(
			camera.CFrame * OFFSET * CFrame.new(currentBob)
		)
	end)
end)

tool.Unequipped:Connect(removeViewmodel)

local function hookCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(removeViewmodel)
end

if player.Character then
	hookCharacter(player.Character)
end

player.CharacterAdded:Connect(hookCharacter)
