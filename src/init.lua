--[=[

WindShake- High performance wind effect for leaves and foliage
by: boatbomber, CloneTrooper1019

Docs: https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806/1

--]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Settings = require(script.Settings)
local VectorMap = require(script.VectorMap)

local COLLECTION_TAG = "WindShake" -- The CollectionService tag to be watched and mounted automatically

-- Use the script's attributes as the default settings.
-- The table provided is a fallback if the attributes
-- are undefined or using the wrong value types.

local DEFAULT_SETTINGS = Settings.new(script, {
	WindDirection = Vector3.new(0.5, 0, 0.5),
	WindSpeed = 20,
	WindPower = 0.5,
})

-----------------------------------------------------------------------------------------------------------------

local ObjectShakeAddedEvent = Instance.new("BindableEvent")
local ObjectShakeRemovedEvent = Instance.new("BindableEvent")
local ObjectShakeUpdatedEvent = Instance.new("BindableEvent")
local PausedEvent = Instance.new("BindableEvent")
local ResumedEvent = Instance.new("BindableEvent")

local WindShake = {
	RenderDistance = 150,
	MaxRefreshRate = 1 / 60,

	ObjectMetadata = {},
	VectorMap = VectorMap.new(),

	Handled = 0,
	Active = 0,

	_partList = table.create(500),
	_cframeList = table.create(500),

	ObjectShakeAdded = ObjectShakeAddedEvent.Event,
	ObjectShakeRemoved = ObjectShakeRemovedEvent.Event,
	ObjectShakeUpdated = ObjectShakeUpdatedEvent.Event,
	Paused = PausedEvent.Event,
	Resumed = ResumedEvent.Event,
}

export type WindShakeSettings = {
	WindDirection: Vector3?,
	WindSpeed: number?,
	WindPower: number?,
}

function WindShake:Connect(funcName: string, event: RBXScriptSignal): RBXScriptConnection
	local callback = self[funcName]
	assert(typeof(callback) == "function", "Unknown function: " .. funcName)

	return event:Connect(function(...)
		return callback(self, ...)
	end)
end

function WindShake:AddObjectShake(object: BasePart | Bone, settingsTable: WindShakeSettings?)
	if typeof(object) ~= "Instance" then
		return
	end

	if not (object:IsA("BasePart") or object:IsA("Bone")) then
		return
	end

	local metadata = self.ObjectMetadata

	if metadata[object] then
		return
	else
		self.Handled += 1
	end

	metadata[object] = {
		ChunkKey = self.VectorMap:AddObject(if object:IsA("Bone") then object.WorldPosition else object.Position, object),
		Settings = Settings.new(object, DEFAULT_SETTINGS),

		Seed = math.random(5000) * 0.32,
		Origin = if object:IsA("Bone") then object.WorldCFrame else object.CFrame,
		LastUpdate = os.clock(),
	}

	if settingsTable then
		self:UpdateObjectSettings(object, settingsTable)
	end

	ObjectShakeAddedEvent:Fire(object)
end

function WindShake:RemoveObjectShake(object: BasePart | Bone)
	if typeof(object) ~= "Instance" then
		return
	end

	local metadata = self.ObjectMetadata
	local objMeta = metadata[object]

	if objMeta then
		self.Handled -= 1
		metadata[object] = nil
		objMeta.Settings:Destroy()
		self.VectorMap:RemoveObject(objMeta.ChunkKey, object)

		if object:IsA("BasePart") then
			object.CFrame = objMeta.Origin
		elseif object:IsA("Bone") then
			object.WorldCFrame = objMeta.Origin
		end
	end

	ObjectShakeRemovedEvent:Fire(object)
end

function WindShake:Update(deltaTime: number)
	debug.profilebegin("WindShake")

	local active = 0

	debug.profilebegin("Update")

	local now = os.clock()
	local slowerDeltaTime = deltaTime * 3
	local step = math.min(1, deltaTime * 5)

	-- Reuse tables to avoid garbage collection
	local i = 0
	local partList = self._partList
	local cframeList = self._cframeList
	table.clear(partList)
	table.clear(cframeList)

	-- Cache hot values
	local objectMetadata = self.ObjectMetadata
	local camera = workspace.CurrentCamera
	local cameraPos = camera.CFrame.Position
	local renderDistance = self.RenderDistance
	local maxRefreshRate = self.MaxRefreshRate

	-- Update objects in view at their respective refresh rates
	self.VectorMap:ForEachObjectInView(camera, renderDistance, function(className: string, object: BasePart | Bone)
		local objMeta = objectMetadata[object]
		local lastUpdate = objMeta.LastUpdate or 0
		local isBone = className == "Bone"

		-- Determine if the object refresh rate
		local objectCFrame = if isBone then (object :: Bone).WorldCFrame else object.CFrame
		local distanceAlpha = ((cameraPos - objectCFrame.Position).Magnitude / renderDistance)
		local distanceAlphaSq = distanceAlpha * distanceAlpha
		local jitter = (1 / math.random(60, 120))
		local refreshRate = (slowerDeltaTime * distanceAlphaSq) + maxRefreshRate

		if (now - lastUpdate) + jitter <= refreshRate then
			-- It is not yet time to update
			return
		end

		objMeta.LastUpdate = now
		active += 1

		local objSettings = objMeta.Settings
		local seed = objMeta.Seed
		local amp = objSettings.WindPower * 0.2
		local lowAmp = amp / 3
		local freq = now * (objSettings.WindSpeed * 0.08)
		local animValue = (math.noise(freq, 0, seed) + 0.4) * amp

		local origin = objMeta.Origin * objSettings.PivotOffset

		local windDirection = objSettings.WindDirection.Unit
		local localWindDirection = origin:VectorToObjectSpace(windDirection)

		if isBone then
			(object :: Bone).Transform = (
				CFrame.fromAxisAngle(
					localWindDirection:Cross(Vector3.yAxis),
					-animValue
				)
				* CFrame.Angles(
					math.noise(seed, 0, freq) * lowAmp,
					math.noise(seed, freq, 0) * lowAmp,
					math.noise(freq, seed, 0) * lowAmp
				)
			) + (localWindDirection * animValue)
		else
			local goalCFrame = (
				origin
				* CFrame.fromAxisAngle(
					localWindDirection:Cross(Vector3.yAxis),
					-animValue
				)
				* CFrame.Angles(
					math.noise(seed, 0, freq) * lowAmp,
					math.noise(seed, freq, 0) * lowAmp,
					math.noise(freq, seed, 0) * lowAmp
				)
				* objSettings.PivotOffsetInverse
			) + (windDirection * animValue)

			local lerpedCFrame = objectCFrame:Lerp(
				goalCFrame,
				math.clamp(step + distanceAlphaSq, 0.1, 0.9)
			)

			i += 1
			partList[i] = object
			cframeList[i] = lerpedCFrame
		end
	end)

	self.Active = active

	debug.profileend()

	workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)

	debug.profileend()
