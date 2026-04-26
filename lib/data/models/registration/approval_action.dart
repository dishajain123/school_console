enum ApprovalActionType { approve, reject, hold }

extension ApprovalActionTypeX on ApprovalActionType {
  String get apiValue {
    switch (this) {
      case ApprovalActionType.approve:
        return 'APPROVE';
      case ApprovalActionType.reject:
        return 'REJECT';
      case ApprovalActionType.hold:
        return 'HOLD';
    }
  }
}
