local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

local eventNames = {
	"GameStateChanged",
	"PlayerReady",
	"TriggerScare",
	"PuzzleActivated",
	"PuzzleSolved",
	"PuzzleInteract",
	"ShowNote",
	"ShowHint",
	"SetAmbientZone",
	"CameraShake",
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