end

function WindShake:Pause()
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
		self.UpdateConnection = nil
	end

	self.Active = 0
	self.Running = false

	PausedEvent:Fire()
end

function WindShake:Resume()
	if self.Running then
		return
	else
		self.Running = true
	end

	-- Connect updater
	self.UpdateConnection = self:Connect("Update", RunService.Heartbeat)

	ResumedEvent:Fire()
end

function WindShake:Init()
	if self.Initialized then
		return
	end

	-- Define attributes if they're undefined.
	local power = script:GetAttribute("WindPower")
	local speed = script:GetAttribute("WindSpeed")
	local direction = script:GetAttribute("WindDirection")

	if typeof(power) ~= "number" then
		script:SetAttribute("WindPower", DEFAULT_SETTINGS.WindPower)
	end

	if typeof(speed) ~= "number" then
		script:SetAttribute("WindSpeed", DEFAULT_SETTINGS.WindSpeed)
	end

	if typeof(direction) ~= "Vector3" then
		script:SetAttribute("WindDirection", DEFAULT_SETTINGS.WindDirection)
	end

	-- Clear any old stuff.
	self:Cleanup()
	self.Initialized = true

	-- Wire up tag listeners.
	local windShakeAdded = CollectionService:GetInstanceAddedSignal(COLLECTION_TAG)
	self.AddedConnection = self:Connect("AddObjectShake", windShakeAdded)

	local windShakeRemoved = CollectionService:GetInstanceRemovedSignal(COLLECTION_TAG)
	self.RemovedConnection = self:Connect("RemoveObjectShake", windShakeRemoved)

	for _, object in CollectionService:GetTagged(COLLECTION_TAG) do
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

	table.clear(self.ObjectMetadata)
	self.VectorMap:ClearAll()

	self.Handled = 0
	self.Active = 0
	self.Initialized = false
end

function WindShake:UpdateObjectSettings(object: Instance, settingsTable: WindShakeSettings)
	if typeof(object) ~= "Instance" then
		return
	end

	if typeof(settingsTable) ~= "table" then
		return
	end

	if not self.ObjectMetadata[object] and (object ~= script) then
		return
	end

	for key, value in settingsTable do
		object:SetAttribute(key, value)
	end

	ObjectShakeUpdatedEvent:Fire(object)
end

function WindShake:UpdateAllObjectSettings(settingsTable: WindShakeSettings)
	if typeof(settingsTable) ~= "table" then
		return
	end

	for obj, _objMeta in self.ObjectMetadata do
		for key, value in settingsTable do
			obj:SetAttribute(key, value)
		end
		ObjectShakeUpdatedEvent:Fire(obj)
	end
end

function WindShake:SetDefaultSettings(settingsTable: WindShakeSettings)
	self:UpdateObjectSettings(script, settingsTable)
end

return WindShake
