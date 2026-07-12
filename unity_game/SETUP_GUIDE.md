# GunSync FPS — Unity Scene Setup Guide

## Step-by-Step Scene Configuration

### 1. Create Project in Unity Hub
- Open Unity Hub → **New Project**
- Template: **Universal 3D** (URP)
- Name: `GunSyncFPS`
- Click **Create Project**

---

### 2. Install Packages

Copy the `Packages/manifest.json` from this repo into your Unity project's `Packages/` folder.
Unity will auto-install all packages on next editor focus, including:

| Package | Purpose |
|---------|---------|
| NativeWebSocket 1.1.4 | WebSocket client (from OpenUPM) |
| Input System 1.8.2 | New input system |
| Cinemachine 2.10.0 | FPS camera rig |
| AI Navigation 2.0.4 | NavMesh for enemy AI |
| TextMeshPro 3.0.9 | HUD text rendering |

---

### 3. Import Free FPS Map from GitHub

**Option A — FPS Microgame level assets (GitHub):**
```
https://github.com/UnityTechnologies/FPSSample
```
- Download ZIP → extract → copy the `/Assets/Levels/` folder into your project

**Option B — Mini First Person Package:**
```
https://github.com/Brackeys/First-Person-Movement
```

**Option C (Easiest) — Unity Asset Store:**
- Search: "Starter Assets - First Person Character Controller" (FREE, official)
- Includes a sample room/level already

---

### 4. Import GunSync Scripts

Copy the entire `unity_game/Assets/GunSync/` folder into your Unity project:
```
[Your Unity Project]/Assets/GunSync/
```

---

### 5. Scene Hierarchy Setup

```
📁 Scene
├── 🎮 GunSyncManager          ← Empty GameObject
│   └── GunSyncManager.cs      (set serverUrl = ws://127.0.0.1:8765/ws/game)
│
├── 👤 Player (from Starter Assets PlayerCapsule prefab)
│   ├── CharacterController
│   ├── MovementBridge.cs      (assign StarterAssetsInputs)
│   ├── WeaponSystem.cs
│   ├── GunController.cs
│   └── GyroAimController.cs
│       └── 📷 PlayerCameraRoot
│           └── 📷 CinemachineVirtualCamera
│
├── 💡 Lighting
├── 🗺️ Level Geometry
│
├── 🤖 Enemy_01                ← Enemy prefab (duplicate for more enemies)
│   ├── NavMeshAgent
│   ├── EnemyAI.cs
│   ├── Animator
│   └── Collider (tag: "Enemy")
│
└── 🖼️ HUD Canvas (Screen Space - Overlay)
    └── GameHUD.cs
        ├── TMP_Text: WeaponName
        ├── TMP_Text: AmmoCurrent
        ├── TMP_Text: AmmoMax
        ├── TMP_Text: Score
        ├── Image: ConnectionDot
        └── GameObject: ReloadingOverlay
```

---

### 6. Player Setup Details

On the **Player** GameObject:

**GyroAimController:**
- `Virtual Camera` → drag your Cinemachine FPC camera
- `Camera Root` → drag PlayerCameraRoot child transform
- `Pitch Sensitivity` = 1.5
- `Yaw Sensitivity` = 1.5
- `Lerp Speed` = 20

**GunController:**
- `Fps Cam` → drag main Camera
- `Weapon System` → drag WeaponSystem component (same GameObject)
- `Muzzle Flash` → assign a Particle System
- `Shootable Layers` → set to Everything (or specific layers)

**GunSyncManager (separate GameObject):**
- `Server Url` = `ws://127.0.0.1:8765/ws/game`
- `Auto Reconnect` = ✅ checked

---

### 7. Enemy Setup

For each enemy:
1. Create a Capsule or import a character model
2. Tag it: `Enemy`
3. Add `NavMeshAgent` component
4. Add `EnemyAI.cs`
5. Set `Patrol Points` array (create empty GameObjects as waypoints)
6. Assign `Player Transform` (or leave empty — it auto-finds by tag)

---

### 8. Bake NavMesh

`Window → AI → Navigation → Bake`
- Make sure floor/ground has `Navigation Static` checked
- Adjust Agent Radius to match enemy size (~0.4)

---

### 9. HUD Canvas Setup

Create a Canvas (Screen Space - Overlay):
```
Canvas
└── Panel (full screen, alpha 0)
    ├── ConnectionDot (Image, top-left, 12x12)
    ├── ConnectionText (TMP, "● CONNECTED")
    ├── WeaponName (TMP, bottom-center)
    ├── AmmoCurrent (TMP, large font, bottom-right)
    ├── AmmoMax (TMP, small, next to AmmoCurrent)
    ├── Score (TMP, top-right)
    ├── KillFeed (TMP, mid-right, initially hidden)
    └── ReloadingOverlay (Image, initially hidden)
```

Attach `GameHUD.cs` to the Canvas and wire up all references.

---

### 10. Test Run

1. Press **Play** in Unity
2. Console should show: `[GunSync] Connecting to ws://127.0.0.1:8765/ws/game...`
3. If server is running: `[GunSync] ✅ Connected to FastAPI server`
4. Open phone app → connect → tilt phone → Unity camera should move!

---

## Troubleshooting Unity

| Issue | Fix |
|-------|-----|
| `NativeWebSocket not found` | Add OpenUPM registry in Project Settings → Package Manager |
| `StarterAssets namespace missing` | Import Starter Assets package first |
| `NavMesh not found` | Install `com.unity.ai.navigation` package |
| Camera doesn't move with phone | Check `GyroAimController` is on the Player, not the camera |
| Movement doesn't work | Ensure `StarterAssetsInputs` component is on same Player GO as `MovementBridge` |
