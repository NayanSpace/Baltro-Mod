-- UI functions for handLogger mod
local config = require('config')
local utils = require('utils')
local card_utils = require('card_utils')
local joker_utils = require('joker_utils')
local scoring = require('scoring')

-- Input handling
local function keypressed(key)
    if key == '1' then config.show_hand_tracker = not config.show_hand_tracker end
    if key == '2' then config.show_deck_tracker = not config.show_deck_tracker end
    if key == '3' then config.show_possible_combos = not config.show_possible_combos end
    if key == '4' then config.show_combo_levels = not config.show_combo_levels end
    if key == '5' then config.show_joker_box = not config.show_joker_box end
    if key == '6' then config.show_boss_blind_info = not config.show_boss_blind_info end
    if key == '7' then config.show_blind_skip_box = not config.show_blind_skip_box end
end

local function wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    -- Hand Tracker
    if mx >= 10 and mx <= 210 and my >= 40 and my <= 280 then -- Adjusted Y range
        config.scroll_offset = config.scroll_offset - y
        if G and G.hand and G.hand.cards then
            local num_cards = #G.hand.cards
            local visible = 10
            config.scroll_offset = utils.clamp(config.scroll_offset, 0, math.max(0, num_cards - visible))
        end
    end
    -- Deck Tracker
    if mx >= 220 and mx <= 420 and my >= 40 and my <= 280 then -- Adjusted Y range
        config.scroll_offset2 = config.scroll_offset2 - y
        if G and G.deck and G.deck.cards then
            local num_cards = #G.deck.cards
            local visible = 10
            config.scroll_offset2 = utils.clamp(config.scroll_offset2, 0, math.max(0, num_cards - visible))
        end
    end
    -- Combo Levels Box (moved to 3rd position)
    if mx >= 430 and mx <= 630 and my >= 40 and my <= 280 then -- Adjusted Y range
        config.combo_level_scroll_offset = config.combo_level_scroll_offset - y
        local num_levels = 0 
        if G and G.GAME and G.GAME.hands then -- Using G.GAME.hands for levels
            num_levels = 9 -- Number of defined poker hands
        end
        local visible = 10
        config.combo_level_scroll_offset = utils.clamp(config.combo_level_scroll_offset, 0, math.max(0, num_levels - visible))
    end
    -- Joker Box (moved to 4th position)
    if mx >= 640 and mx <= 840 and my >= 40 and my <= 280 then -- Adjusted Y range
        config.joker_scroll_offset = config.joker_scroll_offset - y
        local num_jokers = 0
        if G and G.jokers and G.jokers.cards then
            num_jokers = #G.jokers.cards
        elseif G and G.jokers and G.jokers.jokers then
            num_jokers = #G.jokers.jokers
        end
        local visible = 10
        config.joker_scroll_offset = utils.clamp(config.joker_scroll_offset, 0, math.max(0, num_jokers - visible))
    end
    -- Possible Combos (moved to 5th/last position, increased width)
    if mx >= 850 and mx <= 1150 and my >= 40 and my <= 280 then -- Adjusted X and Y range, increased width
        config.combo_scroll_offset = config.combo_scroll_offset - y
        if G and G.hand and G.hand.cards then
            local combos = scoring.get_possible_combos_with_scores(G.hand.cards)
            -- Calculate visible combos for the scrollable section below the best combo
            local scrollable_area_height = 280 - (70 + 36) -- Box bottom Y - (Header Y + Best Combo height)
            local visible_scrollable_combos = math.floor(scrollable_area_height / 36) -- Each combo takes ~36px
            local num_total_scrollable_combos = math.max(0, #combos - 1) -- Total combos after the best one

            config.combo_scroll_offset = utils.clamp(config.combo_scroll_offset, 0, math.max(0, num_total_scrollable_combos - visible_scrollable_combos))
        end
    end
end

-- Drawing functions
local function draw_legend()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 0, 1190, 30)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("[1] Hand Tracker  [2] Deck Tracker  [3] Possible Combos  [4] Combo Levels  [5] Jokers  [6] Boss Blind Info  [7] Blind Skip Box", 20, 10)
end

local function draw_hand_tracker()
    if not config.show_hand_tracker then return end
    
    local box_x = 10
    local box_y = 40
    local box_w = 200
    local box_h = 240
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", box_x, box_y, box_w, box_h)
    love.graphics.print("Hand Tracker", box_x + 10, box_y + 10)
    if G and G.hand and G.hand.cards then
        local visible = 10
        for i = 1, visible do
            local idx = i + config.scroll_offset
            local card = G.hand.cards[idx]
            if card then
                love.graphics.print(card_utils.get_card_info(card), box_x + 10, box_y + 30 + (i - 1) * 20)
            end
        end
    end
