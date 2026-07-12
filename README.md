# 🔫 GunSync FPS

> **Turn your Android phone into a wireless FPS gun controller.**
> Gyroscope aiming · Haptic recoil · Virtual joystick · WebSocket relay over internet

---

## System Overview

```
Android App (Flutter)
    ↓  WSS (ngrok tunnel — internet)
FastAPI Relay Server (Python)
    ↓  WS (localhost)
Unity 6 FPS Game
```

---

## Quick Start

### Step 1 — Install Python backend dependencies

```powershell
cd backend
pip install -r requirements.txt
```

### Step 2 — Get a free ngrok auth token

1. Sign up at https://dashboard.ngrok.com/signup (free)
2. Copy your authtoken from the dashboard
3. Set it as an environment variable:

```powershell
$env:NGROK_AUTHTOKEN = "your_token_here"
```

### Step 3 — Launch the server

```powershell
cd backend
python run.py
```

You'll see a **QR code** printed in the terminal — this is the WSS URL for your phone.

```
════════════════════════════════════════════════════════════
  📱 Scan with GunSync App (Phone WS endpoint):
  ws://x.tcp.ngrok.io:12345/ws/phone
════════════════════════════════════════════════════════════
  [QR code here]

  🎮 Unity connects to:  ws://127.0.0.1:8765/ws/game
════════════════════════════════════════════════════════════
```

### Step 4 — Set up Unity

1. Open **Unity Hub** → New Project → **Universal 3D** template
2. Import the [Unity Starter Assets — First Person](https://assetstore.unity.com/packages/essentials/starter-assets-first-person-character-controller-196525) (free)
3. Import a free FPS map — recommended options:
   - **[FPS Microgame](https://github.com/UnityTechnologies/FPSSample)** (GitHub)
   - **[SampleScene from Starter Assets](https://assetstore.unity.com/packages/essentials/starter-assets-first-person-character-controller-196525)**
4. Install **NativeWebSocket** via OpenUPM:
   - In Unity: `Edit → Project Settings → Package Manager`
   - Add scoped registry: `https://package.openupm.com`
   - Then: `Window → Package Manager → + → Add by name: com.endel.nativewebsocket`
5. Copy the `unity_game/Assets/GunSync/` folder into your Unity project's `Assets/` folder
6. **Scene setup:**
   - Add empty GameObject → name it `GunSyncManager` → attach `GunSyncManager.cs`
   - Attach `GyroAimController.cs` to the Player → assign CameraRoot and VirtualCamera
   - Attach `MovementBridge.cs` to the Player → assign StarterAssetsInputs
   - Attach `WeaponSystem.cs` and `GunController.cs` to the Player
   - Bake NavMesh: `Window → AI → Navigation → Bake`
   - Tag enemies with the `Enemy` tag, attach `EnemyAI.cs`
7. Hit **Play** in Unity — it will auto-connect to `ws://127.0.0.1:8765/ws/game`

### Step 5 — Install the Android app

```powershell
cd mobile_app
flutter pub get
flutter run --release
```

Or build an APK:

```powershell
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

### Step 6 — Play!

1. Open GunSync app on your phone
2. Tap **Scan QR** → scan the QR from the terminal
3. Tap **CONNECT**
4. Hold phone like a gun — **point to aim, tap FIRE**
5. **Shake down** to reload
6. **Swipe** left/right to switch weapons

---

## Controls Reference

| Action | Control |
|--------|---------|
| Aim | Phone gyroscope (point and tilt) |
| Move | Left virtual joystick |
| Fire | FIRE button (right side) |
| Reload | Shake phone downward sharply |
| Weapon Switch | Swipe left/right on screen |
| Calibrate Aim | Tap ⊕ CALIBRATE button |

## Haptic Recoil Patterns

| Weapon | Pattern |
|--------|---------|
| 🔫 Pistol | Short tap 120ms |
| ⚡ SMG | Rapid burst ×3 |
| 💥 Shotgun | Heavy thump 200ms |
| 🎯 Sniper | Strong long kick 300ms |

---

## Architecture

```
mobile_app/
  lib/
    main.dart                    ← App entry, Provider setup
    models/
      input_packet.dart          ← Phone→Server JSON model
      recoil_event.dart          ← Server→Phone JSON models
    services/
      websocket_service.dart     ← WS connection, stream routing
      sensor_service.dart        ← Gyro integration, reload gesture
      haptic_service.dart        ← Weapon-specific vibration patterns
    screens/
      connect_screen.dart        ← URL entry + QR scanner
      controller_screen.dart     ← Full controller UI (landscape)

backend/
  main.py                        ← FastAPI WS relay (/ws/phone, /ws/game)
  models.py                      ← Pydantic validation models
  run.py                         ← ngrok tunnel + QR launcher
  requirements.txt

unity_game/Assets/GunSync/
  GunSyncManager.cs              ← WS client, singleton, event dispatcher
  PhoneInputData.cs              ← Deserialize phone JSON
  RecoilEvent.cs                 ← Serialize outgoing events
  GyroAimController.cs           ← Camera look from gyro pitch/yaw
  MovementBridge.cs              ← Joystick → CharacterController
  WeaponSystem.cs                ← 4 weapons, ammo, reload, switch
  GunController.cs               ← Raycast fire, recoil anim, effects
  EnemyAI.cs                     ← NavMesh Patrol→Chase→Attack→Dead
  GameHUD.cs                     ← Unity HUD: ammo, score, status
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Phone can't connect | Check ngrok is running, token is valid |
| Gyro drifts | Tap CALIBRATE button, hold phone still first |
| High latency | Use 5GHz WiFi, or use local WS if on same network |
| Unity not receiving | Check `ws://127.0.0.1:8765/ws/game` in GunSyncManager |
| No vibration | Check phone isn't in silent mode; some Android skins restrict vibration |
| ngrok tunnel expired | Free ngrok tunnels expire — re-run `python run.py` |

---

## Future Enhancements

- 🤖 **Voice commands** — "Reload!", "Switch" via Whisper
- 📷 **Gun recognition** — Camera recognizes physical toy gun
- 🌍 **Multiplayer** — Multiple phones, multiple players
- 🎯 **AR Mode** — Camera overlay with enemies in real world

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Mobile App | Flutter 3.x (Android) |
| Sensors | sensors_plus |
| Networking | web_socket_channel |
| Haptics | vibration |
| Backend | FastAPI + uvicorn |
| Tunnel | pyngrok (ngrok) |
| Game Engine | Unity 6 (URP) |
| WS in Unity | NativeWebSocket |
| FPS Controller | Unity Starter Assets |
| AI | Unity NavMesh |
