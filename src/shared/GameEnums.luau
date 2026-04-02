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
