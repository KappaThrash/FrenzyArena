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

local function getRocketRoot(rocket)
	if rocket:IsA("BasePart") then
		return rocket
	end
	if rocket:IsA("Model") then
		return rocket.PrimaryPart or rocket:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function prepareRocket(rocket)
	if rocket:IsA("BasePart") then
		rocket.Anchored = true
		rocket.CanCollide = false
		rocket.CastShadow = false
		return rocket
	end

	if rocket:IsA("Model") then
		local root = getRocketRoot(rocket)
		if root and rocket.PrimaryPart == nil then
			rocket.PrimaryPart = root
		end

		for _, part in ipairs(rocket:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CastShadow = false
			end
		end
		return root
	end
	return nil
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
	if not template then
		return
	end

	local rocket = template:Clone()
	local root = prepareRocket(rocket)
	if not root then
		rocket:Destroy()
		return
	end

	local startFrame = CFrame.lookAt(startPos, startPos + direction)
	if rocket:IsA("BasePart") then
		rocket.CFrame = startFrame
	else
		rocket:PivotTo(startFrame)
	end
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
		local newFrame = CFrame.lookAt(newPos, newPos + direction)
		if rocket:IsA("BasePart") then
			rocket.CFrame = newFrame
		else
			rocket:PivotTo(newFrame)
		end
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
