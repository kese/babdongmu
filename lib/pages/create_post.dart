import 'package:flutter/material.dart';
import '../models/create_post_data.dart';
import '../services/api.dart';
import '../widgets/delivery_form_new.dart';
import '../widgets/friend_form.dart';
import 'package:delivery/utils/logging.dart';

/// '게시글 작성' 기능을 담당하는 전체 페이지 위젯
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _postData = CreatePostData();

  final _titleController = TextEditingController();
  final _storeNameController = TextEditingController(); // 배달 폼 전용 '가게 이름' 컨트롤러
  final _deliveryPlaceController = TextEditingController(); // 배달 폼 전용 컨트롤러
  final _meetingPlaceController = TextEditingController(); // 친구 폼 전용 컨트롤러
  final _targetPriceController = TextEditingController(); // 배달 폼 전용 컨트롤러
  final _deliveryFeeController = TextEditingController(); // 배달 폼 전용 컨트롤러
  final _detailsController = TextEditingController(); // 공통 컨트롤러

  bool _isLoading = false;

  @override
  void dispose() {
    // 메모리 누수 방지를 위해 컨트롤러를 정리
    _titleController.dispose();
    _storeNameController.dispose();
    _deliveryPlaceController.dispose();
    _meetingPlaceController.dispose();
    _targetPriceController.dispose();
    _deliveryFeeController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<String?> _getUserNickname() async {
    return ApiService.getUserNickname();
  }

  /// '완료' 버튼을 눌렀을 때 폼을 제출하고 API를 호출하는 함수
  Future<void> _submitForm() async {
    // 폼의 모든 validator를 실행하여 유효한지 확인
    if (!_formKey.currentState!.validate()) {
      return; // 유효하지 않으면 종료
    }
    // onSaved 콜백을 실행하여 입력된 값들을 _postData 모델에 저장
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      //로그인한 사용자의 닉네임 조회
      final userName = await _getUserNickname();
      // 위 await 이후에는 위젯이 dispose 되었을 수 있으므로 마운트 여부 확인
      if (!mounted) return;
      if (userName == null) {
        // 로그인 정보가 없으면 에러 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없습니다. 다시 로그인해주세요.')),
        );
        return;
      }

      if (_postData.type == PostType.delivery) {
        // 서버 요구 형식에 맞게 데이터 구성
        final poiName = _postData.deliveryPoiName?.trim();
        await PostApi.createDeliveryPost(
          title: _postData.title,
          details: _postData.details ?? '',
          storeName: _postData.storeName!,
          deliveryLatitude: _postData.deliveryLatitude,
          deliveryLongitude: _postData.deliveryLongitude,
          orderLink: '',
          targetPrice: int.tryParse(_postData.targetPrice ?? '0') ?? 0,
          deliveryFee: int.tryParse(_postData.deliveryFee ?? '0') ?? 0,
          maxPeople: _postData.maxPeople!,
          deadline: _postData.deadline!,
          locationName: poiName, // POI 순수명만 (없으면 null)
          locationLatitude: _postData.deliveryLatitude,
          locationLongitude: _postData.deliveryLongitude,
        );
      } else {
        await PostApi.createFriendPost(
          title: _postData.title,
          details: _postData.details ?? '',
          meetingPlace:
              _postData.meetingPlace ??
              '', // UI상 '음식점'으로 입력받은 값을 meetingPlace로 전송
          meetingLatitude: _postData.meetingLatitude,
          meetingLongitude: _postData.meetingLongitude,
          maxPeople: _postData.maxPeople!,
          deadline: _postData.deadline!,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true); // 작성이 완료되면 이전 화면으로 돌아감
    } catch (e) {
      // API 호출 실패 시 에러 처리
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('게시글을 만들지 못했습니다. 다시 시도해주세요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 마감 시간 선택을 위한 Date & Time Picker를 띄우는 함수
  Future<void> _selectDeadline(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _postData.deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (pickedDate == null) return;

    final today =
        pickedDate.year == now.year &&
        pickedDate.month == now.month &&
        pickedDate.day == now.day;

    if (!context.mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_postData.deadline ?? DateTime.now()),
    );
    if (pickedTime == null) return;

    if (!mounted) return;

    if (today) {
      final selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('현재 시간 이후를 선택해주세요.')),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _postData.deadline = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _postData.type == PostType.delivery ? '배달 그룹 모집' : '식사 그룹 모집',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitForm,
            child: const Text(
              '완료',
              style: TextStyle(
                color: Color(0xFF81C784),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF81C784)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 공통 UI 1: 게시글 유형
                    _buildLabel('게시글 유형'),
                    _buildDropdown<PostType>(
                      value: _postData.type,
                      items: PostType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type == PostType.delivery ? '배달' : '식사'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _postData.type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 공통 UI 2: 제목
                    _buildLabel('제목'),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration('제목을 입력하세요'),
                      validator: (value) =>
                          value!.trim().isEmpty ? '제목을 입력해주세요.' : null,
                      onSaved: (value) => _postData.title = value!,
                    ),
                    const SizedBox(height: 24),

                    if (_postData.type == PostType.delivery)
                      DeliveryFormNew(
                        storeNameController: _storeNameController,
                        deliveryPlaceController: _deliveryPlaceController,
                        targetPriceController: _targetPriceController,
                        deliveryFeeController: _deliveryFeeController,
                        onSaved: (data) {
                          _postData.storeName = data['storeName'];
                          _postData.deliveryPlace =
                              data['deliveryPlace']; // UI 표시용
                          _postData.deliveryPoiName =
                              data['poiName']; // POI 순수명
                          _postData.deliveryRoadAddress = data['roadAddress'];
                          _postData.targetPrice = data['targetPrice'];
                          _postData.deliveryFee = data['deliveryFee'];
                        },
                        onStorePlaceSelected: (place) {
                          _postData.storeLatitude = place.latitude;
                          _postData.storeLongitude = place.longitude;
                        },
                        onDeliveryLocationSelected: (latitude, longitude) {
                          _postData.deliveryLatitude = latitude;
                          _postData.deliveryLongitude = longitude;
                        },
                      )
                    else
                      FriendForm(
                        meetingPlaceController: _meetingPlaceController,
                        onSaved: (meetingPlace) {
                          // 자식 폼에서 데이터를 받아 _postData에 저장
                          _postData.meetingPlace = meetingPlace;
                        },
                        onPlaceSelected: (place) {
                          _postData.meetingLatitude = place.latitude;
                          _postData.meetingLongitude = place.longitude;
                        },
                      ),
                    const SizedBox(height: 24),

                    // 공통 UI 4: 최대 인원, 마감 시간, 상세 내용
                    _buildLabel('최대 인원'),
                    _buildDropdown<int>(
                      value: _postData.maxPeople,
                      hint: '선택',
                      items: List.generate(9, (index) => index + 2)
                          .map(
                            (count) => DropdownMenuItem(
                              value: count,
                              child: Text('$count명'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _postData.maxPeople = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('마감 시간'),
                    TextFormField(
                      readOnly: true,
                      decoration: _inputDecoration('날짜 및 시간 선택').copyWith(
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.grey,
                        ),
                      ),
                      controller: TextEditingController(
                        text: _postData.deadline == null
                            ? ''
                            : '${_postData.deadline!.month}/${_postData.deadline!.day}, ${_postData.deadline!.hour}:${_postData.deadline!.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: () => _selectDeadline(context),
                      validator: (value) =>
                          _postData.deadline == null ? '마감 시간을 선택해주세요.' : null,
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('상세 내용'),
                    TextFormField(
                      controller: _detailsController,
                      decoration: _inputDecoration('상세 내용을 입력하세요 (선택)'),
                      maxLines: 5,
                      maxLength: 300,
                      onSaved: (value) => _postData.details = value,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// 입력창 위의 라벨 UI를 생성
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// DropdownButtonFormField의 공통 UI를 생성
  Widget _buildDropdown<T>({
    required T? value,
    String? hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: _inputDecoration(hint ?? ''),
      validator: (value) => value == null ? '값을 선택해주세요.' : null,
      isExpanded: true,
    );
  }

  /// TextFormField의 공통 디자인(Decoration)을 생성
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
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
