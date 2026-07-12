// GunSync FPS — Phone Input Data
// Serializable struct matching the JSON contract from the phone controller.

using System;

namespace GunSync
{
    [Serializable]
    public class PhoneInputData
    {
        public string type = "input";
        public float pitch;
        public float yaw;
        public float roll;
        public bool fire;
        public bool reload;
        public float joystickX;
        public float joystickY;
        public int weaponSwipe;   // -1=prev, 0=none, 1=next
        public long timestamp;

        public override string ToString() =>
            $"[Input] fire={fire} pitch={pitch:F1} yaw={yaw:F1} jx={joystickX:F2} jy={joystickY:F2} reload={reload} swipe={weaponSwipe}";
    }
}
