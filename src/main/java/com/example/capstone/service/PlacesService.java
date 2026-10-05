package com.example.capstone.service;

import com.example.capstone.api.PlacesController.NearbyPoiDto;
import com.example.capstone.api.PlacesController.PoiInfo;
import com.example.capstone.domain.place.Place;
import com.example.capstone.dto.place.KakaoPlaceResponse;
import com.example.capstone.dto.place.KakaoReverseGeocodeResponse;
import com.example.capstone.dto.place.PlaceDto;
import com.example.capstone.dto.place.ReverseGeocodeDto;
import com.example.capstone.repository.PlacesRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PlacesService {

    private final PlacesRepository placesRepository;
    private final RestTemplate restTemplate = new RestTemplate();

    // 카카오맵 REST API 키 (주의: JavaScript 키와 다름)
    // https://developers.kakao.com/console/app 에서 "REST API 키" 발급 필요
    // private static final String KAKAO_REST_API_KEY = "change-me";
    private static final String KAKAO_SEARCH_URL = "https://dapi.kakao.com/v2/local/search/keyword.json";
    private static final String KAKAO_REVERSE_GEOCODE_URL = "https://dapi.kakao.com/v2/local/geo/coord2address.json";
    private static final String KAKAO_CATEGORY_URL = "https://dapi.kakao.com/v2/local/search/category.json";

    /**
     * 장소 검색 (위치 기반 또는 키워드만)
     * 
     * @param keyword 검색 키워드 (필수)
     * @param latitude 사용자 위도 (선택, 거리순 정렬 시 필요)
     * @param longitude 사용자 경도 (선택, 거리순 정렬 시 필요)
     * @param radius 검색 반경 (미터, 기본 20000 = 20km)
     */
    @Transactional
    public List<PlaceDto> searchPlaces(String keyword, BigDecimal latitude, BigDecimal longitude, Integer radius) {
        if (keyword == null || keyword.trim().isEmpty()) {
            throw new IllegalArgumentException("검색어를 입력해주세요.");
        }

        boolean hasLocation = (latitude != null && longitude != null);
        log.info("장소 검색 시작: keyword={}, 위치기반={}", keyword, hasLocation);

        // 위치 기반 검색인 경우 캐시 스킵 (거리 계산이 필요하므로)
        if (!hasLocation) {
            // 1. DB 캐시 확인 (키워드 검색만)
            List<Place> cachedPlaces = placesRepository.searchByKeyword(keyword.trim());
            if (!cachedPlaces.isEmpty()) {
                log.info("캐시에서 {}건 조회", cachedPlaces.size());
                cachedPlaces.forEach(Place::incrementSearchCount);
                return cachedPlaces.stream()
                        .map(PlaceDto::from)
                        .collect(Collectors.toList());
            }
        }

        // 2. 카카오맵 API 호출
        log.info("카카오맵 API 호출: keyword={}, lat={}, lng={}, radius={}", 
                keyword, latitude, longitude, radius);
        List<PlaceDto> results = callKakaoMapApi(keyword, latitude, longitude, radius);

        // 3. DB에 저장 (캐싱) - 위치 기반이 아닐 때만
        if (!hasLocation && !results.isEmpty()) {
            saveToCache(results);
            log.info("{}건을 DB에 캐싱", results.size());
        }

        return results;
    }

    /**
     * 카카오맵 REST API 호출 (위치 기반 또는 키워드만)
     */
    private List<PlaceDto> callKakaoMapApi(String keyword, BigDecimal latitude, BigDecimal longitude, Integer radius) {
        try {
            // HTTP 헤더 설정
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + KAKAO_REST_API_KEY);

            // URL 생성
            UriComponentsBuilder builder = UriComponentsBuilder
                    .fromUriString(KAKAO_SEARCH_URL)
                    .queryParam("query", keyword)
                    .queryParam("size", 15); // 최대 15개 결과
            
            // 위치 파라미터 추가 (거리순 정렬)
            if (latitude != null && longitude != null) {
                builder.queryParam("x", longitude.toString()); // 경도
                builder.queryParam("y", latitude.toString());  // 위도
                if (radius != null && radius > 0) {
                    builder.queryParam("radius", radius); // 검색 반경 (미터)
                }
                builder.queryParam("sort", "distance"); // 거리순 정렬
            }
            
            String url = builder.build().toUriString();

            // API 호출
            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<KakaoPlaceResponse> response = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    entity,
                    KakaoPlaceResponse.class
            );

            // 응답 처리
            if (response.getBody() != null && response.getBody().documents() != null) {
                return response.getBody().documents().stream()
                        .map(PlaceDto::fromKakao)
                        .collect(Collectors.toList());
            }

            return new ArrayList<>();

        } catch (Exception e) {
            log.error("카카오맵 API 호출 실패: keyword={}, error={}", keyword, e.getMessage(), e);
            // API 실패 시 빈 배열 반환 (클라이언트에 500 에러 대신 빈 결과 제공)
            return new ArrayList<>();
        }
    }

    /**
     * 검색 결과를 DB에 캐싱
     */
    private void saveToCache(List<PlaceDto> places) {
        places.forEach(dto -> {
            try {
                // 이미 존재하는 경우 업데이트, 없으면 새로 생성
                Optional<Place> existing = placesRepository.findByExternalId(dto.id());
                
                if (existing.isPresent()) {
                    Place place = existing.get();
                    place.updateInfo(
                            dto.name(),
                            dto.category(),
                            dto.address(),
                            dto.address(),
                            dto.phone(),
                            dto.url()
                    );
                    place.incrementSearchCount();
                } else {
                    Place newPlace = Place.builder()
                            .externalId(dto.id())
                            .placeName(dto.name())
                            .category(dto.category())
                            .address(dto.address())
                            .roadAddress(dto.address())
                            .latitude(dto.latitude())
                            .longitude(dto.longitude())
                            .phone(dto.phone())
                            .placeUrl(dto.url())
                            .searchCount(1)
                            .build();
                    placesRepository.save(newPlace);
                }
            } catch (Exception e) {
                log.warn("장소 캐싱 실패: id={}, name={}, error={}", dto.id(), dto.name(), e.getMessage());
            }
        });
    }

    /**
     * 장소 ID로 조회
     */
    @Transactional(readOnly = true)
    public Optional<PlaceDto> getPlaceById(Long placeId) {
        return placesRepository.findById(placeId)
                .map(PlaceDto::from);
    }

    /**
     * 인기 장소 조회
     */
    @Transactional(readOnly = true)
    public List<PlaceDto> getPopularPlaces(int limit) {
        return placesRepository.findPopularPlaces().stream()
                .limit(limit)
                .map(PlaceDto::from)
                .collect(Collectors.toList());
    }

    /**
     * 역지오코딩: 좌표 → 주소 변환
     */
    public ReverseGeocodeDto reverseGeocode(BigDecimal latitude, BigDecimal longitude) {
        // 좌표 유효성 검증
        validateCoordinates(latitude, longitude);

        log.info("역지오코딩 시작: lat={}, lng={}", latitude, longitude);

        try {
            // HTTP 헤더 설정
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + KAKAO_REST_API_KEY);

            // URL 생성 (x=경도, y=위도 주의!)
            String url = UriComponentsBuilder
                    .fromUriString(KAKAO_REVERSE_GEOCODE_URL)
                    .queryParam("x", longitude.toString())
                    .queryParam("y", latitude.toString())
                    .build()
                    .toUriString();

            // API 호출
            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<KakaoReverseGeocodeResponse> response = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    entity,
                    KakaoReverseGeocodeResponse.class
            );

            // 응답 처리
            if (response.getBody() != null && 
                response.getBody().documents() != null && 
                !response.getBody().documents().isEmpty()) {
                
                KakaoReverseGeocodeResponse.Document doc = response.getBody().documents().get(0);
                
                // 도로명 주소 우선, 없으면 지번 주소
                String roadAddress = null;
                String buildingName = null;
                if (doc.roadAddress() != null) {
                    roadAddress = doc.roadAddress().addressName();
                    buildingName = doc.roadAddress().buildingName();
                }

                String jibunAddress = null;
                String region1 = null;
                String region2 = null;
                String region3 = null;
                if (doc.address() != null) {
                    jibunAddress = doc.address().addressName();
                    region1 = doc.address().region1depthName();
                    region2 = doc.address().region2depthName();
                    region3 = doc.address().region3depthName();
                }

                // 기본 주소는 도로명 주소 우선, 없으면 지번 주소
                String primaryAddress = roadAddress != null ? roadAddress : jibunAddress;

                return ReverseGeocodeDto.builder()
                        .address(primaryAddress)
                        .roadAddress(roadAddress)
                        .jibunAddress(jibunAddress)
                        .buildingName(buildingName)
                        .region1depthName(region1)
                        .region2depthName(region2)
                        .region3depthName(region3)
                        .latitude(latitude)
                        .longitude(longitude)
                        .build();
            }

            // 결과가 없는 경우 (바다, 외국 등)
            log.warn("역지오코딩 결과 없음: lat={}, lng={}", latitude, longitude);
            throw new IllegalArgumentException("해당 위치의 주소를 찾을 수 없습니다.");

        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            log.error("역지오코딩 API 호출 실패: lat={}, lng={}, error={}", 
                    latitude, longitude, e.getMessage(), e);
            throw new RuntimeException("주소 변환 중 오류가 발생했습니다.", e);
        }
    }

    /**
     * 주변 POI(상호명) 검색 - 2단계 전략
     * 1단계: 좌표 → 주소 변환
     * 2단계: 주소를 검색어로 + 좌표 반경 필터 → 정밀 POI 검색
     * 
     * @param latitude 위도
     * @param longitude 경도
     * @param radius 검색 반경 (미터, 기본 30m)
     * @param category 카테고리 코드 (사용 안 함, 하위 호환용)
     */
    public NearbyPoiDto searchNearbyPoi(BigDecimal latitude, BigDecimal longitude, Integer radius, String category) {
        validateCoordinates(latitude, longitude);

        // radius 기본값 설정 (30m)
        if (radius == null || radius <= 0) {
            radius = 30;
        }

        log.info("🔍 POI 검색 시작 (2단계 전략): lat={}, lng={}, radius={}m", 
                latitude, longitude, radius);

        PoiInfo poi = null;
        String fallbackAddress = "";

        try {
            // [1단계] 좌표 → 주소 변환
            log.info("📍 1단계: 좌표 → 주소 변환");
            String roadAddress = getRoadAddressFromCoords(latitude, longitude);
            
            if (roadAddress == null || roadAddress.isEmpty()) {
                log.warn("⚠️ 주소를 찾을 수 없음");
                fallbackAddress = String.format("위도 %.4f, 경도 %.4f", 
                        latitude.doubleValue(), longitude.doubleValue());
            } else {
                log.info("✅ 주소 확보: {}", roadAddress);
                fallbackAddress = roadAddress;
                
                // [2단계] 주소 + 좌표 반경으로 POI 검색 ⭐⭐⭐
                log.info("🎯 2단계: 주소 기반 POI 검색 (반경 {}m)", radius);
                poi = searchPoiByAddressAndRadius(roadAddress, latitude, longitude, radius);
                
                if (poi != null) {
                    log.info("🎉 POI 발견 성공: {}", poi.name());
                } else {
                    log.warn("⚠️ POI 못 찾음 (반경 {}m 내)", radius);
                }
            }

        } catch (Exception e) {
            log.error("🔴 2단계 전략 실패: {}", e.getMessage(), e);
        }

        // 2. Fallback: 역지오코딩으로 주소 가져오기
        try {
            ReverseGeocodeDto geocode = reverseGeocode(latitude, longitude);
            fallbackAddress = geocode.address();
            
            // POI가 여전히 없으면 건물명이라도 표시
            if (poi == null) {
                // 건물명이 있으면 사용
                if (geocode.buildingName() != null && !geocode.buildingName().isEmpty()) {
                    poi = new PoiInfo(
                            geocode.buildingName(),
                            "건물",
                            geocode.address()
                    );
                    log.info("✅ 건물명 사용: {}", poi.name());
                }
                // 건물명도 없으면 동/지역명이라도 표시
                else if (geocode.region3depthName() != null && !geocode.region3depthName().isEmpty()) {
                    // "역삼동" 같은 동 이름을 POI처럼 표시
                    String locationName = geocode.region2depthName() + " " + geocode.region3depthName();
                    poi = new PoiInfo(
                            locationName,  // "강남구 역삼동"
                            "지역",
                            geocode.address()
                    );
                    log.info("✅ 지역명 사용: {}", poi.name());
                }
            }
        } catch (Exception e) {
            log.error("역지오코딩도 실패: {}", e.getMessage());
            fallbackAddress = String.format("위도 %.4f, 경도 %.4f", 
                    latitude.doubleValue(), longitude.doubleValue());
        }

        log.info("최종 POI 결과: poi={}, fallback={}", 
                poi != null ? poi.name() : "null", fallbackAddress);

        return new NearbyPoiDto(poi, fallbackAddress);
    }

    /**
     * 좌표 유효성 검증
     */
    private void validateCoordinates(BigDecimal latitude, BigDecimal longitude) {
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException("위도와 경도는 필수입니다.");
        }

        double lat = latitude.doubleValue();
        double lng = longitude.doubleValue();

        if (lat < -90 || lat > 90) {
            throw new IllegalArgumentException("위도는 -90 ~ 90 범위여야 합니다. (입력값: " + lat + ")");
        }

        if (lng < -180 || lng > 180) {
            throw new IllegalArgumentException("경도는 -180 ~ 180 범위여야 합니다. (입력값: " + lng + ")");
        }
    }

    /**
     * [1단계] 좌표로 도로명 주소 가져오기
     */
    private String getRoadAddressFromCoords(BigDecimal latitude, BigDecimal longitude) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + KAKAO_REST_API_KEY);

            String url = UriComponentsBuilder
                    .fromUriString(KAKAO_REVERSE_GEOCODE_URL)
                    .queryParam("x", longitude.toString())
                    .queryParam("y", latitude.toString())
                    .build()
                    .toUriString();

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<KakaoReverseGeocodeResponse> response = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    entity,
                    KakaoReverseGeocodeResponse.class
            );

            if (response.getBody() != null && 
                response.getBody().documents() != null && 
                !response.getBody().documents().isEmpty()) {
                
                KakaoReverseGeocodeResponse.Document doc = response.getBody().documents().get(0);
                
                // 도로명 주소 우선, 없으면 지번 주소
                if (doc.roadAddress() != null && doc.roadAddress().addressName() != null) {
                    return doc.roadAddress().addressName();
                }
                if (doc.address() != null && doc.address().addressName() != null) {
                    return doc.address().addressName();
                }
            }
        } catch (Exception e) {
            log.error("좌표→주소 변환 실패: {}", e.getMessage());
        }
        return null;
    }

    /**
     * [2단계] 주소 + 좌표 반경으로 POI 검색 (핵심 로직)
     * 
     * @param address 1단계에서 얻은 주소 (검색어로 사용)
     * @param latitude 사용자 위도 (반경 중심)
     * @param longitude 사용자 경도 (반경 중심)
     * @param radius 검색 반경 (미터)
     * @return POI 정보 (건물명 등)
     */
    private PoiInfo searchPoiByAddressAndRadius(String address, 
                                                 BigDecimal latitude, 
                                                 BigDecimal longitude, 
                                                 Integer radius) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + KAKAO_REST_API_KEY);

            // keyword search API 사용 (주소를 검색어로)
            String url = UriComponentsBuilder
                    .fromUriString(KAKAO_SEARCH_URL)
                    .queryParam("query", address)  // ⭐ 주소를 검색어로
                    .queryParam("x", longitude.toString())  // ⭐ 반경 중심 경도
                    .queryParam("y", latitude.toString())   // ⭐ 반경 중심 위도
                    .queryParam("radius", radius)           // ⭐ 반경 (미터)
                    .queryParam("sort", "distance")         // ⭐ 거리순 정렬
                    .queryParam("size", 5)  // 상위 5개만 (0번이 가장 가까움)
                    .build()
                    .toUriString();

            log.info("🔎 Keyword Search API 호출: query={}, radius={}m", address, radius);

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<KakaoPlaceResponse> response = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    entity,
                    KakaoPlaceResponse.class
            );

            if (response.getBody() != null && 
                response.getBody().documents() != null && 
                !response.getBody().documents().isEmpty()) {
                
                // 거리순 정렬 → 0번째가 가장 가까운 건물
                var doc = response.getBody().documents().get(0);
                
                log.info("✅ 가장 가까운 POI: {} (거리: {}m)", 
                        doc.placeName(), doc.distance());
                
                return new PoiInfo(
                        doc.placeName(),  // "그린원룸", "GS25 충주점" 등
                        doc.categoryName() != null ? doc.categoryName() : "장소",
                        doc.roadAddressName() != null && !doc.roadAddressName().isEmpty() 
                                ? doc.roadAddressName() 
                                : doc.addressName()
                );
            } else {
                log.warn("검색 결과 없음 (query={}, radius={}m)", address, radius);
            }

        } catch (Exception e) {
            log.error("POI 검색 실패: {}", e.getMessage(), e);
        }
        return null;
    }
}