end

local function draw_deck_tracker()
    if not config.show_deck_tracker then return end
    
    local box_x = 220
    local box_y = 40
    local box_w = 200
    local box_h = 240
    
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
        table.sort(sorted_cards, card_utils.sort_cards)
        for i = 1, visible do
            local idx = i + config.scroll_offset2
            local card = sorted_cards[idx]
            if card then
                love.graphics.print(card_utils.get_card_info(card), box_x + 10, box_y + 30 + (i - 1) * 20)
            end
        end
    end
end

local function draw_combo_levels()
    if not config.show_combo_levels then return end
    
    local box_x = 430
    local box_y = 40
    local box_w = 200
    local box_h = 240
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", box_x, box_y, box_w, box_h)
    love.graphics.print("Combo Levels", box_x + 10, box_y + 10)
    if G and G.GAME and G.GAME.hands then
        local visible = 10
        local displayed_levels = {}
        local poker_hands = require('poker_hands')
        for _, hand_data in ipairs(poker_hands.poker_hands) do
            local hand_name = hand_data.name
            local hand_level = G.GAME.hands[hand_name] and G.GAME.hands[hand_name].level or 0 
            table.insert(displayed_levels, hand_name .. ": Lvl " .. tostring(hand_level))
        end
        for i = 1, visible do
            local idx = i + config.combo_level_scroll_offset
            local level_text = displayed_levels[idx]
            if level_text then
                love.graphics.print(level_text, box_x + 10, box_y + 30 + (i - 1) * 20)
            end
        end
    end
end

local function draw_joker_box()
    if not config.show_joker_box then return end
    
    local box_x = 640
    local box_y = 40
    local box_w = 200
    local box_h = 240
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", box_x, box_y, box_w, box_h)
    love.graphics.print("Jokers", box_x + 10, box_y + 10)
    if G and G.jokers and G.jokers.cards then
        local visible = 10
        for i = 1, visible do
            local idx = i + config.joker_scroll_offset
            local joker = G.jokers.cards[idx]
            if joker then
                local joker_display = joker_utils.get_joker_info(joker)
                love.graphics.print(joker_display, box_x + 10, box_y + 30 + (i - 1) * 20)
            end
        end
    end
end

local function draw_possible_combos()
    if not config.show_possible_combos then return end
    
    local box_x = 850
    local box_y = 40
    local combo_box_w = 350 -- Extra width for possible combos
    local box_h = 240
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", box_x, box_y, combo_box_w, box_h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", box_x, box_y, combo_box_w, box_h)
    love.graphics.print("Possible Combos", box_x + 10, box_y + 10)
    if G and G.hand and G.hand.cards then
        local combos = scoring.get_possible_combos_with_scores(G.hand.cards)
        local current_y_start = box_y + 30

        -- Show best combo at the top (if present)
        if #combos > 0 then
            local best = combos[1]
            local card_strs_best = {}
            for _, card in ipairs(best.cards) do
                table.insert(card_strs_best, card_utils.get_card_info(card))
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
            local combo_to_display_index = (config.combo_scroll_offset + 2) + i -- +2 to skip the first (best) combo
            
            local combo = combos[combo_to_display_index]
            if combo then
                love.graphics.setColor(1, 1, 1, 1) -- White for other combos
                love.graphics.print(combo.name .. " (Score: " .. tostring(combo.score) .. ")", box_x + 10, current_y)
                local y_for_cards = current_y + 16
                local card_strs = {}
                for _, card in ipairs(combo.cards) do
                    table.insert(card_strs, card_utils.get_card_info(card))
                end
                local combo_card_display_str = table.concat(card_strs, ", ")
                love.graphics.print(combo_card_display_str, box_x + 20, y_for_cards)
            end
        end
    end
end

local function draw_boss_blind_info()
    if not config.show_boss_blind_info then return end
    
    local boss_box_x = 10
    local boss_box_y = 290
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

local function draw_blind_skip_box()
    if not config.show_blind_skip_box then return end
    
    local skip_box_x = 1210
    local skip_box_y = 40
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

local function draw_all_ui()
    draw_legend()
    draw_hand_tracker()
    draw_deck_tracker()
    draw_combo_levels()
    draw_joker_box()
    draw_possible_combos()
    draw_boss_blind_info()
    draw_blind_skip_box()
end

return {
    keypressed = keypressed,
    wheelmoved = wheelmoved,
    draw_all_ui = draw_all_ui
} 