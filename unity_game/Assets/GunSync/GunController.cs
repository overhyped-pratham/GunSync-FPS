// GunSync FPS — GunController
// Handles shooting via raycast, hit detection, muzzle flash, and
// triggering recoil events back to the phone.
//
// SETUP: Attach to the PlayerCameraRoot (the child transform that rotates
//        with look). Assign WeaponSystem and muzzle flash references.

using System.Collections;
using UnityEngine;

namespace GunSync
{
    public class GunController : MonoBehaviour
    {
        [Header("References")]
        public WeaponSystem weaponSystem;
        public Camera fpsCam;

        [Header("Effects")]
        public ParticleSystem muzzleFlash;
        public GameObject bulletImpactPrefab;
        public GameObject bloodSplatterPrefab;
        public AudioSource gunAudioSource;
        public AudioClip[] fireSounds;      // index maps to weapon index
        public AudioClip reloadSound;
        public AudioClip emptyClickSound;

        [Header("Layers")]
        public LayerMask shootableLayers = ~0;  // All layers by default

        [Header("Gun Model")]
        public Transform gunModel;              // For recoil animation
        private Vector3 _gunOriginalPos;
        private bool _fireLastFrame = false;

        private void Awake()
        {
            if (fpsCam == null) fpsCam = Camera.main;
            if (gunModel != null) _gunOriginalPos = gunModel.localPosition;
        }

        private void OnEnable()
        {
            GunSyncManager.OnInputReceived += HandleInput;
        }

        private void OnDisable()
        {
            GunSyncManager.OnInputReceived -= HandleInput;
        }

        private void HandleInput(PhoneInputData data)
        {
            var weapon = weaponSystem.Current;

            // Automatic fire: fire every frame while button held
            if (weapon.isAutomatic)
            {
                if (data.fire) TryFire();
            }
            else
            {
                // Semi-auto: fire on rising edge (button just pressed)
                if (data.fire && !_fireLastFrame) TryFire();
            }

            _fireLastFrame = data.fire;
        }

        private void TryFire()
        {
            if (!weaponSystem.CanFire)
            {
                if (weaponSystem.CurrentAmmo <= 0 && !weaponSystem.IsReloading)
                {
                    PlaySound(emptyClickSound);
                }
                return;
            }

            if (!weaponSystem.ConsumeAmmo()) return;

            // Fire all pellets (shotgun = 8, others = 1)
            var weapon = weaponSystem.Current;
            for (int i = 0; i < weapon.pellets; i++)
            {
                FireRaycast(weapon);
            }

            // Muzzle flash
            muzzleFlash?.Play();

            // Sound
            if (fireSounds != null && fireSounds.Length > 0)
            {
                var clip = fireSounds[Mathf.Min(GetWeaponIndex(), fireSounds.Length - 1)];
                PlaySound(clip);
            }

            // Recoil animation on gun model
            StartCoroutine(GunRecoilAnim());

            // Send recoil event to phone via server
            GunSyncManager.Instance?.SendRecoil(
                weapon.name,
                weapon.recoilPattern,
                weapon.recoilDuration,
                weapon.recoilIntensity
            );
        }

        private void FireRaycast(WeaponData weapon)
        {
            // Spread calculation
            var spreadX = Random.Range(-weapon.spread, weapon.spread);
            var spreadY = Random.Range(-weapon.spread, weapon.spread);
            var direction = fpsCam.transform.forward
                          + fpsCam.transform.right * (spreadX * 0.01f)
                          + fpsCam.transform.up * (spreadY * 0.01f);

            if (Physics.Raycast(fpsCam.transform.position, direction, out RaycastHit hit,
                weapon.range, shootableLayers))
            {
                Debug.DrawRay(fpsCam.transform.position, direction * hit.distance, Color.red, 0.5f);

                // Spawn impact effect
                SpawnImpact(hit);

                // Check for enemy hit
                var enemy = hit.collider.GetComponentInParent<EnemyAI>();
                if (enemy != null)
                {
                    bool killed = enemy.TakeDamage(weapon.damage, hit.point);
                    GunSyncManager.Instance?.SendHit(enemy.gameObject.name, killed);

                    if (bloodSplatterPrefab != null)
                    {
                        var blood = Instantiate(bloodSplatterPrefab, hit.point,
                            Quaternion.LookRotation(hit.normal));
                        Destroy(blood, 2f);
                    }
                }
            }
        }

        private void SpawnImpact(RaycastHit hit)
        {
            if (bulletImpactPrefab == null) return;
            var impact = Instantiate(bulletImpactPrefab, hit.point,
                Quaternion.LookRotation(hit.normal));
            Destroy(impact, 2f);
        }

        private IEnumerator GunRecoilAnim()
        {
            if (gunModel == null) yield break;

            var recoilPos = _gunOriginalPos + new Vector3(0f, -0.05f, -0.12f);
            float t = 0f;

            // Kick back
            while (t < 0.08f)
            {
                t += Time.deltaTime;
                gunModel.localPosition = Vector3.Lerp(_gunOriginalPos, recoilPos, t / 0.08f);
                yield return null;
            }

            // Return
            t = 0f;
            while (t < 0.12f)
            {
                t += Time.deltaTime;
                gunModel.localPosition = Vector3.Lerp(recoilPos, _gunOriginalPos, t / 0.12f);
                yield return null;
            }

            gunModel.localPosition = _gunOriginalPos;
        }

        private void PlaySound(AudioClip clip)
        {
            if (gunAudioSource != null && clip != null)
                gunAudioSource.PlayOneShot(clip);
        }

        private int GetWeaponIndex()
        {
            for (int i = 0; i < weaponSystem.weapons.Length; i++)
                if (weaponSystem.weapons[i].name == weaponSystem.Current.name)
                    return i;
            return 0;
        }
    }
}
