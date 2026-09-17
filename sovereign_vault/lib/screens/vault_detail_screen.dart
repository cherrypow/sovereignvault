import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sovereign_core/sovereign_core.dart';
import 'package:uuid/uuid.dart';

class VaultDetailScreen extends StatefulWidget {
  final Vault vault;
  const VaultDetailScreen({super.key, required this.vault});

  @override
  State<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends State<VaultDetailScreen> {
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('MMM d');
  final Set<String> _revealed = {};

  bool _isAddingEntry = false;
  bool _newEntrySensitive = true;
  final _newNameController = TextEditingController();
  final _newValueController = TextEditingController();
  late final TextEditingController _notesController;

  final _entrySearchController = TextEditingController();
  final _documentSearchController = TextEditingController();
  String _entryQuery = '';
  String _documentQuery = '';

  List<VaultEntry> get _filteredEntries {
    if (_entryQuery.isEmpty) return widget.vault.entries;
    final q = _entryQuery.toLowerCase();
    return widget.vault.entries.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  List<DocumentEntry> get _filteredDocuments {
    if (_documentQuery.isEmpty) return widget.vault.documents;
    final q = _documentQuery.toLowerCase();
    return widget.vault.documents.where((d) => d.originalName.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.vault.notes);
  }

  Future<void> _renameVault() async {
    final controller = TextEditingController(text: widget.vault.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('RENAME VAULT', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(labelText: 'Vault name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() => widget.vault.name = newName.trim());
      await VaultSession.instance.repository!.save();
    }
  }

  Future<void> _renameCategory() async {
    final controller = TextEditingController(text: widget.vault.category);
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('RENAME CATEGORY', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(labelText: 'Category'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newCategory != null && newCategory.trim().isNotEmpty) {
      setState(() => widget.vault.category = newCategory.trim());
      await VaultSession.instance.repository!.save();
    }
  }

  void _startAddingEntry() => setState(() => _isAddingEntry = true);

  void _cancelAddingEntry() {
    setState(() {
      _isAddingEntry = false;
      _newEntrySensitive = true;
      _newNameController.clear();
      _newValueController.clear();
    });
  }

  /// Commits the in-progress row: this is the moment a freshly-typed,
  /// plaintext-on-screen value becomes a stored, masked entry — the
  /// "lock" action the user asked for, made explicit rather than
  /// happening invisibly behind a dialog.
  Future<void> _lockNewEntry() async {
    if (_newNameController.text.trim().isEmpty) return;
    setState(() {
      widget.vault.entries.add(VaultEntry(
        id: _uuid.v4(),
        name: _newNameController.text.trim(),
        value: _newValueController.text,
        addedDate: DateTime.now(),
        sensitive: _newEntrySensitive,
      ));
      _isAddingEntry = false;
      _newEntrySensitive = true;
      _newNameController.clear();
      _newValueController.clear();
    });
    await VaultSession.instance.repository!.save();
  }

  Future<void> _deleteEntry(VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('DELETE ENTRY', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
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

  Future<void> _deleteDocument(DocumentEntry d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('DELETE DOCUMENT', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: Text('Delete "${d.originalName}" from this vault? This cannot be undone.',
            style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await VaultSession.instance.repository!.deleteDocumentFile(d.id);
      setState(() => widget.vault.documents.removeWhere((doc) => doc.id == d.id));
      await VaultSession.instance.repository!.save();
    }
  }

  Future<void> _toggleSensitive(VaultEntry entry) async {
    setState(() {
      entry.sensitive = !entry.sensitive;
      // Re-hide it by default when it's marked sensitive again —
      // don't leave a just-restricted value sitting unmasked.
      if (entry.sensitive) _revealed.remove(entry.id);
    });
    await VaultSession.instance.repository!.save();
  }

  Future<void> _saveNotes() async {
    widget.vault.notes = _notesController.text;
    await VaultSession.instance.repository!.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes saved'), duration: Duration(seconds: 1)),
    );
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
      widget.vault.documents.add(DocumentEntry(
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

  Future<void> _exportVault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.borderAt(0.2))),
        title: const Text('EXPORT VAULT', style: TextStyle(color: AppColors.text, fontSize: 14, letterSpacing: 1.5)),
        content: const Text(
          'This will decrypt every entry and note in this vault and save them as a '
          'plain file at a location you choose. Anyone with access to that file can '
          'read these secrets without your PIN or master password. Continue?',
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Export')),
        ],
      ),
    );
    if (confirmed != true) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export vault',
      fileName: '${widget.vault.name}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (savePath == null) return;

    final data = {
      'vault': widget.vault.name,
      'category': widget.vault.category,
      'notes': widget.vault.notes,
      'entries': widget.vault.entries
          .map((e) => {'name': e.name, 'value': e.value, 'sensitive': e.sensitive, 'addedDate': e.addedDate.toIso8601String()})
          .toList(),
    };
    await File(savePath).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported to $savePath'), duration: const Duration(seconds: 4)),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<FileSection, List<DocumentEntry>> _sectioned(List<DocumentEntry> documents) {
    final map = <FileSection, List<DocumentEntry>>{};
    for (final section in FileSection.values) {
      map[section] = [];
    }
    for (final d in documents) {
      map[fileSection(d.originalName)]!.add(d);
    }
    return map;
  }

  static const _clipboardClearDelay = Duration(seconds: 30);

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied — will clear from clipboard in 30s'), duration: Duration(seconds: 2)),
    );
    Timer(_clipboardClearDelay, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  @override
  void dispose() {
    _newNameController.dispose();
    _newValueController.dispose();
    _notesController.dispose();
    _entrySearchController.dispose();
    _documentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
    final documents = _filteredDocuments;
    return Scaffold(
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(56, 32, 56, 22),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.16)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.arrow_back, size: 20, color: AppColors.mutedAt(1)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('HOLDINGS / ${widget.vault.category.toUpperCase()}',
                              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 1.5, color: AppColors.mutedAt(1))),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _renameCategory,
                            child: Icon(Icons.edit_outlined, size: 12, color: AppColors.mutedAt(0.8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(widget.vault.name,
                              style: TextStyle(fontFamily: AppFonts.serif, fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.card)),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: _renameVault,
                            child: Icon(Icons.edit_outlined, size: 16, color: AppColors.mutedAt(0.9)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _exportVault,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ios_share, size: 14, color: AppColors.mutedAt(1)),
                        const SizedBox(width: 6),
                        Text('EXPORT VAULT',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                      ],
                    ),
                  ),
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
                        Text('ENTRIES — ${entries.length}',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _entrySearchController,
                          onChanged: (v) => setState(() => _entryQuery = v),
                          style: const TextStyle(color: AppColors.text, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search entries…',
                            hintStyle: TextStyle(color: AppColors.mutedAt(0.7)),
                            prefixIcon: Icon(Icons.search, size: 16, color: AppColors.mutedAt(1)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.5))),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_isAddingEntry) _newEntryRow(),
                        Expanded(
                          child: entries.isEmpty && !_isAddingEntry
                              ? Center(
                                  child: Text(
                                      _entryQuery.isEmpty ? 'No entries yet.' : 'No entries match "$_entryQuery".',
                                      style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.mutedAt(1))))
                              : ListView.builder(
                                  itemCount: entries.length,
                                  itemBuilder: (context, index) => _row(entries[index], isLast: index == entries.length - 1 && !_isAddingEntry),
                                ),
                        ),
                        InkWell(
                          onTap: _isAddingEntry ? null : _startAddingEntry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderAt(0.16)))),
                            child: Text('+   ADD ENTRY',
                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, letterSpacing: 1, color: AppColors.mutedAt(1))),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('NOTES', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _notesController,
                          onEditingComplete: _saveNotes,
                          onTapOutside: (_) => _saveNotes(),
                          maxLines: 3,
                          style: const TextStyle(color: AppColors.text, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Extra recovery codes, related passwords, anything else worth keeping with this vault…',
                            hintStyle: TextStyle(color: AppColors.mutedAt(0.7), fontSize: 12.5),
                            filled: true,
                            fillColor: AppColors.card.withValues(alpha: 0.035),
                            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.5))),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('DOCUMENTS — ${documents.length}',
                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 2, color: AppColors.mutedAt(1))),
                            const Spacer(),
                            Text(
                              _formatSize(widget.vault.documents.fold<int>(0, (sum, d) => sum + d.sizeBytes)).toUpperCase(),
                              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.card),
                            ),
                            const SizedBox(width: 5),
                            Text('USED', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, letterSpacing: 1, color: AppColors.mutedAt(0.9))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _documentSearchController,
                          onChanged: (v) => setState(() => _documentQuery = v),
                          style: const TextStyle(color: AppColors.text, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search documents…',
                            hintStyle: TextStyle(color: AppColors.mutedAt(0.7)),
                            prefixIcon: Icon(Icons.search, size: 16, color: AppColors.mutedAt(1)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.5))),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: documents.isEmpty
                              ? Center(
                                  child: Text(
                                      _documentQuery.isEmpty ? 'No documents in this vault.' : 'No documents match "$_documentQuery".',
                                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.mutedAt(1))))
                              : Builder(builder: (context) {
                                  final grouped = _sectioned(documents);
                                  return ListView(
                                    children: [
                                      for (final section in FileSection.values)
                                        if (grouped[section]!.isNotEmpty) ...[
                                          _sectionHeader(section, grouped[section]!.length),
                                          for (final d in grouped[section]!) _documentRow(d),
                                          const SizedBox(height: 16),
                                        ],
                                    ],
                                  );
                                }),
                        ),
                        InkWell(
                          onTap: _uploadDocument,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderAt(0.16)))),
                            child: Text('+   ATTACH A FILE TO THIS VAULT',
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

  /// The inline "type it, then lock it" row: the value is shown in
  /// plain text while being entered — it only becomes masked once the
  /// lock icon commits it as a real, stored entry. The sensitivity
  /// toggle lets the user mark a field (like a Bundle ID) as safe to
  /// show in the clear, rather than always masking everything.
  Widget _newEntryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderAt(0.12)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newNameController,
                  autofocus: true,
                  style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Name',
                    hintStyle: TextStyle(color: AppColors.mutedAt(0.8)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _newValueController,
                  style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13),
                  onSubmitted: (_) => _lockNewEntry(),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Key / value — shown in the clear until locked',
                    hintStyle: TextStyle(color: AppColors.mutedAt(0.8), fontSize: 11.5),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.lock_outline, size: 16, color: AppColors.card),
                tooltip: 'Lock and save',
                onPressed: _lockNewEntry,
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: AppColors.mutedAt(1)),
                tooltip: 'Cancel',
                onPressed: _cancelAddingEntry,
              ),
            ],
          ),
          Row(
            children: [
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: _newEntrySensitive,
                  activeThumbColor: AppColors.card,
                  onChanged: (v) => setState(() => _newEntrySensitive = v),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _newEntrySensitive ? 'SENSITIVE — will be masked' : 'NOT SENSITIVE — shown in the clear',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9.5, letterSpacing: 0.5, color: AppColors.mutedAt(1)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(FileSection section, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(section.sectionIcon, size: 13, color: AppColors.card),
          const SizedBox(width: 8),
          Text(section.label,
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w600, color: AppColors.card)),
          const SizedBox(width: 6),
          Text('($count)', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9.5, color: AppColors.mutedAt(0.8))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppColors.borderAt(0.14))),
        ],
      ),
    );
  }

  Widget _documentRow(DocumentEntry d) {
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
  }

  Widget _row(VaultEntry entry, {required bool isLast}) {
    final revealed = _revealed.contains(entry.id) || !entry.sensitive;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.borderAt(0.12)))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(entry.name, style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13.5)),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: revealed
                      ? Text(entry.value,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13))
                      : ImageFiltered(
                          imageFilter: _blurFilter,
                          child: Text(entry.value,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback, color: AppColors.text, fontSize: 13)),
                        ),
                ),
                if (entry.sensitive)
                  IconButton(
                    icon: Icon(revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 15, color: AppColors.mutedAt(1)),
                    onPressed: () => setState(() {
                      revealed ? _revealed.remove(entry.id) : _revealed.add(entry.id);
                    }),
                  ),
                IconButton(
                  icon: Icon(entry.sensitive ? Icons.lock_outline : Icons.lock_open_outlined,
                      size: 15, color: AppColors.mutedAt(1)),
                  tooltip: entry.sensitive ? 'Mark as not sensitive' : 'Mark as sensitive',
                  onPressed: () => _toggleSensitive(entry),
                ),
                IconButton(
                  icon: Icon(Icons.copy_outlined, size: 15, color: AppColors.mutedAt(1)),
                  onPressed: () => _copy(entry.value),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(_dateFormat.format(entry.addedDate),
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.mutedAt(1))),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                tooltip: 'Delete entry',
                onPressed: () => _deleteEntry(entry),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _blurFilter = ImageFilter.blur(sigmaX: 4, sigmaY: 4);
