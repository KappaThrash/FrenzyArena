local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local FIRE_RATE = 1
local DIRECT_DAMAGE = 100
local SPLASH_DAMAGE = 60
local SPLASH_RADIUS = 12
local ROCKET_SPEED = 180
local ROCKET_LIFETIME = 6
local MAX_AMMO = 30
local DEFAULT_AMMO = 10
local lastShot = {}
local ammoByPlayer = {}

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

local function getRocketTemplate()
	return tool:FindFirstChild("Rocket")
end

local function damageHumanoid(humanoid, amount)
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(amount)
	end
end

local function applySplashDamage(position, ignoreList)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = ignoreList

	local parts = workspace:GetPartBoundsInRadius(position, SPLASH_RADIUS, params)
	local damaged = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and not damaged[humanoid] then
			damaged[humanoid] = true
			damageHumanoid(humanoid, SPLASH_DAMAGE)
		end
	end
end

local function spawnRocket(player, origin, direction)
	local rocketTemplate = getRocketTemplate()
	if not rocketTemplate then
		return
	end

	local rocket = rocketTemplate:Clone()
	rocket.Name = "RPG_Rocket"
	rocket.CFrame = CFrame.lookAt(origin, origin + direction)
	rocket.Parent = workspace
	rocket.Anchored = false
	rocket.CanCollide = true
	rocket:SetNetworkOwner(nil)

	local connection
	local exploded = false

	local function explode(hitPart, hitPosition)
		if exploded then return end
		exploded = true

		if connection then
			connection:Disconnect()
			connection = nil
		end

		local model = hitPart and hitPart:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			damageHumanoid(humanoid, DIRECT_DAMAGE)
		end

		local ignoreList = { rocket }
		if model then
			table.insert(ignoreList, model)
		end
		applySplashDamage(hitPosition, ignoreList)

		rocket:Destroy()
	end

	connection = rocket.Touched:Connect(function(hit)
		if hit:IsDescendantOf(player.Character) then
			return
		end
		explode(hit, rocket.Position)
	end)

	rocket.AssemblyLinearVelocity = direction.Unit * ROCKET_SPEED

	Debris:AddItem(rocket, ROCKET_LIFETIME)
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

	local startPos = muzzleAtt.WorldPosition
	local direction = camDir.Unit
	spawnRocket(player, startPos, direction)
end)
