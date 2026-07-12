// GunSync FPS — Haptic Service
// Maps Unity recoil events to distinct vibration patterns per weapon.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../models/recoil_event.dart';

class HapticService {
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;

  /// Initialize — check device vibrator capabilities.
  Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;
      debugPrint(
          '[Haptic] Vibrator: $_hasVibrator | Amplitude control: $_hasAmplitudeControl');
    } catch (e) {
      debugPrint('[Haptic] Init error: $e');
    }
  }

  /// Play haptic recoil for a given weapon type.
  Future<void> playRecoil(GunType gun) async {
    if (!_hasVibrator) return;

    try {
      switch (gun) {
        case GunType.pistol:
          await _pistolRecoil();
          break;
        case GunType.smg:
          await _smgRecoil();
          break;
        case GunType.shotgun:
          await _shotgunRecoil();
          break;
        case GunType.sniper:
          await _sniperRecoil();
          break;
      }
    } catch (e) {
      debugPrint('[Haptic] Vibration error: $e');
    }
  }

  /// Play recoil from a RecoilEvent received from Unity.
  Future<void> playFromEvent(RecoilEvent event) async {
    await playRecoil(event.gunType);
  }

  /// Weapon switch feedback — quick double tap.
  Future<void> playWeaponSwitch() async {
    if (!_hasVibrator) return;
    try {
      await Vibration.vibrate(
        pattern: [0, 40, 40, 40],
        intensities: [0, 80, 0, 80],
      );
    } catch (_) {}
  }

  /// Reload start feedback — rumble pulse.
  Future<void> playReloadStart() async {
    if (!_hasVibrator) return;
    try {
      await Vibration.vibrate(duration: 80, amplitude: 100);
    } catch (_) {}
  }

  /// Kill confirmation — strong triple pulse.
  Future<void> playKillConfirm() async {
    if (!_hasVibrator) return;
    try {
      await Vibration.vibrate(
        pattern: [0, 100, 60, 100, 60, 100],
        intensities: [0, 255, 0, 255, 0, 255],
      );
    } catch (_) {}
  }

  // ── Private weapon patterns

  /// Pistol: clean short tap — 120ms at medium amplitude
  Future<void> _pistolRecoil() async {
    await Vibration.vibrate(
      duration: 120,
      amplitude: _hasAmplitudeControl ? 150 : -1,
    );
  }

  /// SMG: rapid burst — 3 short pulses at 60ms each
  Future<void> _smgRecoil() async {
    await Vibration.vibrate(
      pattern: [0, 60, 40, 60, 40, 60],
      intensities: _hasAmplitudeControl ? [0, 180, 0, 160, 0, 140] : [],
    );
  }

  /// Shotgun: heavy thump — 200ms strong single pulse with ramp
  Future<void> _shotgunRecoil() async {
    await Vibration.vibrate(
      duration: 220,
      amplitude: _hasAmplitudeControl ? 255 : -1,
    );
  }

  /// Sniper: strong long kick — 300ms with build-up pattern
  Future<void> _sniperRecoil() async {
    await Vibration.vibrate(
      pattern: [0, 50, 20, 280],
      intensities: _hasAmplitudeControl ? [0, 100, 0, 220] : [],
    );
  }

  /// Cancel any ongoing vibration.
  void stop() {
    try {
      Vibration.cancel();
    } catch (_) {}
  }
}
