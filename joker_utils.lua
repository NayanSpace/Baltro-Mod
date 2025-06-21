-- Joker utility functions for handLogger mod
local config = require('config')

local function get_joker_info(joker)
    if type(joker) ~= "table" then 
        return "Unknown Joker" 
    end
    
    local info = "Unknown Joker" -- Default value
    local display_data = nil

    -- Prioritize joker.name first for display
    if joker.name and type(joker.name) == "string" and joker.name ~= "" then
        info = joker.name
        display_data = joker
    -- Then fallback to joker.ability.name
    elseif joker.ability and type(joker.ability) == "table" and joker.ability.name and type(joker.ability.name) == "string" then
        info = joker.ability.name
        display_data = joker.ability
    end

    -- If no direct name is found, try to get P_CENTERS data for additional info and possibly a better name
    local joker_key = joker.key or joker.center
    if joker_key and G and G.P_CENTERS and G.P_CENTERS[joker_key] then
        local p_center_data = G.P_CENTERS[joker_key]
        -- Only override info if it's still generic or less specific than P_CENTERS name
        if info == "Unknown Joker" or (p_center_data.name and p_center_data.name ~= info and p_center_data.name ~= joker.ability.name) then
            info = p_center_data.name or info
        end
        display_data = display_data or p_center_data -- Set display_data if not already set
    end
    
    if display_data then
        if display_data.rarity then
            local rarity_name = ""
            if display_data.rarity == 1 then rarity_name = "Common"
            elseif display_data.rarity == 2 then rarity_name = "Uncommon"
            elseif display_data.rarity == 3 then rarity_name = "Rare"
            elseif display_data.rarity == 4 then rarity_name = "Legendary"
            end
            if rarity_name ~= "" then
                info = info .. " [" .. rarity_name .. "]"
            end
        end

        if display_data.config and type(display_data.config) == "table" then
            if display_data.config.mult then info = info .. " Mult:" .. tostring(display_data.config.mult) end
            if display_data.config.Xmult then info = info .. " xMult:" .. tostring(display_data.config.Xmult) end
            if display_data.config.chips then info = info .. " Chips:" .. tostring(display_data.config.chips) end
            if display_data.config.dollars then info = info .. " $:" .. tostring(display_data.config.dollars) end
            
            if display_data.config.extra then
                if type(display_data.config.extra) == "table" then
                    if display_data.config.extra.mult then info = info .. " E.Mult:" .. tostring(display_data.config.extra.mult) end
                    if display_data.config.extra.Xmult then info = info .. " E.xMult:" .. tostring(display_data.config.extra.Xmult) end
                    if display_data.config.extra.chips then info = info .. " E.Chips:" .. tostring(display_data.config.extra.chips) end
                    if display_data.config.extra.dollars then info = info .. " E.$:" .. tostring(display_data.config.extra.dollars) end
                    if display_data.config.extra.odds then info = info .. " E.Odds:" .. tostring(display_data.config.extra.odds) end
                    if display_data.config.extra.h_size then info = info .. " E.H.Size:" .. tostring(display_data.config.extra.h_size) end
                    if display_data.config.extra.d_size then info = info .. " E.D.Size:" .. tostring(display_data.config.extra.d_size) end
                    if display_data.config.extra.poker_hand then info = info .. " E.Hand:" .. tostring(display_data.config.extra.poker_hand) end
                    if display_data.config.extra.s_mult then info = info .. " E.Suit Mult:" .. tostring(display_data.config.extra.s_mult) end
                    if display_data.config.extra.suit then info = info .. " E.Suit:" .. tostring(display_data.config.extra.suit) end
                    if display_data.config.extra.t_mult then info = info .. " E.Type Mult:" .. tostring(display_data.config.extra.t_mult) end
                    if display_data.config.extra.type then info = info .. " E.Type:" .. tostring(display_data.config.extra) end
                    if display_data.config.extra.chip_mod then info = info .. " E.Chip Mod:" .. tostring(display_data.config.extra.chip_mod) end
                    if display_data.config.extra.h_plays then info = info .. " E.Hand Plays:" .. tostring(display_data.config.extra.h_plays) end
                    if display_data.config.extra.hand_add then info = info .. " E.Hand Add:" .. tostring(display_data.config.extra.hand_add) end
                    if display_data.config.extra.discard_sub then info = info .. " E.Discard Sub:" .. tostring(display_data.config.extra.discard_sub) end
                    if display_data.config.extra.faces then info = info .. " E.Faces:" .. tostring(display_data.config.extra.faces) end
                    if display_data.config.extra.increase then info = info .. " E.Increase:" .. tostring(display_data.config.extra.increase) end
                else
                    info = info .. " Extra:" .. tostring(display_data.config.extra)
                end
            end
        end

        if display_data.unlock_condition and type(display_data.unlock_condition) == "table" then
            info = info .. " [Unlock: " .. tostring(display_data.unlock_condition.type)
            if display_data.unlock_condition.extra then
                info = info .. " " .. tostring(display_data.unlock_condition.extra)
            end
            info = info .. "]"
        end
    end
    return info
end

return {
    get_joker_info = get_joker_info
} 