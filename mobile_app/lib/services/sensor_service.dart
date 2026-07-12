// GunSync FPS — Sensor Service
// Streams calibrated gyroscope data and detects reload gesture.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorData {
  final double pitch; // degrees
  final double yaw; // degrees
  final double roll; // degrees

  const SensorData({
    this.pitch = 0.0,
    this.yaw = 0.0,
    this.roll = 0.0,
  });
}

class SensorService extends ChangeNotifier {
  // ── Calibration offsets (raw gyro values when "centered")
  double _calibPitch = 0.0;
  double _calibYaw = 0.0;
  double _calibRoll = 0.0;

  // ── Accumulated angles from gyro integration
  double _pitch = 0.0;
  double _yaw = 0.0;
  double _roll = 0.0;

  // ── Internal state
  DateTime _lastGyroTime = DateTime.now();
  bool _reloadCooldown = false;
  bool _isActive = false;

  // ── Subscriptions
  StreamSubscription? _gyroSub;
  StreamSubscription? _accelSub;

  // ── Stream controllers
  final _sensorController = StreamController<SensorData>.broadcast();
  final _reloadController = StreamController<void>.broadcast();

  Stream<SensorData> get onSensorData => _sensorController.stream;
  Stream<void> get onReload => _reloadController.stream;

  SensorData get currentData =>
      SensorData(pitch: _pitch, yaw: _yaw, roll: _roll);

  /// Start streaming sensor data.
  void start() {
    if (_isActive) return;
    _isActive = true;

    // ── Gyroscope: integrate angular velocity → absolute angles
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 16), // ~60Hz
    ).listen((event) {
      final now = DateTime.now();
      final dt = now.difference(_lastGyroTime).inMicroseconds / 1e6;
      _lastGyroTime = now;

      // Integrate: angle += angular_velocity * dt → convert rad to degrees
      _pitch += (event.x * dt) * (180 / 3.14159265);
      _yaw += (event.y * dt) * (180 / 3.14159265);
      _roll += (event.z * dt) * (180 / 3.14159265);

      // Apply calibration offset
      final calibrated = SensorData(
        pitch: _pitch - _calibPitch,
        yaw: _yaw - _calibYaw,
        roll: _roll - _calibRoll,
      );

      _sensorController.add(calibrated);
    });

    // ── Accelerometer: detect reload gesture (sharp downward flick)
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 33), // ~30Hz
    ).listen((event) {
      // Y-axis: strong negative value = sharp downward flick
      if (event.y < -18.0 && !_reloadCooldown) {
        debugPrint('[Sensor] Reload gesture detected! Y=${event.y.toStringAsFixed(1)}');
        _reloadController.add(null);
        _reloadCooldown = true;
        // 2-second cooldown to prevent accidental double-reloads
        Future.delayed(const Duration(seconds: 2), () {
          _reloadCooldown = false;
        });
      }
    });

    debugPrint('[Sensor] Started 🎮');
  }

  /// Lock current phone orientation as the "center / forward" position.
  void calibrate() {
    _calibPitch = _pitch;
    _calibYaw = _yaw;
    _calibRoll = _roll;
    debugPrint('[Sensor] Calibrated → pitch=$_calibPitch yaw=$_calibYaw roll=$_calibRoll');
    notifyListeners();
  }

  /// Reset accumulated angles and calibration.
  void reset() {
    _pitch = 0.0;
    _yaw = 0.0;
    _roll = 0.0;
    _calibPitch = 0.0;
    _calibYaw = 0.0;
    _calibRoll = 0.0;
    notifyListeners();
  }

  /// Stop sensor streams.
  void stop() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _gyroSub = null;
    _accelSub = null;
    _isActive = false;
    debugPrint('[Sensor] Stopped');
  }

  @override
  void dispose() {
    stop();
    _sensorController.close();
    _reloadController.close();
    super.dispose();
  }
}
