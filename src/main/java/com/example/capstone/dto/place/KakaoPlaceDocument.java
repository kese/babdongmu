package com.example.capstone.dto.place;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 카카오맵 로컬 검색 API 응답 DTO
 * API 문서: https://developers.kakao.com/docs/latest/ko/local/dev-guide#search-by-keyword
 */
public record KakaoPlaceDocument(
        @JsonProperty("id")
        String id,

        @JsonProperty("place_name")
        String placeName,

        @JsonProperty("category_name")
        String categoryName,

        @JsonProperty("category_group_code")
        String categoryGroupCode,

        @JsonProperty("category_group_name")
        String categoryGroupName,

        @JsonProperty("phone")
        String phone,

        @JsonProperty("address_name")
        String addressName,

        @JsonProperty("road_address_name")
        String roadAddressName,

        @JsonProperty("x")
        String x, // 경도

        @JsonProperty("y")
        String y, // 위도

        @JsonProperty("place_url")
        String placeUrl,

        @JsonProperty("distance")
        String distance
) {
}

