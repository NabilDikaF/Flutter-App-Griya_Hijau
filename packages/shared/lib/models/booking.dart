import 'enums.dart';

/// Model booking / survei lokasi (`bookings`, dibaca & diubah oleh Admin).
class Booking {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.propertyId,
    required this.customerName,
    required this.customerWhatsapp,
    required this.intentType,
    this.preferredSurveyDate,
    this.confirmedSurveyDate,
    this.paymentPlan,
    this.customerNotes,
    required this.funnelStatus,
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String bookingCode;
  final int propertyId;
  final String customerName;
  final String customerWhatsapp;
  final IntentType intentType;
  final DateTime? preferredSurveyDate;
  final DateTime? confirmedSurveyDate;
  final PaymentPlan? paymentPlan;
  final String? customerNotes;
  final FunnelStatus funnelStatus;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final String? rawPaymentPlan = json['payment_plan'] as String?;
    return Booking(
      id: (json['id'] as num).toInt(),
      bookingCode: json['booking_code'] as String,
      propertyId: (json['property_id'] as num).toInt(),
      customerName: json['customer_name'] as String,
      customerWhatsapp: (json['customer_whatsapp'] as String?) ?? '',
      intentType: IntentType.fromValue(json['intent_type'] as String),
      preferredSurveyDate: _parseDateTime(json['preferred_survey_date']),
      confirmedSurveyDate: _parseDateTime(json['confirmed_survey_date']),
      paymentPlan:
          rawPaymentPlan != null ? PaymentPlan.fromValue(rawPaymentPlan) : null,
      customerNotes: json['customer_notes'] as String?,
      funnelStatus: FunnelStatus.fromValue(
        json['funnel_status'] as String? ?? 'new',
      ),
      adminNotes: json['admin_notes'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'booking_code': bookingCode,
      'property_id': propertyId,
      'customer_name': customerName,
      'customer_whatsapp': customerWhatsapp,
      'intent_type': intentType.value,
      'preferred_survey_date': preferredSurveyDate?.toUtc().toIso8601String(),
      'confirmed_survey_date': confirmedSurveyDate?.toUtc().toIso8601String(),
      'payment_plan': paymentPlan?.value,
      'customer_notes': customerNotes,
      'funnel_status': funnelStatus.value,
      'admin_notes': adminNotes,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }
}

/// Parameter RPC `create_booking(...)` yang dipanggil oleh Customer App.
class BookingCreateInput {
  const BookingCreateInput({
    required this.propertyId,
    required this.customerName,
    required this.customerWhatsapp,
    required this.intentType,
    this.preferredSurveyDate,
    this.paymentPlan,
    this.customerNotes,
  });

  final int propertyId;
  final String customerName;
  final String customerWhatsapp;
  final IntentType intentType;
  final DateTime? preferredSurveyDate;
  final PaymentPlan? paymentPlan;
  final String? customerNotes;

  Map<String, dynamic> toRpcParams() {
    return <String, dynamic>{
      'p_property_id': propertyId,
      'p_customer_name': customerName,
      'p_customer_whatsapp': customerWhatsapp,
      'p_intent_type': intentType.value,
      'p_preferred_survey_date': preferredSurveyDate?.toUtc().toIso8601String(),
      'p_payment_plan': paymentPlan?.value,
      'p_customer_notes': customerNotes,
    };
  }
}

DateTime? _parseDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
  return null;
}
