--!strict

local VectorMap = {}
VectorMap.__index = VectorMap

function VectorMap.new(chunkSize: number?)
	return setmetatable({
		_chunkSize = chunkSize or 50,
		_map = {},
	}, VectorMap)
end

function VectorMap:_debugDrawChunk(chunkKey: Vector3)
	local box = Instance.new("Part")
	box.Name = tostring(chunkKey)
	box.Anchored = true
	box.CanCollide = false
	box.Transparency = 1
	box.Size = Vector3.one * self._chunkSize
	box.Position = (chunkKey * self._chunkSize) + (Vector3.one * (self._chunkSize / 2))
	box.Parent = workspace

	local selection = Instance.new("SelectionBox")
	selection.Color3 = Color3.new(0, 0, 1)
	selection.Adornee = box
	selection.Parent = box

	task.delay(1 / 30, box.Destroy, box)
end

function VectorMap:AddObject(position: Vector3, object: any)
	local chunkSize = self._chunkSize
	local chunkKey = Vector3.new(
		math.floor(position.X / chunkSize),
		math.floor(position.Y / chunkSize),
		math.floor(position.Z / chunkSize)
	)

	local chunk = self._map[chunkKey]

	if not chunk then
		self._map[chunkKey] = { object }
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

	for x = math.floor(minx / chunkSize), math.floor(maxx / chunkSize) do
		for z = math.floor(minz / chunkSize), math.floor(maxz / chunkSize) do
			for y = math.floor(miny / chunkSize), math.floor(maxy / chunkSize) do
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
	local halfChunkSize = (chunkSize :: number) / 2
	local cameraCFrame = camera.CFrame
	local cameraCFrameInverse = cameraCFrame:Inverse()
	local cameraPos = cameraCFrame.Position
	local rightVec, upVec = cameraCFrame.RightVector, cameraCFrame.UpVector
	local aspectRatio = camera.ViewportSize.X / camera.ViewportSize.Y

	local farPlaneHeight2 = math.tan(math.rad(camera.FieldOfView / 2)) * distance
	local farPlaneWidth2 = farPlaneHeight2 * aspectRatio
	local farPlaneCFrame = cameraCFrame * CFrame.new(0, 0, -distance)
	local farPlaneTopLeft = farPlaneCFrame * Vector3.new(-farPlaneWidth2, farPlaneHeight2, 0)
	local farPlaneTopRight = farPlaneCFrame * Vector3.new(farPlaneWidth2, farPlaneHeight2, 0)
	local farPlaneBottomLeft = farPlaneCFrame * Vector3.new(-farPlaneWidth2, -farPlaneHeight2, 0)
	local farPlaneBottomRight = farPlaneCFrame * Vector3.new(farPlaneWidth2, -farPlaneHeight2, 0)

	local rightNormal = upVec:Cross(farPlaneBottomRight - cameraPos).Unit
	local leftNormal = upVec:Cross(farPlaneBottomLeft - cameraPos).Unit
	local topNormal = rightVec:Cross(cameraPos - farPlaneTopRight).Unit
	local bottomNormal = rightVec:Cross(cameraPos - farPlaneBottomRight).Unit

	local distThreshold = (cameraPos - farPlaneTopRight).Magnitude

	for x = math.floor(
		math.min(cameraCFrame.X, farPlaneTopLeft.X, farPlaneTopRight.X, farPlaneBottomLeft.X, farPlaneBottomRight.X)
			/ chunkSize
	), math.floor(
		math.max(cameraCFrame.X, farPlaneTopLeft.X, farPlaneTopRight.X, farPlaneBottomLeft.X, farPlaneBottomRight.X)
			/ chunkSize
	) do
		local xMin = x * chunkSize
		local xMax = xMin + chunkSize
		local xPos = math.clamp(farPlaneCFrame.X, xMin, xMax)

		for y = math.floor(
			math.min(cameraCFrame.Y, farPlaneTopLeft.Y, farPlaneTopRight.Y, farPlaneBottomLeft.Y, farPlaneBottomRight.Y)
				/ chunkSize
		), math.floor(
			math.max(cameraCFrame.Y, farPlaneTopLeft.Y, farPlaneTopRight.Y, farPlaneBottomLeft.Y, farPlaneBottomRight.Y)
				/ chunkSize
		) do
			local yMin = y * chunkSize
			local yMax = yMin + chunkSize
			local yPos = math.clamp(farPlaneCFrame.Y, yMin, yMax)

			for z = math.floor(
				math.min(
					cameraCFrame.Z,
					farPlaneTopLeft.Z,
					farPlaneTopRight.Z,
					farPlaneBottomLeft.Z,
					farPlaneBottomRight.Z
				) / chunkSize
			), math.floor(
				math.max(
					cameraCFrame.Z,
					farPlaneTopLeft.Z,
					farPlaneTopRight.Z,
					farPlaneBottomLeft.Z,
					farPlaneBottomRight.Z
				) / chunkSize
			) do
				local chunkKey = Vector3.new(x, y, z)
				local chunk = self._map[chunkKey]
				if not chunk then
					continue
				end

				local zMin = z * chunkSize
				local zMax = zMin + chunkSize
				local chunkNearestPoint = Vector3.new(
					xPos,
					yPos,
					math.clamp(farPlaneCFrame.Z, zMin, zMax)
				)

				-- Cut out anything past the far plane or behind the camera
				local depth = (cameraCFrameInverse * chunkNearestPoint).Z
				if depth > halfChunkSize or depth < -halfChunkSize - distance then
					continue
				end

				local lookToCell = chunkNearestPoint - cameraPos

				-- Cheap dist culling for early out
				if lookToCell.Magnitude > distThreshold then
					continue
				end

				-- Cut out cells that lie outside a frustum plane
				if
					rightNormal:Dot(lookToCell) < 0
					or leftNormal:Dot(lookToCell) > 0
					or topNormal:Dot(lookToCell) < 0
					or bottomNormal:Dot(lookToCell) > 0
				then
					continue
				end

				-- self:_debugDrawChunk(chunkKey)

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
