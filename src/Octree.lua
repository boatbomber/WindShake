--[[
Copyright © 2022 Stephen Leitnick
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the “Software”), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions
of the Software.
THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
]]

--[[
	OCTREE - EARLY RELEASE
	API:

		CONSTRUCTOR:
			Octree.new(size: number)
		METHODS:
			octree:CreateNode(position: Vector3, object: any): Node
			octree:CreateNodeFromObject(object: any): Node
			octree:RemoveNode(node: Node)
			octree:ClearNodes()
			octree:ChangeNodePosition(node: Node, position: Vector3)
			octree:RadiusSearch(position: Vector3, radius: number): {Node}
			octree:RadiusSearchForObjects(position: Vector3, radius: number): {Object}
			octree:GetNearest(position: Vector3, radius: number, maxNodes: number?): {Node}
		NODE TYPE:
			Node = {
				Position: Vector3 [readonly]
				Object: any [readonly]
			}
		EXAMPLE:
			local octree = Octree.new(512)
			local node = octree:CreateNodeFromObject(workspace.Baseplate)
			local nodes = octree:RadiusSearch(characterPosition)
			print(nodes)
]]

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

local function IsPointInBox(point: Vector3, boxCenter: Vector3, boxSize: number)
	local half = boxSize / 2
	return point.X >= boxCenter.X - half
		and point.X <= boxCenter.X + half
		and point.Y >= boxCenter.Y - half
		and point.Y <= boxCenter.Y + half
		and point.Z >= boxCenter.Z - half
		and point.Z <= boxCenter.Z + half
end

local Octree = {}
Octree.__index = Octree

function Octree.new(size: number?)
	local self = setmetatable({}, Octree)
	self.Size = size or 512
	self.Regions = {} :: { Region }
	return self
end

function Octree:ClearNodes()
	self.Regions = {} :: { Region }
end

function Octree:CreateNode(position: Vector3, object: any)
	local region = self:_getRegion(self.Regions, MAX_SUB_REGIONS, position)
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
		local n = #nodes
		nodes[index] = nodes[n]
		nodes[n] = nil
	end
	if #nodes == 0 then
		-- Remove regions without any nodes:
		local region = node.Region
		while region do
			local parent = region.Parent
			if parent then
				local numNodes = self:_countNodesInRegion(region)
				if numNodes == 0 then
					local regionIndex = table.find(parent.Regions, region)
					if regionIndex then
						local regions = parent.Regions
						local n = #regions
						regions[regionIndex] = regions[n]
						regions[n] = nil
					end
				end
			end
			region = parent
		end
	end
	node.Region = nil
end

function Octree:_countNodesInRegion(region: Region): number
	local n = 0
	if region.Nodes then
		return #region.Nodes
	else
		for _, subRegion in region.Regions do
			n += self:_countNodesInRegion(subRegion)
		end
	end
	return n
end

function Octree:ChangeNodePosition(node: Node, position: Vector3)
	node.Position = position
	local newRegion = self:_getRegion(self.Regions, MAX_SUB_REGIONS, position)
	if newRegion == node.Region then
		return
	end
	self:RemoveNode(node)
	table.insert(newRegion.Nodes, node)
end

function Octree:RadiusSearch(position: Vector3, radius: number)
	local nodes = {}
	local regions = self:_getRegionsInRadius(position, radius)
	for _, region in regions do
		for _, node in region.Nodes do
			if (node.Position - position).Magnitude < radius then
				table.insert(nodes, node)
			end
		end
	end
	return nodes
end

function Octree:RadiusSearchForObjects(position: Vector3, radius: number)
	local objects = {}
	local regions = self:_getRegionsInRadius(position, radius)
	for _, region in regions do
		for _, node in region.Nodes do
			if (node.Position - position).Magnitude < radius then
				table.insert(objects, node.Object)
			end
		end
	end
	return objects
end

function Octree:GetNearest(position: Vector3, radius: number, maxNodes: number?)
	local nodes = self:RadiusSearch(position, radius, maxNodes)
	table.sort(nodes)
	if maxNodes ~= nil and #nodes > maxNodes then
		return table.move(nodes, 1, maxNodes, 1, table.create(maxNodes))
	end
	return nodes
end

function Octree:_getRegionsInRadius(position: Vector3, radius: number)
	local regionsFound = {}
	local function ScanRegions(regions: { Region })
		-- Find regions that have overlapping radius values
		for _, region in regions do
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
	if radius < self.Size * 1.5 then
		-- Find all surrounding regions in a 3x3 cube:
		for i = 0, 26 do
			-- Get surrounding regions:
			local x = i % 3 - 1
			local y = math.floor(i / 9) - 1
			local z = math.floor(i / 3) % 3 - 1
			local offset = Vector3.new(x * radius, y * radius, z * radius)
			local startRegion = self:_getTopRegion(position + offset)
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
		for _, region in self.Regions do
			local distance = (position - region.Center).Magnitude
			if distance < (radius + region.Radius) then
				ScanRegions(region.Regions)
			end
		end
	end
	return regionsFound
end

function Octree:_getTopRegion(position: Vector3)
	local size = self.Size
	local origin = Vector3.new(
		math.round(position.X / size) * size,
		math.round(position.Y / size) * size,
		math.round(position.Z / size) * size
	)
	-- Unique key to represent the top-level region:
	local key = origin.X .. "_" .. origin.Y .. "_" .. origin.Z
	local region = self.Regions[key]
	if not region then
		region = {
			Regions = {},
			Level = 1,
			Size = size,
			Radius = math.sqrt(size * size + size * size + size * size),
			Center = origin,
		}
		self.Regions[key] = region
	end
	return region
end

function Octree:_getRegion(regionsStart: { Region }, maxLevel: number, position: Vector3): Region
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
				else Vector3.new(
					math.round(position.X / size) * size,
					math.round(position.Y / size) * size,
					math.round(position.Z / size) * size
				)
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
	local startRegion = self:_getTopRegion(position)
	return GetRegion(startRegion, startRegion.Regions, 2)
end

return Octree
