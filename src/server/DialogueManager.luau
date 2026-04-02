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

	local chapter1 = workspace:FindFirstChild("Chapter1")
	if not chapter1 then
		warn("[DialogueManager] Chapter1 folder not found")
		return
	end

	for _, note in noteConfigs do
		local part = chapter1:FindFirstChild(note.partName)
		if part then
			local detector = part:FindFirstChild("ClickDetector")
			if not detector then
				detector = Instance.new("ClickDetector")
				detector.MaxActivationDistance = 10
				detector.Parent = part
			end
			detector.MouseClick:Connect(function(player)
				if pickedUpNotes[note.partName] then return end
				pickedUpNotes[note.partName] = true
				local noteEvent = RemoteEvents.get("ShowNote")
				for _, p in Players:GetPlayers() do
					noteEvent:FireClient(p, note.title, note.text)
				end
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
