// GunSync FPS — MovementBridge
// Feeds phone joystick X/Y into Unity's CharacterController.
// Compatible with Unity Starter Assets FirstPersonController.
//
// SETUP: Attach to the Player GameObject that has CharacterController.
//        The Starter Assets FirstPersonController will handle the actual
//        movement — this bridge feeds joystick values into StarterAssetsInputs.

using UnityEngine;
using StarterAssets;

namespace GunSync
{
    [RequireComponent(typeof(CharacterController))]
    public class MovementBridge : MonoBehaviour
    {
        [Header("References")]
        [Tooltip("The StarterAssetsInputs component on this player (auto-found if null)")]
        public StarterAssetsInputs starterInputs;

        [Header("Movement")]
        [Range(0.1f, 1f)]
        [Tooltip("Joystick deadzone — values below this are treated as 0")]
        public float deadzone = 0.08f;

        [Range(0f, 1f)]
        [Tooltip("Smoothing factor for joystick (0 = instant, 1 = very smooth)")]
        public float smoothing = 0.12f;

        private Vector2 _smoothedMove = Vector2.zero;
        private bool _bridgeActive = false;

        private void Awake()
        {
            if (starterInputs == null)
                starterInputs = GetComponent<StarterAssetsInputs>();
        }

        private void OnEnable()
        {
            GunSyncManager.OnInputReceived += HandleInput;
            GunSyncManager.OnConnectionChanged += HandleConnection;
        }

        private void OnDisable()
        {
            GunSyncManager.OnInputReceived -= HandleInput;
            GunSyncManager.OnConnectionChanged -= HandleConnection;
        }

        private void HandleConnection(bool connected)
        {
            _bridgeActive = connected;
            if (!connected && starterInputs != null)
            {
                // Zero out movement when disconnected
                starterInputs.MoveInput(Vector2.zero);
            }
        }

        private void HandleInput(PhoneInputData data)
        {
            if (!_bridgeActive) return;

            var raw = new Vector2(data.joystickX, data.joystickY);

            // Apply deadzone
            if (raw.magnitude < deadzone)
                raw = Vector2.zero;

            // Smooth
            _smoothedMove = Vector2.Lerp(_smoothedMove, raw, 1f - smoothing);
        }

        private void Update()
        {
            if (!_bridgeActive) return;

            if (starterInputs != null)
            {
                // Feed smoothed joystick into StarterAssets input system
                starterInputs.MoveInput(_smoothedMove);
            }
        }
    }
}
