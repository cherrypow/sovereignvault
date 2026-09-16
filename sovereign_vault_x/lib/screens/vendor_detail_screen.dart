import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sovereign_core/sovereign_core.dart';
import 'package:uuid/uuid.dart';

class VendorDetailScreen extends StatefulWidget {
  final Vault vault;
  const VendorDetailScreen({super.key, required this.vault});

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('MMM d, yyyy');
  final Set<String> _revealed = {};

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _addOrEditLicense({VaultEntry? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final valueController = TextEditingController(text: existing?.value ?? '');
    DateTime? purchaseDate = existing?.purchaseDate;
    DateTime? expiresOn = existing?.expiresOn;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
          title: Text(existing == null ? 'ADD LICENSE' : 'EDIT LICENSE',
              style: const TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Product name')),
                const SizedBox(height: 12),
                TextField(controller: valueController, decoration: const InputDecoration(labelText: 'License key')),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        label: 'Purchased',
                        date: purchaseDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: purchaseDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setDialogState(() => purchaseDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateButton(
                        label: 'Expires',
                        date: expiresOn,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiresOn ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setDialogState(() => expiresOn = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(existing == null ? 'Add' : 'Save')),
          ],
        ),
      ),
    );

    if (saved != true || nameController.text.trim().isEmpty) return;

    setState(() {
      if (existing != null) {
        existing.name = nameController.text.trim();
        existing.value = valueController.text;
        existing.purchaseDate = purchaseDate;
        existing.expiresOn = expiresOn;
      } else {
        widget.vault.entries.add(VaultEntry(
          id: _uuid.v4(),
          name: nameController.text.trim(),
          value: valueController.text,
          addedDate: DateTime.now(),
          type: 'license',
          purchaseDate: purchaseDate,
          expiresOn: expiresOn,
        ));
      }
    });
    await VaultSession.instance.repository!.save();
  }

  Future<void> _deleteLicense(VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('DELETE LICENSE', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Text('Delete "${entry.name}"? This cannot be undone.', style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        widget.vault.entries.removeWhere((e) => e.id == entry.id);
        _revealed.remove(entry.id);
      });
      await VaultSession.instance.repository!.save();
    }
  }

  Widget _dateButton({required String label, required DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderAt(0.22)),
          color: AppColors.card.withValues(alpha: 0.035),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, letterSpacing: 1, color: AppColors.mutedAt(1))),
            const SizedBox(height: 4),
            Text(date == null ? 'Not set' : _dateFormat.format(date),
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12.5, color: AppColors.text)),
          ],
        ),
      ),
    );
  }

  Color _urgencyColor(DateTime expiresOn) {
    final days = expiresOn.difference(DateTime.now()).inDays;
    if (days <= 7) return AppColors.danger;
    if (days <= 30) return const Color(0xFF9A7B1E);
    return AppColors.mutedAt(1);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.vault.entries;
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(56, 30, 56, 22),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.16)))),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, size: 18), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.vault.category.toUpperCase(),
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                      const SizedBox(height: 4),
                      Text(widget.vault.name,
                          style: TextStyle(fontFamily: AppFonts.serif, fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.card)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 24, 56, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LICENSES — ${entries.length}',
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                  const SizedBox(height: 16),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(child: Text('No licenses yet.', style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.mutedAt(1))))
                        : ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, index) => _row(entries[index]),
                          ),
                  ),
                  InkWell(
                    onTap: () => _addOrEditLicense(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderAt(0.16)))),
                      child: Text('+   ADD A LICENSE',
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(VaultEntry entry) {
    final revealed = _revealed.contains(entry.id) || !entry.sensitive;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.12)))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _addOrEditLicense(existing: entry),
              child: Text(entry.name, style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13.5)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: revealed
                      ? Text(entry.value, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13))
                      : ImageFiltered(
                          imageFilter: _blurFilter,
                          child: Text(entry.value, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13)),
                        ),
                ),
                IconButton(
                  icon: Icon(revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 15, color: AppColors.mutedAt(1)),
                  onPressed: () => setState(() {
                    revealed ? _revealed.remove(entry.id) : _revealed.add(entry.id);
                  }),
                ),
                IconButton(
                  icon: Icon(Icons.copy_outlined, size: 15, color: AppColors.mutedAt(1)),
                  onPressed: () => _copy(entry.value),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: entry.expiresOn == null
                ? Text('No expiration', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, color: AppColors.mutedAt(1)))
                : Text('Expires ${_dateFormat.format(entry.expiresOn!)}',
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, fontWeight: FontWeight.w600, color: _urgencyColor(entry.expiresOn!))),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
              tooltip: 'Delete license',
              onPressed: () => _deleteLicense(entry),
            ),
          ),
        ],
      ),
    );
  }
}

final _blurFilter = ImageFilter.blur(sigmaX: 4, sigmaY: 4);
