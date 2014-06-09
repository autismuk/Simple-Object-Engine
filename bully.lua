--- ************************************************************************************************************************************************************************
---
---				Name : 		bully.lua
---				Purpose :	SOE (Simple Object Engine) test
---				Created:	8th June 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************


local testCount = 100
local tagCount = 50
local tagName = {}
local objCount = 100
local objRef = {}
local objTagHash = {}
local queryTestCount = 10
local queryTestMaxSize = 5

function countItems(t)
	local c = 0 for _,_ in pairs(t) do c = c + 1 end return c
end 

function checkQuery(objID,query)
	if objTagHash[objID] == nil then return false end 
	for i = 1,#query do 
		local qID = tonumber(query[i]:sub(5))
		if objTagHash[objID][qID] == nil then return false end 
	end 
	return true
end 

math.randomseed(57)

for i = 1,tagCount do tagName[i] = "tag_"..i end

for i = 1,testCount do 
	if i % 1000 == 0 then print("Completed",i,"of",testCount) end
	local n = math.random(1,objCount) 																		-- pick an random object
	if objRef[n] == nil then 
		objRef[n] = SOE:getBaseClass():new({}) 																-- if not present then create it.
		objTagHash[n] = {} 																					-- and it has no recorded objects.
	end 

	local t = math.random(1,tagCount) 																		-- pick a random tag.
	if objTagHash[n][t] ~= true then 																		-- if it doesn't have it.
		objRef[n]:tag(tagName[t]) 																			-- then add it
		objTagHash[n][t] = true  
	else 
		objRef[n]:detag(tagName[t]) 																		-- if it does have it, remove it.
		objTagHash[n][t] = nil 
	end 
	for i = 1,tagCount do 																					-- work through all the tags.
		local name = tagName[i]
		local tagNumber = tonumber(name:sub(5)) 															-- get the tag number
		if SOE.tagLists[name] ~= nil then  																	-- is there something in the tag index ?
			assert(countItems(SOE.tagLists[name]) == SOE.tagIndexCount[name]) 								-- check the tag number matches the index count
			local c = 0
			for i = 1,objCount do 																			-- check all objects
				if objTagHash[i] ~= nil then 
					if objTagHash[i][tagNumber] == true then  												-- if tag present
						c = c + 1 																			-- count it.
						assert(SOE.tagLists[name][objRef[i]] ~= nil) 										-- check the object is in the tag list.
					end
				end 
			end 
			assert(c == SOE.tagIndexCount[name]) 															-- check the numbers match, if so all matches up.
		else 																								-- no tag index created. 
			assert((SOE.tagIndexCount[name] or 0) == 0) 													-- check that tag count is zero.
			for i = 1,objCount do 																			-- check our mirror to see that all the objects
				if objTagHash[i] ~= nil then  																-- do not have this tag.
					assert(objTagHash[i][tagNumber] == nil)
				end 
			end
		end 
	end

	for i = 1,queryTestCount do 
		local size = math.random(1,queryTestMaxSize)														-- how long the query is.
		local query = {} 																					-- build a pretty random query.
		for j = 1,size do 
			local newTag = tagName[math.random(1,tagCount)]
			query[#query+1] = newTag
		end		
		local result = SOE:query(query) or {} 	 															-- do it, replace nil with empty table.
		local matches = 0 																					-- count matches
		for j = 1,objCount do  																				-- work through objects
			if checkQuery(j,query) then  																	-- match found.
				matches = matches + 1 																		-- bump match count
				assert(result[objRef[j]] ~= nil) 															-- check it is in our innternal mirror
			end 
		end
		assert(countItems(result) == matches) 																-- check set size.
	end
end
--SOE:deleteAll()
print("Done.")

