import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_models.dart';

/// Calls CourierGuy via Supabase Edge Functions (server-side proxy).
/// This avoids CORS issues and keeps the API key out of the app bundle.
///
/// Before going live:
/// 1. Deploy both edge functions (see supabase/functions/)
/// 2. Add secret COURIER_GUY_API_KEY in Supabase dashboard
/// 3. Add secret COLLECTION_ADDRESS_JSON (your dispatch address as JSON)
class CourierGuyService {
  static SupabaseClient get _sb => Supabase.instance.client;

  /// Fetches PUDO pickup points matching [search] text.
  /// [type] = 'locker' or 'counter' (kiosk).
  static Future<List<PickupPoint>> getPickupPoints({
    required String search,
    String type = 'locker',
  }) async {
    final res = await _sb.functions.invoke(
      'courierguy-pickup-points',
      body: {'search': search, 'type': type},
    );

    if (res.status != 200) {
      throw Exception('Could not load pickup points (${res.status})');
    }

    final raw = res.data;
    final list = (raw is List)
        ? raw
        : (raw is Map && raw['pickup_points'] is List)
            ? raw['pickup_points'] as List
            : [];

    return list
        .whereType<Map<String, dynamic>>()
        .map(PickupPoint.fromJson)
        .toList();
  }

  /// Gets a D2D delivery quote.
  /// [itemCount] is used to estimate parcel weight/size.
  static Future<List<DeliveryQuote>> getD2DQuote({
    required String street,
    required String suburb,
    required String city,
    required String province,
    required String postalCode,
    int itemCount = 1,
  }) async {
    final res = await _sb.functions.invoke(
      'courierguy-rates',
      body: {
        'itemCount': itemCount,
        'deliveryAddress': {
          'street_address': street,
          'suburb':         suburb,
          'city':           city,
          'zone':           _provinceCode(province),
          'code':           postalCode,
          'country':        'ZA',
        },
      },
    );

    if (res.status != 200) {
      throw Exception('Could not get delivery quote (${res.status})');
    }

    return _parseRates(res.data);
  }

  /// Gets a PUDO delivery quote for a specific pickup point.
  static Future<List<DeliveryQuote>> getPudoQuote({
    required String pudoPointId,
    int itemCount = 1,
  }) async {
    final res = await _sb.functions.invoke(
      'courierguy-rates',
      body: {'itemCount': itemCount, 'pudoPointId': pudoPointId},
    );

    if (res.status != 200) {
      throw Exception('Could not get PUDO quote (${res.status})');
    }

    return _parseRates(res.data);
  }

  static List<DeliveryQuote> _parseRates(dynamic data) {
    final list = (data is List)
        ? data
        : (data is Map && data['rates'] is List)
            ? data['rates'] as List
            : [];

    final quotes = list
        .whereType<Map<String, dynamic>>()
        .map(DeliveryQuote.fromJson)
        .where((q) => q.price > 0)
        .toList()
      ..sort((a, b) => a.price.compareTo(b.price));

    return quotes;
  }

  /// Maps SA province name to Shiplogic zone code.
  static String _provinceCode(String province) {
    const map = {
      'Gauteng':            'GAU',
      'Western Cape':       'WC',
      'KwaZulu-Natal':      'KZN',
      'Eastern Cape':       'EC',
      'Limpopo':            'LIM',
      'Mpumalanga':         'MP',
      'North West':         'NW',
      'Free State':         'FS',
      'Northern Cape':      'NC',
    };
    return map[province] ?? 'GAU';
  }
}
