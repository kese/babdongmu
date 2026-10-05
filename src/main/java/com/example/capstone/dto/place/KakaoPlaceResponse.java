package com.example.capstone.dto.place;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * 카카오맵 로컬 검색 API 전체 응답 구조
 */
public record KakaoPlaceResponse(
        @JsonProperty("meta")
        Meta meta,

        @JsonProperty("documents")
        List<KakaoPlaceDocument> documents
) {
    public record Meta(
            @JsonProperty("total_count")
            Integer totalCount,

            @JsonProperty("pageable_count")
            Integer pageableCount,

            @JsonProperty("is_end")
            Boolean isEnd,

            @JsonProperty("same_name")
            SameName sameName
    ) {
        public record SameName(
                @JsonProperty("region")
                List<String> region,

                @JsonProperty("keyword")
                String keyword,

                @JsonProperty("selected_region")
                String selectedRegion
        ) {
        }
    }
}

