local tool = script.Parent
local shootEvent = tool:WaitForChild("Shoot")

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local tracerEvent = RS:WaitForChild("TracerVisual")
local WEAPON_ID = "rpg"

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

-- ========= DEBUG HELPERS =========
local DEBUG = true
local function now()
	return string.format("%.3f", os.clock())
end

local function dprint(tag, ...)
	if not DEBUG then return end
	print(("[RPG DBG %s] [%s] "):format(now(), tag), ...)
end

local function dwarn(tag, ...)
	if not DEBUG then return end
	warn(("[RPG DBG %s] [%s] "):format(now(), tag), ...)
end

local function safeName(inst)
	if inst == nil then return "nil" end
	local ok, name = pcall(function() return inst:GetFullName() end)
	return ok and name or tostring(inst)
end
-- ================================

local function getHandleOAttachment(character)
	dprint("getHandleOAttachment", "tool=", safeName(tool), "character=", safeName(character))

	local handleO = tool:FindFirstChild("HandleO", true)
	if not handleO and character then
		handleO = character:FindFirstChild("HandleO", true)
	end
	if not handleO then
		dwarn("getHandleOAttachment", "HandleO N�O encontrado (nem na tool nem no character)")
		return nil
	end

	dprint("getHandleOAttachment", "HandleO=", safeName(handleO), "class=", handleO.ClassName)

	-- Prefer attachment inside HandleO.PrimaryPart if exists
	local primary = handleO:IsA("Model") and handleO.PrimaryPart
	if primary then
		dprint("getHandleOAttachment", "PrimaryPart=", safeName(primary))
		local att = primary:FindFirstChildWhichIsA("Attachment")
		if att then
			dprint("getHandleOAttachment", "Attachment achado na PrimaryPart:", safeName(att))
			return att
		end
	end

	-- Fallback: any attachment inside HandleO
	local fallback = handleO:FindFirstChildWhichIsA("Attachment", true)
	if fallback then
		dprint("getHandleOAttachment", "Attachment fallback achado:", safeName(fallback))
		return fallback
	end

	dwarn("getHandleOAttachment", "Nenhum Attachment encontrado dentro do HandleO")
	return nil
end

