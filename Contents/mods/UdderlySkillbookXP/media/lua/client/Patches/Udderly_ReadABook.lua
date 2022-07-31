local original_update = ISReadABook.update
local original_new = ISReadABook.new

UdderlySkillbookXP = {};

local whitelistFallback = "Woodwork;Electricity;MetalWelding;Mechanics"

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

local function getXpForLevel(level)
    if level ~= 10 then
        local XPPerPage = 0
        if level == 0 or level == 1 then
            XPPerPage = 0.84
        elseif level == 2 or level == 3 then
            XPPerPage = 3.24
        elseif level == 4 or level == 5 then
            XPPerPage = 12.02
        elseif level == 6 or level == 7 then
            XPPerPage = 24.74
        elseif level == 8 or level == 9 then
            XPPerPage = 34.78
        end
        return XPPerPage
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
    local skillBook = SkillBook[self.item:getSkillTrained()]
    if skillBook then
        local perk = skillBook.perk
        local skillWhitelisted = false
        for i,skill in ipairs(split(SandboxVars.UdderlySkillbookXP.SkillWhitelist or whitelistFallback, ";")) do
            if tostring(perk) == skill then --if this isn't whitelisted
                skillWhitelisted = true
                break
            end
        end
        local level = self.character:getPerkLevel(perk)
        local prePagesRead = self.item:getAlreadyReadPages()
        local u = SandboxVars.UdderlySkillbookXP.Multiplier
        if not skillWhitelisted then
            u = 0 --abort XP
        end
        local player = getPlayer()
        if player:isPlayerMoving() then
            if SandboxVars.UdderlySkillbookXP.ReadWhileWalking then
                u = u * SandboxVars.UdderlySkillbookXP.WalkingMultiplier
            else
                self.character:Say(getText("IGUI_PlayerText_CantFocusWhileMoving"));
                self:forceStop()
            end
        end
        if player:isSitOnGround() then
            u = u * SandboxVars.UdderlySkillbookXP.SittingMultiplier
        end
        if SandboxVars.UdderlySkillbookXP.NeedLight and not sufficientLight(player) then
            self.character:Say(getText("IGUI_PlayerText_TooDark"))
            self:forceStop()
        end

        original_update(self)
        if self.item:getMaxLevelTrained() < level + 1 then
            if self.pageTimer >= 200 then            
                self.pageTimer = 0;
                local txtRandom = ZombRand(2);
                if txtRandom == 0 then
                    self.character:Say(getText("IGUI_PlayerText_KnowSkill"));
                    self:forceStop()                    
                else
                    self.character:Say(getText("IGUI_PlayerText_BookObsolete"));
                    self:forceStop()
                end
            end        
        else       
            local pagesRead = self.item:getAlreadyReadPages() - prePagesRead
            if pagesRead > 0 and level ~= 10 then                   
                self.character:getXp():AddXP(perk, getXpForLevel(level) * pagesRead * u);
            end
        end         
    else
        original_update(self)    
    end
end

function ISReadABook:new(character, item, time)
    -- check for existing saves.
    if SkillBook[item:getSkillTrained()] then
        local player = getPlayer()
        -- if item:getMaxLevelTrained() - 2 > character:getPerkLevel(SkillBook[item:getSkillTrained()].perk) then
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