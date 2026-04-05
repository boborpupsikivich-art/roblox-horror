-- MapBuilder: procedurally generates Chapter 1 map (Draugr's Mound) at runtime
-- Creates all zones, puzzles, triggers, lighting, spawns as described in map-building-guide.md

local Lighting = game:GetService("Lighting")

local MAP_NAME = "Chapter1"

-- Check if map already exists (rebuild on server start only)
if workspace:FindFirstChild(MAP_NAME) then
	workspace[MAP_NAME]:Destroy()
end

print("[MapBuilder] Building Chapter 1: The Draugr's Mound...")

-- =============================================================================
-- UTILITIES
-- =============================================================================
local function make(className, name, parent, props)
	local inst = Instance.new(className)
	inst.Name = name
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function part(name, parent, size, position, color, material)
	return make("Part", name, parent, {
		Size = size,
		Position = position,
		Color = color or Color3.fromRGB(90, 80, 70),
		Material = material or Enum.Material.Slate,
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
end

local function trigger(name, parent, size, position)
	return make("Part", name, parent, {
		Size = size,
		Position = position,
		Transparency = 1,
		CanCollide = false,
		Anchored = true,
		CastShadow = false,
	})
end

local function room(parent, center, size, name, floorColor)
	-- Creates a hollow box: floor, ceiling, 4 walls
	local group = make("Folder", name, parent, {})
	local hw, hh, hd = size.X / 2, size.Y / 2, size.Z / 2
	local wallThick = 2

	-- Floor
	part("Floor", group, Vector3.new(size.X, wallThick, size.Z),
		center - Vector3.new(0, hh, 0), floorColor or Color3.fromRGB(70, 60, 50), Enum.Material.Slate)
	-- Ceiling
	part("Ceiling", group, Vector3.new(size.X, wallThick, size.Z),
		center + Vector3.new(0, hh, 0), Color3.fromRGB(50, 40, 35), Enum.Material.Rock)
	-- North wall
	part("WallN", group, Vector3.new(size.X, size.Y, wallThick),
		center + Vector3.new(0, 0, hd), Color3.fromRGB(85, 75, 65), Enum.Material.Rock)
	-- South wall
	part("WallS", group, Vector3.new(size.X, size.Y, wallThick),
		center - Vector3.new(0, 0, hd), Color3.fromRGB(85, 75, 65), Enum.Material.Rock)
	-- East wall
	part("WallE", group, Vector3.new(wallThick, size.Y, size.Z),
		center + Vector3.new(hw, 0, 0), Color3.fromRGB(85, 75, 65), Enum.Material.Rock)
	-- West wall
	part("WallW", group, Vector3.new(wallThick, size.Y, size.Z),
		center - Vector3.new(hw, 0, 0), Color3.fromRGB(85, 75, 65), Enum.Material.Rock)

	return group
end

local function corridor(parent, startPos, endPos, width, height, name)
	-- Creates a corridor between two points (axis-aligned)
	local group = make("Folder", name, parent, {})
	local delta = endPos - startPos
	local center = startPos + delta / 2
	local length = delta.Magnitude
	local size
	if math.abs(delta.X) > math.abs(delta.Z) then
		size = Vector3.new(length, height, width)
	else
		size = Vector3.new(width, height, length)
	end
	local hh = height / 2
	-- Floor
	part("Floor", group, Vector3.new(size.X, 1, size.Z),
		center - Vector3.new(0, hh, 0), Color3.fromRGB(60, 50, 40), Enum.Material.Slate)
	-- Ceiling
	part("Ceiling", group, Vector3.new(size.X, 1, size.Z),
		center + Vector3.new(0, hh, 0), Color3.fromRGB(40, 30, 25), Enum.Material.Rock)
	-- Walls (axis-specific)
	if math.abs(delta.X) > math.abs(delta.Z) then
		part("WallN", group, Vector3.new(size.X, height, 1),
			center + Vector3.new(0, 0, size.Z / 2), Color3.fromRGB(75, 65, 55), Enum.Material.Rock)
		part("WallS", group, Vector3.new(size.X, height, 1),
			center - Vector3.new(0, 0, size.Z / 2), Color3.fromRGB(75, 65, 55), Enum.Material.Rock)
	else
		part("WallE", group, Vector3.new(1, height, size.Z),
			center + Vector3.new(size.X / 2, 0, 0), Color3.fromRGB(75, 65, 55), Enum.Material.Rock)
		part("WallW", group, Vector3.new(1, height, size.Z),
			center - Vector3.new(size.X / 2, 0, 0), Color3.fromRGB(75, 65, 55), Enum.Material.Rock)
	end
	return group
end

local function torch(parent, position)
	local model = make("Model", "Torch", parent, {})
	local body = part("Body", model, Vector3.new(0.5, 2, 0.5), position,
		Color3.fromRGB(50, 30, 15), Enum.Material.Wood)
	body.Shape = Enum.PartType.Cylinder
	body.Orientation = Vector3.new(0, 0, 90)
	make("PointLight", "Light", body, {
		Brightness = 2,
		Range = 18,
		Color = Color3.fromRGB(255, 180, 100),
	})
	make("Fire", "Fire", body, {
		Size = 3,
		Heat = 10,
		Color = Color3.fromRGB(255, 140, 60),
		SecondaryColor = Color3.fromRGB(255, 80, 20),
	})
	return model
end

local function puzzleItem(parent, name, position, color, puzzleId, action)
	local p = part(name, parent, Vector3.new(3, 4, 3), position, color, Enum.Material.Marble)
	p:SetAttribute("PuzzleId", puzzleId)
	if action then
		p:SetAttribute("PuzzleAction", action)
	end
	-- Add ProximityPrompt so players can interact
	make("ProximityPrompt", "Prompt", p, {
		ActionText = "Activate",
		ObjectText = name,
		HoldDuration = 0.5,
		MaxActivationDistance = 10,
	})
	-- Emissive glow
	make("PointLight", "Glow", p, {
		Brightness = 0.5,
		Range = 8,
		Color = color,
	})
	return p
end

-- =============================================================================
-- BUILD MAP
-- =============================================================================
local chapter = make("Folder", MAP_NAME, workspace, {})

-- Rooms layout (Y=0 floor level, going south-to-north along Z axis)
-- Each room's center Z coordinate
local Y_FLOOR = 0
local ROOM_Y = 8 -- ceiling height

-- Spawn point (outside the mound, to the south)
make("SpawnLocation", "PlayerSpawn", chapter, {
	Size = Vector3.new(6, 1, 6),
	Position = Vector3.new(0, 1, -40),
	Anchored = true,
	CanCollide = true,
	Transparency = 0.5,
	BrickColor = BrickColor.new("Forest green"),
	Neutral = true,
	Enabled = true,
})

-- Ground around spawn (forest area)
part("ForestGround", chapter, Vector3.new(80, 1, 60),
	Vector3.new(0, -0.5, -50), Color3.fromRGB(40, 55, 30), Enum.Material.Grass)

-- Environment folder
local envFolder = make("Folder", "Environment", chapter, {})

-- 1. Entrance chamber (small, Z=-15)
local entranceCenter = Vector3.new(0, Y_FLOOR + ROOM_Y / 2, -15)
room(envFolder, entranceCenter, Vector3.new(14, ROOM_Y, 10), "Entrance",
	Color3.fromRGB(80, 70, 60))

-- 2. Tutorial corridor (Z=-10 to Z=0)
corridor(envFolder, Vector3.new(0, Y_FLOOR + ROOM_Y / 2, -10),
	Vector3.new(0, Y_FLOOR + ROOM_Y / 2, 0), 6, ROOM_Y, "TutorialCorridor")

-- 3. Hall of Runes (large, Z=15)
local hallCenter = Vector3.new(0, Y_FLOOR + ROOM_Y / 2, 15)
room(envFolder, hallCenter, Vector3.new(24, ROOM_Y + 2, 20), "HallOfRunes",
	Color3.fromRGB(65, 55, 50))

-- 4. Corridor 2 (Z=25 to Z=35)
corridor(envFolder, Vector3.new(0, Y_FLOOR + ROOM_Y / 2, 25),
	Vector3.new(0, Y_FLOOR + ROOM_Y / 2, 35), 5, ROOM_Y - 1, "Corridor2")

-- 5. Burial Chamber (medium, Z=45)
local burialCenter = Vector3.new(0, Y_FLOOR + ROOM_Y / 2, 45)
room(envFolder, burialCenter, Vector3.new(18, ROOM_Y, 16), "BurialChamber",
	Color3.fromRGB(55, 45, 40))

-- 6. Corridor 3 (narrowest, Z=53 to Z=63)
corridor(envFolder, Vector3.new(0, Y_FLOOR + ROOM_Y / 2 - 1, 53),
	Vector3.new(0, Y_FLOOR + ROOM_Y / 2 - 1, 63), 4, ROOM_Y - 2, "Corridor3")

-- 7. Draugr Chamber (huge, Z=80)
local draugrCenter = Vector3.new(0, Y_FLOOR + ROOM_Y / 2, 80)
room(envFolder, draugrCenter, Vector3.new(30, ROOM_Y + 4, 25), "DraugrChamber",
	Color3.fromRGB(40, 30, 30))

-- =============================================================================
-- TRIGGERS
-- =============================================================================
local triggersFolder = make("Folder", "Triggers", chapter, {})
trigger("Zone_Entrance", triggersFolder, Vector3.new(14, 6, 10), entranceCenter)
trigger("Zone_TutorialCorridor", triggersFolder, Vector3.new(6, 6, 10), Vector3.new(0, Y_FLOOR + 3, -5))
trigger("Zone_HallOfRunes", triggersFolder, Vector3.new(24, 6, 20), hallCenter)
trigger("Zone_Corridor2", triggersFolder, Vector3.new(5, 6, 10), Vector3.new(0, Y_FLOOR + 3, 30))
trigger("Zone_BurialChamber", triggersFolder, Vector3.new(18, 6, 16), burialCenter)
trigger("Zone_Corridor3", triggersFolder, Vector3.new(4, 6, 10), Vector3.new(0, Y_FLOOR + 3, 58))
trigger("Zone_DraugrChamber", triggersFolder, Vector3.new(30, 6, 25), draugrCenter)
trigger("Escape_Exit", triggersFolder, Vector3.new(6, 4, 2),
	Vector3.new(0, 2, -42))

-- =============================================================================
-- PUZZLES
-- =============================================================================
local puzzlesFolder = make("Folder", "Puzzles", chapter, {})

-- Rune puzzle in Hall of Runes (4 runes around the room)
puzzleItem(puzzlesFolder, "Rune_A", Vector3.new(-8, 2, 10),
	Color3.fromRGB(200, 150, 80), "runes", "A")
puzzleItem(puzzlesFolder, "Rune_B", Vector3.new(8, 2, 10),
	Color3.fromRGB(200, 150, 80), "runes", "B")
puzzleItem(puzzlesFolder, "Rune_C", Vector3.new(-8, 2, 20),
	Color3.fromRGB(200, 150, 80), "runes", "C")
puzzleItem(puzzlesFolder, "Rune_D", Vector3.new(8, 2, 20),
	Color3.fromRGB(200, 150, 80), "runes", "D")

-- Altar items in Burial Chamber
puzzleItem(puzzlesFolder, "Sword", Vector3.new(-6, 2, 42),
	Color3.fromRGB(180, 180, 200), "altar", "Sword")
puzzleItem(puzzlesFolder, "Goblet", Vector3.new(0, 2, 42),
	Color3.fromRGB(220, 180, 60), "altar", "Goblet")
puzzleItem(puzzlesFolder, "Amulet", Vector3.new(6, 2, 42),
	Color3.fromRGB(80, 150, 200), "altar", "Amulet")
puzzleItem(puzzlesFolder, "Slot_Left", Vector3.new(-3, 2, 48),
	Color3.fromRGB(100, 80, 60), "altar")
puzzleItem(puzzlesFolder, "Slot_Center", Vector3.new(0, 2, 48),
	Color3.fromRGB(100, 80, 60), "altar")
puzzleItem(puzzlesFolder, "Slot_Right", Vector3.new(3, 2, 48),
	Color3.fromRGB(100, 80, 60), "altar")

-- Ritual items in Draugr Chamber
puzzleItem(puzzlesFolder, "Brazier_1", Vector3.new(-10, 2, 75),
	Color3.fromRGB(180, 100, 60), "ritual")
puzzleItem(puzzlesFolder, "Brazier_2", Vector3.new(10, 2, 75),
	Color3.fromRGB(180, 100, 60), "ritual")
puzzleItem(puzzlesFolder, "Sarcophagus_Slot", Vector3.new(0, 2, 85),
	Color3.fromRGB(120, 100, 80), "ritual")
puzzleItem(puzzlesFolder, "Runestone", Vector3.new(0, 2, 80),
	Color3.fromRGB(150, 120, 90), "ritual")

-- =============================================================================
-- NOTES (lore)
-- =============================================================================
local notesFolder = make("Folder", "Notes", chapter, {})
local note1 = part("Note_1", notesFolder, Vector3.new(1, 0.1, 1.5),
	Vector3.new(-10, 2, 18), Color3.fromRGB(200, 180, 140), Enum.Material.Sand)
make("ClickDetector", "Click", note1, { MaxActivationDistance = 8 })
local note2 = part("Note_2", notesFolder, Vector3.new(1, 0.1, 1.5),
	Vector3.new(8, 2, 48), Color3.fromRGB(200, 180, 140), Enum.Material.Sand)
make("ClickDetector", "Click", note2, { MaxActivationDistance = 8 })

-- =============================================================================
-- SCARES (invisible spawn points)
-- =============================================================================
local scaresFolder = make("Folder", "Scares", chapter, {})
trigger("Scare1_DraugrSpawn", scaresFolder, Vector3.new(2, 2, 2),
	Vector3.new(0, 2, 34))
trigger("Scare2_DraugrSpawn", scaresFolder, Vector3.new(2, 2, 2),
	Vector3.new(0, 2, 62))

-- =============================================================================
-- CHECKPOINTS
-- =============================================================================
local checkpointsFolder = make("Folder", "Checkpoints", chapter, {})
trigger("Checkpoint_1", checkpointsFolder, Vector3.new(2, 2, 2),
	Vector3.new(0, 2, 25))
trigger("Checkpoint_2", checkpointsFolder, Vector3.new(2, 2, 2),
	Vector3.new(0, 2, 53))

-- =============================================================================
-- SARCOPHAGUS (in Draugr Chamber)
-- =============================================================================
local sarcModel = make("Model", "Sarcophagus", chapter, {})
part("Base", sarcModel, Vector3.new(6, 2, 10),
	Vector3.new(0, 1, 85), Color3.fromRGB(90, 80, 70), Enum.Material.Slate)
part("Lid", sarcModel, Vector3.new(6, 0.5, 10),
	Vector3.new(0, 2.25, 85), Color3.fromRGB(110, 100, 90), Enum.Material.Marble)

-- =============================================================================
-- DRAUGR MODEL — humanoid shape, invisible until ScareManager reveals
-- =============================================================================
local draugrModel = make("Model", "Draugr", chapter, {})
local draugrColor = Color3.fromRGB(65, 75, 55)
local draugrBodyParts = {
	{ n = "Torso",    s = Vector3.new(2, 2.5, 1),   p = Vector3.new(0, 10, 80),   c = draugrColor },
	{ n = "Head",     s = Vector3.new(1.2, 1.4, 1), p = Vector3.new(0, 12, 80),   c = Color3.fromRGB(85, 95, 70), ball = true },
	{ n = "LeftArm",  s = Vector3.new(0.7, 2.5, 0.7), p = Vector3.new(-1.5, 10, 80), c = draugrColor },
	{ n = "RightArm", s = Vector3.new(0.7, 2.5, 0.7), p = Vector3.new(1.5, 10, 80),  c = draugrColor },
	{ n = "LeftLeg",  s = Vector3.new(0.8, 2.5, 0.8), p = Vector3.new(-0.5, 7, 80),  c = draugrColor },
	{ n = "RightLeg", s = Vector3.new(0.8, 2.5, 0.8), p = Vector3.new(0.5, 7, 80),   c = draugrColor },
}
for _, bp in draugrBodyParts do
	local pp = part(bp.n, draugrModel, bp.s, bp.p, bp.c, Enum.Material.Slate)
	pp.Transparency = 1
	pp.CanCollide = false
	if bp.ball then pp.Shape = Enum.PartType.Ball end
end
make("PointLight", "Glow", draugrModel:FindFirstChild("Torso"), {
	Brightness = 0.4,
	Range = 20,
	Color = Color3.fromRGB(80, 200, 170),
	Enabled = false,
})

-- =============================================================================
-- FOREST: trees + runestones in south area (forest outside the mound)
-- =============================================================================
local forestFolder = make("Folder", "Forest", chapter, {})
math.randomseed(42)
for i = 1, 30 do
	local x = math.random(-35, 35)
	local z = math.random(-75, -22)
	if math.abs(x) < 4 and z > -42 then x = x + 10 end
	local treeH = math.random(6, 12)
	local tree = make("Model", "Tree_" .. i, forestFolder, {})
	local trunk = make("Part", "Trunk", tree, {
		Size = Vector3.new(1.5, treeH, 1.5),
		Color = Color3.fromRGB(55, 35, 20),
		Material = Enum.Material.Wood,
		Anchored = true,
	})
	trunk.CFrame = CFrame.new(x, treeH / 2, z)
	for j = 1, 3 do
		local sz = math.random(4, 7)
		make("Part", "Foliage", tree, {
			Size = Vector3.new(sz, sz, sz),
			Position = Vector3.new(x + math.random(-2, 2), treeH + math.random(-1, 2), z + math.random(-2, 2)),
			Color = Color3.fromRGB(30 + math.random(0, 20), 55 + math.random(0, 20), 25),
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
			Anchored = true,
		})
	end
end
for i = 1, 5 do
	local x = math.random(-30, 30)
	local z = math.random(-55, -25)
	make("Part", "Runestone_" .. i, forestFolder, {
		Size = Vector3.new(1.5, math.random(4, 7), 0.8),
		Position = Vector3.new(x, 3, z),
		Color = Color3.fromRGB(120, 110, 100),
		Material = Enum.Material.Slate,
		Anchored = true,
		Orientation = Vector3.new(0, math.random(0, 180), math.random(-10, 10)),
	})
end

-- =============================================================================
-- BONES AND SKULLS — scattered decor in burial/draugr chambers
-- =============================================================================
local bonesFolder = make("Folder", "Bones", chapter, {})
for i = 1, 8 do
	local x = math.random(-8, 8)
	local z = 40 + math.random(-6, 6)
	make("Part", "Bone_" .. i, bonesFolder, {
		Size = Vector3.new(0.3, 0.3, math.random(2, 4)),
		Position = Vector3.new(x, 0.2, z),
		Color = Color3.fromRGB(220, 210, 190),
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		Orientation = Vector3.new(0, math.random(0, 180), 0),
	})
end
for i = 1, 4 do
	local x = math.random(-12, 12)
	local z = 80 + math.random(-10, 10)
	make("Part", "Skull_" .. i, bonesFolder, {
		Size = Vector3.new(1.2, 1, 1.3),
		Position = Vector3.new(x, 0.6, z),
		Color = Color3.fromRGB(230, 220, 200),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Anchored = true,
	})
end

-- =============================================================================
-- ATMOSPHERIC FOG particles inside chambers
-- =============================================================================
local atmosphere = make("Folder", "Atmosphere", chapter, {})
for _, pos in { Vector3.new(0, 3, 15), Vector3.new(0, 3, 45), Vector3.new(0, 4, 80) } do
	local attach = make("Part", "FogSource", atmosphere, {
		Size = Vector3.new(0.1, 0.1, 0.1),
		Position = pos,
		Anchored = true,
		CanCollide = false,
		Transparency = 1,
	})
	make("ParticleEmitter", "Fog", attach, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Lifetime = NumberRange.new(8, 14),
		Rate = 5,
		Speed = NumberRange.new(0.5, 1.5),
		Size = NumberSequence.new(8, 15),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.85),
			NumberSequenceKeypoint.new(0.7, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(Color3.fromRGB(120, 130, 140)),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-10, 10),
		LightEmission = 0.1,
	})
end

-- =============================================================================
-- LIGHTING (torches throughout)
-- =============================================================================
local lightingFolder = make("Folder", "Lighting", chapter, {})
local torchPositions = {
	Vector3.new(-5, 3, -15), Vector3.new(5, 3, -15), -- Entrance
	Vector3.new(-10, 3, 8), Vector3.new(10, 3, 8),   -- Hall corners
	Vector3.new(-10, 3, 22), Vector3.new(10, 3, 22), -- Hall back
	Vector3.new(-7, 3, 45), Vector3.new(7, 3, 45),   -- Burial
}
for _, pos in torchPositions do
	torch(lightingFolder, pos)
end

print("[MapBuilder] Map built: 7 zones, 14 puzzle items, 8 torches, 2 notes, 30 trees, 12 bones")
