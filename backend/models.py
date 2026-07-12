"""
GunSync FPS — FastAPI WebSocket Relay Server
Pydantic models for input/output packets.
"""

from pydantic import BaseModel, Field
from typing import Optional, Literal
from enum import Enum


class WeaponSwipe(int, Enum):
    NONE = 0
    PREVIOUS = -1
    NEXT = 1


class InputPacket(BaseModel):
    """Phone → Server → Unity: controller state at ~60 Hz."""
    type: Literal["input"] = "input"
    pitch: float = Field(0.0, description="Gyro pitch in degrees")
    yaw: float = Field(0.0, description="Gyro yaw in degrees")
    roll: float = Field(0.0, description="Gyro roll in degrees")
    fire: bool = Field(False, description="Fire button pressed")
    reload: bool = Field(False, description="Reload gesture detected")
    joystick_x: float = Field(0.0, alias="joystickX", description="Joystick X axis [-1,1]")
    joystick_y: float = Field(0.0, alias="joystickY", description="Joystick Y axis [-1,1]")
    weapon_swipe: int = Field(0, alias="weaponSwipe", description="-1=prev, 0=none, 1=next")
    timestamp: int = Field(0, description="Client timestamp in milliseconds")

    class Config:
        populate_by_name = True


class RecoilEvent(BaseModel):
    """Unity → Server → Phone: recoil haptic feedback command."""
    type: Literal["recoil"] = "recoil"
    gun: str = Field(..., description="Gun type: pistol|smg|shotgun|sniper")
    pattern: str = Field(..., description="Haptic pattern: short|rapid|heavy|strong")
    duration: int = Field(120, description="Total vibration duration in ms")
    intensity: float = Field(0.7, description="Vibration amplitude [0.0, 1.0]")


class HitEvent(BaseModel):
    """Unity → Server → Phone: enemy hit confirmation."""
    type: Literal["hit"] = "hit"
    enemy_id: str = Field("", alias="enemyId")
    is_kill: bool = Field(False, alias="isKill")
    score: int = Field(0)

    class Config:
        populate_by_name = True


class StatusEvent(BaseModel):
    """Server → Client: connection/game status updates."""
    type: Literal["status"] = "status"
    message: str
    phone_connected: bool = Field(False, alias="phoneConnected")
    game_connected: bool = Field(False, alias="gameConnected")

    class Config:
        populate_by_name = True


class AmmoEvent(BaseModel):
    """Unity → Server → Phone: ammo/weapon state sync."""
    type: Literal["ammo"] = "ammo"
    weapon: str
    ammo_current: int = Field(alias="ammoCurrent")
    ammo_max: int = Field(alias="ammoMax")
    is_reloading: bool = Field(False, alias="isReloading")

    class Config:
        populate_by_name = True
