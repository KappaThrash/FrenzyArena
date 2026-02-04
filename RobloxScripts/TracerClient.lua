local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local tracerEvent = RS:WaitForChild("TracerVisual")
local tool = script.Parent
local viewmodelFolder = RS:WaitForChild("Viewmodel")
local VIEWMODEL_NAME = "ViewmodelRailgun"
local cachedAttachment
local SOUND_ATTRIBUTE = "ShotSoundId"
local SOUND_NAMES = { "ShotSound", "FireSound" }

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
			playShotSoundAt(muzzleAtt.WorldPosition, muzzleAtt)
			createTracer(muzzleAtt.WorldPosition, hitPos)
			return
		end
	end

	playShotSoundAt(startPos)

	createTracer(startPos, hitPos)
end)
