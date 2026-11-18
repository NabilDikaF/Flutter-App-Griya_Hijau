/// Pembantu pembuatan slug URL bersih (huruf kecil, alfanumerik, strip tunggal).
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
}
