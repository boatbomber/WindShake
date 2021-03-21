local Settings = {}

function Settings.new(object, base)
	local inst = {
		_object = object;
		_base = base;
	}
	
	return setmetatable(inst, Settings)
end

function Settings:__index(key)
	local result = self._object:GetAttribute(key)
	local base = self._base
	
	if base ~= nil then
		base = base[key]

		if typeof(result) ~= typeof(base) then
			result = base
		end
	end
	
	return result
end

function Settings:__newindex(key, value)
	self._object:SetAttribute(key, value)
end

return Settings