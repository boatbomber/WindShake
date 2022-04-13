--- Basic node interacting with the octree
-- @classmod OctreeNode

local OctreeNode = {ClassName = "OctreeNode"}
OctreeNode.__index = OctreeNode

function OctreeNode.new(Octree, Object)
	return setmetatable({
		Octree = Octree or error("No octree");
		Object = Object or error("No object");

		CurrentLowestRegion = nil;
		Position = nil;
		PositionX = nil;
		PositionY = nil;
		PositionZ = nil;
	}, OctreeNode)
end

function OctreeNode:KNearestNeighborsSearch(K: number, Radius: number)
	return self.Octree:KNearestNeighborsSearch(self.Position, K, Radius)
end

function OctreeNode:GetObject()
	warn("OctreeNode:GetObject is deprecated.")
	return self.Object
end

function OctreeNode:RadiusSearch(Radius: number)
	return self.Octree:RadiusSearch(self.Position, Radius)
end

function OctreeNode:GetPosition()
	warn("OctreeNode:GetPosition is deprecated.")
	return self.Position
end

function OctreeNode:GetRawPosition(): (number, number, number)
	return self.PositionX, self.PositionY, self.PositionZ
end

function OctreeNode:SetPosition(Position: Vector3)
	if self.Position == Position then
		return
	end

	local PositionX, PositionY, PositionZ = Position.X, Position.Y, Position.Z

	self.PositionX = PositionX
	self.PositionY = PositionY
	self.PositionZ = PositionZ
	self.Position = Position

	if self.CurrentLowestRegion then
		local Region = self.CurrentLowestRegion
		local LowerBounds = Region.LowerBounds
		local UpperBounds = Region.UpperBounds
		if PositionX >= LowerBounds[1] and PositionX <= UpperBounds[1] and PositionY >= LowerBounds[2] and PositionY <= UpperBounds[2] and PositionZ >= LowerBounds[3] and PositionZ <= UpperBounds[3] then
			return
		end
	end

	local NewLowestRegion = self.Octree:GetOrCreateLowestSubRegion(PositionX, PositionY, PositionZ)
	if self.CurrentLowestRegion then
		-- OctreeRegionUtils_MoveNode(self.CurrentLowestRegion, NewLowestRegion, self)
		local FromLowest = self.CurrentLowestRegion
		if FromLowest.Depth ~= NewLowestRegion.Depth then
			error("fromLowest.Depth ~= toLowest.Depth")
		end

		if FromLowest == NewLowestRegion then
			error("fromLowest == toLowest")
		end

		local CurrentFrom = FromLowest
		local CurrentTo = NewLowestRegion

		while CurrentFrom ~= CurrentTo do
			-- remove from current
			local CurrentFromNodes = CurrentFrom.Nodes
			if not CurrentFromNodes[self] then
				error("CurrentFrom.Nodes doesn't have a node here.")
			end

			local NodeCount = CurrentFrom.NodeCount
			if NodeCount <= 0 then
				error("NodeCount is <= 0.")
			end

			NodeCount -= 1
			CurrentFromNodes[self] = nil
			CurrentFrom.NodeCount = NodeCount

			-- remove subregion!
			local ParentIndex = CurrentFrom.ParentIndex
			if NodeCount <= 0 and ParentIndex then
				local Parent = CurrentFrom.Parent
				if not Parent then
					error("CurrentFrom.Parent doesn't exist.")
				end

				local SubRegions = Parent.SubRegions
				if SubRegions[ParentIndex] ~= CurrentFrom then
					error("Failed equality check.")
				end

				SubRegions[ParentIndex] = nil
			end

			local CurrentToNodes = CurrentTo.Nodes
			if CurrentToNodes[self] then
				error("CurrentTo.Nodes already has a node here.")
			end

			CurrentToNodes[self] = self
			CurrentTo.NodeCount += 1

			CurrentFrom = CurrentFrom.Parent
			CurrentTo = CurrentTo.Parent
		end
	else
		local Current = NewLowestRegion
		while Current do
			local CurrentNodes = Current.Nodes
			if not CurrentNodes[self] then
				CurrentNodes[self] = self
				Current.NodeCount += 1
			end

			Current = Current.Parent
		end
	end

	self.CurrentLowestRegion = NewLowestRegion
end

function OctreeNode:Destroy()
	local LowestSubregion = self.CurrentLowestRegion
	if LowestSubregion then
		local Current = LowestSubregion

		while Current do
			local Nodes = Current.Nodes
			if not Nodes[self] then
				error("CurrentFrom.Nodes doesn't have a node here.")
			end

			local NodeCount = Current.NodeCount
			if NodeCount <= 0 then
				error("NodeCount is <= 0.")
			end

			NodeCount -= 1
			Nodes[self] = nil
			Current.NodeCount = NodeCount

			-- remove subregion!
			local Parent = Current.Parent
			local ParentIndex = Current.ParentIndex
			if NodeCount <= 0 and ParentIndex then
				if not Parent then
					error("Current.Parent doesn't exist.")
				end

				local SubRegions = Parent.SubRegions
				if SubRegions[ParentIndex] ~= Current then
					error("Failed equality check.")
				end

				SubRegions[ParentIndex] = nil
			end

			Current = Parent
		end
	end
end

return OctreeNode