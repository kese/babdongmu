package com.example.capstone.api;

import com.example.capstone.dto.place.PlaceDto;
import com.example.capstone.dto.place.ReverseGeocodeDto;
import com.example.capstone.service.PlacesService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

/**
 * 장소 검색 API
 * - 지도 기반 장소 검색
 * - 카카오맵 API 연동 및 캐싱
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/places")
@RequiredArgsConstructor
public class PlacesController {

    private final PlacesService placesService;

    /**
     * 장소 검색 (GET 방식 - 권장)
     * 
     * @param keyword 검색 키워드 (장소명, 주소 등)
     * @param latitude 사용자 위도 (선택, 거리순 정렬 시 필요)
     * @param longitude 사용자 경도 (선택, 거리순 정렬 시 필요)
     * @param radius 검색 반경 (미터, 기본 20000 = 20km)
     * @return 장소 목록 (배열 직접 반환, 위치 제공 시 거리순 정렬)
     */
    @GetMapping("/search")
    public ResponseEntity<List<PlaceDto>> searchPlaces(
            @RequestParam(name = "keyword") String keyword,
            @RequestParam(name = "latitude", required = false) BigDecimal latitude,
            @RequestParam(name = "longitude", required = false) BigDecimal longitude,
            @RequestParam(name = "radius", required = false, defaultValue = "20000") Integer radius
    ) {
        log.info("GET /api/v1/places/search - keyword: {}, lat: {}, lng: {}, radius: {}", 
                keyword, latitude, longitude, radius);
        
        List<PlaceDto> results = placesService.searchPlaces(keyword, latitude, longitude, radius);
        
        log.info("검색 완료: {} 건", results.size());
        return ResponseEntity.ok(results);
    }

    /**
     * 장소 검색 (POST 방식 - 대안)
     * 
     * @param request 검색 요청 (keyword, latitude, longitude 포함)
     * @return 장소 목록 (배열 직접 반환)
     */
    @PostMapping("/search")
    public ResponseEntity<List<PlaceDto>> searchPlacesPost(
            @RequestBody SearchRequest request
    ) {
        log.info("POST /api/v1/places/search - keyword: {}, lat: {}, lng: {}", 
                request.keyword(), request.latitude(), request.longitude());
        
        List<PlaceDto> results = placesService.searchPlaces(
                request.keyword(), 
                request.latitude(), 
                request.longitude(), 
                request.radius() != null ? request.radius() : 20000
        );
        
        log.info("검색 완료: {} 건", results.size());
        return ResponseEntity.ok(results);
    }

    /**
     * 인기 장소 조회 (선택사항)
     */
    @GetMapping("/popular")
    public ResponseEntity<List<PlaceDto>> getPopularPlaces(
            @RequestParam(name = "limit", defaultValue = "10") int limit
    ) {
        log.info("GET /api/v1/places/popular - limit: {}", limit);
        
        List<PlaceDto> results = placesService.getPopularPlaces(limit);
        
        return ResponseEntity.ok(results);
    }

    /**
     * 장소 상세 조회 (선택사항)
     */
    @GetMapping("/{placeId}")
    public ResponseEntity<PlaceDto> getPlaceById(@PathVariable Long placeId) {
        log.info("GET /api/v1/places/{} ", placeId);
        
        return placesService.getPlaceById(placeId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * 역지오코딩: 좌표 → 주소 변환
     * 
     * @param latitude 위도 (-90 ~ 90)
     * @param longitude 경도 (-180 ~ 180)
     * @return 주소 정보
     */
    @GetMapping("/reverse-geocode")
    public ResponseEntity<ReverseGeocodeDto> reverseGeocode(
            @RequestParam(name = "latitude") BigDecimal latitude,
            @RequestParam(name = "longitude") BigDecimal longitude
    ) {
        log.info("GET /api/v1/places/reverse-geocode - lat: {}, lng: {}", latitude, longitude);
        
        try {
            ReverseGeocodeDto result = placesService.reverseGeocode(latitude, longitude);
            log.info("역지오코딩 성공: {}", result.address());
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            log.warn("역지오코딩 실패 (잘못된 요청): {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("역지오코딩 오류: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * 주변 POI(상호명) 검색
     * 
     * @param latitude 위도
     * @param longitude 경도
     * @param radius 검색 반경 (미터, 기본 100m)
     * @param category 카테고리 코드 (기본: 모든 카테고리)
     * @return POI 정보 + fallback 주소
     */
    @GetMapping("/nearby-poi")
    public ResponseEntity<NearbyPoiDto> searchNearbyPoi(
            @RequestParam(name = "latitude") BigDecimal latitude,
            @RequestParam(name = "longitude") BigDecimal longitude,
            @RequestParam(name = "radius", required = false, defaultValue = "20") Integer radius,
            @RequestParam(name = "category", required = false) String category
    ) {
        log.info("GET /api/v1/places/nearby-poi - lat: {}, lng: {}, radius: {}m, category: {}", 
                latitude, longitude, radius, category);
        
        try {
            NearbyPoiDto result = placesService.searchNearbyPoi(latitude, longitude, radius, category);
            log.info("POI 검색 완료: {}", result.poi() != null ? result.poi().name() : "주소만");
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("POI 검색 오류: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * 검색 요청 DTO (POST 방식용)
     */
    public record SearchRequest(
            String keyword,
            BigDecimal latitude,
            BigDecimal longitude,
            Integer radius
    ) {
    }

    /**
     * POI 정보 DTO
     */
    public record PoiInfo(
            String name,
            String category,
            String address
    ) {
    }

    /**
     * 주변 POI 응답 DTO
     */
    public record NearbyPoiDto(
            PoiInfo poi,
            String fallbackAddress
    ) {
    }
}

