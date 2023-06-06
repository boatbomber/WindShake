local WIND_DIRECTION = Vector3.new(1, 0, 0.3)
local WIND_SPEED = 20
local WIND_POWER = 0.5
local SHAKE_RADIUS = 120

local WindLines = require(script.WindLines)
local WindShake = require(script.WindShake)

WindLines:Init({
	Direction = WIND_DIRECTION,
	Speed = WIND_SPEED,
	Lifetime = 1.5,
	SpawnRate = 11,
})

WindShake:SetDefaultSettings({
	WindSpeed = WIND_SPEED,
	WindDirection = WIND_DIRECTION,
	WindPower = WIND_POWER,
})
WindShake:Init()

-- Demo dynamic settings

local Gui = Instance.new("ScreenGui")

local CountLabel = Instance.new("TextLabel")
CountLabel.Text = string.format("Leaf Count: %d Active, %d Inactive, 77760 Total", 0, 0)
CountLabel.BackgroundTransparency = 0.3
CountLabel.BackgroundColor3 = Color3.new()
CountLabel.TextStrokeTransparency = 0.8
CountLabel.Size = UDim2.new(0.6, 0, 0, 27)
CountLabel.Position = UDim2.new(0.2, 0, 1, -35)
CountLabel.Font = Enum.Font.RobotoMono
CountLabel.TextSize = 25
CountLabel.TextColor3 = Color3.new(1, 1, 1)
CountLabel.Parent = Gui

local SpeedInput = Instance.new("TextBox")
SpeedInput.Text = string.format("Wind Speed: %.1f", WIND_SPEED)
SpeedInput.PlaceholderText = "Input Speed"
SpeedInput.BackgroundTransparency = 0.8
SpeedInput.TextStrokeTransparency = 0.8
SpeedInput.Size = UDim2.new(0.2, 0, 0, 20)
SpeedInput.Position = UDim2.new(0, 5, 0.45, 0)
SpeedInput.Font = Enum.Font.RobotoMono
SpeedInput.TextXAlignment = Enum.TextXAlignment.Left
SpeedInput.TextSize = 18
SpeedInput.TextColor3 = Color3.new(1, 1, 1)
SpeedInput.FocusLost:Connect(function()
	local newSpeed = tonumber(SpeedInput.Text:match("[%d%.]+"))
	if newSpeed then
		WIND_SPEED = math.clamp(newSpeed, 0, 50)
		WindLines.Speed = WIND_SPEED
		WindShake:UpdateAllObjectSettings({ Speed = WIND_SPEED })
		WindShake:SetDefaultSettings({ Speed = WIND_SPEED })
	end
	SpeedInput.Text = string.format("Wind Speed: %.1f", WIND_SPEED)
end)
SpeedInput.Parent = Gui

local PowerInput = Instance.new("TextBox")
PowerInput.Text = string.format("Wind Power: %.1f", WIND_POWER)
PowerInput.PlaceholderText = "Input Power"
PowerInput.BackgroundTransparency = 0.8
PowerInput.TextStrokeTransparency = 0.8
PowerInput.Size = UDim2.new(0.2, 0, 0, 20)
PowerInput.Position = UDim2.new(0, 5, 0.45, 25)
PowerInput.Font = Enum.Font.RobotoMono
PowerInput.TextXAlignment = Enum.TextXAlignment.Left
PowerInput.TextSize = 18
PowerInput.TextColor3 = Color3.new(1, 1, 1)
PowerInput.FocusLost:Connect(function()
	local newPower = tonumber(PowerInput.Text:match("[%d%.]+"))
	if newPower then
		WIND_POWER = math.clamp(newPower, 0, 10)
		WindShake:UpdateAllObjectSettings({ Power = WIND_POWER })
		WindShake:SetDefaultSettings({ Power = WIND_POWER })
	end
	PowerInput.Text = string.format("Wind Power: %.1f", WIND_POWER)
end)
PowerInput.Parent = Gui

local DirInput = Instance.new("TextBox")
DirInput.Text = string.format("Wind Direction: %.1f,%.1f,%.1f", WIND_DIRECTION.X, WIND_DIRECTION.Y, WIND_DIRECTION.Z)
DirInput.PlaceholderText = "Input Direction"
DirInput.BackgroundTransparency = 0.8
DirInput.TextStrokeTransparency = 0.8
DirInput.Size = UDim2.new(0.2, 0, 0, 20)
DirInput.Position = UDim2.new(0, 5, 0.45, 50)
DirInput.Font = Enum.Font.RobotoMono
DirInput.TextXAlignment = Enum.TextXAlignment.Left
DirInput.TextSize = 18
DirInput.TextColor3 = Color3.new(1, 1, 1)
DirInput.FocusLost:Connect(function()
	local Inputs = table.create(3)
	for Num in string.gmatch(DirInput.Text, "%-?[%d%.]+") do
		Inputs[#Inputs + 1] = tonumber(Num)
	end

	local newDir =
		Vector3.new(Inputs[1] or WIND_DIRECTION.X, Inputs[2] or WIND_DIRECTION.Y, Inputs[3] or WIND_DIRECTION.Z).Unit
	if newDir then
		WIND_DIRECTION = newDir
		WindLines.Direction = newDir
		WindShake:UpdateAllObjectSettings({ Direction = newDir })
		WindShake:SetDefaultSettings({ Direction = newDir })
	end

	DirInput.Text =
		string.format("Wind Direction: %.1f, %.1f, %.1f", WIND_DIRECTION.X, WIND_DIRECTION.Y, WIND_DIRECTION.Z)
end)
DirInput.Parent = Gui

local RadiusInput = Instance.new("TextBox")
RadiusInput.Text = string.format("Shake Radius: %.1f", SHAKE_RADIUS)
RadiusInput.PlaceholderText = "Input Radius"
RadiusInput.BackgroundTransparency = 0.8
RadiusInput.TextStrokeTransparency = 0.8
RadiusInput.Size = UDim2.new(0.2, 0, 0, 20)
RadiusInput.Position = UDim2.new(0, 5, 0.45, 75)
RadiusInput.Font = Enum.Font.RobotoMono
RadiusInput.TextXAlignment = Enum.TextXAlignment.Left
RadiusInput.TextSize = 18
RadiusInput.TextColor3 = Color3.new(1, 1, 1)
RadiusInput.FocusLost:Connect(function()
	local newRadius = tonumber(RadiusInput.Text:match("[%d%.]+"))
	if newRadius then
		SHAKE_RADIUS = math.clamp(newRadius, 5, 500)
		WindShake.Radius = SHAKE_RADIUS
	end
	RadiusInput.Text = string.format("Shake Radius: %.1f", SHAKE_RADIUS)
end)
RadiusInput.Parent = Gui

Gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

task.defer(function()
	while task.wait(0.1) do
		local Active, Handled = WindShake.Active, WindShake.Handled
		CountLabel.Text = string.format(
			"Leaf Count: %d Active, %d Inactive, %d Not Streamed In (77760 Total)",
			Active,
			Handled - Active,
			77760 - Handled
		)
	end
end)
