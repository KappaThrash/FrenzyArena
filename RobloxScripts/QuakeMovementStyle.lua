--!strict

local MOVE_SPEED = 30
local RUN_ACCELERATION = 5
local RUN_DEACCELERATION = 5
local AIR_ACCELERATION = 2.5
local AIR_DEACCELERATION = 2.5
local SIDE_STRAFE_ACCELERATION = 100
local SIDE_STRAFE_SPEED = 1
local FRICTION = 8
local AIR_FRICTION = 3
local MAX_SPEED = math.huge
local JUMP_BUFFER = 0.1
local HOLD_JUMP_TO_BHOP = true

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local function WaitForChildOfClass(Parent: Instance, ClassName: string, TimeOut: number?): Instance
	local Child = Parent:FindFirstChildOfClass(ClassName)

	if not Child then
		local Connection: RBXScriptConnection?
		local Thread = coroutine.running()

		Connection = Parent.ChildAdded:Connect(function(child: Instance)
			if child.ClassName == ClassName then
				if Connection then
					if Connection.Connected then
						Connection:Disconnect()
					end
					Connection = nil
				end
				Child = child
				task.spawn(Thread)
			end
		end)

		if TimeOut then
			task.delay(TimeOut, function()
				if not Child then
					if Connection then
						if Connection.Connected then
							Connection:Disconnect()
						end
						Connection = nil
					end
					task.spawn(Thread)
				end
			end)
		else
			task.delay(5, function()
				if not Child then
					warn(
						string.format(
							"Infinite yield possible waiting on %s:FindFirstChildOfClass(\"%s\")", 
							Parent:GetFullName(), 
							ClassName
						)
					)
				end
			end)
		end

		assert(coroutine.isyieldable(), "assertion failed!")
		coroutine.yield()
	end

	return Child
end

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local PlayerScripts = WaitForChildOfClass(LocalPlayer, "PlayerScripts") :: PlayerScripts
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule")) :: any

local Controls = PlayerModule:GetControls()
local PlayerVelocity = Vector3.zero

local InputVelocity = Vector3.zero
local Humanoid: Humanoid?

local WishJump = false
local CanJump = true

local function ThumbstickCurve(X: number): number
	local K_CURVATURE = 2.0
	local K_DEADZONE = 0.15

	local function FCurve(X: number): number
		return (math.exp(K_CURVATURE * X) - 1) / (math.exp(K_CURVATURE) - 1)
	end

	local function FDeadzone(X: number): number
		return FCurve((X - K_DEADZONE) / (1 - K_DEADZONE))
	end

	return math.sign(X) * math.clamp(FDeadzone(math.abs(X)), 0, 1)
end

local function OnCharacterAdded(character: Model)
	local humanoid = WaitForChildOfClass(character, "Humanoid", 5) :: Humanoid
	if humanoid then
		humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
			if humanoid.Jump then
				humanoid.Jump = false
			end
		end)
		Humanoid = humanoid
	end
end

local function OnCharacterRemoving(_: Model)
	Humanoid = nil
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
LocalPlayer.CharacterRemoving:Connect(OnCharacterRemoving)
if LocalPlayer.Character then
	task.spawn(OnCharacterAdded, LocalPlayer.Character)
end

local function QueueJump()
	if Humanoid then
		local IsJumping = if (Controls.activeController and Controls.activeController.enabled and Controls.humanoid) 
			then (if (Controls.activeController:GetIsJumping() or (Controls.touchJumpController and Controls.touchJumpController:GetIsJumping())) 
				then true 
				else false) 
			else false
		if not Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) and IsJumping then
			IsJumping = false
		end
		if HOLD_JUMP_TO_BHOP then
			WishJump = IsJumping
		else
			if IsJumping and not WishJump then
				WishJump = true
				if Controls.activeController then
					Controls.activeController.isJumping = false
				elseif Controls.touchJumpController then
					Controls.touchJumpController.isJumping = false
				end
			end
			if not IsJumping then
				WishJump = false
			end
		end
	end
end

local function ApplyFriction(Time: number, InAir: boolean)
	local Vector = Vector3.new(PlayerVelocity.X, 0, PlayerVelocity.Z)
	local Speed = Vector.Magnitude
	local Control = if Speed < RUN_DEACCELERATION then RUN_DEACCELERATION else Speed
	local NewFriction = if InAir then AIR_FRICTION else FRICTION
	local Drop = Control * NewFriction * RunService.Heartbeat:Wait() * Time
	local NewSpeed = Speed - Drop

	if NewSpeed < 0 then
		NewSpeed = 0
	end

	if Speed > 0 then
		NewSpeed /= Speed
	end

	local X = PlayerVelocity.X * NewSpeed
	local Z = PlayerVelocity.Z * NewSpeed
	PlayerVelocity = Vector3.new(X, 0, Z)
