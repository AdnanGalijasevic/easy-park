import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class PhotoPicker extends StatefulWidget {
  final List<int>? initialPhoto;
  final void Function(List<int>?) onPhotoSelected;
  final bool enabled;

  const PhotoPicker({
    super.key,
    this.initialPhoto,
    required this.onPhotoSelected,
    this.enabled = true,
  });

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  static const int _maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  Uint8List? _imageData;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoto != null) {
      _imageData = Uint8List.fromList(widget.initialPhoto!);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      try {
        final originalBytes = result.files.single.bytes!;
        final processedBytes = _ensureMaxSize(originalBytes);

        if (processedBytes == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to compress image to 5 MB. Please choose a smaller image.',
              ),
            ),
          );
          return;
        }

        setState(() {
          _imageData = processedBytes;
        });

        widget.onPhotoSelected(processedBytes);
      } catch (e) {
        debugPrint('Error processing image: $e');
      }
    }
  }

  Uint8List? _ensureMaxSize(Uint8List originalBytes) {
    if (originalBytes.lengthInBytes <= _maxImageSizeBytes) {
      return originalBytes;
    }

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      return null;
    }

    img.Image working = decoded;
    for (int step = 0; step < 8; step++) {
      final quality = 90 - (step * 10);
      final encoded = Uint8List.fromList(
        img.encodeJpg(working, quality: quality.clamp(20, 90)),
      );

      if (encoded.lengthInBytes <= _maxImageSizeBytes) {
        return encoded;
      }

      final nextWidth = (working.width * 0.85).round();
      final nextHeight = (working.height * 0.85).round();
      if (nextWidth < 320 || nextHeight < 320) {
        break;
      }

      working = img.copyResize(
        working,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 400,
      child: Column(
        children: [
          Container(
            width: 280,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: widget.enabled ? EasyParkColors.overlaySubtle : EasyParkColors.muted,
              border: Border.all(color: EasyParkColors.borderLight),
            ),
            child: _imageData != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _imageData!,
                      fit: BoxFit.cover,
                      width: 280,
                      height: 300,
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo, size: 48, color: EasyParkColors.muted),
                        SizedBox(height: 8),
                        Text(
                          'No image selected',
                          style: TextStyle(color: EasyParkColors.muted),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          widget.enabled
              ? ElevatedButton.icon(
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: EasyParkColors.onInverseSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(100, 36),
                  ),
                  icon: _imageData == null
                      ? const Icon(Icons.add)
                      : const Icon(Icons.edit),
                  label: _imageData == null
                      ? const Text('Add photo')
                      : const Text('Edit photo'),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
