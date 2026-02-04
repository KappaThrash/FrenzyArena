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
local SOUND_ATTRIBUTE = "ShotSoundId"
local SOUND_NAMES = { "ShotSound", "FireSound" }

local function getRocketTemplate()
	return tool:FindFirstChild(ROCKET_NAME)
end

local function getProjectileRoot(projectile)
	if not projectile then
		return nil
	end
	if projectile:IsA("BasePart") then
		return projectile
	end
	if projectile:IsA("Model") then
		return projectile.PrimaryPart or projectile:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function getProjectileLifetime()
	local lifetime = tool:GetAttribute("ProjectileLifetime")
	if lifetime == nil then
		lifetime = PROJECTILE_LIFETIME
	end
	return math.max(lifetime, 0.1)
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

local function enableRocketEffects(rocket)
	for _, desc in ipairs(rocket:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = true
		elseif desc:IsA("Trail") or desc:IsA("Beam") then
			desc.Enabled = true
		end
	end
end

local function getShotSoundTemplate()
	for _, name in ipairs(SOUND_NAMES) do
		local sound = tool:FindFirstChild(name)
		if not sound then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				sound = handle:FindFirstChild(name)
			end
		end
		if sound and sound:IsA("Sound") then
			return sound
		end
	end

	return nil
end

local function playSoundOnParent(parent)
	local template = getShotSoundTemplate()
	local sound
	if template then
		sound = template:Clone()
	else
		local soundId = tool:GetAttribute(SOUND_ATTRIBUTE)
		if not soundId then
			return
		end
		sound = Instance.new("Sound")
		sound.SoundId = soundId
	end

	sound.Looped = false
	sound.PlayOnRemove = false
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 0.5) + 0.25)
end

local function playShotSoundAt(position, attachment)
	if attachment and attachment.Parent then
		playSoundOnParent(attachment)
		return
	end

	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	playSoundOnParent(holder)
	Debris:AddItem(holder, 2)
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
	local function hidePart(part)
		part.LocalTransparencyModifier = 1
	end

	local function hideNow()
		local hidden = false
		if projectile:IsA("BasePart") then
			hidePart(projectile)
			hidden = true
		elseif projectile:IsA("Model") then
			for _, part in ipairs(projectile:GetDescendants()) do
				if part:IsA("BasePart") then
					hidePart(part)
					hidden = true
				end
			end
		end
		return hidden
	end

	if hideNow() then
		return
	end

	local connection
	connection = projectile.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			hidePart(desc)
		end
	end)
	task.delay(1, function()
		if connection then
			connection:Disconnect()
		end
	end)
end

local function createViewmodelProjectile(startPos, direction, serverProjectile)
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
	enableRocketEffects(rocket)
	rocket.Parent = workspace

	local alive = true
	local timeAlive = 0
	local projectileLifetime = getProjectileLifetime()
	local serverRoot = getProjectileRoot(serverProjectile)

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
		if timeAlive >= projectileLifetime then
			rocket:Destroy()
			if connection then
				connection:Disconnect()
			end
			return
		end

		if serverRoot and serverRoot.Parent then
			local targetPos = serverRoot.Position
			local rocketPos = rocket:IsA("BasePart") and rocket.Position or rocket:GetPivot().Position
			local blendedPos = rocketPos:Lerp(targetPos, 0.35)
			local lookDir = (targetPos - blendedPos)
			if lookDir.Magnitude == 0 then
				lookDir = direction
			else
				lookDir = lookDir.Unit
			end
			local newFrame = CFrame.lookAt(blendedPos, blendedPos + lookDir)
			if rocket:IsA("BasePart") then
				rocket.CFrame = newFrame
			else
				rocket:PivotTo(newFrame)
			end
		else
			local rocketPos = rocket:IsA("BasePart") and rocket.Position or rocket:GetPivot().Position
			local newPos = rocketPos + direction * PROJECTILE_SPEED * dt
			local newFrame = CFrame.lookAt(newPos, newPos + direction)
			if rocket:IsA("BasePart") then
				rocket.CFrame = newFrame
			else
				rocket:PivotTo(newFrame)
			end
		end
	end)

	Debris:AddItem(rocket, projectileLifetime + 0.1)
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
		playShotSoundAt(muzzleAtt.WorldPosition, muzzleAtt)
		local dir = direction.Magnitude > 0 and direction.Unit or camera.CFrame.LookVector
		createViewmodelProjectile(muzzleAtt.WorldPosition, dir, serverProjectile)
	end
end)
