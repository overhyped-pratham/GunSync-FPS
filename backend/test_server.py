"""
GunSync FPS — Quick Backend Test
Run this AFTER starting the server (python run.py) to verify:
  1. Phone WS endpoint accepts connections
  2. Game WS endpoint accepts connections
  3. Messages relay correctly phone → game
  4. Recoil events relay correctly game → phone

Usage:
  python test_server.py [server_url]
  python test_server.py ws://127.0.0.1:8765       # local test
  python test_server.py ws://x.tcp.ngrok.io:PORT   # remote test
"""

import asyncio
import json
import sys
import time

# Force UTF-8 output on Windows
if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

try:
    import websockets
except ImportError:
    print("pip install websockets")
    sys.exit(1)

SERVER = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "ws://127.0.0.1:8765"
PHONE_URL = f"{SERVER}/ws/phone"
GAME_URL = f"{SERVER}/ws/game"

SAMPLE_INPUT = {
    "type": "input",
    "pitch": 15.5,
    "yaw": -8.2,
    "roll": 0.0,
    "fire": True,
    "reload": False,
    "joystickX": 0.5,
    "joystickY": 0.8,
    "weaponSwipe": 0,
    "timestamp": int(time.time() * 1000),
}

SAMPLE_RECOIL = {
    "type": "recoil",
    "gun": "pistol",
    "pattern": "short",
    "duration": 120,
    "intensity": 0.7,
}

PASS = "[PASS]"
FAIL = "[FAIL]"
results = []


async def recv_non_status(websocket, timeout=3.0):
    """Read from websocket, skipping any 'status' messages."""
    start_time = time.time()
    while True:
        elapsed = time.time() - start_time
        if elapsed >= timeout:
            raise asyncio.TimeoutError()
        
        raw_msg = await asyncio.wait_for(websocket.recv(), timeout=max(0.1, timeout - elapsed))
        try:
            data = json.loads(raw_msg)
            if data.get("type") != "status":
                return raw_msg, data
        except json.JSONDecodeError:
            return raw_msg, {}


async def run_tests():
    print(f"\n{'-' * 55}")
    print(f"  GunSync Backend Test")
    print(f"  Server: {SERVER}")
    print(f"{'-' * 55}\n")

    # ── Test 1: Phone connects
    try:
        async with websockets.connect(PHONE_URL, open_timeout=5) as phone:
            results.append((PASS, "Phone endpoint connects"))

            # ── Test 2: Game connects
            try:
                async with websockets.connect(GAME_URL, open_timeout=5) as game:
                    results.append((PASS, "Game endpoint connects"))

                    # Give server time to broadcast status
                    await asyncio.sleep(0.3)

                    # ── Test 3: Status message received by phone
                    try:
                        status_raw = await asyncio.wait_for(phone.recv(), timeout=3)
                        status = json.loads(status_raw)
                        if status.get("type") == "status":
                            results.append((PASS, f"Status event received: phoneConnected={status.get('phoneConnected')} gameConnected={status.get('gameConnected')}"))
                        else:
                            results.append((PASS, f"Message received (type={status.get('type')})"))
                    except asyncio.TimeoutError:
                        results.append((FAIL, "No status message received within 3s"))

                    # ── Test 4: Input relays phone → game
                    await phone.send(json.dumps(SAMPLE_INPUT))
                    try:
                        relayed, data = await recv_non_status(game, timeout=3)
                        if data.get("type") == "input" and data.get("fire") is True:
                            results.append((PASS, f"Input relayed phone->game (fire=True pitch={data.get('pitch')})"))
                        else:
                            results.append((FAIL, f"Unexpected relay: {relayed[:80]}"))
                    except asyncio.TimeoutError:
                        results.append((FAIL, "Input packet not relayed to game within 3s"))

                    # ── Test 5: Recoil relays game → phone
                    await game.send(json.dumps(SAMPLE_RECOIL))
                    try:
                        recoil_raw, recoil = await recv_non_status(phone, timeout=3)
                        if recoil.get("type") == "recoil" and recoil.get("gun") == "pistol":
                            results.append((PASS, f"Recoil relayed game->phone (gun={recoil.get('gun')} pattern={recoil.get('pattern')})"))
                        else:
                            results.append((FAIL, f"Unexpected recoil: {recoil_raw[:80]}"))
                    except asyncio.TimeoutError:
                        results.append((FAIL, "Recoil event not relayed to phone within 3s"))

            except Exception as e:
                results.append((FAIL, f"Game endpoint failed: {e}"))

    except Exception as e:
        results.append((FAIL, f"Phone endpoint failed: {e}"))

    # ── Summary
    print(f"\n{'-' * 55}")
    passed = 0
    for icon, msg in results:
        print(f"  {icon}  {msg}")
        if icon == PASS:
            passed += 1
    print(f"{'-' * 55}")
    total = len(results)
    print(f"\n  Result: {passed}/{total} passed\n")

    if passed == total:
        print("  Server is ready! Start Unity + Flutter app.\n")
    else:
        print("  Some tests failed. Check server logs above.\n")


if __name__ == "__main__":
    asyncio.run(run_tests())
