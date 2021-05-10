--- Octree implementation
-- @classmod Octree

-- Original by Quenty, Optimized by howmanysmall

local OctreeNode = require(script.OctreeNode)
local OctreeRegionUtils = require(script.OctreeRegionUtils)

local EPSILON = 1e-9
local SQRT_3_OVER_2 = math.sqrt(3) / 2
local SUB_REGION_POSITION_OFFSET = {
	{0.25, 0.25, -0.25};
	{-0.25, 0.25, -0.25};
	{0.25, 0.25, 0.25};
	{-0.25, 0.25, 0.25};
	{0.25, -0.25, -0.25};
	{-0.25, -0.25, -0.25};
	{0.25, -0.25, 0.25};
	{-0.25, -0.25, 0.25};
}

local Octree = {ClassName = "Octree"}
Octree.__index = Octree

local OctreeNode_new = OctreeNode.new
local OctreeRegionUtils_GetNeighborsWithinRadius = OctreeRegionUtils.GetNeighborsWithinRadius

function Octree.new()
	return setmetatable({
		MaxDepth = 4;
		MaxRegionSize = table.create(3, 512);
		RegionHashMap = {};
	}, Octree)
end

function Octree:ClearNodes()
	self.MaxDepth = 4
	self.MaxRegionSize = table.create(3, 512)
	table.clear(self.RegionHashMap)
end

function Octree:GetAllNodes()
	local Options = {}
	local Length = 0

	for _, RegionList in next, self.RegionHashMap do
		for _, Region in ipairs(RegionList) do
			for Node in next, Region.Nodes do
				Length += 1
				Options[Length] = Node
			end
		end
	end

	return Options
end

function Octree:CreateNode(Position: Vector3, Object)
	if typeof(Position) ~= "Vector3" then
		error("Bad position value")
	end

	if not Object then
		error("Bad object value.")
	end

	local Node = OctreeNode_new(self, Object)
	Node:SetPosition(Position)
	return Node
end

function Octree:RadiusSearch(Position: Vector3, Radius: number)
	if typeof(Position) ~= "Vector3" then
		error("Bad position value")
	end

	if type(Radius) ~= "number" then
		error("Bad radius value")
	end

	local PositionX, PositionY, PositionZ = Position.X, Position.Y, Position.Z
	local ObjectsFound = {}
	local NodeDistances2 = {}
	local ObjectsLength = 0
	local DistancesLength = 0

	local Diameter = self.MaxRegionSize[1]
	local SearchRadius = Radius + SQRT_3_OVER_2 * Diameter
	local SearchRadiusSquared = SearchRadius * SearchRadius + EPSILON

	for _, RegionList in next, self.RegionHashMap do
		for _, Region in ipairs(RegionList) do
			local RegionPosition = Region.Position
			local RegionPositionX = RegionPosition[1]
			local RegionPositionY = RegionPosition[2]
			local RegionPositionZ = RegionPosition[3]

			local OffsetX, OffsetY, OffsetZ = PositionX - RegionPositionX, PositionY - RegionPositionY, PositionZ - RegionPositionZ
			local Distance2 = OffsetX * OffsetX + OffsetY * OffsetY + OffsetZ * OffsetZ

			if Distance2 <= SearchRadiusSquared then
				ObjectsLength, DistancesLength = OctreeRegionUtils_GetNeighborsWithinRadius(Region, Radius, PositionX, PositionY, PositionZ, ObjectsFound, NodeDistances2, self.MaxDepth, ObjectsLength, DistancesLength)
			end
		end
	end

	return ObjectsFound, NodeDistances2
end

local function NearestNeighborSort(A, B)
	return A.Distance2 < B.Distance2
end

function Octree:KNearestNeighborsSearch(Position: Vector3, K: number, Radius: number)
	if typeof(Position) ~= "Vector3" then
		error("Bad position value")
	end

	if type(Radius) ~= "number" then
		error("Bad radius value")
	end

	local PositionX, PositionY, PositionZ = Position.X, Position.Y, Position.Z
	local Objects = {}
	local NodeDistances2 = {}
	local ObjectsLength = 0
	local DistancesLength = 0

	local Diameter = self.MaxRegionSize[1]
	local SearchRadius = Radius + SQRT_3_OVER_2 * Diameter
	local SearchRadiusSquared = SearchRadius * SearchRadius + EPSILON

	for _, RegionList in next, self.RegionHashMap do
		for _, Region in ipairs(RegionList) do
			local RegionPosition = Region.Position
			local RegionPositionX = RegionPosition[1]
			local RegionPositionY = RegionPosition[2]
			local RegionPositionZ = RegionPosition[3]

			local OffsetX, OffsetY, OffsetZ = PositionX - RegionPositionX, PositionY - RegionPositionY, PositionZ - RegionPositionZ
			local Distance2 = OffsetX * OffsetX + OffsetY * OffsetY + OffsetZ * OffsetZ

			if Distance2 <= SearchRadiusSquared then
				ObjectsLength, DistancesLength = OctreeRegionUtils_GetNeighborsWithinRadius(Region, Radius, PositionX, PositionY, PositionZ, Objects, NodeDistances2, self.MaxDepth, ObjectsLength, DistancesLength)
			end
		end
	end

	local Sortable = table.create(DistancesLength)
	for Index, Distance2 in ipairs(NodeDistances2) do
		Sortable[Index] = {
			Distance2 = Distance2;
			Index = Index;
		}
	end

	table.sort(Sortable, NearestNeighborSort)

	local ArrayLength = math.min(DistancesLength, K)
	local KNearest = table.create(ArrayLength)
	local KNearestDistance2 = table.create(ArrayLength)
	for Index = 1, ArrayLength do
		local Sorted = Sortable[Index]
		KNearestDistance2[Index] = Sorted.Distance2
		KNearest[Index] = Objects[Sorted.Index]
	end

	return KNearest, KNearestDistance2
