local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundController = {}

-- Placeholder Roblox asset IDs (replace with real assets later)
local SOUND_ASSETS = {
	Forest_Night      = "rbxassetid://9114488953",
	Cave_Drip         = "rbxassetid://9114227015",
	Cave_Hum          = "rbxassetid://9114227015",
	Cave_Drip_Deep    = "rbxassetid://9114227015",
	Cave_Wind         = "rbxassetid://9114488953",
	Cave_Whisper      = "rbxassetid://9114488953",
	Draugr_Ambient    = "rbxassetid://9114227015",
	Distant_Scrape    = "rbxassetid://5765933874",
	Door_Slam         = "rbxassetid://5765933874",
	Old_Norse_Whisper = "rbxassetid://9114488953",
	Draugr_Growl      = "rbxassetid://5765933874",
	Draugr_Roar       = "rbxassetid://5765933874",
	Rocks_Falling     = "rbxassetid://5765933874",
	Puzzle_Solved     = "rbxassetid://9114488953",
}

local ambientSound: Sound? = nil

function SoundController.init()
	print("[SoundController] Initialized")
end

function SoundController.setAmbient(soundName: string)
	local assetId = SOUND_ASSETS[soundName]
	if not assetId then warn(`[SoundController] Unknown ambient: {soundName}`); return end
	if ambientSound then
		local old = ambientSound
		TweenService:Create(old, TweenInfo.new(2), { Volume = 0 }):Play()
		task.delay(2, function() old:Destroy() end)
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
	if ambientSound then TweenService:Create(ambientSound, TweenInfo.new(duration), { Volume = 0 }):Play() end
end

function SoundController.fadeInAmbient(duration: number)
	if ambientSound then TweenService:Create(ambientSound, TweenInfo.new(duration), { Volume = 0.3 }):Play() end
end

function SoundController.playScare(soundName: string, volume: number?)
	local assetId = SOUND_ASSETS[soundName]
	if not assetId then warn(`[SoundController] Unknown scare sound: {soundName}`); return end
	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = volume or 0.8
	sound.Looped = false
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function() sound:Destroy() end)
	task.delay(10, function() if sound and sound.Parent then sound:Destroy() end end)
end

function SoundController.stopAll()
	if ambientSound then ambientSound:Destroy(); ambientSound = nil end
end

return SoundController
