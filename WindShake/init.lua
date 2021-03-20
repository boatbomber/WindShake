--[=[

WindShake- High performance wind effect for leaves and foliage
by: boatbomber, CloneTrooper1019

Docs: https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806/1

--]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Settings = require(script.Settings)
local Octree = require(script.Octree)

local UPDATE_HZ = 1/30 -- Update the object targets at 30 Hz.

-- Use the script's attributes as the default settings.
-- The table provided is a fallback if the attributes
-- are undefined or using the wrong value types.

local DEFAULT_SETTINGS = Settings.new(script,
{
	Direction = Vector3.new(0.5, 0, 0.5);
	Speed = 20;
	Power = 0.5;
})

-----------------------------------------------------------------------------------------------------------------

local WindShake =
{
	ObjectMetadata = {};
	Octree = Octree.new();

	Handled = 0;
	Active = 0;
}

export type WindShakeSettings =
{
	Direction: Vector3?,
	Speed: number?,
	Power: number?
}

function WindShake:Connect(funcName: string, event: RBXScriptSignal): RBXScriptConnection
	local callback = self[funcName]
	assert(typeof(callback) == "function", "Unknown function: " .. funcName)

	return event:Connect(function (...)
		return callback(self, ...)
	end)
end

function WindShake:AddObjectShake(object: BasePart, settingsTable: WindShakeSettings?)
	if typeof(object) ~= "Instance" then
		return
	end

	if not object:IsA("BasePart") then
		return
	end

	local metadata = self.ObjectMetadata

	if metadata[object] then
		return
	else
		self.Handled += 1
	end

	metadata[object] =
	{
		Node = self.Octree:CreateNode(object.Position, object);
		Settings = Settings.new(object, DEFAULT_SETTINGS);

		Seed = math.random(1000) * 0.1;
		Origin = object.CFrame;
	}

	self:UpdateObjectSettings(object, settingsTable)
end

function WindShake:RemoveObjectShake(object: BasePart)
	if typeof(object) ~= "Instance" then
		return
	end

	local metadata = self.ObjectMetadata
	local objMeta = metadata[object]

	if objMeta then
		metadata[object] = nil
		objMeta.Node:Destroy()

		if object:IsA("BasePart") then
			object.CFrame = objMeta.Origin
		end
	end
end

function WindShake:Update(dt)
	local now = os.clock()
	debug.profilebegin("WindShake")

	local camera = workspace.CurrentCamera
	local cameraCF = camera and camera.CFrame

	local updateObjects = self.Octree:RadiusSearch(cameraCF.Position + (cameraCF.LookVector * 115), 120)
	local activeCount = #updateObjects

	self.Active = activeCount

	if self.Active < 1 then
		return
	end

	local step = math.min(1, dt * 8)
	local cfTable = table.create(activeCount)
	local objectMetadata = self.ObjectMetadata

	for i, object in ipairs(updateObjects) do
		local objMeta = objectMetadata[object]
		local lastComp = objMeta.LastCompute or 0

		local origin = objMeta.Origin
		local current = objMeta.CFrame or origin

		if (now - lastComp) > UPDATE_HZ then
			local objSettings = objMeta.Settings

			local seed = objMeta.Seed
			local amp = math.abs(objSettings.Power * 0.1)

			local freq = now * (objSettings.Speed * 0.08)
			local rot = math.noise(freq, 0, seed) * amp

			objMeta.Target
				= origin * CFrame.Angles(rot, rot, rot)
				+ objSettings.Direction * ((0.5 + math.noise(freq, seed, seed)) * amp)

			objMeta.LastCompute = now
		end

		current = current:Lerp(objMeta.Target, step)
		objMeta.CFrame = current
		cfTable[i] = current
	end

	workspace:BulkMoveTo(updateObjects, cfTable, Enum.BulkMoveMode.FireCFrameChanged)
	debug.profileend()
end

function WindShake:Pause()
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
		self.UpdateConnection = nil
	end

	self.Active = 0
	self.Running = false
end

function WindShake:Resume()
	if self.Running then
		return
	else
		self.Running = true
	end

	-- Connect updater
	self.UpdateConnection = self:Connect("Update", RunService.Heartbeat)
end

function WindShake:Init()
	if self.Initialized then
		return
	else
		self.Initialized = true
	end

	-- Define attributes if they're undefined.
	local power = script:GetAttribute("Power")
	local speed = script:GetAttribute("Speed")
	local direction = script:GetAttribute("Direction")

	if typeof(power) ~= "number" then
		script:SetAttribute("Power", DEFAULT_SETTINGS.Power)
	end

	if typeof(speed) ~= "number" then
		script:SetAttribute("Speed", DEFAULT_SETTINGS.Speed)
	end

	if typeof(direction) ~= "number" then
		script:SetAttribute("Direction", DEFAULT_SETTINGS.Direction)
	end
	
	-- Clear any old stuff.
	self:Cleanup()

	-- Wire up tag listeners.
	local windShakeAdded = CollectionService:GetInstanceAddedSignal("WindShake")
	self.AddedConnection = self:Connect("AddObjectShake", windShakeAdded)

	local windShakeRemoved = CollectionService:GetInstanceRemovedSignal("WindShake")
	self.RemovedConnection = self:Connect("RemoveObjectShake", windShakeRemoved)

	for _,object in pairs(CollectionService:GetTagged("WindShake")) do
		self:AddObjectShake(object)
	end

	-- Automatically start.
	self:Resume()
end

function WindShake:Cleanup()
	if not self.Initialized then
		return
	end

	self:Pause()

	if self.AddedConnection then
		self.AddedConnection:Disconnect()
		self.AddedConnection = nil
	end

	if self.RemovedConnection then
		self.RemovedConnection:Disconnect()
		self.RemovedConnection = nil
	end

	self.Handled = 0
	self.Initialized = false
end

function WindShake:UpdateObjectSettings(object: Instance, settingsTable: WindShakeSettings)
	if typeof(object) ~= "Instance" then
		return
	end

	if typeof(settingsTable) ~= "table" then
		return
	end

	if not self.ObjectMetadata[object] then
		if object ~= script then
			return
		end
	end

	for key, value in pairs(settingsTable) do
		object:SetAttribute(key, value)
	end
end

function WindShake:UpdateAllObjectSettings(settingsTable: WindShakeSettings)
	if typeof(settingsTable) ~= "table" then
		return
	end

	for obj, objMeta in pairs(self.ObjectMetadata) do
		local objSettings = objMeta.Settings

		for key, value in pairs(settingsTable) do
			objSettings[key] = value
		end
	end
end

function WindShake:SetDefaultSettings(settingsTable: WindShakeSettings)
	self:UpdateObjectSettings(script, settingsTable)
end

return WindShake