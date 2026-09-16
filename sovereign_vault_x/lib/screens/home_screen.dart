import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sovereign_core/sovereign_core.dart';
import 'package:uuid/uuid.dart';

import 'unlock_screen.dart';
import 'vendor_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _uuid = const Uuid();
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('MMM d, yyyy');
  String _query = '';

  List<Vault> get _vaults => VaultSession.instance.repository!.vaults;

  List<Vault> get _filteredVaults {
    if (_query.isEmpty) return _vaults;
    final q = _query.toLowerCase();
    return _vaults.where((v) => v.name.toLowerCase().contains(q) || v.category.toLowerCase().contains(q)).toList();
  }

  List<(VaultEntry, Vault)> get _expiringSoon {
    final items = <(VaultEntry, Vault)>[];
    for (final vault in _vaults) {
      for (final entry in vault.entries) {
        if (entry.type == 'license' && entry.expiresOn != null) {
          items.add((entry, vault));
        }
      }
    }
    items.sort((a, b) => a.$1.expiresOn!.compareTo(b.$1.expiresOn!));
    return items;
  }

  Future<void> _addVendor() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('NEW VENDOR', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Vendor name'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (created != true || nameController.text.trim().isEmpty) return;
    setState(() {
      _vaults.add(Vault(
        id: _uuid.v4(),
        name: nameController.text.trim(),
        category: categoryController.text.trim().isEmpty ? 'Software' : categoryController.text.trim(),
      ));
    });
    await VaultSession.instance.repository!.save();
  }

  Future<void> _deleteVendor(Vault vault) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('DELETE VENDOR', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Text('Delete "${vault.name}" and all ${vault.entries.length} license(s) in it? This cannot be undone.',
            style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _vaults.removeWhere((v) => v.id == vault.id));
    await VaultSession.instance.repository!.save();
  }

  Color _urgencyColor(DateTime expiresOn) {
    final days = expiresOn.difference(DateTime.now()).inDays;
    if (days < 0) return AppColors.danger;
    if (days <= 7) return AppColors.danger;
    if (days <= 30) return const Color(0xFF9A7B1E);
    return AppColors.mutedAt(1);
  }

  String _urgencyLabel(DateTime expiresOn) {
    final days = expiresOn.difference(DateTime.now()).inDays;
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Today';
    return 'in ${days}d';
  }

  @override
  Widget build(BuildContext context) {
    final expiring = _expiringSoon;
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(56, 36, 56, 22),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.16)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const AuroraLogo(size: 46, radius: 12),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SOVEREIGN VAULT X',
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 3, color: AppColors.mutedAt(1))),
                      const SizedBox(height: 8),
                      Text('License & Key Tracker',
                          style: TextStyle(fontFamily: AppFonts.serif, fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.card)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('UNLOCKED — SESSION ACTIVE',
                        style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 1.2, color: AppColors.card)),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: () {
                        VaultSession.instance.lock();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const UnlockScreen()),
                          (route) => false,
                        );
                      },
                      child: Icon(Icons.lock_outline, size: 15, color: AppColors.mutedAt(1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 30, 56, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VENDORS — ${_filteredVaults.length}',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search vendors...',
                            hintStyle: TextStyle(color: AppColors.mutedAt(0.8), fontSize: 13),
                            prefixIcon: Icon(Icons.search, size: 17, color: AppColors.mutedAt(1)),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.card.withValues(alpha: 0.03),
                            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.2))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.2))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.5))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: _filteredVaults.isEmpty
                              ? Center(child: Text('No vendors yet.', style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.mutedAt(1))))
                              : ListView.builder(
                                  itemCount: _filteredVaults.length,
                                  itemBuilder: (context, index) {
                                    final vault = _filteredVaults[index];
                                    return InkWell(
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => VendorDetailScreen(vault: vault)),
                                        );
                                        setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.12)))),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(vault.category.toUpperCase(),
                                                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9.5, letterSpacing: 1.2, color: AppColors.mutedAt(1))),
                                                  const SizedBox(height: 4),
                                                  Text(vault.name,
                                                      style: TextStyle(fontFamily: AppFonts.serif, fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.card)),
                                                ],
                                              ),
                                            ),
                                            Text('${vault.entries.length} LICENSE${vault.entries.length == 1 ? '' : 'S'}',
                                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: AppColors.mutedAt(1))),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                                              tooltip: 'Delete vendor',
                                              onPressed: () => _deleteVendor(vault),
                                            ),
                                            Icon(Icons.chevron_right, color: AppColors.mutedAt(1)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        InkWell(
                          onTap: _addVendor,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderAt(0.16)))),
                            child: Text('+   ADD A VENDOR',
                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 56),
                  Container(width: 1, color: AppColors.borderAt(0.16)),
                  const SizedBox(width: 56),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPIRING SOON — ${expiring.length}',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                        const SizedBox(height: 16),
                        Expanded(
                          child: expiring.isEmpty
                              ? Center(
                                  child: Text('No licenses with an expiration date yet.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.mutedAt(1))))
                              : ListView.builder(
                                  itemCount: expiring.length,
                                  itemBuilder: (context, index) {
                                    final (entry, vault) = expiring[index];
                                    return InkWell(
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => VendorDetailScreen(vault: vault)),
                                        );
                                        setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.12)))),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(entry.name, style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
                                                  const SizedBox(height: 3),
                                                  Text('${vault.name} · ${_dateFormat.format(entry.expiresOn!)}',
                                                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: AppColors.mutedAt(1))),
                                                ],
                                              ),
                                            ),
                                            Text(_urgencyLabel(entry.expiresOn!),
                                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, fontWeight: FontWeight.w600, color: _urgencyColor(entry.expiresOn!))),
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
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(56, 16, 56, 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderAt(0.14)))),
            child: Row(
              children: [
                Text('AES-256-GCM · ARGON2ID · LOCAL-ONLY STORAGE',
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, letterSpacing: 1.5, color: AppColors.mutedAt(0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
