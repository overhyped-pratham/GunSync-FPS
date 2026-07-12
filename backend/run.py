# -*- coding: utf-8 -*-
import sys
if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
"""
GunSync FPS — Server Launcher
Starts the FastAPI server and opens an ngrok tunnel for remote phone access.
Prints a QR code in the terminal so the phone can scan the WSS URL.
"""

import os
import sys
import socket
import uvicorn
import threading
import qrcode
from pyngrok import ngrok, conf

# Load .env file if it exists (so NGROK_AUTHTOKEN is auto-set)
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    # dotenv not installed — fall back to env vars only
    pass

NGROK_AUTH_TOKEN = os.getenv("NGROK_AUTHTOKEN", "")

# ─────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────
LOCAL_HOST = "127.0.0.1"
LOCAL_PORT = 8765


def get_local_ip() -> str:
    """Get machine's local network IP."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def print_qr(url: str, label: str):
    """Print QR code to terminal."""
    print(f"\n{'-' * 60}")
    print(f"  {label}")
    print(f"  {url}")
    print(f"{'-' * 60}")
    qr = qrcode.QRCode(border=1)
    qr.add_data(url)
    qr.make(fit=True)
    qr.print_ascii(invert=True)
    print(f"{'-' * 60}\n")


def start_ngrok() -> str | None:
    """Start ngrok tunnel and return public WSS URL."""
    if NGROK_AUTH_TOKEN:
        conf.get_default().auth_token = NGROK_AUTH_TOKEN
    else:
        print("⚠️  No NGROK_AUTHTOKEN set. Using anonymous tunnel (limited).")
        print("   Get a free token at: https://dashboard.ngrok.com/signup")
        print("   Then: set NGROK_AUTHTOKEN=your_token\n")

    try:
        # Use http tunnel instead of tcp to bypass credit card verification requirement
        tunnel = ngrok.connect(LOCAL_PORT, "http")
        public_url = tunnel.public_url
        # Convert http/https to ws/wss
        ws_url = public_url.replace("https://", "wss://").replace("http://", "ws://")
        return ws_url
    except Exception as e:
        print(f"❌ ngrok failed: {e}")
        print("   Falling back to local WiFi only.")
        return None


def run_server():
    """Run uvicorn in a thread."""
    uvicorn.run(
        "main:app",
        host=LOCAL_HOST,
        port=LOCAL_PORT,
        log_level="info",
        ws_ping_interval=20,
        ws_ping_timeout=30,
    )


if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("  [GunSync FPS] WebSocket Relay Server")
    print("=" * 60 + "\n")

    local_ip = get_local_ip()

    # Start ngrok tunnel
    print("[*] Starting ngrok tunnel for remote play...")
    ngrok_ws_url = start_ngrok()

    # Print connection info
    local_ws = f"ws://{local_ip}:{LOCAL_PORT}"
    print_qr(
        url=ngrok_ws_url or local_ws,
        label="[PHONE] Scan QR or copy this URL into the GunSync app:",
    )

    print(f"  [UNITY]  Game endpoint  : ws://127.0.0.1:{LOCAL_PORT}/ws/game")
    print(f"  [PHONE]  Phone endpoint : {(ngrok_ws_url or local_ws)}/ws/phone")
    print(f"  [WEB]    Status page    : http://{local_ip}:{LOCAL_PORT}/status")
    print()

    # Start uvicorn server (blocking)
    run_server()
