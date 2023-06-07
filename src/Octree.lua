--!strict

export type Octree<T> = {
	ClearAllNodes: (self: Octree<T>) -> (),
	GetAllNodes: (self: Octree<T>) -> { Node<T> },
	ForEachNode: (self: Octree<T>) -> () -> Node<T>?,
	FindFirstNode: (self: Octree<T>, object: T) -> Node<T>?,
	CountNodes: (self: Octree<T>) -> number,
	CreateNode: (self: Octree<T>, position: Vector3, object: T) -> Node<T>,
	RemoveNode: (self: Octree<T>, node: Node<T>) -> (),
	ChangeNodePosition: (self: Octree<T>, node: Node<T>, position: Vector3) -> (),
	SearchRadius: (self: Octree<T>, position: Vector3, radius: number) -> { Node<T> },
	SearchRadiusForObjects: (self: Octree<T>, position: Vector3, radius: number) -> { T },
	ForEachInRadius: (self: Octree<T>, position: Vector3, radius: number) -> () -> Node<T>?,
	GetNearest: (self: Octree<T>, position: Vector3, radius: number, maxNodes: number?) -> { Node<T> },
}

type OctreeInternal<T> = Octree<T> & {
	Size: number,
	Regions: { Region<T> },
	_getRegion: (self: OctreeInternal<T>, maxLevel: number, position: Vector3) -> Region<T>,
}

type Region<T> = {
	Center: Vector3,
	Size: number,
	Radius: number,
	Regions: { Region<T> },
	Parent: Region<T>?,
	Level: number,
	Nodes: { Node<T> }?,
}

type Node<T> = {
	Position: Vector3,
	Object: T,
}

