# GunSync FPS — Backend Server

FastAPI WebSocket relay between the Flutter phone controller and Unity game.

## Endpoints

| Endpoint | Role |
|----------|------|
| `GET /` | Server info + connection status |
| `GET /status` | JSON: phone/game connected? |
| `GET /health` | Health check |
| `WS /ws/phone` | Flutter app connects here |
| `WS /ws/game` | Unity game connects here |

## Message Flow

```
Phone → /ws/phone → Server → /ws/game → Unity
Unity → /ws/game  → Server → /ws/phone → Phone
```

## Running

```powershell
pip install -r requirements.txt
$env:NGROK_AUTHTOKEN = "your_token"
python run.py
```
