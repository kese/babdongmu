import 'package:flutter/material.dart';

import '../models/place_data.dart';
import '../services/place_search_api.dart';
import 'place_search_list.dart';

class DeliveryForm extends StatefulWidget {
  final TextEditingController storeNameController;
  final TextEditingController deliveryPlaceController;
  final TextEditingController targetPriceController;
  final TextEditingController deliveryFeeController;
  final Function(Map<String, String>) onSaved;
  final Function(Place)? onStorePlaceSelected;
  final Function(Place)? onDeliveryPlaceSelected;

  const DeliveryForm({
    super.key,
    required this.storeNameController,
    required this.deliveryPlaceController,
    required this.targetPriceController,
    required this.deliveryFeeController,
    required this.onSaved,
    this.onStorePlaceSelected,
    this.onDeliveryPlaceSelected,
  });

  @override
  State<DeliveryForm> createState() => _DeliveryFormState();
}

class _DeliveryFormState extends State<DeliveryForm> {
  final _formKey = GlobalKey<FormState>();
  final _snackDuration = const Duration(seconds: 2);

  DeliverySearchTarget _activeTarget = DeliverySearchTarget.store;
  List<Place> _places = const [];
  bool _isSearching = false;
  bool _hasSearched = false; // 검색 실행 여부
  Place? _pendingSelection;

  @override
  void initState() {
    super.initState();
    widget.storeNameController.addListener(_notifyParent);
    widget.deliveryPlaceController.addListener(_notifyParent);
    widget.targetPriceController.addListener(_notifyParent);
    widget.deliveryFeeController.addListener(_notifyParent);
  }

  @override
  void dispose() {
    widget.storeNameController.removeListener(_notifyParent);
    widget.deliveryPlaceController.removeListener(_notifyParent);
    widget.targetPriceController.removeListener(_notifyParent);
    widget.deliveryFeeController.removeListener(_notifyParent);
    super.dispose();
  }

  void _notifyParent() {
    widget.onSaved({
      'storeName': widget.storeNameController.text,
      'deliveryPlace': widget.deliveryPlaceController.text,
      'targetPrice': widget.targetPriceController.text,
      'deliveryFee': widget.deliveryFeeController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchFieldRow(
            label: '가게 이름',
            controller: widget.storeNameController,
            validatorMessage: '가게 이름을 입력해 주세요.',
            hint: '가게 이름을 입력하세요',
            target: DeliverySearchTarget.store,
          ),
          const SizedBox(height: 20),
          _buildSearchFieldRow(
            label: '배달 장소',
            controller: widget.deliveryPlaceController,
            validatorMessage: '배달 장소를 입력해 주세요.',
            hint: '배달 받을 장소를 입력하세요',
            target: DeliverySearchTarget.delivery,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PlaceSearchList(
              places: _places,
              isLoading: _isSearching,
              hasSearched: _hasSearched,
              onPlaceTap: (place) {
                setState(() => _pendingSelection = place);
              },
            ),
          ),
          if (_pendingSelection != null) ...[
            const SizedBox(height: 12),
            _SelectionCard(
              place: _pendingSelection!,
              onConfirm: _applySelection,
              onCancel: () => setState(() => _pendingSelection = null),
            ),
          ],
          const SizedBox(height: 20),
          _buildLabel('최소 주문 금액'),
          TextFormField(
            controller: widget.targetPriceController,
            decoration: _inputDecoration('숫자만 입력'),
            keyboardType: TextInputType.number,
            validator: (value) =>
                value!.trim().isEmpty ? '최소 주문 금액을 입력해 주세요.' : null,
          ),
          const SizedBox(height: 20),
          _buildLabel('배달비'),
          TextFormField(
            controller: widget.deliveryFeeController,
            decoration: _inputDecoration('숫자만 입력'),
            keyboardType: TextInputType.number,
            validator: (value) => value!.trim().isEmpty ? '배달비를 입력해 주세요.' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFieldRow({
    required String label,
    required TextEditingController controller,
    required String validatorMessage,
    required String hint,
    required DeliverySearchTarget target,
  }) {
    final isActive = _activeTarget == target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: _inputDecoration(hint),
                validator: (value) =>
                    value!.trim().isEmpty ? validatorMessage : null,
              ),
            ),
            const SizedBox(width: 12),
            _SearchButton(
              isActive: isActive,
              onTap: () => _handleSearch(target),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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

  Future<void> _handleSearch(DeliverySearchTarget target) async {
    final controller = target == DeliverySearchTarget.store
        ? widget.storeNameController
        : widget.deliveryPlaceController;
    final keyword = controller.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (keyword.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('검색할 키워드를 입력해 주세요.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _activeTarget = target;
      _isSearching = true;
      _hasSearched = true; // 검색 실행 표시
      _pendingSelection = null;
    });

    try {
      final results = await PlaceSearchApi.searchPlace(keyword: keyword);
      if (!mounted) return;
      setState(() => _places = results);
      if (results.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('검색 결과가 없습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('장소 검색에 실패했습니다. 다시 시도해주세요.'),
          duration: _snackDuration,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _applySelection() {
    final place = _pendingSelection;
    if (place == null) return;

    if (_activeTarget == DeliverySearchTarget.store) {
      widget.storeNameController.text = place.name;
      widget.onStorePlaceSelected?.call(place);
    } else {
      widget.deliveryPlaceController.text =
          place.address.isNotEmpty ? place.address : place.name;
      widget.onDeliveryPlaceSelected?.call(place);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${place.name}을(를) 적용했습니다.')),
    );

    setState(() => _pendingSelection = null);
  }
}

class _SearchButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _SearchButton({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF81C784) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          Icons.search,
          color: isActive ? Colors.white : Colors.grey[600],
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final Place place;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _SelectionCard({
    required this.place,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              place.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              place.address.isEmpty ? '주소 정보가 없습니다.' : place.address,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C784),
                  ),
                  child: const Text('선택하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum DeliverySearchTarget { store, delivery }
