import 'dart:async';

import 'package:delivery/models/delivery_post_data.dart';
import 'package:delivery/models/friend_post_data.dart';
import 'package:delivery/pages/post_detail_page.dart';
import 'package:delivery/services/notification_service.dart';
import 'package:delivery/services/place_search_api.dart';
import 'package:delivery/services/post_api.dart';
import 'package:delivery/utils/kakao_map_config.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

// 외부에서 새로고침을 트리거할 수 있도록 public 클래스 추가
abstract class MapPageController {
  void refreshPosts();
}

class _MapPageState extends State<MapPage> implements MapPageController {
  @override
  void refreshPosts() {
    if (_lastMapRefreshLat != null && _lastMapRefreshLng != null) {
      debugPrint('[MapPage] 🔄 외부 요청으로 새로고침 실행');
      _loadPosts(lat: _lastMapRefreshLat!, lng: _lastMapRefreshLng!);
    }
  }
  GoogleMapController? _mapController;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  List<DeliveryPost> _deliveryPosts = [];
  List<FriendPost> _friendPosts = [];

  // 선택된 게시글 정보
  Map<String, dynamic>? _selectedPost;

  // 현재 위치
  double _currentLat = KakaoMapConfig.defaultLatitude;
  double _currentLng = KakaoMapConfig.defaultLongitude;

  // 마지막으로 게시글을 로드한 위치
  double? _lastMapRefreshLat;
  double? _lastMapRefreshLng;

  // 위치 스트림 구독
  StreamSubscription<Position>? _positionStream;
  
  // 게시물 업데이트 알림 구독
  StreamSubscription<String>? _postUpdateSubscription;

  // 자동 새로고침을 위한 최소 이동 거리 (미터)
  static const double _minMoveDistance = 200.0;

  // 게시글 마커
  Set<Marker> _markers = {};

  // 디바운싱용 타이머 (지도 이동 시)
  Timer? _debounceTimer;
  
  // 주기적 새로고침 타이머
  Timer? _periodicRefreshTimer;
  
