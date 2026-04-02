# Roblox Horror Game — Design Spec

## Overview

Psychological multiplayer horror game for Roblox based on Scandinavian folklore. Each chapter features a different creature from Norse folk mythology. Two players explore together, solving puzzles and surviving scripted horror events.

Reference: The Mimic (Roblox) — chapter structure, atmosphere, folklore-driven narrative.

## Core Parameters

| Parameter | Value |
|-----------|-------|
| Genre | Psychological multiplayer horror |
| Platform | Roblox (Luau) |
| Setting | Scandinavian folklore, folk creatures |
| Structure | Chapters, each = one creature + legend |
| Players | 2 (always together) |
| Core mechanic | Exploration + puzzles, creature at scripted moments |
| Chapter duration | 25-35 minutes |
| Approach | Modular system (reusable managers + per-chapter config) |

## Chapter 1: The Draugr

### Setting

A cursed Viking burial mound (kurgan) in a Scandinavian forest.

**Outside:** Night forest, snow, northern lights between trees. Runic stones at the entrance.

**Inside the mound (main gameplay):**
- Entry corridor — narrow, stone walls, dying torches. Tutorial zone
- Hall of Runes — first large room, runic pillars, patterned stone floor
- Transition corridors — progressively narrower, lower ceiling, dripping water
- Burial chamber — medium room, stone altar, bones, Viking weapons on walls
- Draugr's chamber — deepest and largest hall, sarcophagus in center, blue-green glow

**Finale:** Mound collapses → reverse path through corridors with changed routes → escape outside to dawn.

Two contrasting environments: forest outside (open, cold, beautiful) vs mound inside (tight, dark, oppressive). Contrast amplifies claustrophobia.

### Level Progression

```
Entrance (Prologue) → Entry Corridor (Tutorial) → Hall of Runes (Puzzle 1)
→ Scare 1: Draugr shadow → Burial Chamber (Puzzle 2)
→ Scare 2: Whispers + lights out → Draugr's Chamber (Puzzle 3 + Finale)
→ Escape (mound collapses)
```

Optional side rooms with lore notes branch off the main path.

## Architecture

### Project Structure

```
ServerScriptService/
├── GameManager.lua          -- main orchestrator: chapter start, game state
├── PuzzleManager.lua        -- puzzle registration and logic
├── ScareManager.lua         -- scripted horror events (sound, light, draugr appearances)
├── DialogueManager.lua      -- text/audio hints, notes, lore
└── ChapterConfig/
    └── Chapter1_Draugr.lua  -- chapter 1 config: triggers, puzzles, scares

StarterPlayerScripts/
├── ClientEffects.lua        -- visual effects (fog, vignette, camera shake)
├── SoundController.lua      -- sound management (ambient, footsteps, scare sounds)
└── UIController.lua         -- HUD: interaction prompts, inventory, dialogues

ReplicatedStorage/
├── Events/                  -- RemoteEvents for server↔client communication
└── SharedTypes.lua          -- shared data types

Workspace/
└── Chapter1/               -- 3D map: rooms, triggers, items
```

### Data Flow

1. Player enters trigger zone → server (GameManager) receives signal
2. GameManager checks ChapterConfig → calls appropriate manager (Puzzle/Scare/Dialogue)
3. Manager executes server logic + fires RemoteEvent to client
4. Client handles effects (sound, visuals, UI)

## Scare System (ScareManager)

### Tension Curve

Waves of tension with valleys of relief between peaks. Each wave higher than the last, culminating in the finale.

### Scare Types

| Type | Example | When |
|------|---------|------|
| Audio | Whispers, scraping, footsteps behind | Between puzzles |
| Visual | Shadow flickers, torch dies, peripheral movement | In corridors |
| Environmental | Door closes, object moved, inscription appears on wall | After puzzle |
| False calm | 10-15 seconds of silence after a scare. Player expects next — nothing happens | Between scares |
| Draugr | Appears far away, stands, watches, vanishes. Then closer. Then closer still | Progresses through chapter |

Key rule: Draugr does NOT attack until the finale. Only observes. Each appearance closer than the last.

Scare config is per-chapter in ChapterConfig. Manager is shared.

## Puzzle System (PuzzleManager)

Three puzzles per chapter, increasing difficulty. Both players interact with the same puzzle cooperatively.

| Puzzle | Mechanic | Co-op Element | Time |
|--------|----------|---------------|------|
| 1. Hall of Runes | 4 runes on walls, press in correct order. Hint: floor pattern | One reads hint, other presses. Runes visible from different angles | ~5 min |
| 2. Altar | 3 items (sword, goblet, amulet) placed on altar. Order from notes | Items in different corners, carry one at a time | ~7 min |
| 3. Ritual | Final: repeat action sequence (light, place, speak). Draugr nearby, time pressure | One performs ritual, other holds torch (darkness = death) | ~5 min |

### Puzzle State

- States: locked → active → solved
- Progress tracking per puzzle (steps completed)
- Unlock condition: previous puzzle solved → next unlocked
- On solved: signal to GameManager → advance chapter state → may trigger ScareManager

## Client Effects

### SoundController

- Ambient: wind outside, water drips inside, distant hum. Different per zone
- Footsteps: sound changes by surface (snow → stone → water)
- Scare sounds: stingers on ScareManager command
- Draugr whisper: quiet, grows louder approaching his chamber. Old Norse (meaningless phrases — sound matters)

### ClientEffects

- Fog: thick outside, light haze inside
- Lighting: torches flicker (random amplitude), deeper = darker
- Vignette: screen edge darkening, intensifies in danger zones
- Camera shake: light on scares, heavy on finale collapse
- ColorCorrection: cold blue outside, warm orange from torches inside → shifts to sickly green toward finale

### UIController — Minimal HUD

No health bars, markers, or minimaps. Only:
- Interaction prompts (E — pick up / examine)
- Notes (overlay as parchment text)
- Whisper subtitles (optional)

Minimal UI = maximum immersion. Player never knows if they're safe.

## Game Lifecycle (GameManager)

### State Machine

```
LOBBY → LOADING → PROLOGUE → GAMEPLAY → FINALE → ESCAPE → COMPLETE
```

| State | Description |
|-------|-------------|
| LOBBY | Both players in lobby, choose chapter, press "Ready" |
| LOADING | Load chapter map, spawn players |
| PROLOGUE | Forest, walk to mound. Free walk (no cutscenes). Atmosphere setup via environment and audio |
| GAMEPLAY | Main loop: puzzle → scare → puzzle → scare → puzzle. GameManager reads ChapterConfig and sequentially activates events |
| FINALE | Puzzle 3 + draugr. Timer: 90 sec to complete ritual or both die |
| ESCAPE | Mound collapses. Linear run to exit, falling rocks, one path |
| COMPLETE | Outside. Dawn. Results screen: completion time, notes found |

### Death & Respawn

- One player dies → other continues alone (scarier)
- Both die → respawn at last checkpoint (after each solved puzzle)

### Chapter Config

Lua table describing the full sequence: which zones trigger which events, in what order, with what parameters. For chapter 2 — write a new config, managers stay the same.
