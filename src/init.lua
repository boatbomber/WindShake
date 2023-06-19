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

local FALLBACK_SETTINGS = {
	WindDirection = Vector3.new(0.5, 0, 0.5),
	WindSpeed = 20,
	WindPower = 0.5,
}

-----------------------------------------------------------------------------------------------------------------

local ObjectShakeAddedEvent = Instance.new("BindableEvent")
local ObjectShakeRemovedEvent = Instance.new("BindableEvent")
local ObjectShakeUpdatedEvent = Instance.new("BindableEvent")
local PausedEvent = Instance.new("BindableEvent")
local ResumedEvent = Instance.new("BindableEvent")

local WindShake = {
	RenderDistance = 150,
	MaxRefreshRate = 1 / 60,
	SharedSettings = Settings.new(script),

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
		ChunkKey = self.VectorMap:AddObject(
			if object:IsA("Bone") then object.WorldPosition else object.Position,
			object
		),
		Settings = Settings.new(object),

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
	local bulkMoveIndex = 0
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
	local sharedSettings = self.SharedSettings
	local sharedWindPower = sharedSettings.WindPower
	local sharedWindSpeed = sharedSettings.WindSpeed
	local sharedWindDirection = sharedSettings.WindDirection

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
		local amp = (objSettings.WindPower or sharedWindPower) * 0.2
		if amp < 1e-5 then
			return
		end

		local freq = now * ((objSettings.WindSpeed or sharedWindSpeed) * 0.08)
		if freq < 1e-5 then
			return
		end

		local seed = objMeta.Seed
		local animValue = (math.noise(freq, 0, seed) + 0.4) * amp
		local lerpAlpha = math.clamp(step + distanceAlphaSq, 0.1, 0.5)
		local lowAmp = amp / 3

		local origin = objMeta.Origin * (objSettings.PivotOffset or CFrame.identity)
		local windDirection = (objSettings.WindDirection or sharedWindDirection)
		local localWindDirection = origin:VectorToObjectSpace(windDirection)

		if isBone then
			local bone: Bone = object :: Bone
			bone.Transform = bone.Transform:Lerp(
				(
					CFrame.fromAxisAngle(localWindDirection:Cross(Vector3.yAxis), -animValue)
					* CFrame.Angles(
						math.noise(seed, 0, freq) * lowAmp,
						math.noise(seed, freq, 0) * lowAmp,
						math.noise(freq, seed, 0) * lowAmp
					)
				) + (localWindDirection * animValue * amp),
				lerpAlpha
			)
		else
			bulkMoveIndex += 1
			partList[bulkMoveIndex] = object
			cframeList[bulkMoveIndex] = objectCFrame:Lerp(
				(
					origin
					* CFrame.fromAxisAngle(localWindDirection:Cross(Vector3.yAxis), -animValue)
					* CFrame.Angles(
						math.noise(seed, 0, freq) * lowAmp,
						math.noise(seed, freq, 0) * lowAmp,
						math.noise(freq, seed, 0) * lowAmp
					)
					* (objSettings.PivotOffsetInverse or CFrame.identity)
				) + (windDirection * animValue * (amp * 2)),
				lerpAlpha
			)
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

function WindShake:Init(config: { MatchWorkspaceWind: boolean? })
	if self.Initialized then
		return
	end

	-- Define attributes if they're undefined.
	local power = script:GetAttribute("WindPower")
	local speed = script:GetAttribute("WindSpeed")
	local direction = script:GetAttribute("WindDirection")

	if typeof(power) ~= "number" then
		script:SetAttribute("WindPower", FALLBACK_SETTINGS.WindPower)
	end

	if typeof(speed) ~= "number" then
		script:SetAttribute("WindSpeed", FALLBACK_SETTINGS.WindSpeed)
	end

	if typeof(direction) ~= "Vector3" then
		script:SetAttribute("WindDirection", FALLBACK_SETTINGS.WindDirection)
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

	-- Wire up workspace wind.
	if config and config.MatchWorkspaceWind then
		self:MatchWorkspaceWind()
		self.WorkspaceWindConnection = workspace:GetPropertyChangedSignal("GlobalWind"):Connect(function()
			self:MatchWorkspaceWind()
		end)
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

	if self.WorkspaceWindConnection then
		self.WorkspaceWindConnection:Disconnect()
		self.WorkspaceWindConnection = nil
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

function WindShake:MatchWorkspaceWind()
	local workspaceWind = workspace.GlobalWind
	local windDirection = workspaceWind.Unit
	local windSpeed, windPower = 0, 0

	local windMagnitude = workspaceWind.Magnitude
	if windMagnitude > 0 then
		windPower = if windMagnitude > 1 then math.log10(windMagnitude) + 0.2 else 0.3
		windSpeed = if windMagnitude < 100 then (windMagnitude * 1.2) + 5 else 125
	end

	self:SetDefaultSettings({
		WindDirection = windDirection,
		WindSpeed = windSpeed,
		WindPower = windPower,
	})
end

return WindShake