end

local function Accelerate(WishDirection: Vector3, WishSpeed: number, Acceleration: number)
	local Currentspeed = PlayerVelocity:Dot(WishDirection)
	local AddSpeed = WishSpeed - Currentspeed

	if AddSpeed > 0 then 
		local AccelerationSpeed = Acceleration * RunService.Heartbeat:Wait() * WishSpeed
		if AccelerationSpeed > AddSpeed then
			AccelerationSpeed = AddSpeed
		end

		local X = PlayerVelocity.X + AccelerationSpeed * WishDirection.X
		local Z = PlayerVelocity.Z + AccelerationSpeed * WishDirection.Z
		PlayerVelocity = Vector3.new(X, 0, Z)
	end
end

local function GroundMove(RelativeToCamera: boolean)
	if not WishJump and CanJump then
		ApplyFriction(1, false)
	else
		ApplyFriction(0, false)
	end
	
	local CoordinateFrame = if workspace.CurrentCamera 
		then workspace.CurrentCamera.CFrame
		else CFrame.new()

	local WishDirection = CoordinateFrame:VectorToWorldSpace(InputVelocity)
	WishDirection = if RelativeToCamera 
		then Vector3.new(WishDirection.X, 0, WishDirection.Z)
		else InputVelocity

	if WishDirection ~= Vector3.zero then
		WishDirection = WishDirection.Unit
	end

	local WishSpeed = WishDirection.Magnitude
	WishSpeed *= MOVE_SPEED

	Accelerate(
		WishDirection, 
		WishSpeed, 
		RUN_ACCELERATION
	)

	PlayerVelocity = Vector3.new(
		PlayerVelocity.X, 
		0, 
		PlayerVelocity.Z
	)
	
	if Humanoid and WishJump and CanJump then
		Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		WishJump = false
		CanJump = false

		task.spawn(function()
			local Begin = tick()
			while tick() - Begin < JUMP_BUFFER do
				RunService.Heartbeat:Wait()
			end
			CanJump = true
		end)
	end
end

local function AirMove(RelativeToCamera: boolean)
	if InputVelocity.Z ~= 0 then
		ApplyFriction(1, true)
	end

	local CoordinateFrame = if workspace.CurrentCamera 
		then workspace.CurrentCamera.CFrame
		else CFrame.new()

	local WishDirection = CoordinateFrame:VectorToWorldSpace(InputVelocity)
	WishDirection = if RelativeToCamera 
		then Vector3.new(WishDirection.X, 0, WishDirection.Z)
		else InputVelocity
	
	local WishSpeed = WishDirection.Magnitude
	WishSpeed *= MOVE_SPEED

	if WishDirection ~= Vector3.zero then
		WishDirection = WishDirection.Unit
	end

	local Acceleration: number = if PlayerVelocity:Dot(WishDirection) < 0 
		then AIR_DEACCELERATION
		else AIR_ACCELERATION

	if InputVelocity.Z == 0 and InputVelocity.X ~= 0 then
		if WishSpeed > SIDE_STRAFE_SPEED then
			WishSpeed = SIDE_STRAFE_SPEED
		end
		Acceleration = SIDE_STRAFE_ACCELERATION
	end
	
	Accelerate(WishDirection, WishSpeed, Acceleration)
end

Controls.moveFunction = function(Player: Player, _: Vector3, RelativeToCamera: boolean)
	RelativeToCamera = if Controls.activeController
		then Controls.activeController:IsMoveVectorCameraRelative()
		else RelativeToCamera
	if Player == LocalPlayer then
		local MoveVector = Controls:GetMoveVector()
		MoveVector = Vector3.new(
			ThumbstickCurve(MoveVector.X),
			ThumbstickCurve(MoveVector.Y),
			ThumbstickCurve(MoveVector.Z)
		)
		if MoveVector ~= InputVelocity then
			InputVelocity = MoveVector
		end
		if Humanoid then
			QueueJump()
			local Grounded = Humanoid.FloorMaterial ~= Enum.Material.Air or Humanoid:GetState() == Enum.HumanoidStateType.Climbing
			if Grounded then
				GroundMove(RelativeToCamera)
			else
				AirMove(RelativeToCamera)
			end
			
			local NewDirection = Vector3.zero
			if PlayerVelocity ~= Vector3.zero then 
				NewDirection = PlayerVelocity.Unit 
			end
			
			local NewSpeed = PlayerVelocity.Magnitude
			NewSpeed = math.clamp(NewSpeed, 0, MAX_SPEED)
			
			if Humanoid then
				Humanoid.WalkSpeed = NewSpeed
				Humanoid:Move(NewDirection, false)
			end
		end
	end
end