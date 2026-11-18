import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:shared/shared.dart';

/// Mengubah ukuran dan mengompres foto properti ke JPEG (maks 1600px dan < 1 MB).
abstract final class ImageCompressor {
  static Uint8List compressToJpeg(Uint8List rawBytes) {
    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw const FormatException(
        'File gambar tidak dapat dibaca. Pilih foto JPG atau PNG yang valid.',
      );
    }

    img.Image working = decoded.width > CompanyConfig.maxImageWidthPx
        ? img.copyResize(decoded, width: CompanyConfig.maxImageWidthPx)
        : decoded;

    const List<int> qualitySteps = <int>[85, 72, 60, 48, 35];
    for (final int quality in qualitySteps) {
      final Uint8List encoded = Uint8List.fromList(
        img.encodeJpg(working, quality: quality),
      );
      if (encoded.lengthInBytes <= CompanyConfig.maxImageBytes) {
        return encoded;
      }
    }

    for (final int fallbackWidth in <int>[1200, 800]) {
      if (working.width > fallbackWidth) {
        working = img.copyResize(working, width: fallbackWidth);
      }
      final Uint8List encoded = Uint8List.fromList(
        img.encodeJpg(working, quality: 55),
      );
      if (encoded.lengthInBytes <= CompanyConfig.maxImageBytes) {
        return encoded;
      }
    }

    throw const FormatException(
      'Ukuran foto masih melebihi batas 1 MB setelah dikompresi. Pilih gambar lain.',
    );
  }
}
