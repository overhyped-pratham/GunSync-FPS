// GunSync FPS — Recoil & Outgoing Event Models
// Serializable structs for events sent FROM Unity → FastAPI → Phone.

using System;

namespace GunSync
{
    [Serializable]
    public class RecoilEvent
    {
        public string type = "recoil";
        public string gun;       // pistol | smg | shotgun | sniper
        public string pattern;   // short | rapid | heavy | strong
        public int duration;     // ms
        public float intensity;  // 0.0 - 1.0
    }

    [Serializable]
    public class HitEvent
    {
        public string type = "hit";
        public string enemyId;
        public bool isKill;
        public int score;
    }

    [Serializable]
    public class AmmoEvent
    {
        public string type = "ammo";
        public string weapon;
        public int ammoCurrent;
        public int ammoMax;
        public bool isReloading;
    }

    [Serializable]
    public class PingEvent
    {
        public string type = "pong";
    }
}
