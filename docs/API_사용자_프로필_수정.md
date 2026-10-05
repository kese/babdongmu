# 사용자 프로필 수정 API 명세서

## 개요
사용자가 "내 정보 수정" 페이지에서 프로필 정보를 수정할 때 사용하는 API입니다.

---

## 1. 프로필 정보 수정 API

### 기본 정보
- **엔드포인트**: `PUT /api/user/profile`
- **인증**: 필수 (Bearer Token)
- **Content-Type**: `application/json`

### 요청 헤더
```http
Authorization: Bearer {access_token}
Content-Type: application/json
```

### 요청 본문 (JSON)
모든 필드는 **선택적(optional)**입니다. 변경하고 싶은 필드만 포함하면 됩니다.

```json
{
  "name": "홍길동",
  "nickname": "길동이",
  "phone": "+821000000000",
  "email": "user@example.com",
  "address": "충북 충주시 대학로 50",
  "account": "0000000000"
}
```

### 필드 설명

| 필드 | 타입 | 필수 | 설명 | 예시 |
|------|------|------|------|------|
| `name` | String | X | 사용자 실명 | "홍길동" |
| `nickname` | String | X | 앱에서 사용할 닉네임 | "길동이" |
| `phone` | String | X | 전화번호 (국제 형식) | "+821000000000" |
| `email` | String | X | 이메일 주소 | "user@example.com" |
| `address` | String | X | 주소 | "충북 충주시 대학로 50" |
| `account` | String | X | 계좌번호 (포인트 출금용) | "0000000000" |

### 전화번호 형식
- 클라이언트에서 자동으로 `+82` 형식으로 정규화하여 전송합니다
- 입력 예시는 예약된 테스트 번호 `000-0000-0000`을 사용합니다.
- 서버는 `+82`로 시작하는 형식을 받습니다

### 요청 예시

#### 예시 1: 이름만 변경
```json
PUT /api/user/profile
{
  "name": "김철수"
}
```

#### 예시 2: 닉네임과 전화번호 변경
```json
PUT /api/user/profile
{
  "nickname": "철수짱",
  "phone": "+821000000000"
}
```

#### 예시 3: 모든 정보 변경
```json
PUT /api/user/profile
{
  "name": "김철수",
  "nickname": "철수짱",
  "phone": "+821000000000",
  "email": "chulsoo@example.com",
  "address": "충북 충주시 교현동 123-45",
  "account": "0000000000"
}
```

### 응답

#### 성공 (200 OK)
```json
{
  "success": true,
  "message": "프로필이 수정되었습니다",
  "data": {
    "id": 123,
    "email": "user@example.com",
    "name": "홍길동",
    "nickname": "길동이",
    "phone": "+821000000000",
    "address": "충북 충주시 대학로 50",
    "account": "0000000000",
    "profile_image": "https://example.com/uploads/profile/abc123.jpg",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-11-30T12:00:00Z"
  }
}
```

#### 실패 (400 Bad Request)
```json
{
  "success": false,
  "message": "닉네임은 2자 이상이어야 합니다"
}
```

#### 실패 (401 Unauthorized)
```json
{
  "success": false,
  "message": "인증이 필요합니다"
}
```

---

## 2. 비밀번호 변경 API

### 기본 정보
- **엔드포인트**: `PUT /api/user/password`
- **인증**: 필수 (Bearer Token)
- **Content-Type**: `application/json`

### 요청 헤더
```http
Authorization: Bearer {access_token}
Content-Type: application/json
```

### 요청 본문 (JSON)
```json
{
  "current_password": "OldPass123!@#",
  "new_password": "NewPass456!@#"
}
```

### 필드 설명

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `current_password` | String | O | 현재 비밀번호 |
| `new_password` | String | O | 새 비밀번호 (영문, 숫자, 특수문자 포함 8자 이상) |

### 비밀번호 유효성 규칙
- **최소 8자 이상**
- **영문 대소문자 포함**
- **숫자 포함**
- **특수문자 포함** (`@$!%*#?&`)

정규식: `^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$`

### 응답

#### 성공 (200 OK)
```json
{
  "success": true,
  "message": "비밀번호가 변경되었습니다"
}
```

#### 실패 (400 Bad Request)
```json
{
  "success": false,
  "message": "현재 비밀번호가 일치하지 않습니다"
}
```

---

## 3. 프로필 이미지 업로드 API

### 기본 정보
- **엔드포인트**: `POST /api/user/profile/image`
- **인증**: 필수 (Bearer Token)
- **Content-Type**: `multipart/form-data`

### 요청 헤더
```http
Authorization: Bearer {access_token}
Content-Type: multipart/form-data
```

### 요청 본문 (Form Data)
```
image: [파일]
```

### 필드 설명

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `image` | File | O | 이미지 파일 (JPG, PNG, GIF) |

### 이미지 제약사항
- **최대 크기**: 10MB
- **지원 형식**: JPG, JPEG, PNG, GIF
- **권장 해상도**: 1024x1024 이하 (클라이언트에서 자동 리사이징)
- **압축률**: 85% (클라이언트에서 자동 압축)

### 요청 예시 (cURL)
```bash
curl -X POST https://api.example.com/api/user/profile/image \
  -H "Authorization: Bearer {access_token}" \
  -F "image=@/path/to/profile.jpg"
```

### 응답

