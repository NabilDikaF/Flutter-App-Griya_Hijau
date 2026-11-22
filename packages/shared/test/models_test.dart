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

    test('Property.fromJson handles null or non-List property_images without throwing', () {
      final Map<String, dynamic> base = <String, dynamic>{
        'id': 11,
        'property_category_id': 1,
        'location_id': 1,
        'title': 'Griya Tanpa Foto',
        'slug': 'griya-tanpa-foto',
        'price': 500000000,
      };

      final Property withNull = Property.fromJson(<String, dynamic>{
        ...base,
        'property_images': null,
      });
      final Property withString = Property.fromJson(<String, dynamic>{
        ...base,
        'property_images': 'invalid',
      });

      expect(withNull.images, isEmpty);
      expect(withString.images, isEmpty);
    });

    test('PropertyCategory.fromJson defaults isActive to false when is_active is omitted', () {
      final PropertyCategory omitted = PropertyCategory.fromJson(<String, dynamic>{
        'id': 3,
        'name': 'Kavling',
        'slug': 'kavling',
      });
      final PropertyCategory explicitTrue =
          PropertyCategory.fromJson(<String, dynamic>{
        'id': 4,
        'name': 'Ruko',
        'slug': 'ruko',
        'is_active': true,
      });

      expect(omitted.isActive, isFalse);
      expect(explicitTrue.isActive, isTrue);
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

    test('Booking.fromJson parses Stage-1 check_booking_status payload without customer_whatsapp or admin_notes', () {
      final Booking stage1 = Booking.fromJson(<String, dynamic>{
        'id': 7,
        'booking_code': 'BK-20261122-0123456789ABCDEF',
        'property_id': 1,
        'customer_name': 'Rina Marlina',
        'intent_type': 'survey_location',
        'preferred_survey_date': '2026-11-23T03:00:00Z',
        'funnel_status': 'survey_scheduled',
        'created_at': '2026-11-22T01:00:00Z',
        'updated_at': '2026-11-22T02:00:00Z',
      });

      expect(stage1.customerWhatsapp, isEmpty);
      expect(stage1.adminNotes, isNull);
      expect(stage1.funnelStatus, FunnelStatus.surveyScheduled);
    });

    test('All models and BookingCreateInput serialize DateTime fields as UTC ISO-8601', () {
      final DateTime localDt = DateTime(2026, 11, 22, 14, 30);

      final Property property = Property(
        id: 1,
        propertyCategoryId: 1,
        locationId: 1,
        title: 'A',
        slug: 'a',
        price: 100,
        availabilityStatus: AvailabilityStatus.available,
        viewsCount: 0,
        isPublished: true,
        createdAt: localDt,
        updatedAt: localDt,
      );
      expect(property.toJson()['created_at'], endsWith('Z'));
      expect(property.toJson()['updated_at'], endsWith('Z'));

      final PropertyCategory category = PropertyCategory(
        id: 1,
        name: 'Rumah',
        slug: 'rumah',
        isActive: true,
        createdAt: localDt,
        updatedAt: localDt,
      );
      expect(category.toJson()['created_at'], endsWith('Z'));
      expect(category.toJson()['updated_at'], endsWith('Z'));

      final Location location = Location(
        id: 1,
        city: 'Bandung',
        district: 'Sukamaju',
        slug: 'bandung-sukamaju',
        createdAt: localDt,
        updatedAt: localDt,
      );
      expect(location.toJson()['created_at'], endsWith('Z'));
      expect(location.toJson()['updated_at'], endsWith('Z'));

      final PropertyImage image = PropertyImage(
        id: 1,
        propertyId: 1,
        imagePath: 'properties/1/a.jpg',
        isPrimary: true,
        sortOrder: 0,
        createdAt: localDt,
        updatedAt: localDt,
      );
      expect(image.toJson()['created_at'], endsWith('Z'));
      expect(image.toJson()['updated_at'], endsWith('Z'));

      final Booking booking = Booking(
        id: 1,
        bookingCode: 'BK-20261122-0123456789ABCDEF',
        propertyId: 1,
        customerName: 'Budi',
        customerWhatsapp: '6281234567890',
        intentType: IntentType.surveyLocation,
        preferredSurveyDate: localDt,
        confirmedSurveyDate: localDt,
        funnelStatus: FunnelStatus.newLead,
        createdAt: localDt,
        updatedAt: localDt,
      );
      final Map<String, dynamic> bookingJson = booking.toJson();
      expect(bookingJson['preferred_survey_date'], endsWith('Z'));
      expect(bookingJson['confirmed_survey_date'], endsWith('Z'));
      expect(bookingJson['created_at'], endsWith('Z'));
      expect(bookingJson['updated_at'], endsWith('Z'));

      final BookingCreateInput input = BookingCreateInput(
        propertyId: 1,
        customerName: 'Budi',
        customerWhatsapp: '6281234567890',
        intentType: IntentType.surveyLocation,
        preferredSurveyDate: localDt,
      );
      expect(input.toRpcParams()['p_preferred_survey_date'], endsWith('Z'));

      final PropertyViewLog viewLog = PropertyViewLog(
        id: 1,
        propertyId: 1,
        viewedAt: localDt,
      );
      expect(viewLog.toJson()['viewed_at'], endsWith('Z'));

      final SearchLog searchLog = SearchLog(
        id: 1,
        resultsCount: 3,
        searchedAt: localDt,
      );
      expect(searchLog.toJson()['searched_at'], endsWith('Z'));
    });

    test('SeedData provides unmodifiable properties list and expected seed counts', () {
      expect(SeedData.categories, hasLength(2));
      expect(SeedData.locations, hasLength(5));
      expect(SeedData.properties, hasLength(8));
      expect(SeedData.publishedSummaries, hasLength(6));
      expect(
        SeedData.properties.where((Property p) => !p.isPublished),
        hasLength(2),
      );
      expect(
        () => SeedData.properties.add(SeedData.properties.first),
        throwsUnsupportedError,
      );
    });
  });
}
