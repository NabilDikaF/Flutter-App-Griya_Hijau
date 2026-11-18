/// Status ketersediaan unit properti di database (`availability_status`).
enum AvailabilityStatus {
  available('available', 'Tersedia'),
  booked('booked', 'Dipesan'),
  sold('sold', 'Terjual');

  const AvailabilityStatus(this.value, this.label);

  final String value;
  final String label;

  static AvailabilityStatus fromValue(String value) {
    return AvailabilityStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Status ketersediaan tidak dikenal',
      ),
    );
  }
}

/// Tujuan pengajuan calon pembeli (`intent_type`).
enum IntentType {
  surveyLocation('survey_location', 'Survei Lokasi'),
  bookUnit('book_unit', 'Booking Unit');

  const IntentType(this.value, this.label);

  final String value;
  final String label;

  static IntentType fromValue(String value) {
    return IntentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Tujuan pengajuan tidak dikenal',
      ),
    );
  }
}

/// Rencana pembayaran saat memesan unit (`payment_plan`).
enum PaymentPlan {
  kpr('kpr', 'KPR'),
  cashHard('cash_hard', 'Cash Keras'),
  cashInstallment('cash_installment', 'Cash Bertahap');

  const PaymentPlan(this.value, this.label);

  final String value;
  final String label;

  static PaymentPlan fromValue(String value) {
    return PaymentPlan.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Rencana pembayaran tidak dikenal',
      ),
    );
  }
}

/// Tahap tindak lanjut booking pada aplikasi admin (`funnel_status`).
enum FunnelStatus {
  newLead('new', 'Baru'),
  contacted('contacted', 'Dihubungi'),
  surveyScheduled('survey_scheduled', 'Jadwal Survei'),
  officeVisit('office_visit', 'Kunjungan Kantor'),
  closedWon('closed_won', 'Closing'),
  closedLost('closed_lost', 'Batal');

  const FunnelStatus(this.value, this.label);

  final String value;
  final String label;

  static FunnelStatus fromValue(String value) {
    return FunnelStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Status funnel tidak dikenal',
      ),
    );
  }
}
