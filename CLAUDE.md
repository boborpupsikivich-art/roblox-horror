# Draugr's Mound — Roblox Horror Game

## What is this

Psychological multiplayer horror game for Roblox. Scandinavian folklore, folk creatures. Chapter-based structure like The Mimic. 2 players co-op, exploration + puzzles, scripted scare events.

## Current State

Chapter 1 (The Draugr) — all code written, needs 3D map in Roblox Studio.

- 11 Luau scripts (server + client + shared)
- Rojo project config ready
- Map building guide in `assets/map-building-guide.md`
- Design spec in `~/Vibe/specs/roblox-horror/2026-04-02-chapter1-draugr-design.md` (or see below)

## Architecture

```
Server (ServerScriptService):
  GameManager.server.luau  — state machine: LOBBY→LOADING→PROLOGUE→GAMEPLAY→FINALE→ESCAPE→COMPLETE
  PuzzleManager.luau       — 3 puzzle types: sequence, placement, timed_sequence
  ScareManager.luau        — zone/puzzle triggered scares, draugr appearances
  DialogueManager.luau     — lore notes with ClickDetectors
  ChapterConfig/Chapter1_Draugr.luau — all chapter data (zones, puzzles, scares, notes)

Client (StarterPlayerScripts):
  ClientController.client.luau — routes all RemoteEvents to client modules
  ClientEffects.luau           — fog, color correction, camera shake, lighting modes
  SoundController.luau         — ambient crossfade, scare sounds (placeholder asset IDs)
  UIController.luau            — hint label, parchment note overlay, minimal HUD

Shared (ReplicatedStorage):
  GameEnums.luau      — GameState, PuzzleState, ScareType enums
  RemoteEvents.luau   — creates and returns RemoteEvents
```

## Data Flow

1. Player enters trigger zone → server GameManager receives signal
2. GameManager checks ChapterConfig → calls PuzzleManager/ScareManager/DialogueManager
3. Manager executes server logic + fires RemoteEvent to client
4. Client handles effects (sound, visuals, UI)

## Chapter 1: The Draugr

Setting: Viking burial mound (kurgan). Forest outside → narrow corridors inside → draugr's chamber deep below.

Puzzles:
1. Hall of Runes — press 4 runes in correct order (solution: C, A, D, B)
2. Burial Chamber Altar — place Amulet/Goblet/Sword on 3 slots
3. Ritual — timed (90s), light braziers + place amulet + read runestone

Scares: draugr appears at increasing proximity (far → medium → finale). Never attacks until final puzzle. Audio/visual/environmental scares between puzzles.

Death: one dies → other continues alone. Both die → respawn at last checkpoint.

## Setup Instructions

### Prerequisites
- Roblox Studio (https://create.roblox.com)
- Rojo CLI: `D:/Vibe/tools/rojo.exe` (already installed, v7.6.1)

### Quick Start
1. Clone this repo
2. Open Roblox Studio → Create new Baseplate
3. Install Rojo plugin: Plugins → Manage Plugins → search "Rojo"
4. Terminal: `D:/Vibe/tools/rojo.exe serve` (from project root)
5. Studio: Rojo plugin → Connect
6. Build the 3D map following `assets/map-building-guide.md`
7. Play!

### Roblox Studio MCP (AI-assisted building)
MCP server `robloxstudio` (boshyxd/robloxstudio-mcp) is configured in Claude Code.

**Setup in Studio (one-time):**
1. Download the companion plugin `.rbxm` from https://github.com/boshyxd/robloxstudio-mcp/releases
2. Place it in `%LOCALAPPDATA%/Roblox/Plugins/`
3. In Studio: Game Settings → Security → Enable "Allow HTTP Requests"
4. Restart Studio — plugin toolbar should appear

**What Claude can do via MCP (39 tools):**
- Explore game hierarchy, search objects by name/class
- Create/delete/duplicate/reparent instances
- Read and edit script source code
- Set properties (including bulk operations)
- Manage attributes and CollectionService tags
- Terrain operations
- Control playtests (start/stop)
- Execute Luau code directly in Studio

## Next Steps

1. **Build 3D map in Studio** — follow `assets/map-building-guide.md` for exact part names and structure
2. **Replace placeholder sounds** — current asset IDs are Roblox library placeholders. Need real horror audio
3. **Draugr model** — create or find a Viking undead model
4. **Polish lighting** — torches with PointLight + Fire, ambient fog tuning
5. **Chapter 2** — write new ChapterConfig (Nøkk? Huldra? Mara?), reuse all managers
6. **Lobby system** — chapter select UI, ready button

## Commands

```bash
rojo serve          # Start Rojo file sync with Studio
rojo build -o game.rbxl  # Build .rbxl file from project
```

## Key Design Decisions

- Modular approach: managers are chapter-agnostic, ChapterConfig holds all data
- 2 players only (not 4) — intimate horror, every sound matters
- No health bars, no minimap — player never knows if they're safe
- Draugr observes but doesn't attack until finale — psychological pressure > jump scares
- Linear level with optional side rooms for lore notes
- Tension wave pattern: puzzle (calm) → scare (peak) → puzzle (calm) → scare (higher peak) → finale

## File Naming

- `.server.luau` = ServerScript (runs on server)
- `.client.luau` = LocalScript (runs on client)
- `.luau` without prefix = ModuleScript (imported by others)
