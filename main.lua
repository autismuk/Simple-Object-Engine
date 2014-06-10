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
require("soe.controller"):new({})

local Bat = SOE:getBaseClass():new()

function Bat:constructor(info)
	self.height = info.height or display.contentHeight / 4
	self.bat = display.newRect(0,0,10,self.height)
	self.bat:setFillColor(1,1,0)
	self.bat.x = info.x or 32
	self.bat.y = display.contentHeight/2
	self:tag("update,obstacle")
end 

function Bat:destructor()
	self.bat:removeSelf()
end 

function Bat:onUpdate(dTime,dmilliTime)
	self.bat.y = self.bat.y + SOE.e.controller:getY() * dTime * display.contentHeight
	self.bat.y = math.max(self.bat.y,self.height/2)
	self.bat.y = math.min(self.bat.y,display.contentHeight-self.height/2)
end 

function Bat:onMessage(message)
	local ball = message.sender
	if math.abs(ball.ball.x - self.bat.x) < ball.radius and math.abs(ball.ball.y - self.bat.y) < self.height/2 then 
		ball.dx = -ball.dx
		ball.dy = math.random(-10,10)/10
	end
end 

local Ball = SOE:getBaseClass():new()

function Ball:constructor()
	self.radius = display.contentHeight / 30
	self.dx = 1
	self.dy = math.random(5,10)/10
	self.ball = display.newCircle(0,0,self.radius)
	self.ball:setFillColor(0,1,1)
	self.ball.x = display.contentWidth / 2
	self.ball.y = math.random(self.radius,display.contentHeight-self.radius)
	self.speed = 8
	self:tag("balls")
	--self:tag("update")
end 

function Ball:destructor()
	self.ball:removeSelf() 
end 

function Ball:onMessage(message)
	self:tag("update")
end 

function Ball:onUpdate(dTime,dMilliTime)
	self.ball.x = self.ball.x + self.dx * self.speed 
	self.ball.y = self.ball.y + self.dy * self.speed 
	if self.ball.y < self.radius or self.ball.y > display.contentHeight - self.radius then 
		self.dy = -self.dy 
	end 
	if self.ball.x > display.contentWidth - self.radius then 
		self.dx = -self.dx 
	end 
	if self.ball.x < 0 then 
		-- SOE:deleteAll()
		self.dx = 1
	end
	--SOE.e.post:send("obstacle",self)
	self:sendMessage("obstacle",42)
end 

Bat:new({ x = 32 })
Bat:new({ x = display.contentWidth/3 })
Ball:new({})
Ball:new({})
local i = Ball:new({})

i:sendMessageDelayed("balls",1000)

