type Region = {
	Center: Vector3,
	Size: Vector3,
	Radius: number,
	Regions: { Region },
	Parent: Region?,
	Level: number,
	Nodes: { Node }?,
}

type Node = {
	Region: Region?,
	Position: Vector3,
	Object: any,
}

local MAX_SUB_REGIONS = 4
local DEFAULT_TOP_REGION_SIZE = 512

local function IsPointInBox(point: Vector3, boxCenter: Vector3, boxSize: number)
	local half = boxSize / 2
	return point.X >= boxCenter.X - half
		and point.X <= boxCenter.X + half
		and point.Y >= boxCenter.Y - half
		and point.Y <= boxCenter.Y + half
		and point.Z >= boxCenter.Z - half
		and point.Z <= boxCenter.Z + half
end

local function RoundTo(x: number, mult: number): number
	return math.round(x / mult) * mult
end

local function SwapRemove(tbl, index)
	local n = #tbl
	tbl[index] = tbl[n]
	tbl[n] = nil
end

local function CountNodesInRegion(region: Region)
	local n = 0
	if region.Nodes then
		return #region.Nodes
	else
		for _, subRegion in ipairs(region.Regions) do
			n += CountNodesInRegion(subRegion)
		end
	end
	return n
end

local function GetTopRegion(octree, position: Vector3)
	local size = octree.Size
	local origin = Vector3.new(RoundTo(position.X, size), RoundTo(position.Y, size), RoundTo(position.Z, size))
	-- Unique key to represent the top-level region:
	-- local key = origin.X .. "_" .. origin.Y .. "_" .. origin.Z
	local key = origin -- vectors can now be used as keys
	local region = octree.Regions[key]
	if not region then
		region = {
			Regions = {},
			Level = 1,
			Size = size,
			Radius = math.sqrt(size * size + size * size + size * size),
			Center = origin,
		}
		table.freeze(region)
		octree.Regions[key] = region
	end
	return region
end

