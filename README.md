# WindShake

High performance wind effect for leaves and foliage

*by boatbomber*

I wanted to have massive forests full of moving leaves. Not for any project of mine, I just wanted to make it cuz it sounded like fun. So I did. And now you guys benefit!

This module handled 77,750 leaf meshes while the game ran at over 400 FPS on my machine. It's pretty darn fast, all things considered.

-----

## Source:

**GitHub:**

https://github.com/boatbomber/WindShake

**Library:**

https://www.roblox.com/library/6377120469/WindShake

**Uncopylocked Demo:**

https://www.roblox.com/games/6342320514/Wind-Demo

-----

## API:


```Lua
function WindShake:Init()
```
*Initializes the wind shake logic*

**Returns:**  
* `void`

```Lua
function WindShake:Cleanup()
```
*Halts and clears the wind shake logic*

**Returns:**  
* `void`

```Lua
function WindShake:AddObjectShake(Object, Settings)
```
*Adds an object to be shaken*

**Parameters:**
- `Object` *[BasePart]*
The Object to apply shaking to

- `Settings` *[Optional Dictionary]*
The settings to apply to this object's shake (See below for Settings structure)

**Returns:**  
* `void`

```Lua
function WindShake:SetDefaultSettings(Settings)
```
*Sets the default settings for future object shake additions*

**Parameters:**

- `Settings` *[Dictionary]*
The settings to use as default (See below for Settings structure)

**Returns:**  
* `void`

```Lua
function WindShake:UpdateObjectSettings(Object, Settings)
```
*Updates the shake settings of an object already added*

**Parameters:**
- `Object` *[BasePart]*
The Object to apply shake settings to

- `Settings` *[Dictionary]*
The settings to apply to this object's shake (See below for Settings structure)

**Returns:**  
* `void`

```Lua
function WindShake:UpdateAllObjectSettings(Settings)
```
*Updates the shake settings of all active shakes*

**Parameters:**

- `Settings` *[Dictionary]*
The settings to apply to all objects' shake (See below for Settings structure)

**Returns:**  
* `void`

```Lua
Settings
```

`Settings` tables are structured like so:

```Lua
{
    Direction: Vector3 to shake towards (Initially 0.5,0,0.5)
    Speed: Positive number that defines how fast to shake (Initially 20)
    Power: Positive number that defines how much to shake (Initially 0.5)
 
    --If one of these is not defined, it will use default for that one,
    --so you can pass a table with just one or two settings and the rest
    --will be default so you don't need to make the full table every time.
}
```

-----

## Usage Example:

```Lua
local WIND_DIRECTION = Vector3.new(1,0,0.3)
local WIND_SPEED = 25
local WIND_POWER = 0.4

local WindShake = require(script.WindShake)

WindShake:Init()
WindShake:SetDefaultSettings({
	Speed = WIND_SPEED;
	Direction = WIND_DIRECTION;
	Power = WIND_POWER;
})

local Trees = workspace:WaitForChild("Trees")

for _, LeafBall in pairs(Trees:GetDescendants()) do
	if LeafBall.Name == "LeafBall" then
		WindShake:AddObjectShake(LeafBall)
	end
end
```
