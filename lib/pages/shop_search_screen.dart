import 'package:flutter/material.dart';
import '../models/place_data.dart';
import '../services/place_search_api.dart';
import '../utils/kakao_map_config.dart';

/// 가게 이름 검색 화면 (검색 리스트 UX)
class ShopSearchScreen extends StatefulWidget {
  const ShopSearchScreen({super.key});

  @override
  State<ShopSearchScreen> createState() => _ShopSearchScreenState();
}

class _ShopSearchScreenState extends State<ShopSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<Place> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 바로 검색창에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색어를 입력해 주세요')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _results = [];
    });

    try {
      // 한국교통대학교 충주캠퍼스 기준으로 검색 (거리순 정렬)
      final places = await PlaceSearchApi.searchPlace(
        keyword: keyword,
        latitude: KakaoMapConfig.defaultLatitude,
        longitude: KakaoMapConfig.defaultLongitude,
      );
      if (!mounted) return;
      
      setState(() {
        _results = places;
        _isSearching = false;
      });

      if (places.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 결과가 없습니다')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  void _selectPlace(Place place) {
    // 가게명과 주소를 함께 반환
    Navigator.pop(context, {
      'name': place.name,
      'address': place.address,
      'place': place, // 전체 Place 객체도 함께 반환
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            hintText: '가게 이름을 검색하세요',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          ),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF81C784)),
            onPressed: _performSearch,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF81C784)),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '가게 이름을 검색해 보세요',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '예: 맥도날드, 이마트, 스타벅스',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        final place = _results[index];
        return _PlaceItem(
          place: place,
          onTap: () => _selectPlace(place),
        );
      },
    );
  }
}

class _PlaceItem extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _PlaceItem({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF81C784).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.store,
                color: Color(0xFF81C784),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      place.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

