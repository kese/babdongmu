import 'package:flutter/material.dart';
import '../models/place_data.dart';
import '../pages/shop_search_screen.dart';
import '../pages/location_picker_screen.dart';

/// 배달 게시글 작성 폼
/// - 가게 이름: 검색 화면으로 이동
/// - 배달 장소: 지도 화면으로 이동
/// - 게시글에는 POI와 대략적인 위치만 포함합니다.
class DeliveryFormNew extends StatefulWidget {
  final TextEditingController storeNameController;
  final TextEditingController deliveryPlaceController;
  final TextEditingController targetPriceController;
  final TextEditingController deliveryFeeController;
  final Function(Map<String, String>) onSaved;
  final Function(Place)? onStorePlaceSelected;
  final void Function(double latitude, double longitude)?
  onDeliveryLocationSelected;

  const DeliveryFormNew({
    super.key,
    required this.storeNameController,
    required this.deliveryPlaceController,
    required this.targetPriceController,
    required this.deliveryFeeController,
    required this.onSaved,
    this.onStorePlaceSelected,
    this.onDeliveryLocationSelected,
  });

  @override
  State<DeliveryFormNew> createState() => _DeliveryFormNewState();
}

class _DeliveryFormNewState extends State<DeliveryFormNew> {
  String? _poiName; // POI 순수명
  String? _roadAddress; // 도로명 주소

  @override
  void initState() {
    super.initState();
    widget.storeNameController.addListener(_notifyParent);
    widget.deliveryPlaceController.addListener(_notifyParent);
    widget.targetPriceController.addListener(_notifyParent);
    widget.deliveryFeeController.addListener(_notifyParent);
  }

  void _notifyParent() {
    widget.onSaved({
      'storeName': widget.storeNameController.text,
      'deliveryPlace': widget.deliveryPlaceController.text,
      'poiName': _poiName ?? '', // POI 순수명
      'roadAddress': _roadAddress ?? '', // 도로명 주소
      'targetPrice': widget.targetPriceController.text,
      'deliveryFee': widget.deliveryFeeController.text,
    });
  }

  /// 가게 검색 화면으로 이동
  Future<void> _openShopSearch() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const ShopSearchScreen()),
    );

    if (result != null && mounted) {
      final name = result['name'] as String?;
      final place = result['place'] as Place?;

      if (name != null) {
        widget.storeNameController.text = name;
      }

      if (place != null) {
        widget.onStorePlaceSelected?.call(place);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${name ?? "가게"}을(를) 선택했습니다'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 배달 장소 지도 선택 화면으로 이동
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && mounted) {
      final address = result['address'] as String?;
      final poiName = result['poiName'] as String?;
      final roadAddress = result['roadAddress'] as String?;
      final latitude = result['latitude'] as double?;
      final longitude = result['longitude'] as double?;

      if (address != null) {
        widget.deliveryPlaceController.text = address; // UI 표시용
      }

      // POI명과 도로명 주소 저장
      setState(() {
        _poiName = poiName;
        _roadAddress = roadAddress;
      });
      _notifyParent(); // 부모에게 데이터 전달

      if (latitude != null && longitude != null) {
        widget.onDeliveryLocationSelected?.call(latitude, longitude);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('배달 장소를 설정했습니다'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 가게 이름
        _buildLabel('가게 이름'),
        TextFormField(
          controller: widget.storeNameController,
          readOnly: true, // 검색 화면으로만 입력
          decoration: _inputDecoration('클릭하여 가게 검색').copyWith(
            suffixIcon: const Icon(Icons.search, color: Color(0xFF81C784)),
          ),
          validator: (value) => value!.trim().isEmpty ? '가게 이름을 선택해 주세요' : null,
          onTap: _openShopSearch,
        ),
        const SizedBox(height: 20),

        // 배달 장소 (도로명 주소)
        _buildLabel('배달 장소'),
        TextFormField(
          controller: widget.deliveryPlaceController,
          readOnly: true, // 지도 화면으로만 입력
          decoration: _inputDecoration('터치하여 지도에서 선택').copyWith(
            suffixIcon: const Icon(Icons.map, color: Color(0xFF81C784)),
          ),
          validator: (value) => value!.trim().isEmpty ? '배달 장소를 선택해 주세요' : null,
          onTap: _openLocationPicker,
        ),
        const SizedBox(height: 20),
        const Text(
          '공개 게시글에는 장소명과 대략적인 위치만 표시됩니다. 상세 주소나 동·호수는 입력하지 마세요.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 20),

        // 최소 주문 금액
        _buildLabel('최소 주문 금액'),
        TextFormField(
          controller: widget.targetPriceController,
          decoration: _inputDecoration('숫자만 입력'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value!.trim().isEmpty) {
              return '최소 주문 금액을 입력해 주세요';
            }
            final parsed = int.tryParse(value.trim().replaceAll(',', ''));
            if (parsed == null || parsed <= 0) {
              return '올바른 금액을 입력해 주세요';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // 배달비
        _buildLabel('배달비'),
        TextFormField(
          controller: widget.deliveryFeeController,
          decoration: _inputDecoration('숫자만 입력'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value!.trim().isEmpty) {
              return '배달비를 입력해 주세요';
            }
            final parsed = int.tryParse(value.trim().replaceAll(',', ''));
            if (parsed == null || parsed < 0) {
              return '올바른 배달비를 입력해 주세요';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
