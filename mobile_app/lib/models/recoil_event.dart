// GunSync FPS — Server Event Models
// Events received from Unity via FastAPI server

enum GunType { pistol, smg, shotgun, sniper }

extension GunTypeExt on GunType {
  String get displayName {
    switch (this) {
      case GunType.pistol:
        return 'Pistol';
      case GunType.smg:
        return 'SMG';
      case GunType.shotgun:
        return 'Shotgun';
      case GunType.sniper:
        return 'Sniper';
    }
  }

  String get icon {
    switch (this) {
      case GunType.pistol:
        return '🔫';
      case GunType.smg:
        return '⚡';
      case GunType.shotgun:
        return '💥';
      case GunType.sniper:
        return '🎯';
    }
  }
}

/// Unity → Server → Phone: haptic recoil command
class RecoilEvent {
  final String type;
  final String gun;
  final String pattern;
  final int duration;
  final double intensity;

  const RecoilEvent({
    this.type = 'recoil',
    required this.gun,
    required this.pattern,
    required this.duration,
    required this.intensity,
  });

  factory RecoilEvent.fromJson(Map<String, dynamic> json) => RecoilEvent(
        type: json['type'] ?? 'recoil',
        gun: json['gun'] ?? 'pistol',
        pattern: json['pattern'] ?? 'short',
        duration: json['duration'] ?? 120,
        intensity: (json['intensity'] ?? 0.7).toDouble(),
      );

  GunType get gunType {
    switch (gun.toLowerCase()) {
      case 'smg':
        return GunType.smg;
      case 'shotgun':
        return GunType.shotgun;
      case 'sniper':
        return GunType.sniper;
      default:
        return GunType.pistol;
    }
  }
}

/// Unity → Server → Phone: hit/kill confirmation
class HitEvent {
  final String type;
  final String enemyId;
  final bool isKill;
  final int score;

  const HitEvent({
    this.type = 'hit',
    required this.enemyId,
    required this.isKill,
    required this.score,
  });

  factory HitEvent.fromJson(Map<String, dynamic> json) => HitEvent(
        type: json['type'] ?? 'hit',
        enemyId: json['enemyId'] ?? '',
        isKill: json['isKill'] ?? false,
        score: json['score'] ?? 0,
      );
}

/// Server → Client: connection status
class StatusEvent {
  final bool phoneConnected;
  final bool gameConnected;
  final String message;

  const StatusEvent({
    required this.phoneConnected,
    required this.gameConnected,
    required this.message,
  });

  factory StatusEvent.fromJson(Map<String, dynamic> json) => StatusEvent(
        phoneConnected: json['phoneConnected'] ?? false,
        gameConnected: json['gameConnected'] ?? false,
        message: json['message'] ?? '',
      );
}

/// Unity → Server → Phone: ammo/weapon sync
class AmmoEvent {
  final String weapon;
  final int ammoCurrent;
  final int ammoMax;
  final bool isReloading;

  const AmmoEvent({
    required this.weapon,
    required this.ammoCurrent,
    required this.ammoMax,
    required this.isReloading,
  });

  factory AmmoEvent.fromJson(Map<String, dynamic> json) => AmmoEvent(
        weapon: json['weapon'] ?? 'pistol',
        ammoCurrent: json['ammoCurrent'] ?? 0,
        ammoMax: json['ammoMax'] ?? 0,
        isReloading: json['isReloading'] ?? false,
      );
}
