# Chapter 1 Map Building Guide — Roblox Studio

## Folder Structure in Workspace

```
Workspace/
└── Chapter1/                    (Folder)
    ├── PlayerSpawn              (SpawnLocation, hidden)
    ├── Environment/             (Folder)
    │   ├── Forest/              (trees, snow, runic stones)
    │   ├── Entrance/            (mound entrance, door frame)
    │   ├── TutorialCorridor/    (narrow stone corridor)
    │   ├── HallOfRunes/         (large room, runic pillars)
    │   ├── Corridor2/           (narrower corridor)
    │   ├── BurialChamber/       (medium room, altar)
    │   ├── Corridor3/           (narrowest, lowest)
    │   └── DraugrChamber/       (large hall, sarcophagus)
    │
    ├── Triggers/                (Folder — invisible trigger zones)
    │   ├── Zone_Entrance        (Part, CanCollide=false, Transparency=1)
    │   ├── Zone_TutorialCorridor
    │   ├── Zone_HallOfRunes
    │   ├── Zone_Corridor2
    │   ├── Zone_BurialChamber
    │   ├── Zone_Corridor3
    │   ├── Zone_DraugrChamber
    │   └── Escape_Exit          (trigger at mound exit)
    │
    ├── Puzzles/                 (Folder)
    │   ├── Rune_A               (Part + ProximityPrompt, Attr: PuzzleId="runes")
    │   ├── Rune_B, Rune_C, Rune_D  (same)
    │   ├── Sword                (Part, Attr: PuzzleId="altar", PuzzleAction="Sword")
    │   ├── Goblet               (Part, Attr: PuzzleId="altar", PuzzleAction="Goblet")
    │   ├── Amulet               (Part, Attr: PuzzleId="altar", PuzzleAction="Amulet")
    │   ├── Slot_Left/Center/Right  (Part, Attr: PuzzleId="altar")
    │   ├── Brazier_1, Brazier_2    (Part, Attr: PuzzleId="ritual")
    │   ├── Sarcophagus_Slot     (Part, Attr: PuzzleId="ritual")
    │   └── Runestone            (Part, Attr: PuzzleId="ritual")
    │
    ├── Notes/                   (Folder)
    │   ├── Note_1               (Part + ClickDetector, in HallOfRunes side room)
    │   └── Note_2               (Part + ClickDetector, in BurialChamber side room)
    │
    ├── Scares/                  (Folder)
    │   ├── Scare1_DraugrSpawn   (Part, Transparency=1, far end of Corridor2)
    │   └── Scare2_DraugrSpawn   (Part, Transparency=1, end of Corridor3)
    │
    ├── Checkpoints/             (Folder)
    │   ├── Checkpoint_1         (Part, Transparency=1, after HallOfRunes)
    │   └── Checkpoint_2         (Part, Transparency=1, after BurialChamber)
    │
    ├── Sarcophagus              (Model — stone coffin in DraugrChamber)
    ├── Draugr                   (Model — all parts Transparency=1 initially)
    │
    └── Lighting/                (Folder)
        ├── Torch_1 ... Torch_N  (Parts with PointLight + Fire)
        └── DraugrGlow           (PointLight, blue-green, Brightness=0.3)
```

## How to Set Up Parts

### Trigger Zones
1. Insert > Part > resize to cover the zone area
2. Properties: CanCollide=false, Transparency=1, Anchored=true
3. Name: exactly as listed (Zone_Entrance, etc.)

### Puzzle Parts
1. Create Part (or MeshPart)
2. Add child ProximityPrompt: ActionText="Interact", HoldDuration=0.5
3. In Properties panel, add Attributes:
   - PuzzleId (string): "runes", "altar", or "ritual"
   - PuzzleAction (string): optional item name
4. Name: exactly as listed

### Torches
1. Part (cylinder) for torch body
2. Add PointLight: Brightness=0.5, Range=20, Color=warm orange
3. Add Fire particle: Size=3, Heat=10

### Draugr Model
1. Simple humanoid model
2. All BaseParts: Transparency=1
3. Optional: ParticleEmitter for ghostly effect (Rate=0)

## Testing Checklist
- [ ] Walk through all zones — each triggers in Output
- [ ] Click all rune parts — PuzzleInteract fires
- [ ] Click notes — ShowNote fires
- [ ] Fog and lighting feel dark
- [ ] Can walk from entrance to draugr chamber without getting stuck
