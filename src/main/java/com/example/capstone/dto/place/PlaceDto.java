package com.example.capstone.dto.place;

import com.example.capstone.domain.place.Place;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;

import java.math.BigDecimal;

@Builder
public record PlaceDto(
        @JsonProperty("id")
        String id,

        @JsonProperty("name")
        String name,

        @JsonProperty("address")
        String address,

        @JsonProperty("latitude")
        BigDecimal latitude,

        @JsonProperty("longitude")
        BigDecimal longitude,

        @JsonProperty("phone")
        String phone,

        @JsonProperty("category")
        String category,

        @JsonProperty("url")
        String url,

        @JsonProperty("distance")
        Integer distance // 거리 (미터 단위, 위치 기반 검색 시만)
) {
    public static PlaceDto from(Place place) {
        return PlaceDto.builder()
                .id(place.getId() != null ? place.getId().toString() : null)
                .name(place.getPlaceName())
                .address(place.getRoadAddress() != null ? place.getRoadAddress() : place.getAddress())
                .latitude(place.getLatitude())
                .longitude(place.getLongitude())
                .phone(place.getPhone())
                .category(place.getCategory())
                .url(place.getPlaceUrl())
                .distance(null) // 캐시 조회 시에는 거리 정보 없음
                .build();
    }

    public static PlaceDto fromKakao(KakaoPlaceDocument doc) {
        // distance 필드 파싱 (미터 단위)
        Integer distanceInMeters = null;
        if (doc.distance() != null && !doc.distance().isEmpty()) {
            try {
                distanceInMeters = Integer.parseInt(doc.distance());
            } catch (NumberFormatException e) {
                // 파싱 실패 시 null
            }
        }
        
        return PlaceDto.builder()
                .id(doc.id())
                .name(doc.placeName())
                .address(doc.roadAddressName() != null && !doc.roadAddressName().isEmpty() 
                        ? doc.roadAddressName() 
                        : doc.addressName())
                .latitude(new BigDecimal(doc.y()))
                .longitude(new BigDecimal(doc.x()))
                .phone(doc.phone())
                .category(doc.categoryName())
                .url(doc.placeUrl())
                .distance(distanceInMeters)
                .build();
    }
}

