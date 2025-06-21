-- Card utility functions for handLogger mod
local config = require('config')
local utils = require('utils')

local function get_card_info(card)
    if type(card) ~= "table" or type(card.base) ~= "table" then return "Unknown Card" end
    local value = card.base.value
    local suit_id = card.base.suit
    
    local rank = value and utils.get_rank_name(value) or "?"
    local suit_display_name = "Unknown Suit"

    if SMODS and SMODS.Suits and suit_id then
        local suit_data = SMODS.Suits[suit_id]
        if type(suit_data) == "table" and suit_data.name then
            suit_display_name = suit_data.name
        else
            suit_display_name = "Unknown Suit (" .. tostring(suit_id) .. ")"
        end
    elseif suit_id then
        suit_display_name = "Unknown Suit (" .. tostring(suit_id) .. ")"
    end
    
    -- Use abbreviated format for the card name
    local rank_abbr = config.rank_abbrev[rank] or rank
    local suit_abbr = config.suit_abbrev[suit_display_name] or suit_display_name
    local info = rank_abbr .. suit_abbr

    -- Show seal if it is a string or number
    if card.seal ~= nil and (type(card.seal) == "string" or type(card.seal) == "number") and tostring(card.seal) ~= "" then
        local seal_text = tostring(card.seal)
        -- Try to convert seal color to abbreviation
        if config.seal_abbrev[seal_text] then
            seal_text = config.seal_abbrev[seal_text]
        end
        info = info .. "[" .. seal_text .. "]"
    end
    
    -- Show edition (enhancement) if it exists
    if card.edition and type(card.edition) == "table" then
        if card.edition.holo then
            info = info .. "<" .. config.enhancement_abbrev["Holographic"] .. ">"
        elseif card.edition.foil then
            info = info .. "<" .. config.enhancement_abbrev["Foil"] .. ">"
        elseif card.edition.polychrome then
            info = info .. "<" .. config.enhancement_abbrev["Polychrome"] .. ">"
        elseif card.edition.negative then
            info = info .. "<" .. config.enhancement_abbrev["Negative"] .. ">"
        end
    end

    -- Show ability effect (enhancement) if it exists
    if card.ability and type(card.ability) == "table" then
        -- Show if card is wild
        if card.ability.name == "Wild Card" then
            info = info .. "<" .. config.enhancement_abbrev["Wild"] .. ">"
        end
        
        -- Show other effects
        if card.ability.effect then
            if card.ability.effect == "Lucky Card" then
                info = info .. "<" .. config.enhancement_abbrev["Lucky"] .. ">"
            elseif card.ability.effect == "Stone Card" then
                info = info .. "<" .. config.enhancement_abbrev["Stone"] .. ">"
            elseif card.ability.effect == "Glass Card" then
                info = info .. "<" .. config.enhancement_abbrev["Glass"] .. ">"
            end
        end

        -- Show if it's a bonus card (but not if it's a stone card)
        if card.ability.bonus and card.ability.bonus > 0 and not (card.ability.effect == "Stone Card") then
            info = info .. "<" .. config.enhancement_abbrev["Bonus"] .. ">"
        end
    end

    -- Show center enhancement if it exists
    if card.config and type(card.config) == "table" and card.config.center then
        if card.config.center == G.P_CENTERS.m_gold then
            info = info .. "<" .. config.enhancement_abbrev["Gold"] .. ">"
        elseif card.config.center == G.P_CENTERS.m_steel then
            info = info .. "<" .. config.enhancement_abbrev["Steel"] .. ">"
        elseif card.config.center == G.P_CENTERS.m_mult then
            info = info .. "<" .. config.enhancement_abbrev["Suit Mult"] .. ">"
        end
    end
    
    -- Show debuff if card is debuffed
    if utils.is_card_debuffed(card) then
        info = info .. "<D>"
    end
    
    return info
end

local function sort_cards(a, b)
    local suit_a = SMODS.Suits[a.base.suit] and SMODS.Suits[a.base.suit].name or "Unknown"
    local suit_b = SMODS.Suits[b.base.suit] and SMODS.Suits[b.base.suit].name or "Unknown"
    
    local suit_order_a = utils.get_suit_order(suit_a)
    local suit_order_b = utils.get_suit_order(suit_b)
    
    if suit_order_a ~= suit_order_b then
        return suit_order_a < suit_order_b
    end
    
    -- Sort by rank in descending order
    local rank_a = utils.get_rank_value(a.base.value)
    local rank_b = utils.get_rank_value(b.base.value)
    return rank_a > rank_b
end

-- Helper: Get the base chips for a card (rank value)
local function get_card_base_chips(card)
    if not card or not card.base or not card.base.value then return 0 end
    
    -- Stone cards always give +50 chips regardless of rank
    if card.ability and card.ability.effect == "Stone Card" then
        return 50
    end
    
    local v = utils.get_rank_value(card.base.value)
    if v >= 2 and v <= 10 then return v end
    if v == 11 or v == 12 or v == 13 then return 10 end -- J, Q, K = 10
    if v == 14 then return 11 end -- Ace = 11
    return 0
end

return {
    get_card_info = get_card_info,
    sort_cards = sort_cards,
    get_card_base_chips = get_card_base_chips
} 