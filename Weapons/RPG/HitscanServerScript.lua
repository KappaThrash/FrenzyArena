local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local tracerEvent = RS:WaitForChild("TracerVisual")

local FIRE_RATE = 1
local DIRECT_DAMAGE = 100
local SPLASH_DAMAGE = 60
local SPLASH_RADIUS = 12
local PROJECTILE_SPEED = 220
local PROJECTILE_LIFETIME = 6
local MAX_AMMO = 30
local DEFAULT_AMMO = 30
local lastShot = {}
local ammoByPlayer = {}

local function getHandleOAttachment(character)
	local handleO = tool:FindFirstChild("HandleO", true)
	if not handleO and character then
		handleO = character:FindFirstChild("HandleO", true)
	end
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

local function getRocketTemplate()
	return tool:FindFirstChild("Rocket")
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
		rocket.Anchored = false
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
				part.Anchored = false
				part.CanCollide = false
				part.CastShadow = false
			end
		end
		return root
	end
	return nil
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

	local rocketTemplate = getRocketTemplate()
	if not rocketTemplate then
		return
	end

	local startPos = muzzleAtt.WorldPosition
	local direction = camDir.Magnitude > 0 and camDir.Unit or character.HumanoidRootPart.CFrame.LookVector

	local rocket = rocketTemplate:Clone()
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

	root.AssemblyLinearVelocity = direction * PROJECTILE_SPEED
	Debris:AddItem(rocket, PROJECTILE_LIFETIME + 0.1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { character, rocket }

	local function applyDamageAt(position, directInstance)
		local model = directInstance and directInstance:FindFirstAncestorOfClass("Model")
		if model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(DIRECT_DAMAGE)
			end
		end

		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
		overlapParams.FilterDescendantsInstances = { character, rocket }
		local parts = workspace:GetPartBoundsInRadius(position, SPLASH_RADIUS, overlapParams)

		local damaged = {}
		for _, part in ipairs(parts) do
			local hitModel = part:FindFirstAncestorOfClass("Model")
			if hitModel and not damaged[hitModel] then
				local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:TakeDamage(SPLASH_DAMAGE)
					damaged[hitModel] = true
				end
			end
		end
	end

	local lastPos = root.Position
	local spawnTime = tick()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not rocket.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local currentPos = root.Position
		local delta = currentPos - lastPos
		if delta.Magnitude > 0 then
			local result = workspace:Raycast(lastPos, delta, params)
			if result then
				applyDamageAt(result.Position, result.Instance)
				rocket:Destroy()
				if connection then
					connection:Disconnect()
				end
				return
			end
		end
		lastPos = currentPos

		if tick() - spawnTime >= PROJECTILE_LIFETIME then
			rocket:Destroy()
			if connection then
				connection:Disconnect()
			end
		end
	end)

	tracerEvent:FireAllClients(startPos, direction, player.UserId, rocket)
end)
