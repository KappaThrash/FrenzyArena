local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local tracerEvent = RS:WaitForChild("TracerVisual")
local WEAPON_ID = "shotgun"

local RANGE = 450
local FIRE_RATE = 0.9
local DAMAGE = 10
local PELLETS = 12
local SPREAD_DEGREES = 4.5
local MAX_AMMO = 24
local DEFAULT_AMMO = 24
local lastShot = {}
local ammoByPlayer = {}

local function getHandleOAttachment(character)
	local handleO = tool:FindFirstChild("HandleO", true)
	if not handleO and character then
		handleO = character:FindFirstChild("HandleO", true)
	end
	if not handleO then return nil end

	local primary = handleO:IsA("Model") and handleO.PrimaryPart
	if primary then
		local att = primary:FindFirstChildWhichIsA("Attachment")
		if att then return att end
	end

	return handleO:FindFirstChildWhichIsA("Attachment", true)
end

local function getMaxAmmo()
	local maxAmmo = tool:GetAttribute("MaxAmmo")
	if maxAmmo == nil then
		maxAmmo = MAX_AMMO
	end
	return maxAmmo
end

local function getDefaultAmmo()
	local defaultAmmo = tool:GetAttribute("DefaultAmmo")
	if defaultAmmo == nil then
		defaultAmmo = DEFAULT_AMMO
	end
	return math.clamp(defaultAmmo, 0, getMaxAmmo())
end

local function getAmmo(player)
	local ammo = tool:GetAttribute("Ammo")
	if ammo == nil then
		ammo = ammoByPlayer[player]
	end
	if ammo == nil then
		ammo = getDefaultAmmo()
	end
	return ammo
end

local function setAmmo(player, ammo)
	local clamped = math.clamp(ammo, 0, getMaxAmmo())
	ammoByPlayer[player] = clamped
	tool:SetAttribute("Ammo", clamped)
end

local function getSpreadDirection(baseDirection)
	local spread = math.rad(SPREAD_DEGREES)
	local yaw = (math.random() * 2 - 1) * spread
	local pitch = (math.random() * 2 - 1) * spread
	local spreadCF = CFrame.fromOrientation(pitch, yaw, 0)
	return (spreadCF * baseDirection).Unit
end

tool.Equipped:Connect(function()
	local character = tool.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	if getAmmo(player) == nil then
		setAmmo(player, getDefaultAmmo())
	else
		setAmmo(player, getAmmo(player))
	end
end)

tool.AncestryChanged:Connect(function()
	if tool.Parent == nil then
		tool:SetAttribute("Ammo", nil)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ammoByPlayer[player] = nil
end)

shootEvent.OnServerEvent:Connect(function(player, camOrigin, camDir)
	if tool.Parent ~= player.Character then return end

	local t = tick()
	if lastShot[player] and (t - lastShot[player]) < FIRE_RATE then
		return
	end

	local ammo = getAmmo(player)
	if ammo <= 0 then
		return
	end

	lastShot[player] = t
	setAmmo(player, ammo - 1)

	local character = player.Character
	if not character then return end

	local muzzleAtt = getHandleOAttachment(character)
	if not muzzleAtt then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { character }

	local startPos = muzzleAtt.WorldPosition
	for pelletIndex = 1, PELLETS do
		local pelletDirection = getSpreadDirection(camDir)
		local result = workspace:Raycast(camOrigin, pelletDirection * RANGE, params)

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
			hitPos = camOrigin + pelletDirection * RANGE
		end

		tracerEvent:FireAllClients(startPos, hitPos, player.UserId, WEAPON_ID, pelletIndex)
	end
end)
