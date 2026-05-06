class FeeInstallmentDue {
  const FeeInstallmentDue({
    required this.installmentName,
    required this.dueDate,
    required this.outstandingAmount,
  });

  final String installmentName;
  final String? dueDate;
  final double outstandingAmount;

  bool get hasOutstanding => outstandingAmount > 0.01;
}

class FeePaymentCalculator {
  static double suggestedAmountForCycle({
    required String cycle,
    required double totalOutstanding,
    required List<FeeInstallmentDue> installments,
  }) {
    final outstandingInstallments = installments.where((i) => i.hasOutstanding).toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.dueDate ?? '') ?? DateTime(2100);
        final bd = DateTime.tryParse(b.dueDate ?? '') ?? DateTime(2100);
        return ad.compareTo(bd);
      });

    if (totalOutstanding <= 0.01) return 0;

    final hasMonthlyNames = outstandingInstallments.any(
      (i) => i.installmentName.toLowerCase().contains('month'),
    );
    final hasQuarterNames = outstandingInstallments.any(
      (i) => i.installmentName.toLowerCase().contains('quarter'),
    );

    if (cycle == 'MONTHLY') {
      if (hasMonthlyNames && outstandingInstallments.isNotEmpty) {
        return outstandingInstallments.first.outstandingAmount.clamp(0.0, totalOutstanding);
      }
      if (hasQuarterNames && outstandingInstallments.isNotEmpty) {
        return (outstandingInstallments.first.outstandingAmount / 3).clamp(0.0, totalOutstanding);
      }
      return (totalOutstanding / 12).clamp(0.0, totalOutstanding);
    }

    if (cycle == 'QUARTERLY') {
      if (hasMonthlyNames) {
        final chunk = outstandingInstallments.take(3).fold<double>(
          0.0,
          (sum, i) => sum + i.outstandingAmount,
        );
        return chunk.clamp(0.0, totalOutstanding);
      }
      if (hasQuarterNames && outstandingInstallments.isNotEmpty) {
        return outstandingInstallments.first.outstandingAmount.clamp(0.0, totalOutstanding);
      }
      return (totalOutstanding / 4).clamp(0.0, totalOutstanding);
    }

    return totalOutstanding;
  }

  static List<FeeInstallmentDue> nextInstallmentsForCycle({
    required String cycle,
    required List<FeeInstallmentDue> installments,
  }) {
    final outstandingInstallments = installments.where((i) => i.hasOutstanding).toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.dueDate ?? '') ?? DateTime(2100);
        final bd = DateTime.tryParse(b.dueDate ?? '') ?? DateTime(2100);
        return ad.compareTo(bd);
      });
    if (outstandingInstallments.isEmpty) return const [];
    if (cycle == 'MONTHLY') return [outstandingInstallments.first];
    if (cycle == 'QUARTERLY') {
      final hasMonthlyNames = outstandingInstallments.any(
        (i) => i.installmentName.toLowerCase().contains('month'),
      );
      return hasMonthlyNames
          ? outstandingInstallments.take(3).toList()
          : [outstandingInstallments.first];
    }
    return outstandingInstallments;
  }
}
