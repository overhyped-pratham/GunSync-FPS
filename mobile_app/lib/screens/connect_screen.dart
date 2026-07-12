// GunSync FPS — Connect Screen
// Entry screen: enter ngrok WSS URL or scan QR code, then connect.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../services/websocket_service.dart';
import 'controller_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with TickerProviderStateMixin {
  final _urlController = TextEditingController(text: 'ws://');
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a server URL');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    final ws = context.read<WebSocketService>();
    final ok = await ws.connect(url);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ControllerScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() {
        _connecting = false;
        _error = 'Connection failed: ${ws.lastError}';
      });
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null && code.startsWith('ws')) {
      setState(() {
        _scanning = false;
        _urlController.text = code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: _scanning ? _buildScanner() : _buildConnectUI(),
      ),
    );
  }

  Widget _buildConnectUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [
                      Color(0xFFFF4040),
                      Color(0xFF8B0000),
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4040).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.gps_fixed,
                      color: Colors.white, size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Title
          const Center(
            child: Text(
              'GunSync FPS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const Center(
            child: Text(
              'Your Phone Is Your Gun',
              style: TextStyle(
                color: Color(0xFF888DA7),
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // ── URL field label
          const Text(
            'SERVER URL',
            style: TextStyle(
              color: Color(0xFFFF4040),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),

          // ── URL field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141824),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2F45), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: InputBorder.none,
                      hintText: 'ws://x.ngrok.io:PORT',
                      hintStyle: TextStyle(color: Color(0xFF444860)),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onSubmitted: (_) => _connect(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner,
                      color: Color(0xFFFF4040)),
                  tooltip: 'Scan QR from terminal',
                  onPressed: () => setState(() => _scanning = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Help text
          const Text(
            'Run the server and scan the QR code printed in the terminal.',
            style: TextStyle(color: Color(0xFF666880), fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tip: ngrok URL looks like  ws://x.tcp.ngrok.io:12345',
            style: TextStyle(
                color: Color(0xFF444860),
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0A0A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8B0000)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF4040), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFFF8080), fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Connect Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _connecting ? null : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4040),
                disabledBackgroundColor: const Color(0xFF8B0000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _connecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'CONNECT TO SERVER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 40),

          // ── Feature pills
          const Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _FeaturePill('🎯', 'Gyro Aim'),
                _FeaturePill('🕹️', 'Joystick Move'),
                _FeaturePill('📳', 'Haptic Recoil'),
                _FeaturePill('🔄', 'Shake Reload'),
                _FeaturePill('🔫', '4 Weapons'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(onDetect: _onQrDetected),
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Scan the QR code from the terminal',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _scanning = false),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Cancel',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String emoji;
  final String label;

  const _FeaturePill(this.emoji, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2F45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888DA7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
