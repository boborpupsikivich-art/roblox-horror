local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ClientEffects = {}

local camera = workspace.CurrentCamera
local colorCorrection: ColorCorrectionEffect
local blur: BlurEffect
local shakeThread: thread? = nil

function ClientEffects.init()
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
	TweenService:Create(colorCorrection, TweenInfo.new(2), {
		TintColor = Color3.fromRGB(180, 190, 220), Saturation = -0.3, Contrast = 0.05,
	}):Play()
	Lighting.FogEnd = 150
	Lighting.FogStart = 10
	Lighting.FogColor = Color3.fromRGB(13, 13, 20)
end

function ClientEffects.setIndoorMode()
	TweenService:Create(colorCorrection, TweenInfo.new(3), {
		TintColor = Color3.fromRGB(220, 190, 160), Saturation = -0.4, Contrast = 0.15,
	}):Play()
	ClientEffects.setFog(80)
end

function ClientEffects.setDawnMode()
	TweenService:Create(colorCorrection, TweenInfo.new(5), {
		TintColor = Color3.fromRGB(240, 220, 200), Saturation = -0.1, Contrast = 0.05, Brightness = 0.05,
	}):Play()
	TweenService:Create(Lighting, TweenInfo.new(5), { FogEnd = 500, ClockTime = 6, Brightness = 1 }):Play()
end

function ClientEffects.startEscapeMode()
	TweenService:Create(colorCorrection, TweenInfo.new(1), {
		TintColor = Color3.fromRGB(220, 150, 140), Contrast = 0.25,
	}):Play()
	ClientEffects.shake(0.4, 30)
end

function ClientEffects.setFog(fogEnd: number)
	TweenService:Create(Lighting, TweenInfo.new(2), { FogEnd = fogEnd, FogStart = fogEnd * 0.1 }):Play()
end

function ClientEffects.setColorShift(shift: { number })
	local r = math.clamp(shift[1] * 255 + 150, 0, 255)
	local g = math.clamp(shift[2] * 255 + 150, 0, 255)
	local b = math.clamp(shift[3] * 255 + 150, 0, 255)
	TweenService:Create(colorCorrection, TweenInfo.new(2), { TintColor = Color3.fromRGB(r, g, b) }):Play()
end

function ClientEffects.lightsOut(duration: number)
	local originalBrightness = Lighting.Brightness
	Lighting.Brightness = 0
	colorCorrection.Brightness = -0.5
	blur.Size = 6
	task.delay(duration, function()
		TweenService:Create(Lighting, TweenInfo.new(1), { Brightness = originalBrightness }):Play()
		TweenService:Create(colorCorrection, TweenInfo.new(1), { Brightness = 0 }):Play()
		TweenService:Create(blur, TweenInfo.new(1), { Size = 0 }):Play()
	end)
end

function ClientEffects.shake(intensity: number, duration: number)
	if shakeThread then task.cancel(shakeThread); shakeThread = nil end
	shakeThread = task.spawn(function()
		local elapsed = 0
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			elapsed += dt
			if elapsed >= duration then connection:Disconnect(); shakeThread = nil; return end
			local ci = intensity * (1 - elapsed / duration)
			camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * 2 * ci, (math.random() - 0.5) * 2 * ci, 0)
		end)
	end)
end

return ClientEffects
