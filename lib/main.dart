import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'screens/login_screen.dart';
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

  // Set orientasi portrait & status bar transparan layaknya aplikasi POS modern
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
      // LoginScreen sebagai halaman pertama (initial route) saat aplikasi dijalankan
      home: const LoginScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final String? role; // 'Admin' atau 'Karyawan'
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.role,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  bool _isAudioMuted = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _isAudioMuted = AudioService().isMuted;
  }

  /// Mendeteksi role pengguna aktif (dari widget constructor argument atau RouteSettings arguments)
  String get _currentRole {
    if (widget.role != null && widget.role!.isNotEmpty) {
      return widget.role!;
    }
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is String && routeArgs.isNotEmpty) {
      return routeArgs;
    }
    if (routeArgs is Map && routeArgs['role'] is String) {
      return routeArgs['role'] as String;
    }
    return 'Karyawan';
  }

  bool get _isAdmin => _currentRole.toLowerCase() == 'admin';

  /// Menyusun daftar layar sesuai Role yang sedang login:
  /// - Admin: Kasir, Stok, Kulakan, Log Audit (4 Layar)
  /// - Karyawan: Kasir, Stok (2 Layar, Kulakan & Log disembunyikan)
  List<Widget> _buildScreens() {
    if (_isAdmin) {
      return const [
        KasirScreen(),
        StokScreen(),
        KulakanScreen(),
        LogScreen(),
      ];
    } else {
      return const [
        KasirScreen(),
        StokScreen(),
      ];
    }
  }

  /// Menyusun tab BottomNavigationBar sesuai Role:
  /// - Admin: 4 Tab (Kasir, Stok, Kulakan, Log)
  /// - Karyawan: 2 Tab (Kasir, Stok)
  List<BottomNavigationBarItem> _buildNavItems() {
    if (_isAdmin) {
      return const [
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
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.scanLine),
          label: 'Kasir',
        ),
        BottomNavigationBarItem(
          icon: Icon(LucideIcons.boxes),
          label: 'Stok',
        ),
      ];
    }
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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444)),
        ),
        title: const Row(
          children: [
            Icon(LucideIcons.logOut, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Keluar Akun?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Yakin ingin keluar dari akun sebagai ${_currentRole.toUpperCase()}?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final navItems = _buildNavItems();

    // Guard untuk index di luar jangkauan jika berganti role
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      // Top Header: Identitas Warung, Lencana Role, Audio Mute, & Logout
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
                  // Logo Warung & Role Badge
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
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
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
                                'WARUNG MADURA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Lencana Role Aktif (Admin vs Karyawan)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _isAdmin
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                  border: Border.all(
                                    color: _isAdmin
                                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                        : const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isAdmin ? '👑 ADMIN' : '👷 KARYAWAN',
                                  style: TextStyle(
                                    color: _isAdmin ? const Color(0xFF6EE7B7) : const Color(0xFF7DD3FC),
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
                                decoration: BoxDecoration(
                                  color: _isAdmin ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isAdmin
                                    ? 'StokKu • Hak Akses Penuh (4 Tab)'
                                    : 'StokKu • Akses Kasir & Stok (2 Tab)',
                                style: const TextStyle(
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

                  // Actions: Toggle Audio & Logout Button
                  Row(
                    children: [
                      // Tombol Mute/Unmute Audio
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
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Tombol Logout Akun
                      IconButton(
                        onPressed: _confirmLogout,
                        tooltip: 'Keluar Akun',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(LucideIcons.logOut, color: Color(0xFFEF4444), size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Screen Body: IndexedStack dengan layar sesuai hak akses role aktif
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),

      // Bottom Navigation Bar:
      // - Admin: 4 Tab (Kasir, Stok, Kulakan, Log Audit)
      // - Karyawan: 2 Tab (Kasir, Stok)
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
          items: navItems,
        ),
      ),
    );
  }
}
