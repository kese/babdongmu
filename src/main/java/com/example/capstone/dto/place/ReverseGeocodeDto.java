package com.example.capstone.dto.place;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;

import java.math.BigDecimal;

/**
 * 역지오코딩 응답 DTO
 * 좌표 → 주소 변환 결과
 */
@Builder
public record ReverseGeocodeDto(
        @JsonProperty("address")
        String address, // 기본 주소 (도로명 우선)

        @JsonProperty("roadAddress")
        String roadAddress, // 도로명 주소

        @JsonProperty("jibunAddress")
        String jibunAddress, // 지번 주소

        @JsonProperty("buildingName")
        String buildingName, // 건물명

        @JsonProperty("region1depthName")
        String region1depthName, // 시도 (예: 서울)

        @JsonProperty("region2depthName")
        String region2depthName, // 구 (예: 강남구)

        @JsonProperty("region3depthName")
        String region3depthName, // 동 (예: 역삼동)

        @JsonProperty("latitude")
        BigDecimal latitude, // 요청한 위도

        @JsonProperty("longitude")
        BigDecimal longitude // 요청한 경도
) {
}

