local Players = game:GetService("Players")
local playerlocal = Players.LocalPlayer

local frame = script.Parent.Frame
local fram2 = frame.Frame
local icon = fram2.IconPlayer


--Players:GetUserThumbnailAsync(1, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

local function refresh()
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		local iconUrl, isReady = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		if isReady or not isReady then
			if not frame:FindFirstChild(tostring(userId)) then
				local copyfram2 = fram2:Clone()
				copyfram2.Parent = frame
				copyfram2.Name = tostring(userId)
				copyfram2.IconPlayer.Image = iconUrl
				copyfram2.Visible = true
			end
		end
	end
end

refresh()

Players.PlayerAdded:Connect(function(player)
	local userId = player.UserId
	local iconUrl, isReady = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	if isReady then
		if not frame:FindFirstChild(tostring(userId)) then
			local copyfram2 = fram2:Clone()
			copyfram2.Parent = frame
			copyfram2.Name = tostring(userId)
			copyfram2.IconPlayer.Image = iconUrl
			copyfram2.Visible = true
		end
	end
end)


Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId

	local frameToRemove = frame:FindFirstChild(tostring(userId))
	if frameToRemove then
		frameToRemove:Destroy()
	end
	
end)

	