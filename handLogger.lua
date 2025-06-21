--- STEAMODDED HEADER
--- MOD_NAME: Hand Logger
--- MOD_ID: handLogger
--- MOD_AUTHOR: [navindoor]
--- MOD_DESCRIPTION: Logs the cards in your hand to the console whenever it changes
--- VERSION: 1.0.0


function SMODS.INIT()
    SMODS.add_mod("Card Tracker", "CardTracker", "navindoor", "1.0.0")
end

local scroll_offset = 0
local scroll_offset2 = 0
local combo_scroll_offset = 0
local combo_level_scroll_offset = 0
local joker_scroll_offset = 0

local rank_names = { "Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King" }
local suit_order = { "Spades", "Hearts", "Clubs", "Diamonds" }

-- Add rank and suit abbreviation mappings
local rank_abbrev = {
    ["Ace"] = "A",
    ["2"] = "2",
    ["3"] = "3",
    ["4"] = "4",
    ["5"] = "5",
    ["6"] = "6",
    ["7"] = "7",
    ["8"] = "8",
    ["9"] = "9",
    ["10"] = "T",
    ["Jack"] = "J",
    ["Queen"] = "Q",
    ["King"] = "K"
}

local suit_abbrev = {
    ["Spades"] = "S",
    ["Hearts"] = "H",
    ["Clubs"] = "C",
    ["Diamonds"] = "D"
}

-- Add abbreviation mappings for enhancements, editions, and seals
local enhancement_abbrev = {
    ["Holographic"] = "H",
    ["Foil"] = "F",
    ["Polychrome"] = "P",
    ["Negative"] = "N",
    ["Gold"] = "G",
    ["Steel"] = "S",
    ["Lucky"] = "L",
    ["Stone"] = "ST",
    ["Glass"] = "GL",
    ["Suit Mult"] = "M",
    ["Wild"] = "W",
    ["Bonus"] = "B"
}

-- Add seal color abbreviations
local seal_abbrev = {
    ["Red"] = "R",
    ["Blue"] = "B",
    ["Gold"] = "G",
    ["Purple"] = "P",
}

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

local function get_rank_name(rank_index)
    -- card.base.value is 1 for Ace, 11 for Jack, 12 for Queen, 13 for King
    return rank_names[rank_index] or (tostring(rank_index))
end

local function get_suit_order(suit_name)
    for i, suit in ipairs(suit_order) do
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
        for _, rank_name in ipairs(rank_names) do
            local pattern = "\b" .. rank_name:lower() .. "\b"
            if text:find(pattern) then
                return rank_name
            end
        end
        -- Check for rank abbreviations
        for rank, abbrev in pairs(rank_abbrev) do
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

local function get_card_info(card)
    if type(card) ~= "table" or type(card.base) ~= "table" then return "Unknown Card" end
    local value = card.base.value
    local suit_id = card.base.suit
    
    local rank = value and get_rank_name(value) or "?"
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
    local rank_abbr = rank_abbrev[rank] or rank
    local suit_abbr = suit_abbrev[suit_display_name] or suit_display_name
    local info = rank_abbr .. suit_abbr

    -- Show seal if it is a string or number
    if card.seal ~= nil and (type(card.seal) == "string" or type(card.seal) == "number") and tostring(card.seal) ~= "" then
        local seal_text = tostring(card.seal)
        -- Try to convert seal color to abbreviation
        if seal_abbrev[seal_text] then
            seal_text = seal_abbrev[seal_text]
        end
        info = info .. "[" .. seal_text .. "]"
    end
    
    -- Show edition (enhancement) if it exists
    if card.edition and type(card.edition) == "table" then
        if card.edition.holo then
            info = info .. "<" .. enhancement_abbrev["Holographic"] .. ">"
        elseif card.edition.foil then
            info = info .. "<" .. enhancement_abbrev["Foil"] .. ">"
        elseif card.edition.polychrome then
            info = info .. "<" .. enhancement_abbrev["Polychrome"] .. ">"
        elseif card.edition.negative then
            info = info .. "<" .. enhancement_abbrev["Negative"] .. ">"
        end
    end

    -- Show ability effect (enhancement) if it exists
    if card.ability and type(card.ability) == "table" then
        -- Show if card is wild
        if card.ability.name == "Wild Card" then
            info = info .. "<" .. enhancement_abbrev["Wild"] .. ">"
        end
        
        -- Show other effects
        if card.ability.effect then
            if card.ability.effect == "Lucky Card" then
                info = info .. "<" .. enhancement_abbrev["Lucky"] .. ">"
            elseif card.ability.effect == "Stone Card" then
                info = info .. "<" .. enhancement_abbrev["Stone"] .. ">"
            elseif card.ability.effect == "Glass Card" then
                info = info .. "<" .. enhancement_abbrev["Glass"] .. ">"
            end
        end

        -- Show if it's a bonus card (but not if it's a stone card)
        if card.ability.bonus and card.ability.bonus > 0 and not (card.ability.effect == "Stone Card") then
            info = info .. "<" .. enhancement_abbrev["Bonus"] .. ">"
        end
    end

    -- Show center enhancement if it exists
    if card.config and type(card.config) == "table" and card.config.center then
        if card.config.center == G.P_CENTERS.m_gold then
            info = info .. "<" .. enhancement_abbrev["Gold"] .. ">"
        elseif card.config.center == G.P_CENTERS.m_steel then
            info = info .. "<" .. enhancement_abbrev["Steel"] .. ">"
        elseif card.config.center == G.P_CENTERS.m_mult then
            info = info .. "<" .. enhancement_abbrev["Suit Mult"] .. ">"
        end
    end
    
    -- Show debuff if card is debuffed
    if is_card_debuffed(card) then
        info = info .. "<D>"
    end
    
    return info
