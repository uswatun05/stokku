import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'screens/kasir_screen.dart';
import 'screens/stok_screen.dart';
import 'screens/kulakan_screen.dart';
import 'screens/log_screen.dart';
import 'services/storage_service.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Database Lokal & Audio Service
  await StorageService().init();
  await AudioService().init();

  // Set orientasi portrait & status bar transparan layaknya PWA mobile web app
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const StokKuApp());
}

class StokKuApp extends StatelessWidget {
  const StokKuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StokKu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617), // slate-950
        primaryColor: const Color(0xFF10B981), // emerald-500
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF6366F1),
          surface: Color(0xFF0F172A),
          error: Color(0xFFDC2626),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F172A),
          selectedItemColor: Color(0xFF10B981),
          unselectedItemColor: Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isAudioMuted = false;

  final List<Widget> _screens = const [
    KasirScreen(),
    StokScreen(),
    KulakanScreen(),
    LogScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _isAudioMuted = AudioService().isMuted;
  }

  void _toggleAudioMute() async {
    await AudioService().toggleMute();
    setState(() {
      _isAudioMuted = AudioService().isMuted;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isAudioMuted ? '🔊 Suara Dinonaktifkan' : '🔊 Suara Diaktifkan'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top Header: Warung Madura Identity & Offline Sync Status
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF1E293B),
                width: 1.0,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo Warung & Status Pill
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '🏪',
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'TOKO KELONTONG',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withOpacity(0.2),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626).withOpacity(0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '24 JAM',
                                  style: TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'StokKu • Local DB Active',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Audio Mute Button
                  IconButton(
                    onPressed: _toggleAudioMute,
                    tooltip: _isAudioMuted ? 'Aktifkan Suara' : 'Bisukan Suara',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      _isAudioMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                      color: _isAudioMuted ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Screen Body (IndexedStack preserves state across tab switches)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Bottom Navigation Bar with 5 Navigation Items
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(
            top: BorderSide(
              color: Color(0xFF1E293B),
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.scanLine),
              label: 'Kasir',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.boxes),
              label: 'Stok',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.alertOctagon),
              label: 'Kulakan',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.fileText),
              label: 'Log Audit',
            ),
          ],
        ),
      ),
    );
  }
}

