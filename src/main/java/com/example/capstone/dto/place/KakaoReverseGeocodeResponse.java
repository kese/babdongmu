package com.example.capstone.dto.place;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * 카카오맵 좌표→주소 변환 API 응답 구조
 * API 문서: https://developers.kakao.com/docs/latest/ko/local/dev-guide#coord-to-address
 */
public record KakaoReverseGeocodeResponse(
        @JsonProperty("meta")
        Meta meta,

        @JsonProperty("documents")
        List<Document> documents
) {
    public record Meta(
            @JsonProperty("total_count")
            Integer totalCount
    ) {
    }

    public record Document(
            @JsonProperty("address")
            Address address,

            @JsonProperty("road_address")
            RoadAddress roadAddress
    ) {
    }

    public record Address(
            @JsonProperty("address_name")
            String addressName, // 지번 주소 전체

            @JsonProperty("region_1depth_name")
            String region1depthName, // 시도

            @JsonProperty("region_2depth_name")
            String region2depthName, // 구

            @JsonProperty("region_3depth_name")
            String region3depthName, // 동

            @JsonProperty("mountain_yn")
            String mountainYn,

            @JsonProperty("main_address_no")
            String mainAddressNo,

            @JsonProperty("sub_address_no")
            String subAddressNo,

            @JsonProperty("zip_code")
            String zipCode
    ) {
    }

    public record RoadAddress(
            @JsonProperty("address_name")
            String addressName, // 도로명 주소 전체

            @JsonProperty("region_1depth_name")
            String region1depthName,

            @JsonProperty("region_2depth_name")
            String region2depthName,

            @JsonProperty("region_3depth_name")
            String region3depthName,

            @JsonProperty("road_name")
            String roadName,

            @JsonProperty("underground_yn")
            String undergroundYn,

            @JsonProperty("main_building_no")
            String mainBuildingNo,

            @JsonProperty("sub_building_no")
            String subBuildingNo,

            @JsonProperty("building_name")
            String buildingName,

            @JsonProperty("zone_no")
            String zoneNo
    ) {
    }
}

