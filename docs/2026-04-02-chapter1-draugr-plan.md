# Draugr's Mound — Chapter 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable 25-35 minute psychological horror chapter for 2 players in Roblox, featuring a Draugr in a Viking burial mound with 3 puzzles and scripted scare events.

**Architecture:** Modular server-side managers (GameManager, PuzzleManager, ScareManager, DialogueManager) driven by a per-chapter config table. Client-side controllers handle effects, sound, and minimal UI. Server↔client communication via RemoteEvents. Rojo for external file sync to Roblox Studio.

**Tech Stack:** Roblox Studio, Luau, Rojo (file sync), Wally (package manager)

**Spec:** `~/Vibe/specs/roblox-horror/2026-04-02-chapter1-draugr-design.md`

---

## File Structure

```
roblox-horror/
├── default.project.json              -- Rojo project config
├── src/
│   ├── server/                       -- ServerScriptService
│   │   ├── GameManager.server.luau   -- state machine, chapter lifecycle
│   │   ├── PuzzleManager.luau        -- ModuleScript: puzzle registration & logic
│   │   ├── ScareManager.luau         -- ModuleScript: scare event execution
│   │   ├── DialogueManager.luau      -- ModuleScript: notes, lore, hints
│   │   └── ChapterConfig/
│   │       └── Chapter1_Draugr.luau  -- ModuleScript: chapter 1 data
│   ├── client/                       -- StarterPlayerScripts
│   │   ├── ClientController.client.luau -- boots client modules
│   │   ├── ClientEffects.luau        -- ModuleScript: fog, vignette, shake, color
│   │   ├── SoundController.luau      -- ModuleScript: ambient, footsteps, scares
│   │   └── UIController.luau         -- ModuleScript: prompts, notes overlay, subtitles
│   └── shared/                       -- ReplicatedStorage
│       ├── GameEnums.luau            -- ModuleScript: game states, scare types, puzzle states
│       └── RemoteEvents.luau         -- ModuleScript: creates/returns RemoteEvents
├── assets/                           -- reference for Studio assets (sounds, textures)
│   └── sounds.md                     -- list of needed sound assets with descriptions
└── wally.toml                        -- package manager config (optional, for TestEZ)
```

---

### Task 1: Project Setup — Rojo + Roblox Studio

**Files:**
- Create: `default.project.json`
- Create: `wally.toml`

Rojo syncs local `.luau` files into Roblox Studio in real-time. This lets Claude Code write all scripts externally.

- [ ] **Step 1: Install Rojo CLI**

Run:
```bash
# macOS via aftman (Roblox toolchain manager)
cargo install aftman || brew install aftman
aftman init
aftman add rojo-rbx/rojo
```

If aftman is not available, install Rojo directly:
```bash
# Alternative: download from https://github.com/rojo-rbx/rojo/releases
# Place binary in PATH
```

Verify:
```bash
rojo --version
```
Expected: `rojo 7.x.x`

- [ ] **Step 2: Create Rojo project config**

```json
{
  "name": "DraugrsMound",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "$path": "src/server"
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/client"
      }
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": {
        "$path": "src/shared"
      }
    },
    "Lighting": {
      "$className": "Lighting",
      "$properties": {
        "Ambient": [0.02, 0.02, 0.04],
        "Brightness": 0,
        "ClockTime": 0,
        "FogColor": [0.05, 0.05, 0.08],
        "FogEnd": 150,
        "FogStart": 10,
        "GlobalShadows": true,
        "OutdoorAmbient": [0.03, 0.03, 0.06]
      }
    }
  }
}
```

- [ ] **Step 3: Create folder structure**

Run:
```bash
cd ~/Vibe/lab/roblox-horror
mkdir -p src/server/ChapterConfig src/client src/shared assets
```

- [ ] **Step 4: Open Roblox Studio and connect Rojo**

1. Open Roblox Studio → Create new Baseplate place
2. Save as `DraugrsMound.rbxl` in project root
3. Install Rojo plugin: Plugins → Manage Plugins → search "Rojo" → Install
4. In terminal: `rojo serve` (from project root)
5. In Studio: Rojo plugin panel → Connect

Verify: Rojo plugin shows "Connected" with green indicator.

- [ ] **Step 5: Commit**

```bash
cd ~/Vibe/lab/roblox-horror
git init
echo ".superpowers/\n*.rbxl\n*.rbxlx" > .gitignore
git add default.project.json src/ .gitignore
git commit -m "feat: project setup with Rojo config and folder structure"
```

---

### Task 2: Shared Enums and RemoteEvents

**Files:**
- Create: `src/shared/GameEnums.luau`
- Create: `src/shared/RemoteEvents.luau`

- [ ] **Step 1: Create GameEnums**

```lua
-- src/shared/GameEnums.luau
local GameEnums = {}

GameEnums.GameState = {
	LOBBY = "LOBBY",
	LOADING = "LOADING",
	PROLOGUE = "PROLOGUE",
	GAMEPLAY = "GAMEPLAY",
	FINALE = "FINALE",
	ESCAPE = "ESCAPE",
	COMPLETE = "COMPLETE",
}

GameEnums.PuzzleState = {
	LOCKED = "LOCKED",
	ACTIVE = "ACTIVE",
	SOLVED = "SOLVED",
}

GameEnums.ScareType = {
	AUDIO = "AUDIO",
	VISUAL = "VISUAL",
	ENVIRONMENT = "ENVIRONMENT",
	FALSE_CALM = "FALSE_CALM",
	DRAUGR = "DRAUGR",
}

return GameEnums
```

- [ ] **Step 2: Create RemoteEvents module**

```lua
-- src/shared/RemoteEvents.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

local eventNames = {
	-- Game state
	"GameStateChanged",     -- server → client: notify state transition
	"PlayerReady",          -- client → server: player pressed Ready in lobby

	-- Scares
	"TriggerScare",         -- server → client: execute scare effect

	-- Puzzles
	"PuzzleActivated",      -- server → client: show puzzle UI/hints
	"PuzzleSolved",         -- server → client: puzzle complete feedback
	"PuzzleInteract",       -- client → server: player interacted with puzzle element

	-- Dialogue
	"ShowNote",             -- server → client: display a lore note
	"ShowHint",             -- server → client: display interaction hint

	-- Effects
	"SetAmbientZone",       -- server → client: change ambient sound/lighting zone
	"CameraShake",          -- server → client: trigger camera shake
}

function RemoteEvents.setup()
	local folder = Instance.new("Folder")
	folder.Name = "GameEvents"
	folder.Parent = ReplicatedStorage

	for _, name in eventNames do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
end

function RemoteEvents.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("GameEvents")
	return folder:WaitForChild(name)
end

return RemoteEvents
```

- [ ] **Step 3: Verify in Studio**

1. Run `rojo serve` if not already running
2. In Studio: check ReplicatedStorage → Shared → GameEnums and RemoteEvents appear
3. No errors in Output panel

- [ ] **Step 4: Commit**

```bash
git add src/shared/
git commit -m "feat: add shared enums and RemoteEvents module"
```

---

### Task 3: Chapter 1 Config

**Files:**
- Create: `src/server/ChapterConfig/Chapter1_Draugr.luau`

The config defines every trigger, puzzle, scare, and note in the chapter. Managers read this data — they never hardcode chapter-specific logic.

- [ ] **Step 1: Create Chapter 1 config**

