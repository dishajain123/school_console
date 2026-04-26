class IdentifierConfigItem {
  IdentifierConfigItem({
    required this.identifierType,
    required this.formatTemplate,
    required this.sequencePadding,
    required this.resetYearly,
    required this.isLocked,
    this.prefix,
    this.previewNext,
    this.warning,
  });

  final String identifierType;
  final String formatTemplate;
  final int sequencePadding;
  final bool resetYearly;
  final bool isLocked;
  final String? prefix;
  final String? previewNext;
  final String? warning;

  factory IdentifierConfigItem.fromJson(Map<String, dynamic> json) {
    return IdentifierConfigItem(
      identifierType: (json['identifier_type'] ?? '').toString(),
      formatTemplate: (json['format_template'] ?? '').toString(),
      sequencePadding: (json['sequence_padding'] as num?)?.toInt() ?? 4,
      resetYearly: (json['reset_yearly'] as bool?) ?? true,
      isLocked: (json['is_locked'] as bool?) ?? false,
      prefix: json['prefix'] as String?,
      previewNext: json['preview_next'] as String?,
      warning: json['warning'] as String?,
    );
  }
}
