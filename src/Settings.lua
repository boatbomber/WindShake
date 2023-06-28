local Settings = {}

local SettingTypes = {
	WindPower = "number",
	WindSpeed = "number",
	WindDirection = "Vector3",
	PivotOffset = "CFrame",
}

function Settings.new(object: BasePart | Bone | ModuleScript)
	local objectSettings = {}

	-- Initial settings
	local WindPower = object:GetAttribute("WindPower")
	local WindSpeed = object:GetAttribute("WindSpeed")
	local WindDirection = object:GetAttribute("WindDirection")

	objectSettings.WindPower = if typeof(WindPower) == SettingTypes.WindPower then WindPower else nil
	objectSettings.WindSpeed = if typeof(WindSpeed) == SettingTypes.WindSpeed then WindSpeed else nil
	objectSettings.WindDirection = if typeof(WindDirection) == SettingTypes.WindDirection
		then (if WindDirection.Magnitude > 0 then WindDirection.Unit else Vector3.zero)
		else nil
	objectSettings.PivotOffset = if object:IsA("BasePart") then object.PivotOffset else nil
	objectSettings.PivotOffsetInverse = if typeof(objectSettings.PivotOffset) == "CFrame"
		then objectSettings.PivotOffset:Inverse()
		else nil

	-- Update settings on event

	local PowerConnection = object:GetAttributeChangedSignal("WindPower"):Connect(function()
		WindPower = object:GetAttribute("WindPower")
		objectSettings.WindPower = if typeof(WindPower) == SettingTypes.WindPower then WindPower else nil
	end)

	local SpeedConnection = object:GetAttributeChangedSignal("WindSpeed"):Connect(function()
		WindSpeed = object:GetAttribute("WindSpeed")
		objectSettings.WindSpeed = if typeof(WindSpeed) == SettingTypes.WindSpeed then WindSpeed else nil
	end)

	local DirectionConnection = object:GetAttributeChangedSignal("WindDirection"):Connect(function()
		WindDirection = object:GetAttribute("WindDirection")
		objectSettings.WindDirection = if typeof(WindDirection) == SettingTypes.WindDirection
			then (if WindDirection.Magnitude > 0 then WindDirection.Unit else Vector3.zero)
			else nil
	end)

	local PivotConnection
	if object:IsA("BasePart") then
		PivotConnection = object:GetPropertyChangedSignal("PivotOffset"):Connect(function()
			objectSettings.PivotOffset = object.PivotOffset
			objectSettings.PivotOffsetInverse = objectSettings.PivotOffset:Inverse()
		end)
	end

	-- Cleanup function for when shake is removed or object is unloaded

	function objectSettings:Destroy()
		PowerConnection:Disconnect()
		SpeedConnection:Disconnect()
		DirectionConnection:Disconnect()
		if PivotConnection then
			PivotConnection:Disconnect()
		end

		table.clear(objectSettings)
	end

	return objectSettings
end

return Settings
