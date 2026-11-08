import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/item_model.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final Function(double delta)? onAdjustStock;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPrintBarcode;

  const ItemCard({
    super.key,
    required this.item,
    this.onAdjustStock,
    this.onEdit,
    this.onDelete,
    this.onPrintBarcode,
  });

  String _formatStock(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // slate-900
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.status == ItemStatus.overstock
              ? const Color(0xFFEF4444).withOpacity(0.5)
              : (item.status == ItemStatus.menipis
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : const Color(0xFF1E293B)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Emoji, Nama, Harga, & Badge Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container Emoji Produk
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Center(
                    child: Text(
                      item.img,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info Nama, Kategori, & Barcode
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currencyFormatter.format(item.price),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            item.isCurah ? LucideIcons.sparkles : LucideIcons.scanLine,
                            size: 11,
                            color: item.isCurah ? const Color(0xFF818CF8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.barcode.isNotEmpty ? item.barcode : '-',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: item.isCurah ? const Color(0xFFA5B4FC) : const Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Sisa Stok & Badge Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.statusBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.statusLabel.toUpperCase(),
                        style: TextStyle(
                          color: item.statusTextColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _formatStock(item.stock),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: ' ${item.unit}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Progress Kapasitas Maksimal
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kapasitas: ${_formatStock(item.stock)} / ${_formatStock(item.maxStock)} ${item.unit}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                    Text(
                      '${item.capacityPercentageInt}%',
                      style: TextStyle(
                        color: item.statusTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: item.capacityPercentage,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item.status == ItemStatus.overstock
                          ? const Color(0xFFEF4444)
                          : (item.status == ItemStatus.menipis
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981)),
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1E293B), height: 1),
            const SizedBox(height: 8),

            // Row 3: Tombol Aksi Cepat (+ / -) & Menu Edit/Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quick Stock Adjust (+1, -1, +5)
                Row(
                  children: [
                    const Text(
                      'Stok Cepat:',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                    _buildDeltaButton('-1', -1.0, color: const Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    _buildDeltaButton('+1', 1.0, color: const Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    _buildDeltaButton('+5', 5.0, color: const Color(0xFF10B981)),
                  ],
                ),

                // Tombol Cetak (jika Curah), Edit (Pensil), & Hapus (Tong Sampah)
                Row(
                  children: [
                    if (item.isCurah && onPrintBarcode != null)
                      IconButton(
                        icon: const Icon(LucideIcons.printer, size: 16, color: Color(0xFF818CF8)),
                        tooltip: 'Cetak Label Thermal',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: onPrintBarcode,
                      ),
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(LucideIcons.edit2, size: 16, color: Color(0xFF94A3B8)),
                        tooltip: 'Edit Barang',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: onEdit,
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFEF4444)),
                        tooltip: 'Hapus Barang',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeltaButton(String label, double delta, {required Color color}) {
    return InkWell(
      onTap: onAdjustStock != null ? () => onAdjustStock!(delta) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

