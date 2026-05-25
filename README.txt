Ниже — хороший стартовый brief для Codex/агента. Он описывает концепцию, механику и структуру проекта без излишней детализации, чтобы AI понимал архитектуру игры.

---

# Texas Hold'em Strip Poker — Game Design Brief

## Project Overview

Create a 2D anime-style strip poker game using the Godot Engine.

The game is focused on Texas Hold'em poker gameplay combined with a progressive clothing-loss mechanic. The tone should be playful, stylish, and similar to anime visual novels.

The project is intended for solo indie development and should use a clean, modular architecture that is easy to expand later.

---

## Core Gameplay

The main gameplay loop:

1. Start a poker match against one or more AI opponents.
2. Play standard Texas Hold'em rounds.
3. Characters lose clothing/items when they lose enough chips.
4. Win poker rounds to progress.
5. Unlock new opponents, outfits, expressions, and scenes.

The game should prioritize:

* simple and understandable UI;
* readable poker flow;
* character reactions and expressions;
* smooth pacing.

---

## Technical Requirements

### Engine

Use Godot Engine with GDScript.

### Graphics Style

* 2D anime style
* Static sprites with expression changes
* Layered clothing system
* Minimal animation
* Visual novel inspired presentation

### Target Structure

The project should be modular and beginner-friendly.

Suggested folders:

```text
/scenes
/scripts
/ui
/cards
/characters
/backgrounds
/audio
/data
```

---

## Poker Rules

Use standard Texas Hold'em rules.

### Match Flow

1. Deal two private cards to each player
2. Pre-flop betting
3. Flop
4. Turn
5. River
6. Showdown

### Required Systems

* Deck generation and shuffling
* Hand evaluation
* Betting system
* Pot management
* Turn order
* AI decision making
* Winner calculation

---

## Strip Mechanic

Characters have:

* chip count
* clothing layers
* emotional states

When a character loses enough chips:

* one clothing layer is removed;
* character expression changes;
* dialogue/comment appears.

The clothing system should use layered sprites:

* body
* top clothing
* bottom clothing
* accessories

Clothing visibility should be toggleable in code.

Example:

```gdscript
shirt.visible = false
```

---

## Character System

Each opponent should have:

* name
* portrait
* emotions
* clothing states
* personality type
* poker behavior profile

Example AI personalities:

* aggressive
* shy
* bluff-heavy
* defensive

---

## UI Requirements

The interface should include:

* poker table
* player cards
* community cards
* chip counters
* action buttons
* dialogue box
* character portraits

Buttons:

* Fold
* Check
* Call
* Raise
* All In

---

## AI Behavior

Opponent AI should:

* evaluate hand strength;
* bluff occasionally;
* react emotionally to wins/losses;
* use different personalities.

Keep the AI simple but believable.

---

## Dialogue System

Characters should comment during gameplay:

* winning hands;
* bluffing;
* losing clothing;
* player actions.

Dialogue should feel anime-inspired and lighthearted.

---

## Save System

The game should support:

* unlocked characters;
* settings;
* progress;
* statistics.

---

## Audio

Include support for:

* background music;
* button sounds;
* card sounds;
* reaction sounds.

---

## Development Priorities

Build the project in this order:

1. Basic poker logic
2. Card UI
3. Betting system
4. AI opponents
5. Character system
6. Clothing system
7. Dialogue system
8. Save/load
9. Polish and animations

---

## Important Development Notes

* Keep code modular and readable.
* Use reusable scenes whenever possible.
* Avoid overengineering.
* Prefer simple systems over complex abstractions.
* The project should remain manageable for a beginner developer.


# Technical Specification — MVP

## Engine Version

Use:

* Godot 4.4+
* GDScript only

Avoid C# and plugins unless absolutely necessary.

---

# MVP Goal

Create a playable single-opponent Texas Hold'em strip poker prototype.

The MVP must include:

* one AI opponent;
* one poker table;
* complete Texas Hold'em round flow;
* simple betting;
* clothing removal system;
* basic anime-style UI.

No multiplayer.
No advanced animations.
No voice acting.

---

# Initial Vertical Slice

The first playable version should allow:

1. Start game
2. Play poker rounds
3. Win/lose chips
4. AI reacts
5. Opponent loses clothing
6. Restart match

The game should already feel like a complete mini-game.

---

# Recommended Scene Structure

```text
MainMenu.tscn
Game.tscn
PokerTable.tscn
PlayerUI.tscn
OpponentUI.tscn
Card.tscn
DialogueBox.tscn
```

---

# Main Scene Responsibilities

## Game.tscn

Controls:

* game state;
* poker phases;
* match flow;
* scene communication.

---

## PokerTable.tscn

Handles:

* community cards;
* pot display;
* dealing cards;
* table visuals.

---

## PlayerUI.tscn

Handles:

* player chips;
* action buttons;
* hand cards.

---

## OpponentUI.tscn

Handles:

* opponent portrait;
* clothing layers;
* emotions;
* chip count.

---

# Recommended Script Structure

```text
/scripts/game/
GameManager.gd
PokerRoundManager.gd

/scripts/poker/
Deck.gd
CardData.gd
HandEvaluator.gd
PokerRules.gd

/scripts/ai/
PokerAI.gd

/scripts/characters/
CharacterData.gd
ClothingSystem.gd

/scripts/ui/
DialogueSystem.gd
```

---

# Minimal Poker Rules

For MVP:

* single opponent only;
* fixed blinds;
* simplified betting;
* no side pots;
* no tournaments.

Focus on stability first.

---

# AI Requirements

Initial AI should:

* randomly fold weak hands;
* call medium hands;
* raise strong hands;
* occasionally bluff.

Keep AI intentionally simple for MVP.

---

# Clothing System

Use layered Sprite2D nodes.

Example structure:

```text
Opponent
 ├── Body
 ├── Bra
 ├── Shirt
 ├── Skirt
 └── Accessories
```

Removing clothing:

```gdscript
shirt.visible = false
```

Avoid sprite sheet animation for MVP.

---

# Art Direction

Style:

* anime visual novel;
* static portraits;
* expression swaps;
* minimal motion.

Recommended expressions:

* neutral
* happy
* angry
* embarrassed
* shocked

---

# UI Style

The UI should resemble:

* anime visual novels;
* poker HUDs;
* mobile-friendly layouts.

Large readable buttons:

* Fold
* Call
* Raise
* Check

---

# Save System

Use JSON save files.

Save:

* unlocked opponents;
* settings;
* statistics.

---

# Coding Standards

Requirements:

* modular code;
* readable variable names;
* avoid giant scripts;
* comment important systems;
* avoid unnecessary optimization.

---

# Important Scope Limitations

DO NOT:

* build multiplayer first;
* overcomplicate AI;
* create advanced animations early;
* add unnecessary systems before MVP works.

---

# First Development Tasks

1. Create card/deck system
2. Create Texas Hold'em flow
3. Create hand evaluation
4. Create betting system
5. Create AI turns
6. Create UI
7. Add opponent reactions
8. Add clothing system
