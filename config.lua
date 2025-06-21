-- Configuration file for handLogger mod
-- Contains all constants, settings, and configuration data

-- Scroll offset variables
local scroll_offset = 0
local scroll_offset2 = 0
local combo_scroll_offset = 0
local combo_level_scroll_offset = 0
local joker_scroll_offset = 0

-- Card data
local rank_names = { "Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King" }
local suit_order = { "Spades", "Hearts", "Clubs", "Diamonds" }

-- Abbreviation mappings
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

local seal_abbrev = {
    ["Red"] = "R",
    ["Blue"] = "B",
    ["Gold"] = "G",
    ["Purple"] = "P",
}

-- Toggle states for overlay boxes
local show_hand_tracker = true
local show_deck_tracker = true
local show_possible_combos = true
local show_combo_levels = true
local show_joker_box = true
local show_boss_blind_info = true
local show_blind_skip_box = true

-- Export all variables
return {
    scroll_offset = scroll_offset,
    scroll_offset2 = scroll_offset2,
    combo_scroll_offset = combo_scroll_offset,
    combo_level_scroll_offset = combo_level_scroll_offset,
    joker_scroll_offset = joker_scroll_offset,
    rank_names = rank_names,
    suit_order = suit_order,
    rank_abbrev = rank_abbrev,
    suit_abbrev = suit_abbrev,
    enhancement_abbrev = enhancement_abbrev,
    seal_abbrev = seal_abbrev,
    show_hand_tracker = show_hand_tracker,
    show_deck_tracker = show_deck_tracker,
    show_possible_combos = show_possible_combos,
    show_combo_levels = show_combo_levels,
    show_joker_box = show_joker_box,
    show_boss_blind_info = show_boss_blind_info,
    show_blind_skip_box = show_blind_skip_box
} 