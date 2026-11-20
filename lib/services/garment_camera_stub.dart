import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
Future<XFile?> captureGarment(BuildContext context, ImagePicker picker) =>
    picker.pickImage(source: ImageSource.camera, imageQuality: 92);
