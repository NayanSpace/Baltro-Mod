--- STEAMODDED HEADER
--- MOD_NAME: Hand Logger
--- MOD_ID: handLogger
--- MOD_AUTHOR: [navindoor]
--- MOD_DESCRIPTION: Logs the cards in your hand to the console whenever it changes
--- VERSION: 1.0.0

package.path = package.path .. ";mods/handLogger/?.lua"

-- Load all modules
local config = require('config')
local utils = require('utils')
local card_utils = require('card_utils')
local joker_utils = require('joker_utils')
local poker_hands = require('poker_hands')
local scoring = require('scoring')
local ui = require('ui')

function SMODS.INIT()
    SMODS.add_mod("Card Tracker", "CardTracker", "navindoor", "1.0.0")
end

-- Override love functions
local old_keypressed = love.keypressed
function love.keypressed(key)
    if old_keypressed then old_keypressed(key) end
    ui.keypressed(key)
end

local old_wheelmoved = love.wheelmoved
function love.wheelmoved(x, y)
    if old_wheelmoved then old_wheelmoved(x, y) end
    ui.wheelmoved(x, y)
end

local old_draw = love.draw
function love.draw(...)
    if old_draw then old_draw(...) end
    ui.draw_all_ui()
end