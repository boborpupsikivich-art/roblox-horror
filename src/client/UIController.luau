local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIController = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui
local hintLabel: TextLabel
local noteFrame: Frame

function UIController.init()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HorrorUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Size = UDim2.new(0.6, 0, 0, 40)
	hintLabel.Position = UDim2.new(0.2, 0, 0.85, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.fromRGB(220, 220, 200)
	hintLabel.TextSize = 18
	hintLabel.Font = Enum.Font.Antique
	hintLabel.TextTransparency = 1
	hintLabel.Text = ""
	hintLabel.Parent = screenGui

	noteFrame = Instance.new("Frame")
	noteFrame.Name = "NoteFrame"
	noteFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
	noteFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
	noteFrame.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
	noteFrame.BorderSizePixel = 0
	noteFrame.Visible = false
	noteFrame.Parent = screenGui

	Instance.new("UICorner", noteFrame).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", noteFrame)
	stroke.Color = Color3.fromRGB(100, 85, 65)
	stroke.Thickness = 2
	local pad = Instance.new("UIPadding", noteFrame)
	pad.PaddingTop = UDim.new(0, 20)
	pad.PaddingBottom = UDim.new(0, 20)
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)

	local title = Instance.new("TextLabel", noteFrame)
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 200, 170)
	title.TextSize = 22
	title.Font = Enum.Font.Antique
	title.TextXAlignment = Enum.TextXAlignment.Left

	local body = Instance.new("TextLabel", noteFrame)
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -60)
	body.Position = UDim2.new(0, 0, 0, 40)
	body.BackgroundTransparency = 1
	body.TextColor3 = Color3.fromRGB(190, 180, 160)
	body.TextSize = 16
	body.Font = Enum.Font.Antique
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true

	local closeBtn = Instance.new("TextButton", noteFrame)
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -30, 0, -10)
	closeBtn.BackgroundTransparency = 1
	closeBtn.TextColor3 = Color3.fromRGB(180, 160, 140)
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.MouseButton1Click:Connect(function() noteFrame.Visible = false end)

	print("[UIController] Initialized")
end

function UIController.showHint(text: string, duration: number?)
	hintLabel.Text = text
	TweenService:Create(hintLabel, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	task.delay(duration or 4, function()
		TweenService:Create(hintLabel, TweenInfo.new(1), { TextTransparency = 1 }):Play()
	end)
end

function UIController.showNote(title: string, text: string)
	local t = noteFrame:FindFirstChild("Title")
	local b = noteFrame:FindFirstChild("Body")
	if t then t.Text = title end
	if b then b.Text = text end
	noteFrame.Visible = true
end

return UIController