```lua
-- src/server/ChapterConfig/Chapter1_Draugr.luau
local GameEnums = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameEnums"))

local Chapter1 = {}

Chapter1.name = "The Draugr's Mound"
Chapter1.description = "A cursed Viking burial mound. Something stirs within."
Chapter1.maxPlayers = 2

-- Zones: name → trigger part name in Workspace.Chapter1
Chapter1.zones = {
	{ name = "entrance",        trigger = "Zone_Entrance" },
	{ name = "tutorial_corridor", trigger = "Zone_TutorialCorridor" },
	{ name = "hall_of_runes",   trigger = "Zone_HallOfRunes" },
	{ name = "corridor_2",     trigger = "Zone_Corridor2" },
	{ name = "burial_chamber",  trigger = "Zone_BurialChamber" },
	{ name = "corridor_3",     trigger = "Zone_Corridor3" },
	{ name = "draugr_chamber",  trigger = "Zone_DraugrChamber" },
}

-- Ambient per zone (SoundController reads this)
Chapter1.ambientZones = {
	entrance           = { sound = "Forest_Night", fogEnd = 150, colorShift = {0.1, 0.1, 0.2} },
	tutorial_corridor  = { sound = "Cave_Drip", fogEnd = 80, colorShift = {0.15, 0.1, 0.05} },
	hall_of_runes      = { sound = "Cave_Hum", fogEnd = 60, colorShift = {0.15, 0.1, 0.05} },
	corridor_2         = { sound = "Cave_Drip_Deep", fogEnd = 40, colorShift = {0.1, 0.08, 0.04} },
	burial_chamber     = { sound = "Cave_Wind", fogEnd = 50, colorShift = {0.1, 0.08, 0.04} },
	corridor_3         = { sound = "Cave_Whisper", fogEnd = 30, colorShift = {0.05, 0.08, 0.04} },
	draugr_chamber     = { sound = "Draugr_Ambient", fogEnd = 40, colorShift = {0.03, 0.07, 0.05} },
}

-- Puzzles: sequential, each unlocks after previous solved
Chapter1.puzzles = {
	{
		id = "runes",
		zone = "hall_of_runes",
		type = "sequence",
		description = "Press 4 runes in correct order. Hint: floor pattern.",
		elements = { "Rune_A", "Rune_B", "Rune_C", "Rune_D" },  -- Part names in Workspace
		solution = { "Rune_C", "Rune_A", "Rune_D", "Rune_B" },
		hintText = "The floor pattern shows the way: wave, eye, tree, shield.",
		onSolve = "open_door_to_corridor2",
	},
	{
		id = "altar",
		zone = "burial_chamber",
		type = "placement",
		description = "Place 3 items on altar in correct positions.",
		items = { "Sword", "Goblet", "Amulet" },           -- Pickup part names
		slots = { "Slot_Left", "Slot_Center", "Slot_Right" }, -- Altar slot part names
		solution = { Slot_Left = "Amulet", Slot_Center = "Goblet", Slot_Right = "Sword" },
		hintText = "The dead were honored: protection first, offering second, strength last.",
		onSolve = "open_door_to_corridor3",
	},
	{
		id = "ritual",
		zone = "draugr_chamber",
		type = "timed_sequence",
		description = "Complete the ritual before the Draugr reaches you.",
		timeLimit = 90,
		steps = {
			{ action = "interact", target = "Brazier_1", text = "Light the brazier" },
			{ action = "interact", target = "Brazier_2", text = "Light the second brazier" },
			{ action = "place", target = "Sarcophagus_Slot", item = "Amulet", text = "Place the amulet" },
			{ action = "interact", target = "Runestone", text = "Read the inscription" },
		},
		onSolve = "pacify_draugr",
		onFail = "kill_all_players",
	},
}

-- Scares: triggered by zone entry or puzzle completion
Chapter1.scares = {
	{
		trigger = { type = "zone_enter", zone = "tutorial_corridor" },
		scareType = GameEnums.ScareType.AUDIO,
		params = { sound = "Distant_Scrape", delay = 3, volume = 0.4 },
	},
	{
		trigger = { type = "puzzle_solved", puzzleId = "runes" },
		scareType = GameEnums.ScareType.DRAUGR,
		params = {
			spawnPoint = "Scare1_DraugrSpawn",
			duration = 2.5,
			animation = "stand_and_stare",
			distance = "far",
		},
	},
	{
		trigger = { type = "zone_enter", zone = "corridor_2" },
		scareType = GameEnums.ScareType.ENVIRONMENT,
		params = { event = "door_slam_behind", delay = 5 },
	},
	{
		trigger = { type = "zone_enter", zone = "burial_chamber" },
		scareType = GameEnums.ScareType.FALSE_CALM,
		params = { silenceDuration = 15 },
	},
	{
		trigger = { type = "puzzle_solved", puzzleId = "altar" },
		scareType = GameEnums.ScareType.VISUAL,
		params = { event = "lights_out", duration = 5, whisperSound = "Old_Norse_Whisper" },
	},
	{
		trigger = { type = "zone_enter", zone = "corridor_3" },
		scareType = GameEnums.ScareType.DRAUGR,
		params = {
			spawnPoint = "Scare2_DraugrSpawn",
			duration = 3,
			animation = "stand_and_stare",
			distance = "medium",
		},
	},
}

-- Lore notes: optional pickups
Chapter1.notes = {
	{
		partName = "Note_1",
		zone = "hall_of_runes",
		title = "Bjorn's Warning",
		text = "Do not disturb the jarl's rest. His rage does not end with death. I have seen him walk. — Bjorn, son of Erik",
	},
	{
		partName = "Note_2",
		zone = "burial_chamber",
		title = "The Ritual of Binding",
		text = "To bind the draugr: light the sacred flames, return what was taken, speak the old words. Only then will he sleep again.",
	},
}

-- Checkpoints: after each puzzle, players respawn here on death
Chapter1.checkpoints = {
	{ afterPuzzle = "runes", spawnPoint = "Checkpoint_1" },
	{ afterPuzzle = "altar", spawnPoint = "Checkpoint_2" },
}

-- Escape sequence (ESCAPE state)
Chapter1.escape = {
	duration = 30,
	collapseEvents = {
		{ delay = 0, event = "rumble_start" },
		{ delay = 3, event = "rocks_fall_corridor3" },
		{ delay = 8, event = "rocks_fall_burial_chamber" },
		{ delay = 15, event = "rocks_fall_corridor2" },
		{ delay = 22, event = "rocks_fall_hall" },
	},
	exitPoint = "Escape_Exit",
}

return Chapter1
```

- [ ] **Step 2: Verify in Studio**

Check that `ServerScriptService → ChapterConfig → Chapter1_Draugr` appears in the Explorer panel.

- [ ] **Step 3: Commit**

```bash
git add src/server/ChapterConfig/
git commit -m "feat: add Chapter 1 Draugr config with puzzles, scares, notes"
```

---

### Task 4: GameManager — State Machine

**Files:**
- Create: `src/server/GameManager.server.luau`

The central orchestrator. Manages game state transitions and coordinates all managers.

- [ ] **Step 1: Create GameManager**

