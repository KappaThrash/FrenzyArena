local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local FIRE_RATE = 1
local SPEED = 160
local LIFETIME = 6
local BLAST_RADIUS = 12
local DAMAGE = 90
local MAX_AMMO = 5
local DEFAULT_AMMO = 5
local lastShot = {}
local ammoByPlayer = {}
local ROCKET_ATTACHMENT_NAME = "RocketAttachment"

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

local function findRocketTemplate()
	return tool:FindFirstChild("Rocket") or ReplicatedStorage:FindFirstChild("Rocket")
end

local function getRocketPrimary(rocket)
	if rocket:IsA("Model") then
		if not rocket.PrimaryPart then
			local primary = rocket:FindFirstChildWhichIsA("BasePart")
			if primary then
				rocket.PrimaryPart = primary
			end
		end
		return rocket.PrimaryPart
	end

	if rocket:IsA("BasePart") then
		return rocket
	end

	return nil
end

local function setRocketCFrame(rocket, cframe)
	if rocket:IsA("Model") then
		rocket:PivotTo(cframe)
		return
	end

	if rocket:IsA("BasePart") then
		rocket.CFrame = cframe
	end
end

local function ensureRocketAttachment(part)
	local attachment = part:FindFirstChild(ROCKET_ATTACHMENT_NAME)
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	attachment = Instance.new("Attachment")
	attachment.Name = ROCKET_ATTACHMENT_NAME
	attachment.Parent = part
	return attachment
end

local function applyRocketFlight(rocketPart, direction)
	local attachment = ensureRocketAttachment(rocketPart)

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = direction.Unit * SPEED
	linearVelocity.MaxForce = math.huge
	linearVelocity.Parent = rocketPart

	local align = Instance.new("AlignOrientation")
	align.Attachment0 = attachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.MaxTorque = math.huge
	align.Responsiveness = 200
	align.CFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
	align.Parent = rocketPart

	return linearVelocity, align
end

local function prepareRocketParts(rocket)
	for _, part in ipairs(rocket:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CastShadow = false
		end
	end
end

local function applyBlastDamage(position, shooter, ignoreList)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = ignoreList

	local parts = workspace:GetPartBoundsInRadius(position, BLAST_RADIUS, params)
	local damaged = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and not damaged[humanoid] then
			local root = model:FindFirstChild("HumanoidRootPart")
			local targetPos = root and root.Position or part.Position
			local distance = (targetPos - position).Magnitude
			local scale = math.clamp(1 - (distance / BLAST_RADIUS), 0, 1)
			local damageAmount = DAMAGE * scale
			if damageAmount > 0 then
				humanoid:TakeDamage(damageAmount)
			end
			damaged[humanoid] = true
		end
	end
end

local function spawnRocket(player, muzzleCFrame, direction)
	local rocketTemplate = findRocketTemplate()
	if not rocketTemplate then
		warn("Rocket mesh not found for RPG tool")
		return
	end

	local rocket = rocketTemplate:Clone()
	rocket.Parent = workspace
	prepareRocketParts(rocket)

	local rocketPart = getRocketPrimary(rocket)
	if not rocketPart then
		rocket:Destroy()
		warn("Rocket mesh has no BasePart to use as primary")
		return
	end

	local directionUnit = direction.Magnitude > 0 and direction.Unit or muzzleCFrame.LookVector
	local launchCFrame = CFrame.lookAt(muzzleCFrame.Position, muzzleCFrame.Position + directionUnit)
	setRocketCFrame(rocket, launchCFrame)

	local linearVelocity = applyRocketFlight(rocketPart, directionUnit)
	rocketPart.AssemblyLinearVelocity = directionUnit * SPEED
	rocketPart.AssemblyAngularVelocity = Vector3.zero
	rocketPart:SetNetworkOwner(nil)

	local lastPos = rocketPart.Position
	local connection
	local touchedConnection

	local function explode(hitPos)
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if touchedConnection then
			touchedConnection:Disconnect()
			touchedConnection = nil
		end

		local ignore = { rocket }
		if player.Character then
			table.insert(ignore, player.Character)
		end

		applyBlastDamage(hitPos, player, ignore)
		rocket:Destroy()
	end

	touchedConnection = rocketPart.Touched:Connect(function(hit)
		if not hit or not rocketPart.Parent then
			return
		end

		if hit:IsDescendantOf(rocket) then
			return
		end

		if player.Character and hit:IsDescendantOf(player.Character) then
			return
		end

		explode(rocketPart.Position)
	end)

	connection = RunService.Heartbeat:Connect(function(dt)
		if not rocketPart or not rocketPart.Parent then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			return
		end

		local currentPos = rocketPart.Position
		local rayDir = currentPos - lastPos
		if linearVelocity then
			linearVelocity.VectorVelocity = directionUnit * SPEED
		end
		if rayDir.Magnitude > 0 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Blacklist
			params.FilterDescendantsInstances = { rocket }

			local result = workspace:Raycast(lastPos, rayDir, params)
			if result then
				explode(result.Position)
				return
			end
		end

		lastPos = currentPos
	end)

	Debris:AddItem(rocket, LIFETIME)
end

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

	local direction = camDir.Magnitude > 0 and camDir.Unit or muzzleAtt.WorldCFrame.LookVector
	spawnRocket(player, muzzleAtt.WorldCFrame, direction)
end)
