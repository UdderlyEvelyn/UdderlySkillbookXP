local original_update = ISReadABook.update
local original_new = ISReadABook.new

UdderlySkillbookXP = {};

local whitelistFallback = "Woodwork=1;Electricity=1;MetalWelding=1;Mechanics=1;Cooking=.5;Farming=.5;Doctor=.5;Tailoring=.5;Fishing=.5;Trapping=.5;PlantScavenging=.5;Maintenance=.5;Aiming=.1;Reloading=.1;Sprinting=.1;Sneaking=.1;Lightfooted=.1;Nimble=.1;Axe=.1;Long Blunt=.1;Short Blunt=.1;Long Blade=.1;Short Blade=.1;Spear=.1;Strength=.1;Fitness=.1"

local function sufficientLight(player)
	local leftItem = player:getSecondaryHandItem()
	if leftItem ~= nil and leftItem:isEmittingLight() then
		return true
	end
	local rightItem = player:getPrimaryHandItem()
	if rightItem ~= nil and rightItem:isEmittingLight() then
		return true
	end
	local vehicle = player:getVehicle()
	if vehicle ~= nil and vehicle:getBatteryCharge() > 0 then
		return true
	end
	local playerId = player:getPlayerNum()
	local square = player:getCurrentSquare()
	local colors = {
		square:getVertLight(0, playerId),
		square:getVertLight(1, playerId),
		square:getVertLight(2, playerId),
		square:getVertLight(3, playerId),
		square:getVertLight(4, playerId),
		square:getVertLight(5, playerId),
		square:getVertLight(6, playerId),
		square:getVertLight(7, playerId),
	}
	local light = 0
	for i, color in ipairs(colors) do		
	local hex_str = string.format("%x", color)
		light = math.max(
			tonumber(string.sub(hex_str, 3, 4), 16) or 0, -- "a1"
			tonumber(string.sub(hex_str, 5, 6), 16) or 0, -- "b2"
			tonumber(string.sub(hex_str, 7, 8), 16) or 0, -- "c3"
			light
		)
	end
	if light >= 127 then
		return true
	end
	return false --nothing let them read, so return false.
end

local passiveXPLevelThresholds = { 1500.0, 3000.0, 6000.0, 9000.0, 18000.0, 30000.0, 60000.0, 90000.0, 120000.0, 150000.0 }
local xpLevelThresholds = { 75.0, 150.0, 300.0, 750.0, 1500.0, 3000.0, 4500.0, 6000.0, 7500.0, 9000.0 }

local function getXPForLevel(level, passive)
    passive = passive or false
    if level ~= 10 then
        if not passive then
            return xpLevelThresholds[level]
        else
            return passiveXPLevelThresholds[level]
        end
    end
    return 0
end

