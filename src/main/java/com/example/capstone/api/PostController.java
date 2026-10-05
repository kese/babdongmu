package com.example.capstone.api;

import com.example.capstone.dto.post.JoinResponseDto;
import com.example.capstone.dto.post.PostCreateRequestDto;
import com.example.capstone.dto.post.PostCreateResponseDto;
import com.example.capstone.dto.post.PostDetailResponseDto;
import com.example.capstone.dto.post.PostListResponseDto;
import com.example.capstone.dto.post.PostUpdateRequestDto;
import com.example.capstone.service.PostService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1")
@Tag(name = "Post", description = "모집 게시글 CRUD 및 참여 관련 API")
public class PostController {

    private final PostService postService;

    @Operation(
        summary = "게시글 생성",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더가 반드시 포함되어야 합니다.
            - `postType` 값에 따라 `deliveryDetail` 또는 `meetDetail` 블록이 필수입니다.
            - 작성자는 자동으로 게시글 참여자 및 채팅방 참가자로 등록됩니다.

            ### 성공 응답
            - 생성된 게시글 ID(`postId`)와 연결된 채팅방 ID(`chatRoomId`)를 반환합니다.
            - HTTP 200 OK

            ### 실패 케이스 예시
            - 잘못된 모집 유형: 400 Bad Request
            - 필수 상세 정보 누락: 400 Bad Request
            - 사용자 미존재: 404 Not Found
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "게시글 생성 성공",
            content = @Content(schema = @Schema(implementation = PostCreateResponseDto.class))),
        @ApiResponse(responseCode = "400", description = "요청 본문 검증 실패, 잘못된 모집 유형, 모집 조건 위반"),
        @ApiResponse(responseCode = "401", description = "인증 실패 (JWT 누락 또는 만료)"),
        @ApiResponse(responseCode = "404", description = "사용자를 찾을 수 없음")
    })
    @io.swagger.v3.oas.annotations.parameters.RequestBody(
        description = "게시글 생성 요청 본문",
        required = true,
        content = @Content(
            mediaType = "application/json",
            schema = @Schema(implementation = PostCreateRequestDto.class),
            examples = {
                @ExampleObject(
                    name = "배달 모집",
                    value = """
                        {
                          "postType": "delivery",
                          "title": "맥도날드 단체 주문",
                          "content": "밤 10시까지 주문받습니다.",
                          "maxParticipants": 4,
                          "deliveryDetail": {
                            "restaurantName": "맥도날드",
                                                        "deliveryAddress": "서울시 중구 세종대로 110",
                            "deliveryFee": 4000,
                            "orderLink": "https://order.example.com/123"
                          }
                        }
                        """
                ),
                @ExampleObject(
                    name = "모임 모집",
                    value = """
                        {
                          "postType": "meet",
                          "title": "스터디 모임",
                          "content": "토요일 오후 2시에 스터디합니다.",
                          "maxParticipants": 6,
                          "meetDetail": {
                            "meetingPlace": "강남역 2번 출구 카페",
                            "meetingTime": "2025-04-25T14:00:00"
                          }
                        }
                        """
                )
            }
        )
    )
    @PostMapping("/posts")
    public ResponseEntity<PostCreateResponseDto> createPost(@Valid @RequestBody PostCreateRequestDto request,
                                                            @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        PostCreateResponseDto response = postService.createPost(request, userId);
        return ResponseEntity.ok(response);
    }

    @Operation(
        summary = "전체 게시글 목록 조회",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 상태가 `ACTIVE`인 게시글만 최신순으로 반환합니다.

            ### 응답 필드 하이라이트
            - `currentParticipants`: 현재 참가 인원수
            - `deliveryFeePerPerson`: 배달 모집일 경우 1인당 예상 배달비
            - `meetingTime`, `meetingPlace`: 모임 모집 정보
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "게시글 목록 조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "403", description = "접근 권한 없음")
    })
    @GetMapping("/posts")
    public List<PostListResponseDto> getPosts() {
        return postService.findAllPosts();
    }

    @Operation(
        summary = "단일 게시글 상세 조회",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 경로 변수 `postId`에 조회할 게시글 ID를 전달합니다.

            ### 응답 구성
            - 게시글 메타 정보
            - 모집 상세(배달/모임)
            - 참여자 목록과 역할(`CREATOR`/`MEMBER`)
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader"),
        @Parameter(name = "postId", description = "조회할 게시글 ID", example = "42")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "게시글 상세 조회 성공",
            content = @Content(schema = @Schema(implementation = PostDetailResponseDto.class))),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "404", description = "게시글을 찾을 수 없음")
    })
    @GetMapping("/posts/{postId}")
    public PostDetailResponseDto getPostById(@PathVariable Long postId) {
        return postService.findPostById(postId);
    }

    @Operation(
        summary = "게시글 참여",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 경로 변수 `postId`에 참여할 게시글 ID 전달

            ### 동작
            - 정원이 가득 찬 경우 400 Bad Request를 응답합니다.
            - 이미 참여한 사용자인 경우 400 Bad Request
            - 성공 시 최신 참여 인원 수를 내려줍니다.
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader"),
        @Parameter(name = "postId", description = "참여할 게시글 ID", example = "42")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "게시글 참여 성공",
            content = @Content(schema = @Schema(implementation = JoinResponseDto.class))),
    @ApiResponse(responseCode = "400", description = "모집 조건 미충족 또는 중복 참여"),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "404", description = "게시글을 찾을 수 없음")
    })
    @PostMapping("/posts/{postId}/join")
    public JoinResponseDto joinPost(@PathVariable Long postId,
                                    @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        return postService.joinPost(postId, userId);
    }

    @Operation(
        summary = "게시글 수정",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 작성자 본인만 수정 가능합니다. 권한이 없으면 400 Bad Request로 처리됩니다.
            - `postType`에 따라 상세 정보(`deliveryDetail` 또는 `meetDetail`) 필수 여부가 유지됩니다.

            ### 응답
            - 본문 없이 204 No Content 반환
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader"),
        @Parameter(name = "postId", description = "수정할 게시글 ID", example = "42")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "204", description = "게시글 수정 성공"),
    @ApiResponse(responseCode = "400", description = "검증 실패 또는 권한 부족"),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "404", description = "게시글을 찾을 수 없음")
    })
    @io.swagger.v3.oas.annotations.parameters.RequestBody(
        description = "게시글 수정 요청 본문",
        required = true,
        content = @Content(
            mediaType = "application/json",
            schema = @Schema(implementation = PostUpdateRequestDto.class),
            examples = @ExampleObject(
                name = "수정 예시",
                value = """
                    {
                      "title": "모집 글 제목 수정",
                      "content": "내용을 이렇게 변경합니다.",
                      "maxParticipants": 5,
                      "meetDetail": {
                        "meetingPlace": "을지로 입구 카페",
                        "meetingTime": "2025-05-01T19:30:00"
                      }
                    }
                    """
            )
        )
    )
    @PutMapping("/posts/{postId}")
    public ResponseEntity<Void> updatePost(@PathVariable Long postId,
                                           @Valid @RequestBody PostUpdateRequestDto request,
                                           @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        postService.updatePost(postId, request, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(
        summary = "게시글 삭제",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 작성자 본인만 삭제 가능하며, 권한이 없으면 400 Bad Request로 처리됩니다.
            - 내부적으로 상태를 `DELETED`로 변경합니다.

            ### 응답
            - 본문 없이 204 No Content 반환
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader"),
        @Parameter(name = "postId", description = "삭제할 게시글 ID", example = "42")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "204", description = "게시글 삭제 성공"),
    @ApiResponse(responseCode = "400", description = "권한 부족"),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "404", description = "게시글을 찾을 수 없음")
    })
    @DeleteMapping("/posts/{postId}")
    public ResponseEntity<Void> deletePost(@PathVariable Long postId,
                                           @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        postService.deletePost(postId, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(
        summary = "모집 상태 변경",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 게시글 작성자 또는 채팅방 방장만 모집 상태를 변경할 수 있습니다.
            - 게시글 상태를 `ACTIVE`에서 `CLOSED`로 변경하여 새 참여자를 방지합니다.

            ### 응답
            - 본문 없이 204 No Content 반환
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader"),
        @Parameter(name = "postId", description = "모집을 마감할 게시글 ID", example = "42")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "204", description = "모집 상태 변경 성공"),
        @ApiResponse(responseCode = "400", description = "권한 부족 또는 이미 마감된 게시글"),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "404", description = "게시글을 찾을 수 없음")
    })
    @PostMapping("/posts/{postId}/close")
    public ResponseEntity<Void> closeRecruitment(@PathVariable Long postId,
                                                  @Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        postService.closeRecruitment(postId, userId);
        return ResponseEntity.noContent().build();
    }

    @Operation(
        summary = "내가 작성한 게시글 조회",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 로그인 사용자가 작성한 게시글을 최신순으로 제공합니다.
            - 삭제(`DELETED`)된 게시글은 제외됩니다.
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "내가 작성한 게시글 조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @GetMapping("/posts/my-posts")
    public List<PostListResponseDto> getMyPosts(@Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        return postService.findMyPosts(userId);
    }

    @Operation(
        summary = "내가 참여한 게시글 조회",
        description = """
            ### 사용 방법
            - `Authorization: Bearer {JWT}` 헤더 필요
            - 작성자가 아닌 순수 참여자로 속한 게시글만 반환합니다.
            - 최신순 정렬
            """,
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @Parameters({
        @Parameter(ref = "#/components/parameters/AuthorizationHeader")
    })
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "내가 참여한 게시글 조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @GetMapping("/posts/my-joined-posts")
    public List<PostListResponseDto> getMyJoinedPosts(@Parameter(hidden = true) @AuthenticationPrincipal Long userId) {
        return postService.findMyJoinedPosts(userId);
    }
}
