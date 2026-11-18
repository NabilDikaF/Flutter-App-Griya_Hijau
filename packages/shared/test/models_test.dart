import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('Enums schema mapping', () {
    test('availability, intent, payment plan, and funnel status map identically', () {
      expect(
        AvailabilityStatus.fromValue('booked'),
        AvailabilityStatus.booked,
      );
      expect(
        IntentType.fromValue('survey_location'),
        IntentType.surveyLocation,
      );
      expect(
        PaymentPlan.fromValue('cash_installment'),
        PaymentPlan.cashInstallment,
      );
      expect(FunnelStatus.fromValue('new'), FunnelStatus.newLead);
      expect(
        FunnelStatus.fromValue('closed_won'),
        FunnelStatus.closedWon,
      );
    });
  });

  group('PropertyInput', () {
    test('never contains views_count in JSON payload', () {
      const PropertyInput input = PropertyInput(
        propertyCategoryId: 1,
        locationId: 1,
        title: 'Rumah Contoh',
        slug: 'rumah-contoh',
        price: 750000000,
        buildingArea: 45,
        landArea: 84,
        bedrooms: 2,
        bathrooms: 1,
        floors: 1,
        electricity: '1300 VA',
        certificateType: 'SHM',
        latitude: -6.914744,
        longitude: 107.609810,
      );

      final Map<String, dynamic> json = input.toJson();
      expect(json.containsKey('views_count'), isFalse);
      expect(json.containsKey('viewsCount'), isFalse);
      expect(json['property_category_id'], 1);
      expect(json['availability_status'], 'available');
      expect(json['is_published'], isTrue);
    });
  });

  group('Model JSON roundtrips', () {
    test('Property parses nested category, location, and images sorted with primary first', () {
      final Property property = Property.fromJson(<String, dynamic>{
        'id': 10,
        'property_category_id': 1,
        'location_id': 2,
        'title': 'Griya Asri',
        'slug': 'griya-asri',
        'price': 900000000,
        'availability_status': 'available',
        'views_count': 12,
        'is_published': true,
        'property_categories': <String, dynamic>{
          'id': 1,
          'name': 'Komplek Perumahan',
          'slug': 'komplek-perumahan',
          'is_active': true,
        },
        'locations': <String, dynamic>{
          'id': 2,
          'city': 'Bandung',
          'district': 'Kec. Mekar Jaya',
          'slug': 'bandung-kec-mekar-jaya',
        },
        'property_images': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2,
            'property_id': 10,
            'image_path': 'properties/10/interior.jpg',
            'is_primary': false,
            'sort_order': 1,
          },
          <String, dynamic>{
            'id': 1,
            'property_id': 10,
            'image_path': 'properties/10/main.jpg',
            'is_primary': true,
            'sort_order': 0,
          },
        ],
      });

      expect(property.primaryImagePath, 'properties/10/main.jpg');
      expect(property.category?.name, 'Komplek Perumahan');
      expect(property.location?.displayName, 'Kec. Mekar Jaya, Bandung');
      expect(property.toJson()['views_count'], 12);
    });

    test('Booking and BookingCreateInput map schema and RPC params', () {
      final Booking booking = Booking.fromJson(<String, dynamic>{
        'id': 5,
        'booking_code': 'BK-20261114-AB12C',
        'property_id': 1,
        'customer_name': 'Budi Santoso',
        'customer_whatsapp': '6281234567890',
        'intent_type': 'book_unit',
        'payment_plan': 'kpr',
        'funnel_status': 'new',
      });
      expect(booking.funnelStatus, FunnelStatus.newLead);
      expect(booking.paymentPlan, PaymentPlan.kpr);

      const BookingCreateInput rpcInput = BookingCreateInput(
        propertyId: 1,
        customerName: 'Budi Santoso',
        customerWhatsapp: '6281234567890',
        intentType: IntentType.bookUnit,
        paymentPlan: PaymentPlan.kpr,
      );
      final Map<String, dynamic> params = rpcInput.toRpcParams();
      expect(params['p_property_id'], 1);
      expect(params['p_customer_whatsapp'], '6281234567890');
      expect(params['p_intent_type'], 'book_unit');
      expect(params['p_payment_plan'], 'kpr');
    });

    test('SeedData provides 2 categories, 5 locations, 6 published + 2 unpublished properties', () {
      expect(SeedData.categories, hasLength(2));
      expect(SeedData.locations, hasLength(5));
      expect(SeedData.properties, hasLength(8));
      expect(SeedData.publishedSummaries, hasLength(6));
      expect(
        SeedData.properties.where((Property p) => !p.isPublished),
        hasLength(2),
      );
    });
  });
}
