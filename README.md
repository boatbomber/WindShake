# WindShake

High performance wind effect for leaves and foliage

*by boatbomber*

I wanted to have massive forests full of moving leaves. Not for any project of mine, I just wanted to make it cuz it sounded like fun. So I did. And now you guys benefit!

This module handled 77,750+ leaf meshes while the game ran at over 400 FPS on my machine. It's pretty darn fast, all things considered.

Demo:
https://www.youtube.com/watch?v=WdJr7k9Uqfw

-----

# Source:

**GitHub:**

https://github.com/boatbomber/WindShake

**Library:**

https://www.roblox.com/library/6377120469/WindShake

**Uncopylocked Demo:**

https://www.roblox.com/games/6342320514/Wind-Demo

-----

# API:

## Properties

```Lua
number WindShake.RenderDistance
```
*Sets the render distance for active objects in studs. Default 150*

```Lua
number WindShake.MaxRefreshRate
```
*Sets the maximum dynamic refresh rate for active objects in seconds. Default 1/60*


## Functions

```Lua
function WindShake:Init(config: {
    MatchWorkspaceWind: boolean?,
}?)
```
*Initializes the wind shake logic and adds shake to all tagged objects*

**Parameters:**
- `config` *[Optional Dictionary]*

    Configuration for the initialization
    - `MatchWorkspaceWind` *[Optional Boolean]*

        Whether to match the wind settings to the Workspace's GlobalWind setting. Default false


**Returns:**
* `void`

```Lua
function WindShake:Cleanup()
```
*Halts and clears the wind shake logic and all object shakes*

**Returns:**
* `void`

```Lua
function WindShake:Pause()
```
*Halts the wind shake logic without clearing*

**Returns:**
* `void`

```Lua
function WindShake:Resume()
```
*Restarts the wind shake logic without clearing*

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
function WindShake:RemoveObjectShake(Object)
```
*Removes shake from an object*

**Parameters:**
- `Object` *[BasePart]*
The Object to remove shaking from

**Returns:**
* `void`

```Lua
function WindShake:SetDefaultSettings(Settings) [DEPRECATED]
```
> Deprecated in favor of setting the Attributes of the WindShake modulescript

*Sets the default settings for future object shake additions*


**Parameters:**

- `Settings` *[Dictionary]*
The settings to use as default (See below for Settings structure)

**Returns:**
* `void`

```Lua
function WindShake:UpdateObjectSettings(Object, Settings) [DEPRECATED]
```
> Deprecated in favor of setting the Attributes of the Object

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
function WindShake:MatchWorkspaceWind()
```
*Sets the wind settings to match the current workspace GlobalWind*

> When `:Init()` is called with the `MatchWorkspaceWind` config set to true, this is called automatically

**Returns:**
* `void`

## Events

```Lua
RBXScriptSignal WindShake.ObjectShakeAdded(Object)
```
*Fires when an object is added to WindShake*

**Parameters:**

- `Object` *[BasePart]*
The object that was added

```Lua
RBXScriptSignal WindShake.ObjectShakeRemoved(Object)
```
*Fires when an object is removed from WindShake*

**Parameters:**

- `Object` *[BasePart]*
The object that was removed

```Lua
RBXScriptSignal WindShake.ObjectShakeUpdated(Object)
```
*Fires when an object's settings are updated through the update APIs*

**Parameters:**

- `Object` *[BasePart]*
The object that had its settings updated

```Lua
RBXScriptSignal WindShake.Resumed()
```
*Fires when WindShake begins shaking the objects*

```Lua
RBXScriptSignal WindShake.Paused()
```
*Fires when WindShake stops shaking the objects*

## Types

```Lua
Settings = {
    WindDirection: Vector3 to shake towards (Initially 0.5,0,0.5)
    WindSpeed: Positive number that defines how fast to shake (Initially 20)
    WindPower: Positive number that defines how much to shake (Initially 0.5)

    --If one of these is not defined, it will use default for that one,
    --so you can pass a table with just one or two settings and the rest
    --will be default so you don't need to make the full table every time.
}
```

-----

# Usage Example:

```Lua
local WIND_DIRECTION = Vector3.new(1,0,0.3)
local WIND_SPEED = 25
local WIND_POWER = 0.4

local WindShake = require(script.WindShake)

WindShake:SetDefaultSettings({
	WindSpeed = WIND_SPEED;
	WindDirection = WIND_DIRECTION;
	WindPower = WIND_POWER;
})

WindShake:Init() -- Anything with the WindShake tag will now shake

```
