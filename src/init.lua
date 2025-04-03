--[=[

WindShake- High performance wind effect for leaves and foliage
by: boatbomber, MaximumADHD

Docs: https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806/1

--]=]

--!strict
local RunService = game:GetService("RunService")
local Settings = require(script.Settings)

local Packages = script:FindFirstChild("Packages") or script.Parent

local CullThrottle
local CullThrottleModule = Packages:FindFirstChild("CullThrottle")

if CullThrottleModule and CullThrottleModule:IsA("ModuleScript") then
	CullThrottle = require(CullThrottleModule)
end

if not CullThrottle then
	error("Could not find required packages")
end

local COLLECTION_TAG = "WindShake" -- The CollectionService tag to be watched and mounted automatically

-- Use the script's attributes as the default settings.
-- The table provided is a fallback if the attributes
-- are undefined or using the wrong value types.

local FALLBACK_SETTINGS = {
	WindDirection = Vector3.new(0.5, 0, 0.5),
	WindPower = 0.5,
	WindSpeed = 20,
}

type Settings = Settings.Class

-----------------------------------------------------------------------------------------------------------------

local Paused = Instance.new("BindableEvent")
local Resumed = Instance.new("BindableEvent")
local ObjectShakeAdded = Instance.new("BindableEvent")
local ObjectShakeRemoved = Instance.new("BindableEvent")
local ObjectShakeUpdated = Instance.new("BindableEvent")

local WindShake = {
	RenderDistance = 200,
	MaxRefreshRate = 1 / 60,
	MinRefreshRate = 1 / 12,
	SharedSettings = Settings.new(script),

	ObjectMetadata = {} :: {
		[Instance]: {
			Settings: Settings,
			Seed: number,
			IsBone: boolean,
			Origin: CFrame,
			LastUpdate: number,
		},
	},

	CullThrottle = CullThrottle.new(),
	Handled = 0,
	Active = 0,

	_partList = table.create(500) :: { any }, -- ('any' because Studio and Luau LSP disagree on the type)
	_cframeList = table.create(500) :: { CFrame },

	ObjectShakeAdded = ObjectShakeAdded.Event,
	ObjectShakeRemoved = ObjectShakeRemoved.Event,
	ObjectShakeUpdated = ObjectShakeUpdated.Event,

	Paused = Paused.Event,
	Resumed = Resumed.Event,

	Initialized = nil :: boolean?,
	AddedConnection = nil :: RBXScriptConnection?,
	UpdateConnection = nil :: RBXScriptConnection?,
	RemovedConnection = nil :: RBXScriptConnection?,
	WorkspaceWindConnection = nil :: RBXScriptConnection?,
}

type WindShake = typeof(WindShake)

export type WindShakeSettings = {
	WindDirection: Vector3?,
	WindSpeed: number?,
	WindPower: number?,
}

local function Connect<Args...>(
	self: WindShake,
	event: RBXScriptSignal,
	callback: (self: WindShake, Args...) -> ()
): RBXScriptConnection
	return event:Connect(function(...)
		return callback(self, ...)
	end)
end

function WindShake.AddObjectShake(self: WindShake, object: BasePart | Bone, settingsTable: WindShakeSettings?)
	if typeof(object) ~= "Instance" then
		return
	end

	if not (object:IsA("BasePart") or object:IsA("Bone")) then
		return
	end

	local metadata = self.ObjectMetadata

	if metadata[object] then
		return
	end

	metadata[object] = {
		Settings = Settings.new(object),
		Seed = math.random(5000) * 0.32,
		IsBone = object:IsA("Bone"),
		Origin = if object:IsA("Bone") then object.WorldCFrame else object.CFrame,

		LastUpdate = os.clock(),
	}

	if settingsTable then
		self:UpdateObjectSettings(object, settingsTable)
	end

	self.CullThrottle:AddObject(object)

	ObjectShakeAdded:Fire(object)
	self.Handled += 1

	return
end

function WindShake.RemoveObjectShake(self: WindShake, object: BasePart | Bone)
	if typeof(object) ~= "Instance" then
		return
	end

	if not (object:IsA("BasePart") or object:IsA("Bone")) then
		return
	end

	local metadata = self.ObjectMetadata
	local objMeta = metadata[object]

	if objMeta then
		self.Handled -= 1
		metadata[object] = nil
		objMeta.Settings:Destroy()
		self.CullThrottle:RemoveObject(object)

		if object:IsA("BasePart") then
			object.CFrame = objMeta.Origin
		elseif object:IsA("Bone") then
			object.WorldCFrame = objMeta.Origin
		end
	end

	ObjectShakeRemoved:Fire(object)
	return
