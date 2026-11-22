/// Pembantu pembuatan dan validasi slug URL bersih (huruf kecil, alfanumerik, strip tunggal).
abstract final class SlugHelper {
  static String slugify(String input) {
    final String normalized = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'[\s_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized;
  }

  /// Validator untuk field form agar slug tidak kosong setelah dinormalisasi.
  static String? validate(String? input, {String fieldLabel = 'Slug'}) {
    if (slugify(input ?? '').isEmpty) {
      return '$fieldLabel harus mengandung minimal satu huruf atau angka.';
    }
    return null;
  }

  /// Mengembalikan slug ternormalisasi atau melempar [FormatException] jika kosong.
  static String requireValidSlug(String input, {String fieldLabel = 'Slug'}) {
    final String normalized = slugify(input);
    if (normalized.isEmpty) {
      throw FormatException(
        '$fieldLabel harus mengandung minimal satu huruf atau angka.',
      );
    }
    return normalized;
  }
}
