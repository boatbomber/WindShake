--!strict

local VectorMap = {}
VectorMap.__index = VectorMap

function VectorMap.new(chunkSize: number?)
	return setmetatable({
		_chunkSize = chunkSize or 75,
		_map = {},
	}, VectorMap)
end

function VectorMap:AddObject(position: Vector3, object: any)
	local chunkSize = self._chunkSize
	local x, y, z = position.X, position.Y, position.Z
	local chunkKey = Vector3.new(math.floor(x / chunkSize), math.floor(y / chunkSize), math.floor(z / chunkSize))

	local chunk = self._map[chunkKey]

	if not chunk then
		chunk = { object }
		self._map[chunkKey] = chunk
		return chunkKey
	end

	table.insert(chunk, object)
	return chunkKey
end

function VectorMap:RemoveObject(chunkKey: Vector3, object: any)
	local chunk = self._map[chunkKey]

	if not chunk then
		return
	end

	for index, storedObject in chunk do
		if storedObject == object then
			-- Swap remove to avoid shifting
			local n = #chunk
			chunk[index] = chunk[n]
			chunk[n] = nil
			break
		end
	end

	if #chunk == 0 then
		-- Remove empty chunk
		self._map[chunkKey] = nil
	end
end

function VectorMap:GetChunk(chunkKey: Vector3)
	return self._map[chunkKey]
end

function VectorMap:ForEachObjectInRegion(top: Vector3, bottom: Vector3, callback: (any) -> ())
	local chunkSize = self._chunkSize
	local minx, miny, minz = math.min(bottom.X, top.X), math.min(bottom.Y, top.Y), math.min(bottom.Z, top.Z)
	local maxx, maxy, maxz = math.max(bottom.X, top.X), math.max(bottom.Y, top.Y), math.max(bottom.Z, top.Z)

	for x = math.floor(minx / chunkSize) - 1, math.ceil(maxx / chunkSize) do
		for z = math.floor(minz / chunkSize) - 1, math.ceil(maxz / chunkSize) do
			for y = math.floor(miny / chunkSize) - 1, math.ceil(maxy / chunkSize) do
				local chunk = self._map[Vector3.new(x, y, z)]
				if not chunk then
					continue
				end

				for _, object in chunk do
					callback(object)
				end
			end
		end
	end
end

function VectorMap:ForEachObjectInFrustum(camera: Camera, distance: number, callback: (any) -> ())
	local chunkSize = self._chunkSize
	local cameraCFrame = camera.CFrame
	local tanFov2 = math.tan(math.rad(camera.FieldOfView/2))
	local fovThreshold = math.rad((camera.MaxAxisFieldOfView) / 2)
	local aspectRatio = camera.ViewportSize.X / camera.ViewportSize.Y
	local lookVec = cameraCFrame.LookVector

	local farPlaneHeight2 = tanFov2 * distance
	local farPlaneWidth2 = farPlaneHeight2 * aspectRatio
	local farPlaneCFrame = cameraCFrame * CFrame.new(0, 0, -distance)
	local farPlaneTopLeft = (farPlaneCFrame * CFrame.new(-farPlaneWidth2, farPlaneHeight2, 0)).Position
	local farPlaneTopRight = (farPlaneCFrame * CFrame.new(farPlaneWidth2, farPlaneHeight2, 0)).Position
	local farPlaneBottomLeft = (farPlaneCFrame * CFrame.new(-farPlaneWidth2, -farPlaneHeight2, 0)).Position
	local farPlaneBottomRight = (farPlaneCFrame * CFrame.new(farPlaneWidth2, -farPlaneHeight2, 0)).Position

	local checkedKeys = {}
	for x = math.floor(math.min(cameraCFrame.X, farPlaneTopLeft.X, farPlaneTopRight.X, farPlaneBottomLeft.X, farPlaneBottomRight.X) / chunkSize), math.ceil(math.max(cameraCFrame.X, farPlaneTopLeft.X, farPlaneTopRight.X, farPlaneBottomLeft.X, farPlaneBottomRight.X) / chunkSize) do
		for y = math.floor(math.min(cameraCFrame.Y, farPlaneTopLeft.Y, farPlaneTopRight.Y, farPlaneBottomLeft.Y, farPlaneBottomRight.Y) / chunkSize), math.ceil(math.max(cameraCFrame.Y, farPlaneTopLeft.Y, farPlaneTopRight.Y, farPlaneBottomLeft.Y, farPlaneBottomRight.Y) / chunkSize) do
			for z = math.floor(math.min(cameraCFrame.Z, farPlaneTopLeft.Z, farPlaneTopRight.Z, farPlaneBottomLeft.Z, farPlaneBottomRight.Z) / chunkSize), math.ceil(math.max(cameraCFrame.Z, farPlaneTopLeft.Z, farPlaneTopRight.Z, farPlaneBottomLeft.Z, farPlaneBottomRight.Z) / chunkSize) do
				local chunkKey = Vector3.new(x, y, z)
				if checkedKeys[chunkKey] then
					continue
				end
				checkedKeys[chunkKey] = true

				local chunk = self._map[chunkKey]
				if not chunk then
					continue
				end

				if
					math.abs(lookVec:Angle(((chunkKey * chunkSize) - cameraCFrame.Position).Unit)) > fovThreshold
				then
					continue
				end

				for _, object in chunk do
					callback(object)
				end
			end
		end
	end
end


function VectorMap:ClearAll()
	self._map = {}
end

return VectorMap
