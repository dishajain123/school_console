/// Tiny in-process cache with TTL for short-lived list responses.
/// Avoids repeated network work when navigating back to a screen quickly.
class TimedMemoryCache {
  final Map<String, _Entry> _store = {};

  T? getIfFresh<T>(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return e.value as T;
  }

  void put<T>(String key, T value, Duration ttl) {
    _store[key] = _Entry(value, DateTime.now().add(ttl));
  }

  void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() {
    _store.clear();
  }
}

class _Entry {
  _Entry(this.value, this.expiresAt);
  final Object? value;
  final DateTime expiresAt;
}
