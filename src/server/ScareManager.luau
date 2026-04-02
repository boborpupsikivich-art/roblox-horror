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

	if scare.scareType == GameEnums.ScareType.DRAUGR then
		local chapter1 = workspace:FindFirstChild("Chapter1")
		if chapter1 then
			local spawnPoint = chapter1:FindFirstChild(scare.params.spawnPoint)
			local draugrModel = chapter1:FindFirstChild("Draugr")
			if spawnPoint and draugrModel then
				draugrModel:PivotTo(spawnPoint.CFrame)
				for _, part in draugrModel:GetDescendants() do
					if part:IsA("BasePart") then part.Transparency = 0 end
				end
				task.delay(scare.params.duration, function()
					for _, part in draugrModel:GetDescendants() do
						if part:IsA("BasePart") then part.Transparency = 1 end
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
	local sarcophagus = chapter1:FindFirstChild("Sarcophagus")
	if sarcophagus then
		draugrModel:PivotTo(sarcophagus.CFrame + Vector3.new(0, 3, 0))
	end
	for _, part in draugrModel:GetDescendants() do
		if part:IsA("BasePart") then part.Transparency = 0 end
	end
	local scareEvent = RemoteEvents.get("TriggerScare")
	for _, player in Players:GetPlayers() do
		scareEvent:FireClient(player, GameEnums.ScareType.DRAUGR, { finale = true, sound = "Draugr_Roar" })
	end
end

function ScareManager.triggerCollapseEvent(eventName: string)
	print(`[ScareManager] Collapse event: {eventName}`)
	local shakeEvent = RemoteEvents.get("CameraShake")
	local scareEvent = RemoteEvents.get("TriggerScare")
	for _, player in Players:GetPlayers() do
		shakeEvent:FireClient(player, { intensity = 0.8, duration = 2 })
		scareEvent:FireClient(player, GameEnums.ScareType.ENVIRONMENT, { event = eventName, sound = "Rocks_Falling" })
	end
end

return ScareManager
