/// Tiny in-process cache with TTL for short-lived list responses.
/// Avoids repeated network work when navigating back to a screen quickly.
class TimedMemoryCache {
  TimedMemoryCache._();

  static final Map<String, _Entry> _store = {};

  static T? getIfFresh<T>(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return e.value as T;
  }

  static void put<T>(String key, T value, Duration ttl) {
    _store[key] = _Entry(value, DateTime.now().add(ttl));
  }

  static void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }
}

class _Entry {
  _Entry(this.value, this.expiresAt);
  final Object? value;
  final DateTime expiresAt;
}
