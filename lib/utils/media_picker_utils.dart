import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
enum PickedMediaType { image, video }

class MediaPickerUtils {
  static final ImagePicker _picker = ImagePicker();

  static Future<({File file, PickedMediaType type})?> pickFromGallery(
    BuildContext context,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1D1F24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: const Text('Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Video', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'photo') {
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x != null) {
        return (file: File(x.path), type: PickedMediaType.image);
      }
    } else if (choice == 'video') {
      final x = await _picker.pickVideo(source: ImageSource.gallery);
      if (x != null) {
        return (file: File(x.path), type: PickedMediaType.video);
      }
    }
    return null;
  }
}
