--!strict

local VectorMap = {}
VectorMap.__index = VectorMap

function VectorMap.new(chunkSize: number?)
	return setmetatable({
		_chunkSize = chunkSize or 75,
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
	box.Position = chunkKey * self._chunkSize
	box.Parent = workspace

	local selection = Instance.new("SelectionBox")
	selection.Color3 = Color3.new(0, 0, 1)
	selection.Adornee = box
	selection.Parent = box

	task.delay(1 / 30, box.Destroy, box)
end

function VectorMap:AddObject(position: Vector3, object: any)
	local chunkSize = self._chunkSize
	local x, y, z = position.X, position.Y, position.Z
	local chunkKey = Vector3.new(math.round(x / chunkSize), math.round(y / chunkSize), math.round(z / chunkSize))

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
	local halfChunkSize = (chunkSize :: number) / 2
	local cameraCFrame = camera.CFrame
	local cameraCFrameInverse = cameraCFrame:Inverse()
	local cameraPos = cameraCFrame.Position
	local tanFov2 = math.tan(math.rad(camera.FieldOfView / 2))
	local aspectRatio = camera.ViewportSize.X / camera.ViewportSize.Y

	-- Build frustum

	local farPlaneHeight2 = tanFov2 * distance
	local farPlaneWidth2 = farPlaneHeight2 * aspectRatio
	local farPlaneCFrame = cameraCFrame * CFrame.new(0, 0, -distance)
	local farPlaneCFrameInverse = farPlaneCFrame:Inverse()
	local farPlaneTopLeft = (farPlaneCFrame * CFrame.new(-farPlaneWidth2, farPlaneHeight2, 0)).Position
	local farPlaneTopRight = (farPlaneCFrame * CFrame.new(farPlaneWidth2, farPlaneHeight2, 0)).Position
	local farPlaneBottomLeft = (farPlaneCFrame * CFrame.new(-farPlaneWidth2, -farPlaneHeight2, 0)).Position
	local farPlaneBottomRight = (farPlaneCFrame * CFrame.new(farPlaneWidth2, -farPlaneHeight2, 0)).Position

	local right1 = cameraPos - farPlaneTopRight
	local right2 = cameraPos - farPlaneBottomRight
	local rightNormal = right1:Cross(right2).Unit
	local rightMidpoint = Vector3.new(
		(cameraCFrame.X + farPlaneTopRight.X + farPlaneBottomRight.X) / 3,
		(cameraCFrame.Y + farPlaneTopRight.Y + farPlaneBottomRight.Y) / 3,
		(cameraCFrame.Z + farPlaneTopRight.Z + farPlaneBottomRight.Z) / 3
	)
	local rightPlaneCFrameInverse = CFrame.lookAt(rightMidpoint, rightMidpoint - rightNormal):Inverse()

	local left1 = cameraPos - farPlaneTopLeft
	local left2 = cameraPos - farPlaneBottomLeft
	local leftNormal = left1:Cross(left2).Unit
	local leftMidpoint = Vector3.new(
		(cameraCFrame.X + farPlaneTopLeft.X + farPlaneBottomLeft.X) / 3,
		(cameraCFrame.Y + farPlaneTopLeft.Y + farPlaneBottomLeft.Y) / 3,
		(cameraCFrame.Z + farPlaneTopLeft.Z + farPlaneBottomLeft.Z) / 3
	)
	local leftPlaneCFrameInverse = CFrame.lookAt(leftMidpoint, leftMidpoint + leftNormal):Inverse()

	local top1 = cameraPos - farPlaneTopLeft
	local top2 = cameraPos - farPlaneTopRight
	local topNormal = top1:Cross(top2).Unit
	local topMidpoint = Vector3.new(
		(cameraCFrame.X + farPlaneTopLeft.X + farPlaneTopRight.X) / 3,
		(cameraCFrame.Y + farPlaneTopLeft.Y + farPlaneTopRight.Y) / 3,
		(cameraCFrame.Z + farPlaneTopLeft.Z + farPlaneTopRight.Z) / 3
	)
	local topPlaneCFrameInverse = CFrame.lookAt(topMidpoint, topMidpoint - topNormal):Inverse()

	local bottom1 = cameraPos - farPlaneBottomLeft
	local bottom2 = cameraPos - farPlaneBottomRight
	local bottomNormal = bottom1:Cross(bottom2).Unit
	local bottomMidpoint = Vector3.new(
		(cameraCFrame.X + farPlaneBottomLeft.X + farPlaneBottomRight.X) / 3,
		(cameraCFrame.Y + farPlaneBottomLeft.Y + farPlaneBottomRight.Y) / 3,
		(cameraCFrame.Z + farPlaneBottomLeft.Z + farPlaneBottomRight.Z) / 3
	)
	local bottomPlaneCFrameInverse = CFrame.lookAt(bottomMidpoint, bottomMidpoint + bottomNormal):Inverse()

	local checkedKeys = {}
	for x = math.floor(
		math.min(cameraCFrame.X, farPlaneTopLeft.X, farPlaneTopRight.X, farPlaneBottomLeft.X, farPlaneBottomRight.X)
			/ chunkSize
	), math.ceil(
		math.max(cameraCFrame.X, farPlaneTopLeft.X, farPlaneTopRight.X, farPlaneBottomLeft.X, farPlaneBottomRight.X)
			/ chunkSize
	) do
		for y = math.floor(
			math.min(cameraCFrame.Y, farPlaneTopLeft.Y, farPlaneTopRight.Y, farPlaneBottomLeft.Y, farPlaneBottomRight.Y)
				/ chunkSize
		), math.ceil(
			math.max(cameraCFrame.Y, farPlaneTopLeft.Y, farPlaneTopRight.Y, farPlaneBottomLeft.Y, farPlaneBottomRight.Y)
				/ chunkSize
		) do
			for z = math.floor(
				math.min(
					cameraCFrame.Z,
					farPlaneTopLeft.Z,
					farPlaneTopRight.Z,
					farPlaneBottomLeft.Z,
					farPlaneBottomRight.Z
				) / chunkSize
			), math.ceil(
				math.max(
					cameraCFrame.Z,
					farPlaneTopLeft.Z,
					farPlaneTopRight.Z,
					farPlaneBottomLeft.Z,
					farPlaneBottomRight.Z
				) / chunkSize
			) do
				local chunkKey = Vector3.new(x, y, z)
				if checkedKeys[chunkKey] then
					continue
				end
				checkedKeys[chunkKey] = true

				local chunk = self._map[chunkKey]
				if not chunk then
					continue
				end

				local chunkWorldPos = chunkKey * chunkSize
				if
					(cameraCFrameInverse * chunkWorldPos).Z > halfChunkSize -- Behind near plane
					or (farPlaneCFrameInverse * chunkWorldPos).Z < -halfChunkSize -- Past far plane
					or (rightPlaneCFrameInverse * chunkWorldPos).Z < -halfChunkSize -- Outside right plane
					or (leftPlaneCFrameInverse * chunkWorldPos).Z < -halfChunkSize -- Outside left plane
					or (topPlaneCFrameInverse * chunkWorldPos).Z < -halfChunkSize -- Outside top plane
					or (bottomPlaneCFrameInverse * chunkWorldPos).Z < -halfChunkSize -- Outside bottom plane
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
