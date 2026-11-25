enum DeliveryType { door2door, pudo }

class PickupPoint {
  final String id;
  final String name;
  final String address;
  final String city;
  final String type; // 'locker' | 'counter'

  const PickupPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.type,
  });

  factory PickupPoint.fromJson(Map<String, dynamic> j) {
    final parts = <String>[];
    if (j['address'] != null && j['address'].toString().isNotEmpty) parts.add(j['address'].toString());
    if (j['suburb']  != null && j['suburb'].toString().isNotEmpty)  parts.add(j['suburb'].toString());
    return PickupPoint(
      id:      j['id']?.toString() ?? j['code']?.toString() ?? '',
      name:    j['name']?.toString() ?? '',
      address: parts.join(', '),
      city:    j['city']?.toString() ?? '',
      type:    j['type']?.toString() ?? 'locker',
    );
  }

  String get typeLabel {
    switch (type) {
      case 'counter': return 'Kiosk';
      default:        return 'Locker';
    }
  }

  String get displayAddress => [address, city].where((s) => s.isNotEmpty).join(', ');
}

class DeliveryQuote {
  final String serviceCode;
  final String serviceName;
  final double price; // VAT inclusive
  final String? deliveryDays;

  const DeliveryQuote({
    required this.serviceCode,
    required this.serviceName,
    required this.price,
    this.deliveryDays,
  });

  factory DeliveryQuote.fromJson(Map<String, dynamic> j) {
    final level = j['service_level'] as Map<String, dynamic>? ?? {};
    return DeliveryQuote(
      serviceCode:  level['code']?.toString() ?? j['service_level_code']?.toString() ?? '',
      serviceName:  level['name']?.toString() ?? '',
      price:        ((j['rate'] ?? j['total'] ?? 0) as num).toDouble(),
      deliveryDays: level['delivery_window']?.toString() ?? j['service_days']?.toString(),
    );
  }
}

class DeliverySelection {
  final DeliveryType type;
  final DeliveryQuote quote;
  // D2D fields
  final String? street;
  final String? suburb;
  final String? city;
  final String? province;
  final String? postalCode;
  // PUDO
  final PickupPoint? pudoPoint;

  const DeliverySelection({
    required this.type,
    required this.quote,
    this.street,
    this.suburb,
    this.city,
    this.province,
    this.postalCode,
    this.pudoPoint,
  });

  String get summaryLine {
    if (type == DeliveryType.pudo && pudoPoint != null) {
      return '${pudoPoint!.typeLabel}: ${pudoPoint!.name}';
    }
    final parts = [street, suburb, city].where((s) => s != null && s!.isNotEmpty).toList();
    return parts.join(', ');
  }
}
