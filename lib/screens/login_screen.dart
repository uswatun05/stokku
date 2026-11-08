import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../main.dart';
import '../services/audio_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      AudioService().playWarning();
      _showErrorSnackBar('Username dan Password wajib diisi!');
      return;
    }

    setState(() => _isLoading = true);

    // Efek loading singkat (600ms) untuk simulasi proses verifikasi
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // ==========================================
    // LOGIKA LOGIN DUMMY ROLE-BASED (RBAC)
    // ==========================================
    final userLower = username.toLowerCase();

    if (userLower == 'admin' && password == 'admin123') {
      // 1. Role: ADMIN -> Akses penuh ke seluruh menu (Kasir, Stok, Kulakan, Log)
      await AudioService().playSuccess();
      if (!mounted) return;

      _showSuccessSnackBar('Login berhasil! Selamat datang, Admin.');
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(
            role: 'Admin',
            initialIndex: 0,
          ),
          settings: const RouteSettings(arguments: 'Admin'),
        ),
      );
    } else if (userLower == 'karyawan' && password == 'karyawan123') {
      // 2. Role: KARYAWAN -> Hanya akses tab Kasir & Stok (Kulakan & Log disembunyikan)
      await AudioService().playSuccess();
      if (!mounted) return;

      _showSuccessSnackBar('Login berhasil! Selamat datang, Karyawan.');
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(
            role: 'Karyawan',
            initialIndex: 0,
          ),
          settings: const RouteSettings(arguments: 'Karyawan'),
        ),
      );
    } else {
      // 3. Kredensial Salah
      await AudioService().playWarning();
      setState(() => _isLoading = false);
      _showErrorSnackBar('Username atau Password salah! Periksa kembali akun Anda.');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669), // Emerald-600 (Sukses)
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626), // Merah Crimson (Error)
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _fillCredentials(String user, String pass) {
    _usernameController.text = user;
    _passwordController.text = pass;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // slate-950
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. LOGO & IDENTITAS APLIKASI
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🏪', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'StokKu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sistem Manajemen Stok & Kasir Warung Madura',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // 2. KARTU FORM LOGIN MODERN
                Container(
                  padding: const EdgeInsets.all(22.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A), // slate-900
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1E293B)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Masuk Akun',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Silakan masukkan kredensial untuk mengakses aplikasi.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                      ),
                      const SizedBox(height: 20),

                      // Input Username
                      const Text(
                        'Username',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(LucideIcons.user, color: Color(0xFF10B981), size: 18),
                            hintText: 'admin / karyawan',
                            hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Input Password
                      const Text(
                        'Password',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.lock, color: Color(0xFF10B981), size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                                color: const Color(0xFF94A3B8),
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            hintText: '••••••••',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tombol Login dengan Indikator Loading
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Memverifikasi...',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.logIn, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Masuk ke Sistem',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. SHORTCUT AKUN DEMO CEPAT (ADMIN & KARYAWAN)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Pilihan Akun Uji Coba (Klik Cepat):',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _fillCredentials('admin', 'admin123'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                ),
                                child: const Column(
                                  children: [
                                    Text('👑 Role: Admin', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 2),
                                    Text('admin / admin123', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => _fillCredentials('karyawan', 'karyawan123'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                                ),
                                child: const Column(
                                  children: [
                                    Text('👷 Role: Karyawan', style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 11, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 2),
                                    Text('karyawan / karyawan123', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Footer
                const Text(
                  'SmartStock AI • Role-Based Authentication',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
