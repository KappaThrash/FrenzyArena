--!strict
-- ============================================================================
-- Q3PlayerController (Unity C#) -> Roblox (IMPROVED, mantendo a lgica original)
-- ============================================================================

print(workspace.Gravity)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

type MovementSettings = {
	MaxSpeed: number,
	Acceleration: number,
	Deceleration: number,
}

-- CONFIG (ORIGINAL)
local m_Friction = 3.5
local m_Gravity = workspace.Gravity
local m_JumpForce = 40
local m_AutoBunnyHop = false
local m_AirControl = 0.5
local m_LastExternalStamp = 0

local m_GroundSettings: MovementSettings = { MaxSpeed = 35, Acceleration = 20, Deceleration = 10 }
local m_AirSettings: MovementSettings    = { MaxSpeed = 10, Acceleration =  1, Deceleration =  1 }
local m_StrafeSettings: MovementSettings = { MaxSpeed = 15, Acceleration = 12, Deceleration = 30 }

-- (do seu script antigo)
local function ThumbstickCurve(x: number): number
	local K_CURVATURE = 1.5
	local K_DEADZONE = 0.05

	local function fCurve(v: number): number
		return (math.exp(K_CURVATURE * v) - 1) / (math.exp(K_CURVATURE) - 1)
	end

	local function fDeadzone(v: number): number
		return fCurve((v - K_DEADZONE) / (1 - K_DEADZONE))
	end

	return math.sign(x) * math.clamp(fDeadzone(math.abs(x)), 0, 1)
end

local function flatten(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function safeUnit(v: Vector3): Vector3
	local m = v.Magnitude
	return (m > 1e-6) and (v / m) or Vector3.zero
end

-- PlayerModule Controls
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local function WaitForChildOfClass(parent: Instance, className: string, timeout: number?): Instance
	local child = parent:FindFirstChildOfClass(className)
	if child then return child end

	local thread = coroutine.running()
	local conn: RBXScriptConnection? = nil
	local resumed = false

	local function resumeThread()
		if resumed then
			return
		end
		resumed = true
		if conn and conn.Connected then
			conn:Disconnect()
		end
		conn = nil
		task.spawn(coroutine.resume, thread)
	end

	conn = parent.ChildAdded:Connect(function(inst: Instance)
		if inst.ClassName == className then
			child = inst
			resumeThread()
		end
	end)

	if timeout then
		task.delay(timeout, function()
			if not child then
				resumeThread()
			end
		end)
	end

	assert(coroutine.isyieldable())
	coroutine.yield()
	return child
end

local PlayerScripts = WaitForChildOfClass(LocalPlayer, "PlayerScripts", 5) :: PlayerScripts
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule")) :: any
local Controls = PlayerModule:GetControls()

-- STATE
local Humanoid: Humanoid? = nil
local Root: BasePart? = nil

local m_PlayerVelocity = Vector3.zero
local m_MoveInput = Vector3.zero
local m_MoveDirectionNorm = Vector3.zero
local m_LastCamLookDir = Vector3.zero

local m_JumpQueued = false
local m_IgnoreGroundUntil = 0 -- ADICIONADO

-- Input helpers
local function GetIsJumping(): boolean
	local active = Controls.activeController
	local hum = Controls.humanoid
	if not (active and active.enabled and hum) then
		return false
	end

	local jumping = false
	if active.GetIsJumping then
		jumping = (active:GetIsJumping() == true)
	end
	if (not jumping) and Controls.touchJumpController and Controls.touchJumpController.GetIsJumping then
		jumping = (Controls.touchJumpController:GetIsJumping() == true)
	end

	if Humanoid and not Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
		return false
	end

	return jumping
end

local function QueueJump()
	if m_AutoBunnyHop then
		m_JumpQueued = GetIsJumping()
		return
	end

	local isDown = GetIsJumping()
	if isDown and not m_JumpQueued then
		m_JumpQueued = true
	end
	if not isDown then
		m_JumpQueued = false
	end
end

-- Core math
local function ApplyFriction(t: number, dt: number, isGrounded: boolean)
	local vec = flatten(m_PlayerVelocity)
	local speed = vec.Magnitude
	local drop = 0

	if isGrounded then
		local control = if speed < m_GroundSettings.Deceleration then m_GroundSettings.Deceleration else speed
		drop = control * m_Friction * dt * t
	end

	local newSpeed = speed - drop
	if newSpeed < 0 then newSpeed = 0 end
	if speed > 0 then newSpeed /= speed end

	m_PlayerVelocity = Vector3.new(
		m_PlayerVelocity.X * newSpeed,
		m_PlayerVelocity.Y,
		m_PlayerVelocity.Z * newSpeed
	)
end

local function Accelerate(targetDir: Vector3, targetSpeed: number, accel: number, dt: number)
	local currentspeed = m_PlayerVelocity:Dot(targetDir)
	local addspeed = targetSpeed - currentspeed
	if addspeed <= 0 then
		return
	end

	local accelspeed = accel * dt * targetSpeed
	if accelspeed > addspeed then
		accelspeed = addspeed
	end

	m_PlayerVelocity = Vector3.new(
		m_PlayerVelocity.X + accelspeed * targetDir.X,
		m_PlayerVelocity.Y,
		m_PlayerVelocity.Z + accelspeed * targetDir.Z
	)
end

local function AirControl(targetDir: Vector3, targetSpeed: number, dt: number)
	if math.abs(m_MoveInput.Z) < 0.001 or math.abs(targetSpeed) < 0.001 then
		return
	end

	local ySpeed = m_PlayerVelocity.Y
	local horiz = flatten(m_PlayerVelocity)
	local speed = horiz.Magnitude
	if speed <= 1e-6 then
		return
	end

	horiz = horiz / speed
	local dot = horiz:Dot(targetDir)

	local k = 32
	k = k * m_AirControl * dot * dot * dt

	if dot > 0 then
		local new = Vector3.new(
			horiz.X * speed + targetDir.X * k,
			0,
			horiz.Z * speed + targetDir.Z * k
		)
		new = safeUnit(new)
		m_MoveDirectionNorm = new
		horiz = new
	end

	m_PlayerVelocity = Vector3.new(horiz.X * speed, ySpeed, horiz.Z * speed)
end

local function GetWishDirAndSpeed(settings: MovementSettings): (Vector3, number)
	local inputMag = math.clamp(
		math.sqrt(m_MoveInput.X * m_MoveInput.X + m_MoveInput.Z * m_MoveInput.Z),
		0,
		1
	)
	if inputMag <= 0 then
		return Vector3.zero, 0
	end

	local cam = workspace.CurrentCamera
	local wishDirWorld: Vector3

	if cam then
		local fwd = safeUnit(flatten(cam.CFrame.LookVector))
		local right = safeUnit(flatten(cam.CFrame.RightVector))
		wishDirWorld = (right * m_MoveInput.X) + (fwd * m_MoveInput.Z)
	else
		wishDirWorld = Vector3.new(m_MoveInput.X, 0, m_MoveInput.Z)
	end

	local wishDir = safeUnit(wishDirWorld)

	local wishSpeed = inputMag * settings.MaxSpeed
	return wishDir, wishSpeed
end

local function GetWishDirAndSpeedWithInput(settings: MovementSettings, moveInput: Vector3): (Vector3, number)
	local inputMag = math.clamp(
		math.sqrt(moveInput.X * moveInput.X + moveInput.Z * moveInput.Z),
		0,
		1
	)
	if inputMag <= 0 then
		return Vector3.zero, 0
	end

	local cam = workspace.CurrentCamera
	local wishDirWorld: Vector3

	if cam then
		local fwd = safeUnit(flatten(cam.CFrame.LookVector))
		local right = safeUnit(flatten(cam.CFrame.RightVector))
		wishDirWorld = (right * moveInput.X) + (fwd * moveInput.Z)
	else
		wishDirWorld = Vector3.new(moveInput.X, 0, moveInput.Z)
	end

	local wishDir = safeUnit(wishDirWorld)
	local wishSpeed = inputMag * settings.MaxSpeed
	return wishDir, wishSpeed
end

local function AirMove(dt: number, camLookDir: Vector3)
	local accel: number

	local moveInput = m_MoveInput
	if math.abs(moveInput.Z) > 1e-6 and math.abs(moveInput.X) > 1e-6 then
		local prevLookDir = m_LastCamLookDir
		if prevLookDir.Magnitude > 0 then
			local lookDot = camLookDir:Dot(prevLookDir)
			if lookDot > 0.999 then
				moveInput = Vector3.new(moveInput.X * 0.2, 0, moveInput.Z)
			end
		end
	end

	local wishDir, wishSpeed = GetWishDirAndSpeedWithInput(m_AirSettings, moveInput)
	m_MoveDirectionNorm = wishDir

	local wishSpeed2 = wishSpeed

	if m_PlayerVelocity:Dot(wishDir) < 0 then
		accel = m_AirSettings.Deceleration
	else
		accel = m_AirSettings.Acceleration
	end

	if math.abs(m_MoveInput.Z) < 1e-6 and math.abs(m_MoveInput.X) > 1e-6 then
		if wishSpeed > m_StrafeSettings.MaxSpeed then
			wishSpeed = m_StrafeSettings.MaxSpeed
		end
		accel = m_StrafeSettings.Acceleration
	end

	Accelerate(wishDir, wishSpeed, accel, dt)
	if m_AirControl > 0 then
		AirControl(wishDir, wishSpeed2, dt)
	end

	if math.abs(m_MoveInput.X) < 1e-6 and math.abs(m_MoveInput.Z) > 1e-6 then
		local forwardDir = safeUnit(wishDir)
		if forwardDir.Magnitude > 0 then
			local horiz = flatten(m_PlayerVelocity)
			local forwardSpeed = horiz:Dot(forwardDir)
			m_PlayerVelocity = Vector3.new(
				forwardDir.X * forwardSpeed,
				m_PlayerVelocity.Y,
				forwardDir.Z * forwardSpeed
			)
		end
	end

	m_PlayerVelocity = m_PlayerVelocity - Vector3.new(0, m_Gravity * dt, 0)
end

local function GroundMove(dt: number, isGrounded: boolean)
	if not m_JumpQueued then
		ApplyFriction(1.0, dt, isGrounded)
	else
		ApplyFriction(0, dt, isGrounded)
	end

	local wishDir, wishSpeed = GetWishDirAndSpeed(m_GroundSettings)
	m_MoveDirectionNorm = wishDir

	Accelerate(wishDir, wishSpeed, m_GroundSettings.Acceleration, dt)

	m_PlayerVelocity = Vector3.new(m_PlayerVelocity.X, -m_Gravity * dt, m_PlayerVelocity.Z)

	if m_JumpQueued then
		m_PlayerVelocity = Vector3.new(m_PlayerVelocity.X, m_JumpForce, m_PlayerVelocity.Z)
		m_JumpQueued = false
	end
end

-- Character lifecycle
local function OnCharacterAdded(character: Model)
	local hum = WaitForChildOfClass(character, "Humanoid", 5) :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart

	Humanoid = hum
	Root = root

	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.AutoRotate = true

	hum:GetPropertyChangedSignal("Jump"):Connect(function()
		if hum.Jump then
			hum.Jump = false
		end
	end)
end

local function OnCharacterRemoving()
	Humanoid = nil
	Root = nil
	m_PlayerVelocity = Vector3.zero
	m_MoveInput = Vector3.zero
	m_MoveDirectionNorm = Vector3.zero
	m_LastCamLookDir = Vector3.zero
	m_JumpQueued = false
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
LocalPlayer.CharacterRemoving:Connect(OnCharacterRemoving)
if LocalPlayer.Character then
	task.spawn(OnCharacterAdded, LocalPlayer.Character)
end

-- Capture move input
Controls.moveFunction = function(plr: Player, _unused: Vector3, relativeToCamera: boolean)
	if plr ~= LocalPlayer then return end

	local mv = Controls:GetMoveVector()
	local forward = (mv.Z ~= 0) and mv.Z or mv.Y

	local x = ThumbstickCurve(mv.X)
	local z = ThumbstickCurve(forward)

	m_MoveInput = Vector3.new(x, 0, -z)
end

-- Main loop
RunService.Heartbeat:Connect(function(dt: number)
	if dt <= 0 then
		return
	end

	local hum = Humanoid
	local root = Root
	if not hum or not root or hum.Health <= 0 then
		return
	end

	local now = os.clock()

	-- === JUMPPAD HOOK COM STAMP ===
	local stamp = root:GetAttribute("Q3ExternalStamp")
	if stamp and stamp ~= m_LastExternalStamp then
		m_LastExternalStamp = stamp
		local ext = root:GetAttribute("Q3ExternalVelocity")
		if ext then
			m_PlayerVelocity = ext
			m_IgnoreGroundUntil = now + 0.1
		end
	end

	QueueJump()

	local cam = workspace.CurrentCamera
	local camLookDir = if cam then safeUnit(flatten(cam.CFrame.LookVector)) else Vector3.zero

	local isGrounded = hum.FloorMaterial ~= Enum.Material.Air
	if now < m_IgnoreGroundUntil then
		isGrounded = false
	end

	if isGrounded then
		GroundMove(dt, true)
	else
		AirMove(dt, camLookDir)
	end

	m_LastCamLookDir = camLookDir

	root.AssemblyLinearVelocity = m_PlayerVelocity
	root:SetAttribute("Q3Speed", Vector3.new(
		m_PlayerVelocity.X,
		0,
		m_PlayerVelocity.Z
		).Magnitude)

	hum:Move(m_MoveDirectionNorm, false)
end)

print("? Q3PlayerController carregado.")