#### 성공 (200 OK)
```json
{
  "success": true,
  "message": "프로필 이미지가 업로드되었습니다",
  "data": {
    "image_url": "https://example.com/uploads/profile/user123_20241130120000.jpg"
  }
}
```

#### 실패 (400 Bad Request)
```json
{
  "success": false,
  "message": "이미지 파일만 업로드 가능합니다"
}
```

#### 실패 (413 Payload Too Large)
```json
{
  "success": false,
  "message": "파일 크기는 10MB를 초과할 수 없습니다"
}
```

---

## 4. 회원 탈퇴 API

### 기본 정보
- **엔드포인트**: `DELETE /api/user/account`
- **인증**: 필수 (Bearer Token)

### 요청 헤더
```http
Authorization: Bearer {access_token}
```

### 요청 본문
없음 (Body 없이 DELETE 요청)

### 응답

#### 성공 (200 OK)
```json
{
  "success": true,
  "message": "회원 탈퇴가 완료되었습니다"
}
```

#### 실패 (401 Unauthorized)
```json
{
  "success": false,
  "message": "인증이 필요합니다"
}
```

### 주의사항
- 회원 탈퇴 시 **모든 사용자 데이터가 삭제**됩니다
- 삭제된 데이터는 **복구할 수 없습니다**
- 탈퇴 후 클라이언트는 자동으로 로그인 화면으로 이동합니다

---

## 5. 사용자 프로필 조회 API

### 기본 정보
- **엔드포인트**: `GET /api/user/profile`
- **인증**: 필수 (Bearer Token)

### 요청 헤더
```http
Authorization: Bearer {access_token}
```

### 응답

#### 성공 (200 OK)
```json
{
  "success": true,
  "data": {
    "id": 123,
    "email": "user@example.com",
    "name": "홍길동",
    "nickname": "길동이",
    "phone": "+821000000000",
    "address": "충북 충주시 대학로 50",
    "account": "0000000000",
    "profile_image": "https://example.com/uploads/profile/abc123.jpg",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-11-30T12:00:00Z"
  }
}
```

---

## 6. 클라이언트 구현 흐름

### 프로필 수정 페이지 진입 시
1. `GET /api/user/profile` 호출하여 현재 정보 불러오기
2. 폼 필드에 현재 값 채우기

### 완료 버튼 클릭 시
1. **프로필 이미지가 변경된 경우**:
   - `POST /api/user/profile/image` 호출
   - 응답에서 `image_url` 받기

2. **비밀번호가 입력된 경우**:
   - `PUT /api/user/password` 호출

3. **프로필 정보 수정**:
   - `PUT /api/user/profile` 호출
   - 변경된 필드만 포함하여 전송

4. 모든 API 호출 성공 시:
   - 성공 메시지 표시
   - 이전 페이지로 돌아가기

### 에러 처리
- 각 API 호출 실패 시 즉시 중단하고 에러 메시지 표시
- 네트워크 오류 시 재시도 옵션 제공

---

## 7. 보안 고려사항

### 인증
- 모든 API는 Bearer Token 인증 필수
- 토큰 만료 시 401 응답, 클라이언트는 로그인 화면으로 이동

### 비밀번호
- 비밀번호는 **절대 평문으로 저장하지 않음**
- bcrypt 또는 Argon2 등 안전한 해시 알고리즘 사용
- 현재 비밀번호 검증 필수

### 이미지 업로드
- 파일 확장자 검증
- MIME 타입 검증
- 파일 크기 제한 (10MB)
- 악성 파일 스캔 권장

### 전화번호
- 국제 형식 (+82) 사용
- 중복 전화번호 허용 여부는 비즈니스 로직에 따라 결정

---

## 8. 테스트 시나리오

### 정상 케이스
- [ ] 이름만 변경
- [ ] 닉네임만 변경
- [ ] 전화번호만 변경
- [ ] 여러 필드 동시 변경
- [ ] 프로필 이미지 업로드
- [ ] 비밀번호 변경
- [ ] 회원 탈퇴

### 예외 케이스
- [ ] 토큰 없이 요청
- [ ] 만료된 토큰으로 요청
- [ ] 잘못된 비밀번호로 변경 시도
- [ ] 10MB 초과 이미지 업로드
- [ ] 지원하지 않는 파일 형식 업로드
- [ ] 빈 값으로 필수 필드 변경 시도

---

## 9. 참고 코드

### 클라이언트 코드 위치
- **프로필 수정 페이지**: `lib/pages/edit_profile_page.dart`
- **API 호출 로직**: `lib/services/user_api.dart`
- **사용자 모델**: `lib/models/user_data.dart`

### 주요 함수
```dart
// 프로필 정보 수정
UserApi.updateUserProfile(
  name: "홍길동",
  nickname: "길동이",
  phone: "+821000000000",
)

// 비밀번호 변경
UserApi.changePassword(
  currentPassword: "old123!@#",
  newPassword: "new456!@#",
)

// 프로필 이미지 업로드
UserApi.uploadProfileImage(
  imagePath: "/path/to/image.jpg",
)

// 회원 탈퇴
UserApi.deleteAccount(password: "")
```

---

## 10. 변경 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| 2024-11-30 | 1.0 | 초안 작성 | - |

---

## 문의사항
API 구현 관련 문의사항은 백엔드 개발팀에 전달해주세요.
