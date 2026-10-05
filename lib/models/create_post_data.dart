enum PostType { delivery, friend }

class CreatePostData {
  PostType type = PostType.delivery; // 초기값: 배달

  // 공통 항목
  String title = '';
  String? storeName;
  double? storeLatitude;
  double? storeLongitude;
  int? maxPeople;
  DateTime? deadline;
  String? details;

  // 배달 전용 항목
  String? deliveryPlace;
  String? deliveryPoiName; // POI 명칭만 (예: "GS25 교통대생활관점")
  String? deliveryRoadAddress; // 도로명 주소 (예: "충북 충주시 교현동 123-4")
  double? deliveryLatitude;
  double? deliveryLongitude;
  String? targetPrice;
  String? deliveryFee;

  // 친구 전용 항목
  String? meetingPlace;
  double? meetingLatitude;
  double? meetingLongitude;

  bool isValid() {
    // 공통 항목 검사
    if (title.isEmpty || storeName == null || storeName!.isEmpty) {
      return false;
    }
    if (maxPeople == null || deadline == null) {
      return false;
    }

    // 유형별 검사
    if (type == PostType.delivery) {
      if (deliveryPlace == null || deliveryPlace!.isEmpty) return false;
      if (targetPrice == null || targetPrice!.isEmpty) return false;
      if (deliveryFee == null || deliveryFee!.isEmpty) return false;
    } else {
      if (meetingPlace == null || meetingPlace!.isEmpty) return false;
    }

    return true;
  }

  void reset() {
    type = PostType.delivery;
    title = '';
    storeName = null;
    storeLatitude = null;
    storeLongitude = null;
    maxPeople = null;
    deadline = null;
    details = null;
    deliveryPlace = null;
    deliveryPoiName = null;
    deliveryRoadAddress = null;
    deliveryLatitude = null;
    deliveryLongitude = null;
    targetPrice = null;
    deliveryFee = null;
    meetingPlace = null;
    meetingLatitude = null;
    meetingLongitude = null;
  }
}
