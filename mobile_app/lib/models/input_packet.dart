// GunSync FPS — Input Packet Model
// Phone → Server → Unity: controller state

class InputPacket {
  final String type;
  final double pitch;
  final double yaw;
  final double roll;
  final bool fire;
  final bool reload;
  final double joystickX;
  final double joystickY;
  final int weaponSwipe; // -1=prev, 0=none, 1=next
  final int timestamp;

  const InputPacket({
    this.type = 'input',
    this.pitch = 0.0,
    this.yaw = 0.0,
    this.roll = 0.0,
    this.fire = false,
    this.reload = false,
    this.joystickX = 0.0,
    this.joystickY = 0.0,
    this.weaponSwipe = 0,
    this.timestamp = 0,
  });

  InputPacket copyWith({
    double? pitch,
    double? yaw,
    double? roll,
    bool? fire,
    bool? reload,
    double? joystickX,
    double? joystickY,
    int? weaponSwipe,
  }) {
    return InputPacket(
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      roll: roll ?? this.roll,
      fire: fire ?? this.fire,
      reload: reload ?? this.reload,
      joystickX: joystickX ?? this.joystickX,
      joystickY: joystickY ?? this.joystickY,
      weaponSwipe: weaponSwipe ?? this.weaponSwipe,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'pitch': pitch,
        'yaw': yaw,
        'roll': roll,
        'fire': fire,
        'reload': reload,
        'joystickX': joystickX,
        'joystickY': joystickY,
        'weaponSwipe': weaponSwipe,
        'timestamp': timestamp,
      };
}
