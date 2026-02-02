local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")

local camera = workspace.CurrentCamera
local tool = script.Parent
local viewmodelFolder = RS:WaitForChild("Viewmodel")
local VIEWMODEL_NAME = "ViewmodelRPG"

local function getViewmodelAttachment()
	local viewmodelRef = tool:FindFirstChild("ViewmodelRef")
	if viewmodelRef and viewmodelRef.Value then
		local vm = viewmodelRef.Value
		local primary = vm.PrimaryPart
		if primary then
			local att = primary:FindFirstChildWhichIsA("Attachment", true)
			if att then return att end
		end
		return vm:FindFirstChildWhichIsA("Attachment", true)
	end

	local vmByName = camera:FindFirstChild(VIEWMODEL_NAME)
	if vmByName and vmByName:IsA("Model") then
		local primary = vmByName.PrimaryPart
		if primary then
			local att = primary:FindFirstChildWhichIsA("Attachment", true)
			if att then return att end
		end
		return vmByName:FindFirstChildWhichIsA("Attachment", true)
	end

	local vm
	for _, child in ipairs(camera:GetChildren()) do
		if child:IsA("Model") and viewmodelFolder:FindFirstChild(child.Name, true) then
			vm = child
			break
		end
	end
	if not vm then return nil end

	local primary = vm.PrimaryPart
	if primary then
		local att = primary:FindFirstChildWhichIsA("Attachment", true)
		if att then return att end
	end

	return vm:FindFirstChildWhichIsA("Attachment", true)
end

local function getToolAttachment()
	local handleO = tool:FindFirstChild("HandleO", true)
	if not handleO then return nil end

	local primary = handleO:IsA("Model") and handleO.PrimaryPart
	if primary then
		local att = primary:FindFirstChildWhichIsA("Attachment")
		if att then return att end
	end

	return handleO:FindFirstChildWhichIsA("Attachment", true)
end

local function createMuzzleFlash(position)
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 200, 80)
	flash.Transparency = 0.2
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.35, 0.35, 0.35)
	flash.CFrame = CFrame.new(position)
	flash.Parent = workspace

	Debris:AddItem(flash, 0.08)
end

tool.Activated:Connect(function()
	local muzzleAtt = getViewmodelAttachment()
	if not muzzleAtt then
		muzzleAtt = getToolAttachment()
	end

	if muzzleAtt then
		createMuzzleFlash(muzzleAtt.WorldPosition)
	end
end)
