package com.example.capstone.api;

import com.example.capstone.dto.ApiEnvelope;
import com.example.capstone.dto.LoginRequest;
import com.example.capstone.dto.SignupRequest;
import com.example.capstone.dto.TokenResponseDto;
import com.example.capstone.dto.user.ProfileImageResponse;
import com.example.capstone.service.AuthService;
import com.example.capstone.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.dao.DataIntegrityViolationException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "인증 API", description = "회원가입과 로그인 등 사용자 인증 관련 API")
public class AuthController {

    private final AuthService authService;
    private final UserService userService;

    @Operation(summary = "회원가입", description = "새로운 사용자 계정을 생성합니다.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "202", description = "회원가입 요청 접수 (계정 존재 여부를 노출하지 않음)",
            content = @Content(schema = @Schema(implementation = ApiEnvelope.class))),
        @ApiResponse(responseCode = "400", description = "잘못된 요청 형식")
    })
    @PostMapping("/signup")
    public ResponseEntity<ApiEnvelope<Void>> signup(
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                description = "회원가입 요청 정보",
                required = true,
                content = @Content(
                    schema = @Schema(implementation = SignupRequest.class),
                    examples = {
                        @ExampleObject(
                            name = "기본 회원가입",
                            value = """
                                {
                                  "email": "user@example.com",
                                  "password": "password123",
                                  "username": "홍길동",
                                  "nickname": "길동이",
                                  "phoneNumber": "+821000000000"
                                }
                                """
                        )
                    }
                )
            )
            @Valid @RequestBody SignupRequest request) {
        try {
            authService.signup(request);
        } catch (DataIntegrityViolationException ignored) {
            // Keep account existence private; duplicate identifiers receive the same response.
        }
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(
                ApiEnvelope.ok("가입 요청이 처리되었습니다. 가입된 계정이면 로그인해 주세요.", null)
        );
    }

    @Operation(summary = "로그인", description = "이메일과 비밀번호로 로그인합니다.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "로그인 성공",
            content = @Content(schema = @Schema(implementation = TokenResponseDto.class))),
        @ApiResponse(responseCode = "401", description = "인증 실패 (이메일 또는 비밀번호 불일치)"),
        @ApiResponse(responseCode = "404", description = "사용자를 찾을 수 없음")
    })
    @PostMapping("/login")
    public ResponseEntity<TokenResponseDto> login(
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                description = "로그인 요청 정보",
                required = true,
                content = @Content(
                    schema = @Schema(implementation = LoginRequest.class),
                    examples = @ExampleObject(
                        name = "기본 로그인",
                        value = """
                            {
                              "email": "user@example.com",
                              "password": "password123"
                            }
                            """
                    )
                )
            )
            @Valid @RequestBody LoginRequest request) {
        TokenResponseDto response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "회원가입용 프로필 이미지 업로드", 
               description = "회원가입 전 프로필 이미지를 미리 업로드합니다. 인증이 필요하지 않습니다. 반환된 URL을 회원가입 요청의 profileImageUrl 필드에 포함하세요.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "이미지 업로드 성공",
            content = @Content(schema = @Schema(implementation = ProfileImageResponse.class))),
        @ApiResponse(responseCode = "400", description = "잘못된 파일 형식 또는 파일 없음"),
        @ApiResponse(responseCode = "413", description = "파일 크기 초과 (10MB)")
    })
    @PostMapping(value = "/upload-profile-image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiEnvelope<ProfileImageResponse>> uploadProfileImageForSignup(
            @Parameter(description = "프로필 이미지 파일 (JPG, PNG, GIF, 최대 10MB)") 
            @RequestParam("image") MultipartFile image) {
        ProfileImageResponse response = userService.uploadProfileImageForSignup(image);
        return ResponseEntity.ok(ApiEnvelope.ok("프로필 이미지가 업로드되었습니다", response));
    }
}


