/// FILE: lib/services/pdf_picker.dart
/// PURPOSE: Lets the user choose a PDF from the phone. Everything that depends on the
///          file_picker package is in THIS file only.
///
/// This file is written for file_picker 8.x (pubspec: file_picker: ^8.0.6), which uses
/// `FilePicker.platform.pickFiles(...)`. Newer major versions changed this API, so keep 8.x.
import 'package:file_picker/file_picker.dart';

class PickedPdf {
  PickedPdf({required this.path, required this.name, required this.sizeBytes});

  final String path;
  final String name;
  final int sizeBytes;
}

class PdfPickException implements Exception {
  PdfPickException(this.message);

  final String message;
}

/// Returns null if the user cancelled. Throws PdfPickException if the file cannot be used.
Future<PickedPdf?> pickPdf() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: false, // we upload straight from the file path, no need to load it into memory
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final path = file.path;
  if (path == null) {
    throw PdfPickException('Could not open this file. Copy it to your phone storage and try again.');
  }
  return PickedPdf(path: path, name: file.name, sizeBytes: file.size);
}
