--- ************************************************************************************************************************************************************************
---
---				Name : 		soe.lua
---				Purpose :	SOE (Simple Object Engine)
---				Created:	7th June 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local SOEBaseObject 

--- ************************************************************************************************************************************************************************
--//	The SOE object is a singleton which keeps track of game objects. 
--- ************************************************************************************************************************************************************************

local SOE = Base:new()

SOE.decorationList = { "delete","tag","detag","name","isAlive","process","fireMethod"} 		--  methods that decorate objects.

--//	SOE Constructor

function SOE:initialise()
	self.objects = {} 																		-- Hash of objects (reference => reference)
	self.objectCount = 0 																	-- Tracking count of objects.
	self.e = {} 																			-- named objects store (name l/c => reference) 
	self.tagLists = {} 																		-- Hash of indexes (tag Name l/c => {objects => objects})
	self.tagIndexCount = {} 																-- Index size (tag Name l/c => number)
end 

--//	SOE destructor. This reinitialises the object to empty so it can be reused.

function SOE:delete()
	self:deleteAllObjects() 																-- delete all known objects
	self:initialise() 																		-- set it back to the default, clear, state.
end 

--//	Delete all Game Objects, also checks counters are zero and tag index lists are empty.

function SOE:deleteAll() 
	for _,obj in pairs(self.objects) do obj:delete() end 									-- delete every object in the system.
	assert(self.objectCount == 0) assert(self:tableSize(self.e) == 0) 						-- check everything tidied up correctly.
	assert(self:tableSize(self.objects) == 0)
	for name,_ in pairs(self.tagLists) do 													-- check the tag indexes are clear.
		assert(self.tagIndexCount[name] == 0)
		assert(self:tableSize(self.tagLists[name]) == 0)
	end 
end

--//%	Utility function to calculate hash size. Speed is not important as this is only used to check on clean up.

function SOE:tableSize(table)
	local c = 0
	for _,_ in pairs(table) do c = c + 1 end 												-- count the number of key/value pairs.
	return c 
end 

--//	Access the prototype for a Game Object Base Class.
--//	@return 	[class]			Game Object Prototype

function SOE:getBaseClass()
	return SOEBaseObject 
end 

SOE.decorationList = { "delete","tag","detag","name","isAlive"}

--//	Attach an object to the system. It is added to the indices and decorated with the needed default functions, currently tag, detag, name and delete.
--//	@object 	[object]		Object to attach to SOE

function SOE:attach(object)
	assert(object ~= nil and self.objects[object] == nil,"Bad Game Object Attached") 		-- check parameter is present and not already in objects list.
	self.objects[object] = object 															-- add to object list.
	self.objectCount = self.objectCount + 1 												-- increment the object counter.
	for _,name in ipairs(SOE.decorationList) do self[name] = SOEBaseObject[name] end  		-- add functions from decoration list
end 

--//	Detach an object from the system. It removes its reference, any usage in SOE.e and removes itself from the tag lists
--//	@object 	[object]		Object to detach from SOE

function SOE:detach(object)
	assert(object ~= nil and self.objects[object] ~= nil,"Cannot remove Game Object") 		-- check parameter present and object actually exists.
	self.objects[object] = nil  															-- remove from object list
	self.objectCount = self.objectCount - 1 												-- decrement object count.
	for name,ref in pairs(self.e) do 														-- remove reference from self.e
		if ref == object then self.e[name] = nil end 
	end			
	for name,tagList in pairs(self.tagLists) do 											-- scan all the tag lists.
		if tagList[object] ~= nil then 														-- if in this tag list
			self.tagLists[name][object] = nil 												-- then remove it
			self.tagIndexCount[name] = self.tagIndexCount[name] - 1 						-- decrement the tag list index count
		end 
	end
	for _,name in ipairs(SOE.decorationList) do self[name] = nil end  						-- remove functions from decoration list
end 

--//%	Add a tag to a specific object. Objects should add tags to themselves using the tag() method.
--//	@tagName 	[string]		name of tag
--//	@object 	[object] 		object to tag 

function SOE:addTag(tagName,object)
	-- print("Tagging",tagName,tostring(object))
	if self.tagLists[tagName] == nil then 													-- add tag index and count if not present 
		self.tagLists[tagName] = {}
		self.tagIndexCount[tagName] = 0 
	end 
	if self.tagLists[tagName][object] == nil then 											-- if it is not tagged already.
		self.tagLists[tagName][object] = object 											-- add to the tag indexes.
		self.tagIndexCount[tagName] = self.tagIndexCount[tagName] + 1 						-- bump the counter.
	end 
end 

--//%	Remove a tag from a specific object. Objects should remove tags from themselves using the detag() method.
--//	@tagName 	[string]		name of tag
--//	@object 	[object] 		object to remove tag from