end

local function GetOrCreateRegion(self, PositionX: number, PositionY: number, PositionZ: number)
	local RegionHashMap = self.RegionHashMap
	local MaxRegionSize = self.MaxRegionSize
	local X, Y, Z = MaxRegionSize[1], MaxRegionSize[2], MaxRegionSize[3]
	local CX, CY, CZ = math.floor(PositionX / X + 0.5), math.floor(PositionY / Y + 0.5), math.floor(PositionZ / Z + 0.5)
	local Hash = CX * 73856093 + CY * 19351301 + CZ * 83492791

	local RegionList = RegionHashMap[Hash]
	if not RegionList then
		RegionList = {}
		RegionHashMap[Hash] = RegionList
	end

	local RegionPositionX, RegionPositionY, RegionPositionZ = X * CX, Y * CY, Z * CZ
	for _, Region in ipairs(RegionList) do
		local Position = Region.Position
		if Position[1] == RegionPositionX and Position[2] == RegionPositionY and Position[3] == RegionPositionZ then
			return Region
		end
	end

	local HalfSizeX, HalfSizeY, HalfSizeZ = X / 2, Y / 2, Z / 2

	local LowerBoundsArray = {RegionPositionX - HalfSizeX, RegionPositionY - HalfSizeY, RegionPositionZ - HalfSizeZ}
	local PositionArray = {RegionPositionX, RegionPositionY, RegionPositionZ}
	local SizeArray = {X, Y, Z}
	local UpperBoundsArray = {RegionPositionX + HalfSizeX, RegionPositionY + HalfSizeY, RegionPositionZ + HalfSizeZ}

	local Region = {
		Depth = 1;
		LowerBounds = LowerBoundsArray;
		NodeCount = 0;
		Nodes = {}; -- [node] = true (contains subchild nodes too)
		Parent = nil;
		ParentIndex = nil;
		Position = PositionArray;
		Size = SizeArray; -- { sx, sy, sz }
		SubRegions = {};
		UpperBounds = UpperBoundsArray;
	}

	table.insert(RegionList, Region)
	return Region
end

function Octree:GetOrCreateLowestSubRegion(PositionX: number, PositionY: number, PositionZ: number)
	local Region = GetOrCreateRegion(self, PositionX, PositionY, PositionZ)
	local MaxDepth = self.MaxDepth
	local Current = Region
	for _ = Region.Depth, MaxDepth do
		local CurrentPosition = Current.Position
		local Index = PositionX > CurrentPosition[1] and 1 or 2
		if PositionY <= CurrentPosition[2] then
			Index += 4
		end

		if PositionZ >= CurrentPosition[3] then
			Index += 2
		end

		local SubRegions = Current.SubRegions
		local Next = SubRegions[Index]

		-- construct
		if not Next then
			local Size = Current.Size
			local Multiplier = SUB_REGION_POSITION_OFFSET[Index]

			local X, Y, Z = Size[1], Size[2], Size[3]
			local CurrentPositionX = CurrentPosition[1] + Multiplier[1] * X
			local CurrentPositionY = CurrentPosition[2] + Multiplier[2] * Y
			local CurrentPositionZ = CurrentPosition[3] + Multiplier[3] * Z
			local SizeX, SizeY, SizeZ = X / 2, Y / 2, Z / 2

			local HalfSizeX, HalfSizeY, HalfSizeZ = SizeX / 2, SizeY / 2, SizeZ / 2

			local LowerBoundsArray = {CurrentPositionX - HalfSizeX, CurrentPositionY - HalfSizeY, CurrentPositionZ - HalfSizeZ}
			local PositionArray = {CurrentPositionX, CurrentPositionY, CurrentPositionZ}
			local SizeArray = {SizeX, SizeY, SizeZ}
			local UpperBoundsArray = {CurrentPositionX + HalfSizeX, CurrentPositionY + HalfSizeY, CurrentPositionZ + HalfSizeZ}

			Next = {
				Depth = Current and (Current.Depth + 1) or 1;
				LowerBounds = LowerBoundsArray;
				NodeCount = 0;
				Nodes = {}; -- [node] = true (contains subchild nodes too)
				Parent = Current;
				ParentIndex = Index;
				Position = PositionArray;
				Size = SizeArray; -- { sx, sy, sz }
				SubRegions = {};
				UpperBounds = UpperBoundsArray;
			}

			-- Next = OctreeRegionUtils.CreateSubRegion(Current, Index)
			SubRegions[Index] = Next
		end

		-- iterate
		Current = Next
	end

	return Current
end

return Octree