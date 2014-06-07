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

--//	Attach an object to the system. It is added to the indices and decorated with the needed default functions, currently tag, detag, name and delete.
--//	@object 	[object]		Object to attach to SOE

function SOE:attach(object)
	assert(object ~= nil and self.objects[object] == nil,"Bad Game Object Attached") 		-- check parameter is present and not already in objects list.
	self.objects[object] = object 															-- add to object list.
	self.objectCount = self.objectCount + 1 												-- increment the object counter.
	self.delete = SOEBaseObject.delete 														-- add decorations
	self.tag = SOEBaseObject.tag
	self.detag = SOEBaseObject.detag
	self.name = SOEBaseObject.name
	self.isAlive = SOEBaseObject.isAlive 													-- we decorate this one but we do not remove it - so we can check life !
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
	self.delete = nil self.tag = nil self.detag = nil self.name = nil						-- remove decorations.
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
	print("Constructor",tostring(self))
end 

--//	Destructor for game object

function SOEBaseObject:destructor() 	 													-- default destructor.
	print("Destructor",tostring(self))
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

--//	Name an object - make it accessible via SOE.e 
--//	@name 		[string] 			identifier to use.

function SOEBaseObject:name(name)
	self.__SOE:nameObject(name:lower():gsub("%s",""),self) 									-- name the object
end 

--- ************************************************************************************************************************************************************************
--- ************************************************************************************************************************************************************************

-- TODO: tag Query design ? 1/2/any ?
-- TODO: Query executor given method/function parameter.

local o1 = SOE:getBaseClass():new({})
local o2 = SOE:getBaseClass():new({})
local o3 = SOE:getBaseClass():new({})
o1:tag("tag1,tag2")
o2:tag("tag2,tag3")
o2:name("fred")
print(o2,SOE.e.fred,o2:isAlive())
o2:detag("tag3")
o2:delete()
print(o2,SOE.e.fred,o2:isAlive())

for k,v in pairs(SOE.tagIndexCount) do print(k,v,SOE:tableSize(SOE.tagLists[k])) end
SOE:deleteAll()