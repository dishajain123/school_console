// lib/core/rbac/admin_route_access.dart  [Admin Console]
import '../../data/models/auth/admin_user.dart';
import '../constants/route_constants.dart';

String normalizeRouterPath(String raw) {
  if (raw.isEmpty) return '/';
  if (raw.length > 1 && raw.endsWith('/')) {
    return raw.substring(0, raw.length - 1);
  }
  return raw;
}

/// Staff-admin web console: allow any navigated path once authenticated.
/// New [GoRouter] routes do not need listing here — access is not gated by path allowlists.
bool routeAccessAllowedForUser(AdminUser user, String normalizedPath) {
  if (normalizedPath == RouteNames.dashboard ||
      normalizedPath == RouteNames.accessDenied) {
    return true;
  }
  return user.role.toUpperCase() == 'STAFF_ADMIN';
}
