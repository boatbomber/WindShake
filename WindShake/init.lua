--[=[

WindShake- High performance wind effect for leaves and foliage
by boatbomber

Docs: https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806/1

--]=]

local UPDATE_HZ = 1/30 -- Update the objects at 30 Hz

local DEFAULT_SETTINGS = {
	Direction = Vector3.new(0.5,0,0.5);
	Speed = 20;
	Power = 0.5;
}


---------------------------------------------------------------------------------


local RunService = game:GetService("RunService")
local OctreeModule = require(script.Octree)
local Camera = workspace.CurrentCamera

local module = {
	ObjectMetadata = {};
	Octree = OctreeModule.new();
	Active = 0;
	Handled = 0;
}

function module:AddObjectShake(Object, Settings)
	Settings = type(Settings) == "table" and Settings or DEFAULT_SETTINGS

	module.Handled += 1

	module.ObjectMetadata[Object] = {
		CF = Object.CFrame;
		Seed = math.random(1000)*0.1;

		Speed = Settings.Speed or DEFAULT_SETTINGS.Speed;
		Direction = Settings.Direction or DEFAULT_SETTINGS.Direction;
		Power = Settings.Power or DEFAULT_SETTINGS.Power;
	}
	module.Octree:CreateNode(Object.Position,Object)

end

function module:Init()
	
	-- Clear any old stuff
	module:Cleanup()
	
	-- Connect updater
	local LastUpdate = os.clock()
	module.UpdateConnection = RunService.Heartbeat:Connect(function()
		local Clock = os.clock()
		if Clock-LastUpdate >= UPDATE_HZ then
			LastUpdate = Clock
			
			debug.profilebegin("WindShake")
			
			local UpdateObjects = module.Octree:RadiusSearch((Camera.CFrame*CFrame.new(0,0,-115)).Position, 120)
			
			local ActiveCount = #UpdateObjects
			module.Active = ActiveCount
			
			if ActiveCount < 1 then return end
			
			local CFrames = table.create(ActiveCount)

			for Index, Object in ipairs(UpdateObjects) do
				local ObjMeta = module.ObjectMetadata[Object]
				local CF,Seed,Speed,Direction,Power = ObjMeta.CF,ObjMeta.Seed,ObjMeta.Speed,ObjMeta.Direction,ObjMeta.Power
				
				local Amp = math.abs(Power*0.1)
				local Freq = Clock*(Speed*0.08)

				CFrames[Index] = (CF * CFrame.Angles(
					-- Rotation
					math.noise(Freq,0,Seed)*Amp,
					math.noise(Freq,0,Seed)*Amp,
					math.noise(Freq,0,Seed)*Amp
				)) + ( -- Wind Direction
					Direction * (math.noise(Freq,Seed,Seed)+0.5)*(Amp)
				)
			end

			workspace:BulkMoveTo(UpdateObjects,CFrames,Enum.BulkMoveMode.FireCFrameChanged)
			debug.profileend()
		end
	end)
	
end

function module:Pause()
	if module.UpdateConnection then
		module.UpdateConnection:Disconnect()
		module.UpdateConnection = nil
	end
	module.Active = 0
end

function module:Resume()
	module:Pause()
	
	-- Connect updater
	local LastUpdate = os.clock()
	module.UpdateConnection = RunService.Heartbeat:Connect(function()
		local Clock = os.clock()
		if Clock-LastUpdate >= UPDATE_HZ then
			LastUpdate = Clock
			
			debug.profilebegin("WindShake")
			
			local UpdateObjects = module.Octree:RadiusSearch((Camera.CFrame*CFrame.new(0,0,-115)).Position, 120)
			
			local ActiveCount = #UpdateObjects
			module.Active = ActiveCount
			
			if ActiveCount < 1 then return end
			
			local CFrames = table.create(ActiveCount)

			for Index, Object in ipairs(UpdateObjects) do
				local ObjMeta = module.ObjectMetadata[Object]
				local CF,Seed,Speed,Direction,Power = ObjMeta.CF,ObjMeta.Seed,ObjMeta.Speed,ObjMeta.Direction,ObjMeta.Power
				
				local Amp = math.abs(Power*0.1)
				local Freq = Clock*(Speed*0.08)

				CFrames[Index] = (CF * CFrame.Angles(
					-- Rotation
					math.noise(Freq,0,Seed)*Amp,
					math.noise(Freq,0,Seed)*Amp,
					math.noise(Freq,0,Seed)*Amp
				)) + ( -- Wind Direction
					Direction * (math.noise(Freq,Seed,Seed)+0.5)*(Amp)
				)
			end

			workspace:BulkMoveTo(UpdateObjects,CFrames,Enum.BulkMoveMode.FireCFrameChanged)
			debug.profileend()
		end
	end)
end

function module:SetDefaultSettings(Settings)
	if not type(Settings) == "table" then return end
	
	-- Apply settings
	for Key,Value in pairs(Settings) do
		DEFAULT_SETTINGS[Key] = Value
	end
	
end

function module:UpdateObjectSettings(Object, Settings)
	if not type(Settings) == "table" then return end
	
	local ObjMeta = module.ObjectMetadata[Object]
	if not ObjMeta then return end

	-- Apply settings
	for Key,Value in pairs(Settings) do
		ObjMeta[Key] = Value
	end

end

function module:UpdateAllObjectSettings(Settings)
	if not type(Settings) == "table" then return end

	for Obj, ObjMeta in pairs(module.ObjectMetadata) do
		-- Apply settings
		for Key,Value in pairs(Settings) do
			ObjMeta[Key] = Value
		end
	end
	
end

function module:Cleanup()
	
	if module.UpdateConnection then
		module.UpdateConnection:Disconnect()
		module.UpdateConnection = nil
	end

	table.clear(module.ObjectMetadata)

	module.Octree:ClearNodes()
	
	module.Handled = 0
	module.Active = 0
end

return module
