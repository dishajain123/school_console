import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/registration/approval_action.dart';
import '../../data/models/registration/registration_request.dart';
import '../../data/repositories/approval_repository.dart';
import 'auth_provider.dart';

final approvalRepositoryProvider = Provider<ApprovalRepository>(
  (ref) => ApprovalRepository(ref.watch(dioClientProvider)),
);

final approvalQueueProvider = FutureProvider<List<RegistrationRequest>>((
  ref,
) async {
  return ref.watch(approvalRepositoryProvider).queue();
});

final approvalDetailProvider =
    FutureProvider.family<RegistrationRequest, String>((ref, userId) async {
      return ref.watch(approvalRepositoryProvider).detail(userId);
    });

final approvalActionProvider =
    FutureProvider.family<
      void,
      ({
        String userId,
        ApprovalActionType action,
        String? note,
        bool overrideValidation,
      })
    >((ref, args) async {
      await ref
          .watch(approvalRepositoryProvider)
          .decide(
            userId: args.userId,
            action: args.action,
            note: args.note,
            overrideValidation: args.overrideValidation,
          );
      ref.invalidate(approvalQueueProvider);
      ref.invalidate(approvalDetailProvider(args.userId));
    });
