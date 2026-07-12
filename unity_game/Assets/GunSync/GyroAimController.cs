// GunSync FPS — GyroAimController
// Overrides the FPS camera look with phone gyroscope pitch/yaw data.
// Smoothly interpolates for low-latency feel.
//
// SETUP: Attach to the same GameObject as the FPS CameraRoot or
//        the Cinemachine Virtual Camera that controls first-person look.
//        If using Unity Starter Assets, disable the "Look" input in
//        StarterAssetsInputs while GunSync is active.

using UnityEngine;
using Cinemachine;

namespace GunSync
{
    public class GyroAimController : MonoBehaviour
    {
        [Header("References")]
        [Tooltip("Assign the Cinemachine Virtual Camera used for first-person look")]
        public CinemachineVirtualCamera virtualCamera;

        [Tooltip("Assign the PlayerCameraRoot transform from Starter Assets player")]
        public Transform cameraRoot;

        [Header("Sensitivity")]
        [Range(0.5f, 5f)]
        public float pitchSensitivity = 1.5f;

        [Range(0.5f, 5f)]
        public float yawSensitivity = 1.5f;

        [Header("Clamping")]
        [Range(20f, 90f)]
        public float maxPitchUp = 85f;

        [Range(20f, 90f)]
        public float maxPitchDown = 85f;

        [Header("Smoothing")]
        [Range(5f, 30f)]
        [Tooltip("Higher = snappier, lower = smoother")]
        public float lerpSpeed = 20f;

        // ── Current target angles
        private float _targetPitch = 0f;
        private float _targetYaw = 0f;

        // ── Current smoothed angles
        private float _currentPitch = 0f;
        private float _currentYaw = 0f;

        // ── Whether to use gyro or fall back to mouse
        private bool _gyroActive = false;

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
            _gyroActive = connected;
            if (!connected)
            {
                Debug.Log("[GyroAim] Gyro inactive — falling back to mouse");
            }
        }

        private void HandleInput(PhoneInputData data)
        {
            // Invert pitch direction: phone pitch up = aim up = negative Unity pitch
            _targetPitch = -data.pitch * pitchSensitivity;
            _targetYaw = data.yaw * yawSensitivity;

            // Clamp pitch to prevent looking too far up/down
            _targetPitch = Mathf.Clamp(_targetPitch, -maxPitchDown, maxPitchUp);
        }

        private void LateUpdate()
        {
            if (!_gyroActive) return;

            // Smooth interpolation for feel
            float dt = Time.deltaTime * lerpSpeed;
            _currentPitch = Mathf.Lerp(_currentPitch, _targetPitch, dt);
            _currentYaw = Mathf.Lerp(_currentYaw, _targetYaw, dt);

            // Apply to camera root (Starter Assets pattern)
            if (cameraRoot != null)
            {
                cameraRoot.localRotation = Quaternion.Euler(_currentPitch, 0f, 0f);
            }

            // Apply yaw to player body (horizontal rotation)
            transform.rotation = Quaternion.Euler(0f, _currentYaw, 0f);
        }

        /// <summary>Reset accumulated angles (e.g., after level load).</summary>
        public void ResetAngles()
        {
            _targetPitch = 0f;
            _targetYaw = 0f;
            _currentPitch = 0f;
            _currentYaw = 0f;
        }
    }
}
