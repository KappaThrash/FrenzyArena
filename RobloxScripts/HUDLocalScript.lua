local hud = script.Parent
local frame = hud:WaitForChild("Frame")
local player = game.Players.LocalPlayer

local healthText = frame.HealthIcon:WaitForChild("HealthNumber")
local armorText = frame.ArmorIcon:WaitForChild("ArmorNumber")
local ammoText = frame.AmmoIcon:WaitForChild("AmmoNumber")

local characterConnections = {}
local toolConnections = {}
local humanoid

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function updateHealth()
	if not humanoid then return end
	local currentHealth = math.floor(humanoid.Health)
	healthText.Text = tostring(currentHealth)
	if currentHealth <= 25 then
		healthText.TextColor3 = Color3.fromRGB(255, 0, 0)
	elseif currentHealth <= 75 then
		healthText.TextColor3 = Color3.fromRGB(255, 175, 0)
	else
		healthText.TextColor3 = Color3.fromRGB(255, 255, 0)
	end
end

local function updateAmmo(tool)
	if not tool then
		ammoText.Text = "--"
		return
	end

	local ammo = tool:GetAttribute("Ammo")
	if ammo == nil then
		ammoText.Text = "--"
		return
	end

	local maxAmmo = tool:GetAttribute("MaxAmmo")
	if maxAmmo ~= nil then
		ammoText.Text = string.format("%d/%d", ammo, maxAmmo)
	else
		ammoText.Text = tostring(ammo)
	end
end

local function attachTool(tool)
	if not tool:IsA("Tool") then return end
	disconnectAll(toolConnections)
	updateAmmo(tool)
	table.insert(toolConnections, tool:GetAttributeChangedSignal("Ammo"):Connect(function()
		updateAmmo(tool)
	end))
	table.insert(toolConnections, tool:GetAttributeChangedSignal("MaxAmmo"):Connect(function()
		updateAmmo(tool)
	end))
end

local function getEquippedTool(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end
	return nil
end

local function bindCharacter(character)
	disconnectAll(characterConnections)
	disconnectAll(toolConnections)

	humanoid = character:WaitForChild("Humanoid")
	table.insert(characterConnections, humanoid.HealthChanged:Connect(updateHealth))
	table.insert(characterConnections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			attachTool(child)
		end
	end))
	table.insert(characterConnections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			disconnectAll(toolConnections)
			updateAmmo(nil)
		end
	end))

	updateHealth()
	attachTool(getEquippedTool(character))
end

bindCharacter(player.Character or player.CharacterAdded:Wait())
player.CharacterAdded:Connect(bindCharacter)
