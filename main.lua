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
