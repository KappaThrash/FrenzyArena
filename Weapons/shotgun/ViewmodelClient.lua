local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local tool = script.Parent
local tracerEvent = ReplicatedStorage:WaitForChild("TracerVisual")
local WEAPON_ID = "shotgun"

local viewmodelFolder = ReplicatedStorage:WaitForChild("Viewmodel")
local viewmodelTemplate = viewmodelFolder:WaitForChild("ViewmodelShotgun")

local viewmodel
local connection
local tracerConnection

local OFFSET = CFrame.new(0.9, -1, -1.4) * CFrame.Angles(0, math.rad(180), 0)

local BOB_FREQ = 7
local BOB_VERT = 0.07
local BOB_SIDE = 0.05
local BOB_SMOOTH = 10
local bobTime = 0
local currentBob = Vector3.zero

local RECOIL_BACK = 0.3
local RECOIL_RETURN = 8

local recoilOffset = 0

local HIDE_NAMES = {
	"RightHand", "RightLowerArm", "RightUpperArm",
	"LeftHand", "LeftLowerArm", "LeftUpperArm",
	"Right Arm", "Left Arm"
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

	for _, name in ipairs(HIDE_NAMES) do
		local part = char:FindFirstChild(name)
		if part then hidePart(part) end
	end

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
	if not viewmodel.PrimaryPart then
		viewmodel.PrimaryPart = viewmodel:FindFirstChildWhichIsA("BasePart")
	end
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

	if tracerConnection then
		tracerConnection:Disconnect()
		tracerConnection = nil
	end

	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end

	restoreDefaultViewmodel()
end

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
	recoilOffset = 0

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

		recoilOffset += (0 - recoilOffset) * math.clamp(dt * RECOIL_RETURN, 0, 1)

		viewmodel:SetPrimaryPartCFrame(
			camera.CFrame * OFFSET * CFrame.new(currentBob) * CFrame.new(0, 0, recoilOffset)
		)
	end)

	tracerConnection = tracerEvent.OnClientEvent:Connect(function(_, _, shooterUserId, weaponId, pelletIndex)
		if weaponId ~= WEAPON_ID then return end
		if shooterUserId ~= player.UserId then return end
		if not (viewmodel and viewmodel.PrimaryPart) then return end

		if pelletIndex == 1 then
			recoilOffset = math.clamp(recoilOffset + RECOIL_BACK, 0, RECOIL_BACK * 2)
		end
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