local function GetRegionsInRadius(octree, position: Vector3, radius: number)
	local regionsFound = {}
	local function ScanRegions(regions: { Region })
		-- Find regions that have overlapping radius values
		for _, region in ipairs(regions) do
			local distance = (position - region.Center).Magnitude
			if distance < (radius + region.Radius) then
				if region.Nodes then
					-- table.insert(regionsFound, region)
					regionsFound[#regionsFound + 1] = region
				else
					ScanRegions(region.Regions)
				end
			end
		end
	end
	local startRegions = {}
	if radius < octree.Size * 1.5 then
		-- Find all surrounding regions in a 3x3 cube:
		for i = 0, 26 do
			-- Get surrounding regions:
			local x = i % 3 - 1
			local y = math.floor(i / 9) - 1
			local z = math.floor(i / 3) % 3 - 1
			local offset = Vector3.new(x * radius, y * radius, z * radius)
			local startRegion = GetTopRegion(octree, position + offset)
			if not startRegions[startRegion] then
				startRegions[startRegion] = true
				ScanRegions(startRegion.Regions)
			end
		end
	else
		-- If radius is larger than the surrounding regions will detect, then
		-- we need to use a different algorithm to pickup the regions. Ideally,
		-- we won't be querying with huge radius values, but this is here in
		-- cases where that happens. Just scan all top-level regions and check
		-- the distance.
		for _, region in octree.Regions do
			local distance = (position - region.Center).Magnitude
			if distance < (radius + region.Radius) then
				ScanRegions(region.Regions)
			end
		end
	end
	return regionsFound
end

local Octree = {}
Octree.__index = Octree

function Octree.new(topRegionSize: number?)
	local self = setmetatable({}, Octree)
	self.Size = if topRegionSize then topRegionSize else DEFAULT_TOP_REGION_SIZE
	self.Regions = {} :: { Region }

	return self
end

function Octree:ClearAllNodes()
	table.clear(self.Regions)
end

function Octree:GetAllNodes(): { Node }
	local all = {}
	local function GetNodes(regions)
		for _, region in regions do
			local nodes = region.Nodes
			if nodes then
				table.move(nodes, 1, #nodes, #all + 1, all)
			else
				GetNodes(region.Regions)
			end
		end
	end
	GetNodes(self.Regions)
	return all
end

function Octree:ForEachNode(): () -> Node?
	local function GetNodes(regions)
		for _, region in regions or self.Regions do
			local nodes = region.Nodes
			if nodes then
				for _, node in nodes do
					coroutine.yield(node)
				end
			else
				GetNodes(region.Regions)
			end
		end
	end
	local getNextNode = coroutine.wrap(GetNodes)
	return function(): Node?
		return getNextNode()
	end
end

function Octree:FindFirstNode(object: any): Node?
	for node: Node in self:ForEachNode() do
		if node.Object == object then
			return node
		end
	end
	return nil
end

function Octree:CountNodes()
	return #self:GetAllNodes()
end

function Octree:CreateNode(position: Vector3, object: any)
	local region = self:_getRegion(MAX_SUB_REGIONS, position)
	local node: Node = {
		Region = region,
		Position = position,
		Object = object,
	}
	table.insert(region.Nodes, node)
	return node
end

function Octree:CreateNodeFromObject(object: BasePart | Attachment)
	return self:CreateNode(object.Position, object)
end

function Octree:RemoveNode(node: Node)
	if not node.Region then
		return
	end
	local nodes = (node.Region :: Region).Nodes :: { Node }
	local index = table.find(nodes, node)
	if index then
		SwapRemove(nodes, index)
	end
	if #nodes == 0 then
		-- Remove regions without any nodes:
		local region = node.Region
		while region do
			local parent = region.Parent
			if parent then
				local numNodes = CountNodesInRegion(region)
				if numNodes == 0 then
					local regionIndex = table.find(parent.Regions, region)
					if regionIndex then
						SwapRemove(parent.Regions, regionIndex)
					end
				end
			end
			region = parent
		end
	end
	node.Region = nil
end

function Octree:ChangeNodePosition(node: Node, position: Vector3)
	node.Position = position
	local newRegion = self:_getRegion(MAX_SUB_REGIONS, position)
	if newRegion == node.Region then
		return
	end
	self:RemoveNode(node)
	table.insert(newRegion.Nodes, node)
end

function Octree:RadiusSearch(position: Vector3, radius: number)
	local nodes = {}
	local regions = GetRegionsInRadius(self, position, radius)
	for _, region in ipairs(regions) do
		for _, node in ipairs(region.Nodes) do
			if (node.Position - position).Magnitude < radius then
				table.insert(nodes, node)
			end
		end
	end
	return nodes
end

function Octree:RadiusSearchForObjects(position: Vector3, radius: number)
	local objects = {}
	local regions = GetRegionsInRadius(self, position, radius)
	for _, region in ipairs(regions) do
		for _, node in ipairs(region.Nodes) do
			if (node.Position - position).Magnitude < radius then
				table.insert(objects, node.Object)
			end
		end
	end
	return objects
end

function Octree:RadiusSearchForEach(position: Vector3, radius: number)
	local regions = GetRegionsInRadius(self, position, radius)
	local function ForEach()
		for _, region in ipairs(regions) do
			for _, node in ipairs(region.Nodes) do
				if (node.Position - position).Magnitude < radius then
					coroutine.yield(node)
				end
			end
		end
	end
	local getNext = coroutine.wrap(ForEach)
	return function()
		return getNext()
	end
end

function Octree:GetNearest(position: Vector3, radius: number, maxNodes: number?)
	local nodes = self:RadiusSearch(position, radius, maxNodes)
	table.sort(nodes, function(n0: Node, n1: Node)
		local d0 = (n0.Position - position).Magnitude
		local d1 = (n1.Position - position).Magnitude
		return d0 < d1
	end)
	if maxNodes ~= nil and #nodes > maxNodes then
		return table.move(nodes, 1, maxNodes, 1, table.create(maxNodes))
	end
	return nodes
end

function Octree:_getRegion(maxLevel: number, position: Vector3): Region
	local function GetRegion(regionParent: Region?, regions: { Region }, level: number): Region
		local region: Region? = nil
		-- Find region that contains the position:
		for _, r in regions do
			if IsPointInBox(position, r.Center, r.Size) then
				region = r
				break
			end
		end
		if not region then
			-- Create new region:
			local size = self.Size / (2 ^ (level - 1))
			local origin = if regionParent
				then regionParent.Center
				else Vector3.new(RoundTo(position.X, size), RoundTo(position.Y, size), RoundTo(position.Z, size))
			local center = origin
			if regionParent then
				-- Offset position to fit the subregion within the parent region:
				center += Vector3.new(
					if position.X > origin.X then size / 2 else -size / 2,
					if position.Y > origin.Y then size / 2 else -size / 2,
					if position.Z > origin.Z then size / 2 else -size / 2
				)
			end
			local newRegion: Region = {
				Regions = {},
				Level = level,
				Size = size,
				-- Radius represents the spherical radius that contains the entirety of the cube region
				Radius = math.sqrt(size * size + size * size + size * size),
				Center = center,
				Parent = regionParent,
				Nodes = if level == MAX_SUB_REGIONS then {} else nil,
			}
			table.freeze(newRegion)
			table.insert(regions, newRegion)
			region = newRegion
		end
		if level == maxLevel then
			-- We've made it to the bottom-tier region
			return region :: Region
		else
			-- Find the sub-region:
			return GetRegion(region :: Region, (region :: Region).Regions, level + 1)
		end
	end
	local startRegion = GetTopRegion(self, position)
	return GetRegion(startRegion, startRegion.Regions, 2)
end

return Octree
