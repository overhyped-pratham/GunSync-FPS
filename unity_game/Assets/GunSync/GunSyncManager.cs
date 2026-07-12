// GunSync FPS — GunSyncManager
// Central WebSocket client for Unity. Connects to FastAPI /ws/game endpoint,
// receives phone input, dispatches events to subsystems.
//
// SETUP: Attach this script to an empty "GunSyncManager" GameObject in scene root.
//        Set serverUrl in Inspector: ws://127.0.0.1:8765/ws/game

using System;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using NativeWebSocket;

namespace GunSync
{
    public class GunSyncManager : MonoBehaviour
    {
        [Header("Connection")]
        [Tooltip("FastAPI server WebSocket URL for game endpoint")]
        public string serverUrl = "ws://127.0.0.1:8765/ws/game";

        [Tooltip("Auto-reconnect if connection drops")]
        public bool autoReconnect = true;

        [Tooltip("Seconds between reconnect attempts")]
        public float reconnectDelay = 3f;

        // ── Singleton
        public static GunSyncManager Instance { get; private set; }

        // ── Events — subscribe in other scripts
        public static event Action<PhoneInputData> OnInputReceived;
        public static event Action<bool> OnConnectionChanged;  // true = connected

        // ── Current state (thread-safe read)
        public static PhoneInputData CurrentInput { get; private set; } = new PhoneInputData();
        public static bool IsConnected { get; private set; } = false;

        // ── Score tracking
        private int _score = 0;
        public static int Score => Instance?._score ?? 0;

        private WebSocket _ws;
        private bool _isConnecting = false;
        private bool _applicationQuitting = false;

        // ── Outgoing message queue (thread-safe)
        private readonly Queue<string> _sendQueue = new Queue<string>();

        // ─────────────────────────────────────────────
        // Unity Lifecycle
        // ─────────────────────────────────────────────

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private IEnumerator Start()
        {
            yield return new WaitForSeconds(0.5f);
            yield return ConnectCoroutine();
        }

        private void Update()
        {
#if !UNITY_WEBGL || UNITY_EDITOR
            _ws?.DispatchMessageQueue();
#endif
            // Drain send queue on main thread
            while (_sendQueue.Count > 0)
            {
                var msg = _sendQueue.Dequeue();
                SendRaw(msg);
            }
        }

        private void OnApplicationQuit()
        {
            _applicationQuitting = true;
            _ws?.Close();
        }

        // ─────────────────────────────────────────────
        // Connection
        // ─────────────────────────────────────────────

        private IEnumerator ConnectCoroutine()
        {
            while (!_applicationQuitting)
            {
                if (!IsConnected && !_isConnecting)
                {
                    yield return StartCoroutine(DoConnect());
                }
                yield return new WaitForSeconds(reconnectDelay);
            }
        }

        private IEnumerator DoConnect()
        {
            _isConnecting = true;
            Debug.Log($"[GunSync] Connecting to {serverUrl}...");

            _ws = new WebSocket(serverUrl);

            _ws.OnOpen += () =>
            {
                IsConnected = true;
                _isConnecting = false;
                Debug.Log("[GunSync] ✅ Connected to FastAPI server");
                OnConnectionChanged?.Invoke(true);
            };

            _ws.OnMessage += (bytes) =>
            {
                var raw = Encoding.UTF8.GetString(bytes);
                HandleMessage(raw);
            };

            _ws.OnError += (err) =>
            {
                Debug.LogWarning($"[GunSync] WS Error: {err}");
            };

            _ws.OnClose += (code) =>
            {
                IsConnected = false;
                _isConnecting = false;
                Debug.Log($"[GunSync] Disconnected (code={code})");
                OnConnectionChanged?.Invoke(false);
            };

            yield return _ws.Connect();
        }

        // ─────────────────────────────────────────────
        // Message Handling
        // ─────────────────────────────────────────────

        private void HandleMessage(string raw)
        {
            try
            {
                // Quick type check before full parse
                if (raw.Contains("\"type\":\"status\""))
                {
                    // Server status update — log only
                    Debug.Log($"[GunSync] Status: {raw}");
                    return;
                }

                if (raw.Contains("\"type\":\"ping\""))
                {
                    EnqueueSend("{\"type\":\"pong\"}");
                    return;
                }

                // Parse as input packet
                var input = JsonUtility.FromJson<PhoneInputData>(raw);
                if (input != null && input.type == "input")
                {
                    CurrentInput = input;
                    OnInputReceived?.Invoke(input);
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning($"[GunSync] Parse error: {e.Message} | raw={raw.Substring(0, Mathf.Min(100, raw.Length))}");
            }
        }

        // ─────────────────────────────────────────────
        // Sending Events to Phone
        // ─────────────────────────────────────────────

        public void SendRecoil(string gun, string pattern, int duration, float intensity)
        {
            var evt = new RecoilEvent
            {
                gun = gun,
                pattern = pattern,
                duration = duration,
                intensity = intensity,
            };
            EnqueueSend(JsonUtility.ToJson(evt));
        }

        public void SendHit(string enemyId, bool isKill)
        {
            if (isKill) _score += 100;
            var evt = new HitEvent
            {
                enemyId = enemyId,
                isKill = isKill,
                score = _score,
            };
            EnqueueSend(JsonUtility.ToJson(evt));
        }

        public void SendAmmoUpdate(string weapon, int current, int max, bool reloading)
        {
            var evt = new AmmoEvent
            {
                weapon = weapon,
                ammoCurrent = current,
                ammoMax = max,
                isReloading = reloading,
            };
            EnqueueSend(JsonUtility.ToJson(evt));
        }

        private void EnqueueSend(string json)
        {
            _sendQueue.Enqueue(json);
        }

        private async void SendRaw(string json)
        {
            if (_ws != null && IsConnected)
            {
                try
                {
                    await _ws.SendText(json);
                }
                catch (Exception e)
                {
                    Debug.LogWarning($"[GunSync] Send failed: {e.Message}");
                }
            }
        }
    }
}
