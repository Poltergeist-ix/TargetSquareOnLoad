# Project Zomboid Mod - Target Square: OnLoad Commands

## Summary

Simple way to trigger functions when the square is loaded, without every mod performing same checks multiple times.

> Steam Workshop Link  
> https://steamcommunity.com/sharedfiles/filedetails/?id=2969455858

## Permissions

> [Give credit where credit is due](http://theindiestone.com/forums/index.php/topic/2530-mod-permissions/?p=36477)  
> Please do not re-upload this mod, it's meant to be used as a tool to improve performance. You can however reuse it for different tasks as long as you give credit to the author.

## Basics

- To use the API you need to require the file "!_TargetSquare_OnLoad".
- Register a function that the API will call for you.
- Add the command you want to be called when a square at x,y,z coordinates is loaded.
- It's best to use the API after it creates the instance because then you have access to the persistent tables.
- Map Objects are generally handled on server, so we make a server only system.
- This was made with/for v.41.78 of Project Zomboid.

## Commands & function

### Register a function

The functions are set in the `API.OnLoadCommands` table.

`API.OnLoadCommands.myFunction = function(square, myCommand) print(square, myCommand) end`

These are not persistent and need to be set every time the game reloads.

If the function returns true then the command will be repeated next time the square is loaded again.
In all other cases, the command will be removed and the function will not be called again.

### Add commands - function triggers

You add commands with the next call.

`API.addCommand(x, y, z, { command = "myFunction" })`

These are persistent and don't need to be added again between reloads.

Parameter 1,2,3 are used for the square (x,y,z) coordinates. They should be integers.
Parameter 4, the command table, should be a Lua Table with a command value which is used to get the function to call.
This table will be stored and passed to your function when the square is loaded.
This table is reused if the function returns true.

Currently, you should set `squareCanBeNil = true` if you want your function to be called even if the square doesn't have an object.

## Reload Persistence

Every Square Command is stored in a global object on that square and the command data is persistent between reloads.

The API System saves the savedData table, which is then loaded on the OnSGlobalObjectSystemInit event, it can be used just like a global ModData table.

You can save only primary types, objects and functions are not persistent.

## Example

This is example of using a 'soft require' of the API, as an optional extension.
```lua
if isClient() then return end
local API = require "!_TargetSquare_OnLoad"

local addSpawns = function()
    local instance = API and API.instance
    if not instance then print("myLog: API has no instance") return end

    instance.OnLoadCommands.isaWorldSpawn = function(square, myCommand)
        ISAWorldSpawns.addToWorld(square, myCommand.sprite)
    end

    if instance.savedData["isaWorldSpawns"] then
        return
    end

    local x, y, z = 1, 2, 3
    instance.addCommand(x, y, z, { command = "isaWorldSpawn", sprite = "solarmod_tileset_01_0" })

    instance.savedData["isaWorldSpawns"] = true
end

Events.OnSGlobalObjectSystemInit.Add(addSpawns)
```

## Debugging problems
- require doesn't return a table
    > check that you use the right name of the file, if the file isn't found you will see a log message similar to: "require ... failed"
- API does not have an instance table.
    > The API makes an instance on the OnSGlobalObjectSystemInit event. If there is no instance during loading, but there is one when the game is loaded, it means you try this too early.
- found other bug or issue: contact on discord or create a GitHub issue
