# Hand Logger Mod for Balatro

A comprehensive mod for Balatro that provides detailed information about your cards, possible combinations, jokers, and game state.

## Features

- **Hand Tracker**: Shows all cards currently in your hand with detailed information
- **Deck Tracker**: Displays all cards in your deck, sorted by suit and rank
- **Possible Combos**: Calculates and shows all possible poker hand combinations with scores
- **Combo Levels**: Shows the current level of each poker hand type
- **Joker Box**: Displays all active jokers with their effects and stats
- **Boss Blind Info**: Shows information about the current boss blind and its effects
- **Blind Skip Box**: Tracks how many blinds have been skipped this run

## Controls

- **1**: Toggle Hand Tracker
- **2**: Toggle Deck Tracker  
- **3**: Toggle Possible Combos
- **4**: Toggle Combo Levels
- **5**: Toggle Joker Box
- **6**: Toggle Boss Blind Info
- **7**: Toggle Blind Skip Box
- **Mouse Wheel**: Scroll through lists in each box

## File Structure

The mod has been organized into modular files for better maintainability:

### Core Files
- `handLogger.lua` - Main entry point and love function overrides
- `config.lua` - Configuration constants and settings
- `utils.lua` - General utility functions

### Feature Modules
- `card_utils.lua` - Card-related functions (display, sorting, scoring)
- `joker_utils.lua` - Joker information and display functions
- `poker_hands.lua` - Poker hand checking and validation functions
- `scoring.lua` - Complex scoring calculations including all joker effects
- `ui.lua` - User interface drawing and input handling

## Installation

1. Place all `.lua` files in your Balatro mods directory
2. Enable the mod in Steamodded
3. Start a new run or continue an existing one

## Card Display Format

Cards are displayed in abbreviated format:
- **Rank + Suit**: `AS` (Ace of Spades), `KH` (King of Hearts)
- **Enhancements**: `<H>` (Holographic), `<F>` (Foil), `<P>` (Polychrome)
- **Seals**: `[R]` (Red), `[B]` (Blue), `[G]` (Gold), `[P]` (Purple)
- **Effects**: `<W>` (Wild), `<L>` (Lucky), `<ST>` (Stone), `<GL>` (Glass)
- **Debuffs**: `<D>` (Debuffed by boss blind)

## Scoring System

The mod calculates scores using Balatro's actual scoring mechanics:
- Base hand chips and multipliers
- Card rank values (2-10 = face value, J/Q/K = 10, Ace = 11)
- Enhancement bonuses (Holographic +10, Foil +5, etc.)
- All joker effects applied in the correct order
- Boss blind debuffs and restrictions

## Contributing

The modular structure makes it easy to contribute:
- Add new joker effects in `scoring.lua`
- Modify UI layout in `ui.lua`
- Add new card enhancements in `card_utils.lua`
- Update configuration in `config.lua`

## Version History

- **1.0.0**: Initial release with modular structure
- Previous versions: Monolithic single-file implementation 