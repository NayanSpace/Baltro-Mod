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
local function calculate_combo_score(combo_name, cards, sorted_jokers, all_played_cards)
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
            if card.ability and type(card.ability) == "table" and card.ability.bonus and card.ability.bonus > 0 then
                card_chips = card_chips + card.ability.bonus
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

    -- Apply joker effects in order
    local photograph_used = false -- Photograph should only trigger once
    for _, joker in ipairs(sorted_jokers or {}) do
        -- First, apply edition bonuses
        if joker.edition then
            if joker.edition.foil then
                total_chips = total_chips + 50
            end
            if joker.edition.holo then
                total_mult = total_mult + 10
            end
            if joker.edition.polychrome then
                total_mult = total_mult * 1.5
            end
        end

        -- Then, apply the joker's main ability
        local name = joker.ability and joker.ability.name

        if name == "Smiley Face" then
            local face_count = 0
            for _, card in ipairs(cards) do
                if card.base and (card.base.id == 11 or card.base.id == 12 or card.base.id == 13) then
                    face_count = face_count + 1
                end
            end
            total_mult = total_mult + (5 * face_count)
        elseif name == "Photograph" then
            local has_face_card = false
            for _, card in ipairs(cards) do
                if card.base and (card.base.id == 11 or card.base.id == 12 or card.base.id == 13) then
                    has_face_card = true
                    break
                end
            end
            if has_face_card and not photograph_used then
                total_mult = total_mult * 2
                photograph_used = true
            end
        -- Half Joker: +20 mult if hand has 3 or fewer cards
        elseif name == "Half Joker" then
            if #cards <= 3 then
                total_mult = total_mult + 20
            end
        -- Ice Cream: +Chips that decrease over time
        elseif name == "Ice Cream" then
            -- The game engine updates joker.ability.extra.chips. We just read it.
            local current_chips = (joker.ability and joker.ability.extra and joker.ability.extra.chips) or 100
            total_chips = total_chips + current_chips
            -- Note: "Melted!" self-destruct logic is handled by the game engine.
        -- Throwback: +25% mult per blind skipped
        elseif name == "Throwback" then
            local skips = (G and G.GAME and G.GAME.skips) or 0
            local throwback_mult = 1 + 0.25 * skips
            total_mult = total_mult * throwback_mult
        -- Scary Face: +30 chips per face card
        elseif name == "Scary Face" then
            local face_count = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and (card.base.id == 11 or card.base.id == 12 or card.base.id == 13) then
                    face_count = face_count + 1
                end
            end
            total_chips = total_chips + (30 * face_count)
        -- Greedy Joker: +3 mult for Diamonds
        elseif name == "Greedy Joker" then
            local diamond_count = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.suit == "Diamonds" then
                    diamond_count = diamond_count + 1
                end
            end
            total_mult = total_mult + (3 * diamond_count)
        -- Lusty Joker: +3 mult for Hearts
        elseif name == "Lusty Joker" then
            local heart_count = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.suit == "Hearts" then
                    heart_count = heart_count + 1
                end
            end
            total_mult = total_mult + (3 * heart_count)
        -- Wrathful Joker: +3 mult for Spades
        elseif name == "Wrathful Joker" then
            local spade_count = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.suit == "Spades" then
                    spade_count = spade_count + 1
                end
            end
            total_mult = total_mult + (3 * spade_count)
        -- Gluttonous Joker: +3 mult for Clubs
        elseif name == "Gluttonous Joker" then
            local club_count = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.suit == "Clubs" then
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
        -- Mad Joker: +10 mult if hand contains a Two Pair
        elseif name == "Mad Joker" then
            if combo_name == "Two Pair" or combo_name == "Full House" then
                total_mult = total_mult + 10
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
        -- Runner: +15 chips if hand contains a Straight
        elseif name == "Runner" then
            local runner_chips = (joker.ability and joker.ability.extra and joker.ability.extra.chips) or 0
            if combo_name == "Straight" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                runner_chips = runner_chips + 15
            end
            total_chips = total_chips + runner_chips
        -- Crafty Joker: +80 chips if hand contains a Flush
        elseif name == "Crafty Joker" then
            if combo_name == "Flush" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                total_chips = total_chips + 80
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
        -- Banner: +30 chips per discard remaining
        elseif name == "Banner" then
            local discards_left = (G and G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left) or 0
            total_chips = total_chips + (30 * discards_left)
        -- Castle: +Chips for discarding cards of a specific suit
        elseif name == "Castle" then
            -- The game engine determines the suit and updates the joker's chip value on discard.
            local castle_chips = (joker.ability and joker.ability.extra and joker.ability.extra.chips) or 0
            total_chips = total_chips + castle_chips
        -- Mystic Summit: +8 mult if 1 discard remaining
        elseif name == "Mystic Summit" then
            local discards_left = (G and G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left) or 0
            if discards_left == 1 then
                total_mult = total_mult + 8
            end
        -- Loyalty Card: x4 Mult every 6 hands
        elseif name == "Loyalty Card" then
            -- Logic replicated from game source code to correctly predict the trigger.
            local hands_played = (G and G.GAME and G.GAME.hands_played) or 0
            local created_at = joker.ability and joker.ability.hands_played_at_create
            local extra = joker.ability and joker.ability.extra

            if created_at and extra and extra.every and extra.Xmult then
                local hands_since_create = hands_played - created_at
                local loyalty_remaining = (extra.every - 1 - hands_since_create) % (extra.every + 1)
                
                -- The source code applies the multiplier when loyalty_remaining == extra.every
                if loyalty_remaining == extra.every then
                    total_mult = total_mult * extra.Xmult
                end
            end
        -- Misprint: Random mult between 1-4
        elseif name == "Misprint" then
            local random_mult = math.random(1, 4)
            total_mult = total_mult + random_mult
        -- Dusk: +2 mult per card in hand
        elseif name == "Dusk" then
            total_mult = total_mult + (2 * #cards)
        -- Raised Fist: Adds double the rank of lowest card held in hand to Mult
        elseif name == "Raised Fist" then
            local remaining_cards = {}
            if G and G.hand and G.hand.cards then
                for _, hand_card in ipairs(G.hand.cards) do
                    local is_played = false
                    for _, played_card in ipairs(cards) do
                        if hand_card == played_card then
                            is_played = true
                            break
                        end
                    end
                    if not is_played then
                        table.insert(remaining_cards, hand_card)
                    end
                end
            end

            if #remaining_cards > 0 then
                local lowest_rank = 14 -- Start with something higher than any rank
                for _, card in ipairs(remaining_cards) do
                    if card.base and card.base.value then
                        local rank = utils.get_rank_value(card.base.value)
                        if rank < lowest_rank then
                            lowest_rank = rank
                        end
                    end
                end
                
                if lowest_rank <= 14 then -- If we found a card
                    total_mult = total_mult + (2 * lowest_rank)
                end
            end
        -- Fibonacci: +8 mult for each played Ace, 2, 3, 5, 8
        elseif name == "Fibonacci" then
            local fib_mult = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.id then
                    local rank = card.base.id
                    -- Check for Fibonacci numbers: Ace (14), 2, 3, 5, 8
                    if rank == 14 or rank == 2 or rank == 3 or rank == 5 or rank == 8 then
                        fib_mult = fib_mult + 8
                    end
                end
            end
            total_mult = total_mult + fib_mult
        -- Steel Joker: +2 mult per steel card in hand
        elseif name == "Steel Joker" then
            local steel_count = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.config and card.config.center and card.config.center.name == "Steel Card" then
                    steel_count = steel_count + 1
                end
            end
            total_mult = total_mult + (2 * steel_count)
        -- Campfire: adds 0.25 mult for each card sold adn reset after boss blind
        elseif name == "Campfire" then
            local campfire_mult = (joker.ability and joker.ability.x_mult) or 1.0
            total_mult = total_mult * campfire_mult
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
        -- Swashbuckler: +Mult from sum of other Jokers' sell values
        elseif name == "Swashbuckler" then
            -- The game engine calculates the total sell value and stores it as the joker's mult.
            local swash_mult = (joker.ability and joker.ability.mult) or 0
            total_mult = total_mult + swash_mult
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
                if not utils.is_card_debuffed(card) and card.base and card.base.suit then
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
                    if not utils.is_card_debuffed(card) and card.base and card.base.value == idol_card.rank and card.base.suit == idol_card.suit then
                        total_mult = total_mult + 4
                        break
                    end
                end
            end
        -- Seeing Double: +6 mult if all 4 suits present
        elseif name == "Seeing Double" then
            local suits = {Hearts = false, Diamonds = false, Spades = false, Clubs = false}
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.suit then
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
            if combo_name == "Straight" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                total_mult = total_mult + 4
            end
        -- The Tribe: X2 mult for Flush
        elseif name == "The Tribe" then
            if combo_name == "Flush" or combo_name == "Straight Flush" or combo_name == "Royal Flush" then
                total_mult = total_mult * 2
            end
        -- Stuntman: +250 chips, -2 hand size
        elseif name == "Stuntman" then
            total_chips = total_chips + 250
            -- Note: Hand size reduction would need to be handled elsewhere
        -- Abstract Joker: +3 mult per joker
        elseif name == "Abstract Joker" then
            local joker_count = 0
            if G and G.jokers and G.jokers.cards then
                joker_count = #G.jokers.cards
            end
            total_mult = total_mult + (3 * joker_count)
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
                if not utils.is_card_debuffed(card) and card.base and card.base.id == 12 then -- Queen
                    queen_count = queen_count + 1
                end
            end
            total_mult = total_mult + (13 * queen_count)
        -- Odd Todd: +31 chips for each played card with an odd rank (Aces, 3s, 5s, 7s, 9s)
        elseif name == "Odd Todd" then
            local odd_chips = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.id then
                    local rank = card.base.id
                    -- Check for odd ranks: Ace (14), 3, 5, 7, 9
                    if rank == 14 or rank == 3 or rank == 5 or rank == 7 or rank == 9 then
                        odd_chips = odd_chips + 31
                    end
                end
            end
            total_chips = total_chips + odd_chips
        -- Even Steven: +4 mult for each played card with an even rank (2s, 4s, 6s, 8s, 10s)
        elseif name == "Even Steven" then
            local even_mult = 0
            for _, card in ipairs(cards) do
                if not utils.is_card_debuffed(card) and card.base and card.base.id then
                    local rank = card.base.id
                    -- Check for even ranks: 2, 4, 6, 8, 10
                    if rank == 2 or rank == 4 or rank == 6 or rank == 8 or rank == 10 then
                        even_mult = even_mult + 4
                    end
                end
            end
            total_mult = total_mult + even_mult
        -- Joker: +4 mult to all played hands
        elseif name == "Joker" then
            total_mult = total_mult + 4
        -- Ramen: Multiplicative mult that decreases per card discarded
        elseif name == "Ramen" then
            -- The game engine updates joker.ability.x_mult. We just read it.
            -- It's joker.ability.x_mult (lowercase) for the dynamic value.
            local ramen_mult = (joker.ability and joker.ability.x_mult) or (joker.config and joker.config.Xmult) or 2.0

            -- Apply multiplicative mult
            total_mult = total_mult * ramen_mult
            
            -- Note: Self-destruct logic is handled by the game engine, not needed for scoring.
        -- Blue Joker: +2 chips for every card remaining in deck
        elseif name == "Blue Joker" then
            local deck_size = 0
            if G and G.deck and G.deck.cards then
                deck_size = #G.deck.cards
            end
            total_chips = total_chips + (2 * deck_size)
        -- Blackboard: X3 mult if all cards left in hand are Spades or Clubs
        elseif name == "Blackboard" then
            -- Determine the cards remaining in hand after the played hand is removed.
            local played_cards_lookup = {}
            -- Use `all_played_cards` which represents the full set of cards in the potential play.
            local cards_in_play = all_played_cards or cards -- Fallback for safety
            for _, card in ipairs(cards_in_play) do
                played_cards_lookup[card] = true
            end

            local remaining_cards = {}
            if G and G.hand and G.hand.cards then
                for _, card_in_full_hand in ipairs(G.hand.cards) do
                    if not played_cards_lookup[card_in_full_hand] then
                        table.insert(remaining_cards, card_in_full_hand)
                    end
                end
            end

            local condition_met = false
            if #remaining_cards == 0 then
                -- Condition met if hand is empty after playing
                condition_met = true
            else
                local all_black_suits = true
                for _, card in ipairs(remaining_cards) do
                    if not (card.base and (card.base.suit == "Spades" or card.base.suit == "Clubs")) then
                        all_black_suits = false
                        break
                    end
                end
                if all_black_suits then
                    condition_met = true
                end
            end
            
            if condition_met then
                total_mult = total_mult * 3
            end
        -- Popcorn: +20 Mult, -4 Mult per round played
        elseif name == "Popcorn" then
            local popcorn_mult = joker.ability and joker.ability.mult
            total_mult = total_mult + math.max(0, popcorn_mult)
        -- Green Joker: +1 mult per hand played, -1 per discard
        elseif name == "Green Joker" then
            local green_mult = (joker.ability and joker.ability.mult) or 0
            total_mult = total_mult + green_mult + 1
        -- Walkie Talkie: +10 chips and +4 mult for each 10 or 4 played
        elseif name == "Walkie Talkie" then
            for _, card in ipairs(cards) do
                local rank = utils.get_rank_value(card.base.value)
                if rank == 10 or rank == 4 then
                    total_chips = total_chips + 10
                    total_mult = total_mult + 4
                end
            end
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
                local score = calculate_combo_score(hand.name, for_scoring, sorted_jokers, combo)
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