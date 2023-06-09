--!strict

local VectorMap = {}
VectorMap.__index = VectorMap

function VectorMap.new(voxelSize: number?)
	return setmetatable({
		_voxelSize = voxelSize or 50,
		_voxels = {},
	}, VectorMap)
end

function VectorMap:_debugDrawVoxel(voxelKey: Vector3)
	local box = Instance.new("Part")
	box.Name = tostring(voxelKey)
	box.Anchored = true
	box.CanCollide = false
	box.Transparency = 1
	box.Size = Vector3.one * self._voxelSize
	box.Position = (voxelKey * self._voxelSize) + (Vector3.one * (self._voxelSize / 2))
	box.Parent = workspace

	local selection = Instance.new("SelectionBox")
	selection.Color3 = Color3.new(0, 0, 1)
	selection.Adornee = box
	selection.Parent = box

	task.delay(1 / 30, box.Destroy, box)
end

function VectorMap:AddObject(position: Vector3, object: any)
	local voxelSize = self._voxelSize
	local voxelKey = Vector3.new(
		math.floor(position.X / voxelSize),
		math.floor(position.Y / voxelSize),
		math.floor(position.Z / voxelSize)
	)

	local voxel = self._voxels[voxelKey]

	if not voxel then
		self._voxels[voxelKey] = { object }
		return voxelKey
	end

	table.insert(voxel, object)
	return voxelKey
end

function VectorMap:RemoveObject(voxelKey: Vector3, object: any)
	local voxel = self._voxels[voxelKey]

	if not voxel then
		return
	end

	for index, storedObject in voxel do
		if storedObject == object then
			-- Swap remove to avoid shifting
			local n = #voxel
			voxel[index] = voxel[n]
			voxel[n] = nil
			break
		end
	end

	if #voxel == 0 then
		-- Remove empty voxel
		self._voxels[voxelKey] = nil
	end
end

function VectorMap:GetVoxel(voxelKey: Vector3)
	return self._voxels[voxelKey]
end

function VectorMap:ForEachObjectInRegion(top: Vector3, bottom: Vector3, callback: (any) -> ())
	local voxelSize = self._voxelSize
	local xMin, yMin, zMin = math.min(bottom.X, top.X), math.min(bottom.Y, top.Y), math.min(bottom.Z, top.Z)
	local xMax, yMax, zMax = math.max(bottom.X, top.X), math.max(bottom.Y, top.Y), math.max(bottom.Z, top.Z)

	for x = math.floor(xMin / voxelSize), math.floor(xMax / voxelSize) do
		for z = math.floor(zMin / voxelSize), math.floor(zMax / voxelSize) do
			for y = math.floor(yMin / voxelSize), math.floor(yMax / voxelSize) do
				local voxel = self._voxels[Vector3.new(x, y, z)]
				if not voxel then
					continue
				end

				for _, object in voxel do
					callback(object)
				end
			end
		end
	end
end

function VectorMap:ForEachObjectInView(camera: Camera, distance: number, callback: (any) -> ())
	local voxelSize = self._voxelSize
	local cameraCFrame = camera.CFrame
	local cameraPos = cameraCFrame.Position
	local rightVec, upVec = cameraCFrame.RightVector, cameraCFrame.UpVector

	local distance2 = distance / 2
	local farPlaneHeight2 = math.tan(math.rad((camera.FieldOfView + 5) / 2)) * distance
	local farPlaneWidth2 = farPlaneHeight2 * (camera.ViewportSize.X / camera.ViewportSize.Y)
	local farPlaneCFrame = cameraCFrame * CFrame.new(0, 0, -distance)
	local farPlaneTopLeft = farPlaneCFrame * Vector3.new(-farPlaneWidth2, farPlaneHeight2, 0)
	local farPlaneTopRight = farPlaneCFrame * Vector3.new(farPlaneWidth2, farPlaneHeight2, 0)
	local farPlaneBottomLeft = farPlaneCFrame * Vector3.new(-farPlaneWidth2, -farPlaneHeight2, 0)
	local farPlaneBottomRight = farPlaneCFrame * Vector3.new(farPlaneWidth2, -farPlaneHeight2, 0)

	local frustumCFrameInverse = (cameraCFrame * CFrame.new(0, 0, -distance2)):Inverse()

	local rightNormal = upVec:Cross(farPlaneBottomRight - cameraPos).Unit
	local leftNormal = upVec:Cross(farPlaneBottomLeft - cameraPos).Unit
	local topNormal = rightVec:Cross(cameraPos - farPlaneTopRight).Unit
	local bottomNormal = rightVec:Cross(cameraPos - farPlaneBottomRight).Unit

	local minBound =
		cameraPos:Min(farPlaneTopLeft):Min(farPlaneTopRight):Min(farPlaneBottomLeft):Min(farPlaneBottomRight)
	local maxBound =
		cameraPos:Max(farPlaneTopLeft):Max(farPlaneTopRight):Max(farPlaneBottomLeft):Max(farPlaneBottomRight)

	for x = math.floor(minBound.X / voxelSize), math.floor(maxBound.X / voxelSize) do
		local xMin = x * voxelSize
		local xMax = xMin + voxelSize
		local xPos = math.clamp(farPlaneCFrame.X, xMin, xMax)

		for y = math.floor(minBound.Y / voxelSize), math.floor(maxBound.Y / voxelSize) do
			local yMin = y * voxelSize
			local yMax = yMin + voxelSize
			local yPos = math.clamp(farPlaneCFrame.Y, yMin, yMax)

			for z = math.floor(minBound.Z / voxelSize), math.floor(maxBound.Z / voxelSize) do
				local voxelKey = Vector3.new(x, y, z)
				local voxel = self._voxels[voxelKey]
				if not voxel then
					continue
				end

				local zMin = z * voxelSize
				local zMax = zMin + voxelSize
				local voxelNearestPoint = Vector3.new(xPos, yPos, math.clamp(farPlaneCFrame.Z, zMin, zMax))

				-- Cut out voxel if outside the frustum OBB
				local relativeToOBB = frustumCFrameInverse * voxelNearestPoint
				if
					relativeToOBB.X > farPlaneWidth2
					or relativeToOBB.X < -farPlaneWidth2
					or relativeToOBB.Y > farPlaneHeight2
					or relativeToOBB.Y < -farPlaneHeight2
					or relativeToOBB.Z > distance2
					or relativeToOBB.Z < -distance2
				then
					continue
				end

				-- Cut out voxel if it lies outside a frustum plane
				local lookToVoxel = voxelNearestPoint - cameraPos
				if
					rightNormal:Dot(lookToVoxel) < 0
					or leftNormal:Dot(lookToVoxel) > 0
					or topNormal:Dot(lookToVoxel) < 0
					or bottomNormal:Dot(lookToVoxel) > 0
				then
					continue
				end

				-- self:_debugDrawVoxel(voxelKey)

				for _, object in voxel do
					callback(object)
				end
			end
		end
	end
end

function VectorMap:ClearAll()
	self._voxels = {}
end

return VectorMap
