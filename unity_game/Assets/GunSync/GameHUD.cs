// GunSync FPS — GameHUD
// Unity in-game UI controller for health, ammo, weapon, score, connection status.
//
// SETUP: Create a Canvas in the scene. Create UI elements and assign references.

using UnityEngine;
using UnityEngine.UI;
using TMPro;

namespace GunSync
{
    public class GameHUD : MonoBehaviour
    {
        [Header("Connection Status")]
        public Image connectionDot;
        public TextMeshProUGUI connectionText;
        public Color connectedColor = new Color(0f, 1f, 0.5f);
        public Color disconnectedColor = new Color(1f, 0.25f, 0.25f);

        [Header("Weapon & Ammo")]
        public TextMeshProUGUI weaponNameText;
        public TextMeshProUGUI ammoCurrentText;
        public TextMeshProUGUI ammoMaxText;
        public Image weaponIcon;
        public GameObject reloadingOverlay;

        [Header("Score")]
        public TextMeshProUGUI scoreText;
        public TextMeshProUGUI killFeedText;

        [Header("Crosshair")]
        public Image crosshairCenter;
        public RectTransform[] crosshairLines; // Top, Bottom, Left, Right

        [Header("References")]
        public WeaponSystem weaponSystem;

        private int _score = 0;
        private float _killFeedTimer = 0f;

        private void OnEnable()
        {
            GunSyncManager.OnConnectionChanged += UpdateConnectionUI;
            GunSyncManager.OnInputReceived += OnInput;
        }

        private void OnDisable()
        {
            GunSyncManager.OnConnectionChanged -= UpdateConnectionUI;
            GunSyncManager.OnInputReceived -= OnInput;
        }

        private void Start()
        {
            UpdateConnectionUI(GunSyncManager.IsConnected);
            UpdateWeaponUI();
        }

        private void Update()
        {
            // Auto-refresh weapon/ammo display every frame (simple approach)
            if (weaponSystem != null)
            {
                UpdateWeaponUI();
            }

            // Kill feed fade
            if (_killFeedTimer > 0f)
            {
                _killFeedTimer -= Time.deltaTime;
                if (_killFeedTimer <= 0f && killFeedText != null)
                    killFeedText.gameObject.SetActive(false);
            }
        }

        private void OnInput(PhoneInputData _) { }

        private void UpdateConnectionUI(bool connected)
        {
            if (connectionDot != null)
                connectionDot.color = connected ? connectedColor : disconnectedColor;

            if (connectionText != null)
                connectionText.text = connected ? "● CONNECTED" : "○ WAITING...";
        }

        private void UpdateWeaponUI()
        {
            if (weaponSystem == null) return;
            var weapon = weaponSystem.Current;

            if (weaponNameText != null)
                weaponNameText.text = weapon.displayName.ToUpper();

            if (ammoCurrentText != null)
            {
                ammoCurrentText.text = weaponSystem.CurrentAmmo.ToString();
                ammoCurrentText.color = weaponSystem.CurrentAmmo < 4
                    ? new Color(1f, 0.25f, 0.25f)
                    : Color.white;
            }

            if (ammoMaxText != null)
                ammoMaxText.text = $"/ {weapon.maxAmmo}";

            if (reloadingOverlay != null)
                reloadingOverlay.SetActive(weaponSystem.IsReloading);
        }

        public void ShowKill(string enemyName, int newScore)
        {
            _score = newScore;

            if (scoreText != null)
                scoreText.text = $"{_score:N0}";

            if (killFeedText != null)
            {
                killFeedText.gameObject.SetActive(true);
                killFeedText.text = $"☠ {enemyName}  +100";
                _killFeedTimer = 3f;
            }
        }
    }
}