end

function WindShake.Update(self: WindShake, deltaTime: number)
	debug.profilebegin("WindShake")

	local active = 0

	debug.profilebegin("Update")

	local now = os.clock()
	local step = math.min(1, deltaTime * 5)

	-- Reuse tables to avoid garbage collection
	local bulkMoveIndex = 0
	local partList = self._partList
	local cframeList = self._cframeList
	table.clear(partList)
	table.clear(cframeList)

	-- Cache hot values
	local objectMetadata = self.ObjectMetadata

	local renderDistance = self.RenderDistance
	local sharedSettings = self.SharedSettings

	self.CullThrottle:SetRefreshRates(self.MaxRefreshRate, self.MinRefreshRate)
	self.CullThrottle:SetRenderDistanceTarget(renderDistance)

	local sharedWindPower = assert(sharedSettings.WindPower, "SharedSettings.WindPower is nil")
	local sharedWindSpeed = assert(sharedSettings.WindSpeed, "SharedSettings.WindSpeed is nil")
	local sharedWindDirection = assert(sharedSettings.WindDirection, "SharedSettings.WindDirection is nil")

	-- Update objects in view at their respective refresh rates
	for object, _, distance, cframe in self.CullThrottle:IterateObjectsToUpdate() do
		local objMeta = objectMetadata[object]
		local isBone = objMeta.IsBone

		local distanceAlpha = (distance / renderDistance)
		local distanceAlphaSq = distanceAlpha * distanceAlpha

		active += 1

		local objSettings = objMeta.Settings

		local windDirection = (objSettings.WindDirection or sharedWindDirection)
		if windDirection.Magnitude < 1e-5 then
			return
		end

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
			cframeList[bulkMoveIndex] = cframe:Lerp(
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
	end

	self.Active = active

	debug.profileend()

	workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)

	debug.profileend()
end

function WindShake.Pause(self: WindShake)
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
		self.UpdateConnection = nil
	end

	self.Active = 0
	self.Running = false

	Paused:Fire()
end

function WindShake.Resume(self: WindShake)
	if self.Running then
		return
	end

	-- Connect updater
	self.UpdateConnection = Connect(self, RunService.Heartbeat, self.Update)
	self.Running = true

	Resumed:Fire()
end

function WindShake.Init(self: WindShake, config: { MatchWorkspaceWind: boolean? }?)
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

	self.CullThrottle:SetRefreshRates(self.MaxRefreshRate, self.MinRefreshRate)
	self.CullThrottle:SetRenderDistanceTarget(self.RenderDistance)

	self.AddedConnection = Connect(self, self.CullThrottle.ObjectAdded, self.AddObjectShake)
	self.RemovedConnection = Connect(self, self.CullThrottle.ObjectRemoved, self.RemoveObjectShake)

	-- Wire up tag listeners.
	self.CullThrottle:CaptureTag(COLLECTION_TAG)

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

function WindShake.Cleanup(self: WindShake)
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
	self.CullThrottle:ReleaseTag(COLLECTION_TAG)
	self.CullThrottle:RemoveObjectsWithTag(COLLECTION_TAG)

	self.Handled = 0
	self.Active = 0
	self.Initialized = false
end

function WindShake.UpdateObjectSettings(self: WindShake, object: Instance, settingsTable: WindShakeSettings)
	if typeof(object) ~= "Instance" then
		return
	end

	if typeof(settingsTable) ~= "table" then
		return
	end

	if not self.ObjectMetadata[object] and (object ~= script) then
		return
	end

	for key, value in pairs(settingsTable) do
		object:SetAttribute(key, value)
	end

	ObjectShakeUpdated:Fire(object)
	return
end

function WindShake.UpdateAllObjectSettings(self: WindShake, settingsTable: WindShakeSettings)
	if typeof(settingsTable) ~= "table" then
		return
	end

	for obj, _objMeta in self.ObjectMetadata do
		for key, value in pairs(settingsTable) do
			obj:SetAttribute(key, value)
		end

		ObjectShakeUpdated:Fire(obj)
	end
end

function WindShake.SetDefaultSettings(self: WindShake, settingsTable: WindShakeSettings)
	self:UpdateObjectSettings(script, settingsTable)
end

function WindShake.MatchWorkspaceWind(self: WindShake)
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