```lua
-- src/server/GameManager.server.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameEnums = require(Shared:WaitForChild("GameEnums"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local PuzzleManager = require(ServerScriptService:WaitForChild("PuzzleManager"))
local ScareManager = require(ServerScriptService:WaitForChild("ScareManager"))
local DialogueManager = require(ServerScriptService:WaitForChild("DialogueManager"))
local Chapter1 = require(ServerScriptService:WaitForChild("ChapterConfig"):WaitForChild("Chapter1_Draugr"))

-- Setup RemoteEvents (must happen before anything else)
RemoteEvents.setup()

-- State
local currentState = GameEnums.GameState.LOBBY
local currentChapter = nil
local readyPlayers: { Player } = {}
local solvedPuzzles: { [string]: boolean } = {}
local activeCheckpoint: string? = nil

-- Zone tracking: which zones each player has entered (prevent re-triggering)
local triggeredZones: { [string]: boolean } = {}
local triggeredScares: { [number]: boolean } = {}

-- Forward declarations
local transitionTo
local setupZoneTriggers
local onPuzzleSolved

-- State transition
transitionTo = function(newState: string)
	local oldState = currentState
	currentState = newState
	print(`[GameManager] {oldState} → {newState}`)

	local events = RemoteEvents.get("GameStateChanged")
	for _, player in Players:GetPlayers() do
		events:FireClient(player, newState)
	end

	if newState == GameEnums.GameState.LOADING then
		currentChapter = Chapter1
		solvedPuzzles = {}
		triggeredZones = {}
		triggeredScares = {}
		activeCheckpoint = nil
		-- Teleport players to chapter spawn
		local spawn = workspace:FindFirstChild("Chapter1"):FindFirstChild("PlayerSpawn")
		if spawn then
			for _, player in Players:GetPlayers() do
				local char = player.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					char.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
				end
			end
		end
		task.wait(1)
		transitionTo(GameEnums.GameState.PROLOGUE)

	elseif newState == GameEnums.GameState.PROLOGUE then
		-- Set ambient for entrance
		local zoneData = currentChapter.ambientZones["entrance"]
		local ambientEvent = RemoteEvents.get("SetAmbientZone")
		for _, player in Players:GetPlayers() do
			ambientEvent:FireClient(player, zoneData)
		end
		-- Setup zone triggers for the whole chapter
		setupZoneTriggers()
		-- Register puzzles
		PuzzleManager.init(currentChapter.puzzles, onPuzzleSolved)
		-- Register scares
		ScareManager.init(currentChapter.scares)
		-- Register notes
		DialogueManager.init(currentChapter.notes)
		-- Activate first puzzle
		PuzzleManager.activate("runes")

		task.wait(2)
		transitionTo(GameEnums.GameState.GAMEPLAY)

	elseif newState == GameEnums.GameState.FINALE then
		-- Activate ritual puzzle with timer
		PuzzleManager.activate("ritual")
		ScareManager.triggerFinale(currentChapter)

	elseif newState == GameEnums.GameState.ESCAPE then
		-- Start collapse sequence
		local escapeConfig = currentChapter.escape
		for _, event in escapeConfig.collapseEvents do
			task.delay(event.delay, function()
				ScareManager.triggerCollapseEvent(event.event)
			end)
		end
		-- Timer: reach exit or die
		task.delay(escapeConfig.duration, function()
			if currentState == GameEnums.GameState.ESCAPE then
				-- Time's up — kill remaining players
				for _, player in Players:GetPlayers() do
					local char = player.Character
					if char then
						local humanoid = char:FindFirstChild("Humanoid")
						if humanoid then humanoid.Health = 0 end
					end
				end
			end
		end)

	elseif newState == GameEnums.GameState.COMPLETE then
		-- Show results after 3 seconds
		task.wait(3)
		-- TODO in future: results screen with time, notes found
		print("[GameManager] Chapter complete!")
	end
end

-- Puzzle solved callback
onPuzzleSolved = function(puzzleId: string)
	solvedPuzzles[puzzleId] = true
	print(`[GameManager] Puzzle solved: {puzzleId}`)

	-- Fire scares triggered by puzzle completion
	ScareManager.onPuzzleSolved(puzzleId)

	-- Update checkpoint
	for _, cp in currentChapter.checkpoints do
		if cp.afterPuzzle == puzzleId then
			activeCheckpoint = cp.spawnPoint
		end
	end

	-- Progress chapter
	if puzzleId == "runes" then
		PuzzleManager.activate("altar")
	elseif puzzleId == "altar" then
		transitionTo(GameEnums.GameState.FINALE)
	elseif puzzleId == "ritual" then
		transitionTo(GameEnums.GameState.ESCAPE)
	end
end

-- Zone trigger setup
setupZoneTriggers = function()
	local chapter1Folder = workspace:FindFirstChild("Chapter1")
	if not chapter1Folder then
		warn("[GameManager] Chapter1 folder not found in Workspace")
		return
	end

	for _, zone in currentChapter.zones do
		local triggerPart = chapter1Folder:FindFirstChild(zone.trigger)
		if triggerPart then
			triggerPart.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and not triggeredZones[zone.name] then
					triggeredZones[zone.name] = true
					print(`[GameManager] Zone entered: {zone.name}`)

					-- Update ambient
					local zoneData = currentChapter.ambientZones[zone.name]
					if zoneData then
						local ambientEvent = RemoteEvents.get("SetAmbientZone")
						for _, p in Players:GetPlayers() do
							ambientEvent:FireClient(p, zoneData)
						end
					end

					-- Trigger zone-based scares
					ScareManager.onZoneEnter(zone.name)
				end
			end)
		else
			warn(`[GameManager] Trigger part not found: {zone.trigger}`)
		end
	end

	-- Escape exit trigger
	local exitPart = chapter1Folder:FindFirstChild(currentChapter.escape.exitPoint)
	if exitPart then
		exitPart.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and currentState == GameEnums.GameState.ESCAPE then
				transitionTo(GameEnums.GameState.COMPLETE)
			end
		end)
	end
end

-- Player death / respawn
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			task.wait(3)
			-- Respawn at checkpoint
			if activeCheckpoint then
				local spawnPart = workspace.Chapter1:FindFirstChild(activeCheckpoint)
				if spawnPart then
					player:LoadCharacter()
					task.wait(0.5)
					local newChar = player.Character
					if newChar and newChar:FindFirstChild("HumanoidRootPart") then
						newChar.HumanoidRootPart.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
					end
				end
			else
				player:LoadCharacter()
			end
		end)
	end)
end)

-- Lobby: wait for 2 players, both ready
RemoteEvents.get("PlayerReady").OnServerEvent:Connect(function(player)
	if currentState ~= GameEnums.GameState.LOBBY then return end

	if not table.find(readyPlayers, player) then
		table.insert(readyPlayers, player)
		print(`[GameManager] Player ready: {player.Name} ({#readyPlayers}/{Chapter1.maxPlayers})`)
	end

	if #readyPlayers >= Chapter1.maxPlayers then
		transitionTo(GameEnums.GameState.LOADING)
	end
end)

print("[GameManager] Initialized. Waiting for players...")
```

- [ ] **Step 2: Verify in Studio**

1. Play solo in Studio (File → Play)
2. Check Output panel for: `[GameManager] Initialized. Waiting for players...`
3. No errors

- [ ] **Step 3: Commit**

```bash
git add src/server/GameManager.server.luau
git commit -m "feat: add GameManager with state machine and zone triggers"
```

---

### Task 5: PuzzleManager

**Files:**
- Create: `src/server/PuzzleManager.luau`

- [ ] **Step 1: Create PuzzleManager**

```lua
-- src/server/PuzzleManager.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameEnums = require(Shared:WaitForChild("GameEnums"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local PuzzleManager = {}

local puzzles: { [string]: any } = {}
local puzzleStates: { [string]: string } = {}
local puzzleProgress: { [string]: any } = {}
local onSolvedCallback = nil
local timerThread: thread? = nil

function PuzzleManager.init(puzzleConfigs: { any }, onSolved: (string) -> ())
	puzzles = {}
	puzzleStates = {}
	puzzleProgress = {}
	onSolvedCallback = onSolved

	for _, config in puzzleConfigs do
		puzzles[config.id] = config
		puzzleStates[config.id] = GameEnums.PuzzleState.LOCKED
		puzzleProgress[config.id] = {}
	end

	-- Listen for player interactions
	RemoteEvents.get("PuzzleInteract").OnServerEvent:Connect(function(player, puzzleId, action, target)
		PuzzleManager.handleInteraction(player, puzzleId, action, target)
	end)

	print("[PuzzleManager] Initialized with " .. tostring(#puzzleConfigs) .. " puzzles")
end

function PuzzleManager.activate(puzzleId: string)
	if not puzzles[puzzleId] then
		warn(`[PuzzleManager] Unknown puzzle: {puzzleId}`)
		return
	end

	puzzleStates[puzzleId] = GameEnums.PuzzleState.ACTIVE
	puzzleProgress[puzzleId] = { steps = {}, placements = {} }

	-- Notify clients
	local event = RemoteEvents.get("PuzzleActivated")
	local config = puzzles[puzzleId]
	for _, player in Players:GetPlayers() do
		event:FireClient(player, puzzleId, config.hintText)
	end

	-- Start timer for timed puzzles
	if config.type == "timed_sequence" and config.timeLimit then
		timerThread = task.delay(config.timeLimit, function()
			if puzzleStates[puzzleId] == GameEnums.PuzzleState.ACTIVE then
				print(`[PuzzleManager] Puzzle timed out: {puzzleId}`)
				PuzzleManager.onFail(puzzleId)
			end
		end)
	end

	print(`[PuzzleManager] Activated: {puzzleId}`)
end

function PuzzleManager.handleInteraction(player: Player, puzzleId: string, action: string, target: string)
	if puzzleStates[puzzleId] ~= GameEnums.PuzzleState.ACTIVE then return end

	local config = puzzles[puzzleId]
	local progress = puzzleProgress[puzzleId]

	if config.type == "sequence" then
		-- Sequence puzzle: player presses elements in order
		table.insert(progress.steps, target)

		-- Check if sequence matches so far
		for i, step in progress.steps do
			if config.solution[i] ~= step then
				-- Wrong sequence — reset
				progress.steps = {}
				print(`[PuzzleManager] Wrong sequence for {puzzleId}, resetting`)
				return
			end
		end

		-- Check if complete
		if #progress.steps == #config.solution then
			PuzzleManager.solve(puzzleId)
		end

	elseif config.type == "placement" then
		-- Placement puzzle: player places item on slot
		progress.placements[target] = action -- target = slot, action = item name

		-- Check if all slots filled correctly
		local allCorrect = true
		for slot, expectedItem in config.solution do
			if progress.placements[slot] ~= expectedItem then
				allCorrect = false
				break
			end
		end

		if allCorrect then
			PuzzleManager.solve(puzzleId)
		end

	elseif config.type == "timed_sequence" then
		-- Timed sequence: steps must be done in order
		table.insert(progress.steps, target)

		local stepIndex = #progress.steps
		local expectedStep = config.steps[stepIndex]

		if expectedStep and expectedStep.target == target then
			print(`[PuzzleManager] Ritual step {stepIndex}/{#config.steps} complete`)
			if stepIndex == #config.steps then
				PuzzleManager.solve(puzzleId)
			end
		else
			-- Wrong step — reset progress
			progress.steps = {}
			print(`[PuzzleManager] Wrong ritual step, resetting`)
		end
	end
end

function PuzzleManager.solve(puzzleId: string)
	puzzleStates[puzzleId] = GameEnums.PuzzleState.SOLVED

	-- Cancel timer if exists
	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end

	-- Notify clients
	local event = RemoteEvents.get("PuzzleSolved")
	for _, player in Players:GetPlayers() do
		event:FireClient(player, puzzleId)
	end

	print(`[PuzzleManager] Solved: {puzzleId}`)

	if onSolvedCallback then
		onSolvedCallback(puzzleId)
	end
end

function PuzzleManager.onFail(puzzleId: string)
	local config = puzzles[puzzleId]
	if config.onFail == "kill_all_players" then
		for _, player in Players:GetPlayers() do
			local char = player.Character
			if char then
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then humanoid.Health = 0 end
			end
		end
	end
end

return PuzzleManager
```

- [ ] **Step 2: Verify in Studio**

Play in Studio, check Output for: `[PuzzleManager] Initialized with 3 puzzles`

- [ ] **Step 3: Commit**

```bash
git add src/server/PuzzleManager.luau
git commit -m "feat: add PuzzleManager with sequence, placement, and timed puzzle types"
```

---

### Task 6: ScareManager

**Files:**
- Create: `src/server/ScareManager.luau`

- [ ] **Step 1: Create ScareManager**

```lua
-- src/server/ScareManager.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameEnums = require(Shared:WaitForChild("GameEnums"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local ScareManager = {}

local scareConfigs: { any } = {}
local triggeredScares: { [number]: boolean } = {}

function ScareManager.init(configs: { any })
	scareConfigs = configs
	triggeredScares = {}
	print(`[ScareManager] Initialized with {#configs} scares`)
end

function ScareManager.onZoneEnter(zoneName: string)
	for i, scare in scareConfigs do
		if triggeredScares[i] then continue end

		local trigger = scare.trigger
		if trigger.type == "zone_enter" and trigger.zone == zoneName then
			triggeredScares[i] = true
			local delay = scare.params.delay or 0
			task.delay(delay, function()
				ScareManager.executeScare(scare)
			end)
		end
	end
end

function ScareManager.onPuzzleSolved(puzzleId: string)
	for i, scare in scareConfigs do
		if triggeredScares[i] then continue end

		local trigger = scare.trigger
		if trigger.type == "puzzle_solved" and trigger.puzzleId == puzzleId then
			triggeredScares[i] = true
			local delay = scare.params.delay or 0
			task.delay(delay, function()
				ScareManager.executeScare(scare)
			end)
		end
	end
end

function ScareManager.executeScare(scare: any)
	local scareEvent = RemoteEvents.get("TriggerScare")

	print(`[ScareManager] Executing scare: {scare.scareType}`)

	for _, player in Players:GetPlayers() do
		scareEvent:FireClient(player, scare.scareType, scare.params)
	end

	-- Server-side effects for DRAUGR type
	if scare.scareType == GameEnums.ScareType.DRAUGR then
		local chapter1 = workspace:FindFirstChild("Chapter1")
		if chapter1 then
			local spawnPoint = chapter1:FindFirstChild(scare.params.spawnPoint)
			local draugrModel = chapter1:FindFirstChild("Draugr")
			if spawnPoint and draugrModel then
				draugrModel:PivotTo(spawnPoint.CFrame)
				draugrModel.Parent = chapter1

				-- Make visible
				for _, part in draugrModel:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = 0
					end
				end

				-- Disappear after duration
				task.delay(scare.params.duration, function()
					for _, part in draugrModel:GetDescendants() do
						if part:IsA("BasePart") then
							part.Transparency = 1
						end
					end
				end)
			end
		end
	end
end

function ScareManager.triggerFinale(chapterConfig: any)
	print("[ScareManager] Finale triggered — Draugr awakens")

	local chapter1 = workspace:FindFirstChild("Chapter1")
	if not chapter1 then return end

	local draugrModel = chapter1:FindFirstChild("Draugr")
	if not draugrModel then return end

	-- Show draugr permanently at sarcophagus
	local sarcophagus = chapter1:FindFirstChild("Sarcophagus")
	if sarcophagus then
		draugrModel:PivotTo(sarcophagus.CFrame + Vector3.new(0, 3, 0))
	end
	for _, part in draugrModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end

	-- Scare all clients with draugr ambient
	local scareEvent = RemoteEvents.get("TriggerScare")
	for _, player in Players:GetPlayers() do
		scareEvent:FireClient(player, GameEnums.ScareType.DRAUGR, {
			finale = true,
			sound = "Draugr_Roar",
		})
	end
end

function ScareManager.triggerCollapseEvent(eventName: string)
	print(`[ScareManager] Collapse event: {eventName}`)

	local shakeEvent = RemoteEvents.get("CameraShake")
	local scareEvent = RemoteEvents.get("TriggerScare")

	for _, player in Players:GetPlayers() do
		shakeEvent:FireClient(player, { intensity = 0.8, duration = 2 })
		scareEvent:FireClient(player, GameEnums.ScareType.ENVIRONMENT, {
			event = eventName,
			sound = "Rocks_Falling",
		})
	end
end

return ScareManager
```

- [ ] **Step 2: Verify in Studio**

Play, check Output: `[ScareManager] Initialized with 6 scares`

- [ ] **Step 3: Commit**

```bash
git add src/server/ScareManager.luau
git commit -m "feat: add ScareManager with zone/puzzle triggers and draugr appearances"
```

---

### Task 7: DialogueManager

**Files:**
- Create: `src/server/DialogueManager.luau`

- [ ] **Step 1: Create DialogueManager**

```lua
-- src/server/DialogueManager.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local DialogueManager = {}

local noteConfigs: { any } = {}
local pickedUpNotes: { [string]: boolean } = {}

function DialogueManager.init(notes: { any })
	noteConfigs = notes
	pickedUpNotes = {}

	-- Setup click detectors on note parts
	local chapter1 = workspace:FindFirstChild("Chapter1")
	if not chapter1 then
		warn("[DialogueManager] Chapter1 folder not found")
		return
	end

	for _, note in noteConfigs do
		local part = chapter1:FindFirstChild(note.partName)
		if part then
			-- Add ClickDetector if not present
			local detector = part:FindFirstChild("ClickDetector")
			if not detector then
				detector = Instance.new("ClickDetector")
				detector.MaxActivationDistance = 10
				detector.Parent = part
			end

			detector.MouseClick:Connect(function(player)
				if pickedUpNotes[note.partName] then return end
				pickedUpNotes[note.partName] = true

				-- Send note to all players (both should see it)
				local noteEvent = RemoteEvents.get("ShowNote")
				for _, p in Players:GetPlayers() do
					noteEvent:FireClient(p, note.title, note.text)
				end

				-- Hide note part
				part.Transparency = 1
				if part:FindFirstChild("ClickDetector") then
					part.ClickDetector:Destroy()
				end

				print(`[DialogueManager] Note picked up: {note.title}`)
			end)
		else
			warn(`[DialogueManager] Note part not found: {note.partName}`)
		end
	end

	print(`[DialogueManager] Initialized with {#notes} notes`)
end

function DialogueManager.showHint(hintText: string)
	local hintEvent = RemoteEvents.get("ShowHint")
	for _, player in Players:GetPlayers() do
		hintEvent:FireClient(player, hintText)
	end
end

function DialogueManager.getNotesFound(): number
	local count = 0
	for _ in pickedUpNotes do
		count += 1
	end
	return count
end

return DialogueManager
```

- [ ] **Step 2: Verify in Studio**

Play, check Output: `[DialogueManager] Initialized with 2 notes`

- [ ] **Step 3: Commit**

```bash
git add src/server/DialogueManager.luau
git commit -m "feat: add DialogueManager for lore notes and hints"
```

---

### Task 8: ClientController — Boot Script

**Files:**
- Create: `src/client/ClientController.client.luau`

The single client entry point that initializes all client modules.

- [ ] **Step 1: Create ClientController**

```lua
-- src/client/ClientController.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))
local GameEnums = require(Shared:WaitForChild("GameEnums"))

local ClientEffects = require(script.Parent:WaitForChild("ClientEffects"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

-- Initialize modules
ClientEffects.init()
SoundController.init()
UIController.init()

-- Game state changes
RemoteEvents.get("GameStateChanged").OnClientEvent:Connect(function(newState)
	print(`[Client] Game state: {newState}`)

	if newState == GameEnums.GameState.PROLOGUE then
		ClientEffects.setOutdoorMode()
	elseif newState == GameEnums.GameState.GAMEPLAY then
		ClientEffects.setIndoorMode()
	elseif newState == GameEnums.GameState.ESCAPE then
		ClientEffects.startEscapeMode()
	elseif newState == GameEnums.GameState.COMPLETE then
		ClientEffects.setDawnMode()
		SoundController.stopAll()
	end
end)

-- Scare events
RemoteEvents.get("TriggerScare").OnClientEvent:Connect(function(scareType, params)
	if scareType == GameEnums.ScareType.AUDIO then
		SoundController.playScare(params.sound, params.volume)
	elseif scareType == GameEnums.ScareType.VISUAL then
		if params.event == "lights_out" then
			ClientEffects.lightsOut(params.duration)
		end
		if params.whisperSound then
			SoundController.playScare(params.whisperSound, 0.6)
		end
	elseif scareType == GameEnums.ScareType.ENVIRONMENT then
		SoundController.playScare(params.sound or "Door_Slam", 0.8)
		ClientEffects.shake(0.3, 1)
	elseif scareType == GameEnums.ScareType.FALSE_CALM then
		SoundController.fadeOutAmbient(1)
		task.delay(params.silenceDuration, function()
			SoundController.fadeInAmbient(2)
		end)
	elseif scareType == GameEnums.ScareType.DRAUGR then
		SoundController.playScare("Draugr_Growl", 0.5)
		ClientEffects.shake(0.2, 1.5)
		if params.finale then
			SoundController.playScare(params.sound, 1)
			ClientEffects.shake(0.6, 3)
		end
	end
end)

-- Ambient zone changes
RemoteEvents.get("SetAmbientZone").OnClientEvent:Connect(function(zoneData)
	SoundController.setAmbient(zoneData.sound)
	ClientEffects.setFog(zoneData.fogEnd)
	ClientEffects.setColorShift(zoneData.colorShift)
end)

-- Camera shake
RemoteEvents.get("CameraShake").OnClientEvent:Connect(function(params)
	ClientEffects.shake(params.intensity, params.duration)
end)

-- Puzzles
RemoteEvents.get("PuzzleActivated").OnClientEvent:Connect(function(puzzleId, hintText)
	UIController.showHint(hintText, 5)
end)

RemoteEvents.get("PuzzleSolved").OnClientEvent:Connect(function(puzzleId)
	UIController.showHint("Puzzle solved.", 3)
	SoundController.playScare("Puzzle_Solved", 0.7)
end)

-- Notes
RemoteEvents.get("ShowNote").OnClientEvent:Connect(function(title, text)
	UIController.showNote(title, text)
end)

-- Hints
RemoteEvents.get("ShowHint").OnClientEvent:Connect(function(hintText)
	UIController.showHint(hintText, 4)
end)

print("[ClientController] Initialized")
```

- [ ] **Step 2: Verify in Studio**

Play, check Output: `[ClientController] Initialized`

- [ ] **Step 3: Commit**

```bash
git add src/client/ClientController.client.luau
git commit -m "feat: add ClientController boot script routing all events to client modules"
```

---

### Task 9: ClientEffects

**Files:**
- Create: `src/client/ClientEffects.luau`

- [ ] **Step 1: Create ClientEffects**

```lua
-- src/client/ClientEffects.luau
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ClientEffects = {}

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- Lighting effects (created once)
local colorCorrection: ColorCorrectionEffect
local blur: BlurEffect
local vignette: ColorCorrectionEffect -- use saturation/contrast for vignette feel

local shakeThread: thread? = nil

function ClientEffects.init()
	-- Create post-processing effects
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "HorrorCC"
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0.1
	colorCorrection.Saturation = -0.3
	colorCorrection.TintColor = Color3.fromRGB(200, 200, 220)
	colorCorrection.Parent = Lighting

	blur = Instance.new("BlurEffect")
	blur.Name = "HorrorBlur"
	blur.Size = 0
	blur.Parent = Lighting

	print("[ClientEffects] Initialized")
end

function ClientEffects.setOutdoorMode()
	-- Cold blue tones, wide fog
	TweenService:Create(colorCorrection, TweenInfo.new(2), {
		TintColor = Color3.fromRGB(180, 190, 220),
		Saturation = -0.3,
		Contrast = 0.05,
	}):Play()

	Lighting.FogEnd = 150
	Lighting.FogStart = 10
	Lighting.FogColor = Color3.fromRGB(13, 13, 20)
end

function ClientEffects.setIndoorMode()
	-- Warm orange from torches
	TweenService:Create(colorCorrection, TweenInfo.new(3), {
		TintColor = Color3.fromRGB(220, 190, 160),
		Saturation = -0.4,
		Contrast = 0.15,
	}):Play()

	ClientEffects.setFog(80)
end

function ClientEffects.setDawnMode()
	-- Warm sunrise
	TweenService:Create(colorCorrection, TweenInfo.new(5), {
		TintColor = Color3.fromRGB(240, 220, 200),
		Saturation = -0.1,
		Contrast = 0.05,
		Brightness = 0.05,
	}):Play()

	TweenService:Create(Lighting, TweenInfo.new(5), {
		FogEnd = 500,
		ClockTime = 6,
		Brightness = 1,
	}):Play()
end

function ClientEffects.startEscapeMode()
	-- Red danger tint, heavy shake
	TweenService:Create(colorCorrection, TweenInfo.new(1), {
		TintColor = Color3.fromRGB(220, 150, 140),
		Contrast = 0.25,
	}):Play()

	ClientEffects.shake(0.4, 30) -- continuous shake during escape
end

function ClientEffects.setFog(fogEnd: number)
	TweenService:Create(Lighting, TweenInfo.new(2), {
		FogEnd = fogEnd,
		FogStart = fogEnd * 0.1,
	}):Play()
end

function ClientEffects.setColorShift(shift: { number })
	local r = math.clamp(shift[1] * 255 + 150, 0, 255)
	local g = math.clamp(shift[2] * 255 + 150, 0, 255)
	local b = math.clamp(shift[3] * 255 + 150, 0, 255)

	TweenService:Create(colorCorrection, TweenInfo.new(2), {
		TintColor = Color3.fromRGB(r, g, b),
	}):Play()
end

function ClientEffects.lightsOut(duration: number)
	-- Sudden darkness
	local originalBrightness = Lighting.Brightness
	Lighting.Brightness = 0
	colorCorrection.Brightness = -0.5
	blur.Size = 6

	task.delay(duration, function()
		TweenService:Create(Lighting, TweenInfo.new(1), {
			Brightness = originalBrightness,
		}):Play()
		TweenService:Create(colorCorrection, TweenInfo.new(1), {
			Brightness = 0,
		}):Play()
		TweenService:Create(blur, TweenInfo.new(1), {
			Size = 0,
		}):Play()
	end)
end

function ClientEffects.shake(intensity: number, duration: number)
	-- Cancel previous shake
	if shakeThread then
		task.cancel(shakeThread)
		shakeThread = nil
	end

	shakeThread = task.spawn(function()
		local elapsed = 0
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			elapsed += dt
			if elapsed >= duration then
				connection:Disconnect()
				camera.CFrame = camera.CFrame -- reset
				shakeThread = nil
				return
			end

			local progress = elapsed / duration
			local currentIntensity = intensity * (1 - progress) -- fade out
			local offsetX = (math.random() - 0.5) * 2 * currentIntensity
			local offsetY = (math.random() - 0.5) * 2 * currentIntensity

			camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, 0)
		end)
	end)
end

return ClientEffects
```

- [ ] **Step 2: Verify in Studio**

Play, check Output: `[ClientEffects] Initialized`. Lighting should appear dark with slight blue tint.

- [ ] **Step 3: Commit**

```bash
git add src/client/ClientEffects.luau
git commit -m "feat: add ClientEffects with fog, color, shake, and lighting modes"
```

---

### Task 10: SoundController

**Files:**
- Create: `src/client/SoundController.luau`

Sound assets will be referenced by name. In Roblox, sounds are uploaded as audio assets. For development, we use placeholder sound IDs (Roblox library sounds).

- [ ] **Step 1: Create SoundController**

```lua
-- src/client/SoundController.luau
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SoundController = {}

-- Placeholder Roblox asset IDs (replace with real assets later)
-- These are free Roblox library sounds
local SOUND_ASSETS = {
	-- Ambient
	Forest_Night      = "rbxassetid://9114488953",  -- forest ambient
	Cave_Drip         = "rbxassetid://9114227015",  -- cave dripping
	Cave_Hum          = "rbxassetid://9114227015",  -- reuse for now
	Cave_Drip_Deep    = "rbxassetid://9114227015",  -- reuse for now
	Cave_Wind         = "rbxassetid://9114488953",  -- reuse for now
	Cave_Whisper      = "rbxassetid://9114488953",  -- reuse for now
	Draugr_Ambient    = "rbxassetid://9114227015",  -- reuse for now

	-- Scares
	Distant_Scrape    = "rbxassetid://5765933874",  -- metallic scrape
	Door_Slam         = "rbxassetid://5765933874",  -- reuse for now
	Old_Norse_Whisper = "rbxassetid://9114488953",  -- whisper placeholder
	Draugr_Growl      = "rbxassetid://5765933874",  -- growl placeholder
	Draugr_Roar       = "rbxassetid://5765933874",  -- roar placeholder
	Rocks_Falling     = "rbxassetid://5765933874",  -- rocks placeholder
	Puzzle_Solved     = "rbxassetid://9114488953",  -- chime placeholder
}

local ambientSound: Sound? = nil
local scareSounds: { Sound } = {}

function SoundController.init()
	-- Create a SoundGroup for spatial organization
	print("[SoundController] Initialized")
end

function SoundController.setAmbient(soundName: string)
	local assetId = SOUND_ASSETS[soundName]
	if not assetId then
		warn(`[SoundController] Unknown ambient: {soundName}`)
		return
	end

	-- Crossfade to new ambient
	if ambientSound then
		local oldSound = ambientSound
		TweenService:Create(oldSound, TweenInfo.new(2), { Volume = 0 }):Play()
		task.delay(2, function()
			oldSound:Destroy()
		end)
	end

	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = 0
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()

	TweenService:Create(sound, TweenInfo.new(2), { Volume = 0.3 }):Play()
	ambientSound = sound
end

function SoundController.fadeOutAmbient(duration: number)
	if ambientSound then
		TweenService:Create(ambientSound, TweenInfo.new(duration), { Volume = 0 }):Play()
	end
end

function SoundController.fadeInAmbient(duration: number)
	if ambientSound then
		TweenService:Create(ambientSound, TweenInfo.new(duration), { Volume = 0.3 }):Play()
	end
end

function SoundController.playScare(soundName: string, volume: number?)
	local assetId = SOUND_ASSETS[soundName]
	if not assetId then
		warn(`[SoundController] Unknown scare sound: {soundName}`)
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = volume or 0.8
	sound.Looped = false
	sound.Parent = SoundService
	sound:Play()

	-- Auto-cleanup after playing
	sound.Ended:Once(function()
		sound:Destroy()
	end)

	-- Fallback cleanup in case Ended doesn't fire
	task.delay(10, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

function SoundController.stopAll()
	if ambientSound then
		ambientSound:Destroy()
		ambientSound = nil
	end
	for _, sound in scareSounds do
		if sound and sound.Parent then
			sound:Destroy()
		end
	end
	scareSounds = {}
end

return SoundController
```

- [ ] **Step 2: Verify in Studio**

Play, check Output: `[SoundController] Initialized`. No errors about missing assets (sounds will just be silent if IDs are invalid).

- [ ] **Step 3: Commit**

```bash
git add src/client/SoundController.luau
git commit -m "feat: add SoundController with ambient crossfade and scare sounds"
```

---

### Task 11: UIController

**Files:**
- Create: `src/client/UIController.luau`

Minimal HUD: interaction hints, notes overlay, no health bars or minimaps.

- [ ] **Step 1: Create UIController**

```lua
-- src/client/UIController.luau
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIController = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui
local screenGui: ScreenGui

-- UI elements
local hintLabel: TextLabel
local noteFrame: Frame
local noteTitleLabel: TextLabel
local noteTextLabel: TextLabel
local noteCloseButton: TextButton

function UIController.init()
	playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HorrorUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- Hint label (bottom center)
	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Size = UDim2.new(0.6, 0, 0, 40)
	hintLabel.Position = UDim2.new(0.2, 0, 0.85, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.fromRGB(220, 220, 200)
	hintLabel.TextSize = 18
	hintLabel.Font = Enum.Font.Antique
	hintLabel.TextTransparency = 1
	hintLabel.Text = ""
	hintLabel.Parent = screenGui

	-- Note overlay (center, parchment style)
	noteFrame = Instance.new("Frame")
	noteFrame.Name = "NoteFrame"
	noteFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
	noteFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
	noteFrame.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
	noteFrame.BorderSizePixel = 0
	noteFrame.Visible = false
	noteFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = noteFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 85, 65)
	stroke.Thickness = 2
	stroke.Parent = noteFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingBottom = UDim.new(0, 20)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = noteFrame

	noteTitleLabel = Instance.new("TextLabel")
	noteTitleLabel.Name = "Title"
	noteTitleLabel.Size = UDim2.new(1, 0, 0, 30)
	noteTitleLabel.Position = UDim2.new(0, 0, 0, 0)
	noteTitleLabel.BackgroundTransparency = 1
	noteTitleLabel.TextColor3 = Color3.fromRGB(220, 200, 170)
	noteTitleLabel.TextSize = 22
	noteTitleLabel.Font = Enum.Font.Antique
	noteTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	noteTitleLabel.Parent = noteFrame

	noteTextLabel = Instance.new("TextLabel")
	noteTextLabel.Name = "Body"
	noteTextLabel.Size = UDim2.new(1, 0, 1, -60)
	noteTextLabel.Position = UDim2.new(0, 0, 0, 40)
	noteTextLabel.BackgroundTransparency = 1
	noteTextLabel.TextColor3 = Color3.fromRGB(190, 180, 160)
	noteTextLabel.TextSize = 16
	noteTextLabel.Font = Enum.Font.Antique
	noteTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	noteTextLabel.TextYAlignment = Enum.TextYAlignment.Top
	noteTextLabel.TextWrapped = true
	noteTextLabel.Parent = noteFrame

	noteCloseButton = Instance.new("TextButton")
	noteCloseButton.Name = "Close"
	noteCloseButton.Size = UDim2.new(0, 30, 0, 30)
	noteCloseButton.Position = UDim2.new(1, -30, 0, -10)
	noteCloseButton.BackgroundTransparency = 1
	noteCloseButton.TextColor3 = Color3.fromRGB(180, 160, 140)
	noteCloseButton.TextSize = 20
	noteCloseButton.Font = Enum.Font.GothamBold
	noteCloseButton.Text = "X"
	noteCloseButton.Parent = noteFrame

	noteCloseButton.MouseButton1Click:Connect(function()
		noteFrame.Visible = false
	end)

	-- Interaction prompt (E key)
	-- This is handled by Roblox's ProximityPrompt on parts (set up in map)

	print("[UIController] Initialized")
end

function UIController.showHint(text: string, duration: number?)
	hintLabel.Text = text
	TweenService:Create(hintLabel, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()

	task.delay(duration or 4, function()
		TweenService:Create(hintLabel, TweenInfo.new(1), { TextTransparency = 1 }):Play()
	end)
end

function UIController.showNote(title: string, text: string)
	noteTitleLabel.Text = title
	noteTextLabel.Text = text
	noteFrame.Visible = true
end

return UIController
```

- [ ] **Step 2: Verify in Studio**

Play, check Output: `[UIController] Initialized`. ScreenGui "HorrorUI" should appear under PlayerGui (invisible by default — elements hidden until triggered).

- [ ] **Step 3: Commit**

```bash
git add src/client/UIController.luau
git commit -m "feat: add UIController with hint label and parchment note overlay"
```

---

### Task 12: Puzzle Interaction — Client Side

**Files:**
- Modify: `src/client/ClientController.client.luau`

Players need to interact with puzzle elements (runes, altar slots, ritual objects). Roblox's ProximityPrompt is the standard way.

- [ ] **Step 1: Add ProximityPrompt handler to ClientController**

Append to the end of `src/client/ClientController.client.luau`, before the final print:

```lua
-- Puzzle interaction via ProximityPrompt
local ProximityPromptService = game:GetService("ProximityPromptService")

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then return end

	local part = prompt.Parent
	if not part then return end

	-- Check if this part belongs to a puzzle
	local puzzleId = part:GetAttribute("PuzzleId")
	local action = part:GetAttribute("PuzzleAction") or part.Name

	if puzzleId then
		RemoteEvents.get("PuzzleInteract"):FireServer(puzzleId, action, part.Name)
		print(`[Client] Puzzle interact: {puzzleId} / {action} / {part.Name}`)
	end
end)
```

ProximityPrompts and attributes (`PuzzleId`, `PuzzleAction`) are set up on parts in Workspace when building the map (Task 13).

- [ ] **Step 2: Verify — no errors on play**

- [ ] **Step 3: Commit**

```bash
git add src/client/ClientController.client.luau
git commit -m "feat: add ProximityPrompt handler for puzzle interactions"
```

---

### Task 13: Map Building Guide — Workspace Setup in Roblox Studio

**Files:**
- Create: `assets/map-building-guide.md`

This task is done in Roblox Studio (3D editor), not in code. This guide tells you exactly what to build and how to name parts.

- [ ] **Step 1: Create the map building guide**

```markdown
# Chapter 1 Map Building Guide — Roblox Studio

## Folder Structure in Workspace

Create this hierarchy in Explorer:

```
Workspace/
└── Chapter1/                    (Folder)
    ├── PlayerSpawn              (SpawnLocation, hidden)
    ├── Environment/             (Folder)
    │   ├── Forest/              (trees, snow, runic stones)
    │   ├── Entrance/            (mound entrance, door frame)
    │   ├── TutorialCorridor/    (narrow stone corridor)
    │   ├── HallOfRunes/         (large room, runic pillars)
    │   ├── Corridor2/           (narrower corridor)
    │   ├── BurialChamber/       (medium room, altar)
    │   ├── Corridor3/           (narrowest, lowest)
    │   └── DraugrChamber/       (large hall, sarcophagus)
    │
    ├── Triggers/                (Folder — invisible trigger zones)
    │   ├── Zone_Entrance        (Part, CanCollide=false, Transparency=1)
    │   ├── Zone_TutorialCorridor
    │   ├── Zone_HallOfRunes
    │   ├── Zone_Corridor2
    │   ├── Zone_BurialChamber
    │   ├── Zone_Corridor3
    │   ├── Zone_DraugrChamber
    │   └── Escape_Exit          (trigger at mound exit)
    │
    ├── Puzzles/                 (Folder)
    │   ├── Rune_A               (Part with ProximityPrompt, Attribute: PuzzleId="runes")
    │   ├── Rune_B               (same)
    │   ├── Rune_C               (same)
    │   ├── Rune_D               (same)
    │   ├── Sword                (Part, Attribute: PuzzleId="altar", PuzzleAction="Sword")
    │   ├── Goblet               (Part, Attribute: PuzzleId="altar", PuzzleAction="Goblet")
    │   ├── Amulet               (Part, Attribute: PuzzleId="altar", PuzzleAction="Amulet")
    │   ├── Slot_Left            (Part, Attribute: PuzzleId="altar")
    │   ├── Slot_Center          (Part, Attribute: PuzzleId="altar")
    │   ├── Slot_Right           (Part, Attribute: PuzzleId="altar")
    │   ├── Brazier_1            (Part, Attribute: PuzzleId="ritual")
    │   ├── Brazier_2            (Part, Attribute: PuzzleId="ritual")
    │   ├── Sarcophagus_Slot     (Part, Attribute: PuzzleId="ritual")
    │   └── Runestone            (Part, Attribute: PuzzleId="ritual")
    │
    ├── Notes/                   (Folder)
    │   ├── Note_1               (Part with ClickDetector in HallOfRunes side room)
    │   └── Note_2               (Part with ClickDetector in BurialChamber side room)
    │
    ├── Scares/                  (Folder)
    │   ├── Scare1_DraugrSpawn   (Part, Transparency=1, far end of Corridor2)
    │   └── Scare2_DraugrSpawn   (Part, Transparency=1, end of Corridor3)
    │
    ├── Checkpoints/             (Folder)
    │   ├── Checkpoint_1         (Part, Transparency=1, after HallOfRunes)
    │   └── Checkpoint_2         (Part, Transparency=1, after BurialChamber)
    │
    ├── Sarcophagus              (Model — stone coffin in DraugrChamber)
    │
    ├── Draugr                   (Model — humanoid draugr, all parts Transparency=1 initially)
    │
    └── Lighting/                (Folder)
        ├── Torch_1 ... Torch_N  (Parts with PointLight + Fire effect)
        └── DraugrGlow           (PointLight in DraugrChamber, blue-green, Brightness=0.3)
```

## Setting Up Parts

### Trigger Zones
1. Insert → Part → resize to cover the zone
2. Properties: CanCollide=false, Transparency=1, Anchored=true
3. Name: exactly as listed (e.g., "Zone_Entrance")

### Puzzle Parts
1. Create Part (or MeshPart for visual fidelity)
2. Add ProximityPrompt (child): ActionText="Interact", HoldDuration=0.5
3. Add Attributes:
   - PuzzleId (string): "runes", "altar", or "ritual"
   - PuzzleAction (string): optional, the item/action name
4. Name: exactly as listed

### Torches
1. Part (cylinder shape for torch body)
2. Add PointLight: Brightness=0.5, Range=20, Color=warm orange
3. Add Fire particle: Size=3, Heat=10
4. Group as Model, duplicate along corridors

### Draugr Model
1. Simple humanoid model (can use Roblox avatar or build from parts)
2. All BaseParts: Transparency=1 (invisible until ScareManager shows)
3. Optional: add ParticleEmitter for ghostly effect (Rate=0, enable during scares)

## Testing Checklist
- [ ] Walk through all zones — each should trigger in Output
- [ ] Click all rune parts — PuzzleInteract fires
- [ ] Click notes — ShowNote event fires
- [ ] Fog and lighting feel appropriately dark
- [ ] Can walk from entrance to draugr chamber without getting stuck
```

- [ ] **Step 2: Build the map in Roblox Studio following the guide**

Start with basic geometry (grey parts for walls/floors). Polish visuals later. Priority: get the layout and all named parts in place so the code can find them.

- [ ] **Step 3: Save the .rbxl file**

- [ ] **Step 4: Commit the guide**

```bash
git add assets/map-building-guide.md
git commit -m "docs: add Chapter 1 map building guide for Roblox Studio"
```

---

### Task 14: Integration Test — Full Playthrough

- [ ] **Step 1: Start Rojo and connect Studio**

```bash
cd ~/Vibe/lab/roblox-horror
rojo serve
```

Connect in Studio via Rojo plugin.

- [ ] **Step 2: Test lobby → loading flow**

1. File → Play (solo mode)
2. Open Studio command bar, run: `game.ReplicatedStorage.Shared.GameEvents.PlayerReady:FireServer()`
3. Since maxPlayers=2, need second player. For solo testing, temporarily change `Chapter1.maxPlayers = 1` in config
4. Expected: state transitions appear in Output: LOBBY → LOADING → PROLOGUE → GAMEPLAY

- [ ] **Step 3: Test zone triggers**

1. Walk through each zone
2. Expected in Output: `[GameManager] Zone entered: entrance`, `tutorial_corridor`, etc.
3. Expected: ambient sound changes between zones

- [ ] **Step 4: Test Puzzle 1 (Runes)**

1. Walk to HallOfRunes
2. Interact with runes in correct order: Rune_C → Rune_A → Rune_D → Rune_B
3. Expected: `[PuzzleManager] Solved: runes`, then `[ScareManager] Executing scare: DRAUGR`

- [ ] **Step 5: Test Puzzle 2 (Altar)**

1. Walk to BurialChamber
2. Place items on altar in correct order
3. Expected: `[PuzzleManager] Solved: altar`, state → FINALE

- [ ] **Step 6: Test Finale + Escape**

1. Complete ritual in DraugrChamber within 90 seconds
2. Expected: state → ESCAPE, collapse events fire, camera shakes
3. Reach exit → state → COMPLETE

- [ ] **Step 7: Test death/respawn**

1. Die during gameplay (fall off map or let ritual timer expire)
2. Expected: respawn at last checkpoint

- [ ] **Step 8: Final commit**

```bash
git add -A
git commit -m "feat: Chapter 1 complete — Draugr's Mound playable"
```

---

## Sound Assets Needed (Future Polish)

Create `assets/sounds.md` for reference when sourcing real audio:

| Sound Name | Description | Where Used |
|-----------|-------------|-----------|
| Forest_Night | Wind, distant owl, snow crunch ambient | Entrance zone |
| Cave_Drip | Water drops echoing in stone | Tutorial corridor |
| Cave_Hum | Low frequency resonance | Hall of runes |
| Cave_Whisper | Faint unintelligible whispers | Corridor 3 |
| Draugr_Ambient | Deep drone + occasional creak | Draugr chamber |
| Distant_Scrape | Metal on stone, far away | First scare |
| Door_Slam | Heavy stone door closing | Environment scare |
| Old_Norse_Whisper | Whispering in Old Norse (gibberish is fine) | Lights out scare |
| Draugr_Growl | Low guttural growl | Draugr appearances |
| Draugr_Roar | Loud roar | Finale |
| Rocks_Falling | Stone crumbling, debris | Escape sequence |
| Puzzle_Solved | Satisfying stone mechanism click | After each puzzle |
