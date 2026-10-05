class Place {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: (json['id'] ?? json['placeId'] ?? json['place_id'] ?? '').toString(),
      name: (json['name'] ?? json['placeName'] ?? json['place_name'] ?? '')
          .toString(),
      address: (json['address'] ??
              json['roadAddress'] ??
              json['road_address'] ??
              json['address_name'] ??
              '')
          .toString(),
      latitude: _parseDouble(
        json['latitude'] ??
            json['lat'] ??
            json['y'] ??
            json['position']?['lat'],
      ),
      longitude: _parseDouble(
        json['longitude'] ??
            json['lng'] ??
            json['x'] ??
            json['position']?['lng'],
      ),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}
