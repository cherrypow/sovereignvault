import 'document_entry.dart';
import 'vault_entry.dart';

class Vault {
  final String id;
  String name;
  String category;
  String notes;
  final List<VaultEntry> entries;
  final List<DocumentEntry> documents;

  Vault({
    required this.id,
    required this.name,
    required this.category,
    this.notes = '',
    List<VaultEntry>? entries,
    List<DocumentEntry>? documents,
  })  : entries = entries ?? [],
        documents = documents ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'notes': notes,
        'entries': entries.map((e) => e.toJson()).toList(),
        'documents': documents.map((d) => d.toJson()).toList(),
      };

  factory Vault.fromJson(Map<String, dynamic> json) => Vault(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        notes: json['notes'] as String? ?? '',
        entries: (json['entries'] as List)
            .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        documents: (json['documents'] as List? ?? [])
            .map((d) => DocumentEntry.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}
