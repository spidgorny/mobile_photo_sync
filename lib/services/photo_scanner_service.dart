import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_upload.dart';

class PhotoScannerService {
  Future<List<PhotoUpload>> findCameraPhotos({required DateTime start, required DateTime end}) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      await PhotoManager.openSetting();
      throw StateError('Photo permission is required.');
    }

    final filter = FilterOptionGroup(
      imageOption: const FilterOption(sizeConstraint: SizeConstraint(ignoreSize: true)),
      createTimeCond: DateTimeCond(min: start, max: end.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1))),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: true)],
    );

    final paths = await PhotoManager.getAssetPathList(type: RequestType.image, filterOption: filter);
    final cameraPaths = paths.where((path) => path.name.toLowerCase().contains('camera')).toList();
    final searchPaths = cameraPaths.isNotEmpty ? cameraPaths : paths;

    final result = <PhotoUpload>[];
    for (final path in searchPaths) {
      final count = await path.assetCountAsync;
      var page = 0;
      const pageSize = 200;
      while (page * pageSize < count) {
        final assets = await path.getAssetListPaged(page: page, size: pageSize);
        for (final asset in assets) {
          final file = await asset.originFile;
          if (file == null) continue;
          if (!_isCameraFile(file)) continue;
          final stat = await file.stat();
          final filename = p.basename(file.path);
          final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
          result.add(PhotoUpload(
            file: file,
            filename: filename,
            takenAt: asset.createDateTime,
            size: stat.size,
            mimeType: mimeType,
            assetId: asset.id,
          ));
        }
        page++;
      }
    }

    final unique = <String, PhotoUpload>{};
    for (final photo in result) {
      unique[photo.file.path] = photo;
    }
    final photos = unique.values.toList()..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return photos;
  }

  bool _isCameraFile(File file) {
    final normalized = file.path.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/dcim/camera/') || normalized.contains('/dcim/100') || normalized.contains('/camera/');
  }
}
