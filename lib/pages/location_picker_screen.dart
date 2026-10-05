import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/place_search_api.dart';
import '../utils/kakao_map_config.dart';
import '../utils/logging.dart';

/// 배달 장소 선택 화면 (네이티브 지도 + 중앙 핀 UX)
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // 상태 변수
  GoogleMapController? _mapController;
  bool _isLoadingGps = false;
  bool _isLoadingAddress = false;
  String _currentAddress = '위치를 이동하여 주소를 확인하세요';
  String? _currentPoiName; // POI 순수명 (예: "GS25 충주점")
  String? _currentRoadAddress; // 도로명 주소 (예: "충북 충주시 교현동 123-4")

  // 현재 지도 중심 좌표
  double _currentLat = KakaoMapConfig.defaultLatitude;
  double _currentLng = KakaoMapConfig.defaultLongitude;

  // 디바운싱용 타이머
  Timer? _debounceTimer;

  // 검색 관련 상태
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// 지도 카메라 이동 시 호출 (실시간)
  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentLat = position.target.latitude;
      _currentLng = position.target.longitude;
    });
  }

  /// 지도 카메라 이동 완료 시 호출 (디바운싱 적용)
  void _onCameraIdle() {
    // 기존 타이머 취소
    _debounceTimer?.cancel();

    // 500ms 후에 API 호출 (드래그 중에는 호출 안함)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchAddressForCurrentLocation();
    });
  }

  /// 현재 좌표의 주소/상호명 조회 (POI 우선 → 주소 fallback)
  Future<void> _fetchAddressForCurrentLocation() async {
    logDebug('[LocationPicker] Address lookup started');

    setState(() {
      _isLoadingAddress = true;
      _currentAddress = '주소 조회 중...';
    });

    try {
      // 서버 API 호출: POI 검색 (상호명 우선)
      logDebug('[LocationPicker] Nearby place lookup started');
      final result = await PlaceSearchApi.nearbyPoi(
        latitude: _currentLat,
        longitude: _currentLng,
        // radius 생략 시 서버 기본값(20m) 사용
      );

      if (!mounted) return;

      final poi = result['poi'];
      final address = result['address'];

      if (poi != null && poi.isNotEmpty) {
        // POI 발견: "스타벅스 강남점"
        logDebug('[LocationPicker] Place result available');
        setState(() {
          _currentAddress = poi; // UI에 POI만 표시
          _currentPoiName = poi; // POI 명칭 저장
          _currentRoadAddress = address; // 도로명 주소 저장
          _isLoadingAddress = false;
        });
      } else if (address != null && address.isNotEmpty) {
        // POI 없음: 주소만 표시
        logDebug('[LocationPicker] Address result available');
        setState(() {
          _currentAddress = address; // UI에 주소 표시
          _currentPoiName = null; // POI 없음
          _currentRoadAddress = address; // 도로명 주소만 저장
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _currentAddress = '주소를 찾을 수 없습니다';
          _currentPoiName = null;
          _currentRoadAddress = null;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      logDebug('[LocationPicker] Address lookup failed');
      if (!mounted) return;
      setState(() {
        _currentAddress = '주소 조회 실패';
        _isLoadingAddress = false;
      });
    }
  }

  /// 장소 검색
  Future<void> _searchPlace(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // 한국교통대학교 충주캠퍼스 기준으로 검색 (거리순 정렬)
      final results = await PlaceSearchApi.searchPlace(
        keyword: keyword,
        latitude: KakaoMapConfig.defaultLatitude,
        longitude: KakaoMapConfig.defaultLongitude,
      );
      if (!mounted) return;

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      logDebug('[LocationPicker] Place search failed');
      if (!mounted) return;
      setState(() {
        _searchResults = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// 검색어 입력 시 디바운싱 처리
  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlace(value);
    });
  }

  /// 검색 결과 선택
  void _onSearchResultSelected(dynamic place) {
    final lat = place.latitude;
    final lng = place.longitude;

    if (lat != null && lng != null) {
      // 지도 이동
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
      );

      // 상태 업데이트
      setState(() {
        _currentLat = lat;
        _currentLng = lng;
        _searchController.clear();
        _searchResults = [];
      });

      // 주소 조회
      _fetchAddressForCurrentLocation();
    }
  }

  /// [이 위치로 설정] 버튼 클릭
  void _confirmLocation() {
    if (_currentAddress == '주소를 찾을 수 없습니다' || _currentAddress == '주소 조회 실패') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('유효한 주소를 선택해주세요')));
      return;
    }
    Navigator.pop(context, {
      'address': _currentAddress, // UI 표시용 (POI 또는 도로명)
      'poiName': _currentPoiName, // POI 순수명 (매칭용)
      'roadAddress': _currentRoadAddress, // 도로명 주소
      'latitude': _currentLat,
      'longitude': _currentLng,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('배달 장소 선택'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoadingGps
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('지도 로딩 중...'),
                ],
              ),
            )
          : Stack(
              children: [
                // 네이티브 Google Maps
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentLat, _currentLng),
                    zoom: 16.0,
                  ),
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    logDebug('[LocationPicker] Map created');

                    // 지도 생성 후 한국교통대학교 위치로 카메라 이동
                    await controller.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(
                          KakaoMapConfig.defaultLatitude,
                          KakaoMapConfig.defaultLongitude,
                        ),
                        16.0,
                      ),
                    );

                    // 현재 좌표를 한국교통대학교로 업데이트
                    setState(() {
                      _currentLat = KakaoMapConfig.defaultLatitude;
                      _currentLng = KakaoMapConfig.defaultLongitude;
                    });

                    // 초기 주소 조회
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _fetchAddressForCurrentLocation();
                    });
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: false,
                  buildingsEnabled: false, // 성능 향상
                  trafficEnabled: false,
                ),

                // 상단 검색창
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      // 검색 입력창
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: '장소 검색',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      // 검색 결과 리스트
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final place = _searchResults[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF81C784),
                                ),
                                title: Text(
                                  place.name ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  place.address ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                onTap: () => _onSearchResultSelected(place),
                              );
                            },
                          ),
                        ),

                      // 검색 중 로딩
                      if (_isSearching)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('검색 중...'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 중앙 고정 핀 (지도는 움직이지만 핀은 고정)
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, -24), // 핀 끝이 중심에 오도록 보정
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 48.0,
                    ),
                  ),
                ),

                // 하단 주소 표시 카드
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 주소 표시 영역
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _isLoadingAddress
                                    ? Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text('주소 조회 중...'),
                                        ],
                                      )
                                    : Text(
                                        _currentAddress,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // [이 위치로 설정] 버튼
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoadingAddress
                                  ? null
                                  : _confirmLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                '이 위치로 설정',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