end

local function sort_cards(a, b)
    local suit_a = SMODS.Suits[a.base.suit] and SMODS.Suits[a.base.suit].name or "Unknown"
    local suit_b = SMODS.Suits[b.base.suit] and SMODS.Suits[b.base.suit].name or "Unknown"
    
    local suit_order_a = get_suit_order(suit_a)
    local suit_order_b = get_suit_order(suit_b)
    
    if suit_order_a ~= suit_order_b then
        return suit_order_a < suit_order_b
    end
    
    -- Sort by rank in descending order
    local rank_a = get_rank_value(a.base.value)
    local rank_b = get_rank_value(b.base.value)
    return rank_a > rank_b
end

local function clamp(val, min, max)
    return math.max(min, math.min(val, max))
end

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
        unique_values[get_rank_value(card.base.value)] = true
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
        values[get_rank_value(card.base.value)] = true
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

-- Helper: Get the base chips and multiplier for a combo from G.GAME.hands
local function get_combo_base(combo_name)
    if G and G.GAME and G.GAME.hands and G.GAME.hands[combo_name] then
        local hand = G.GAME.hands[combo_name]
        local chips = hand.chips or 0
        local mult = hand.mult or 1
        return chips, mult
    end
    return 0, 1
end

-- Helper: Get the base chips for a card (rank value)
local function get_card_base_chips(card)
    if not card or not card.base or not card.base.value then return 0 end
    
    -- Stone cards always give +50 chips regardless of rank
    if card.ability and card.ability.effect == "Stone Card" then
        return 50
    end
    
    local v = get_rank_value(card.base.value)
    if v >= 2 and v <= 10 then return v end
    if v == 11 or v == 12 or v == 13 then return 10 end -- J, Q, K = 10
    if v == 14 then return 11 end -- Ace = 11
    return 0
end

-- Helper: Filter only relevant cards for certain hand types, but always include Stone cards for scoring
local function filter_relevant_combo_cards(hand_name, combo_cards)
    local value_counts = {}
    for _, card in ipairs(combo_cards) do
        local v = card.base.value
        value_counts[v] = (value_counts[v] or {})
        table.insert(value_counts[v], card)
    end
    local relevant = {}
    if hand_name == "Pair" then
        for _, cards in pairs(value_counts) do
            if #cards == 2 then
                for _, c in ipairs(cards) do table.insert(relevant, c) end
                break
            end
        end
    elseif hand_name == "Two Pair" then
        for _, cards in pairs(value_counts) do
            if #cards == 2 then
                for _, c in ipairs(cards) do table.insert(relevant, c) end
            end
        end
    elseif hand_name == "Three of a Kind" then
        for _, cards in pairs(value_counts) do
            if #cards == 3 then
                for _, c in ipairs(cards) do table.insert(relevant, c) end
                break
            end
        end
    elseif hand_name == "Four of a Kind" then
        for _, cards in pairs(value_counts) do
            if #cards == 4 then
                for _, c in ipairs(cards) do table.insert(relevant, c) end
                break
            end
        end
    else
        -- For other hands, use all cards
        for _, c in ipairs(combo_cards) do table.insert(relevant, c) end
    end
    -- Always include Stone cards for scoring (but not for display)
    local for_scoring = {}
    for _, c in ipairs(combo_cards) do
        if c.ability and c.ability.effect == "Stone Card" then
            table.insert(for_scoring, c)
        end
    end
    -- Add relevant cards (avoid duplicates)
    local seen = {}
    for _, c in ipairs(relevant) do
        seen[c] = true
        table.insert(for_scoring, c)
    end
    return relevant, for_scoring
end

