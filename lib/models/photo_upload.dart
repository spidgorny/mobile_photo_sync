import 'dart:io';

class PhotoUpload {
  PhotoUpload({
    required this.file,
    required this.filename,
    required this.takenAt,
    required this.size,
    required this.mimeType,
    required this.assetId,
  });

  final File file;
  final String filename;
  final DateTime takenAt;
  final int size;
  final String mimeType;
  final String assetId;

  String uploadKey(String folder) => '${folder.replaceAll(RegExp(r'/+$'), '')}/$filename';
}
