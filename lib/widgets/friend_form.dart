import 'package:flutter/material.dart';

import '../models/place_data.dart';
import '../services/place_search_api.dart';
import 'place_search_list.dart';

class FriendForm extends StatefulWidget {
  final TextEditingController meetingPlaceController;
  final Function(String) onSaved;
  final Function(Place)? onPlaceSelected;

  const FriendForm({
    super.key,
    required this.meetingPlaceController,
    required this.onSaved,
    this.onPlaceSelected,
  });

  @override
  State<FriendForm> createState() => _FriendFormState();
}

class _FriendFormState extends State<FriendForm> {
  final _formKey = GlobalKey<FormState>();
  final _snackDuration = const Duration(seconds: 2);

  List<Place> _places = const [];
  bool _isSearching = false;
  bool _hasSearched = false; // 검색 실행 여부
  Place? _pendingSelection;

  @override
  void initState() {
    super.initState();
    widget.meetingPlaceController.addListener(_notifyParent);
  }

  @override
  void dispose() {
    widget.meetingPlaceController.removeListener(_notifyParent);
    super.dispose();
  }

  void _notifyParent() {
    widget.onSaved(widget.meetingPlaceController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('음식점'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.meetingPlaceController,
                  decoration: _inputDecoration('음식점을 입력하세요.'),
                  validator: (value) =>
                      value!.trim().isEmpty ? '음식점을 입력해 주세요' : null,
                ),
              ),
              const SizedBox(width: 12),
              _SearchButton(onTap: _handleSearch),
            ],
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
        ],
      ),
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

  Future<void> _handleSearch() async {
    final keyword = widget.meetingPlaceController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (keyword.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('검색할 키워드를 입력해 주세요.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
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

    widget.meetingPlaceController.text =
        place.address.isNotEmpty ? place.address : place.name;

    widget.onPlaceSelected?.call(place);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${place.name}을(를) 적용했습니다.')),
    );

    setState(() => _pendingSelection = null);
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF81C784),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
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
