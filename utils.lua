-- Utility functions for handLogger mod
local config = require('config')

-- Helper: Get the number of blinds skipped this run
local function get_blinds_skipped_count()
    if G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states then
        local count = 0
        for _, state in pairs(G.GAME.round_resets.blind_states) do
            if state == "Skipped" then
                count = count + 1
            end
        end
        return count
    end
    return 0
end

local function get_rounds_played()
    if G and G.GAME and G.GAME.completed_rounds then
        return G.GAME.completed_rounds
    end
    return 0
end

local function get_rank_name(rank_index)
    -- card.base.value is 1 for Ace, 11 for Jack, 12 for Queen, 13 for King
    return config.rank_names[rank_index] or (tostring(rank_index))
end

local function get_suit_order(suit_name)
    for i, suit in ipairs(config.suit_order) do
        if suit == suit_name then
            return i
        end
    end
    return 5 -- Unknown suits go last
end

local function get_rank_value(value)
    -- If value is a string, convert it to the corresponding number
    if type(value) == "string" then
        local lookup = {
            ["Ace"] = 14,
            ["King"] = 13,
            ["Queen"] = 12,
            ["Jack"] = 11,
            ["10"] = 10,
            ["9"] = 9,
            ["8"] = 8,
            ["7"] = 7,
            ["6"] = 6,
            ["5"] = 5,
            ["4"] = 4,
            ["3"] = 3,
            ["2"] = 2
        }
        return lookup[value] or tonumber(value) or 0
    end
    if value == 1 then return 14 end  -- Ace
    return value
end

-- Helper: Get the debuffed suit from the current boss blind (if any)
local function get_debuffed_suit()
    if G and G.GAME and G.GAME.blind and G.GAME.blind.loc_debuff_text then
        local text = G.GAME.blind.loc_debuff_text:lower()
        if text:find("diamond") then return "Diamonds" end
        if text:find("spade") then return "Spades" end
        if text:find("club") then return "Clubs" end
        if text:find("heart") then return "Hearts" end
    end
    return nil
end

-- Helper: Get the debuffed rank from the current boss blind (if any)
local function get_debuffed_rank()
    if G and G.GAME and G.GAME.blind and G.GAME.blind.loc_debuff_text then
        local text = G.GAME.blind.loc_debuff_text:lower()
        -- Check for full rank names
        for _, rank_name in ipairs(config.rank_names) do
            local pattern = "\b" .. rank_name:lower() .. "\b"
            if text:find(pattern) then
                return rank_name
            end
        end
        -- Check for rank abbreviations
        for rank, abbrev in pairs(config.rank_abbrev) do
            local pattern = "\b" .. abbrev:lower() .. "\b"
            if text:find(pattern) then
                return rank
            end
        end
    end
    return nil
end

-- Helper: Check if a card is debuffed
local function is_card_debuffed(card)
    local debuffed_suit = get_debuffed_suit()
    local debuffed_rank = get_debuffed_rank()
    if not debuffed_suit and not debuffed_rank then return false end

    local suit_matches = false
    if debuffed_suit and SMODS and SMODS.Suits and card.base.suit then
        local suit_data = SMODS.Suits[card.base.suit]
        if suit_data and suit_data.name == debuffed_suit then
            suit_matches = true
        end
    end

    local rank_matches = false
    if debuffed_rank and card.base.value then
        if get_rank_name(card.base.value) == debuffed_rank then
            rank_matches = true
        end
    end

    return suit_matches or rank_matches
end

local function clamp(val, min, max)
    return math.max(min, math.min(val, max))
end

-- Helper: Check if a combo type is blocked by the current boss blind
local function is_combo_type_blocked_by_blind(combo_name)
    if G and G.GAME and G.GAME.blind and G.GAME.blind.loc_debuff_text then
        local text = G.GAME.blind.loc_debuff_text:lower()
        -- Common blocked hands by text. Add more as needed based on actual blind texts.
        if combo_name == "Straight" and (text:find("no straight") or text:find("straights cannot be played")) then return true end
        if combo_name == "Flush" and (text:find("no flush") or text:find("flushes cannot be played")) then return true end
        if combo_name == "Straight Flush" and (text:find("no straight flush") or text:find("straight flushes cannot be played")) then return true end
        if combo_name == "Royal Flush" and (text:find("no royal flush") or text:find("royal flushes cannot be played")) then return true end
        -- More complex conditions for combined phrases or specific hand types will need further analysis
    end
    return false
end

return {
    get_blinds_skipped_count = get_blinds_skipped_count,
    get_rounds_played = get_rounds_played,
    get_rank_name = get_rank_name,
    get_suit_order = get_suit_order,
    get_rank_value = get_rank_value,
    get_debuffed_suit = get_debuffed_suit,
    get_debuffed_rank = get_debuffed_rank,
    is_card_debuffed = is_card_debuffed,
    clamp = clamp,
    is_combo_type_blocked_by_blind = is_combo_type_blocked_by_blind
} 