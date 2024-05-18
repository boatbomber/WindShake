--!strict
local Settings = {}

export type Class = {
	Destroy: (any) -> (),
	WindPower: number?,
	WindSpeed: number?,
	PivotOffset: CFrame?,
	WindDirection: Vector3?,
	PivotOffsetInverse: CFrame?,
}

local function Normalize(vec: Vector3)
	return vec.Magnitude > 0 and vec.Unit or Vector3.zero
end

function Settings.new(object: BasePart | Bone | ModuleScript): Class
	local objectSettings = {}

	-- Initial settings
	local WindPower = object:GetAttribute("WindPower")
	local WindSpeed = object:GetAttribute("WindSpeed")
	local WindDirection = object:GetAttribute("WindDirection")

	objectSettings.WindPower = if type(WindPower) == "number"
		then WindPower
		else nil

	objectSettings.WindSpeed = if type(WindSpeed) == "number"
		then WindSpeed
		else nil

	objectSettings.WindDirection = if typeof(WindDirection) == "Vector3"
		then Normalize(WindDirection)
		else nil

	objectSettings.PivotOffset = if object:IsA("BasePart")
		then object.PivotOffset
		else nil

	objectSettings.PivotOffsetInverse = if objectSettings.PivotOffset
		then objectSettings.PivotOffset:Inverse()
		else nil

	-- Update settings on event
	local Conns = {} :: {
		[string]: RBXScriptConnection
	}

	Conns.PowerConnection = object:GetAttributeChangedSignal("WindPower"):Connect(function()
		WindPower = object:GetAttribute("WindPower")
		objectSettings.WindPower = if type(WindPower) == "number" then WindPower else nil
	end)

	Conns.SpeedConnection = object:GetAttributeChangedSignal("WindSpeed"):Connect(function()
		WindSpeed = object:GetAttribute("WindSpeed")
		objectSettings.WindSpeed = if type(WindSpeed) == "number" then WindSpeed else nil
	end)

	Conns.DirectionConnection = object:GetAttributeChangedSignal("WindDirection"):Connect(function()
		WindDirection = object:GetAttribute("WindDirection")
		objectSettings.WindDirection = if typeof(WindDirection) == "Vector3" then Normalize(WindDirection) else nil
	end)

	if object:IsA("BasePart") then
		Conns.PivotConnection = object:GetPropertyChangedSignal("PivotOffset"):Connect(function()
			local pivotOffset = object.PivotOffset
			objectSettings.PivotOffset = pivotOffset
			objectSettings.PivotOffsetInverse = pivotOffset:Inverse()
		end)
	end

	-- Cleanup function for when shake is removed or object is unloaded
	function objectSettings.Destroy(_self: any)
		for i, conn in pairs(Conns) do
			conn:Disconnect()
		end
	end

	return objectSettings
end

return Settings
