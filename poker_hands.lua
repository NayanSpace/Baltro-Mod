-- Poker hand checking functions for handLogger mod
local utils = require('utils')

-- Poker hand checking functions
local function check_flush(cards)
    if #cards < 5 then return false end
    
    -- First, find a non-wild card to determine the target suit
    local target_suit = nil
    for _, card in ipairs(cards) do
        if not (card.ability and card.ability.name == "Wild Card") then
            target_suit = card.base.suit
            break
        end
    end
    
    -- If all cards are wild, it's not a flush
    if not target_suit then return false end
    
    -- Count how many cards match the target suit or are wild
    local matching_cards = 0
    for _, card in ipairs(cards) do
        if card.base.suit == target_suit or (card.ability and card.ability.name == "Wild Card") then
            matching_cards = matching_cards + 1
        end
    end
    
    return matching_cards >= 5
end

local function check_straight(cards)
    if #cards < 5 then return false end
    local unique_values = {}
    for _, card in ipairs(cards) do
        unique_values[utils.get_rank_value(card.base.value)] = true
    end
    local values = {}
    for val, _ in pairs(unique_values) do
        table.insert(values, val)
    end
    table.sort(values, function(a, b) return a > b end)
    -- Check for Ace-high straight (14, 13, 12, 11, 10)
    local ace_high = {14, 13, 12, 11, 10}
    local found_ace_high = true
    for _, v in ipairs(ace_high) do
        if not unique_values[v] then found_ace_high = false break end
    end
    if found_ace_high then return true end
    -- Check for Ace-low straight (14, 5, 4, 3, 2)
    local ace_low = {14, 5, 4, 3, 2}
    local found_ace_low = true
    for _, v in ipairs(ace_low) do
        if not unique_values[v] then found_ace_low = false break end
    end
    if found_ace_low then return true end
    -- Check for any other straight
    for i = 1, #values - 4 do
        local is_straight = true
        for j = 0, 3 do
            if values[i + j] - 1 ~= values[i + j + 1] then
                is_straight = false
                break
            end
        end
        if is_straight then return true end
    end
    return false
end

local function check_royal_flush(cards)
    if not check_flush(cards) then return false end
    local values = {}
    for _, card in ipairs(cards) do
        values[utils.get_rank_value(card.base.value)] = true
    end
    return values[14] and values[13] and values[12] and values[11] and values[10]
end

local function check_straight_flush(cards)
    return check_flush(cards) and check_straight(cards)
end

local function check_four_of_a_kind(cards)
    local value_counts = {}
    for _, card in ipairs(cards) do
        value_counts[card.base.value] = (value_counts[card.base.value] or 0) + 1
    end
    for _, count in pairs(value_counts) do
        if count >= 4 then return true end
    end
    return false
end

local function check_full_house(cards)
    local value_counts = {}
    for _, card in ipairs(cards) do
        value_counts[card.base.value] = (value_counts[card.base.value] or 0) + 1
    end
    local has_three = false
    local has_pair = false
    for _, count in pairs(value_counts) do
        if count >= 3 then has_three = true
        elseif count >= 2 then has_pair = true end
    end
    return has_three and has_pair
end

local function check_three_of_a_kind(cards)
    local value_counts = {}
    for _, card in ipairs(cards) do
        value_counts[card.base.value] = (value_counts[card.base.value] or 0) + 1
    end
    for _, count in pairs(value_counts) do
        if count >= 3 then return true end
    end
    return false
end

local function check_two_pair(cards)
    local value_counts = {}
    local pair_count = 0
    for _, card in ipairs(cards) do
        value_counts[card.base.value] = (value_counts[card.base.value] or 0) + 1
    end
    for _, count in pairs(value_counts) do
        if count >= 2 then pair_count = pair_count + 1 end
    end
    return pair_count >= 2
end

local function check_pair(cards)
    local value_counts = {}
    for _, card in ipairs(cards) do
        value_counts[card.base.value] = (value_counts[card.base.value] or 0) + 1
    end
    for _, count in pairs(value_counts) do
        if count >= 2 then return true end
    end
    return false
end

-- Poker hand combinations
local poker_hands = {
    {name = "Royal Flush", check = check_royal_flush},
    {name = "Straight Flush", check = check_straight_flush},
    {name = "Four of a Kind", check = check_four_of_a_kind},
    {name = "Full House", check = check_full_house},
    {name = "Flush", check = check_flush},
    {name = "Straight", check = check_straight},
    {name = "Three of a Kind", check = check_three_of_a_kind},
    {name = "Two Pair", check = check_two_pair},
    {name = "Pair", check = check_pair}
}

return {
    poker_hands = poker_hands,
    check_flush = check_flush,
    check_straight = check_straight,
    check_royal_flush = check_royal_flush,
    check_straight_flush = check_straight_flush,
    check_four_of_a_kind = check_four_of_a_kind,
    check_full_house = check_full_house,
    check_three_of_a_kind = check_three_of_a_kind,
    check_two_pair = check_two_pair,
    check_pair = check_pair
} 