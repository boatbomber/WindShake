local Settings = {}

local SettingTypes = {
	WindPower = "number",
	WindSpeed = "number",
	WindDirection = "Vector3",
	PivotOffset = "CFrame",
}

function Settings.new(object: Instance, base)
	local inst = {}

	-- Initial settings

	local WindPower = object:GetAttribute("WindPower")
	local WindSpeed = object:GetAttribute("WindSpeed")
	local WindDirection = object:GetAttribute("WindDirection")

	inst.WindPower = typeof(WindPower) == SettingTypes.WindPower and WindPower or base.WindPower
	inst.WindSpeed = typeof(WindSpeed) == SettingTypes.WindSpeed and WindSpeed or base.WindSpeed
	inst.WindDirection = typeof(WindDirection) == SettingTypes.WindDirection and WindDirection or base.WindDirection
	inst.PivotOffset = if object:IsA("BasePart") then object.PivotOffset else (base.PivotOffset or CFrame.new())
	inst.PivotOffsetInverse = inst.PivotOffset:Inverse()

	-- Update settings on event

	local PowerConnection = object:GetAttributeChangedSignal("WindPower"):Connect(function()
		WindPower = object:GetAttribute("WindPower")
		inst.WindPower = typeof(WindPower) == SettingTypes.WindPower and WindPower or base.WindPower
	end)

	local SpeedConnection = object:GetAttributeChangedSignal("WindSpeed"):Connect(function()
		WindSpeed = object:GetAttribute("WindSpeed")
		inst.WindSpeed = typeof(WindSpeed) == SettingTypes.WindSpeed and WindSpeed or base.WindSpeed
	end)

	local DirectionConnection = object:GetAttributeChangedSignal("WindDirection"):Connect(function()
		WindDirection = object:GetAttribute("WindDirection")
		inst.WindDirection = typeof(WindDirection) == SettingTypes.WindDirection and WindDirection or base.WindDirection
	end)

	local PivotConnection
	if object:IsA("BasePart") then
		PivotConnection = object:GetPropertyChangedSignal("PivotOffset"):Connect(function()
			inst.PivotOffset = object.PivotOffset
			inst.PivotOffsetInverse = inst.PivotOffset:Inverse()
		end)
	end

	-- Cleanup function for when shake is removed or object is unloaded

	function inst:Destroy()
		PowerConnection:Disconnect()
		SpeedConnection:Disconnect()
		DirectionConnection:Disconnect()
		if PivotConnection then
			PivotConnection:Disconnect()
		end

		table.clear(inst)
	end

	return inst
end

return Settings
