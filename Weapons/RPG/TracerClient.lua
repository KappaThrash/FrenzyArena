local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local tracerEvent = RS:WaitForChild("TracerVisual")
local tool = script.Parent
local viewmodelFolder = RS:WaitForChild("Viewmodel")
local VIEWMODEL_NAME = "ViewmodelRPG"
local cachedAttachment
local ROCKET_NAME = "Rocket"
local PROJECTILE_SPEED = 220
local PROJECTILE_LIFETIME = 6

local function getRocketTemplate()
	return tool:FindFirstChild(ROCKET_NAME)
end

local function getAttachmentFromModel(vm)
	if not vm then return nil end

	local primary = vm.PrimaryPart
	if primary then
		local att = primary:FindFirstChildWhichIsA("Attachment")
		if att then return att end
	end

	return vm:FindFirstChildWhichIsA("Attachment", true)
end

local function getViewmodelAttachment()
	local vm = camera:FindFirstChild(VIEWMODEL_NAME)
	if not vm then
		vm = camera:WaitForChild(VIEWMODEL_NAME, 0.2)
	end

	return getAttachmentFromModel(vm)
end

local function hideServerProjectile(projectile)
	if not projectile then return end
	if projectile:IsA("BasePart") then
		projectile.LocalTransparencyModifier = 1
		return
	end

	if projectile:IsA("Model") then
		for _, part in ipairs(projectile:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end
end

local function createProjectile(startPos, direction)
	local template = getRocketTemplate()
	if not (template and template:IsA("BasePart")) then
		return
	end

	local rocket = template:Clone()
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CastShadow = false
	rocket.CFrame = CFrame.lookAt(startPos, startPos + direction)
	rocket.Parent = workspace

	local alive = true
	local speed = PROJECTILE_SPEED
	local lastPos = startPos
	local timeAlive = 0

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not rocket.Parent then
			alive = false
		end
		if not alive then
			if connection then
				connection:Disconnect()
			end
			return
		end

		timeAlive += dt
		if timeAlive >= PROJECTILE_LIFETIME then
			rocket:Destroy()
			if connection then
				connection:Disconnect()
			end
			return
		end

		local newPos = lastPos + direction * speed * dt
		rocket.CFrame = CFrame.lookAt(newPos, newPos + direction)
		lastPos = newPos
	end)

	Debris:AddItem(rocket, PROJECTILE_LIFETIME + 0.1)
end

tool.Equipped:Connect(function()
	cachedAttachment = getViewmodelAttachment()
end)

tool.Unequipped:Connect(function()
	cachedAttachment = nil
end)

tracerEvent.OnClientEvent:Connect(function(startPos, direction, shooterUserId, serverProjectile)
	if shooterUserId ~= player.UserId then
		return
	end

	if tool.Parent ~= player.Character then
		return
	end

	if not viewmodelFolder:FindFirstChild(VIEWMODEL_NAME) then
		return
	end

	hideServerProjectile(serverProjectile)

	local muzzleAtt = cachedAttachment
	if not (muzzleAtt and muzzleAtt.Parent) then
		muzzleAtt = getViewmodelAttachment()
		cachedAttachment = muzzleAtt
	end
	if muzzleAtt then
		local dir = direction.Magnitude > 0 and direction.Unit or camera.CFrame.LookVector
		createProjectile(muzzleAtt.WorldPosition, dir)
	end
end)
