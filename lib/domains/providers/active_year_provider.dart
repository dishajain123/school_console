import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveAcademicYearNotifier extends StateNotifier<String?> {
  ActiveAcademicYearNotifier() : super(null);

  void setYear(String? yearId) => state = yearId;
  void clear() => state = null;
}

final activeAcademicYearProvider =
    StateNotifierProvider<ActiveAcademicYearNotifier, String?>(
  (ref) => ActiveAcademicYearNotifier(),
);

