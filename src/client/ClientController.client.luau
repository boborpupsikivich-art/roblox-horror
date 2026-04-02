local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))
local GameEnums = require(Shared:WaitForChild("GameEnums"))

local ClientEffects = require(script.Parent:WaitForChild("ClientEffects"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer

ClientEffects.init()
SoundController.init()
UIController.init()

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

RemoteEvents.get("TriggerScare").OnClientEvent:Connect(function(scareType, params)
	if scareType == GameEnums.ScareType.AUDIO then
		SoundController.playScare(params.sound, params.volume)
	elseif scareType == GameEnums.ScareType.VISUAL then
		if params.event == "lights_out" then ClientEffects.lightsOut(params.duration) end
		if params.whisperSound then SoundController.playScare(params.whisperSound, 0.6) end
	elseif scareType == GameEnums.ScareType.ENVIRONMENT then
		SoundController.playScare(params.sound or "Door_Slam", 0.8)
		ClientEffects.shake(0.3, 1)
	elseif scareType == GameEnums.ScareType.FALSE_CALM then
		SoundController.fadeOutAmbient(1)
		task.delay(params.silenceDuration, function() SoundController.fadeInAmbient(2) end)
	elseif scareType == GameEnums.ScareType.DRAUGR then
		SoundController.playScare("Draugr_Growl", 0.5)
		ClientEffects.shake(0.2, 1.5)
		if params.finale then
			SoundController.playScare(params.sound, 1)
			ClientEffects.shake(0.6, 3)
		end
	end
end)

RemoteEvents.get("SetAmbientZone").OnClientEvent:Connect(function(zoneData)
	SoundController.setAmbient(zoneData.sound)
	ClientEffects.setFog(zoneData.fogEnd)
	ClientEffects.setColorShift(zoneData.colorShift)
end)

RemoteEvents.get("CameraShake").OnClientEvent:Connect(function(params)
	ClientEffects.shake(params.intensity, params.duration)
end)

RemoteEvents.get("PuzzleActivated").OnClientEvent:Connect(function(puzzleId, hintText)
	UIController.showHint(hintText, 5)
end)

RemoteEvents.get("PuzzleSolved").OnClientEvent:Connect(function(puzzleId)
	UIController.showHint("Puzzle solved.", 3)
	SoundController.playScare("Puzzle_Solved", 0.7)
end)

RemoteEvents.get("ShowNote").OnClientEvent:Connect(function(title, text)
	UIController.showNote(title, text)
end)

RemoteEvents.get("ShowHint").OnClientEvent:Connect(function(hintText)
	UIController.showHint(hintText, 4)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then return end
	local part = prompt.Parent
	if not part then return end
	local puzzleId = part:GetAttribute("PuzzleId")
	local action = part:GetAttribute("PuzzleAction") or part.Name
	if puzzleId then
		RemoteEvents.get("PuzzleInteract"):FireServer(puzzleId, action, part.Name)
	end
end)

print("[ClientController] Initialized")
