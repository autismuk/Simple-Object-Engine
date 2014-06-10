--- ************************************************************************************************************************************************************************
---
---				Name : 		core.lua
---				Purpose :	SOE Core Objects
---				Created:	7th June 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

--- ************************************************************************************************************************************************************************
--//	Update Object, does frame based updates on anything tagged with the update tag. Anything tagged wth 'update' has its onUpdate() method called every frame.
--- ************************************************************************************************************************************************************************

local UpdateObject = SOE.getBaseClass():new() 												-- create a subclass

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
	if not ok then self:delete() end 														-- stop on failure.
end 

UpdateObject:new({}) 																		-- create an object which is added automatically.
UpdateObject.new = nil 																		-- singleton

--- ************************************************************************************************************************************************************************
-- 		Timer Object, provides multiple timers. Only one instance is required per scene, as it can handle multiple events, dispatched to multiple targets. Targets are
--		individual objects, and should normally be the message originator. If a broadcast timed message is required this can be done using MessageObject.
--- ************************************************************************************************************************************************************************

local TimerObject = SOE.getBaseClass():new() 												-- create a subclass

--//	Constructor

function TimerObject:constructor() 
	self.timerEvents = {} 																	-- list of timer events. { ref = fireTime = , delay = , isRepeat = , target = }
	self:tag("update")	 																	-- tagged for update
	self:name("timer") 																		-- accessible via SOE.e.timer
	self.nextFreeID = 1000 																	-- next free timer ID.
end 

--//%	General addEvent method. Adds a method to be fired at a point in the future. Use the other functions which encapsulate this.
--//	@timerID 	[number]		Timer ID to use, if not provided will use the next one.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@repeatCount [number]		Number of repeats, 1 upwards. -1 will run until cancelled.
--//	@tag 		[string]		optional identifying tag
--//	@return 	[number]		Internal ID of timer

function TimerObject:_addEvent(timerID,target,delay,repeatCount,tag)
	if timerID == nil then 																	-- if no ID given, create one.
		timerID = self.nextFreeID
		self.nextFreeID = self.nextFreeID + 1
	end
	repeatCount = repeatCount or 1 	 		 												-- repeat count defaults to 1.
	local newEvent = { ref = timerID, fireTime = system.getTimer()+delay, delay = delay, 	-- create a new event record.
													count = repeatCount, target = target, tag = tag}															
	self.timerEvents[#self.timerEvents+1] = newEvent 										-- add to the list.
	table.sort(self.timerEvents,function(a,b) return a.fireTime < b.fireTime end) 			-- sort it so the next one is first on the list.
	return timerID
end 

--//	Fire the timer event once.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@tag 		[string]		optional identifying tag
--//	@return 	[number]		Internal ID of timer

function TimerObject:addOneEvent(target,delay,tag)
	return self:_addEvent(nil,target,delay,1,tag)
end 

--//	Fire the timer event a specific number of times.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@repeatCount [number]		Number of repeats, 1 upwards. -1 will run until cancelled.
--//	@tag 		[string]		optional identifying tag
--//	@return 	[number]		Internal ID of timer

function TimerObject:addMultipleEvent(target,delay,repeatCount,tag)
	return self:_addEvent(nil,target,delay,repeatCount,tag)
end 

--//	Fire the timer event at regular intervals until cancelled.
--//	@target 	[object]		Object which should have an onTimer() handler
--//	@delay 		[number]		Timer time in ms
--//	@tag 		[string]		optional identifying tag
--//	@return 	[number]		Internal ID of timer

function TimerObject:addRepeatingEvent(target,delay,tag)
	return self:_addEvent(nil,target,delay,-1,tag)
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
		self:_addEvent(event.ref,event.target,event.delay,event.count,event.tag)			-- set it to fire again
	end 
	self:fireMethod(event.target,"onTimer",event.ref,event.tag) 							-- fire the onTimer(referenceID,tag) method.
end 

TimerObject:new({}) 																		-- create a new empty timer object.
TimerObject.new = nil 																		-- one instance only.

--- ************************************************************************************************************************************************************************
--//	Inter object messaging system. Messages can take any form you like, they are stored as variable arguments. The first element is either a string (representing a 
--//	tag or tags for a query) or a table (representing an object to receive the message). Hence messages can be sent to groups or to individuals. Messages are always 
--//	queued, and dispatched on an update tick.
--- ************************************************************************************************************************************************************************

local MessageObject = SOE:getBaseClass():new() 												-- messaging object prototype.

function MessageObject:constructor(init)
	self.currentMessages = {} 																-- array of current messages.
	self:tag("update") 																		-- this is updated on the frame 
	self:name("post") 																		-- accessible through SOE.e.post
end 

function MessageObject:destructor()
	self.currentMessages = nil 	 															-- lose reference
end

function MessageObject:send(tags,sender,...)
	self:sendDelayed(tags,sender,0,...)
end 

function MessageObject:sendDelayed(tags,sender,delay,...)
	if delay > 0 then delay = delay + system.gettimer() end 								-- messages can be sent with a delay in.
	local newMessage = { recipient = tags, delay = delay, contents = arg, sender = sender} 	-- construct a new message list.
	self.currentMessages[#self.currentMessages+1] = newMessage 								-- add message to  internal list.
end 

function MessageObject:onUpdate()
	local sendList = self.currentMessages 													-- get the current messages
	self.currentMessages = {} 																-- clear the list.
	local sysTime = system.getTimer() 														-- get the system timer.
	for _,msg in ipairs(sendList) do 														-- work through the current list
		if sysTime > msg.delay then  														-- is it past the message time ?
			self:process("onMessage",self:query(msg.recipient),msg) 						-- if so, send it to all satisfying the requirements.
		else 
			self.currentMessages[#self.currentMessages+1] = msg  							-- otherwise put it back for next time.
		end 
	end 
	sendList = nil 
end

MessageObject:new({})
MessageObject.new = nil

-- TODO: More Asserts
-- TODO: State Machine ? Attached to Scenes ?
-- TODO: Pong
-- TODO: Flappy Circle
-- TODO: Add buttons to controller.
