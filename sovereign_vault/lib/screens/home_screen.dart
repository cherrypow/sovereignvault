import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sovereign_core/sovereign_core.dart';
import 'package:uuid/uuid.dart';

import 'unlock_screen.dart';
import 'vault_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('MMM d');

  List<Vault> get _allVaults => VaultSession.instance.repository!.vaults;
  List<DocumentEntry> get _documents => VaultSession.instance.repository!.documents;

  final _searchController = TextEditingController();
  String _query = '';

  List<Vault> get _vaults {
    if (_query.isEmpty) return _allVaults;
    final q = _query.toLowerCase();
    return _allVaults.where((v) => v.name.toLowerCase().contains(q) || v.category.toLowerCase().contains(q)).toList();
  }

  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_updateOnlineStatus);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_updateOnlineStatus);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateOnlineStatus(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (mounted) setState(() => _isOnline = online);
  }

  Future<void> _createVault() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('CREATE VAULT', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(labelText: 'Vault name', labelStyle: TextStyle(color: AppColors.mutedAt(1))),
            ),
            TextField(
              controller: categoryController,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: AppColors.mutedAt(1))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (result == true && nameController.text.trim().isNotEmpty) {
      setState(() {
        _allVaults.add(Vault(
          id: _uuid.v4(),
          name: nameController.text.trim(),
          category: categoryController.text.trim().isEmpty ? 'Uncategorized' : categoryController.text.trim(),
        ));
      });
      await VaultSession.instance.repository!.save();
    }
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final id = _uuid.v4();
    await VaultSession.instance.repository!.storeDocumentBytes(id, bytes);
    setState(() {
      _documents.add(DocumentEntry(
        id: id,
        originalName: file.name,
        sizeBytes: bytes.length,
        addedDate: DateTime.now(),
      ));
    });
    await VaultSession.instance.repository!.save();
    if (!mounted) return;

    final originalPath = file.path;
    if (originalPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied and encrypted into the vault.'), duration: Duration(seconds: 3)),
      );
      return;
    }
    final deleteOriginal = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('COPIED AND ENCRYPTED', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Text(
          'This document now lives encrypted inside the vault. Delete the original '
          'plaintext copy from your desktop now?\n\n$originalPath',
          style: const TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Original')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete Original')),
        ],
      ),
    );
    if (deleteOriginal == true) {
      try {
        await File(originalPath).delete();
      } catch (_) {
        // Best-effort — if it's locked or already gone, there's
        // nothing more useful to do than leave it.
      }
    }
  }

  Future<void> _downloadDocument(DocumentEntry d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('DOWNLOAD DOCUMENT', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Text('Would you like to download "${d.originalName}"? It will be decrypted and saved to a location you choose.',
            style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Download')),
        ],
      ),
    );
    if (confirmed != true) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save decrypted file',
      fileName: d.originalName,
    );
    if (savePath == null) return;

    final bytes = await VaultSession.instance.repository!.readDocumentBytes(d.id);
    await File(savePath).writeAsBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $savePath'), duration: const Duration(seconds: 4)),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int get _totalStorageBytes {
    var total = _documents.fold<int>(0, (sum, d) => sum + d.sizeBytes);
    for (final vault in _allVaults) {
      total += vault.documents.fold<int>(0, (sum, d) => sum + d.sizeBytes);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // HEADER
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
                      Text('SOVEREIGN VAULT',
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 3, color: AppColors.mutedAt(1))),
                      const SizedBox(height: 8),
                      Text('Dual-custody encryption · Sovereign Key Protocol',
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderAt(0.2)),
                    color: AppColors.card.withValues(alpha: 0.04),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('SYSTEM CAPACITY',
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 8.5, letterSpacing: 1.5, color: AppColors.mutedAt(0.9))),
                      const SizedBox(height: 4),
                      Text(_formatSize(_totalStorageBytes).toUpperCase(),
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.card)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(_isOnline ? Icons.wifi : Icons.wifi_off, size: 13, color: AppColors.mutedAt(1)),
                        const SizedBox(width: 6),
                        Text(_isOnline ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9.5, letterSpacing: 1.2, color: AppColors.mutedAt(1))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
              ],
            ),
          ),
          // MAIN
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 26, 56, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HOLDINGS — ${_allVaults.length} VAULTS',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          style: const TextStyle(color: AppColors.text, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search vaults…',
                            hintStyle: TextStyle(color: AppColors.mutedAt(0.7)),
                            prefixIcon: Icon(Icons.search, size: 16, color: AppColors.mutedAt(1)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.5))),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _vaults.isEmpty
                              ? Center(
                                  child: Text(
                                      _query.isEmpty ? 'No vaults yet — create one to store credentials.' : 'No vaults match "$_query".',
                                      style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.mutedAt(1))),
                                )
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 150,
                                    childAspectRatio: 0.72,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                                  itemCount: _vaults.length,
                                  itemBuilder: (context, index) => _vaultCard(_vaults[index]),
                                ),
                        ),
                        InkWell(
                          onTap: _createVault,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderAt(0.16)))),
                            child: Text('+   ADD A NEW VAULT',
                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 56),
                  Container(width: 1.5, color: AppColors.borderAt(0.22)),
                  const SizedBox(width: 56),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DOCUMENTS — ${_documents.length} FILES',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _documents.isEmpty
                              ? Center(child: Text('No documents yet.', style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.mutedAt(1))))
                              : ListView.builder(
                                  itemCount: _documents.length,
                                  itemBuilder: (context, index) {
                                    final d = _documents[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.12)))),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _downloadDocument(d),
                                              child: Row(
                                                children: [
                                                  Icon(fileTypeIcon(d.originalName), size: 18, color: AppColors.mutedAt(1)),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(d.originalName, style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
                                                        const SizedBox(height: 3),
                                                        Text('${_formatSize(d.sizeBytes)} · ${_dateFormat.format(d.addedDate)}',
                                                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: AppColors.mutedAt(1))),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                                            tooltip: 'Delete document',
                                            onPressed: () => _deleteDocument(d),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        InkWell(
                          onTap: _uploadDocument,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderAt(0.16)))),
                            child: Text('+   ADD A DOCUMENT',
                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // FOOTER
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

  Future<void> _deleteVault(Vault vault) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('DELETE VAULT', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Text('Delete "${vault.name}" and all ${vault.entries.length} entries in it? This cannot be undone.',
            style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _allVaults.removeWhere((v) => v.id == vault.id));
      await VaultSession.instance.repository!.save();
    }
  }

  Future<void> _deleteDocument(DocumentEntry d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('DELETE DOCUMENT', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Text('Delete "${d.originalName}" from the vault? This cannot be undone.',
            style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await VaultSession.instance.repository!.deleteDocumentFile(d.id);
      setState(() => _documents.removeWhere((doc) => doc.id == d.id));
      await VaultSession.instance.repository!.save();
    }
  }

  Widget _vaultCard(Vault vault) {
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VaultDetailScreen(vault: vault)),
        );
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderAt(0.22)),
          color: AppColors.card.withValues(alpha: 0.045),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(vault.category.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 8.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                ),
                InkWell(
                  onTap: () => _deleteVault(vault),
                  child: Icon(Icons.delete_outline, size: 14, color: AppColors.mutedAt(0.8)),
                ),
              ],
            ),
            const Spacer(),
            Text(vault.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppFonts.serif, fontSize: 17, fontWeight: FontWeight.w600, height: 1.15, color: AppColors.card)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('${vault.entries.length} ENTRIES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: AppColors.mutedAt(1))),
                ),
                Icon(Icons.chevron_right, size: 14, color: AppColors.mutedAt(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
