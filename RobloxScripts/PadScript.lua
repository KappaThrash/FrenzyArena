local pad = script.Parent

local VERTICAL = 50
local HORIZONTAL = 190
local COOLDOWN = 0.2

local lastHit = {}

pad.Touched:Connect(function(hit)
	local model = hit:FindFirstAncestorWhichIsA("Model")
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	local now = os.clock()
	if lastHit[hrp] and (now - lastHit[hrp]) < COOLDOWN then return end
	lastHit[hrp] = now

	local dir = pad.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then dir = Vector3.new(0,0,-1) else dir = dir.Unit end

	local vel = (dir * HORIZONTAL) + Vector3.new(0, VERTICAL, 0)

	hrp:SetAttribute("Q3ExternalVelocity", vel)
	hrp:SetAttribute("Q3ExternalStamp", os.clock())
end)