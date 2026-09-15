import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_hospital_flutter/core/media/gallery_media_picker.dart';

class ImagePickerGalleryMediaGateway implements GalleryMediaPickerGateway {
  ImagePickerGalleryMediaGateway(this.imagePicker);

  final ImagePicker imagePicker;

  @override
  Future<bool> hasPermission(GalleryMediaPickerOptions options) async => true;

  @override
  Future<List<XFile>> pick(
    BuildContext context,
    GalleryMediaPickerOptions options,
  ) async {
    return switch ((options.mediaType, options.allowMultiple)) {
      (GalleryMediaType.image, false) => <XFile>[
        ?await imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: options.maxWidth,
          maxHeight: options.maxHeight,
          imageQuality: options.imageQuality,
        ),
      ],
      (GalleryMediaType.image, true) => imagePicker.pickMultiImage(
        maxWidth: options.maxWidth,
        maxHeight: options.maxHeight,
        imageQuality: options.imageQuality,
        limit: options.maxCount,
      ),
      (GalleryMediaType.video, false) => <XFile>[
        ?await imagePicker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: options.maxVideoDuration,
        ),
      ],
      (GalleryMediaType.video, true) => imagePicker.pickMultiVideo(
        maxDuration: options.maxVideoDuration,
        limit: options.maxCount,
      ),
      (GalleryMediaType.imageAndVideo, false) => <XFile>[
        ?await imagePicker.pickMedia(
          maxWidth: options.maxWidth,
          maxHeight: options.maxHeight,
          imageQuality: options.imageQuality,
        ),
      ],
      (GalleryMediaType.imageAndVideo, true) => imagePicker.pickMultipleMedia(
        maxWidth: options.maxWidth,
        maxHeight: options.maxHeight,
        imageQuality: options.imageQuality,
        limit: options.maxCount,
      ),
    };
  }
}
