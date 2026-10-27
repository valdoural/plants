import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

final _picker = ImagePicker();

/// Фото уменьшается до 1280 px: этого хватает для распознавания и экономит трафик и место.
Future<Uint8List?> pickPhoto(ImageSource source, {double maxSide = 1280}) async {
  final file = await _picker.pickImage(source: source, maxWidth: maxSide, maxHeight: maxSide, imageQuality: 82);
  return file?.readAsBytes();
}

/// Нижнее меню «Камера / Галерея».
Future<Uint8List?> pickPhotoWithSheet(BuildContext context, {double maxSide = 1280}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Сфотографировать'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  return pickPhoto(source, maxSide: maxSide);
}