local function split(s, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(s, "([^"..sep.."]+)") do
       table.insert(t, str)
    end
    return t
end

function ISReadABook:update()
	print("USBXP: Enter Function")
	local player = getPlayer()
	if SandboxVars.UdderlySkillbookXP.NeedLight and not sufficientLight(player) then
		self.character:Say(getText("IGUI_PlayerText_TooDark"))
		self:forceStop()
		return
	elseif self.character:HasTrait("Illiterate") then
		self.character:Say(getText("IGUI_PlayerText_IlliterateReadAttempt"))
		self:forceStop()
		return
	else
		print("USBXP: Not illiterate and has sufficient light, proceeding..")
		local multiplier = 1
		
		if player:isPlayerMoving() then
		    if SandboxVars.UdderlySkillbookXP.ReadWhileWalking then
                multiplier = SandboxVars.UdderlySkillbookXP.WalkingMultiplier
		    else
                self.character:Say(getText("IGUI_PlayerText_CantFocusWhileMoving"));
                self:forceStop()
		    end
		end
		if player:isSitOnGround() then
		    multiplier = SandboxVars.UdderlySkillbookXP.SittingMultiplier
		end
		
		original_update(self) --Only run original code if we meet light requirements and aren't illiterate.
		
		local skillBook = SkillBook[self.item:getSkillTrained()]
		local skillWhitelisted = false
		local perk = ""
		if skillBook then --If it's a skillbook, process the info about what skill it trains.
			perk = skillBook.perk
			print("USBXP: Is a skillbook for \""..tostring(perk).."\"")
			local tmpMultiplier = 0
			for i,pair in ipairs(split(SandboxVars.UdderlySkillbookXP.SkillWhitelist or whitelistFallback, ";")) do
			print("USBXP: Parsing pair from sandbox options \""..pair.."\"..")
				local pairBits = split(pair, "=")
				local skill = pairBits[1] or ""
				tmpMultiplier = multiplier * tonumber(pairBits[2]) or 0
				print("USBXP: Skill \""..skill.."\", Multiplier "..tmpMultiplier)
				if tostring(perk) == skill and tmpMultiplier > 0 then --if this is whitelisted
					skillWhitelisted = true
					multiplier = tmpMultiplier
					break
				end
			end
		end
		print("USBXP: Skill \""..tostring(perk).."\" Whitelisted: "..tostring(skillWhitelisted))
		
		
		if not skillWhitelisted then --Abort if not whitelisted for XP, we do this here and not earlier because we want to interrupt reading for walking or light level.
		    return
		end
		
		print("USBXP: Skill is whitelisted, proceeding..")
		local level = self.character:getPerkLevel(perk)
		local maxLevelTrained = self.item:getMaxLevelTrained()
		local minLevelTrained = maxLevelTrained - self.item:getNumLevelsTrained()
		local nextLevel = level + 1
		print("USBXP: Level "..level..", Max Trained: "..maxLevelTrained..", Min Trained: "..minLevelTrained..", Next Level "..nextLevel)
		if nextLevel > maxLevelTrained then --If they passed the tier, stop them..
			local phrases = { "IGUI_PlayerText_KnowSkill", "IGUI_PlayerText_BookObsolete" }
			self.character:Say(getText(phrases[ZombRand(2)]));
			self:forceStop()
		elseif nextLevel < minLevelTrained then --If they are under the threshold for this tier, stop them..
			local phrases = { "IGUI_PlayerText_NotReady", "IGUI_PlayerText_TooAdvanced" }
			self.character:Say(getText(phrases[ZombRand(2)]));
			self:forceStop()
		else --They are on the proper tier, continue..
			print("USBXP: Correct tier to receive XP..")
			local passive = perk == Perks.Fitness or perk == Perks.Strength
			local percentRead = self.item:getAlreadyReadPages() / self.item:getNumberOfPages()
			if percentRead > 1 then
				percentRead = 1
			end
			print("USBXP: Percent Read: "..(percentRead * 100).."%")
			local targetLevel = self.item:getLvlSkillTrained() + (self.item:getNumLevelsTrained() * multiplier) - 1
			print("USBXP: Target Level "..targetLevel)
			local targetXP = 0.0
			for i=1,targetLevel do
				targetXP = targetXP + getXPForLevel(i, passive)
			end
			print("USBXP: Full Target XP: "..targetXP)
			targetXP = targetXP * percentRead
			print("USBXP: Target XP: "..targetXP)
			local currentXP = self.character:getXp():getXP(perk)
			print("USBXP: Current XP: "..currentXP)
			local xpToAdd = math.ceil(targetXP - currentXP)
			if percentRead == 1 then
				xpToAdd = xpToAdd + 1
			end
			print("USBXP: XP To Add: "..xpToAdd)
			self.character:getXp():AddXP(perk, xpToAdd);
		end
	end
	print("USBXP: End Function")
end

function ISReadABook:new(character, item, time)
    -- check for existing saves.
    if SkillBook[item:getSkillTrained()] then
        local player = getPlayer()
        -- check if character has been inited before.
        if not player:getModData()['udderly:read:'..item:getName()] then
            item:setAlreadyReadPages(0)
            character:setAlreadyReadPages(item:getFullType(), 0)

            player:getModData()['udderly:read:'..item:getName()] = true
            player:transmitModData()
        end
    end
    -- start working.
    local o = original_new(self, character, item, time)
    o.stopOnWalk = not SandboxVars.UdderlySkillbookXP.ReadWhileWalking
    o.stopOnRun = true
    return o
end