function SOE:removeTag(tagName,object) 
	-- print("Detagging",tagName,tostring(object))
	assert(self.tagLists[tagName] ~= nil,"Unknown tag") 									-- tag list must exist
	assert(self.tagLists[tagName][object] ~= nil,"Object not tagged with "..tagName)		-- and must contain the object.
	self.tagLists[tagName][object] = nil 													-- remove the tag
	self.tagIndexCount[tagName] = self.tagIndexCount[tagName] - 1 							-- decrement the count.
end 

--//%	Give an object a name so it can be accessed via SOE.e - for example calling self:name("demo") on an object causes
--//	SOE.e.demo to refer to it. Do not use directly, use object's name() method
--//	@name 		[string]		identifier
--//	@object 	[object] 		object to add to name space

function SOE:nameObject(name,object)
	assert(name ~= nil and type(name) == "string","Bad Name parameter") 					-- check parameter
	assert(self.e[name] == nil,"Object name duplication "..name) 							-- check not already in use.
	self.e[name] = object 																	-- save into SOE.e
end 

--//%	Utility function, converts a comma seperated list of tags into an array of tags
--//	@tags 	[string] 			csl tags - tag1,tag2,tag9
--//	@return [array]				list of tags { "tag1","tag2","tag9" }

function SOE:createTagList(tags)
	assert(tags ~= nil and type(tags) == "string","Bad tags parameter") 					-- check tags parameter
	tags = tags:lower():gsub("%s","")														-- make lower case, remove spaces
	assert(#tags > 0,"Bad tags parameter")													-- check not empty string.
	if tags:find(",") == nil then return { tags } end 										-- optimisation for a single tag.
	local tagList = {} 																		-- tags remaining.
	tags = tags .. "," 																		-- add a trailing comma
	while tags ~= "" do 																	-- while not finished 
		local newTag newTag,tags = tags:match("^([a-z][%w%_]*)%,(.*)$")
		assert(tags ~= nil,"Bad tags format")
		tagList[#tagList+1] = newTag 	
	end 
	return tagList
end 

--//	Query the tag database, return a list of objects with the tag(s) or nil if there are none. Note that multiple tag queries
--// 	are not optimised or cache, but single tag queries are very fast.
--//
--//	@tagList 	[table]				table of tags (if empty, returns all objects)
--//	@return 	[hash]				table of ref => ref of matching tags, or nil.

function SOE:query(tagList)
	assert(type(tagList) == "table") 														-- must be a table
	if #tagList == 0 then  																	-- an empty table returns the whole lot
		if self.objectCount > 0 then return self.objects else return nil end 				-- return the object list or nil
	end 
	if #tagList == 1 then 																	-- if one item.
		return self.tagLists[tagList[1]] 													-- then return the taglist for that tag (the first and only one)
	end
	for i = 1,#tagList do 																	-- check that all the tags have at least one value, otherwise
		if self.tagLists[tagList[i]] == nil then return nil end  							-- we return nothing.
	end
	table.sort(tagList,function(a,b) return self.tagIndexCount[a]<self.tagIndexCount[b] end)-- sort taglist so smallest number of items first, speeds search.
	local result = {} 																		-- result hash
	for _,ref in pairs(self.tagLists[tagList[1]]) do 										-- work through all the objects in the list of the first query tag.
		local isOk = true 
		for i = 2,#tagList do 																-- check keys in 2,3,4,5 etc. to see if they are present.
			if self.tagLists[tagList[i]][ref] == nil then 									-- if not present
				isOk = false  																-- mark as not passing
				break 																		-- break out of the loop
			end 
		end
		if isOk then result[ref] = ref end 													-- if matches all add to the result list.
	end
	return result
end 

SOE:initialise() 																			-- create the single instance
SOE.new = nil 																				-- disable its constructor.

--- ************************************************************************************************************************************************************************
--//	This is the base object from which all derive. If you create a mixin object then you will have to decorate it with a constructor/destructor if you want one
--//	and attach it manually.
--- ************************************************************************************************************************************************************************

SOEBaseObject = Base:new()

--//%	The real Base object constructor, which is responsible for calling the game object constructor.
--//	@data 	[table]					Object data for the game object. If nil, it is being used to prototype.

function SOEBaseObject:initialise(data)
	if data == nil then return end 															-- being used to create a new object, not an actual new object.
	self.__SOE = SOE 																		-- set an SOE reference for general use
	self.__SOE:attach(self) 																-- attach the object and decorate it
	self:constructor(data) 																	-- call its SOE constructor 
end 

--//	Constructor for game object
--//	@data 	[table]					Object data for the game object.

function SOEBaseObject:constructor(data) 	 												-- default constructor
	--print("Constructor",tostring(self))
end 

--//	Destructor for game object

function SOEBaseObject:destructor() 	 													-- default destructor.
	--print("Destructor",tostring(self))
end 

--//	Instruct object to self-destroy, also removes itself from the system.

function SOEBaseObject:delete()
	self:destructor() 																		-- call destructor.
	self.__SOE:detach(self) 																-- detach the object.
	self.__SOE = nil 																		-- removing this reference means the object is dead.
end 

--//	Check to see if object has not been destroyed. This needs to be done when processing tag lists, unless you know for an absolute fact that 
--//	you aren't removing objects when doing so.
--//	@return 	[boolean]			true if alive.

function SOEBaseObject:isAlive()
	return self.__SOE ~= nil 
end 

--//	Add tag or tags to a game object
--//	@tagList 	[string]			tag name or comma seperated list of tags

function SOEBaseObject:tag(tagList) 		
	tagList = self.__SOE:createTagList(tagList) 											-- convert to a list of tags.
	for _,tag in ipairs(tagList) do self.__SOE:addTag(tag,self) end 						-- add all the tags.
end 

--//	Remove tag or tags from a game object
--//	@tagList 	[string]			tag name or comma seperated list of tags

function SOEBaseObject:detag(tagList)
	tagList = self.__SOE:createTagList(tagList) 											-- convert to a list of tags.
	for _,tag in ipairs(tagList) do self.__SOE:removeTag(tag,self) end 						-- remove all the tags.
end

--//	Query the tag database, return a list of objects with the tag(s) or nil if there are none.
--//	@tagList 	[string]			CSV List of tags, or table of tags.
--//	@return 	[hash]				table of ref => ref of matching tags, or nil.

function SOEBaseObject:query(tagList)
	if type(tagList) == "string" then tagList = self.__SOE:createTagList(tagList) end 		-- convert to a list of tags if not a list already.
	return self.__SOE:query(tagList)  														-- evaluate the query.
end 

--//	Name an object - make it accessible via SOE.e 
--//	@name 		[string] 			identifier to use.

function SOEBaseObject:name(name)
	self.__SOE:nameObject(name:lower():gsub("%s",""),self) 									-- name the object
end 

--//	Call a named class method on all the entities in the entity list.
--//	@methodName 	[string] 		name of method to call
--//	@entities 		[table]			table of ref=>ref
--//	@return 		[boolean]		true if successfully called. Failures will log errors.

function SOEBaseObject:process(methodName,entities,...)
	local ok = true
	if entities == nil then return end 														-- nothing in the list, then return.
	for _,ref in pairs(entities) do 														-- work through all the entities
		ok = ok and self:fireMethod(ref,methodName,...)
	end
	return ok
end 

--//	Call the given method (by name) on the given reference.
--//	@ref 			[object]		object reference
--//	@methodName 	[string] 		name of method to call
--//	@return 		[boolean]		true if successfully called. Failures will log errors.

function SOEBaseObject:fireMethod(ref,methodName,...)
	local ok = true
	if ref:isAlive() then 																	-- if the entity is still alive
		if ref[methodName] == nil then 														-- don't have that tag
			ok = false 																		-- so send a warning.
			print("Warning : object does not have "..methodName.."()")
		else
			ref[methodName](ref,...) 														-- call the appropriate method
		end
	end 
	return ok
end 

_G.SOE = SOE

--- ************************************************************************************************************************************************************************
--
--																			C O M P O N E N T S
--
--- ************************************************************************************************************************************************************************

--- ************************************************************************************************************************************************************************
--//	Update Object, does frame based updates on anything tagged with the update tag. Anything tagged wth 'update' has its onUpdate() method called every frame.
--- ************************************************************************************************************************************************************************

local UpdateObject = SOEBaseObject:new() 													-- create a subclass

--//	Constructor

function UpdateObject:constructor()
	-- print("Construct update")
	self.lastTick = 0 																		-- clear last tick
	Runtime:addEventListener("enterFrame",self) 											-- add RTEL
end 

--// 	Destructor

function UpdateObject:destructor()
	-- print("Destruct update")
	Runtime:removeEventListener("enterFrame",self) 											-- remove RTEL
end 

--//	Update enterFrame handler. Works out the dt value in both seconds and milliseconds, and dispatches to all 
--//	update tagged objects.

function UpdateObject:enterFrame()
	local currentTime = system.getTimer() 													-- get now
	local deltaMillisecs = math.min(100,currentTime-self.lastTick) 							-- get dt in milliseconds
	self.lastTick = currentTime  															-- update last tick.
	local ok=self:process("onUpdate",self:query("update"),deltaMillisecs/1000,deltaMillisecs) 		-- and pass it to all matching objects
	if not ok then self:delete() end
end 

UpdateObject:new({}) 																		-- create an object which is added automatically.
UpdateObject.new = nil 																		-- singleton

--- ************************************************************************************************************************************************************************
-- 		Timer Object, provides multiple timers. Only one instance is required per scene, as it can handle multiple events. 
--- ************************************************************************************************************************************************************************

local TimerObject = SOEBaseObject:new() 													-- create a subclass

--//	Constructor

function TimerObject:constructor() 
	self.timerEvents = {} 																	-- list of timer events. { ref = fireTime = , delay = , isRepeat = , target = }
	self:tag("update")	 																	-- tagged for update
	self:name("timer") 																		-- accessible via SOE.e.timer
	self.nextFreeID = 1000 																	-- next free timer ID.
end 

--//%	General addEvent method. Adds a method to be fired at a point in the future
--//	@timerID 	[number]		Timer ID to use, if not provided will use the next one.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@repeatCount [number]		Number of repeats, 1 upwards. -1 will run until cancelled.
--//	@return 	[number]		Internal ID of timer

function TimerObject:_addEvent(timerID,target,delay,repeatCount)
	if timerID == nil then 																	-- if no ID given, create one.
		timerID = self.nextFreeID
		self.nextFreeID = self.nextFreeID + 1
	end
	repeatCount = repeatCount or 1 	 		 												-- repeat count defaults to 1.
	local newEvent = { ref = timerID, fireTime = system.getTimer()+delay, delay = delay, 	-- create a new event record.
															count = repeatCount, target = target}															
	self.timerEvents[#self.timerEvents+1] = newEvent 										-- add to the list.
	table.sort(self.timerEvents,function(a,b) return a.fireTime < b.fireTime end) 			-- sort it so the next one is first on the list.
	return timerID
end 

--//	Fire the timer event once.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@return 	[number]		Internal ID of timer

function TimerObject:addOneEvent(target,delay)
	return self:_addEvent(nil,target,delay,1)
end 

--//	Fire the timer event a specific number of times.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@repeatCount [number]		Number of repeats, 1 upwards. -1 will run until cancelled.
--//	@return 	[number]		Internal ID of timer

function TimerObject:addMultipleEvent(target,delay,repeatCount)
	return self:_addEvent(nil,target,delay,repeatCount)
end 

--//	Fire the timer event at regular intervals until cancelled.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@return 	[number]		Internal ID of timer

function TimerObject:addRepeatingEvent(target,delay)
	return self:_addEvent(nil,target,delay,-1)
end 


--//	Remove a current event
--//	@timerID 	[number]		Event you want to remove.

function TimerObject:removeEvent(timerID)
	local i = 1 																			-- work through the timer events
	while i <= #self.timerEvents do  														-- scan them
		if self.timerEvents[i].ref == timerID then  										-- if IDs match then remove
			table.remove(self.timerEvents,i)
		else  																				-- otherwise go on to the next one.
			i = i + 1
		end 
	end
end 

--//	Destructor

function TimerObject:destructor()
	timerEvents = {}
end 

--//	Called on update (e.g. enterFrame)
--//	@dt 	[number] 	delta time in seconds
--//	@dms 	[number] 	delta time in milliseconds

function TimerObject:onUpdate(dt,dms)
	if #self.timerEvents == 0 then return end 												-- if no timer events, do nothing.
	local currentTime = system.getTimer() 													-- get elapsed time in milliseconds.
	if currentTime < self.timerEvents[1].fireTime then return end 							-- not time to fire yet
	local event = self.timerEvents[1] 														-- grab the event.
	table.remove(self.timerEvents,1) 														-- remove it from the array.
	if event.count > 0 then event.count = event.count - 1 end 								-- decrement repeeat count if > 0
	if event.count ~= 0 then 																-- is it a repeatable event ?
		self:_addEvent(event.ref,event.target,event.delay,event.count)						-- set it to fire again
	end 
	self:fireMethod(event.target,"onTimer",event.ref) 										-- fire the onTimer() method.
end 

TimerObject:new({}) 																		-- create a new empty timer object.
TimerObject.new = nil 																		-- one instance only.

--- ********************************T****************************************************************************************************************************************
--- ************************************************************************************************************************************************************************


-- TODO: Messaging System
-- TODO: Event Systen
-- TODO: State Machine ?

print("Creating o1")
local o1 = SOE.getBaseClass():new({})
local o2 = SOE.getBaseClass():new({})
SOE.e.timer:addMultipleEvent(o1,2000,3)
local rTimer = SOE.e.timer:addRepeatingEvent(o2,500,-1)
function o1:onTimer(id) print("*** clock ***",id) SOE.e.timer:removeEvent(rTimer) end
function o2:onTimer(id) print("long",id) end
--SOE:deleteAll()

require("bully")