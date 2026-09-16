import 'package:flutter/material.dart';

/// The four sections a vault's attached files are grouped into. Kept
/// deliberately small — four labeled interior sections read as a real
/// filing system; a dozen narrow categories would read as clutter.
enum FileSection {
  photos('PHOTOS', Icons.image_outlined),
  audio('AUDIO', Icons.audiotrack_outlined),
  documents('DOCUMENTS', Icons.description_outlined),
  files('FILES', Icons.insert_drive_file_outlined);

  final String label;
  final IconData sectionIcon;
  const FileSection(this.label, this.sectionIcon);
}

const _images = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', 'svg', 'tiff'};
const _audio = {'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'wma'};
const _video = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};
const _archives = {'zip', 'rar', '7z', 'tar', 'gz'};
const _spreadsheets = {'xls', 'xlsx', 'csv'};
const _docs = {'doc', 'docx', 'txt', 'md', 'rtf'};

String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
}

/// Which of the four vault sections a file belongs in, by extension.
/// Video and archives fall into FILES rather than getting their own
/// section — four sections is the whole point.
FileSection fileSection(String fileName) {
  final ext = _extensionOf(fileName);
  if (_images.contains(ext)) return FileSection.photos;
  if (_audio.contains(ext)) return FileSection.audio;
  if (ext == 'pdf' || _docs.contains(ext) || _spreadsheets.contains(ext)) return FileSection.documents;
  return FileSection.files;
}

/// Per-file icon, finer-grained than [fileSection] (e.g. a PDF and a
/// spreadsheet both live in DOCUMENTS but still get distinct icons in
/// a row listing).
IconData fileTypeIcon(String fileName) {
  final ext = _extensionOf(fileName);
  if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
  if (_images.contains(ext)) return Icons.image_outlined;
  if (_audio.contains(ext)) return Icons.audiotrack_outlined;
  if (_video.contains(ext)) return Icons.videocam_outlined;
  if (_archives.contains(ext)) return Icons.folder_zip_outlined;
  if (_spreadsheets.contains(ext)) return Icons.table_chart_outlined;
  if (_docs.contains(ext)) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}
