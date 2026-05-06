class FeeStructureItem {
  const FeeStructureItem({
    required this.id,
    required this.feeCategory,
    required this.customFeeHead,
    required this.amount,
    required this.dueDate,
    this.standardName,
    this.description,
    this.installmentPlan,
  });

  final String id;
  final String feeCategory;
  final String customFeeHead;
  final double amount;
  final String dueDate;
  final String? standardName;
  final String? description;
  final List<dynamic>? installmentPlan;

  factory FeeStructureItem.fromJson(Map<String, dynamic> json) =>
      FeeStructureItem(
        id: json['id'].toString(),
        feeCategory: json['fee_category']?.toString() ?? '',
        customFeeHead: json['custom_fee_head']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        dueDate: json['due_date']?.toString() ?? '',
        standardName: json['standard']?['name'] as String?,
        description: json['description'] as String?,
        installmentPlan: json['installment_plan'] as List<dynamic>?,
      );

  String get displayLabel =>
      customFeeHead.trim().isNotEmpty ? customFeeHead : feeCategory;
}
