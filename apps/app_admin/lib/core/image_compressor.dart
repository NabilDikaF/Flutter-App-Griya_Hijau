import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:shared/shared.dart';

/// Mengubah ukuran dan mengompres foto properti ke JPEG (maks 1600px dan < 1 MB).
abstract final class ImageCompressor {
  static const int maxInputBytes = 25 * 1024 * 1024;
  static const int maxInputDimensionPx = 10000;
  static const int maxInputPixels = 50000000;

  /// Menjalankan [compressToJpeg] di isolate terpisah agar UI thread tidak macet.
  static Future<Uint8List> compressToJpegAsync(
    Uint8List rawBytes, {
    int maxDimensionPx = maxInputDimensionPx,
    int maxPixels = maxInputPixels,
  }) {
    return Isolate.run(
      () => compressToJpeg(
        rawBytes,
        maxDimensionPx: maxDimensionPx,
        maxPixels: maxPixels,
      ),
    );
  }

  static void _validateDimensions(
    int width,
    int height, {
    required int maxDimensionPx,
    required int maxPixels,
  }) {
    if (width <= 0 || height <= 0) {
      throw const FormatException('Dimensi gambar tidak valid.');
    }
    if (width > maxDimensionPx ||
        height > maxDimensionPx ||
        width * height > maxPixels) {
      throw FormatException(
        'Dimensi gambar terlalu besar (${width}x$height px). Maksimal ${maxDimensionPx}px per sisi atau ${(maxPixels / 1000000).round()} MP.',
      );
    }
  }

  /// Membaca dimensi header PNG/JPEG sebelum dekode piksel penuh untuk mencegah lonjakan memori.
  static (int, int)? _tryReadHeaderDimensions(Uint8List bytes) {
    // PNG: 8-byte signature + length(4) + "IHDR"(4) + width(4) + height(4)
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[12] == 0x49 &&
        bytes[13] == 0x48 &&
        bytes[14] == 0x44 &&
        bytes[15] == 0x52) {
      final ByteData data = ByteData.sublistView(bytes);
      return (data.getUint32(16, Endian.big), data.getUint32(20, Endian.big));
    }

    // JPEG: SOI (0xFF 0xD8), pindai marker SOF untuk membaca tinggi/lebar frame.
    if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      final ByteData data = ByteData.sublistView(bytes);
      int offset = 2;
      while (offset + 3 < bytes.length) {
        if (bytes[offset] != 0xFF) {
          offset++;
          continue;
        }
        while (offset < bytes.length && bytes[offset] == 0xFF) {
          offset++;
        }
        if (offset >= bytes.length) break;
        final int marker = bytes[offset];
        offset++;

        if (marker == 0xD9 || marker == 0xDA) break; // EOI atau SOS
        if (marker == 0x00 ||
            marker == 0x01 ||
            (marker >= 0xD0 && marker <= 0xD7)) {
          continue;
        }
        if (offset + 2 > bytes.length) break;
        final int segLen = data.getUint16(offset, Endian.big);
        if (segLen < 2 || offset + segLen > bytes.length) break;

        final bool isSof = (marker >= 0xC0 && marker <= 0xC3) ||
            (marker >= 0xC5 && marker <= 0xC7) ||
            (marker >= 0xC9 && marker <= 0xCB) ||
            (marker >= 0xCD && marker <= 0xCF);
        if (isSof && segLen >= 7 && offset + 7 <= bytes.length) {
          final int height = data.getUint16(offset + 3, Endian.big);
          final int width = data.getUint16(offset + 5, Endian.big);
          return (width, height);
        }
        offset += segLen;
      }
    }

    return null;
  }

  static Uint8List compressToJpeg(
    Uint8List rawBytes, {
    int maxDimensionPx = maxInputDimensionPx,
    int maxPixels = maxInputPixels,
  }) {
    if (rawBytes.isEmpty) {
      throw const FormatException('File gambar kosong atau tidak dapat dibaca.');
    }
    if (rawBytes.lengthInBytes > maxInputBytes) {
      throw const FormatException(
        'Ukuran file foto mentah terlalu besar (maksimal 25 MB).',
      );
    }

    final (int, int)? headerDims = _tryReadHeaderDimensions(rawBytes);
    if (headerDims != null) {
      _validateDimensions(
        headerDims.$1,
        headerDims.$2,
        maxDimensionPx: maxDimensionPx,
        maxPixels: maxPixels,
      );
    }

    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw const FormatException(
        'File gambar tidak dapat dibaca. Pilih foto JPG atau PNG yang valid.',
      );
    }
    _validateDimensions(
      decoded.width,
      decoded.height,
      maxDimensionPx: maxDimensionPx,
      maxPixels: maxPixels,
    );

    img.Image working = decoded;
    if (working.width > CompanyConfig.maxImageWidthPx ||
        working.height > CompanyConfig.maxImageWidthPx) {
      working = working.width >= working.height
          ? img.copyResize(working, width: CompanyConfig.maxImageWidthPx)
          : img.copyResize(working, height: CompanyConfig.maxImageWidthPx);
    }

    const List<int> qualitySteps = <int>[85, 72, 60, 48, 35];
    for (final int quality in qualitySteps) {
      final Uint8List encoded = Uint8List.fromList(
        img.encodeJpg(working, quality: quality),
      );
      if (encoded.lengthInBytes <= CompanyConfig.maxImageBytes) {
        return encoded;
      }
    }

    for (final int fallbackMaxSide in <int>[1200, 800]) {
      if (working.width > fallbackMaxSide || working.height > fallbackMaxSide) {
        working = working.width >= working.height
            ? img.copyResize(working, width: fallbackMaxSide)
            : img.copyResize(working, height: fallbackMaxSide);
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
