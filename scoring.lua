-- Scoring functions for handLogger mod
local config = require('config')
local utils = require('utils')
local card_utils = require('card_utils')
local poker_hands = require('poker_hands')

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
        if not utils.is_card_debuffed(card) and card.config and card.config.center == G.P_CENTERS.m_glass then
            total_mult = total_mult * 2
        end
    end

    -- Then calculate chips and additive multipliers from cards in the combo
    for _, card in ipairs(cards) do
        local card_chips = 0
        if not utils.is_card_debuffed(card) then
            card_chips = card_utils.get_card_base_chips(card)
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
        for _, hand in ipairs(poker_hands.poker_hands) do
            if hand.check(combo) then
                local relevant, for_scoring = filter_relevant_combo_cards(hand.name, combo)
                -- Create a unique key based on hand name, sorted relevant card values and suits, and score
                local card_keys = {}
                for _, c in ipairs(relevant) do
                    table.insert(card_keys, tostring(utils.get_rank_value(c.base.value)) .. (c.base.suit or ""))
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

return {
    get_combo_base = get_combo_base,
    filter_relevant_combo_cards = filter_relevant_combo_cards,
    calculate_combo_score = calculate_combo_score,
    get_possible_combos_with_scores = get_possible_combos_with_scores
} 