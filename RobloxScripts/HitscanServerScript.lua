local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local tracerEvent = RS:WaitForChild("TracerVisual")

local RANGE = 1100
local FIRE_RATE = 1
local DAMAGE = 100
local lastShot = {}

local function getHandleOAttachment(character)
	local handleO = character:FindFirstChild("HandleO", true)
	if not handleO then return nil end

	-- Prefer attachment inside HandleO.PrimaryPart if exists
	local primary = handleO:IsA("Model") and handleO.PrimaryPart
	if primary then
		local att = primary:FindFirstChildWhichIsA("Attachment")
		if att then return att end
	end

	-- Fallback: any attachment inside HandleO
	return handleO:FindFirstChildWhichIsA("Attachment", true)
end

shootEvent.OnServerEvent:Connect(function(player, camOrigin, camDir)
	if tool.Parent ~= player.Character then return end

	local t = tick()
	if lastShot[player] and (t - lastShot[player]) < FIRE_RATE then
		return
	end
	lastShot[player] = t

	local character = player.Character
	if not character then return end

	local muzzleAtt = getHandleOAttachment(character)
	if not muzzleAtt then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(camOrigin, camDir * RANGE, params)

	local hitPos
	if result then
		hitPos = result.Position
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(DAMAGE)
			end
		end
	else
		hitPos = camOrigin + camDir * RANGE
	end

	local startPos = muzzleAtt.WorldPosition
	tracerEvent:FireAllClients(startPos, hitPos, player.UserId)
end)