local function getRocketTemplate()
	local weaponsFolder = RS:FindFirstChild("Weapons")
	local rpgFolder = weaponsFolder and weaponsFolder:FindFirstChild("RPG")
	local rocket = rpgFolder and rpgFolder:FindFirstChild("Rocket")
	dprint("getRocketTemplate", "Rocket template=", safeName(rocket))
	return rocket
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
	dprint("prepareRocket", "rocket=", safeName(rocket), "class=", rocket.ClassName)

	if rocket:IsA("BasePart") then
		rocket.Anchored = true
		rocket.CanCollide = false
		rocket.CastShadow = false
		dprint("prepareRocket", "Rocket � BasePart; configurado OK")
		return rocket
	end

	if rocket:IsA("Model") then
		local root = getRocketRoot(rocket)
		dprint("prepareRocket", "Model root=", safeName(root), "PrimaryPart antes=", safeName(rocket.PrimaryPart))

		if root and rocket.PrimaryPart == nil then
			rocket.PrimaryPart = root
			dprint("prepareRocket", "PrimaryPart definido:", safeName(rocket.PrimaryPart))
		end

		local partsCount = 0
		for _, part in ipairs(rocket:GetDescendants()) do
			if part:IsA("BasePart") then
				partsCount += 1
				part.Anchored = true
				part.CanCollide = false
				part.CastShadow = false
			end
		end
		dprint("prepareRocket", "Parts configuradas=", partsCount)
		return root
	end

	dwarn("prepareRocket", "Rocket n�o � BasePart nem Model")
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
	local emitters, trails = 0, 0
	for _, desc in ipairs(rocket:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = true
			emitters += 1
		elseif desc:IsA("Trail") or desc:IsA("Beam") then
			desc.Enabled = true
			trails += 1
		end
	end
	dprint("enableRocketEffects", "ParticleEmitters=", emitters, "Trails/Beams=", trails)
end

local function getProjectileLifetime()
	local lifetime = tool:GetAttribute("ProjectileLifetime")
	if lifetime == nil then
		lifetime = PROJECTILE_LIFETIME
	end
	lifetime = math.max(lifetime, 0.1)
	dprint("getProjectileLifetime", "=", lifetime)
	return lifetime
end

local function getMaxAmmo()
	local maxAmmo = tool:GetAttribute("MaxAmmo")
	if maxAmmo == nil then
		maxAmmo = MAX_AMMO
	end
	dprint("getMaxAmmo", "=", maxAmmo)
	return maxAmmo
end

local function getDefaultAmmo()
	local defaultAmmo = tool:GetAttribute("DefaultAmmo")
	if defaultAmmo == nil then
		defaultAmmo = DEFAULT_AMMO
	end
	defaultAmmo = math.clamp(defaultAmmo, 0, getMaxAmmo())
	dprint("getDefaultAmmo", "=", defaultAmmo)
	return defaultAmmo
end

local function shouldAutoReload()
	local autoReload = tool:GetAttribute("AutoReload")
	if autoReload == nil then
		dprint("shouldAutoReload", "= true (default)")
		return true
	end
	dprint("shouldAutoReload", "=", autoReload)
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
	dprint("getAmmo", "player=", player and player.Name, "ammo=", ammo, "toolAttrAmmo=", tool:GetAttribute("Ammo"))
	return ammo
end

local function setAmmo(player, ammo)
	local clamped = math.clamp(ammo, 0, getMaxAmmo())
	ammoByPlayer[player] = clamped
	tool:SetAttribute("Ammo", clamped)
	dprint("setAmmo", "player=", player and player.Name, "ammo->", clamped)
end

tool.Equipped:Connect(function()
	local character = tool.Parent
	local player = Players:GetPlayerFromCharacter(character)
	dprint("Equipped", "character=", safeName(character), "player=", player and player.Name)

	if not player then return end
	tool.Enabled = true

	local ammo = getAmmo(player)
	if ammo == nil then
		dwarn("Equipped", "ammo veio nil; setando default")
		setAmmo(player, getDefaultAmmo())
	else
		setAmmo(player, ammo)
	end
end)

tool.AncestryChanged:Connect(function()
	dprint("AncestryChanged", "tool.Parent=", safeName(tool.Parent))
	if tool.Parent == nil then
		dprint("AncestryChanged", "limpando Ammo attribute")
		tool:SetAttribute("Ammo", nil)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	dprint("PlayerRemoving", player.Name, "limpando ammoByPlayer")
	ammoByPlayer[player] = nil
end)

shootEvent.OnServerEvent:Connect(function(player, camOrigin, camDir)
	dprint("OnServerEvent", "RECEBIDO", "player=", player and player.Name, "tool.Parent=", safeName(tool.Parent))
	dprint("OnServerEvent", "camOrigin=", camOrigin, "camDir=", camDir, "camDirMag=", (typeof(camDir) == "Vector3" and camDir.Magnitude) or "n/a")

	if tool.Parent ~= player.Character then
		dwarn("OnServerEvent", "Tool n�o est� no character do player. tool.Parent=", safeName(tool.Parent), "char=", safeName(player.Character))
		return
	end

	if not tool.Enabled then
		dwarn("OnServerEvent", "tool.Enabled estava false; setando true")
		tool.Enabled = true
	end

	local t = tick()
	if lastShot[player] and (t - lastShot[player]) < FIRE_RATE then
		dwarn("FireRate", "bloqueado", "delta=", (t - lastShot[player]), "FIRE_RATE=", FIRE_RATE)
		return
	end

	local ammo = getAmmo(player)
	if ammo <= 0 then
		dwarn("Ammo", "sem muni��o", "ammo=", ammo, "autoReload=", shouldAutoReload())
		if shouldAutoReload() then
			setAmmo(player, getDefaultAmmo())
			ammo = getAmmo(player)
		else
			return
		end
	end

	local character = player.Character
	if not character then
		dwarn("Character", "player.Character nil")
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		dwarn("Character", "HumanoidRootPart n�o encontrado")
	end

	local muzzleAtt = getHandleOAttachment(character)
	if not muzzleAtt then
		dwarn("Muzzle", "muzzleAtt nil; abortando tiro")
		return
	end

	dprint("Muzzle", "Attachment=", safeName(muzzleAtt), "WorldPos=", muzzleAtt.WorldPosition)

	local rocketTemplate = getRocketTemplate()
	if not rocketTemplate then
		dwarn("Rocket", "Template 'Rocket' n�o existe em ReplicatedStorage/Weapons/RPG")
		return
	end

	local startPos = muzzleAtt.WorldPosition
	local direction
	if typeof(camDir) == "Vector3" and camDir.Magnitude > 0 then
		direction = camDir.Unit
	else
		if hrp then
			dwarn("Direction", "camDir inv�lido/zero; usando LookVector do HRP")
			direction = hrp.CFrame.LookVector
		else
			dwarn("Direction", "camDir inv�lido e sem HRP; usando Vector3.new(0,0,-1)")
			direction = Vector3.new(0,0,-1)
		end
	end

	dprint("Direction", "=", direction)

	local rocket = rocketTemplate:Clone()
	dprint("Rocket", "Clone criado:", safeName(rocket), "class=", rocket.ClassName)

	local root = prepareRocket(rocket)
	if not root then
		dwarn("Rocket", "prepareRocket falhou; destruindo clone")
		rocket:Destroy()
		return
	end

	lastShot[player] = t
	setAmmo(player, ammo - 1)
	dprint("Ammo", "consumiu 1 -> agora", getAmmo(player))

	local startFrame = CFrame.lookAt(startPos, startPos + direction)
	setRocketFrame(rocket, startFrame)
	enableRocketEffects(rocket)

	rocket.Parent = workspace
	dprint("Rocket", "Parent=workspace", "root=", safeName(root))

	local projectileLifetime = getProjectileLifetime()
	Debris:AddItem(rocket, projectileLifetime + 0.1)
	dprint("Debris", "rocket vai ser removido em", projectileLifetime + 0.1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { character, rocket }

	local function applyDamageAt(position, directInstance)
		dprint("Damage", "applyDamageAt", "pos=", position, "directInstance=", safeName(directInstance))

		local model = directInstance and directInstance:FindFirstAncestorOfClass("Model")
		if model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				dprint("Damage", "DIRECT", "model=", safeName(model), "humanoid=", safeName(humanoid), "dmg=", DIRECT_DAMAGE)
				humanoid:TakeDamage(DIRECT_DAMAGE)
			else
				dprint("Damage", "DIRECT: model sem Humanoid", safeName(model))
			end
		end

		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
		overlapParams.FilterDescendantsInstances = { character, rocket }

		local ok, partsOrErr = pcall(function()
			return workspace:GetPartBoundsInRadius(position, SPLASH_RADIUS, overlapParams)
		end)

		if not ok then
			dwarn("Damage", "GetPartBoundsInRadius falhou:", partsOrErr)
			return
		end

		local parts = partsOrErr
		dprint("Damage", "SPLASH scan", "radius=", SPLASH_RADIUS, "parts=", #parts, "splashDmg=", SPLASH_DAMAGE)

		local damaged = {}
		for _, part in ipairs(parts) do
			local hitModel = part:FindFirstAncestorOfClass("Model")
			if hitModel and not damaged[hitModel] then
				local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
				if humanoid then
					dprint("Damage", "SPLASH", "model=", safeName(hitModel), "humanoid=", safeName(humanoid))
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
			dwarn("Explode", "j� explodiu; ignorando")
			return
		end
		exploded = true
		dprint("Explode", "EXPLODINDO", "pos=", position, "direct=", safeName(directInstance))

		local ok, err = pcall(function()
			applyDamageAt(position, directInstance)
		end)
		if not ok then
			dwarn("Explode", "applyDamageAt erro:", err)
		end

		if rocket then
			rocket:Destroy()
		end
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		if not rocket.Parent then
			dwarn("Heartbeat", "rocket.Parent nil; explodindo em lastPos")
			explode(lastPos, nil)
			if connection then connection:Disconnect() end
			return
		end

		distanceTraveled += PROJECTILE_SPEED * dt
		local currentPos = startPos + direction * distanceTraveled
		local delta = currentPos - lastPos

		if delta.Magnitude > 0 then
			local result = workspace:Raycast(lastPos, delta, params)
			if result then
				dprint("Raycast", "HIT", "from=", lastPos, "to=", currentPos, "hit=", safeName(result.Instance), "pos=", result.Position, "normal=", result.Normal)
				explode(result.Position, result.Instance)
				if connection then connection:Disconnect() end
				return
			end
		end

		setRocketFrame(rocket, CFrame.lookAt(currentPos, currentPos + direction))
		lastPos = currentPos

		if tick() - spawnTime >= projectileLifetime then
			dprint("Lifetime", "acabou; explodindo no ar", "age=", tick() - spawnTime, "limit=", projectileLifetime)
			explode(currentPos, nil)
			if connection then connection:Disconnect() end
		end
	end)

	-- tracer visual
	local ok, err = pcall(function()
		tracerEvent:FireAllClients(startPos, direction, player.UserId, WEAPON_ID, rocket)
	end)
	if ok then
		dprint("Tracer", "FireAllClients OK", "startPos=", startPos, "userId=", player.UserId, "rocket=", safeName(rocket))
	else
		dwarn("Tracer", "FireAllClients FALHOU:", err)
	end

	dprint("OnServerEvent", "finalizado")
end)
