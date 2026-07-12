// GunSync FPS — WeaponSystem
// Manages weapon array, switching, ammo, and reload state.
// Sends AmmoEvent to phone whenever state changes.

using System.Collections;
using UnityEngine;

namespace GunSync
{
    [System.Serializable]
    public class WeaponData
    {
        public string name;           // pistol | smg | shotgun | sniper
        public string displayName;
        public int maxAmmo;
        public float fireRate;        // shots per second
        public float reloadTime;      // seconds
        public float damage;
        public float range;           // raycast distance
        public bool isAutomatic;
        public string recoilPattern;  // short | rapid | heavy | strong
        public int recoilDuration;    // ms
        public float recoilIntensity; // 0-1
        public int pellets = 1;       // shotgun spread
        public float spread = 0f;     // bullet spread angle
    }

    public class WeaponSystem : MonoBehaviour
    {
        [Header("Weapons Configuration")]
        public WeaponData[] weapons = new WeaponData[]
        {
            new WeaponData
            {
                name = "pistol", displayName = "Pistol",
                maxAmmo = 12, fireRate = 2.5f, reloadTime = 1.2f,
                damage = 35f, range = 80f, isAutomatic = false,
                recoilPattern = "short", recoilDuration = 120, recoilIntensity = 0.6f,
                pellets = 1, spread = 1.5f,
            },
            new WeaponData
            {
                name = "smg", displayName = "SMG",
                maxAmmo = 30, fireRate = 8f, reloadTime = 1.8f,
                damage = 20f, range = 50f, isAutomatic = true,
                recoilPattern = "rapid", recoilDuration = 60, recoilIntensity = 0.7f,
                pellets = 1, spread = 3f,
            },
            new WeaponData
            {
                name = "shotgun", displayName = "Shotgun",
                maxAmmo = 6, fireRate = 1.2f, reloadTime = 2.2f,
                damage = 18f, range = 25f, isAutomatic = false,
                recoilPattern = "heavy", recoilDuration = 200, recoilIntensity = 1.0f,
                pellets = 8, spread = 6f,
            },
            new WeaponData
            {
                name = "sniper", displayName = "Sniper",
                maxAmmo = 5, fireRate = 0.6f, reloadTime = 2.8f,
                damage = 150f, range = 300f, isAutomatic = false,
                recoilPattern = "strong", recoilDuration = 300, recoilIntensity = 0.9f,
                pellets = 1, spread = 0f,
            },
        };

        // ── State
        private int _currentIndex = 0;
        private int[] _currentAmmo;
        private bool _isReloading = false;
        private float _nextFireTime = 0f;

        // ── Public accessors
        public WeaponData Current => weapons[_currentIndex];
        public int CurrentAmmo => _currentAmmo[_currentIndex];
        public bool IsReloading => _isReloading;
        public bool CanFire => !_isReloading
                               && CurrentAmmo > 0
                               && Time.time >= _nextFireTime;

        private void Awake()
        {
            _currentAmmo = new int[weapons.Length];
            for (int i = 0; i < weapons.Length; i++)
                _currentAmmo[i] = weapons[i].maxAmmo;
        }

        private void OnEnable()
        {
            GunSyncManager.OnInputReceived += HandleInput;
        }

        private void OnDisable()
        {
            GunSyncManager.OnInputReceived -= HandleInput;
        }

        private void Start()
        {
            // Broadcast initial ammo state to phone
            BroadcastAmmo();
        }

        private void HandleInput(PhoneInputData data)
        {
            // Weapon switch
            if (data.weaponSwipe != 0)
            {
                SwitchWeapon(data.weaponSwipe);
            }

            // Reload gesture
            if (data.reload && !_isReloading)
            {
                StartCoroutine(DoReload());
            }
        }

        /// <summary>Called by GunController when a shot is fired.</summary>
        public bool ConsumeAmmo()
        {
            if (!CanFire) return false;

            _currentAmmo[_currentIndex]--;
            _nextFireTime = Time.time + (1f / Current.fireRate);

            BroadcastAmmo();

            // Auto-reload when empty
            if (_currentAmmo[_currentIndex] <= 0 && !_isReloading)
            {
                StartCoroutine(DoReload());
            }

            return true;
        }

        public void SwitchWeapon(int direction)
        {
            if (_isReloading) return;

            _currentIndex = (_currentIndex + direction + weapons.Length) % weapons.Length;
            Debug.Log($"[Weapon] Switched to {Current.displayName}");
            BroadcastAmmo();
        }

        public void StartReload()
        {
            if (!_isReloading && _currentAmmo[_currentIndex] < Current.maxAmmo)
            {
                StartCoroutine(DoReload());
            }
        }

        private IEnumerator DoReload()
        {
            _isReloading = true;
            BroadcastAmmo(); // Tell phone "isReloading = true"
            Debug.Log($"[Weapon] Reloading {Current.displayName}...");

            yield return new WaitForSeconds(Current.reloadTime);

            _currentAmmo[_currentIndex] = Current.maxAmmo;
            _isReloading = false;
            BroadcastAmmo(); // Full ammo, isReloading = false
            Debug.Log($"[Weapon] Reload complete — {Current.displayName} full");
        }

        private void BroadcastAmmo()
        {
            if (GunSyncManager.Instance != null)
            {
                GunSyncManager.Instance.SendAmmoUpdate(
                    Current.name,
                    _currentAmmo[_currentIndex],
                    Current.maxAmmo,
                    _isReloading
                );
            }
        }
    }
}
