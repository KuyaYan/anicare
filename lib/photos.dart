import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'data.dart';
import 'ui.dart';

/// Opens the gallery, shrinks the picture (max 800 px, JPEG 80%) and uploads it
/// (Supabase Storage, or the phone itself in offline mode).
/// Returns the photo address to save, or null when nothing was picked.
Future<String?> pickPhoto(BuildContext c) async {
  try {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (x == null) return null;
    if (c.mounted) toast(c, 'Uploading photo…');
    return await app.savePhoto(await x.readAsBytes());
  } catch (_) {
    if (c.mounted) toast(c, 'Could not upload the photo. Check your connection and try again.');
    return null;
  }
}