type NodeInternal<T> = Node<T> & {
	Region: Region<T>?,
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

local function CountNodesInRegion<T>(region: Region<T>)
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

local function GetTopRegion<T>(octree, position: Vector3, create: boolean): Region<T>
	local size = octree.Size
	local origin = Vector3.new(RoundTo(position.X, size), RoundTo(position.Y, size), RoundTo(position.Z, size))
	local region = octree.Regions[origin]
	if not region and create then
		region = {
			Regions = {},
			Level = 1,
			Size = size,
			Radius = math.sqrt(size * size + size * size + size * size),
			Center = origin,
		}
		table.freeze(region)
		octree.Regions[origin] = region
	end
	return region
end

local function GetRegionsInRadius<T>(octree, position: Vector3, radius: number): { Region<T> }
	local regionsFound = {}
	local function ScanRegions(regions: { Region<T> })
		-- Find regions that have overlapping radius values
		for _, region in ipairs(regions) do
			local distance = (position - region.Center).Magnitude
			if distance < (radius + region.Radius) then
				if region.Nodes then
					table.insert(regionsFound, region)
				else
					ScanRegions(region.Regions)
				end
			end
		end
	end
	local startRegions = {}
	local size = octree.Size
	local maxOffset = math.ceil(radius / size)
	if radius < octree.Size then
		-- Find all surrounding regions in a 3x3 cube:
		for i = 0, 26 do
			-- Get surrounding regions:
			local x = i % 3 - 1
			local y = math.floor(i / 9) - 1
			local z = math.floor(i / 3) % 3 - 1
			local offset = Vector3.new(x * radius, y * radius, z * radius)
			local startRegion = GetTopRegion(octree, position + offset, false)
			if startRegion and not startRegions[startRegion] then
				startRegions[startRegion] = true
				ScanRegions(startRegion.Regions)
			end
		end
	elseif maxOffset <= 3 then
		-- Find all surrounding regions:
		for x = -maxOffset, maxOffset do
			for y = -maxOffset, maxOffset do
				for z = -maxOffset, maxOffset do
					local offset = Vector3.new(x * size, y * size, z * size)
					local startRegion = GetTopRegion(octree, position + offset, false)
					if startRegion and not startRegions[startRegion] then
						startRegions[startRegion] = true
						ScanRegions(startRegion.Regions)
					end
				end
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

local function CreateOctree<T>(topRegionSize: number?): Octree<T>
	local self = (setmetatable({}, Octree) :: unknown) :: OctreeInternal<T>
	self.Size = if topRegionSize then topRegionSize else DEFAULT_TOP_REGION_SIZE
	self.Regions = {} :: { Region<T> }
	return self
end

function Octree:ClearAllNodes()
	table.clear(self.Regions)
end

function Octree:GetAllNodes<T>(): { Node<T> }
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

function Octree:ForEachNode<T>(): () -> Node<T>?
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
	return coroutine.wrap(GetNodes)
end

function Octree:FindFirstNode<T>(object: T): Node<T>?
	for node: Node<T> in self:ForEachNode() do
		if node.Object == object then
			return node
		end
	end
	return nil
end

function Octree:CountNodes(): number
	return #self:GetAllNodes()
end

function Octree:CreateNode<T>(position: Vector3, object: T): Node<T>
	local region = (self :: OctreeInternal<T>):_getRegion(MAX_SUB_REGIONS, position)
	local node: Node<T> = {
		Region = region,
		Position = position,
		Object = object,
	}
	if region.Nodes then
		table.insert(region.Nodes, node)
	else
		error("region does not contain nodes array")
	end
	return node
end

function Octree:CreateNodeFromObject(object: BasePart | Attachment)
	return self:CreateNode(object.Position, object)
end

function Octree:RemoveNode<T>(node: NodeInternal<T>)
	if not node.Region then
		return
	end
	local nodes = (node.Region :: Region<T>).Nodes :: { Node<T> }
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

function Octree:ChangeNodePosition<T>(node: NodeInternal<T>, position: Vector3)
	node.Position = position
	local newRegion = self:_getRegion(MAX_SUB_REGIONS, position)
	if newRegion == node.Region then
		return
	end
	table.insert(newRegion.Nodes, node)
	self:RemoveNode(node)
	node.Region = newRegion
end

function Octree:SearchRadius<T>(position: Vector3, radius: number): { Node<T> }
	local nodes = {}
	local regions = GetRegionsInRadius(self, position, radius)
	for _, region in ipairs(regions) do
		if region.Nodes ~= nil then
			for _, node: Node<T> in ipairs(region.Nodes) do
				if (node.Position - position).Magnitude < radius then
					table.insert(nodes, node)
				end
			end
		end
	end
	return nodes
end

function Octree:SearchRadiusForObjects<T>(position: Vector3, radius: number): { T }
	local nodes = {}
	local regions = GetRegionsInRadius(self, position, radius)
	for _, region in ipairs(regions) do
		if region.Nodes ~= nil then
			for _, node: Node<T> in ipairs(region.Nodes) do
				if (node.Position - position).Magnitude < radius then
					table.insert(nodes, node.Object)
				end
			end
		end
	end
	return nodes
end

function Octree:ForEachInRadius<T>(position: Vector3, radius: number): () -> Node<T>?
	local regions = GetRegionsInRadius(self, position, radius)
	return coroutine.wrap(function()
		for _, region: Region<T> in ipairs(regions) do
			if region.Nodes ~= nil then
				for _, node: Node<T> in ipairs(region.Nodes) do
					if (node.Position - position).Magnitude < radius then
						coroutine.yield(node)
					end
				end
			end
		end
	end)
end

function Octree:GetNearest<T>(position: Vector3, radius: number, maxNodes: number?): { Node<T> }
	local nodes = self:SearchRadius(position, radius)
	table.sort(nodes, function(n0: Node<T>, n1: Node<T>)
		local d0 = (n0.Position - position).Magnitude
		local d1 = (n1.Position - position).Magnitude
		return d0 < d1
	end)
	if maxNodes ~= nil and #nodes > maxNodes then
		return table.move(nodes, 1, maxNodes, 1, table.create(maxNodes))
	end
	return nodes
end

function Octree:_getRegion<T>(maxLevel: number, position: Vector3): Region<T>
	local function GetRegion(regionParent: Region<T>?, regions: { Region<T> }, level: number): Region<T>
		local region: Region<T>? = nil
		-- Find region that contains the position:
		for _, r in regions do
			if IsPointInBox(position, r.Center, r.Size) then
				region = r
				break
			end
		end
		if not region then
			-- Create new region:
			local size = (self :: OctreeInternal<T>).Size / (2 ^ (level - 1))
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
			local newRegion: Region<T> = {
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
			return region :: Region<T>
		else
			-- Find the sub-region:
			return GetRegion(region :: Region<T>, (region :: Region<T>).Regions, level + 1)
		end
	end
	local startRegion = GetTopRegion(self, position, true)
	return GetRegion(startRegion, startRegion.Regions, 2)
end

Octree.__iter = Octree.ForEachNode

return {
	new = CreateOctree,
}
