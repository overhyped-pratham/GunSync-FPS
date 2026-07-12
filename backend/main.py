"""
GunSync FPS — FastAPI WebSocket Relay Server
Main application: routes phone input to Unity, recoil events back to phone.
"""

import asyncio
import json
import logging
from typing import Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from models import InputPacket, RecoilEvent, HitEvent, StatusEvent, AmmoEvent

# ─────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("gunsync")


# ─────────────────────────────────────────────
# Connection Manager
# ─────────────────────────────────────────────
class GunSyncManager:
    """
    Manages exactly two WebSocket roles:
      - "phone"  : the Flutter controller app
      - "game"   : the Unity FPS client (localhost)
    Messages flow:  phone → server → game
                    game  → server → phone
    """

    def __init__(self):
        self.phone: Optional[WebSocket] = None
        self.game: Optional[WebSocket] = None
        self._lock = asyncio.Lock()

    async def connect_phone(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self.phone = ws
        logger.info("📱 Phone controller connected")
        await self._broadcast_status()

    async def connect_game(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self.game = ws
        logger.info("🎮 Unity game connected")
        await self._broadcast_status()

    async def disconnect_phone(self):
        async with self._lock:
            self.phone = None
        logger.info("📱 Phone controller disconnected")
        await self._broadcast_status()

    async def disconnect_game(self):
        async with self._lock:
            self.game = None
        logger.info("🎮 Unity game disconnected")
        await self._broadcast_status()

    async def relay_to_game(self, data: str):
        """Forward raw JSON string from phone → Unity."""
        if self.game:
            try:
                await self.game.send_text(data)
            except Exception as e:
                logger.warning(f"relay_to_game failed: {e}")
                await self.disconnect_game()

    async def relay_to_phone(self, data: str):
        """Forward raw JSON string from Unity → Phone."""
        if self.phone:
            try:
                await self.phone.send_text(data)
            except Exception as e:
                logger.warning(f"relay_to_phone failed: {e}")
                await self.disconnect_phone()

    async def _broadcast_status(self):
        status = StatusEvent(
            message="Connection updated",
            phoneConnected=self.phone is not None,
            gameConnected=self.game is not None,
        )
        payload = status.model_dump_json(by_alias=True)
        for ws in [self.phone, self.game]:
            if ws:
                try:
                    await ws.send_text(payload)
                except Exception:
                    pass

    @property
    def is_ready(self) -> bool:
        return self.phone is not None and self.game is not None


manager = GunSyncManager()


# ─────────────────────────────────────────────
# App Lifecycle
# ─────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 GunSync Server starting...")
    yield
    logger.info("🛑 GunSync Server shutting down")


app = FastAPI(
    title="GunSync FPS Server",
    description="WebSocket relay between Flutter phone controller and Unity FPS game",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


import os
from fastapi.responses import HTMLResponse

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


# ─────────────────────────────────────────────
# REST Endpoints
# ─────────────────────────────────────────────
@app.get("/", response_class=HTMLResponse)
async def root():
    """Serves the phone controller mobile web app."""
    path = os.path.join(BASE_DIR, "templates", "phone.html")
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


@app.get("/game", response_class=HTMLResponse)
async def get_game():
    """Serves the Three.js WebGL 3D FPS game."""
    path = os.path.join(BASE_DIR, "templates", "game.html")
    with open(path, "r", encoding="utf-8") as f:
        return f.read()



@app.get("/status")
async def status():
    return {
        "phone": "connected" if manager.phone else "disconnected",
        "game": "connected" if manager.game else "disconnected",
        "ready": manager.is_ready,
    }


@app.get("/health")
async def health():
    return {"ok": True}


# ─────────────────────────────────────────────
# WebSocket: Phone Controller
# ─────────────────────────────────────────────
@app.websocket("/ws/phone")
async def phone_endpoint(websocket: WebSocket):
    """
    Flutter app connects here.
    Receives: JSON input packets (pitch, yaw, fire, joystick, etc.)
    Sends:    Recoil events, hit events, ammo events from Unity
    """
    await manager.connect_phone(websocket)
    try:
        while True:
            raw = await websocket.receive_text()

            # Validate & log (optional - comment out for pure performance)
            try:
                data = json.loads(raw)
                pkt_type = data.get("type", "input")
                if pkt_type == "input":
                    logger.debug(f"📥 Input: fire={data.get('fire')} pitch={data.get('pitch', 0):.1f}")
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON from phone: {raw[:100]}")
                continue

            # Relay to Unity game
            await manager.relay_to_game(raw)

    except WebSocketDisconnect:
        await manager.disconnect_phone()
    except Exception as e:
        logger.error(f"Phone WS error: {e}")
        await manager.disconnect_phone()


# ─────────────────────────────────────────────
# WebSocket: Unity Game
# ─────────────────────────────────────────────
@app.websocket("/ws/game")
async def game_endpoint(websocket: WebSocket):
    """
    Unity game client connects here (localhost).
    Receives: Input packets relayed from phone
    Sends:    Recoil events, hit confirmations, ammo updates → phone
    """
    await manager.connect_game(websocket)
    try:
        while True:
            raw = await websocket.receive_text()

            # Log events from Unity
            try:
                data = json.loads(raw)
                evt_type = data.get("type", "?")
                logger.info(f"🎮 Unity event: {evt_type} → {data}")
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON from game: {raw[:100]}")
                continue

            # Relay recoil/hit/ammo events back to phone
            await manager.relay_to_phone(raw)

    except WebSocketDisconnect:
        await manager.disconnect_game()
    except Exception as e:
        logger.error(f"Game WS error: {e}")
        await manager.disconnect_game()
