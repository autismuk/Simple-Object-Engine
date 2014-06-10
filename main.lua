--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	SOE testing.
---				Created:	7th June 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

require("soe.soe")
require("soe.core")


print("Creating o1")
local o1 = SOE.getBaseClass():new({})
local o2 = SOE.getBaseClass():new({})

--require("bully")

local o3 = require("soe.controller")
print(o3:new({}))

local fred = { 1,2 }
function dox(...)
	fred = arg
end 

dox(2,3,4,5)
print(#fred)
--SOE:deleteAll()

print(SOE.e.msg:send("tag1",44,66))

-- o1:tag("update")
function o1:onUpdate(dt,dms) print(SOE.e.controller:getX(),SOE.e.controller:getY()) end 
function o1:onTimer(dt,dms) print(SOE.e.controller:getX(),SOE.e.controller:getY()) end 

SOE.e.timer:addRepeatingEvent(o1,500)

-- TODO: Timer as local Mixin ?
-- TODO: More Asserts
-- TODO: Complete Messaging System (dispatch - transfer, clear, then send to stop loops)
-- TODO: State Machine ? Attached to Scenes ?
-- TODO: Pong
-- TODO: Flappy Circle
-- TODO: Add buttons to controller.
