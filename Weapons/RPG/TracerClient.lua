local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local tracerEvent = RS:WaitForChild("TracerVisual")
local tool = script.Parent
local VIEWMODEL_NAME = "ViewmodelRPG"

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
		vm = camera:WaitForChild(VIEWMODEL_NAME, 1)
	end

	return getAttachmentFromModel(vm)
end

tracerEvent.OnClientEvent:Connect(function(startPos, hitPos, shooterUserId)
	if shooterUserId ~= player.UserId then
		return
	end

	if tool.Parent ~= player.Character then
		return
	end

	local muzzleAtt = getViewmodelAttachment()
	if muzzleAtt then
		createTracer(muzzleAtt.WorldPosition, hitPos)
	end
end)
