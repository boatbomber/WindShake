local Settings = {}

local SettingTypes = {
	WindPower = "number",
	WindSpeed = "number",
	WindDirection = "Vector3",
	PivotOffset = "CFrame",
}

function Settings.new(object: BasePart | Bone, base)
	local inst = {}

	-- Initial settings

	local WindPower = object:GetAttribute("WindPower")
	local WindSpeed = object:GetAttribute("WindSpeed")
	local WindDirection = object:GetAttribute("WindDirection")

	inst.WindPower = if typeof(WindPower) == SettingTypes.WindPower then WindPower else base.WindPower
	inst.WindSpeed = if typeof(WindSpeed) == SettingTypes.WindSpeed then WindSpeed else base.WindSpeed
	inst.WindDirection = if typeof(WindDirection) == SettingTypes.WindDirection
		then WindDirection.Unit
		else base.WindDirection
	inst.PivotOffset = if object:IsA("BasePart") then object.PivotOffset else (base.PivotOffset or CFrame.new())
	inst.PivotOffsetInverse = inst.PivotOffset:Inverse()

	-- Update settings on event

	local PowerConnection = object:GetAttributeChangedSignal("WindPower"):Connect(function()
		WindPower = object:GetAttribute("WindPower")
		inst.WindPower = if typeof(WindPower) == SettingTypes.WindPower then WindPower else base.WindPower
	end)

	local SpeedConnection = object:GetAttributeChangedSignal("WindSpeed"):Connect(function()
		WindSpeed = object:GetAttribute("WindSpeed")
		inst.WindSpeed = if typeof(WindSpeed) == SettingTypes.WindSpeed then WindSpeed else base.WindSpeed
	end)

	local DirectionConnection = object:GetAttributeChangedSignal("WindDirection"):Connect(function()
		WindDirection = object:GetAttribute("WindDirection")
		inst.WindDirection = if typeof(WindDirection) == SettingTypes.WindDirection
			then WindDirection.Unit
			else base.WindDirection
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
