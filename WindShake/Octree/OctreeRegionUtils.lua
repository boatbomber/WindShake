--- Octree implementation
-- @module OctreeRegionUtils

local EPSILON = 1e-6
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

local OctreeRegionUtils = {}

-- See basic algorithm:
-- luacheck: push ignore
-- https://github.com/PointCloudLibrary/pcl/blob/29f192af57a3e7bdde6ff490669b211d8148378f/octree/include/pcl/octree/impl/octree_search.hpp#L309
-- luacheck: pop
local function GetNeighborsWithinRadius(Region, Radius, PositionX, PositionY, PositionZ, ObjectsFound, NodeDistances2, MaxDepth, ObjectsLength, DistancesLength)
	if not MaxDepth then
		error("Missing MaxDepth.")
	end

	local SearchRadius = Radius + SQRT_3_OVER_2 * (Region.Size[1] / 2)
	local SearchRadiusSquared = SearchRadius * SearchRadius + EPSILON
	local RadiusSquared = Radius * Radius

	-- for each child
	for _, ChildRegion in next, Region.SubRegions do
		local ChildPosition = ChildRegion.Position
		local ChildPositionX = ChildPosition[1]
		local ChildPositionY = ChildPosition[2]
		local ChildPositionZ = ChildPosition[3]

		local OffsetX = PositionX - ChildPositionX
		local OffsetY = PositionY - ChildPositionY
		local OffsetZ = PositionZ - ChildPositionZ
		local Distance2 = OffsetX * OffsetX + OffsetY * OffsetY + OffsetZ * OffsetZ

		-- within search radius
		if Distance2 <= SearchRadiusSquared then
			if ChildRegion.Depth == MaxDepth then
				for Node in next, ChildRegion.Nodes do
					local NodePositionX = Node.PositionX
					local NodePositionY = Node.PositionY
					local NodePositionZ = Node.PositionZ

					local NodeOffsetX = NodePositionX - PositionX
					local NodeOffsetY = NodePositionY - PositionY
					local NodeOffsetZ = NodePositionZ - PositionZ
					local NodeDistance2 = NodeOffsetX * NodeOffsetX + NodeOffsetY * NodeOffsetY + NodeOffsetZ * NodeOffsetZ

					if NodeDistance2 <= RadiusSquared then
						ObjectsLength += 1
						DistancesLength += 1
						ObjectsFound[ObjectsLength] = Node.Object
						NodeDistances2[DistancesLength] = NodeDistance2
					end
				end
			else
				ObjectsLength, DistancesLength = GetNeighborsWithinRadius(ChildRegion, Radius, PositionX, PositionY, PositionZ, ObjectsFound, NodeDistances2, MaxDepth, ObjectsLength, DistancesLength)
			end
		end
	end

	return ObjectsLength, DistancesLength
end

OctreeRegionUtils.GetNeighborsWithinRadius = GetNeighborsWithinRadius
return OctreeRegionUtils