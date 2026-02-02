local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local tracerEvent = RS:WaitForChild("TracerVisual")
local viewmodelFolder = RS:WaitForChild("Viewmodel")

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

local function getViewmodelAttachment()
	local vm
	for _, child in ipairs(camera:GetChildren()) do
		if child:IsA("Model") and viewmodelFolder:FindFirstChild(child.Name) then
			vm = child
			break
		end
	end
	if not vm then return nil end

	local primary = vm.PrimaryPart
	if primary then
		local att = primary:FindFirstChildWhichIsA("Attachment")
		if att then return att end
	end

	return vm:FindFirstChildWhichIsA("Attachment", true)
end

tracerEvent.OnClientEvent:Connect(function(startPos, hitPos, shooterUserId)
	-- S o prprio jogador usa o viewmodel
	if shooterUserId == player.UserId then
		local muzzleAtt = getViewmodelAttachment()
		if muzzleAtt then
			createTracer(muzzleAtt.WorldPosition, hitPos)
			return
		end
	end

	-- Outros jogadores: usa o startPos do server
	createTracer(startPos, hitPos)
end)