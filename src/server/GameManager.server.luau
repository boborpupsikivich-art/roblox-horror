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

RemoteEvents.setup()

local currentState = GameEnums.GameState.LOBBY
local currentChapter = nil
local readyPlayers: { Player } = {}
local solvedPuzzles: { [string]: boolean } = {}
local activeCheckpoint: string? = nil
local triggeredZones: { [string]: boolean } = {}

local transitionTo
local setupZoneTriggers
local onPuzzleSolved

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
		activeCheckpoint = nil
		local spawnPoint = workspace:FindFirstChild("Chapter1") and workspace.Chapter1:FindFirstChild("PlayerSpawn")
		if spawnPoint then
			for _, player in Players:GetPlayers() do
				local char = player.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					char.HumanoidRootPart.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0)
				end
			end
		end
		task.wait(1)
		transitionTo(GameEnums.GameState.PROLOGUE)

	elseif newState == GameEnums.GameState.PROLOGUE then
		local zoneData = currentChapter.ambientZones["entrance"]
		local ambientEvent = RemoteEvents.get("SetAmbientZone")
		for _, player in Players:GetPlayers() do
			ambientEvent:FireClient(player, zoneData)
		end
		setupZoneTriggers()
		PuzzleManager.init(currentChapter.puzzles, onPuzzleSolved)
		ScareManager.init(currentChapter.scares)
		DialogueManager.init(currentChapter.notes)
		PuzzleManager.activate("runes")
		task.wait(2)
		transitionTo(GameEnums.GameState.GAMEPLAY)

	elseif newState == GameEnums.GameState.FINALE then
		PuzzleManager.activate("ritual")
		ScareManager.triggerFinale(currentChapter)

	elseif newState == GameEnums.GameState.ESCAPE then
		local escapeConfig = currentChapter.escape
		for _, event in escapeConfig.collapseEvents do
			task.delay(event.delay, function()
				ScareManager.triggerCollapseEvent(event.event)
			end)
		end
		task.delay(escapeConfig.duration, function()
			if currentState == GameEnums.GameState.ESCAPE then
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
		task.wait(3)
		print("[GameManager] Chapter complete!")
	end
end

onPuzzleSolved = function(puzzleId: string)
	solvedPuzzles[puzzleId] = true
	print(`[GameManager] Puzzle solved: {puzzleId}`)
	ScareManager.onPuzzleSolved(puzzleId)

	for _, cp in currentChapter.checkpoints do
		if cp.afterPuzzle == puzzleId then
			activeCheckpoint = cp.spawnPoint
		end
	end

	if puzzleId == "runes" then
		PuzzleManager.activate("altar")
	elseif puzzleId == "altar" then
		transitionTo(GameEnums.GameState.FINALE)
	elseif puzzleId == "ritual" then
		transitionTo(GameEnums.GameState.ESCAPE)
	end
end

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
					local zoneData = currentChapter.ambientZones[zone.name]
					if zoneData then
						local ambientEvent = RemoteEvents.get("SetAmbientZone")
						for _, p in Players:GetPlayers() do
							ambientEvent:FireClient(p, zoneData)
						end
					end
					ScareManager.onZoneEnter(zone.name)
				end
			end)
		else
			warn(`[GameManager] Trigger part not found: {zone.trigger}`)
		end
	end

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

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			task.wait(3)
			if activeCheckpoint then
				local chapter1 = workspace:FindFirstChild("Chapter1")
				local spawnPart = chapter1 and chapter1:FindFirstChild(activeCheckpoint)
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
