// GunSync FPS — Controller Screen
// The main game controller UI: joystick, fire button, gyro aim, weapon HUD.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

import '../services/websocket_service.dart';
import '../services/sensor_service.dart';
import '../services/haptic_service.dart';
import '../models/input_packet.dart';
import '../models/recoil_event.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with TickerProviderStateMixin {
  final _sensorService = SensorService();
  final _hapticService = HapticService();

  // ── Controller state
  InputPacket _packet = const InputPacket();
  bool _firePressing = false;
  Timer? _sendTimer;

  // ── Weapon HUD state
  String _currentWeapon = 'pistol';
  int _ammoCurrent = 12;
  int _ammoMax = 12;
  bool _isReloading = false;
  int _score = 0;
  bool _gameConnected = false;

  // ── Fire button animation
  late AnimationController _fireAnim;
  late Animation<double> _fireScale;

  // ── Hit flash animation
  late AnimationController _hitAnim;
  late Animation<double> _hitOpacity;

  // ── Kill banner animation
  late AnimationController _killAnim;
  bool _showKillBanner = false;

  final _weapons = ['pistol', 'smg', 'shotgun', 'sniper'];
  final _weaponIcons = {'pistol': '🔫', 'smg': '⚡', 'shotgun': '💥', 'sniper': '🎯'};
  final _weaponColors = {
    'pistol': const Color(0xFFFFAA00),
    'smg': const Color(0xFF00AAFF),
    'shotgun': const Color(0xFFFF4040),
    'sniper': const Color(0xFF00FF88),
  };

  // ── Stream subscriptions
  late final List<StreamSubscription> _subs;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation for controller layout
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fireAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _fireScale = Tween(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _fireAnim, curve: Curves.easeOut));

    _hitAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _hitOpacity = Tween(begin: 0.0, end: 0.35).animate(
        CurvedAnimation(parent: _hitAnim, curve: Curves.easeInOut));

    _killAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 2));

    _hapticService.init();
    _sensorService.start();
    _startSendLoop();
    _setupEventListeners();
  }

  void _setupEventListeners() {
    final ws = context.read<WebSocketService>();
    _subs = [
      // Recoil → haptic
      ws.onRecoil.listen((event) async {
        await _hapticService.playFromEvent(event);
        _hitAnim.forward(from: 0).then((_) => _hitAnim.reverse());
      }),

      // Hit / Kill
      ws.onHit.listen((event) async {
        if (event.isKill) {
          await _hapticService.playKillConfirm();
          setState(() {
            _score = event.score;
            _showKillBanner = true;
          });
          _killAnim.forward(from: 0).then((_) {
            setState(() => _showKillBanner = false);
          });
        }
      }),

      // Status (game connected?)
      ws.onStatus.listen((event) {
        setState(() => _gameConnected = event.gameConnected);
      }),

      // Ammo
      ws.onAmmo.listen((event) {
        setState(() {
          _currentWeapon = event.weapon;
          _ammoCurrent = event.ammoCurrent;
          _ammoMax = event.ammoMax;
          _isReloading = event.isReloading;
        });
      }),

      // Sensor → update packet
      _sensorService.onSensorData.listen((data) {
        _packet = _packet.copyWith(
          pitch: data.pitch,
          yaw: data.yaw,
          roll: data.roll,
        );
      }),

      // Reload gesture
      _sensorService.onReload.listen((_) async {
        await _hapticService.playReloadStart();
        _packet = _packet.copyWith(reload: true);
        Future.delayed(const Duration(milliseconds: 100), () {
          _packet = _packet.copyWith(reload: false);
        });
      }),
    ];
  }

  /// Send input packet at ~60Hz
  void _startSendLoop() {
    _sendTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final ws = context.read<WebSocketService>();
      if (ws.isConnected) {
        ws.sendInput(_packet.copyWith(fire: _firePressing));
      }
    });
  }

  void _onJoystick(StickDragDetails details) {
    _packet = _packet.copyWith(
      joystickX: details.x,
      joystickY: -details.y, // Invert Y: push forward = positive
    );
  }

  void _onFireDown() async {
    _firePressing = true;
    _fireAnim.forward();
  }

  void _onFireUp() {
    _firePressing = false;
    _fireAnim.reverse();
  }

  void _onWeaponSwipe(int direction) async {
    await _hapticService.playWeaponSwitch();
    _packet = _packet.copyWith(weaponSwipe: direction);
    Future.delayed(const Duration(milliseconds: 100), () {
      _packet = _packet.copyWith(weaponSwipe: 0);
    });
  }

  void _calibrate() {
    _sensorService.calibrate();
    _hapticService.playReloadStart();
  }

  Future<void> _disconnect() async {
    final ws = context.read<WebSocketService>();
    await ws.disconnect();
    if (mounted) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    _sensorService.dispose();
    _fireAnim.dispose();
    _hitAnim.dispose();
    _killAnim.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weaponColor =
        _weaponColors[_currentWeapon] ?? const Color(0xFFFFAA00);

    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: Stack(
        children: [
          // ── Background grid
          _buildBackground(),

          // ── Hit flash overlay
          AnimatedBuilder(
            animation: _hitOpacity,
            builder: (_, __) => IgnorePointer(
              child: Container(
                color: const Color(0xFFFF4040).withOpacity(_hitOpacity.value),
              ),
            ),
          ),

          // ── Main layout
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -600) _onWeaponSwipe(1);
              if (details.primaryVelocity! > 600) _onWeaponSwipe(-1);
            },
            child: Row(
              children: [
                // ── LEFT: Joystick
                Expanded(
                  flex: 4,
                  child: _buildLeftPanel(),
                ),

                // ── CENTER: HUD
                _buildCenterHUD(weaponColor),

                // ── RIGHT: Fire + Actions
                Expanded(
                  flex: 4,
                  child: _buildRightPanel(weaponColor),
                ),
              ],
            ),
          ),

          // ── Kill banner
          if (_showKillBanner) _buildKillBanner(),

          // ── Top status bar
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return CustomPaint(
      painter: _GridPainter(),
      size: Size.infinite,
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Joystick(
              mode: JoystickMode.all,
              listener: _onJoystick,
              base: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12), width: 2),
                ),
              ),
              stick: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 14,
            child: Text(
              'MOVE',
              style: TextStyle(
                  color: Color(0xFF444860),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCenterHUD(Color weaponColor) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Connection badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_gameConnected
                      ? const Color(0xFF00FF88)
                      : const Color(0xFFFF4040))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _gameConnected
                    ? const Color(0xFF00FF88)
                    : const Color(0xFFFF4040),
                width: 1,
              ),
            ),
            child: Text(
              _gameConnected ? '🟢 LIVE' : '🔴 WAIT',
              style: const TextStyle(
                  color: Colors.white, fontSize: 9, letterSpacing: 1),
            ),
          ),
          const Spacer(),

          // Crosshair
          _buildCrosshair(weaponColor),
          const SizedBox(height: 8),

          // Weapon name
          Text(
            _weaponIcons[_currentWeapon] ?? '🔫',
            style: const TextStyle(fontSize: 24),
          ),
          Text(
            _currentWeapon.toUpperCase(),
            style: TextStyle(
              color: weaponColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),

          // Ammo counter
          _isReloading
              ? const Text(
                  'RELOADING...',
                  style: TextStyle(
                      color: Color(0xFFFFAA00),
                      fontSize: 9,
                      letterSpacing: 1.5),
                )
              : RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_ammoCurrent',
                        style: TextStyle(
                          color: _ammoCurrent < 4
                              ? const Color(0xFFFF4040)
                              : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: '/$_ammoMax',
                        style: const TextStyle(
                          color: Color(0xFF555870),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 4),
          const Text(
            'AMMO',
            style: TextStyle(
                color: Color(0xFF444860),
                fontSize: 9,
                letterSpacing: 2),
          ),
          const Spacer(),

          // Score
          Text(
            '$_score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'SCORE',
            style: TextStyle(
                color: Color(0xFF444860),
                fontSize: 9,
                letterSpacing: 2),
          ),
          const SizedBox(height: 16),

          // Swipe hint
          const Text(
            '← SWIPE →\nWeapon Switch',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF2A2F45), fontSize: 9, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Shake ↓ to Reload',
            style: TextStyle(color: Color(0xFF2A2F45), fontSize: 9),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCrosshair(Color color) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(painter: _CrosshairPainter(color)),
    );
  }

  Widget _buildRightPanel(Color weaponColor) {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Calibrate button
          Padding(
            padding: const EdgeInsets.only(right: 24, top: 24),
            child: Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _calibrate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2F45)),
                  ),
                  child: const Text(
                    '⊕ CALIBRATE',
                    style: TextStyle(
                        color: Color(0xFF888DA7),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // FIRE button
          Padding(
            padding: const EdgeInsets.only(bottom: 28, right: 28),
            child: ScaleTransition(
              scale: _fireScale,
              child: GestureDetector(
                onTapDown: (_) => _onFireDown(),
                onTapUp: (_) => _onFireUp(),
                onTapCancel: _onFireUp,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        weaponColor,
                        weaponColor.withOpacity(0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: weaponColor.withOpacity(0.5),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'FIRE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Consumer<WebSocketService>(
              builder: (_, ws, __) => Text(
                ws.isConnected ? '● CONNECTED' : '○ DISCONNECTED',
                style: TextStyle(
                  color: ws.isConnected
                      ? const Color(0xFF00FF88)
                      : const Color(0xFFFF4040),
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _disconnect,
              child: const Text(
                '✕ EXIT',
                style: TextStyle(
                    color: Color(0xFF444860),
                    fontSize: 9,
                    letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKillBanner() {
    return Center(
      child: AnimatedOpacity(
        opacity: _showKillBanner ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF88).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00FF88), width: 2),
          ),
          child: const Text(
            '☠️  ENEMY DOWN',
            style: TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom painters

class _CrosshairPainter extends CustomPainter {
  final Color color;
  _CrosshairPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const gap = 5.0;
    const len = 8.0;

    canvas.drawLine(Offset(cx - gap - len, cy), Offset(cx - gap, cy), paint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + gap + len, cy), paint);
    canvas.drawLine(Offset(cx, cy - gap - len), Offset(cx, cy - gap), paint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + gap + len), paint);
    canvas.drawCircle(Offset(cx, cy), 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.color != color;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
