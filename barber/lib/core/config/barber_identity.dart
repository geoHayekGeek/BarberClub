/// The public site and reservation system use these published short names for
/// the same barbers. Match only known aliases, never arbitrary name prefixes.
class BarberIdentity {
  BarberIdentity._();

  static String _key(String name) {
    final normalized = name.trim().toLowerCase();
    return const {
          'ju': 'julien',
          'alex': 'alexandre',
          'clem': 'clement',
          'clém': 'clement',
          'clément': 'clement',
        }[normalized] ??
        normalized;
  }

  static bool matches(String first, String second) =>
      first.trim().isNotEmpty && _key(first) == _key(second);
}
