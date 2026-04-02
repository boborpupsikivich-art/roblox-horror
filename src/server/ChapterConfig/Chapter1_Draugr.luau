local GameEnums = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameEnums"))

local Chapter1 = {}

Chapter1.name = "The Draugr's Mound"
Chapter1.description = "A cursed Viking burial mound. Something stirs within."
Chapter1.maxPlayers = 2

Chapter1.zones = {
	{ name = "entrance",        trigger = "Zone_Entrance" },
	{ name = "tutorial_corridor", trigger = "Zone_TutorialCorridor" },
	{ name = "hall_of_runes",   trigger = "Zone_HallOfRunes" },
	{ name = "corridor_2",     trigger = "Zone_Corridor2" },
	{ name = "burial_chamber",  trigger = "Zone_BurialChamber" },
	{ name = "corridor_3",     trigger = "Zone_Corridor3" },
	{ name = "draugr_chamber",  trigger = "Zone_DraugrChamber" },
}

Chapter1.ambientZones = {
	entrance           = { sound = "Forest_Night", fogEnd = 150, colorShift = {0.1, 0.1, 0.2} },
	tutorial_corridor  = { sound = "Cave_Drip", fogEnd = 80, colorShift = {0.15, 0.1, 0.05} },
	hall_of_runes      = { sound = "Cave_Hum", fogEnd = 60, colorShift = {0.15, 0.1, 0.05} },
	corridor_2         = { sound = "Cave_Drip_Deep", fogEnd = 40, colorShift = {0.1, 0.08, 0.04} },
	burial_chamber     = { sound = "Cave_Wind", fogEnd = 50, colorShift = {0.1, 0.08, 0.04} },
	corridor_3         = { sound = "Cave_Whisper", fogEnd = 30, colorShift = {0.05, 0.08, 0.04} },
	draugr_chamber     = { sound = "Draugr_Ambient", fogEnd = 40, colorShift = {0.03, 0.07, 0.05} },
}

Chapter1.puzzles = {
	{
		id = "runes",
		zone = "hall_of_runes",
		type = "sequence",
		description = "Press 4 runes in correct order. Hint: floor pattern.",
		elements = { "Rune_A", "Rune_B", "Rune_C", "Rune_D" },
		solution = { "Rune_C", "Rune_A", "Rune_D", "Rune_B" },
		hintText = "The floor pattern shows the way: wave, eye, tree, shield.",
		onSolve = "open_door_to_corridor2",
	},
	{
		id = "altar",
		zone = "burial_chamber",
		type = "placement",
		description = "Place 3 items on altar in correct positions.",
		items = { "Sword", "Goblet", "Amulet" },
		slots = { "Slot_Left", "Slot_Center", "Slot_Right" },
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

Chapter1.scares = {
	{
		trigger = { type = "zone_enter", zone = "tutorial_corridor" },
		scareType = GameEnums.ScareType.AUDIO,
		params = { sound = "Distant_Scrape", delay = 3, volume = 0.4 },
	},
	{
		trigger = { type = "puzzle_solved", puzzleId = "runes" },
		scareType = GameEnums.ScareType.DRAUGR,
		params = { spawnPoint = "Scare1_DraugrSpawn", duration = 2.5, animation = "stand_and_stare", distance = "far" },
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
		params = { spawnPoint = "Scare2_DraugrSpawn", duration = 3, animation = "stand_and_stare", distance = "medium" },
	},
}

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

Chapter1.checkpoints = {
	{ afterPuzzle = "runes", spawnPoint = "Checkpoint_1" },
	{ afterPuzzle = "altar", spawnPoint = "Checkpoint_2" },
}

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
