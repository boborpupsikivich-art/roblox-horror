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

	local event = RemoteEvents.get("PuzzleActivated")
	local config = puzzles[puzzleId]
	for _, player in Players:GetPlayers() do
		event:FireClient(player, puzzleId, config.hintText)
	end

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
		table.insert(progress.steps, target)
		for i, step in progress.steps do
			if config.solution[i] ~= step then
				progress.steps = {}
				return
			end
		end
		if #progress.steps == #config.solution then
			PuzzleManager.solve(puzzleId)
		end

	elseif config.type == "placement" then
		progress.placements[target] = action
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
		table.insert(progress.steps, target)
		local stepIndex = #progress.steps
		local expectedStep = config.steps[stepIndex]
		if expectedStep and expectedStep.target == target then
			if stepIndex == #config.steps then
				PuzzleManager.solve(puzzleId)
			end
		else
			progress.steps = {}
		end
	end
end

function PuzzleManager.solve(puzzleId: string)
	puzzleStates[puzzleId] = GameEnums.PuzzleState.SOLVED
	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end
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