  // 마지막 새로고침 시간
  DateTime? _lastRefreshTime;
  

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _startPeriodicRefresh();
    _listenPostUpdates();
  }
  
  // 게시물 업데이트 알림 구독
  void _listenPostUpdates() {
    _postUpdateSubscription = NotificationService.postUpdates.listen((postId) {
      if (mounted && _lastMapRefreshLat != null && _lastMapRefreshLng != null) {
        // 게시물 상태가 변경되었으므로 새로고침
        _loadPosts(lat: _lastMapRefreshLat!, lng: _lastMapRefreshLng!);
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 활성화될 때 새로고침 (지도 탭으로 돌아올 때)
    if (_lastMapRefreshLat != null && _lastMapRefreshLng != null) {
      final now = DateTime.now();
      // 마지막 새로고침 후 5초 이상 지났으면 새로고침
      if (_lastRefreshTime == null || 
          now.difference(_lastRefreshTime!).inSeconds > 5) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            debugPrint('[MapPage] 🔄 화면 활성화로 새로고침 실행');
            _loadPosts(lat: _lastMapRefreshLat!, lng: _lastMapRefreshLng!);
          }
        });
      }
    }
  }
  
  // 주기적 새로고침 시작 (30초마다)
  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (mounted && _lastMapRefreshLat != null && _lastMapRefreshLng != null) {
          debugPrint('[MapPage] 🔄 주기적 새로고침 실행');
          _loadPosts(lat: _lastMapRefreshLat!, lng: _lastMapRefreshLng!);
        }
      },
    );
  }
  

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _periodicRefreshTimer?.cancel();
    _positionStream?.cancel();
    _postUpdateSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    debugPrint('[MapPage] 🗺️ 지도 초기화 시작');
    
    // 현재 위치 가져오기
    await _getCurrentLocation();

    // 마지막 새로고침 위치 설정
    _lastMapRefreshLat = _currentLat;
    _lastMapRefreshLng = _currentLng;

    // 현재 위치 기반으로 게시글 로드
    await _loadPosts(lat: _currentLat, lng: _currentLng);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // 실시간 위치 추적 시작
    _startLocationTracking();
    debugPrint('[MapPage] ✅ 지도 초기화 완료');
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // 위치 서비스가 비활성화된 경우 기본 위치 유지
        debugPrint('위치 서비스 비활성화 - 기본 위치 사용');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // 권한이 거부된 경우 기본 위치 유지
          debugPrint('위치 권한 거부 - 기본 위치 사용');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 권한이 영구적으로 거부된 경우 기본 위치 유지
        debugPrint('위치 권한 영구 거부 - 기본 위치 사용');
        return;
      }

      // 현재 위치 가져오기 (타임아웃 설정)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('위치 가져오기 타임아웃');
        },
      );

      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
        });
        
        // 위치를 가져왔으면 지도 카메라도 이동
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              15.0,
            ),
          );
        }
      }
    } catch (e) {
      // 위치 가져오기 실패 시 기본 위치 사용 (이미 초기화되어 있음)
      debugPrint('위치 가져오기 실패 - 기본 위치 사용');
    }
  }

  Future<void> _loadPosts({required double lat, required double lng}) async {
    _lastRefreshTime = DateTime.now();
    
    try {
      // 위치 기반으로 게시글 요청
      final deliveryResult = await PostApi.getDeliveryPosts(lat: lat, lng: lng);
      final friendResult = await PostApi.getFriendPosts(lat: lat, lng: lng);

      if (deliveryResult['success'] == true) {
        final List<dynamic> data = deliveryResult['data'] ?? [];
        _deliveryPosts = data
            .map((json) => DeliveryPost.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint('[MapPage] ✅ 배달 게시글 로드 완료: ${_deliveryPosts.length}개');
        
      } else {
        debugPrint('[MapPage] 배달 게시글 로드 실패');
      }

      if (friendResult['success'] == true) {
        final List<dynamic> data = friendResult['data'] ?? [];
        _friendPosts = data
            .map((json) => FriendPost.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint('[MapPage] ✅ 친구 게시글 로드 완료: ${_friendPosts.length}개');
        
      } else {
        debugPrint('[MapPage] 친구 게시글 로드 실패');
      }

      // 게시글 로드가 완료되면 마커를 다시 그림
      _updateMarkers();
    } catch (_) {
      debugPrint('[MapPage] 게시글 로드 실패');
    }
  }

  // 지도 생성 완료 시 호출
  Future<void> _onMapCreated(GoogleMapController controller) async {
    debugPrint('[MapPage] 🗺️ 지도 생성 완료');
    _mapController = controller;
    
    // 지도가 생성되면 한국교통대학교 위치로 카메라 이동
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          KakaoMapConfig.defaultLatitude,
          KakaoMapConfig.defaultLongitude,
        ),
        15.0,
      ),
    );
    debugPrint('[MapPage] 📍 카메라 위치 이동 완료 (한국교통대학교)');
    
    // 초기 마커 업데이트
    _updateMarkers();
  }

  // 실시간 위치 추적 시작
  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10미터 이동 시 업데이트
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
        });

        // 현재 위치는 myLocationEnabled로 자동 표시됨

        // 마지막 새로고침 위치에서 일정 거리 이상 벗어났는지 확인
        if (_lastMapRefreshLat != null && _lastMapRefreshLng != null) {
          final distance = Geolocator.distanceBetween(
            _lastMapRefreshLat!,
            _lastMapRefreshLng!,
            _currentLat,
            _currentLng,
          );

          // 최소 이동 거리를 넘으면 게시글 새로고침
          if (distance > _minMoveDistance) {
            _lastMapRefreshLat = _currentLat;
            _lastMapRefreshLng = _currentLng;
            _loadPosts(lat: _currentLat, lng: _currentLng);
          }
        }
      }
    });
  }

  // 지도 카메라 이동 완료 시 호출 (디바운싱 적용)
  void _onCameraIdle() {
    if (_mapController == null) return;

    // 기존 타이머 취소
    _debounceTimer?.cancel();

    // 500ms 후에 게시글 새로고침 (드래그 중에는 호출 안함)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final position = await _mapController!.getVisibleRegion();
      final centerLat = (position.northeast.latitude + position.southwest.latitude) / 2;
      final centerLng = (position.northeast.longitude + position.southwest.longitude) / 2;

      // 마지막 새로고침 위치 갱신
      _lastMapRefreshLat = centerLat;
      _lastMapRefreshLng = centerLng;

      // 이동한 위치 기준으로 게시글 새로고침
      await _loadPosts(lat: centerLat, lng: centerLng);
    });
  }

  // 게시글 마커 업데이트
  void _updateMarkers() {
    debugPrint('[MapPage] 📍 마커 업데이트 시작');
    final markers = <Marker>{};
    int deliveryMarkerCount = 0;
    int friendMarkerCount = 0;
    int skippedDeliveryCount = 0;
    int skippedFriendCount = 0;

    // 배달 게시글 마커
    debugPrint('[MapPage] 🔵 배달 게시글 마커 생성 시작 (총 ${_deliveryPosts.length}개)');
    for (final post in _deliveryPosts) {
      final lat = post.deliveryLatitude;
      final lng = post.deliveryLongitude;
      if (lat == null || lng == null) {
        skippedDeliveryCount++;
        continue;
      }

      final markerId = MarkerId('delivery_${post.id}');
      markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: post.title,
            snippet: '${post.storeName} · ${post.deliveryPlace}',
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  postId: post.id,
                  postType: 'delivery',
                ),
              ),
            );
          },
        ),
      );
      deliveryMarkerCount++;
    }

    // 식사 게시글 마커
    debugPrint('[MapPage] 🟠 친구 게시글 마커 생성 시작 (총 ${_friendPosts.length}개)');
    for (final post in _friendPosts) {
      final lat = post.meetingLatitude;
      final lng = post.meetingLongitude;
      if (lat == null || lng == null) {
        skippedFriendCount++;
        continue;
      }

      final markerId = MarkerId('friend_${post.id}');
      markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(
            title: post.title,
            snippet: post.meetingPlace,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  postId: post.id,
                  postType: 'friend',
                ),
              ),
            );
          },
        ),
      );
      friendMarkerCount++;
    }

    debugPrint('[MapPage] 📊 마커 생성 결과:');
    debugPrint('[MapPage]   - 배달 마커: $deliveryMarkerCount개 생성, $skippedDeliveryCount개 스킵');
    debugPrint('[MapPage]   - 친구 마커: $friendMarkerCount개 생성, $skippedFriendCount개 스킵');
    debugPrint('[MapPage]   - 총 마커: ${markers.length}개');

    if (mounted) {
      setState(() {
        _markers = markers;
      });
      debugPrint('[MapPage] ✅ 마커 업데이트 완료 (지도에 ${_markers.length}개 마커 표시)');
    } else {
      debugPrint('[MapPage] ⚠️ 위젯이 마운트되지 않아 마커 업데이트 스킵');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty || _mapController == null) {
      return;
    }

    try {
      // PlaceSearchApi를 사용하여 장소 검색
      final places = await PlaceSearchApi.searchPlace(
        keyword: query,
        latitude: _currentLat,
        longitude: _currentLng,
      );

      if (places.isNotEmpty && _mapController != null) {
        final place = places.first;
        final target = LatLng(place.latitude, place.longitude);
        
        // 지도 중심 이동
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(target, 15.0),
        );

        // 검색 위치 기준으로 게시글 새로고침
        _lastMapRefreshLat = place.latitude;
        _lastMapRefreshLng = place.longitude;
        await _loadPosts(lat: place.latitude, lng: place.longitude);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('검색 결과를 찾을 수 없습니다')),
          );
        }
      }
    } catch (_) {
      debugPrint('장소 검색 실패');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 중 오류가 발생했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '주변 게시글',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '지역 또는 장소 검색',
                filled: true,
                fillColor: Colors.grey[100],
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _searchLocation,
            ),
          ),
          // 지도
          Expanded(
            child: Stack(
              children: [
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF81C784),
                    ),
                  )
                else
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_currentLat, _currentLng),
                      zoom: 15.0,
                    ),
                    onMapCreated: _onMapCreated,
                    onCameraIdle: _onCameraIdle,
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    buildingsEnabled: false,
                    trafficEnabled: false,
                  ),
                // 선택된 게시글 정보 카드
                if (_selectedPost != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _PostInfoCard(
                      post: _selectedPost!,
                      onClose: () {
                        setState(() {
                          _selectedPost = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// 게시글 정보 카드 위젯 (기존과 동일)
class _PostInfoCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onClose;

  const _PostInfoCard({
    required this.post,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final type = post['type'] as String?;
    final isDelivery = type == 'delivery';
    final title = post['title'] as String? ?? '';
    final currentPeople = post['currentPeople'] as int? ?? 0;
    final maxPeople = post['maxPeople'] as int? ?? 0;
    final isRecruiting = post['isRecruiting'] as bool? ?? false;

    String locationInfo;
    if (isDelivery) {
      final storeName = post['storeName'] as String? ?? '';
      final deliveryPlace = post['deliveryPlace'] as String? ?? '';
      locationInfo = '$storeName · $deliveryPlace';
    } else {
      locationInfo = post['meetingPlace'] as String? ?? '';
    }

    // 마감 시간 파싱
    String deadlineText = '';
    final deadlineStr = post['deadline'] as String?;
    if (deadlineStr != null) {
      final deadline = DateTime.tryParse(deadlineStr);
      if (deadline != null) {
        final now = DateTime.now();
        final difference = deadline.difference(now);
        if (difference.isNegative) {
          deadlineText = '마감됨';
        } else if (difference.inMinutes < 60) {
          deadlineText = '${difference.inMinutes}분 후 마감';
        } else if (difference.inHours < 24) {
          deadlineText = '${difference.inHours}시간 후 마감';
        } else {
          deadlineText = '${deadline.month}/${deadline.day} 마감';
        }
      }
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // 타입 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDelivery
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : const Color(0xFFFF9800).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDelivery ? '배달' : '식사',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDelivery
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF9800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 모집 상태
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isRecruiting
                        ? const Color(0xFF81C784).withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isRecruiting ? '모집중' : '모집완료',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isRecruiting
                          ? const Color(0xFF81C784)
                          : Colors.grey,
                    ),
                  ),
                ),
                const Spacer(),
                // 닫기 버튼
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 제목
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 위치 정보
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationInfo,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 인원 및 마감 시간
            Row(
              children: [
                const Icon(
                  Icons.people,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '$currentPeople/$maxPeople명',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                if (deadlineText.isNotEmpty) ...[
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    deadlineText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
