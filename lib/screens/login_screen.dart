import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../main.dart';
import '../services/storage_service.dart';
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

    final userLower = username.toLowerCase();

    // ==========================================
    // LOGIKA LOGIN MULTI-CABANG & ROLE-BASED
    // ==========================================
    if (userLower == 'admin' && password == 'admin123') {
      // 1. Role: ADMIN -> Buka Pop-up Dialog "Pilih Cabang" (Toko Pusat, Cabang 1, Cabang 2)
      await AudioService().playSuccess();
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showBranchSelectionDialog();
    } else if (userLower == 'karyawan' && password == 'karyawan123') {
      // 2. Role: KARYAWAN -> Otomatis set activeTokoId ke "Toko Pusat", langsung ke layar utama
      await AudioService().playSuccess();
      await StorageService().setActiveToko('Toko Pusat');
      if (!mounted) return;

      _showSuccessSnackBar('Login berhasil! Cabang aktif: Toko Pusat.');
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(
            role: 'Karyawan',
            tokoId: 'Toko Pusat',
            initialIndex: 0,
          ),
          settings: const RouteSettings(
            arguments: {'role': 'Karyawan', 'tokoId': 'Toko Pusat'},
          ),
        ),
      );
    } else {
      // 3. Kredensial Salah
      await AudioService().playWarning();
      setState(() => _isLoading = false);
      _showErrorSnackBar('Username atau Password salah! Periksa kembali akun Anda.');
    }
  }

  /// Dialog Pilihan Cabang khusus Akun Admin
  void _showBranchSelectionDialog() {
    String selectedBranch = StorageService().activeTokoId;

    final List<Map<String, dynamic>> branches = [
      {
        'id': 'Toko Pusat',
        'name': 'Toko Pusat',
        'desc': 'Gudang Utama & Terminal Kasir Pusat',
        'icon': LucideIcons.building2,
        'badge': 'Pusat',
        'color': const Color(0xFF10B981),
      },
      {
        'id': 'Cabang 1',
        'name': 'Cabang 1',
        'desc': 'Outlet Ritel Cabang 1',
        'icon': LucideIcons.store,
        'badge': 'Cabang',
        'color': const Color(0xFF38BDF8),
      },
      {
        'id': 'Cabang 2',
        'name': 'Cabang 2',
        'desc': 'Outlet Ritel Cabang 2',
        'icon': LucideIcons.store,
        'badge': 'Cabang',
        'color': const Color(0xFFA855F7),
      },
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
            contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.gitFork, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Cabang Operasional',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pilih outlet yang ingin Anda kelola sebagai Admin:',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: branches.map((branch) {
                final isSelected = selectedBranch == branch['id'];
                final Color branchColor = branch['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedBranch = branch['id'] as String;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? branchColor.withValues(alpha: 0.12)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? branchColor : const Color(0xFF334155),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: branchColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(branch['icon'] as IconData, color: branchColor, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      branch['name'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: branchColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        branch['badge'] as String,
                                        style: TextStyle(
                                          color: branchColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  branch['desc'] as String,
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                            color: isSelected ? branchColor : const Color(0xFF64748B),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await StorageService().setActiveToko(selectedBranch);
                    if (!mounted) return;

                    _showSuccessSnackBar('Login berhasil! Cabang aktif: $selectedBranch');
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainNavigationScreen(
                          role: 'Admin',
                          tokoId: selectedBranch,
                          initialIndex: 0,
                        ),
                        settings: RouteSettings(
                          arguments: {'role': 'Admin', 'tokoId': selectedBranch},
                        ),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                  label: Text(
                    'Buka $selectedBranch',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
                  'Sistem Manajemen Stok & Kasir Multi-Cabang',
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
                  'SmartStock AI • Multi-Cabang & Role-Based Access',
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
