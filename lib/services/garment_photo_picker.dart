import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'garment_camera_stub.dart'
    if (dart.library.html) 'garment_camera_web.dart' as camera;

/// Camera uses a live preview on web; gallery uses the platform photo picker.
Future<XFile?> pickGarmentPhoto(BuildContext context, ImageSource source,
    ImagePicker picker, {int quality = 92}) async {
  if (source == ImageSource.camera) return camera.captureGarment(context, picker);
  return picker.pickImage(source: ImageSource.gallery, imageQuality: quality);
}
