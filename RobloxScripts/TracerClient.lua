local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local tracerEvent = RS:WaitForChild("TracerVisual")
local tool = script.Parent
local viewmodelFolder = RS:WaitForChild("Viewmodel")
local VIEWMODEL_NAME = "ViewmodelRailgun"
local SOUND_ATTRIBUTE = "ShotSoundId"
local SOUND_NAMES = { "ShotSound", "FireSound" }
local cachedAttachment

local function createTracer(startPos, endPos)
	local dist = (endPos - startPos).Magnitude

	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 0, 0)
	tracer.Transparency = 0.6
	tracer.Size = Vector3.new(0.12, 0.12, dist)
	tracer.CFrame = CFrame.lookAt((startPos + endPos) / 2, endPos)
	tracer.Parent = workspace

	Debris:AddItem(tracer, 0.35)
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

local function buildShotSound()
	local template = getShotSoundTemplate()
	if template then
		return template:Clone()
	end

	local soundId = tool:GetAttribute(SOUND_ATTRIBUTE)
	if not soundId then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	return sound
end

local function playShotSoundAt(position)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace

	local sound = buildShotSound()
	if not sound then
		Debris:AddItem(holder, 0.1)
		return
	end

	sound.Looped = false
	sound.PlayOnRemove = false
	sound.Parent = holder
	sound:Play()

	Debris:AddItem(sound, math.max(sound.TimeLength, 0.5) + 0.25)
	Debris:AddItem(holder, 2)
end

local function playLocalShotSound()
	local sound = buildShotSound()
	if not sound then
		return
	end

	sound.Looped = false
	sound.PlayOnRemove = false
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 0.5) + 0.25)
end

tool.Equipped:Connect(function()
	cachedAttachment = getViewmodelAttachment()
end)

tool.Unequipped:Connect(function()
	cachedAttachment = nil
end)

tracerEvent.OnClientEvent:Connect(function(startPos, hitPos, shooterUserId)
	-- S o prprio jogador usa o viewmodel
	if shooterUserId == player.UserId then
		if tool.Parent ~= player.Character then
			return
		end

		if not viewmodelFolder:FindFirstChild(VIEWMODEL_NAME) then
			return
		end

		local muzzleAtt = cachedAttachment
		if not (muzzleAtt and muzzleAtt.Parent) then
			muzzleAtt = getViewmodelAttachment()
			cachedAttachment = muzzleAtt
		end
		if muzzleAtt then
			playLocalShotSound()
			createTracer(muzzleAtt.WorldPosition, hitPos)
			return
		end
	end

	playShotSoundAt(startPos)

	createTracer(startPos, hitPos)
end)
