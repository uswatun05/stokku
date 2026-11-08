import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/activity_log_model.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

enum LogFilterType { all, penjualan, kulakan, overstock }

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<ActivityLogModel> _logs = [];
  bool _isLoading = true;
  LogFilterType _activeFilter = LogFilterType.all;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await StorageService().loadLogs();
    // Urutkan riwayat log dengan yang terbaru selalu di urutan paling atas
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmClearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Bersihkan Riwayat Log?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Semua catatan audit mutasi stok, transaksi kasir, dan peringatan overstock akan dihapus permanen dari memori lokal HP.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(LucideIcons.trash2, size: 15),
            label: const Text('Bersihkan Semua'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService().clearLogs();
      await AudioService().playWarning();
      await _loadLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(LucideIcons.checkCheck, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text('Semua riwayat log mutasi berhasil dibersihkan!'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Menentukan kategori log: Penjualan, Kulakan/Restock, atau Peringatan Overstock
  LogFilterType _classifyLog(ActivityLogModel log) {
    final act = log.action.toLowerCase();
    final desc = log.description.toLowerCase();

    // 1. Peringatan Overstock / Bahaya / Hapus (Merah)
    if (act.contains('overstock') ||
        desc.contains('overstock') ||
        act.contains('hapus') ||
        log.type == 'danger' ||
        log.type == 'warning') {
      return LogFilterType.overstock;
    }

    // 2. Penjualan / Kasir (Hijau)
    if (act.contains('penjualan') ||
        act.contains('kasir') ||
        act.contains('jual') ||
        log.type == 'success') {
      return LogFilterType.penjualan;
    }

    // 3. Kulakan / Restock (Biru)
    return LogFilterType.kulakan;
  }

  Color _getColorForFilter(LogFilterType filter) {
    switch (filter) {
      case LogFilterType.penjualan:
        return const Color(0xFF10B981); // Hijau Emerald
      case LogFilterType.kulakan:
        return const Color(0xFF38BDF8); // Biru Sky
      case LogFilterType.overstock:
        return const Color(0xFFEF4444); // Merah Red
      case LogFilterType.all:
        return Colors.white;
    }
  }

  IconData _getIconForFilter(LogFilterType filter) {
    switch (filter) {
      case LogFilterType.penjualan:
        return LucideIcons.shoppingBag;
      case LogFilterType.kulakan:
        return LucideIcons.truck;
      case LogFilterType.overstock:
        return LucideIcons.alertTriangle;
      case LogFilterType.all:
        return LucideIcons.fileText;
    }
  }

  List<ActivityLogModel> get _filteredLogs {
    if (_activeFilter == LogFilterType.all) return _logs;
    return _logs.where((l) => _classifyLog(l) == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss • dd/MM/yyyy');
    final displayedLogs = _filteredLogs;

    // Hitung jumlah tiap kategori untuk badge counter
    final penjualanCount = _logs.where((l) => _classifyLog(l) == LogFilterType.penjualan).length;
    final kulakanCount = _logs.where((l) => _classifyLog(l) == LogFilterType.kulakan).length;
    final overstockCount = _logs.where((l) => _classifyLog(l) == LogFilterType.overstock).length;

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // slate-950
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: _loadLogs,
              color: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF0F172A),
              child: Column(
                children: [
                  // ==========================================
                  // HEADER LOG & TOMBOL BERSIHKAN LOG
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                ),
                                child: const Icon(LucideIcons.fileClock, color: Color(0xFF10B981), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Audit Mutasi Stok',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_logs.length} Total Riwayat Tercatat',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Tombol Refresh Cepat
                              IconButton(
                                onPressed: _loadLogs,
                                tooltip: 'Muat Ulang Log',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.all(8),
                                ),
                                icon: const Icon(LucideIcons.refreshCw, size: 16, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 8),

                              // Tombol Bersihkan Log
                              if (_logs.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: _confirmClearLogs,
                                  icon: const Icon(LucideIcons.trash2, size: 14),
                                  label: const Text(
                                    'Bersihkan',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                                    foregroundColor: const Color(0xFFEF4444),
                                    elevation: 0,
                                    side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==========================================
                  // FILTER CHIPS (Semua, Penjualan, Kulakan, Overstock)
                  // ==========================================
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Semua (${_logs.length})',
                          filter: LogFilterType.all,
                          activeColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Penjualan ($penjualanCount)',
                          filter: LogFilterType.penjualan,
                          activeColor: const Color(0xFF10B981), // Hijau
                          icon: LucideIcons.shoppingBag,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Kulakan ($kulakanCount)',
                          filter: LogFilterType.kulakan,
                          activeColor: const Color(0xFF38BDF8), // Biru
                          icon: LucideIcons.truck,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Peringatan ($overstockCount)',
                          filter: LogFilterType.overstock,
                          activeColor: const Color(0xFFEF4444), // Merah
                          icon: LucideIcons.alertTriangle,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ==========================================
                  // DAFTAR LOG DENGAN LISTVIEW.BUILDER
                  // ==========================================
                  Expanded(
                    child: displayedLogs.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF1E293B)),
                                      ),
                                      child: const Icon(LucideIcons.history, color: Color(0xFF475569), size: 40),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Tidak Ada Riwayat Log',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Aktivitas transaksi kasir, kulakan restock, dan overstock alert akan otomatis tercatat di sini secara real-time.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: displayedLogs.length,
                            itemBuilder: (context, index) {
                              final log = displayedLogs[index];
                              final category = _classifyLog(log);
                              final color = _getColorForFilter(category);
                              final icon = _getIconForFilter(category);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: color.withOpacity(0.25),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Ikon Kategori Aktivitas
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: color.withOpacity(0.3)),
                                        ),
                                        child: Icon(icon, color: color, size: 20),
                                      ),
                                      const SizedBox(width: 12),

                                      // Detail Aktivitas & Waktu
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Baris Atas: Badge Jenis Aktivitas & Jam Kejadian
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Badge Jenis Aktivitas
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: color.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: color.withOpacity(0.35)),
                                                  ),
                                                  child: Text(
                                                    log.action.toUpperCase(),
                                                    style: TextStyle(
                                                      color: color,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),

                                                // Jam & Tanggal Kejadian
                                                Row(
                                                  children: [
                                                    const Icon(LucideIcons.clock, size: 11, color: Color(0xFF64748B)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      timeFormat.format(log.timestamp),
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

                                            const SizedBox(height: 8),

                                            // Deskripsi Aktivitas Mutasi Stok
                                            Text(
                                              log.description,
                                              style: const TextStyle(
                                                color: Color(0xFFE2E8F0),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required LogFilterType filter,
    required Color activeColor,
    IconData? icon,
  }) {
    final isSelected = _activeFilter == filter;

    return InkWell(
      onTap: () {
        setState(() {
          _activeFilter = filter;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF1E293B),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