-- Helper: Calculate the score for a 5-card combo (Balatro style)
local function calculate_combo_score(combo_name, cards, sorted_jokers)
    local hand_chips, hand_mult = get_combo_base(combo_name)
    local total_chips = hand_chips
    local total_mult = hand_mult

    -- First apply glass card multipliers from cards in the combo
    for _, card in ipairs(cards) do
        if not is_card_debuffed(card) and card.config and card.config.center == G.P_CENTERS.m_glass then
            total_mult = total_mult * 2
        end
    end

    -- Then calculate chips and additive multipliers from cards in the combo
    for _, card in ipairs(cards) do
        local card_chips = 0
        if not is_card_debuffed(card) then
            card_chips = get_card_base_chips(card)
            if card.edition and card.edition.holo then card_chips = card_chips + 10 end
            if card.edition and card.edition.foil then card_chips = card_chips + 5 end
            if card.ability and type(card.ability) == "table" then
                if card.ability.bonus and card.ability.bonus > 0 and not (card.ability.effect == "Stone Card") then
                    card_chips = card_chips + 30
                end
            end
            if card.config and card.config.center == G.P_CENTERS.m_mult then
                total_mult = total_mult + 4
            end
        end
        if card.ability and card.ability.effect == "Stone Card" then
            card_chips = card_chips + 50
        end
        total_chips = total_chips + card_chips
    end

    -- Apply steel card multiplier from cards in hand but not in combo
    if G and G.hand and G.hand.cards then
        for _, card in ipairs(G.hand.cards) do
            local is_in_combo = false
            for _, combo_card in ipairs(cards) do
                if card == combo_card then is_in_combo = true break end
            end
            if not is_in_combo and card.config and card.config.center == G.P_CENTERS.m_steel then
                total_mult = total_mult * 1.5
            end
        end
    end

    -- Split jokers into 'when scored' and 'other' jokers
    local when_scored_jokers = {}
    local other_jokers = {}
    for _, joker in ipairs(sorted_jokers or {}) do
        local name = joker.ability and joker.ability.name
        if name == "Smiley Face" or name == "Photograph" then
            table.insert(when_scored_jokers, joker)
        else
            table.insert(other_jokers, joker)
        end
    end

    -- For face cards, apply 'when scored' jokers in order for each face card
    local face_card_indices = {}
    for idx, card in ipairs(cards) do
        if card.base and (card.base.id == 11 or card.base.id == 12 or card.base.id == 13) then
            table.insert(face_card_indices, idx)
        end
    end
    local photograph_used = false
    for i, idx in ipairs(face_card_indices) do
        for _, joker in ipairs(when_scored_jokers) do
            if joker.ability and joker.ability.name == "Smiley Face" then
                total_mult = total_mult + 5
            elseif joker.ability and joker.ability.name == "Photograph" and not photograph_used then
                total_mult = total_mult * 2
                photograph_used = true
            end
        end
    end

    -- Then apply all other jokers in order
    for _, joker in ipairs(other_jokers) do
        local name = joker.ability and joker.ability.name
        
        -- Half Joker: +20 mult if hand has 3 or fewer cards
        if name == "Half Joker" then
            if #cards <= 3 then
                total_mult = total_mult + 20
            end
        -- Ice Cream: +100 chips (increases each time it's used)
        elseif name == "Ice Cream" then
            local current_chips = joker.ability.extra and joker.ability.extra.chips or 100
            total_chips = total_chips + current_chips
        -- Throwback: +25% mult per blind skipped
        elseif name == "Throwback" then
            local skips = (G and G.GAME and G.GAME.skips) or 0
            local throwback_mult = 1 + 0.25 * skips
            total_mult = total_mult * throwback_mult
        -- Scary Face: +30 chips per face card
        elseif name == "Scary Face" then
            local face_count = 0
            for _, card in ipairs(cards) do
                if card.base and (card.base.id == 11 or card.base.id == 12 or card.base.id == 13) then
                    face_count = face_count + 1
                end
            end
            total_chips = total_chips + (30 * face_count)
        -- Greedy Joker: +3 mult for Diamonds
        elseif name == "Greedy Joker" then
            local diamond_count = 0
            for _, card in ipairs(cards) do
                if card.base and card.base.suit == "Diamonds" then
                    diamond_count = diamond_count + 1
                end
            end
            total_mult = total_mult + (3 * diamond_count)
        -- Lusty Joker: +3 mult for Hearts
        elseif name == "Lusty Joker" then
            local heart_count = 0
            for _, card in ipairs(cards) do
                if card.base and card.base.suit == "Hearts" then
                    heart_count = heart_count + 1
                end
            end
            total_mult = total_mult + (3 * heart_count)
        -- Wrathful Joker: +3 mult for Spades
        elseif name == "Wrathful Joker" then
            local spade_count = 0
            for _, card in ipairs(cards) do
                if card.base and card.base.suit == "Spades" then
                    spade_count = spade_count + 1
                end
            end
            total_mult = total_mult + (3 * spade_count)
        -- Gluttonous Joker: +3 mult for Clubs
        elseif name == "Gluttonous Joker" then
            local club_count = 0
            for _, card in ipairs(cards) do
                if card.base and card.base.suit == "Clubs" then
                    club_count = club_count + 1
                end
            end
            total_mult = total_mult + (3 * club_count)
        -- Jolly Joker: +8 mult if hand contains a Pair
        elseif name == "Jolly Joker" then
            if combo_name == "Pair" or combo_name == "Two Pair" or combo_name == "Three of a Kind" or combo_name == "Four of a Kind" or combo_name == "Full House" then
                total_mult = total_mult + 8
            end
        -- Zany Joker: +12 mult if hand contains a Three of a Kind
        elseif name == "Zany Joker" then
            if combo_name == "Three of a Kind" or combo_name == "Four of a Kind" or combo_name == "Full House" then
                total_mult = total_mult + 12
            end
        -- Mad Joker: +20 mult if hand contains a Four of a Kind
        elseif name == "Mad Joker" then
            if combo_name == "Four of a Kind" then
                total_mult = total_mult + 20
            end
        -- Crazy Joker: +12 mult if hand contains a Straight
        elseif name == "Crazy Joker" then
            if combo_name == "Straight" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                total_mult = total_mult + 12
            end
        -- Droll Joker: +10 mult if hand contains a Flush
        elseif name == "Droll Joker" then
            if combo_name == "Flush" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                total_mult = total_mult + 10
            end
        -- Sly Joker: +50 chips if hand contains a Pair
        elseif name == "Sly Joker" then
            if combo_name == "Pair" or combo_name == "Two Pair" or combo_name == "Three of a Kind" or combo_name == "Four of a Kind" or combo_name == "Full House" then
                total_chips = total_chips + 50
            end
        -- Wily Joker: +100 chips if hand contains a Three of a Kind
        elseif name == "Wily Joker" then
            if combo_name == "Three of a Kind" or combo_name == "Four of a Kind" or combo_name == "Full House" then
                total_chips = total_chips + 100
            end
        -- Clever Joker: +150 chips if hand contains a Four of a Kind
        elseif name == "Clever Joker" then
            if combo_name == "Two Pair" or combo_name == "Full House" then
                total_chips = total_chips + 150
            end
        -- Devious Joker: +100 chips if hand contains a Straight
        elseif name == "Devious Joker" then
            if combo_name == "Straight" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                total_chips = total_chips + 100
            end
        -- Crafty Joker: +150 chips if hand contains a Flush
        elseif name == "Crafty Joker" then
            if combo_name == "Flush" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                total_chips = total_chips + 150
            end
        -- Joker Stencil: +4 mult per joker
        elseif name == "Joker Stencil" then
            local joker_count = 0
            if G and G.jokers and G.jokers.cards then
                joker_count = #G.jokers.cards
            end
            total_mult = total_mult + (4 * joker_count)
        -- Four Fingers: +10 mult if hand has exactly 4 cards
        elseif name == "Four Fingers" then
            if #cards == 4 then
                total_mult = total_mult + 10
            end
        -- Mime: +15 mult if hand has exactly 5 cards
        elseif name == "Mime" then
            if #cards == 5 then
                total_mult = total_mult + 15
            end
        -- Ceremonial Dagger: +3 mult per card destroyed this run
        elseif name == "Ceremonial Dagger" then
            local destroyed_count = (G and G.GAME and G.GAME.destroyed_cards) or 0
            total_mult = total_mult + (3 * destroyed_count)
        -- Banner: +4 chips per discard remaining
        elseif name == "Banner" then
            local discards_left = (G and G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left) or 0
            total_chips = total_chips + (4 * discards_left)
        -- Mystic Summit: +8 mult if 1 discard remaining
        elseif name == "Mystic Summit" then
            local discards_left = (G and G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left) or 0
            if discards_left == 1 then
                total_mult = total_mult + 8
            end
        -- Loyalty Card: +2 mult every 4 hands played
        elseif name == "Loyalty Card" then
            local hands_played = (G and G.GAME and G.GAME.hands_played) or 0
            local loyalty_bonus = math.floor(hands_played / 4) * 2
            total_mult = total_mult + loyalty_bonus
        -- Misprint: Random mult between 1-4
        elseif name == "Misprint" then
            local random_mult = math.random(1, 4)
            total_mult = total_mult + random_mult
        -- Dusk: +2 mult per card in hand
        elseif name == "Dusk" then
            total_mult = total_mult + (2 * #cards)
        -- Raised Fist: Adds double the rank of lowest card held in hand to Mult
        elseif name == "Raised Fist" then
            local lowest_rank = 14 -- Start with Ace (highest)
            for _, card in ipairs(cards) do
                if card.base and card.base.id then
                    local rank = card.base.id
                    if rank < lowest_rank then
                        lowest_rank = rank
                    end
                end
            end
            if lowest_rank < 14 then -- If we found a card
                total_mult = total_mult + (2 * lowest_rank)
            end
        -- Fibonacci: +1 mult per card in hand (Fibonacci sequence)
        elseif name == "Fibonacci" then
            local fib_mult = 0
            for i = 1, #cards do
                if i <= 10 then -- First 10 Fibonacci numbers
                    local fib = {1, 1, 2, 3, 5, 8, 13, 21, 34, 55}
                    fib_mult = fib_mult + fib[i]
                end
            end
            total_mult = total_mult + fib_mult
        -- Steel Joker: +2 mult per steel card in hand
        elseif name == "Steel Joker" then
            local steel_count = 0
            for _, card in ipairs(cards) do
                if card.config and card.config.center and card.config.center.name == "Steel Card" then
                    steel_count = steel_count + 1
                end
            end
            total_mult = total_mult + (2 * steel_count)
        -- Campfire: +2 mult per joker
        elseif name == "Campfire" then
            local joker_count = 0
            if G and G.jokers and G.jokers.cards then
                joker_count = #G.jokers.cards
            end
            total_mult = total_mult + (2 * joker_count)
        -- Mr. Bones: +4 mult if hand has exactly 5 cards
        elseif name == "Mr. Bones" then
            if #cards == 5 then
                total_mult = total_mult + 4
            end
        -- Acrobat: +8 mult if no hands remaining
        elseif name == "Acrobat" then
            local hands_left = (G and G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left) or 0
            if hands_left == 0 then
                total_mult = total_mult + 8
            end
        -- Sock and Buskin: +6 mult if hand has exactly 5 cards
        elseif name == "Sock and Buskin" then
            if #cards == 5 then
                total_mult = total_mult + 6
            end
        -- Swashbuckler: +3 mult per card in hand
        elseif name == "Swashbuckler" then
            total_mult = total_mult + (3 * #cards)
        -- Smeared Joker: +2 mult per card in hand
        elseif name == "Smeared Joker" then
            total_mult = total_mult + (2 * #cards)
        -- Hanging Chad: +4 mult if hand has exactly 4 cards
        elseif name == "Hanging Chad" then
            if #cards == 4 then
                total_mult = total_mult + 4
            end
        -- Bloodstone: +2 mult per card in hand
        elseif name == "Bloodstone" then
            total_mult = total_mult + (2 * #cards)
        -- Arrowhead: +3 mult per card in hand
        elseif name == "Arrowhead" then
            total_mult = total_mult + (3 * #cards)
        -- Onyx Agate: +2 mult per card in hand
        elseif name == "Onyx Agate" then
            total_mult = total_mult + (2 * #cards)
        -- Glass Joker: +4 mult per card in hand
        elseif name == "Glass Joker" then
            total_mult = total_mult + (4 * #cards)
        -- Flower Pot: +8 mult if all 4 suits present
        elseif name == "Flower Pot" then
            local suits = {Hearts = false, Diamonds = false, Spades = false, Clubs = false}
            for _, card in ipairs(cards) do
                if card.base and card.base.suit then
                    suits[card.base.suit] = true
                end
            end
            if suits.Hearts and suits.Diamonds and suits.Spades and suits.Clubs then
                total_mult = total_mult + 8
            end
        -- Blueprint: +2 mult per joker
        elseif name == "Blueprint" then
            local joker_count = 0
            if G and G.jokers and G.jokers.cards then
                joker_count = #G.jokers.cards
            end
            total_mult = total_mult + (2 * joker_count)
        -- Wee Joker: +1 mult per card in hand
        elseif name == "Wee Joker" then
            total_mult = total_mult + #cards
        -- The Idol: +4 mult if specific card is in hand
        elseif name == "The Idol" then
            local idol_card = (G and G.GAME and G.GAME.current_round and G.GAME.current_round.idol_card) or nil
            if idol_card then
                for _, card in ipairs(cards) do
                    if card.base and card.base.value == idol_card.rank and card.base.suit == idol_card.suit then
                        total_mult = total_mult + 4
                        break
                    end
                end
            end
        -- Seeing Double: +6 mult if all 4 suits present
        elseif name == "Seeing Double" then
            local suits = {Hearts = false, Diamonds = false, Spades = false, Clubs = false}
            for _, card in ipairs(cards) do
                if card.base and card.base.suit then
                    suits[card.base.suit] = true
                end
            end
            if suits.Hearts and suits.Diamonds and suits.Spades and suits.Clubs then
                total_mult = total_mult + 6
            end
        -- Hit the Road: +3 mult per card in hand
        elseif name == "Hit the Road" then
            total_mult = total_mult + (3 * #cards)
        -- The Duo: +4 mult for Two Pair
        elseif name == "The Duo" then
            if combo_name == "Two Pair" then
                total_mult = total_mult + 4
            end
        -- The Trio: +4 mult for Three of a Kind
        elseif name == "The Trio" then
            if combo_name == "Three of a Kind" then
                total_mult = total_mult + 4
            end
        -- The Family: +4 mult for Full House
        elseif name == "The Family" then
            if combo_name == "Full House" then
                total_mult = total_mult + 4
            end
        -- The Order: +4 mult for Straight
        elseif name == "The Order" then
            if combo_name == "Straight" then
                total_mult = total_mult + 4
            end
        -- The Tribe: +4 mult for Flush
        elseif name == "The Tribe" then
            if combo_name == "Flush" then
                total_mult = total_mult + 4
            end
        -- Stuntman: +250 chips, -2 hand size
        elseif name == "Stuntman" then
            total_chips = total_chips + 250
            -- Note: Hand size reduction would need to be handled elsewhere
        -- Brainstorm: +3 mult per joker
        elseif name == "Brainstorm" then
            local joker_count = 0
            if G and G.jokers and G.jokers.cards then
                joker_count = #G.jokers.cards
            end
            total_mult = total_mult + (3 * joker_count)
        -- Shoot the Moon: +13 mult for each Queen held in hand
        elseif name == "Shoot the Moon" then
            local queen_count = 0
            for _, card in ipairs(cards) do
                if card.base and card.base.id == 12 then -- Queen
                    queen_count = queen_count + 1
                end
            end
            total_mult = total_mult + (13 * queen_count)
        end
    end

    local total_score = total_chips * total_mult
    return total_score
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

-- Enhanced get_possible_combos: returns {name=..., cards=..., score=...} for highest hand type only
local function get_possible_combos_with_scores(cards)
    local combos = {}
    local all_combos = {}
    
    -- Get sorted jokers by their x position (left to right)
    local sorted_jokers = {}
    if G and G.jokers and G.jokers.cards then
        for _, joker in ipairs(G.jokers.cards) do
            table.insert(sorted_jokers, joker)
        end
        table.sort(sorted_jokers, function(a, b)
            return (a.T and a.T.x or 0) < (b.T and b.T.x or 0)
        end)
    end
    
    -- Filter out stone cards before generating combinations
    local non_stone_cards = {}
    for _, card in ipairs(cards) do
        if not (card.ability and card.ability.effect == "Stone Card") then
            table.insert(non_stone_cards, card)
        end
    end
    
    local function generate_combinations(cards, start, current, result)
        if #current == 5 then
            table.insert(result, current)
            return
        end
        for i = start, #cards do
            local new_current = {}
            for _, card in ipairs(current) do
                table.insert(new_current, card)
            end
            table.insert(new_current, cards[i])
            generate_combinations(cards, i + 1, new_current, result)
        end
    end
    local five_card_combinations = {}
    generate_combinations(non_stone_cards, 1, {}, five_card_combinations)
    for _, combo in ipairs(five_card_combinations) do
        for _, hand in ipairs(poker_hands) do
            if hand.check(combo) then
                local relevant, for_scoring = filter_relevant_combo_cards(hand.name, combo)
                -- Create a unique key based on hand name, sorted relevant card values and suits, and score
                local card_keys = {}
                for _, c in ipairs(relevant) do
                    table.insert(card_keys, tostring(get_rank_value(c.base.value)) .. (c.base.suit or ""))
                end
                table.sort(card_keys)
                local score = calculate_combo_score(hand.name, for_scoring, sorted_jokers)
                local key = hand.name .. ":" .. table.concat(card_keys, ",") .. ":" .. tostring(score)
                if not all_combos[key] then
                    table.insert(combos, {name = hand.name, cards = relevant, score = score})
                    all_combos[key] = true
                end
                break -- Stop after the first (highest) hand type match
            end
        end
    end
    table.sort(combos, function(a, b)
        return a.score > b.score -- sort by score descending
    end)
    return combos
end

-- Toggle states for overlay boxes
local show_hand_tracker = true
local show_deck_tracker = true
local show_possible_combos = true
local show_combo_levels = true
local show_joker_box = true
local show_boss_blind_info = true
local show_blind_skip_box = true

function love.keypressed(key)
    if key == '1' then show_hand_tracker = not show_hand_tracker end
    if key == '2' then show_deck_tracker = not show_deck_tracker end
    if key == '3' then show_possible_combos = not show_possible_combos end
    if key == '4' then show_combo_levels = not show_combo_levels end
    if key == '5' then show_joker_box = not show_joker_box end
    if key == '6' then show_boss_blind_info = not show_boss_blind_info end
    if key == '7' then show_blind_skip_box = not show_blind_skip_box end
end

function love.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    -- Hand Tracker
    if mx >= 10 and mx <= 210 and my >= 40 and my <= 280 then -- Adjusted Y range
        scroll_offset = scroll_offset - y
        if G and G.hand and G.hand.cards then
            local num_cards = #G.hand.cards
            local visible = 10
            scroll_offset = clamp(scroll_offset, 0, math.max(0, num_cards - visible))
        end
    end
    -- Deck Tracker
    if mx >= 220 and mx <= 420 and my >= 40 and my <= 280 then -- Adjusted Y range
        scroll_offset2 = scroll_offset2 - y
        if G and G.deck and G.deck.cards then
            local num_cards = #G.deck.cards
            local visible = 10
            scroll_offset2 = clamp(scroll_offset2, 0, math.max(0, num_cards - visible))
        end
    end
    -- Combo Levels Box (moved to 3rd position)
    if mx >= 430 and mx <= 630 and my >= 40 and my <= 280 then -- Adjusted Y range
        combo_level_scroll_offset = combo_level_scroll_offset - y
        local num_levels = 0 
        if G and G.GAME and G.GAME.hands then -- Using G.GAME.hands for levels
            num_levels = #poker_hands -- Number of defined poker hands
        end
        local visible = 10
        combo_level_scroll_offset = clamp(combo_level_scroll_offset, 0, math.max(0, num_levels - visible))
    end
    -- Joker Box (moved to 4th position)
    if mx >= 640 and mx <= 840 and my >= 40 and my <= 280 then -- Adjusted Y range
        joker_scroll_offset = joker_scroll_offset - y
        local num_jokers = 0
        if G and G.jokers and G.jokers.cards then
            num_jokers = #G.jokers.cards
        elseif G and G.jokers and G.jokers.jokers then
            num_jokers = #G.jokers.jokers
        end
        local visible = 10
        joker_scroll_offset = clamp(joker_scroll_offset, 0, math.max(0, num_jokers - visible))
    end
    -- Possible Combos (moved to 5th/last position, increased width)
    if mx >= 850 and mx <= 1150 and my >= 40 and my <= 280 then -- Adjusted X and Y range, increased width
        combo_scroll_offset = combo_scroll_offset - y
        if G and G.hand and G.hand.cards then
            local combos = get_possible_combos_with_scores(G.hand.cards)
            -- Calculate visible combos for the scrollable section below the best combo
            local scrollable_area_height = 280 - (70 + 36) -- Box bottom Y - (Header Y + Best Combo height)
            local visible_scrollable_combos = math.floor(scrollable_area_height / 36) -- Each combo takes ~36px
            local num_total_scrollable_combos = math.max(0, #combos - 1) -- Total combos after the best one

            combo_scroll_offset = clamp(combo_scroll_offset, 0, math.max(0, num_total_scrollable_combos - visible_scrollable_combos))
        end
    end
end

local old_draw = love.draw
function love.draw(...)
    if old_draw then old_draw(...) end

    -- Draw legend for toggles at the top of the overlay boxes
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 0, 1190, 30)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("[1] Hand Tracker  [2] Deck Tracker  [3] Possible Combos  [4] Combo Levels  [5] Jokers  [6] Boss Blind Info  [7] Blind Skip Box", 20, 10)

    local box_y = 40
    local box_h = 240
    local box_w = 200
    local box_gap = 10
    local box_x = 10

    -- Hand Tracker
    if show_hand_tracker then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", box_x, box_y, box_w, box_h)
        love.graphics.print("Hand Tracker", box_x + 10, box_y + 10)
        if G and G.hand and G.hand.cards then
            local visible = 10
            for i = 1, visible do
                local idx = i + scroll_offset
                local card = G.hand.cards[idx]
                if card then
                    love.graphics.print(get_card_info(card), box_x + 10, box_y + 30 + (i - 1) * 20)
                end
            end
        end
    end

    box_x = box_x + box_w + box_gap

    -- Deck Tracker
    if show_deck_tracker then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", box_x, box_y, box_w, box_h)
        love.graphics.print("Deck Tracker", box_x + 10, box_y + 10)
        if G and G.deck and G.deck.cards then
            local visible = 10
            local sorted_cards = {}
            for _, card in ipairs(G.deck.cards) do
                table.insert(sorted_cards, card)
            end
            table.sort(sorted_cards, sort_cards)
            for i = 1, visible do
                local idx = i + scroll_offset2
                local card = sorted_cards[idx]
                if card then
                    love.graphics.print(get_card_info(card), box_x + 10, box_y + 30 + (i - 1) * 20)
                end
            end
        end
    end

    box_x = box_x + box_w + box_gap

    -- Combo Levels
    if show_combo_levels then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", box_x, box_y, box_w, box_h)
        love.graphics.print("Combo Levels", box_x + 10, box_y + 10)
        if G and G.GAME and G.GAME.hands then
            local visible = 10
            local displayed_levels = {}
            for _, hand_data in ipairs(poker_hands) do
                local hand_name = hand_data.name
                local hand_level = G.GAME.hands[hand_name] and G.GAME.hands[hand_name].level or 0 
                table.insert(displayed_levels, hand_name .. ": Lvl " .. tostring(hand_level))
            end
            for i = 1, visible do
                local idx = i + combo_level_scroll_offset
                local level_text = displayed_levels[idx]
                if level_text then
                    love.graphics.print(level_text, box_x + 10, box_y + 30 + (i - 1) * 20)
                end
            end
        end
    end

    box_x = box_x + box_w + box_gap

    -- Joker Box
    if show_joker_box then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", box_x, box_y, box_w, box_h)
        love.graphics.print("Jokers", box_x + 10, box_y + 10)
        if G and G.jokers and G.jokers.cards then
            local visible = 10
            for i = 1, visible do
                local idx = i + joker_scroll_offset
                local joker = G.jokers.cards[idx]
                if joker then
                    local joker_display = get_joker_info(joker)
                    love.graphics.print(joker_display, box_x + 10, box_y + 30 + (i - 1) * 20)
                end
            end
        end
    end

    box_x = box_x + box_w + box_gap

    -- Possible Combos (rightmost box with extra width)
    if show_possible_combos then
        local combo_box_w = 350 -- Extra width for possible combos
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", box_x, box_y, combo_box_w, box_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", box_x, box_y, combo_box_w, box_h)
        love.graphics.print("Possible Combos", box_x + 10, box_y + 10)
        if G and G.hand and G.hand.cards then
            local combos = get_possible_combos_with_scores(G.hand.cards)
            local current_y_start = box_y + 30

            -- Show best combo at the top (if present)
            if #combos > 0 then
                local best = combos[1]
                local card_strs_best = {}
                for _, card in ipairs(best.cards) do
                    table.insert(card_strs_best, get_card_info(card))
                end
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for best combo
                love.graphics.print("Best Combo: " .. best.name .. " (Score: " .. tostring(best.score) .. ")", box_x + 10, current_y_start)
                local y_for_best_cards = current_y_start + 16
                love.graphics.setColor(1, 1, 1, 1)
                local combo_card_display_str_best = table.concat(card_strs_best, ", ")
                love.graphics.print(combo_card_display_str_best, box_x + 20, y_for_best_cards)
            end

            -- Show the rest of the combos in a scrollable way
            local scrollable_start_y = current_y_start + 36
            local scrollable_area_height = box_h - (scrollable_start_y - box_y)
            local visible_scrollable_combos_count = math.floor(scrollable_area_height / 36)

            for i = 0, visible_scrollable_combos_count - 1 do
                local current_y = scrollable_start_y + (i * 36)
                local combo_to_display_index = (combo_scroll_offset + 2) + i -- +2 to skip the first (best) combo
                
                local combo = combos[combo_to_display_index]
                if combo then
                    love.graphics.setColor(1, 1, 1, 1) -- White for other combos
                    love.graphics.print(combo.name .. " (Score: " .. tostring(combo.score) .. ")", box_x + 10, current_y)
                    local y_for_cards = current_y + 16
                    local card_strs = {}
                    for _, card in ipairs(combo.cards) do
                        table.insert(card_strs, get_card_info(card))
                    end
                    local combo_card_display_str = table.concat(card_strs, ", ")
                    love.graphics.print(combo_card_display_str, box_x + 20, y_for_cards)
                end
            end
        end
    end

    -- Boss Blind Info Box (placed below the row)
    if show_boss_blind_info then
        local boss_box_x = 10
        local boss_box_y = box_y + box_h + box_gap
        local boss_box_w = 1190
        local boss_box_h = 70
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", boss_box_x, boss_box_y, boss_box_w, boss_box_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", boss_box_x, boss_box_y, boss_box_w, boss_box_h)
        love.graphics.print("Boss Blind", boss_box_x + 10, boss_box_y + 10)
        if G and G.GAME and G.GAME.blind and G.GAME.blind.name then
            love.graphics.print("Name: " .. tostring(G.GAME.blind.name), boss_box_x + 120, boss_box_y + 10)
            if G.GAME.blind.loc_debuff_text then
                love.graphics.print("Effect: " .. tostring(G.GAME.blind.loc_debuff_text), boss_box_x + 10, boss_box_y + 35)
            end
        end
        -- Display current discards
        love.graphics.print("Discards Remaining: " .. tostring(G and G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left or "N/A"), boss_box_x + 300, boss_box_y + 35)
    end

    -- Skipped Blinds Box
    if show_blind_skip_box then
        local skip_box_x = box_x + box_w + box_gap
        local skip_box_y = box_y
        local skip_box_w = 200
        local skip_box_h = 60
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", skip_box_x, skip_box_y, skip_box_w, skip_box_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", skip_box_x, skip_box_y, skip_box_w, skip_box_h)
        love.graphics.print("Blinds Skipped", skip_box_x + 10, skip_box_y + 10)
        local skip_count = (G and G.GAME and G.GAME.skips) or 0
        love.graphics.print("Count: " .. tostring(skip_count), skip_box_x + 10, skip_box_y + 30)
    end
end