import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/timed_memory_cache.dart';
import '../../data/models/role_profiles/role_profile_item.dart';
import 'repository_providers.dart';

/// Matches [RoleProfilesScreen] filters + paging when listing profiles.
class RoleProfileListQuery {
  const RoleProfileListQuery({
    required this.role,
    required this.search,
    required this.standardId,
    required this.section,
    required this.page,
    required this.pageSize,
  });

  final String role;
  final String search;
  final String? standardId;
  final String? section;
  final int page;
  final int pageSize;

  String get _cacheKey => [
        'role_profiles_v1',
        role,
        page.toString(),
        search.trim(),
        standardId ?? '',
        section ?? '',
      ].join('|');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleProfileListQuery &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          search == other.search &&
          standardId == other.standardId &&
          section == other.section &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(
        role,
        search,
        standardId,
        section,
        page,
        pageSize,
      );
}

final roleProfileListProvider = FutureProvider.autoDispose
    .family<RoleProfileListData, RoleProfileListQuery>((ref, q) async {
  final cached =
      TimedMemoryCache.getIfFresh<RoleProfileListData>(q._cacheKey);
  if (cached != null) return cached;

  final repository = ref.watch(roleProfileRepositoryProvider);
  final data = await repository.listProfiles(
    role: q.role,
    search: q.search.trim().isEmpty ? null : q.search.trim(),
    academicYearId: null,
    standardId: q.standardId,
    section: q.section,
    page: q.page,
    pageSize: q.pageSize,
  );
  TimedMemoryCache.put(q._cacheKey, data, const Duration(seconds: 25));
  return data;
});
