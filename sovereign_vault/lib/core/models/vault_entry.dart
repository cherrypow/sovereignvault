/// A single named secret within a [Vault] — a credential, a note, or
/// (via [type] and the two optional dates) a trackable item like a
/// software license. The base Sovereign Vault app never sets [type],
/// [purchaseDate], or [expiresOn]; a sibling app (e.g. Sovereign Vault
/// X) built on this same engine uses them to add expiration-aware
/// views on top of the same encrypted entries, without a separate
/// data model or a separate vault.
class VaultEntry {
  final String id;
  String name;
  String value;
  bool sensitive;
  final DateTime addedDate;
  String type;
  DateTime? purchaseDate;
  DateTime? expiresOn;

  VaultEntry({
    required this.id,
    required this.name,
    required this.value,
    required this.addedDate,
    this.sensitive = true,
    this.type = 'credential',
    this.purchaseDate,
    this.expiresOn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'sensitive': sensitive,
        'addedDate': addedDate.toIso8601String(),
        'type': type,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'expiresOn': expiresOn?.toIso8601String(),
      };

  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        value: json['value'] as String,
        sensitive: json['sensitive'] as bool? ?? true,
        addedDate: DateTime.parse(json['addedDate'] as String),
        type: json['type'] as String? ?? 'credential',
        purchaseDate: json['purchaseDate'] == null ? null : DateTime.parse(json['purchaseDate'] as String),
        expiresOn: json['expiresOn'] == null ? null : DateTime.parse(json['expiresOn'] as String),
      );
}
