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

local function setRocketFrame(rocket, frame)
	if rocket:IsA("BasePart") then
		rocket.CFrame = frame
	else
		rocket:PivotTo(frame)
	end
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

local function getProjectileLifetime()
	local lifetime = tool:GetAttribute("ProjectileLifetime")
	if lifetime == nil then
		lifetime = PROJECTILE_LIFETIME
	end
	return math.max(lifetime, 0.1)
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

local function shouldAutoReload()
	local autoReload = tool:GetAttribute("AutoReload")
	if autoReload == nil then
		return true
	end
	return autoReload
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
	tool.Enabled = true
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
	if not tool.Enabled then
		tool.Enabled = true
	end

	local t = tick()
	if lastShot[player] and (t - lastShot[player]) < FIRE_RATE then
		return
	end

	local ammo = getAmmo(player)
	if ammo <= 0 then
		if shouldAutoReload() then
			setAmmo(player, getDefaultAmmo())
			ammo = getAmmo(player)
		else
			return
		end
	end

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

	lastShot[player] = t
	setAmmo(player, ammo - 1)

	local startFrame = CFrame.lookAt(startPos, startPos + direction)
	setRocketFrame(rocket, startFrame)
	enableRocketEffects(rocket)
	rocket.Parent = workspace
	local projectileLifetime = getProjectileLifetime()
	Debris:AddItem(rocket, projectileLifetime + 0.1)

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

	local lastPos = startPos
	local spawnTime = tick()
	local distanceTraveled = 0
	local exploded = false
	local connection

	local function explode(position, directInstance)
		if exploded then
			return
		end
		exploded = true
		applyDamageAt(position, directInstance)
		rocket:Destroy()
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		if not rocket.Parent then
			explode(lastPos, nil)
			if connection then
				connection:Disconnect()
			end
			return
		end

		distanceTraveled += PROJECTILE_SPEED * dt
		local currentPos = startPos + direction * distanceTraveled
		local delta = currentPos - lastPos
		if delta.Magnitude > 0 then
			local result = workspace:Raycast(lastPos, delta, params)
			if result then
				explode(result.Position, result.Instance)
				if connection then
					connection:Disconnect()
				end
				return
			end
		end

		setRocketFrame(rocket, CFrame.lookAt(currentPos, currentPos + direction))
		lastPos = currentPos

		if tick() - spawnTime >= projectileLifetime then
			explode(currentPos, nil)
			if connection then
				connection:Disconnect()
			end
		end
	end)

	tracerEvent:FireAllClients(startPos, direction, player.UserId, rocket)
end)
