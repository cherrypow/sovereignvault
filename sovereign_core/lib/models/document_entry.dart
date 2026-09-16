class DocumentEntry {
  final String id;
  final String originalName;
  final int sizeBytes;
  final DateTime addedDate;

  DocumentEntry({
    required this.id,
    required this.originalName,
    required this.sizeBytes,
    required this.addedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalName': originalName,
        'sizeBytes': sizeBytes,
        'addedDate': addedDate.toIso8601String(),
      };

  factory DocumentEntry.fromJson(Map<String, dynamic> json) => DocumentEntry(
        id: json['id'] as String,
        originalName: json['originalName'] as String,
        sizeBytes: json['sizeBytes'] as int,
        addedDate: DateTime.parse(json['addedDate'] as String),
      );
}
