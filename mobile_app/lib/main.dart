// GunSync FPS — Main App Entry Point

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/connect_screen.dart';
import 'services/websocket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GunSyncApp());
}

class GunSyncApp extends StatelessWidget {
  const GunSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WebSocketService(),
      child: MaterialApp(
        title: 'GunSync FPS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFFF4040),
            secondary: const Color(0xFF00FF88),
            surface: const Color(0xFF0A0E1A),
          ),
          scaffoldBackgroundColor: const Color(0xFF0A0E1A),
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        home: const ConnectScreen(),
      ),
    );
  }
}
